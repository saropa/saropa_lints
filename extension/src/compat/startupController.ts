/**
 * Host side of start-up detection: runs `computeStartup` once per workspace
 * folder on activation and (debounced) when pubspec.lock, pubspec.yaml or
 * analysis_options.yaml change, and shows the single migration prompt.
 * Cached version list and cheap filters only: no solver probe here.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { getProjectRoot } from '../projectRoot';
import { readProjectFacts } from './projectFacts';
import { getPubVersions, type PubVersion, type PubVersionsCache } from './pubVersions';
import { VERSIONS_CACHE_KEY } from './upgradeGate';
import { computeStartup, dontAskKey, isSuppressed, offerMessage, type StartupOffer } from './startupDetection';

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

export function registerStartupDetection(
  context: vscode.ExtensionContext,
  log: (message: string) => void,
): void {
  // Offers already shown this session (any answer but Migrate): not re-toasted on file changes.
  const shownThisSession = new Set<string>();
  const running = new Set<string>();
  const timers = new Map<string, ReturnType<typeof setTimeout>>();

  const check = async (root: string): Promise<void> => {
    if (running.has(root)) return;
    if (!vscode.workspace.getConfiguration('saropaLints').get<boolean>('checkForUpdates', true)) return;
    running.add(root);
    try {
      const versions = await loadVersions(context);
      if (versions.length === 0) return;
      const facts = await readProjectFacts(root);
      // The renamed-rule data source lands with saropaLints.migrateRuleNames; none yet.
      const { state, offer } = await computeStartup(facts, versions);
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
    if (offer.renamedCount > 0 && (await vscode.commands.getCommands(true)).includes(MIGRATE_RULES_COMMAND)) {
      await vscode.commands.executeCommand(MIGRATE_RULES_COMMAND);
    }
  } else if (choice === dontAsk) {
    const list = context.workspaceState.get<string[]>(DISMISSED_KEY) ?? [];
    await context.workspaceState.update(DISMISSED_KEY, [...list, key]);
  }
}
