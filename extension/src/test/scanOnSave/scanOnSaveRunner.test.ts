import * as assert from 'node:assert';
import { buildScanOnSaveArgs, parseScanOnSaveOutput } from '../../scanOnSave/scanOnSaveRunner';

// Arg order matters here: parseScanArgs (the CLI's own arg parser) takes
// the first non-flag token as the project path, so a regression that
// reorders these would silently break scan-on-save without any type error.
describe('buildScanOnSaveArgs', () => {
  it('puts the project root first (parseScanArgs takes the FIRST non-flag token as path)', () => {
    const args = buildScanOnSaveArgs('D:/src/contacts', ['lib/main.dart'], 'recommended', false);
    assert.strictEqual(args[0], 'D:/src/contacts');
  });

  it('includes --tier, --files with all given paths, and --format json', () => {
    const args = buildScanOnSaveArgs('/proj', ['a.dart', 'b.dart'], 'essential', false);
    assert.deepStrictEqual(args, [
      '/proj',
      '--tier',
      'essential',
      '--files',
      'a.dart',
      'b.dart',
      '--format',
      'json',
    ]);
  });

  it('appends --resolve before --format when resolve=true (type-based rules need it)', () => {
    const args = buildScanOnSaveArgs('/proj', ['a.dart'], 'recommended', true);
    assert.ok(args.includes('--resolve'));
    assert.ok(args.indexOf('--resolve') < args.indexOf('--format'));
  });
});

// The CLI subprocess can produce empty stdout or malformed JSON on crash;
// parseScanOnSaveOutput must degrade to null rather than throwing, since
// an uncaught exception here would break the save-triggered scan silently.
describe('parseScanOnSaveOutput', () => {
  it('parses a valid payload with diagnostics', () => {
    const raw = JSON.stringify({
      version: 1,
      diagnostics: [
        { filePath: '/a.dart', line: 5, column: 3, ruleName: 'r1', severity: 'WARNING', problemMessage: 'msg' },
      ],
    });
    const parsed = parseScanOnSaveOutput(raw);
    assert.ok(parsed);
    assert.strictEqual(parsed!.diagnostics.length, 1);
    assert.strictEqual(parsed!.diagnostics[0].ruleName, 'r1');
  });

  it('parses a clean-scan payload with an empty diagnostics array', () => {
    const parsed = parseScanOnSaveOutput(JSON.stringify({ version: 1, diagnostics: [] }));
    assert.ok(parsed);
    assert.strictEqual(parsed!.diagnostics.length, 0);
  });

  it('returns null for empty stdout', () => {
    assert.strictEqual(parseScanOnSaveOutput(''), null);
  });

  it('returns null for malformed JSON instead of throwing', () => {
    assert.strictEqual(parseScanOnSaveOutput('{not json'), null);
  });

  it('returns null when diagnostics is missing/not an array', () => {
    assert.strictEqual(parseScanOnSaveOutput(JSON.stringify({ version: 1 })), null);
  });
});
