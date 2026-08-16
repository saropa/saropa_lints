/**
 * The reconciliation prompt must fire for real drift and stay silent otherwise.
 *
 * Saropa Lints has two independent switches — `saropaLints.enabled` (scan-on-
 * save) and the `plugins:` block (the in-process analyzer plugin). Surfacing
 * both in the sidebar removed the lie but left the user with no way to tell
 * which state they meant. This prompt closes that gap, and its whole value
 * depends on being rare: the new-project default (enabled + a sentinel-wrapped
 * block) looks IDENTICAL on disk to real drift, and prompting there would
 * interrupt every new user about a state we chose for them deliberately. The
 * ownership claim is the only thing separating the two, so these tests pin that
 * distinction, the one-time dismissal, and the action wiring.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { disablePluginsIntegration, runDisable } from '../setup';
import { surfacePluginDivergence } from '../pluginDivergencePrompt';
import { invalidateProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';
import {
  clearTestConfig,
  commands,
  informationMessageMockQueue,
  messageMock,
  mockWorkspaceFolders,
  setTestConfig,
} from './vibrancy/vscode-mock';

const LIVE_OPTIONS = [
  'analyzer:',
  '  exclude:',
  '    - "**/*.g.dart"',
  '',
  'plugins:',
  '  saropa_lints:',
  '    version: "15.0.2"',
  '',
].join('\n');

/** Minimal ExtensionContext stand-in — only workspaceState is exercised. */
function fakeContext(): { workspaceState: any; store: Map<string, unknown> } {
  const store = new Map<string, unknown>();
  return {
    store,
    workspaceState: {
      get: <T>(key: string, defaultValue?: T): T | undefined =>
        store.has(key) ? (store.get(key) as T) : defaultValue,
      update: async (key: string, value: unknown): Promise<void> => {
        if (value === undefined) store.delete(key);
        else store.set(key, value);
      },
    },
  };
}

describe('analyzer plugin divergence prompt', () => {
  let tmpDir: string;
  let optionsPath: string;
  let executed: string[];

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-divergence-'));
    optionsPath = path.join(tmpDir, 'analysis_options.yaml');
    fs.writeFileSync(path.join(tmpDir, 'pubspec.yaml'), 'name: demo\n');
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmpDir } }];
    invalidateProjectRoot();
    messageMock.infos.length = 0;
    informationMessageMockQueue.length = 0;
    // Record which reconciliation command the prompt drives, without running
    // the real Enable/Disable flows (which spawn Dart subprocesses).
    executed = [];
    commands.registerCommand('saropaLints.reenablePlugin', () => { executed.push('reenablePlugin'); });
    commands.registerCommand('saropaLints.disable', () => { executed.push('disable'); });
  });

  afterEach(() => {
    mockWorkspaceFolders.value = undefined;
    invalidateProjectRoot();
    clearTestConfig();
    informationMessageMockQueue.length = 0;
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('stays silent for a brand-new project that defaulted the plugin off', async () => {
    // enabled + disabled block + NO ownership claim: exactly what write_config
    // writes for a new file. Prompting here would nag every new user.
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    disablePluginsIntegration(tmpDir);
    setTestConfig('saropaLints', 'enabled', true);

    const kind = await surfacePluginDivergence(fakeContext() as any, tmpDir);

    assert.strictEqual(kind, undefined);
    assert.deepStrictEqual(messageMock.infos, []);
  });

  it('stays silent when integration was never set up', async () => {
    fs.writeFileSync(optionsPath, 'analyzer:\n  exclude:\n    - "**/*.g.dart"\n');
    setTestConfig('saropaLints', 'enabled', true);

    assert.strictEqual(await surfacePluginDivergence(fakeContext() as any, tmpDir), undefined);
  });

  it('stays silent when both switches agree', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    setTestConfig('saropaLints', 'enabled', true);

    assert.strictEqual(await surfacePluginDivergence(fakeContext() as any, tmpDir), undefined);
  });

  it('prompts when our own Disable took the plugin away and Enable never gave it back', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);
    // The user turned scan-on-save back on; the block stayed commented.
    setTestConfig('saropaLints', 'enabled', true);
    messageMock.infos.length = 0;

    const kind = await surfacePluginDivergence(context as any, tmpDir);

    assert.strictEqual(kind, 'enabled-but-plugin-off');
    assert.strictEqual(messageMock.infos.length, 1);
  });

  it('runs the restore command when the user picks reconcile', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);
    setTestConfig('saropaLints', 'enabled', true);
    informationMessageMockQueue.push(l10n('notify.divergence.actionRestorePlugin'));

    await surfacePluginDivergence(context as any, tmpDir);

    assert.deepStrictEqual(executed, ['reenablePlugin']);
  });

  it('prompts when the plugin is still declared while lints are off', async () => {
    // Not a state we ever produce — reachable via a git checkout or a manual
    // init — and the expensive one: the plugin loads and holds several GB.
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    setTestConfig('saropaLints', 'enabled', false);

    const kind = await surfacePluginDivergence(fakeContext() as any, tmpDir);

    assert.strictEqual(kind, 'disabled-but-plugin-on');
  });

  it('asks only once per divergence, even when dismissed without choosing', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    setTestConfig('saropaLints', 'enabled', false);
    const context = fakeContext();

    await surfacePluginDivergence(context as any, tmpDir);
    messageMock.infos.length = 0;
    const second = await surfacePluginDivergence(context as any, tmpDir);

    assert.strictEqual(second, undefined, 're-asking on every activation is worse than the drift');
    assert.deepStrictEqual(messageMock.infos, []);
  });

  it('still prompts for the OPPOSITE divergence after one was dismissed', async () => {
    // Dismissal is recorded per divergence kind, not per root: "keep scan-on-
    // save only" must not silence the later, costlier "the plugin is loading
    // while you think lints are off".
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);
    setTestConfig('saropaLints', 'enabled', true);
    await surfacePluginDivergence(context as any, tmpDir);

    // The user restores the block by hand and turns lints off.
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    setTestConfig('saropaLints', 'enabled', false);
    const kind = await surfacePluginDivergence(context as any, tmpDir);

    assert.strictEqual(kind, 'disabled-but-plugin-on');
  });
});
