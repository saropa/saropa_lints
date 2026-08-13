/**
 * "Lint integration: Off" must stop background analysis, not just diagnostics.
 *
 * Regression: `runAnalysis`/`runAnalysisForFiles` had no gate on `saropaLints.enabled`,
 * so toggling the integration off did not stop the dependency-change watcher,
 * config-change auto-run, or `enableRulePack` from spawning `dart analyze` and
 * showing a "Running analysis" progress notification.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { invalidateProjectRoot } from '../projectRoot';
import { runAnalysis, runAnalysisForFiles } from '../setup';
import {
  clearTestConfig,
  mockWorkspaceFolders,
  resetMocks,
  setTestConfig,
} from './vibrancy/vscode-mock';

describe('runAnalysis / runAnalysisForFiles enabled gate', () => {
  let tmpRoot: string;

  beforeEach(() => {
    resetMocks();
    clearTestConfig();
    invalidateProjectRoot();
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-analysis-gate-'));
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), 'name: test_pkg\n');
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmpRoot } }];
  });

  afterEach(() => {
    invalidateProjectRoot();
    clearTestConfig();
    resetMocks();
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  });

  it('runAnalysis no-ops without spawning `dart analyze` when integration is off', async () => {
    setTestConfig('saropaLints', 'enabled', false);
    const ok = await runAnalysis({} as any);
    assert.strictEqual(ok, false);
  });

  it('runAnalysisForFiles no-ops when integration is off', async () => {
    setTestConfig('saropaLints', 'enabled', false);
    const ok = await runAnalysisForFiles({} as any, ['lib/main.dart']);
    assert.strictEqual(ok, false);
  });
});
