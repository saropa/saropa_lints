/**
 * Tests for the TS half of the two-lane split
 * (`plans/PLAN_two_lane_daemon_architecture.md`).
 *
 * The parser must agree with the Dart implementation
 * (`parseScalarFromPluginBlock` in `lib/src/config/runtime_tier_cap.dart`),
 * because a disagreement means the extension and the plugin hold different
 * beliefs about which lane is active — the extension would exclude rules from
 * the scan that the plugin is not in fact running.
 */
import '../vibrancy/register-vscode-mock';
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  parseLaneFromPluginBlock,
  projectConfiguresLightLane,
  readRawLaneFromAnalysisOptionsYaml,
  writeLaneToAnalysisOptionsYaml,
} from '../../config/laneConfig';

function makeWorkspace(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lane-cfg-'));
}

function write(root: string, name: string, content: string): void {
  fs.writeFileSync(path.join(root, name), content, 'utf-8');
}

describe('parseLaneFromPluginBlock', () => {
  it('reads lane from the saropa_lints plugin block', () => {
    const yaml = ['plugins:', '  saropa_lints:', '    lane: light', ''].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), 'light');
  });

  it('returns undefined when the key is absent', () => {
    const yaml = ['plugins:', '  saropa_lints:', '    version: "1.0.0"', ''].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), undefined);
  });

  it('returns undefined for an empty document', () => {
    assert.strictEqual(parseLaneFromPluginBlock(''), undefined);
  });

  it('ignores a commented-out lane and finds the live one below it', () => {
    // The generated config ships `# lane: light` as documentation; a user who
    // sets a real value adds a line without disturbing the comment. Reading
    // the comment instead of the live key would pin everyone to the wrong
    // value.
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    # lane: light # full | light (default when absent: light)',
      '    lane: full',
      '',
    ].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), 'full');
  });

  it('returns undefined when only a commented lane exists', () => {
    const yaml = ['plugins:', '  saropa_lints:', '    # lane: light', ''].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), undefined);
  });

  it('stops at the end of the saropa_lints block', () => {
    // `lane:` belonging to a DIFFERENT plugin must not be attributed to us.
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    version: "1.0.0"',
      '  other_plugin:',
      '    lane: light',
      '',
    ].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), undefined);
  });

  it('strips quotes and lower-cases the value', () => {
    const yaml = ['plugins:', '  saropa_lints:', '    lane: "LIGHT"', ''].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), 'light');
  });

  it('ignores a trailing comment on the value', () => {
    const yaml = ['plugins:', '  saropa_lints:', '    lane: light # why', ''].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), 'light');
  });

  it('handles CRLF line endings', () => {
    const yaml = 'plugins:\r\n  saropa_lints:\r\n    lane: light\r\n';
    assert.strictEqual(parseLaneFromPluginBlock(yaml), 'light');
  });

  it('blank lines inside the block do not end it', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    version: "1.0.0"',
      '',
      '    lane: light',
      '',
    ].join('\n');
    assert.strictEqual(parseLaneFromPluginBlock(yaml), 'light');
  });
});

describe('projectConfiguresLightLane', () => {
  // `light` is now the Dart-side default (see RuleLane in
  // lib/src/config/rule_lane.dart) — an absent/uncommented-but-unset `lane:`
  // key must read as light here too, or the extension keeps scanning rules
  // the in-process plugin is already covering, doubling every finding in the
  // Problems panel for every project that just uncomments the plugin block.
  it('reads light when the key is absent from an enabled plugin block', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    version: "1.0.0"\n');
    assert.strictEqual(projectConfiguresLightLane(root), true);
  });

  it('reads light when the key is explicitly light', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    lane: light\n');
    assert.strictEqual(projectConfiguresLightLane(root), true);
  });

  it('reads not-light when the key is explicitly full', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    lane: full\n');
    assert.strictEqual(projectConfiguresLightLane(root), false);
  });

  it('reads not-light on an unrecognized value (matches the Dart-side typo fallback)', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    lane: nonsense\n');
    assert.strictEqual(projectConfiguresLightLane(root), false);
  });

  it('reads not-light when analysis_options.yaml does not exist', () => {
    const root = makeWorkspace();
    assert.strictEqual(projectConfiguresLightLane(root), false);
  });
});

describe('readRawLaneFromAnalysisOptionsYaml', () => {
  it('returns the raw value when set', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    lane: full\n');
    assert.strictEqual(readRawLaneFromAnalysisOptionsYaml(root), 'full');
  });

  it('returns undefined when absent', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    version: "1.0.0"\n');
    assert.strictEqual(readRawLaneFromAnalysisOptionsYaml(root), undefined);
  });

  it('returns undefined when the file does not exist', () => {
    const root = makeWorkspace();
    assert.strictEqual(readRawLaneFromAnalysisOptionsYaml(root), undefined);
  });
});

describe('writeLaneToAnalysisOptionsYaml', () => {
  // Covers the lane-picker command's write path (`runSetLane` in setup.ts):
  // the picker only ever calls this with a live plugin block already on disk.
  it('inserts a live lane line under the block header when only the commented documentation line ships', () => {
    const root = makeWorkspace();
    write(
      root,
      'analysis_options.yaml',
      ['plugins:', '  saropa_lints:', '    version: "1.0.0"', '    # lane: light # full | light (default when absent: light)', ''].join('\n'),
    );
    const result = writeLaneToAnalysisOptionsYaml(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf-8');
    assert.strictEqual(parseLaneFromPluginBlock(content), 'full');
    // The commented documentation line must survive untouched — only a NEW
    // live line is added, the comment is not overwritten or removed.
    assert.ok(content.includes('# lane: light # full | light (default when absent: light)'));
  });

  it('replaces only the value token of an existing live lane line, preserving indentation and a trailing comment', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', ['plugins:', '  saropa_lints:', '    lane: light # why', ''].join('\n'));
    const result = writeLaneToAnalysisOptionsYaml(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf-8');
    assert.strictEqual(parseLaneFromPluginBlock(content), 'full');
    // Trailing comment must survive the flip — the writer replaces only the
    // value token, not the whole line, so a user's own annotation is kept.
    assert.ok(content.includes('lane: full # why'));
  });

  it('does not disturb sibling keys in the same block or a later, unrelated plugin block', () => {
    const root = makeWorkspace();
    write(
      root,
      'analysis_options.yaml',
      [
        'plugins:',
        '  saropa_lints:',
        '    version: "1.0.0"',
        '    log_level: info',
        '  other_plugin:',
        '    lane: light',
        '',
      ].join('\n'),
    );
    const result = writeLaneToAnalysisOptionsYaml(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf-8');
    assert.strictEqual(parseLaneFromPluginBlock(content), 'full');
    assert.ok(content.includes('version: "1.0.0"'));
    assert.ok(content.includes('log_level: info'));
    // The OTHER plugin's own `lane: light` must be untouched — only
    // saropa_lints's block was in scope for the write.
    assert.ok(content.includes('  other_plugin:\n    lane: light'));
  });

  it('preserves CRLF line endings when the source file uses them', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\r\n  saropa_lints:\r\n    lane: light\r\n');
    const result = writeLaneToAnalysisOptionsYaml(root, 'full');
    assert.deepStrictEqual(result, { ok: true });
    const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf-8');
    assert.ok(content.includes('\r\n'));
    assert.ok(!/[^\r]\n/.test(content), 'expected every newline to be preceded by \\r');
  });

  it('returns no-plugin-block when analysis_options.yaml has no saropa_lints block', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'analyzer:\n  strong-mode: true\n');
    const result = writeLaneToAnalysisOptionsYaml(root, 'light');
    assert.deepStrictEqual(result, { ok: false, reason: 'no-plugin-block' });
  });

  it('returns no-file when analysis_options.yaml does not exist', () => {
    const root = makeWorkspace();
    const result = writeLaneToAnalysisOptionsYaml(root, 'light');
    assert.deepStrictEqual(result, { ok: false, reason: 'no-file' });
  });

  it('round-trips through readRawLaneFromAnalysisOptionsYaml', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', 'plugins:\n  saropa_lints:\n    version: "1.0.0"\n');
    writeLaneToAnalysisOptionsYaml(root, 'full');
    assert.strictEqual(readRawLaneFromAnalysisOptionsYaml(root), 'full');
    writeLaneToAnalysisOptionsYaml(root, 'light');
    assert.strictEqual(readRawLaneFromAnalysisOptionsYaml(root), 'light');
  });
});
