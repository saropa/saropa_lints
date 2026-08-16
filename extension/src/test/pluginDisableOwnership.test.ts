/**
 * Toggling "Lint integration" Off then On must give the analyzer plugin back.
 *
 * The sidebar's "Lint integration" row is a single toggle: On runs
 * `saropaLints.disable`, Off runs `saropaLints.enable`. Disable comments out
 * the `plugins:` block, but Enable used to leave it commented — so Off→On
 * silently cost a user their live in-editor diagnostics, with the sidebar
 * still reporting "Lint integration: On" over a disabled analysis_options.yaml.
 *
 * The fix cannot key off the on-disk disable sentinel, because `write_config`
 * writes that same sentinel for a BRAND-NEW project (the in-process plugin
 * costs several GB, so new projects deliberately default to daemon-only).
 * Restoring on "sentinel present" would switch that heavy plugin on for every
 * new user's first Enable. Instead Disable records ownership in workspaceState
 * and Enable restores only what Disable took away — the cases pinned below.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  disablePluginsIntegration,
  getPluginsIntegrationState,
  reconcilePluginOwnership,
  restorePluginsIntegration,
  runDisable,
  runReenablePlugin,
} from '../setup';
import { invalidateProjectRoot } from '../projectRoot';
import { messageMock, mockWorkspaceFolders } from './vibrancy/vscode-mock';

const LIVE_OPTIONS = [
  'analyzer:',
  '  exclude:',
  '    - "**/*.g.dart"',
  '',
  'plugins:',
  '  saropa_lints:',
  '    version: "15.0.2"',
  '    diagnostics:',
  '      avoid_unsafe_cast: false',
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
        // Mirror the real memento: `undefined` deletes rather than stores.
        if (value === undefined) store.delete(key);
        else store.set(key, value);
      },
    },
  };
}

describe('analyzer plugin disable ownership', () => {
  let tmpDir: string;
  let optionsPath: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-ownership-'));
    optionsPath = path.join(tmpDir, 'analysis_options.yaml');
    // getProjectRoot() needs a pubspec.yaml to accept the folder as a root,
    // and caches its answer across calls.
    fs.writeFileSync(path.join(tmpDir, 'pubspec.yaml'), 'name: demo\n');
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmpDir } }];
    invalidateProjectRoot();
  });

  afterEach(() => {
    mockWorkspaceFolders.value = undefined;
    invalidateProjectRoot();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('reports the plugins block state independently of the enabled setting', () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'live');

    disablePluginsIntegration(tmpDir);
    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'disabled');

    fs.rmSync(optionsPath);
    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'absent');
  });

  it('claims ownership when Disable comments out a live block', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();

    await runDisable(context as any);

    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'disabled');
    assert.strictEqual(
      context.store.get(`saropaLints.pluginDisabledByExtension:${tmpDir}`),
      true,
      'Disable must record that it took a live block away',
    );
  });

  it('does NOT claim ownership of an already-disabled block', async () => {
    // This is the new-project case: write_config already wrote the block
    // sentinel-wrapped, so Disable finds nothing live to take away. Claiming
    // it here would make the next Enable switch on the multi-GB plugin that
    // the new-project default deliberately keeps off.
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    disablePluginsIntegration(tmpDir);
    const context = fakeContext();

    await runDisable(context as any);

    assert.strictEqual(
      context.store.has(`saropaLints.pluginDisabledByExtension:${tmpDir}`),
      false,
      'an already-off block must not be claimed',
    );
  });

  it('does NOT claim ownership when there is no plugins block at all', async () => {
    fs.writeFileSync(optionsPath, 'analyzer:\n  exclude:\n    - "**/*.g.dart"\n');
    const context = fakeContext();

    await runDisable(context as any);

    assert.strictEqual(
      context.store.has(`saropaLints.pluginDisabledByExtension:${tmpDir}`),
      false,
      'a project with no plugins block must not be claimed',
    );
  });

  it('releases ownership when the plugin is re-enabled explicitly', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);

    await runReenablePlugin(context as any);

    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'live');
    assert.strictEqual(
      context.store.has(`saropaLints.pluginDisabledByExtension:${tmpDir}`),
      false,
      'a restored block must not stay claimed, or the next Enable fights it',
    );
  });

  it('still reports success for an already-live block instead of dead-ending', async () => {
    // Enable restores the block and restarts the analysis server as two
    // separate steps; cancelling between them leaves the plugin declared but
    // dormant. "Nothing to restore" was a dead end for that state — the file
    // looks right, so the user has no route back short of reloading VS Code.
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    messageMock.infos.length = 0;

    await runReenablePlugin(context as any);

    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'live');
    assert.ok(
      !messageMock.infos.some((m) => /nothing to restore/i.test(m)),
      `must not dead-end on a live block; got: ${JSON.stringify(messageMock.infos)}`,
    );
  });

  it('treats a live block as live even when an orphaned sentinel is present', () => {
    // A half-applied hand-edit or a merge conflict can leave a begin marker
    // stranded above a block that is genuinely live. Trusting the sentinel
    // there would report "Off" while the analysis server loads the plugin —
    // the same UI-contradicts-the-file lie this row exists to remove.
    fs.writeFileSync(
      optionsPath,
      '# >>> saropa_lints integration turned OFF by the VS Code extension — toggle "Lint integration" On to restore >>>\n' +
        LIVE_OPTIONS,
    );

    assert.strictEqual(getPluginsIntegrationState(tmpDir), 'live');
  });

  it('clears a stale claim once the block goes live outside the extension', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);
    assert.strictEqual(context.store.has(`saropaLints.pluginDisabledByExtension:${tmpDir}`), true);

    // Someone re-runs `saropa_lints:init`, checks out a branch, or edits by
    // hand — the block is live again and our claim no longer describes reality.
    restorePluginsIntegration(tmpDir);
    const cleared = await reconcilePluginOwnership(context as any, tmpDir);

    assert.strictEqual(cleared, true, 'a stale claim must be reported as cleared');
    assert.strictEqual(context.store.has(`saropaLints.pluginDisabledByExtension:${tmpDir}`), false);
  });

  it('keeps a valid claim while the block is still disabled', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);

    const cleared = await reconcilePluginOwnership(context as any, tmpDir);

    assert.strictEqual(cleared, false, 'reconcile must not drop a claim that is still true');
    assert.strictEqual(context.store.has(`saropaLints.pluginDisabledByExtension:${tmpDir}`), true);
  });

  it('tracks ownership per project root', async () => {
    fs.writeFileSync(optionsPath, LIVE_OPTIONS);
    const context = fakeContext();
    await runDisable(context as any);

    assert.strictEqual(
      context.store.has('saropaLints.pluginDisabledByExtension:/some/other/root'),
      false,
      'ownership must not leak across roots in a multi-root window',
    );
  });
});
