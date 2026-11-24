/**
 * isSaropaLintsResolved gates the LSP spawn: without saropa_lints in
 * .dart_tool/package_config.json, `dart run saropa_lints:lsp_server` exits 255.
 */
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { isDartSdkTooOld, findLspServerMissing, isSaropaLintsResolved, resolveDartExecutable, buildLspServerArgs } from '../../debug/lspResolution';

describe('findLspServerMissing', () => {
  let root: string;
  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lsp-missing-'));
    fs.mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
  });
  afterEach(() => fs.rmSync(root, { recursive: true, force: true }));

  // Writes package_config.json pointing saropa_lints at a relative dir.
  function point(rel: string): string {
    fs.writeFileSync(
      path.join(root, '.dart_tool', 'package_config.json'),
      JSON.stringify({ packages: [{ name: 'saropa_lints', rootUri: rel }] }),
    );
    return path.resolve(root, '.dart_tool', rel);
  }

  it('reports the version when the package dir exists without bin/lsp_server.dart', () => {
    fs.mkdirSync(point('../saropa_lints-4.15.1/'), { recursive: true });
    assert.deepStrictEqual(findLspServerMissing(root), { version: '4.15.1' });
  });

  it('is undefined when bin/lsp_server.dart exists', () => {
    const dir = point('../pkg_new/');
    fs.mkdirSync(path.join(dir, 'bin'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'bin', 'lsp_server.dart'), '');
    assert.strictEqual(findLspServerMissing(root), undefined);
  });

  it('is undefined when the package dir cannot be found (unknown, do not block)', () => {
    point('../nowhere/');
    assert.strictEqual(findLspServerMissing(root), undefined);
  });
});

describe('isSaropaLintsResolved', () => {
  let root: string;

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lsp-'));
  });

  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true });
  });

  function writeConfig(content: string): void {
    fs.mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
    fs.writeFileSync(path.join(root, '.dart_tool', 'package_config.json'), content);
  }

  it('is undefined when package_config.json is missing', () => {
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is undefined when the file is malformed', () => {
    writeConfig('{not json');
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is undefined when saropa_lints is not listed', () => {
    writeConfig(JSON.stringify({ packages: [{ name: 'other' }] }));
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is true when saropa_lints is listed', () => {
    writeConfig(JSON.stringify({ packages: [{ name: 'other' }, { name: 'saropa_lints' }] }));
    assert.strictEqual(isSaropaLintsResolved(root), true);
  });
});

describe('resolveDartExecutable', () => {
  const root = path.join(os.tmpdir(), 'proj');
  const only = (...files: string[]) => (p: string): boolean => files.includes(p);
  const fvmDart = path.join(root, '.fvm', 'flutter_sdk', 'bin', 'cache', 'dart-sdk', 'bin', 'dart');

  it('prefers dart.sdkPath over everything', () => {
    const sdk = path.join(os.tmpdir(), 'sdk');
    const f = path.join(sdk, 'bin', 'dart');
    const r = resolveDartExecutable(root, { dartSdkPath: sdk }, only(f, fvmDart), 'linux');
    assert.deepStrictEqual([r.command, r.source, r.useShell], [f, 'dart.sdkPath', false]);
  });

  it('resolves a relative dart.flutterSdkPath against the project root', () => {
    const r = resolveDartExecutable(root, { flutterSdkPath: '.fvm/flutter_sdk' }, only(fvmDart), 'linux');
    assert.strictEqual(r.command, fvmDart);
    assert.strictEqual(r.source, 'dart.flutterSdkPath');
  });

  it('auto-detects .fvm/flutter_sdk with no settings', () => {
    const r = resolveDartExecutable(root, {}, only(fvmDart), 'linux');
    assert.strictEqual(r.source, 'fvm');
  });

  it('uses dart.exe without a shell on Windows when resolved', () => {
    const f = path.join(root, '.fvm', 'flutter_sdk', 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe');
    const r = resolveDartExecutable(root, {}, only(f), 'win32');
    assert.deepStrictEqual([r.command, r.useShell], [f, false]);
  });

  it('skips a configured path that does not exist and falls back to PATH', () => {
    const r = resolveDartExecutable(root, { dartSdkPath: '/nope', flutterSdkPath: '  ' }, () => false, 'win32');
    assert.deepStrictEqual([r.command, r.useShell, r.source], ['dart', true, 'path']);
  });

  it('falls back to PATH dart without a shell on non-Windows', () => {
    const r = resolveDartExecutable(root, {}, () => false, 'linux');
    assert.deepStrictEqual([r.command, r.useShell], ['dart', false]);
  });
});

describe('isDartSdkTooOld', () => {
  let root: string;
  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-sdk-'));
    fs.mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
  });
  afterEach(() => fs.rmSync(root, { recursive: true, force: true }));
  const write = (v: string): void => fs.writeFileSync(path.join(root, '.dart_tool', 'version'), v);

  it('is true below 3.9 (Flutter 3.32.8 = Dart 3.8.1)', () => {
    write('3.8.1');
    assert.strictEqual(isDartSdkTooOld(root), true);
  });
  it('is false at 3.9 and above', () => {
    write('3.9.0');
    assert.strictEqual(isDartSdkTooOld(root), false);
  });
  it('is false when the version file is missing', () => {
    assert.strictEqual(isDartSdkTooOld(root), false);
  });
});

describe('buildLspServerArgs', () => {
  let root: string;
  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-args-'));
    fs.mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
  });
  afterEach(() => fs.rmSync(root, { recursive: true, force: true }));

  it('never emits --no-pub (invalid for dart run on every SDK)', () => {
    assert.ok(!buildLspServerArgs(root).includes('--no-pub'));
  });

  it('runs the script directly against package_config when resolvable (no pub get)', () => {
    const pkg = path.join(root, 'pkg');
    fs.mkdirSync(path.join(pkg, 'bin'), { recursive: true });
    fs.writeFileSync(path.join(pkg, 'bin', 'lsp_server.dart'), '');
    fs.writeFileSync(
      path.join(root, '.dart_tool', 'package_config.json'),
      JSON.stringify({ packages: [{ name: 'saropa_lints', rootUri: '../pkg/' }] }),
    );
    const args = buildLspServerArgs(root);
    assert.strictEqual(args.length, 2);
    assert.ok(args[0].startsWith('--packages='));
    assert.ok(args[1].endsWith('lsp_server.dart'));
  });

  it('falls back to dart run when the package dir cannot be resolved', () => {
    assert.deepStrictEqual(buildLspServerArgs(root), ['run', 'saropa_lints:lsp_server']);
  });
});
