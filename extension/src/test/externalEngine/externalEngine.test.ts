/**
 * Pure helpers behind "Scan with latest engine": version gating, SDK path
 * resolution and argv shape (project root must be the first positional token).
 */
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  buildEngineActivateArgs,
  buildEngineScanArgs,
  isDartNewEnough,
  projectNeedsExternalEngine,
  readProjectDartVersion,
  parseDartVersion,
  resolveEngineDart,
} from '../../externalEngine/externalEngine';

describe('parseDartVersion', () => {
  it('reads major.minor from `dart --version` output', () => {
    assert.deepStrictEqual(parseDartVersion('Dart SDK version: 3.14.0 (stable) on "windows_x64"'), [3, 14]);
    assert.deepStrictEqual(parseDartVersion('Dart SDK version: 3.8.1 (stable)'), [3, 8]);
  });
  it('is undefined for unrelated output', () => {
    assert.strictEqual(parseDartVersion('command not found'), undefined);
  });
});

describe('isDartNewEnough', () => {
  it('requires Dart 3.11+', () => {
    assert.strictEqual(isDartNewEnough([3, 10]), false);
    assert.strictEqual(isDartNewEnough([3, 8]), false);
    assert.strictEqual(isDartNewEnough([3, 11]), true);
    assert.strictEqual(isDartNewEnough([4, 0]), true);
  });
});

describe('resolveEngineDart', () => {
  it('uses the configured SDK root, no shell', () => {
    const r = resolveEngineDart('/sdk/dart-3.14', 'linux');
    assert.deepStrictEqual(r, { command: path.join('/sdk/dart-3.14', 'bin', 'dart'), useShell: false });
  });
  it('uses dart.exe on Windows', () => {
    assert.ok(resolveEngineDart('C:/sdk', 'win32').command.endsWith('dart.exe'));
  });
  it('falls back to PATH dart; shell only on Windows', () => {
    assert.deepStrictEqual(resolveEngineDart('  ', 'win32'), { command: 'dart', useShell: true });
    assert.deepStrictEqual(resolveEngineDart(undefined, 'linux'), { command: 'dart', useShell: false });
  });
});

describe('engine argv', () => {
  it('activates saropa_lints globally', () => {
    assert.deepStrictEqual(buildEngineActivateArgs(), ['pub', 'global', 'activate', 'saropa_lints']);
  });
  it('puts the project root immediately after the scan target', () => {
    const a = buildEngineScanArgs('D:/p', 'essential');
    assert.strictEqual(a[a.indexOf('saropa_lints:scan') + 1], 'D:/p');
    assert.ok(a.includes('--format') && a.includes('json'));
    assert.ok(!a.includes('--no-pub'));
  });
});

describe('readProjectDartVersion / projectNeedsExternalEngine', () => {
  it('reads .dart_tool/version and flags Dart 3.8 as needing the external engine', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-engine-'));
    try {
      fs.mkdirSync(path.join(root, '.dart_tool'));
      fs.writeFileSync(path.join(root, '.dart_tool', 'version'), '3.8.1');
      const v = readProjectDartVersion(root);
      assert.deepStrictEqual(v, [3, 8]);
      assert.strictEqual(projectNeedsExternalEngine(v), true);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
  it('does not flag Dart 3.14 or an unknown version', () => {
    assert.strictEqual(projectNeedsExternalEngine([3, 14]), false);
    assert.strictEqual(projectNeedsExternalEngine(undefined), false);
  });
});
