/**
 * Host glue for the rule-rename migration: scans the workspace's package
 * roots, previews diffs, applies with snapshot/restore, reports the result.
 * Pure parts live in report.ts, scanner.ts, applyMigration.ts.
 */
import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { l10n } from '../i18n/runtime';
import { showAnalyzerExcludeDiff } from '../analysisOptimizer/analyzerExcludeDiffProvider';
import { atomicWrite } from '../compat/atomicWrite';
import { readProjectFacts, resolveDataRoot } from '../compat/projectFacts';
import { getWorkspaceRoot } from '../projectRoot';
import { applyRuleMigration, type MigrationReport } from './applyMigration';
import { loadRenames } from './registry';
import { listSome, reportParts, selectChanges, summarizeScan } from './report';
import { buildRenameMap } from './rewriters';
import { packageRoots, scanWorkspace, type FileChange, type PackageScan, type ScanResult } from './scanner';

const fsRead = (file: string): string | undefined => {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return undefined;
  }
};

/** Scan every package root against the registry shipped with its installed saropa_lints. */
export async function scanForRenames(workspaceRoot: string): Promise<ScanResult> {
  const packages: PackageScan[] = [];
  for (const root of packageRoots(workspaceRoot)) {
    const installed = (await readProjectFacts(root)).locked.saropaLints?.version;
    if (!installed) continue;
    const entries = loadRenames({ read: fsRead }, resolveDataRoot(root), undefined, installed);
    if (entries.length > 0) packages.push({ root, renames: buildRenameMap(entries) });
  }
  return scanWorkspace(
    {
      read: fsRead,
      findFiles: async (root, glob, exclude) =>
        (await vscode.workspace.findFiles(new vscode.RelativePattern(root, glob), exclude)).map((u) => u.fsPath),
    },
    packages,
  );
}

async function previewDiffs(changes: readonly FileChange[]): Promise<void> {
  for (const c of changes) {
    await showAnalyzerExcludeDiff(c.file, c.after, l10n('ruleMigration.diffTitle', { file: path.basename(c.file) }));
  }
}

function showReport(r: MigrationReport, root: string): void {
  const rel = (f: string): string => path.relative(root, f) || path.basename(f);
  const p = reportParts(r, rel);
  if (r.status === 'failed') {
    void vscode.window.showErrorMessage(
      l10n(r.restored ? 'ruleMigration.failedRestored' : 'ruleMigration.failedNotRestored', { detail: r.reason ?? '' }),
    );
    return;
  }
  const lines: string[] = [
    r.status === 'applied'
      ? l10n('ruleMigration.applied', { hits: r.hits, count: p.changedFiles.length, files: listSome(p.changedFiles) })
      : l10n('ruleMigration.none'),
  ];
  if (p.bareNames.length) lines.push(l10n('ruleMigration.bareNames', { items: listSome(p.bareNames) }));
  if (p.clashes.length) lines.push(l10n('ruleMigration.clashes', { items: listSome(p.clashes) }));
  if (p.skipped.length) lines.push(l10n('ruleMigration.skipped', { items: listSome(p.skipped) }));
  void vscode.window.showInformationMessage(lines.join(' '));
}

async function applyAndReport(root: string, scan: ScanResult, changes: readonly FileChange[]): Promise<void> {
  const report = await vscode.window.withProgress(
    { location: vscode.ProgressLocation.Notification, title: l10n('ruleMigration.progress') },
    () =>
      applyRuleMigration(
        {
          write: atomicWrite,
          initializeConfig: async () => {
            await vscode.commands.executeCommand('saropaLints.initializeConfig');
          },
        },
        changes,
        scan.skipped,
      ),
  );
  showReport(report, root);
}

/** Command `saropaLints.migrateRuleNames`: pick files, preview diffs, confirm, apply. */
export async function runMigrateRuleNames(): Promise<void> {
  const root = getWorkspaceRoot();
  if (!root) {
    void vscode.window.showInformationMessage(l10n('ruleMigration.noWorkspace'));
    return;
  }
  const scan = await scanForRenames(root);
  const summary = summarizeScan(scan);
  if (summary.files.length === 0) {
    // Findings-only files (bare names, clashes) still deserve a report.
    if (scan.changes.length > 0) await applyAndReport(root, scan, scan.changes);
    else void vscode.window.showInformationMessage(l10n('ruleMigration.none'));
    return;
  }
  const picks = await vscode.window.showQuickPick(
    summary.files.map((f) => ({
      label: path.relative(root, f.file) || path.basename(f.file),
      description: l10n('ruleMigration.fileHits', { hits: f.hits }),
      file: f.file,
      picked: true,
    })),
    { canPickMany: true, title: l10n('ruleMigration.pickTitle'), placeHolder: l10n('ruleMigration.pickPlaceholder') },
  );
  if (!picks || picks.length === 0) return;
  const chosen = selectChanges(scan.changes, new Set(picks.map((p) => p.file)));
  await previewDiffs(chosen);
  const apply = l10n('ruleMigration.apply');
  const answer = await vscode.window.showInformationMessage(
    l10n('ruleMigration.confirm', { count: picks.length }),
    { modal: true },
    apply,
  );
  if (answer === apply) await applyAndReport(root, scan, chosen);
}

/** After a successful compat Apply: offer the rename migration once if renamed rules are in use. */
export async function offerRenameMigration(): Promise<void> {
  const root = getWorkspaceRoot();
  if (!root) return;
  let scan: ScanResult;
  try {
    scan = await scanForRenames(root);
  } catch {
    return; // best effort: the compat Apply already succeeded
  }
  const summary = summarizeScan(scan);
  if (summary.files.length === 0) return;
  const preview = l10n('ruleMigration.offerPreview');
  const apply = l10n('ruleMigration.apply');
  const answer = await vscode.window.showInformationMessage(
    l10n('ruleMigration.offer', { hits: summary.hits, count: summary.files.length }),
    preview,
    apply,
    l10n('ruleMigration.offerNotNow'),
  );
  if (answer === preview) await runMigrateRuleNames();
  else if (answer === apply) await applyAndReport(root, scan, scan.changes);
}
