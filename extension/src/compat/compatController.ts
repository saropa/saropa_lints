/**
 * Host-side glue for the version-compatibility feature: gathers facts and the
 * recommendation (solver probe only when asked, cached by solverProbe), builds
 * the card state, previews diffs, and runs Apply with real dependencies.
 */
import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { l10n } from '../i18n/runtime';
import { resolveDependencies } from '../setup';
import { showAnalyzerExcludeDiff } from '../analysisOptimizer/analyzerExcludeDiffProvider';
import { readProjectFacts, resolveDataRoot } from './projectFacts';
import { getPubVersions, type PubVersionsCache } from './pubVersions';
import { probeConstraint } from './solverProbe';
import { recommend, sameRecommendation, type Recommendation } from './recommend';
import { atomicWrite } from './atomicWrite';
import { applyCompatibility, planEdits, type ApplyDeps, type ApplyOutcome, type ApplyPaths } from './applyCompat';
import { offerableVersion, VERSIONS_CACHE_KEY } from './upgradeGate';
import type { CompatCardState } from './compatCardHtml';
import type { ProjectFacts } from './projectFacts';

export interface CompatSnapshot {
  facts: ProjectFacts;
  rec: Recommendation;
}

function store(context: vscode.ExtensionContext) {
  return {
    get: () => context.globalState.get<PubVersionsCache>(VERSIONS_CACHE_KEY),
    set: (c: PubVersionsCache) => context.globalState.update(VERSIONS_CACHE_KEY, c),
  };
}

export function pathsFor(root: string): ApplyPaths {
  return {
    pubspec: path.join(root, 'pubspec.yaml'),
    analysisOptions: path.join(root, 'analysis_options.yaml'),
    // Pub workspace members keep the lock at the workspace root.
    lock: path.join(resolveDataRoot(root), 'pubspec.lock'),
  };
}

const fsRead = (file: string): string | undefined => {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return undefined;
  }
};

/** Facts + recommendation. `probe` runs the pub solver (on demand only). */
export async function computeCompat(
  context: vscode.ExtensionContext,
  root: string,
  probe: boolean,
): Promise<CompatSnapshot> {
  const [facts, versions] = await Promise.all([
    readProjectFacts(root),
    getPubVersions({ store: store(context) }),
  ]);
  const rec = await recommend(
    facts,
    versions.versions,
    probe ? (c) => probeConstraint(root, c) : undefined,
    { stale: versions.stale },
  );
  return { facts, rec };
}

/** Card state for the Health Panel (probe-backed: called on card open). */
export async function loadCompatState(
  context: vscode.ExtensionContext,
  root: string,
): Promise<CompatCardState> {
  try {
    const { facts, rec } = await computeCompat(context, root, true);
    const hasEdits = planEdits({ read: fsRead }, pathsFor(root), rec).length > 0;
    return { facts, rec, hasEdits };
  } catch (err) {
    return { error: l10n('compat.card.loadFailed', { detail: err instanceof Error ? err.message : String(err) }) };
  }
}

/**
 * The version the upgrade toast may offer, from the cached version list and
 * the cheap filters only (no solver). Undefined: stay silent.
 */
export async function offeredVersion(
  context: vscode.ExtensionContext,
  root: string,
  installed: string,
): Promise<string | undefined> {
  const cached = context.globalState.get<PubVersionsCache>(VERSIONS_CACHE_KEY);
  if (!cached || cached.versions.length === 0) return undefined;
  const facts = await readProjectFacts(root);
  const rec = await recommend(facts, cached.versions);
  return offerableVersion(rec, installed);
}

export async function previewCompat(root: string, rec: Recommendation): Promise<void> {
  for (const e of planEdits({ read: fsRead }, pathsFor(root), rec)) {
    await showAnalyzerExcludeDiff(e.file, e.after, l10n('compat.card.diffTitle', { file: path.basename(e.file) }));
  }
}

/** Apply with real dependencies; no UI. */
export function applyCompatNow(
  root: string,
  rec: Recommendation,
  token: vscode.CancellationToken,
  progress?: vscode.Progress<{ message?: string }>,
): Promise<ApplyOutcome> {
  const deps: ApplyDeps = {
    read: fsRead,
    write: atomicWrite,
    resolve: async () => {
      const r = await resolveDependencies(root, token, progress);
      return { ok: r.ok, stderr: r.stderr, cancelled: r.cancelled };
    },
    readLockedVersion: async () => (await readProjectFacts(root)).locked.saropaLints?.version,
    initializeConfig: async () => {
      await vscode.commands.executeCommand('saropaLints.initializeConfig');
    },
  };
  return applyCompatibility(deps, pathsFor(root), rec);
}

/** Plain-language result for an outcome; `isError` true when the user must act. */
export function describeOutcome(o: ApplyOutcome): { text: string; isError: boolean } {
  switch (o.status) {
    case 'noChange':
      return { text: l10n('compat.apply.noChange'), isError: false };
    case 'applied':
      return { text: l10n('compat.apply.applied', { version: o.version ?? '' }), isError: false };
    case 'cancelled':
      return { text: l10n(o.restored ? 'compat.apply.cancelledRestored' : 'compat.apply.cancelledNotRestored'), isError: true };
    case 'failed':
      return {
        text: l10n(o.restored ? 'compat.apply.failedRestored' : 'compat.apply.failedNotRestored', {
          detail: o.reason || l10n('notify.misc.upgradeCheckerCheckOutput'),
        }),
        isError: true,
      };
  }
}

/** Apply under a progress notification and tell the user the result. */
export async function applyCompatWithUi(root: string, rec: Recommendation): Promise<ApplyOutcome> {
  const outcome = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('compat.apply.progress'),
      cancellable: true,
    },
    (progress, token) => applyCompatNow(root, rec, token, progress),
  );
  const { text, isError } = describeOutcome(outcome);
  if (isError) void vscode.window.showErrorMessage(text);
  else void vscode.window.showInformationMessage(text);
  return outcome;
}
