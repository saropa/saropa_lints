/**
 * Toggling "Lint integration" Off must actually stop the analyzer.
 *
 * Regression for plans/history/2026.06/2026.06.18/BUG_cant turn off lints.md: disabling only flipped the
 * `saropaLints.enabled` setting, which the analysis server never reads, so
 * saropa_lints diagnostics kept appearing. The fix comments out the top-level
 * `plugins:` block in analysis_options.yaml and restores it byte-for-byte on
 * re-enable (preserving the user's rule_packs and overrides).
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { disablePluginsIntegration, restorePluginsIntegration } from '../setup';

const ORIGINAL = [
  'analyzer:',
  '  exclude:',
  '    - "**/*.g.dart"',
  '',
  'linter:',
  '  rules:',
  '    avoid_print: false',
  '',
  'plugins:',
  '  saropa_lints:',
  '    version: "14.0.2"',
  '    rule_packs:',
  '      enabled:',
  '        - bloc',
  '        - drift',
  '    diagnostics:',
  '      avoid_unsafe_cast: false',
  '',
].join('\n');

describe('disablePluginsIntegration / restorePluginsIntegration', () => {
  let tmpDir: string;
  let optionsPath: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-toggle-'));
    optionsPath = path.join(tmpDir, 'analysis_options.yaml');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('comments out the entire plugins block so the analyzer stops loading it', () => {
    fs.writeFileSync(optionsPath, ORIGINAL);

    const result = disablePluginsIntegration(tmpDir);
    assert.strictEqual(result, 'commented');

    const after = fs.readFileSync(optionsPath, 'utf-8');
    // No live (column-0) `plugins:` header remains for the analyzer to load.
    assert.ok(!/^plugins:\s*$/m.test(after), 'live plugins: header still present');
    // The block content is preserved, just commented.
    assert.ok(after.includes('#   saropa_lints:'));
    assert.ok(after.includes('#         - bloc'));
    // Sections above the block are untouched.
    assert.ok(after.includes('\nlinter:\n'));
    assert.ok(after.includes('    avoid_print: false'));
  });

  it('restores the block byte-for-byte (rule_packs + overrides intact)', () => {
    fs.writeFileSync(optionsPath, ORIGINAL);

    disablePluginsIntegration(tmpDir);
    const restored = restorePluginsIntegration(tmpDir);

    assert.strictEqual(restored, true);
    assert.strictEqual(fs.readFileSync(optionsPath, 'utf-8'), ORIGINAL);
  });

  it('is idempotent: a second disable does not double-comment', () => {
    fs.writeFileSync(optionsPath, ORIGINAL);

    disablePluginsIntegration(tmpDir);
    const second = disablePluginsIntegration(tmpDir);
    assert.strictEqual(second, 'already-off');

    // Round-trip still yields the exact original.
    restorePluginsIntegration(tmpDir);
    assert.strictEqual(fs.readFileSync(optionsPath, 'utf-8'), ORIGINAL);
  });

  it('reports no-config when analysis_options.yaml is absent', () => {
    assert.strictEqual(disablePluginsIntegration(tmpDir), 'no-config');
    assert.strictEqual(restorePluginsIntegration(tmpDir), false);
  });

  it('reports no-config when there is no plugins block to disable', () => {
    fs.writeFileSync(optionsPath, 'analyzer:\n  exclude:\n    - "build/**"\n');
    assert.strictEqual(disablePluginsIntegration(tmpDir), 'no-config');
  });

  it('preserves CRLF line endings across the round-trip', () => {
    const crlf = ORIGINAL.replaceAll('\n', '\r\n');
    fs.writeFileSync(optionsPath, crlf);

    disablePluginsIntegration(tmpDir);
    restorePluginsIntegration(tmpDir);

    assert.strictEqual(fs.readFileSync(optionsPath, 'utf-8'), crlf);
  });

  // Regression: a real project's analysis_options.yaml can end up with MIXED
  // line endings (e.g. `write_config`'s Dart writer emits bare `\n` for the
  // plugins: block it generates, dropped into a file whose other lines are
  // CRLF from a Windows/git checkout). The old `content.split(guessedEol)`
  // logic guessed one EOL for the whole file, which glued most lines together
  // and made the exact-match sentinel lookup fail even though the sentinel
  // was plainly present in the file — surfacing to the user as
  // "Re-enable Plugin: nothing to restore" on a file that WAS disabled.
  it('restores correctly even when the file mixes CRLF and bare-LF lines', () => {
    const linesLf = ORIGINAL.split('\n');
    // CRLF above the plugins: block, bare LF for the block itself and below —
    // matches the real-world shape (surrounding file CRLF, generated block LF).
    const pluginsIdx = linesLf.indexOf('plugins:');
    const mixed =
      linesLf.slice(0, pluginsIdx).join('\r\n') +
      '\r\n' +
      linesLf.slice(pluginsIdx).join('\n');
    fs.writeFileSync(optionsPath, mixed);

    const disableResult = disablePluginsIntegration(tmpDir);
    assert.strictEqual(disableResult, 'commented');

    const restoreResult = restorePluginsIntegration(tmpDir);
    assert.strictEqual(restoreResult, true, 'restore must find the sentinel despite mixed EOLs');

    const after = fs.readFileSync(optionsPath, 'utf-8');
    assert.ok(after.includes('rule_packs:'));
    assert.ok(after.includes('- bloc'));
    assert.ok(!after.includes('# plugins:'), 'plugins: block must be live again, not still commented');
  });
});
