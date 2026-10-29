/**
 * The single On / Off / Partly off switch: state computation, the symmetric
 * enable/disable setting writes, and the version-drift sync.
 */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  computeLintsSwitchState,
  detectPluginVersionDrift,
  getLintsSwitchState,
  lintsSwitchDashboardMessage,
  lintsSwitchLabel,
  syncPluginVersionToPinned,
  toggleLints,
} from '../lintsSwitch';
import { disablePluginsIntegration, runDisable, runReenablePlugin } from '../setup';
import { invalidateProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';
import {
  clearTestConfig,
  configUpdates,
  mockWorkspaceFolders,
  setTestConfig,
} from './vibrancy/vscode-mock';

const LIVE = ['plugins:', '  saropa_lints:', '    version: "17.0.0"  # pinned', ''].join('\n');
const LOCK = [
  'packages:',
  '  saropa_lints:',
  '    dependency: "direct dev"',
  '    description:',
  '      name: saropa_lints',
  '    source: hosted',
  '    version: "17.0.1-beta.2"',
  '',
].join('\n');

function fakeContext(): any {
  const store = new Map<string, unknown>();
  return {
    workspaceState: {
      get: <T>(k: string, d?: T): T | undefined => (store.has(k) ? (store.get(k) as T) : d),
      update: async (k: string, v: unknown): Promise<void> => {
        if (v === undefined) store.delete(k);
        else store.set(k, v);
      },
    },
  };
}

describe('lints on/off switch', () => {
  let tmp: string;
  let options: string;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-switch-'));
    options = path.join(tmp, 'analysis_options.yaml');
    fs.writeFileSync(path.join(tmp, 'pubspec.yaml'), 'name: demo\n');
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmp } }];
    invalidateProjectRoot();
  });

  afterEach(() => {
    mockWorkspaceFolders.value = undefined;
    invalidateProjectRoot();
    clearTestConfig();
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('computes On, Off and which part is off', () => {
    assert.deepStrictEqual(computeLintsSwitchState(true, 'live'), { kind: 'on' });
    assert.deepStrictEqual(computeLintsSwitchState(false, 'disabled'), { kind: 'off' });
    assert.deepStrictEqual(computeLintsSwitchState(false, 'absent'), { kind: 'off' });
    assert.deepStrictEqual(computeLintsSwitchState(true, 'disabled', true), { kind: 'partial', off: 'plugin' });
    assert.deepStrictEqual(computeLintsSwitchState(true, 'absent'), { kind: 'partial', off: 'plugin' });
    assert.deepStrictEqual(computeLintsSwitchState(false, 'live'), { kind: 'partial', off: 'setting' });
  });

  it('default new project (sentinel block, no ownership) is On, not Partly off', () => {
    fs.writeFileSync(options, LIVE);
    disablePluginsIntegration(tmp); // sentinel block, no ownership record
    setTestConfig('saropaLints', 'enabled', true);
    assert.deepStrictEqual(getLintsSwitchState(tmp), { kind: 'on' });
    assert.deepStrictEqual(computeLintsSwitchState(true, 'disabled'), { kind: 'on' });
  });

  it('extension-disabled block is Partly off; both off is Off', async () => {
    fs.writeFileSync(options, LIVE);
    await runDisable(fakeContext()); // sets ownership sidecar + setting false
    setTestConfig('saropaLints', 'enabled', true);
    assert.deepStrictEqual(getLintsSwitchState(tmp), { kind: 'partial', off: 'plugin' });
    setTestConfig('saropaLints', 'enabled', false);
    assert.deepStrictEqual(getLintsSwitchState(tmp), { kind: 'off' });
  });

  it('turning On from the default state sets the setting without loading the plugin', async () => {
    fs.writeFileSync(options, LIVE);
    disablePluginsIntegration(tmp);
    setTestConfig('saropaLints', 'enabled', false);
    configUpdates.length = 0;
    await toggleLints(fakeContext());
    assert.ok(configUpdates.some((u) => u.key === 'enabled' && u.value === true));
    assert.ok(!/^plugins:/m.test(fs.readFileSync(options, 'utf-8')));
  });

  it('says Off in words when both switches are off (the silent case)', () => {
    fs.writeFileSync(options, LIVE);
    disablePluginsIntegration(tmp);
    setTestConfig('saropaLints', 'enabled', false);
    const state = getLintsSwitchState(tmp);
    assert.strictEqual(state.kind, 'off');
    assert.strictEqual(lintsSwitchLabel(state), l10n('lintsSwitch.statusOff'));
    assert.strictEqual(lintsSwitchDashboardMessage(state), l10n('lintsSwitch.dashboardOff'));
  });

  it('runReenablePlugin also sets saropaLints.enabled true', async () => {
    fs.writeFileSync(options, LIVE);
    await runDisable(fakeContext());
    configUpdates.length = 0;
    await runReenablePlugin(fakeContext());
    assert.ok(configUpdates.some((u) => u.key === 'enabled' && u.value === true));
    assert.ok(/^plugins:/m.test(fs.readFileSync(options, 'utf-8')));
  });

  it('runDisable sets saropaLints.enabled false', async () => {
    fs.writeFileSync(options, LIVE);
    await runDisable(fakeContext());
    assert.ok(configUpdates.some((u) => u.key === 'enabled' && u.value === false));
  });

  it('toggle from Partly off turns both on; from On turns both off', async () => {
    fs.writeFileSync(options, LIVE);
    const ctx = fakeContext();
    await runDisable(ctx);
    setTestConfig('saropaLints', 'enabled', true); // partly off: plugin
    configUpdates.length = 0;
    await toggleLints(ctx);
    assert.ok(configUpdates.some((u) => u.key === 'enabled' && u.value === true));
    assert.ok(/^plugins:/m.test(fs.readFileSync(options, 'utf-8')));

    setTestConfig('saropaLints', 'enabled', true); // now On
    configUpdates.length = 0;
    await toggleLints(ctx);
    assert.ok(configUpdates.some((u) => u.key === 'enabled' && u.value === false));
    assert.ok(!/^plugins:/m.test(fs.readFileSync(options, 'utf-8')));
  });

  it('detects version drift and syncs it, keeping quotes and the trailing comment', () => {
    fs.writeFileSync(options, LIVE);
    fs.writeFileSync(path.join(tmp, 'pubspec.lock'), LOCK);
    assert.deepStrictEqual(detectPluginVersionDrift(tmp), { configured: '17.0.0', pinned: '17.0.1-beta.2' });
    syncPluginVersionToPinned(tmp);
    assert.ok(fs.readFileSync(options, 'utf-8').includes('version: "17.0.1-beta.2"  # pinned'));
    assert.strictEqual(detectPluginVersionDrift(tmp), null);
  });

  it('reports no drift without a lock or for a range', () => {
    fs.writeFileSync(options, LIVE);
    assert.strictEqual(detectPluginVersionDrift(tmp), null);
    fs.writeFileSync(path.join(tmp, 'pubspec.lock'), LOCK);
    fs.writeFileSync(options, LIVE.replace('"17.0.0"', '"^17.0.0"'));
    assert.strictEqual(detectPluginVersionDrift(tmp), null);
  });
});
