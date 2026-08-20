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
import { parseLaneFromPluginBlock, projectConfiguresLightLane } from '../../config/laneConfig';

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
