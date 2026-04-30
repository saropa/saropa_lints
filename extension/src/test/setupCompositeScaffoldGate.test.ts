/**
 * Preflight UX for composite plugin scaffold: notification gate before folder input.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { invalidateProjectRoot } from '../projectRoot';
import { runEmitCompositePluginScaffold } from '../setup';
import {
  envMock,
  informationMessageMockQueue,
  messageMock,
  mockWorkspaceFolders,
  resetMocks,
} from './vibrancy/vscode-mock';

describe('runEmitCompositePluginScaffold preflight gate', () => {
  let tmpRoot: string;

  beforeEach(() => {
    resetMocks();
    invalidateProjectRoot();
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-scaffold-gate-'));
    fs.writeFileSync(path.join(tmpRoot, 'pubspec.yaml'), 'name: test_pkg\n');
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmpRoot } }];
  });

  afterEach(() => {
    invalidateProjectRoot();
    resetMocks();
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  });

  it('returns false when the preflight notification is dismissed without Continue', async () => {
    const ok = await runEmitCompositePluginScaffold();
    assert.strictEqual(ok, false);
    assert.strictEqual(messageMock.infos[0], 'Composite analyzer plugin scaffold');
  });

  it('returns false and opens the guide URL when Open guide is chosen', async () => {
    informationMessageMockQueue.push('Open guide');
    const ok = await runEmitCompositePluginScaffold();
    assert.strictEqual(ok, false);
    assert.ok(
      envMock.openedUrls.some((u) => u.includes('composite_analyzer_plugin.md')),
      'expected guide URL in openExternal',
    );
  });

  it('returns false when Continue is chosen but the folder input is cancelled', async () => {
    informationMessageMockQueue.push('Continue');
    const ok = await runEmitCompositePluginScaffold();
    assert.strictEqual(ok, false);
    assert.strictEqual(messageMock.infos[0], 'Composite analyzer plugin scaffold');
  });
});
