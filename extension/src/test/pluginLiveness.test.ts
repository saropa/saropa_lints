/**
 * Issue #208 follow-up: when no `violations.json` exists, the recovery
 * branches by *why* (no pubspec, missing dev-dep, missing/malformed/
 * insufficient analysis_options.yaml, truly silent plugin) so the user
 * sees a precise diagnosis and a one-click "Set Up Project" path
 * instead of a generic analyzer-restart hint. Every config-fixable
 * branch surfaces the requirement explicitly so the user understands
 * the dashboard cannot show findings without it.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { verifyPluginLiveness } from '../pluginLiveness';

/** Minimal pubspec that passes the saropa_lints dev-dependency check. */
const PUBSPEC_WITH_SAROPA = 'name: app\ndev_dependencies:\n  saropa_lints: ^13.0.0\n';

describe('verifyPluginLiveness — no-report classification (issue #208 follow-up)', () => {
  let tmpRoot: string;

  beforeEach(() => {
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-liveness-'));
  });

  afterEach(() => {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  });

  // ── Pubspec gates ───────────────────────────────────────────────────

  it('classifies missing pubspec.yaml as no-pubspec (no Set Up button)', () => {
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.status, 'no-report');
    assert.strictEqual(r.noReportCause, 'no-pubspec');
    // Set Up Project requires a Dart/Flutter project — the user has to
    // open one first, so we must NOT offer a one-click setup here.
    assert.strictEqual(r.setUpActionable, false);
    // Message must lead with the requirement, not the symptom.
    assert.match(r.message, /requires a Dart or Flutter project/i);
  });

  it('classifies pubspec.yaml without saropa_lints as pubspec-missing-saropa-lints (Set Up offered)', () => {
    fs.writeFileSync(
      path.join(tmpRoot, 'pubspec.yaml'),
      'name: app\ndev_dependencies:\n  test: ^1.0.0\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.status, 'no-report');
    assert.strictEqual(r.noReportCause, 'pubspec-missing-saropa-lints');
    assert.strictEqual(r.setUpActionable, true);
    // Message must explain WHY (config required) not just WHAT (no entry).
    assert.match(r.message, /not configured/i);
    assert.match(r.message, /dashboard will stay empty/i);
  });

  it('does not match saropa_lints_extra as a saropa_lints dependency', () => {
    // Precision: substring matching would mistake saropa_lints_extra for
    // saropa_lints — exactly the kind of bug `^\s{2}saropa_lints\s*:` is
    // meant to prevent, so guard against regressions here.
    fs.writeFileSync(
      path.join(tmpRoot, 'pubspec.yaml'),
      'name: app\ndev_dependencies:\n  saropa_lints_extra: ^1.0.0\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.noReportCause, 'pubspec-missing-saropa-lints');
  });

  // ── analysis_options.yaml gates (issue #208 reporter's case) ────────

  it('classifies missing analysis_options.yaml as analysis-options-missing (Set Up offered)', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.noReportCause, 'analysis-options-missing');
    assert.strictEqual(r.setUpActionable, true);
    assert.match(r.message, /needs analysis_options\.yaml/i);
    // Make sure the message says the plugin can't enable any rule
    // without it (the actual user-facing consequence).
    assert.match(r.message, /cannot enable a single rule/i);
  });

  it('classifies tab-indented analysis_options.yaml as analysis-options-malformed (overwrite warned)', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    // Tab-indented YAML — the spec forbids tabs in indentation, and
    // this is the most common "looks fine to me" malformation.
    fs.writeFileSync(
      path.join(tmpRoot, 'analysis_options.yaml'),
      'analyzer:\n\terrors:\n\t\ttodo: ignore\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.noReportCause, 'analysis-options-malformed');
    assert.strictEqual(r.setUpActionable, true);
    // Recovery must warn that Set Up overwrites the file so the user
    // doesn't lose their custom analyzer settings by clicking blindly.
    assert.match(r.recovery, /discards your current contents/i);
  });

  it('classifies bare top-level saropa_lints key as analysis-options-no-saropa (issue #208 reporter case)', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    // Reproduces the exact YAML the issue #208 reporter ended up with
    // after their stash dance: a bare top-level `saropa_lints:` key,
    // which is not a valid plugin enrolment form. The dashboard stayed
    // empty until we surfaced this specific case.
    fs.writeFileSync(
      path.join(tmpRoot, 'analysis_options.yaml'),
      'saropa_lints:\n  tier: recommended\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.noReportCause, 'analysis-options-no-saropa');
    assert.strictEqual(r.setUpActionable, true);
    // Recovery must show the exact valid form so the user can fix by
    // hand if they don't want to use Set Up Project.
    assert.match(r.recovery, /include: package:saropa_lints\/tiers\/recommended\.yaml/);
    // Message must call out the bare-key trap by name so the reader
    // recognises the situation in their own file.
    assert.match(r.message, /does not enrol/i);
  });

  it('accepts the tier include directive as valid enrolment', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    fs.writeFileSync(
      path.join(tmpRoot, 'analysis_options.yaml'),
      'include: package:saropa_lints/tiers/recommended.yaml\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    // Pubspec + valid YAML enrolment + still no report → plugin-silent.
    assert.strictEqual(r.noReportCause, 'plugin-silent');
  });

  it('accepts the explicit plugins.saropa_lints block as valid enrolment', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    fs.writeFileSync(
      path.join(tmpRoot, 'analysis_options.yaml'),
      'plugins:\n  saropa_lints:\n    diagnostics:\n      avoid_print: true\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.noReportCause, 'plugin-silent');
  });

  it('rejects a bare plugins block without a saropa_lints child', () => {
    // Defence against a regression: matching only `^plugins:` would let
    // a `plugins: { other_lint: ... }` block falsely register as
    // saropa_lints enrolment.
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    fs.writeFileSync(
      path.join(tmpRoot, 'analysis_options.yaml'),
      'plugins:\n  other_lint:\n    config: true\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.noReportCause, 'analysis-options-no-saropa');
  });

  it('classifies fully-configured-but-no-report as plugin-silent (Set Up still offered)', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    fs.writeFileSync(
      path.join(tmpRoot, 'analysis_options.yaml'),
      'include: package:saropa_lints/tiers/recommended.yaml\n',
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.status, 'no-report');
    assert.strictEqual(r.noReportCause, 'plugin-silent');
    // Even though config looks fine, Set Up Project re-runs analysis
    // which often clears stuck plugin state — keep it offered.
    assert.strictEqual(r.setUpActionable, true);
  });

  it('config-not-loaded (zero rules in report) offers Set Up Project', () => {
    // Writing a zero-rule report simulates the analyzer-loaded-the-plugin-
    // but-never-read-its-config failure mode; setup regenerates yaml.
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    const reportDir = path.join(tmpRoot, 'reports', '.saropa_lints');
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(
      path.join(reportDir, 'violations.json'),
      JSON.stringify({
        violations: [],
        summary: { totalViolations: 0, filesAnalyzed: 10 },
        config: { enabledRuleCount: 0 },
      }),
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.status, 'config-not-loaded');
    assert.strictEqual(r.setUpActionable, true);
  });

  it('no-files-analyzed does NOT offer Set Up Project (would clobber excludes)', () => {
    // Set Up Project rewrites analysis_options.yaml — when the user's
    // exclude list is the problem, setup would lose their customizations.
    // The recovery must be a manual exclude review, not regeneration.
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    const reportDir = path.join(tmpRoot, 'reports', '.saropa_lints');
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(
      path.join(reportDir, 'violations.json'),
      JSON.stringify({
        violations: [],
        summary: { totalViolations: 0, filesAnalyzed: 0 },
        config: { enabledRuleCount: 200 },
      }),
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.status, 'no-files-analyzed');
    assert.strictEqual(r.setUpActionable, false);
  });

  it('alive plugin returns setUpActionable=false and no cause', () => {
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), PUBSPEC_WITH_SAROPA);
    const reportDir = path.join(tmpRoot, 'reports', '.saropa_lints');
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(
      path.join(reportDir, 'violations.json'),
      JSON.stringify({
        violations: [],
        summary: { totalViolations: 0, filesAnalyzed: 50 },
        config: { enabledRuleCount: 200 },
      }),
    );
    const r = verifyPluginLiveness(tmpRoot);
    assert.strictEqual(r.status, 'alive');
    assert.strictEqual(r.setUpActionable, false);
    assert.strictEqual(r.noReportCause, undefined);
  });
});
