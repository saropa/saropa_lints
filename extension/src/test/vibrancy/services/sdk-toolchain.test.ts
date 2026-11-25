/**
 * Tests for the Vibrancy SDK toolchain resolver and the pub-command guard.
 * Regression: bare PATH `dart pub outdated/deps` rewrote pubspec.lock with the
 * wrong SDK in FVM-pinned projects.
 */

import * as assert from 'assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
    shellSafeCommand, parseDartVersion, readProjectSdkVersion,
    readSdkVersionFromExecutable, readLockDartConstraint, satisfiesDartConstraint,
    checkSdkCompatibility, checkFreshness, findSdkBase, findLockRoot, guardPubCommand,
    probeDartVersion, resetProbeCache, GuardIo, affectsSdkSelection,
    registerSdkCacheInvalidation,
} from '../../../vibrancy/services/sdk-toolchain';
import { runDartPubOutdated } from '../../../vibrancy/services/flutter-cli';
import { resolveDartExecutable, resolveFlutterExecutable } from '../../../debug/lspResolution';

describe('sdk-toolchain', () => {
    const root = path.join(path.sep, 'proj');

    describe('resolution (shared resolver)', () => {
        it('prefers the FVM pin over PATH so the pinned SDK runs pub', () => {
            const fvmDart = path.join(root, '.fvm', 'flutter_sdk', 'bin', 'cache', 'dart-sdk', 'bin', 'dart');
            const r = resolveDartExecutable(root, {}, (p) => p === fvmDart, 'linux');
            assert.strictEqual(r.command, fvmDart);
            assert.strictEqual(r.source, 'fvm');
        });

        it('resolves flutter: setting, then FVM, then PATH', () => {
            const f = path.join(root, 'sdk', 'bin', 'flutter');
            assert.strictEqual(
                resolveFlutterExecutable(root, { flutterSdkPath: 'sdk' }, (p) => p === f, 'linux').command, f);
            const fvm = path.join(root, '.fvm', 'flutter_sdk', 'bin', 'flutter');
            assert.strictEqual(resolveFlutterExecutable(root, {}, (p) => p === fvm, 'linux').source, 'fvm');
            assert.strictEqual(resolveFlutterExecutable(root, {}, () => false, 'linux').source, 'path');
        });

        it('uses flutter.bat through a shell on Windows', () => {
            const r = resolveFlutterExecutable('C:\\p', { flutterSdkPath: 'C:\\sdk' }, () => true, 'win32');
            assert.ok(r.command.endsWith('flutter.bat'));
            assert.strictEqual(r.useShell, true);
        });
    });

    describe('findSdkBase', () => {
        it('walks up from a sub-package to the folder holding .fvm', () => {
            const pin = path.join(root, '.fvm', 'flutter_sdk');
            const sub = path.join(root, 'packages', 'a');
            assert.strictEqual(findSdkBase(sub, root, (p) => p === pin), root);
        });

        it('stops at the workspace folder and falls back to it', () => {
            const sub = path.join(root, 'packages', 'a');
            assert.strictEqual(findSdkBase(sub, root, () => false), root);
            assert.strictEqual(findSdkBase(sub, undefined, () => false), sub);
        });
    });

    describe('shellSafeCommand', () => {
        it('quotes only spaced commands under a shell', () => {
            assert.strictEqual(shellSafeCommand('C:\\a b\\dart.exe', true), '"C:\\a b\\dart.exe"');
            assert.strictEqual(shellSafeCommand('C:\\a b\\dart.exe', false), 'C:\\a b\\dart.exe');
            assert.strictEqual(shellSafeCommand('dart', true), 'dart');
        });
    });

    describe('version parsing', () => {
        it('parses `dart --version` output', () => {
            assert.strictEqual(parseDartVersion('Dart SDK version: 3.8.1 (stable) (Mon)'), '3.8.1');
            assert.strictEqual(parseDartVersion('garbage'), undefined);
        });

        it('reads project, SDK-root and lock versions', () => {
            assert.strictEqual(readProjectSdkVersion(root, () => '3.8.1\n'), '3.8.1');
            assert.strictEqual(readProjectSdkVersion(root, () => { throw new Error('x'); }), undefined);
            const exe = path.join(root, 'sdk', 'bin', 'dart');
            let read = '';
            assert.strictEqual(readSdkVersionFromExecutable(exe, (p) => { read = p; return '3.14.0'; }), '3.14.0');
            assert.strictEqual(read, path.join(root, 'sdk', 'version'));
            assert.strictEqual(readSdkVersionFromExecutable('dart', () => '1.0.0'), undefined);
        });

        it('reads the sdks.dart constraint from pubspec.lock (positive parse)', () => {
            const lock = 'packages:\n  a:\n    dependency: direct\nsdks:\n  dart: ">=3.8.0 <4.0.0"\n  flutter: ">=3.29.0"\n';
            assert.strictEqual(readLockDartConstraint(root, () => lock), '>=3.8.0 <4.0.0');
            assert.strictEqual(readLockDartConstraint(root, () => 'packages: {}\n'), undefined);
        });

        it('evaluates pub constraints', () => {
            assert.strictEqual(satisfiesDartConstraint('3.8.1', '>=3.8.0 <4.0.0'), true);
            assert.strictEqual(satisfiesDartConstraint('3.7.9', '>=3.8.0 <4.0.0'), false);
            assert.strictEqual(satisfiesDartConstraint('4.0.0', '>=3.8.0 <4.0.0'), false);
            assert.strictEqual(satisfiesDartConstraint('3.14.0', '>=3.13.0-0 <4.0.0'), true);
        });
    });

    describe('checkSdkCompatibility', () => {
        it('blocks a version mismatch', () => {
            const g = checkSdkCompatibility('3.8.1', undefined, '3.14.0', 'fvm');
            assert.strictEqual(g.safe, false);
            assert.strictEqual(g.reasonKey, 'pubGuard.sdkMismatch');
            assert.deepStrictEqual(g.reasonParams, { project: '3.8.1', tool: '3.14.0' });
        });

        it('allows equal versions', () => {
            assert.strictEqual(checkSdkCompatibility('3.8.1', undefined, '3.8.1', 'fvm').safe, true);
        });

        it('falls back to the lock constraint when .dart_tool/version is missing', () => {
            const bad = checkSdkCompatibility(undefined, '>=3.8.0 <4.0.0', '4.1.0', 'dart.sdkPath');
            assert.strictEqual(bad.reasonKey, 'pubGuard.lockSdkConstraint');
            assert.strictEqual(checkSdkCompatibility(undefined, '>=3.8.0 <4.0.0', '3.9.0', 'path').safe, true);
        });

        it('refuses an unknown PATH SDK but trusts an unknown configured SDK', () => {
            assert.strictEqual(checkSdkCompatibility('3.8.1', undefined, undefined, 'path').safe, false);
            assert.strictEqual(checkSdkCompatibility('3.8.1', undefined, undefined, 'fvm').safe, true);
        });
    });

    describe('checkFreshness (mirrors pub isResolutionUpToDate)', () => {
        const yamlText = 'name: x\ndependencies:\n  http: ^1.0.0\ndev_dependencies:\n  lints: ^4.0.0\n';
        const lockText = (names: string[]): string =>
            'packages:\n' + names.map((n) => `  ${n}:\n    dependency: direct\n    version: "${n === 'lints' ? '4.1.0' : '1.2.0'}"\n`).join('')
            + 'sdks:\n  dart: ">=3.8.0 <4.0.0"\n';
        const cfgText = (names: string[]): string => JSON.stringify({ packages: names.map((name) => ({ name })) });
        /** Builds an io from mtimes (yaml, lock, config) plus optional file contents. */
        const mk = (yaml?: number, lock?: number, cfg?: number, lockNames = ['http', 'lints'],
            cfgNames = ['http', 'lints'], yamlBody = yamlText) => ({
            mtimeMs: (p: string): number | undefined =>
                p.endsWith('pubspec.yaml') ? yaml : p.endsWith('pubspec.lock') ? lock
                    : p.endsWith('package_config.json') ? cfg : undefined,
            readFile: (p: string): string =>
                p.endsWith('pubspec.yaml') ? yamlBody : p.endsWith('pubspec.lock') ? lockText(lockNames)
                    : cfgText(cfgNames),
        });

        it('passes pub fast path: lock strictly newer than yaml, config not older', () => {
            assert.strictEqual(checkFreshness(root, mk(100, 200, 300)).safe, true);
            assert.strictEqual(checkFreshness(root, mk(100, 200, 200)).safe, true);
        });

        it('refuses when pubspec.lock is missing (pub resolves unconditionally)', () => {
            assert.strictEqual(checkFreshness(root, mk(100, undefined, 300)).reasonKey, 'pubGuard.staleLock');
        });

        it('refuses when package_config.json is missing (pub resolves unconditionally)', () => {
            assert.strictEqual(checkFreshness(root, mk(100, 200, undefined)).reasonKey, 'pubGuard.staleConfig');
        });

        it('does nothing without a pubspec.yaml', () => {
            assert.strictEqual(checkFreshness(root, mk(undefined, 200, 300)).safe, true);
        });

        it('git-checkout skew: yaml newer but every dependency locked -> safe (pub only touches mtimes)', () => {
            assert.strictEqual(checkFreshness(root, mk(500, 200, 900)).safe, true);
        });

        it('yaml newer and a declared dependency missing from the lock -> refuse', () => {
            const g = checkFreshness(root, mk(500, 200, 900, ['http']));
            assert.strictEqual(g.reasonKey, 'pubGuard.depsNotLocked');
        });

        it('yaml equal to lock is NOT strictly newer, so content decides', () => {
            assert.strictEqual(checkFreshness(root, mk(200, 200, 300)).safe, true);
            assert.strictEqual(checkFreshness(root, mk(200, 200, 300, ['http'])).reasonKey, 'pubGuard.depsNotLocked');
        });

        it('config older than lock but listing every locked package -> safe', () => {
            assert.strictEqual(checkFreshness(root, mk(100, 300, 200)).safe, true);
        });

        it('config older than lock and missing a locked package -> refuse', () => {
            assert.strictEqual(
                checkFreshness(root, mk(100, 300, 200, ['http', 'lints'], ['http'])).reasonKey, 'pubGuard.staleConfig');
        });

        it('unreadable files while out of order -> refuse', () => {
            const io = { mtimeMs: mk(500, 200, 900).mtimeMs, readFile: (): string => { throw new Error('EIO'); } };
            assert.strictEqual(checkFreshness(root, io).reasonKey, 'pubGuard.staleLock');
        });
    });

    describe('checkFreshness: constraints, path deps, workspaces', () => {
        const lock = (pairs: Array<[string, string]>): string =>
            'packages:\n' + pairs.map(([n, v]) => `  ${n}:\n    dependency: direct\n    version: "${v}"\n`).join('');
        const cfg = (names: string[]): string => JSON.stringify({ packages: names.map((name) => ({ name })) });
        /** files: path-suffix -> {m: mtime, t: text}. Longest suffix wins. */
        const fsio = (files: Record<string, { m: number; t: string }>) => {
            const find = (p: string): { m: number; t: string } | undefined => {
                const norm = p.split(path.sep).join('/');
                const k = Object.keys(files).filter((x) => norm.endsWith(x)).sort((a, b) => b.length - a.length)[0];
                return k ? files[k] : undefined;
            };
            return {
                mtimeMs: (p: string): number | undefined => find(p)?.m,
                readFile: (p: string): string => { const f = find(p); if (!f) { throw new Error('ENOENT'); } return f.t; },
            };
        };

        it('constraint edit (^1.0.0 -> ^2.0.0) with unchanged names -> refuse', () => {
            const io = fsio({
                '/proj/pubspec.yaml': { m: 500, t: 'dependencies:\n  foo: ^2.0.0\n' },
                '/proj/pubspec.lock': { m: 200, t: lock([['foo', '1.4.0']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['foo']) },
            });
            const g = checkFreshness('/proj', io);
            assert.strictEqual(g.reasonKey, 'pubGuard.constraintNotSatisfied');
            assert.deepStrictEqual(g.reasonParams, { name: 'foo', version: '1.4.0', constraint: '^2.0.0' });
        });

        it('yaml newer but locked version still satisfies the constraint -> safe', () => {
            const io = fsio({
                '/proj/pubspec.yaml': { m: 500, t: 'dependencies:\n  foo: ^1.0.0\n' },
                '/proj/pubspec.lock': { m: 200, t: lock([['foo', '1.4.0']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['foo']) },
            });
            assert.strictEqual(checkFreshness('/proj', io).safe, true);
        });

        it('dependency_overrides and dev_dependencies are checked too', () => {
            const base = { m: 200, t: lock([['foo', '1.4.0'], ['bar', '1.0.0']]) };
            const mk = (yaml: string) => fsio({
                '/proj/pubspec.yaml': { m: 500, t: yaml }, '/proj/pubspec.lock': base,
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['foo', 'bar']) },
            });
            assert.strictEqual(checkFreshness('/proj', mk('dev_dependencies:\n  bar: ^2.0.0\n')).reasonKey,
                'pubGuard.constraintNotSatisfied');
            assert.strictEqual(checkFreshness('/proj', mk('dependency_overrides:\n  foo: 2.0.0\n')).reasonKey,
                'pubGuard.constraintNotSatisfied');
        });

        it('pubspec_overrides.yaml content is checked', () => {
            const io = fsio({
                '/proj/pubspec.yaml': { m: 100, t: 'dependencies:\n  foo: ^1.0.0\n' },
                '/proj/pubspec_overrides.yaml': { m: 500, t: 'dependency_overrides:\n  foo: ^3.0.0\n' },
                '/proj/pubspec.lock': { m: 200, t: lock([['foo', '1.4.0']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['foo']) },
            });
            assert.strictEqual(checkFreshness('/proj', io).reasonKey, 'pubGuard.constraintNotSatisfied');
        });

        it('git, custom and unparseable forms are not evaluable -> refuse', () => {
            const mk = (yaml: string) => fsio({
                '/proj/pubspec.yaml': { m: 500, t: yaml },
                '/proj/pubspec.lock': { m: 200, t: lock([['foo', '1.4.0']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['foo']) },
            });
            assert.strictEqual(checkFreshness('/proj', mk('dependencies:\n  foo:\n    git:\n      url: x\n')).reasonKey,
                'pubGuard.constraintUnverifiable');
            assert.strictEqual(checkFreshness('/proj', mk('dependencies:\n  foo: {git: x}\n')).reasonKey,
                'pubGuard.constraintUnverifiable');
            assert.strictEqual(checkFreshness('/proj', mk('dependencies:\n  foo: ">=banana"\n')).reasonKey,
                'pubGuard.constraintUnverifiable');
        });

        it('sdk deps and hosted-with-version maps are fine', () => {
            const io = fsio({
                '/proj/pubspec.yaml': { m: 500, t: 'dependencies:\n  flutter:\n    sdk: flutter\n  foo:\n    hosted: https://x\n    version: ^1.0.0\n' },
                '/proj/pubspec.lock': { m: 200, t: lock([['flutter', '0.0.0'], ['foo', '1.4.0']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['flutter', 'foo']) },
            });
            assert.strictEqual(checkFreshness('/proj', io).safe, true);
        });

        it('path dependency pubspec newer than the lock -> refuse, even when the root yaml is old', () => {
            const io = fsio({
                '/proj/pubspec.yaml': { m: 100, t: 'dependencies:\n  loc:\n    path: ../loc\n' },
                '/loc/pubspec.yaml': { m: 500, t: 'name: loc\n' },
                '/proj/pubspec.lock': { m: 200, t: lock([['loc', '0.0.1']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['loc']) },
            });
            const g = checkFreshness('/proj', io);
            assert.strictEqual(g.reasonKey, 'pubGuard.pathDepNewer');
            assert.deepStrictEqual(g.reasonParams, { name: 'loc' });
        });

        it('path dependency older than the lock keeps pub fast path', () => {
            const io = fsio({
                '/proj/pubspec.yaml': { m: 100, t: 'dependencies:\n  loc:\n    path: ../loc\n' },
                '/loc/pubspec.yaml': { m: 150, t: 'name: loc\n' },
                '/proj/pubspec.lock': { m: 200, t: lock([['loc', '0.0.1']]) },
                '/proj/.dart_tool/package_config.json': { m: 900, t: cfg(['loc']) },
            });
            assert.strictEqual(checkFreshness('/proj', io).safe, true);
        });

        it('findLockRoot climbs to the workspace root and stops at the boundary', () => {
            const mt = (p: string): number | undefined => (p.split(path.sep).join('/').endsWith('/ws/pubspec.lock') ? 1 : undefined);
            const member = path.join(path.sep, 'ws', 'packages', 'a');
            assert.strictEqual(findLockRoot(member, path.join(path.sep, 'ws'), mt), path.join(path.sep, 'ws'));
            // Boundary below the lock: falls back to the member itself.
            assert.strictEqual(findLockRoot(member, path.join(path.sep, 'ws', 'packages'), mt), member);
        });

        it('workspace member: lock + package_config at the root, constraints from both pubspecs', () => {
            const files = {
                '/ws/packages/a/pubspec.yaml': { m: 100, t: 'resolution: workspace\ndependencies:\n  foo: ^1.0.0\n' },
                '/ws/pubspec.yaml': { m: 100, t: 'workspace:\n  - packages/a\n' },
                '/ws/pubspec.lock': { m: 200, t: lock([['foo', '1.4.0']]) },
                '/ws/.dart_tool/package_config.json': { m: 300, t: cfg(['foo']) },
            };
            assert.strictEqual(checkFreshness('/ws/packages/a', fsio(files), '/ws').safe, true);
            // Without the root lock the old code reported "lock missing"; now a real edit is named.
            const edited = { ...files, '/ws/packages/a/pubspec.yaml': { m: 500, t: 'dependencies:\n  foo: ^2.0.0\n' } };
            assert.strictEqual(checkFreshness('/ws/packages/a', fsio(edited), '/ws').reasonKey,
                'pubGuard.constraintNotSatisfied');
        });
    });

    describe('satisfiesDartConstraint (real-world sdks.dart values)', () => {
        const table: Array<[string, string, boolean | undefined]> = [
            ['3.8.1', '>=3.8.0 <4.0.0', true],
            ['3.7.0', '>=3.8.0 <4.0.0', false],
            ['3.14.0', '>=2.17.0-0 <4.0.0', true],
            ['4.0.0', '>=2.17.0-0 <4.0.0', false],
            ['3.5.0', '^3.5.0', true],
            ['3.4.9', '^3.5.0', false],
            ['4.0.0', '^3.5.0', false],
            ['3.0.0', '>=3.0.0', true],
            ['2.19.0', '>=3.0.0', false],
            ['3.8.1', 'any', true],
            ['3.8.1', '', undefined],
            ['3.8.1', '>=banana', undefined],
            ['3.8.1', '>=3.0.0 ||<2.0.0', undefined],
            ['not-a-version', '>=3.0.0', undefined],
            // caret on 0.x (pub semantics)
            ['0.0.3', '^0.0.3', true],
            ['0.0.4', '^0.0.3', false],
            ['0.2.9', '^0.2.1', true],
            ['0.3.0', '^0.2.1', false],
            // prerelease sorts before its release
            ['3.14.0-edge.1', '>=3.13.0-0 <4.0.0', true],
            ['3.8.0-dev', '>=3.8.0 <4.0.0', false],
            ['4.0.0-dev', '<4.0.0', false],
            ['2.0.0', '^1.0.0', false],
        ];
        for (const [version, constraint, expected] of table) {
            it(`${version} vs "${constraint}" -> ${expected}`, () => {
                assert.strictEqual(satisfiesDartConstraint(version, constraint), expected);
            });
        }

        it('malformed constraint on a bare PATH SDK is refused (unknown rule); configured SDK allowed', () => {
            assert.strictEqual(checkSdkCompatibility(undefined, '>=banana', '3.8.1', 'path').reasonKey,
                'pubGuard.unknownPathSdk');
            assert.strictEqual(checkSdkCompatibility(undefined, '>=banana', '3.8.1', 'fvm').safe, true);
            assert.strictEqual(checkSdkCompatibility(undefined, undefined, '3.8.1', 'path').safe, false);
        });
    });

    describe('probe cache invalidation', () => {
        beforeEach(() => resetProbeCache());

        it('resetProbeCache forces a fresh probe (settings / FVM pin changed)', async () => {
            let calls = 0;
            const run = async (): Promise<string | undefined> => { calls++; return '3.8.1'; };
            await probeDartVersion('dart', false, run);
            resetProbeCache();
            await probeDartVersion('dart', false, run);
            assert.strictEqual(calls, 2);
        });

        it('only dart.sdkPath / dart.flutterSdkPath changes invalidate', () => {
            assert.strictEqual(affectsSdkSelection((s) => s === 'dart.sdkPath'), true);
            assert.strictEqual(affectsSdkSelection((s) => s === 'dart.flutterSdkPath'), true);
            assert.strictEqual(affectsSdkSelection((s) => s === 'editor.fontSize'), false);
        });

        it('registerSdkCacheInvalidation returns disposables under the vscode mock', () => {
            const d = registerSdkCacheInvalidation();
            assert.ok(Array.isArray(d));
            d.forEach((x) => x.dispose());
        });
    });

    describe('guardPubCommand', () => {
        const io = (over: Partial<GuardIo>): GuardIo => ({
            readFile: (p) => {
                if (p.endsWith('version') && p.includes('.dart_tool')) { return '3.8.1'; }
                if (p.endsWith('pubspec.yaml') || p.endsWith('pubspec.lock')) { return ''; }
                throw new Error('ENOENT');
            },
            mtimeMs: (p) => (p.endsWith('pubspec.yaml') ? 1 : p.endsWith('pubspec.lock') ? 2 : p.endsWith('package_config.json') ? 3 : undefined),
            probe: async () => '3.14.0',
            ...over,
        });

        it('refuses on a PATH SDK that differs from the project SDK', async () => {
            const g = await guardPubCommand(root, { command: 'dart', useShell: false, source: 'path' }, { io: io({}) });
            assert.strictEqual(g.reasonKey, 'pubGuard.sdkMismatch');
        });

        it('allows when the probe matches the project SDK', async () => {
            const g = await guardPubCommand(root, { command: 'dart', useShell: false, source: 'path' },
                { io: io({ probe: async () => '3.8.1' }) });
            assert.strictEqual(g.safe, true);
        });

        it('refuses on stale files before consulting the SDK', async () => {
            let probed = false;
            const g = await guardPubCommand(root, { command: 'dart', useShell: false, source: 'path' },
                { io: io({
                    mtimeMs: (p) => (p.endsWith('pubspec.yaml') ? 9 : 2),
                    // yaml newer than lock AND declares a dependency the lock lacks.
                    readFile: (p) => (p.endsWith('pubspec.yaml') ? 'dependencies:\n  foo: ^1.0.0\n'
                        : p.endsWith('pubspec.lock') ? '' : '3.8.1'),
                    probe: async () => { probed = true; return '3.8.1'; },
                }) });
            assert.strictEqual(g.reasonKey, 'pubGuard.depsNotLocked');
            assert.strictEqual(probed, false);
        });
    });

    describe('probeDartVersion cache', () => {
        beforeEach(() => resetProbeCache());

        it('does not cache a failed probe', async () => {
            let calls = 0;
            const run = async (): Promise<string | undefined> => (++calls === 1 ? undefined : '3.8.1');
            assert.strictEqual(await probeDartVersion('dart', false, run), undefined);
            // Let the eviction microtask run before the retry.
            await Promise.resolve();
            assert.strictEqual(await probeDartVersion('dart', false, run), '3.8.1');
            assert.strictEqual(calls, 2);
        });

        it('caches a success and shares an in-flight probe', async () => {
            let calls = 0;
            const run = async (): Promise<string | undefined> => { calls++; return '3.8.1'; };
            const [a, b] = await Promise.all([
                probeDartVersion('dart', false, run), probeDartVersion('dart', false, run)]);
            assert.deepStrictEqual([a, b, calls], ['3.8.1', '3.8.1', 1]);
            await probeDartVersion('dart', false, run);
            assert.strictEqual(calls, 1);
        });

        it('expires a success after the TTL', async () => {
            let calls = 0;
            const run = async (): Promise<string | undefined> => { calls++; return '3.8.1'; };
            await probeDartVersion('dart', false, run, () => 0);
            await probeDartVersion('dart', false, run, () => 10 * 60 * 1000);
            assert.strictEqual(calls, 2);
        });
    });

    describe('runDartPubOutdated end to end (no spawn on mismatch)', () => {
        it('returns a skip failure without running the SDK when versions differ', async () => {
            const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vib-guard-'));
            try {
                const exe = process.platform === 'win32' ? 'dart.exe' : 'dart';
                const sdk = path.join(dir, '.fvm', 'flutter_sdk', 'bin', 'cache', 'dart-sdk');
                fs.mkdirSync(path.join(sdk, 'bin'), { recursive: true });
                // Fake SDK: the exe is an empty file, so running it would fail differently
                // from the guard's message; the version file claims 3.14.0.
                fs.writeFileSync(path.join(sdk, 'bin', exe), '');
                fs.writeFileSync(path.join(sdk, 'version'), '3.14.0\n');
                fs.mkdirSync(path.join(dir, '.dart_tool'));
                fs.writeFileSync(path.join(dir, '.dart_tool', 'version'), '3.8.1');
                // Ordered mtimes: yaml <= lock <= config so only the SDK check can refuse.
                const t = (n: number): Date => new Date(1_700_000_000_000 + n * 1000);
                const files: Array<[string, number]> = [
                    [path.join(dir, 'pubspec.yaml'), 0], [path.join(dir, 'pubspec.lock'), 1],
                    [path.join(dir, '.dart_tool', 'package_config.json'), 2]];
                for (const [f, n] of files) { fs.writeFileSync(f, ''); fs.utimesSync(f, t(n), t(n)); }

                const r = await runDartPubOutdated(dir);
                assert.strictEqual(r.success, false);
                assert.ok(r.errorMessage?.includes('3.8.1') && r.errorMessage.includes('3.14.0'), String(r.errorMessage));
            } finally {
                fs.rmSync(dir, { recursive: true, force: true });
            }
        });
    });
});
