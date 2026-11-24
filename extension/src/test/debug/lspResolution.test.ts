/**
 * isSaropaLintsResolved gates the LSP spawn: without saropa_lints in
 * .dart_tool/package_config.json, `dart run saropa_lints:lsp_server` exits 255.
 */
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { isSaropaLintsResolved, resolveDartExecutable, LSP_SERVER_ARGS } from '../../debug/lspResolution';

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

  it('is false when package_config.json is missing', () => {
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is false when the file is malformed', () => {
    writeConfig('{not json');
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is false when saropa_lints is not listed', () => {
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

  it('never allows an implicit pub get', () => {
    assert.ok(LSP_SERVER_ARGS.includes('--no-pub'));
  });
});
