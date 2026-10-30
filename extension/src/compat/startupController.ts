/**
 * Host side of start-up detection: runs `computeStartup` once per workspace
 * folder on activation and (debounced) when pubspec.lock, pubspec.yaml or
 * analysis_options.yaml change, and shows the single migration prompt.
 * Cached version list and cheap filters only: no solver probe here.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { getProjectRoot } from '../projectRoot';
import { readProjectFacts } from './projectFacts';
import { getPubVersions, type PubVersion, type PubVersionsCache } from './pubVersions';
import { VERSIONS_CACHE_KEY } from './upgradeGate';
import { computeStartup, detectState, dontAskKey, installedVersions, isSuppressed, offerMessage, type StartupOffer } from './startupDetection';
import { routeStatus } from './routeStatus';
import { loadRenames } from '../ruleMigration/registry';

const DISMISSED_KEY = 'saropaLints.startupDismissed';
const DEBOUNCE_MS = 1000;
/** Re-fetch the version list at most this often; otherwise use the cache. */
const FRESH_MS = 60 * 60 * 1000;
const MIGRATE_RULES_COMMAND = 'saropaLints.migrateRuleNames';

function roots(): string[] {
  const out = new Set<string>();
  for (const f of vscode.workspace.workspaceFolders ?? []) out.add(f.uri.fsPath);
  const primary = getProjectRoot();
  if (primary) out.add(primary);
  return [...out];
}

async function loadVersions(context: vscode.ExtensionContext): Promise<PubVersion[]> {
  const cached = context.globalState.get<PubVersionsCache>(VERSIONS_CACHE_KEY);
  if (cached && cached.versions.length > 0 && Date.now() - cached.fetchedAt < FRESH_MS) return cached.versions;
  try {
    const result = await getPubVersions({
      store: {
        get: () => context.globalState.get<PubVersionsCache>(VERSIONS_CACHE_KEY),
        set: (c) => context.globalState.update(VERSIONS_CACHE_KEY, c),
      },
    });
    return result.versions;
  } catch {
    return [];
  }
}

/**
 * Cheap rename count from the registry of the installed saropa_lints (the
 * offered version is not installed yet, so this is what is on disk now).
 * Undefined when no installed version ships the file.
 */
function renamedCount(dataRoot: string, from: string, to: string): number | undefined {
  const read = (file: string): string | undefined => {
    try {
      return fs.readFileSync(file, 'utf8');
    } catch {
      return undefined;
    }
  };
  const dartTool = path.join(dataRoot, '.dart_tool', 'package_config.json');
  if (read(dartTool) === undefined) return undefined;
  // loadRenames returns [] both for "no file" and "no matches"; probe the file via an unbounded load.
  const any = loadRenames({ read }, dataRoot, undefined, '999.0.0');
  if (any.length === 0) return undefined;
  return loadRenames({ read }, dataRoot, from, to).length;
}

let currentRouteStatus: { text: string; tooltip: string } | undefined;
let routeStatusListener: (() => void) | undefined;

/** Current route status ("saropa_lints: pubspec 17.0.1") for the single status bar item's tooltip. */
export function getRouteStatus(): { text: string; tooltip: string } | undefined {
  return currentRouteStatus;
}

/** Called whenever the route status changes, so the status bar item can re-render. */
export function onRouteStatusChange(listener: () => void): void {
  routeStatusListener = listener;
}

export function registerStartupDetection(
  context: vscode.ExtensionContext,
  log: (message: string) => void,
): void {
  // Offers already shown this session (any answer but Migrate): not re-toasted on file changes.
  const shownThisSession = new Set<string>();
  const running = new Set<string>();
  const timers = new Map<string, ReturnType<typeof setTimeout>>();

  // Persistent, quiet route status: no popup and no status bar item of its own;
  // the single Saropa status bar item shows it as a tooltip line.
  const statuses = new Map<string, { text: string; tooltip: string } | undefined>();
  const showStatus = () => {
    const primary = getProjectRoot();
    currentRouteStatus = (primary !== undefined && statuses.has(primary) ? statuses.get(primary) : undefined)
      ?? [...statuses.values()].find((v) => v !== undefined);
    routeStatusListener?.();
  };

  const check = async (root: string): Promise<void> => {
    if (running.has(root)) return;
    running.add(root);
    try {
      const facts = await readProjectFacts(root);
      const detected = detectState(facts);
      // A non-Dart folder with nothing configured gets no item.
      statuses.set(
        root,
        detected === 'neither' && !fs.existsSync(path.join(root, 'pubspec.yaml'))
          ? undefined
          : routeStatus(detected, installedVersions(facts), (k, p) => l10n(k, p)),
      );
      showStatus();
      if (!vscode.workspace.getConfiguration('saropaLints').get<boolean>('checkForUpdates', true)) return;
      const versions = await loadVersions(context);
      if (versions.length === 0) return;
      const { state, offer } = await computeStartup(facts, versions, (from, to) =>
        renamedCount(facts.workspaceRoot ?? root, from, to),
      );
      log(`[saropa] start-up detection (${root}): ${state}${offer ? `, offering ${offer.offered}` : ', no offer'}`);
      if (!offer) return;
      const key = dontAskKey(root, offer.route, offer.offered);
      if (shownThisSession.has(key)) return;
      if (isSuppressed(context.workspaceState.get<string[]>(DISMISSED_KEY), offer, root)) return;
      shownThisSession.add(key);
      await prompt(context, offer, key);
    } catch (err) {
      log(`[saropa] start-up detection failed (${root}): ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      running.delete(root);
    }
  };

  const schedule = (root: string) => {
    const t = timers.get(root);
    if (t) clearTimeout(t);
    timers.set(root, setTimeout(() => {
      timers.delete(root);
      void check(root);
    }, DEBOUNCE_MS));
  };

  const watched = new Map<string, vscode.Disposable>();
  const sync = () => {
    const wanted = new Set(roots());
    for (const [root, d] of watched) {
      if (!wanted.has(root)) {
        d.dispose();
        watched.delete(root);
      }
    }
    for (const root of wanted) {
      if (watched.has(root)) continue;
      const watchers = ['pubspec.lock', 'pubspec.yaml', 'analysis_options.yaml'].map((f) => {
        const w = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(root, f));
        w.onDidChange(() => schedule(root));
        w.onDidCreate(() => schedule(root));
        w.onDidDelete(() => schedule(root));
        return w;
      });
      watched.set(root, { dispose: () => watchers.forEach((w) => w.dispose()) });
      schedule(root);
    }
  };

  sync();
  context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(sync), {
    dispose: () => {
      for (const d of watched.values()) d.dispose();
      for (const t of timers.values()) clearTimeout(t);
    },
  });
}

async function prompt(context: vscode.ExtensionContext, offer: StartupOffer, key: string): Promise<void> {
  const migrate = l10n('compat.startup.actionMigrate');
  const notNow = l10n('notify.main.actionNotNow');
  const dontAsk = l10n('notify.misc.actionDontAskForVersion');
  const choice = await vscode.window.showInformationMessage(
    offerMessage(offer, (k, p) => l10n(k, p)),
    migrate,
    notNow,
    dontAsk,
  );
  if (choice === migrate) {
    await vscode.commands.executeCommand('saropaLints.configureCompatibility');
    // Another change adds the rename migration; degrade to the card alone when absent.
    if ((offer.renamedCount ?? 0) > 0 && (await vscode.commands.getCommands(true)).includes(MIGRATE_RULES_COMMAND)) {
      await vscode.commands.executeCommand(MIGRATE_RULES_COMMAND);
    }
  } else if (choice === dontAsk) {
    const list = context.workspaceState.get<string[]>(DISMISSED_KEY) ?? [];
    await context.workspaceState.update(DISMISSED_KEY, [...list, key]);
  }
}
