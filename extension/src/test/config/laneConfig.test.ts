/**
 * Tests for the TS half of the two-lane split
 * (`plans/PLAN_two_lane_daemon_architecture.md`).
 *
 * The parser must agree with the Dart implementation
 * (`_loadRuleLane` in `lib/src/native/config_loader.dart`),
 * because a disagreement means the extension and the plugin hold different
 * beliefs about which lane is active — the extension would exclude rules from
 * the scan that the plugin is not in fact running.
 *
 * `lane:` lives in `analysis_options_custom.yaml` as a top-level key, moved
 * from `analysis_options.yaml` to avoid `unsupported_option` warnings from the
 * Dart SDK's plugin-block validator.
 */
import '../vibrancy/register-vscode-mock';
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  parseLaneFromCustomConfig,
  parseLaneFromPluginBlock,
  projectConfiguresLightLane,
  readRawLaneFromCustomConfig,
  writeLaneToCustomConfig,
} from '../../config/laneConfig';

function makeWorkspace(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lane-cfg-'));
}

function write(root: string, name: string, content: string): void {
  fs.writeFileSync(path.join(root, name), content, 'utf-8');
}

describe('parseLaneFromCustomConfig', () => {
  it('reads lane as a top-level key', () => {
    const yaml = ['max_issues: 500', 'output: both', 'lane: light', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), 'light');
  });

  it('returns undefined when the key is absent', () => {
    const yaml = ['max_issues: 500', 'output: both', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), undefined);
  });

  it('returns undefined for an empty document', () => {
    assert.strictEqual(parseLaneFromCustomConfig(''), undefined);
  });

  it('reads full when explicitly set', () => {
    const yaml = ['lane: full', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), 'full');
  });

  it('ignores a commented-out lane line', () => {
    // The generated config ships `# lane: light` as documentation; an
    // uncommented line must take precedence. But if only the comment exists,
    // the parser should return undefined (commented = absent).
    const yaml = ['# lane: light # full | light (default when absent: light)', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), undefined);
  });

  it('strips quotes and lower-cases the value', () => {
    const yaml = ['lane: "LIGHT"', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), 'light');
  });

  it('ignores a trailing comment on the value', () => {
    const yaml = ['lane: light # why', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), 'light');
  });

  it('handles CRLF line endings', () => {
    const yaml = 'max_issues: 500\r\nlane: light\r\n';
    assert.strictEqual(parseLaneFromCustomConfig(yaml), 'light');
  });

  it('ignores indented lane keys (nested, not top-level)', () => {
    // A `lane:` indented inside another block is not our top-level key.
    const yaml = ['platforms:', '  lane: web', ''].join('\n');
    assert.strictEqual(parseLaneFromCustomConfig(yaml), undefined);
  });
});

describe('projectConfiguresLightLane', () => {
  // `light` is now the Dart-side default (see RuleLane in
  // lib/src/config/rule_lane.dart) — an absent/unset `lane:` key must read as
  // light here too, or the extension keeps scanning rules the in-process plugin
  // is already covering, doubling every finding in the Problems panel.
  it('reads light when the key is absent', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'max_issues: 500\noutput: both\n');
    assert.strictEqual(projectConfiguresLightLane(root), true);
  });

  it('reads light when the key is explicitly light', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'lane: light\n');
    assert.strictEqual(projectConfiguresLightLane(root), true);
  });

  it('reads not-light when the key is explicitly full', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'lane: full\n');
    assert.strictEqual(projectConfiguresLightLane(root), false);
  });

  it('reads not-light on an unrecognized value (matches the Dart-side typo fallback)', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'lane: nonsense\n');
    assert.strictEqual(projectConfiguresLightLane(root), false);
  });

  it('reads not-light when analysis_options_custom.yaml does not exist', () => {
    const root = makeWorkspace();
    assert.strictEqual(projectConfiguresLightLane(root), false);
  });
});

describe('readRawLaneFromCustomConfig', () => {
  it('returns the raw value when set', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'lane: full\n');
    assert.strictEqual(readRawLaneFromCustomConfig(root), 'full');
  });

  it('returns undefined when absent', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'max_issues: 500\n');
    assert.strictEqual(readRawLaneFromCustomConfig(root), undefined);
  });

  it('returns undefined when the file does not exist', () => {
    const root = makeWorkspace();
    assert.strictEqual(readRawLaneFromCustomConfig(root), undefined);
  });

  it('falls back to legacy plugin-block location when custom file has no lane key', () => {
    // Deprecation fallback: lane in old `plugins > saropa_lints:` block,
    // no lane key in custom file. Must return the legacy value.
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'max_issues: 500\n');
    write(root, 'analysis_options.yaml', [
      'plugins:',
      '  saropa_lints:',
      '    version: "15.2.4"',
      '    lane: full',
      '    diagnostics:',
      '      avoid_unguarded_debug: true',
    ].join('\n'));
    assert.strictEqual(readRawLaneFromCustomConfig(root), 'full');
  });

  it('falls back to legacy plugin-block when custom file does not exist', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', [
      'plugins:',
      '  saropa_lints:',
      '    lane: full',
    ].join('\n'));
    assert.strictEqual(readRawLaneFromCustomConfig(root), 'full');
  });

  it('prefers custom file over legacy plugin-block', () => {
    // Custom file takes precedence — the legacy value is ignored.
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'lane: light\n');
    write(root, 'analysis_options.yaml', [
      'plugins:',
      '  saropa_lints:',
      '    lane: full',
    ].join('\n'));
    assert.strictEqual(readRawLaneFromCustomConfig(root), 'light');
  });
});

describe('parseLaneFromPluginBlock', () => {
  it('extracts lane from the saropa_lints plugin block', () => {
    const content = [
      'plugins:',
      '  saropa_lints:',
      '    version: "15.2.4"',
      '    lane: full',
      '    diagnostics:',
      '      avoid_unguarded_debug: true',
    ].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(content), 'full');
  });

  it('returns undefined when lane is absent from the block', () => {
    const content = [
      'plugins:',
      '  saropa_lints:',
      '    version: "15.2.4"',
    ].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(content), undefined);
  });

  it('handles quoted lane values', () => {
    const content = [
      'plugins:',
      '  saropa_lints:',
      '    lane: "light"',
    ].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(content), 'light');
  });

  it('handles tab-indented plugin blocks', () => {
    // Tab indentation is invalid YAML but seen in the wild. The parser
    // must still extract the value rather than breaking out of the block.
    const content = 'plugins:\n\tsaropa_lints:\n\t\tlane: full\n';
    assert.strictEqual(parseLaneFromPluginBlock(content), 'full');
  });
});

describe('writeLaneToCustomConfig', () => {
  it('inserts a lane line when only the commented documentation line exists', () => {
    const root = makeWorkspace();
    write(
      root,
      'analysis_options_custom.yaml',
      ['max_issues: 500', 'output: both', 'log_level: info', '# lane: light # full | light (default when absent: light)', ''].join('\n'),
    );
    const result = writeLaneToCustomConfig(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options_custom.yaml'), 'utf-8');
    assert.strictEqual(parseLaneFromCustomConfig(content), 'full');
    // The commented documentation line must survive untouched.
    assert.ok(content.includes('# lane: light # full | light (default when absent: light)'));
  });

  it('replaces only the value token of an existing live lane line, preserving a trailing comment', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', ['max_issues: 500', 'lane: light # why', ''].join('\n'));
    const result = writeLaneToCustomConfig(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options_custom.yaml'), 'utf-8');
    assert.strictEqual(parseLaneFromCustomConfig(content), 'full');
    // Trailing comment must survive the flip.
    assert.ok(content.includes('lane: full # why'));
  });

  it('preserves CRLF line endings when the source file uses them', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'max_issues: 500\r\nlane: light\r\n');
    const result = writeLaneToCustomConfig(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options_custom.yaml'), 'utf-8');
    assert.ok(content.includes('\r\n'));
    assert.ok(!/[^\r]\n/.test(content), 'expected every newline to be preceded by \\r');
  });

  it('returns no-file when analysis_options_custom.yaml does not exist', () => {
    const root = makeWorkspace();
    const result = writeLaneToCustomConfig(root, 'light');
    assert.deepStrictEqual(result, { ok: false, reason: 'no-file' });
  });

  it('round-trips through readRawLaneFromCustomConfig', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options_custom.yaml', 'max_issues: 500\noutput: both\nlog_level: info\n');
    writeLaneToCustomConfig(root, 'full');
    assert.strictEqual(readRawLaneFromCustomConfig(root), 'full');
    writeLaneToCustomConfig(root, 'light');
    assert.strictEqual(readRawLaneFromCustomConfig(root), 'light');
  });
});
