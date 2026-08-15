/**
 * Unit tests for {@link readTierFromAnalysisOptionsYaml} — the TS-side mirror
 * of `lib/src/config/runtime_tier_cap.dart`'s `parseSaropaTierFromPluginBlock`.
 * analysis_options.yaml must be readable as the tier source of truth from both
 * the Dart engine and the VS Code extension identically.
 *
 * The `plugins.saropa_lints (shared fixture parity)` suite below loads
 * `test/fixtures/tier_yaml_parser_cases.json` — the SAME fixture file
 * `test/config/runtime_tier_cap_test.dart` loads — so both independently
 * implemented regex parsers are checked against one shared set of
 * yaml-input -> expected-tier cases instead of two hand-maintained,
 * potentially-diverging lists.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { readTierFromAnalysisOptionsYaml } from '../../config/tierConfig';

function makeWorkspace(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-tier-cfg-'));
}

function write(root: string, name: string, content: string): void {
  fs.writeFileSync(path.join(root, name), content, 'utf-8');
}

// compiled to out-test/test/config/tierConfig.test.js (rootDir: src, outDir:
// out-test) — four levels up from there is the repo root.
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');
const FIXTURE_PATH = path.join(REPO_ROOT, 'test', 'fixtures', 'tier_yaml_parser_cases.json');

interface FixtureCase {
  name: string;
  yaml: string;
  expected: string | null;
}

describe('readTierFromAnalysisOptionsYaml', () => {
  it('returns null when the file does not exist', () => {
    const root = makeWorkspace();
    assert.strictEqual(readTierFromAnalysisOptionsYaml(root), null);
  });

  it('strips quotes around the tier value', () => {
    const root = makeWorkspace();
    write(root, 'analysis_options.yaml', "plugins:\n  saropa_lints:\n    runtime_tier: 'professional'\n");
    assert.strictEqual(readTierFromAnalysisOptionsYaml(root), 'professional');
  });

  describe('plugins.saropa_lints (shared fixture parity)', () => {
    const fixture = JSON.parse(fs.readFileSync(FIXTURE_PATH, 'utf-8')) as { cases: FixtureCase[] };

    for (const c of fixture.cases) {
      it(c.name, () => {
        const root = makeWorkspace();
        write(root, 'analysis_options.yaml', c.yaml);
        assert.strictEqual(readTierFromAnalysisOptionsYaml(root), c.expected);
      });
    }
  });
});
