/**
 * VS Code surface for the accepted-findings list (`saropa_accepted.yaml`).
 *
 * - "Check Accepted Findings" runs `dart run saropa_lints:scan --check-accepted
 *   --format json` once per workspace folder and places stale / invalid
 *   entries as Problems on each list file (one per package). Reachable from the palette, the command catalog, and a toolbar
 *   button on the list file's editor title.
 * - "Accept in this file…" is a lightbulb action on any saropa_lints finding
 *   in a Dart file: it asks for a kind and a required reason, then appends
 *   one entry to the list beside the file's nearest `pubspec.yaml`. The list's parsing, matching and stale rules live once in
 *   Dart (`lib/src/accepted/`); this module only writes text and reads the
 *   CLI's JSON.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { runInWorkspaceAsync, getSharedOutputChannel } from './setup';
import { findProjectRootIn } from './projectRoot';
import { type CheckRun, planCheckRuns } from './acceptedCheckRoots';
import { hasSaropaLintsDep } from './pubspecReader';
import { l10n } from './i18n/runtime';
import { saropaLintsDataPath } from './reportsPaths';
import { createBusyGuard } from './commandGuards';
// Same "exit 1 means findings, not failure" convention as the stale-ignore CLI.
import { isExpectedNonZeroExit, summarizeError } from './stale-ignore-commands';
import {
  ACCEPTED_FILE_NAME,
  type AcceptedCheckResult,
  type AcceptedKind,
  type ListMarker,
  appendEntry,
  findPackageRoot,
  markersFromCheck,
  mergeCheckResults,
  parseAcceptedCheckJson,
  projectRelativePath,
  saropaRuleOf,
} from './acceptedFindingsModel';

/** Diagnostic source on the list file; distinct from rule findings. */
const DIAGNOSTIC_SOURCE = 'Saropa Lints (accepted findings)';

/** One check at a time per window: two scans on one root would race. */
const withBusyGuard = createBusyGuard(() => l10n('acceptedFindings.info.alreadyRunning'));

let _collection: vscode.DiagnosticCollection | undefined;

/** Lazily created collection holding markers on the list file. */
function getCollection(): vscode.DiagnosticCollection {
  _collection ??= vscode.languages.createDiagnosticCollection('saropaAcceptedFindings');
  return _collection;
}

/**
 * Registers both commands, the lightbulb provider, and a listener that clears
 * markers once the list is edited (their line numbers no longer hold). Returns
 * the collection so the caller disposes it with the extension.
 */
export function registerAcceptedFindingsCommands(
  context: vscode.ExtensionContext,
): vscode.DiagnosticCollection {
  const diags = getCollection();
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.checkAcceptedFindings', () => runCheck()),
    vscode.commands.registerCommand(
      'saropaLints.acceptFindingInFile',
      (uri?: vscode.Uri, rule?: string) => runAccept(uri, rule),
    ),
    vscode.languages.registerCodeActionsProvider(
      { language: 'dart' },
      new AcceptFindingCodeActionProvider(),
      { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
    ),
    vscode.workspace.onDidChangeTextDocument((e) => {
      // Stale markers point at lines that may have moved; drop them and let
      // the next check place fresh ones rather than show misleading lines.
      if (path.basename(e.document.uri.fsPath) === ACCEPTED_FILE_NAME) {
        diags.delete(e.document.uri);
      }
    }),
  );
  return diags;
}

// ── Check ────────────────────────────────────────────────────────────────────

/** Runs the CLI check, publishes markers, and reports the outcome. */
async function runCheck(): Promise<void> {
  await withBusyGuard(async () => {
    const runs = checkRunsOrError();
    if (!runs) return;
    const results: AcceptedCheckResult[] = [];
    // Sequential, not parallel: each run is a full resolved scan, and two at
    // once would double memory beside the analysis server.
    for (const run of runs) {
      const one = await runCheckScan(run);
      if (one === null) return; // Cancelled, or the error was already shown.
      results.push(one);
    }
    const result = mergeCheckResults(results);

    // Replace every marker: a list deleted or fixed since the last check
    // must not keep markers from it.
    const collection = getCollection();
    collection.clear();
    for (const list of result.lists) {
      collection.set(vscode.Uri.file(list.listPath), markersFromCheck(list).map(toDiagnostic));
    }

    if (result.lists.length === 0) {
      void vscode.window.showInformationMessage(l10n('acceptedFindings.info.noList'));
      return;
    }
    const { entryCount, stale, problemCount } = result.summary;
    if (stale === 0 && problemCount === 0) {
      void vscode.window.showInformationMessage(
        l10n('acceptedFindings.info.clean', { count: String(entryCount) }),
      );
      return;
    }
    const open = l10n('acceptedFindings.action.openList');
    const choice = await vscode.window.showWarningMessage(
      l10n('acceptedFindings.info.issues', {
        stale: String(stale),
        invalid: String(problemCount),
        count: String(entryCount),
      }),
      open,
    );
    // Open the first list that needs attention; the Problems panel lists
    // the rest.
    const first = result.lists.find((l) => l.summary.stale > 0 || l.summary.problemCount > 0);
    if (choice === open && first) await vscode.window.showTextDocument(vscode.Uri.file(first.listPath));
  });
}

/**
 * The CLI runs for this window (see `planCheckRuns`): every workspace
 * folder's package root, found at the folder or one level down. A root that
 * depends on saropa_lints runs the CLI itself; one that only uses the plugin
 * (a list, or the plugin in its analysis options) is checked by launching the
 * CLI from the first root that has the package. The CLI checks every list
 * under each target, so nested packages are covered by their enclosing
 * folder. Shows an error and returns null when there is nothing to run.
 */
function checkRunsOrError(): CheckRun[] | null {
  const folders = vscode.workspace.workspaceFolders?.map((f) => f.uri.fsPath) ?? [];
  if (folders.length === 0) {
    void vscode.window.showErrorMessage(l10n('acceptedFindings.error.noWorkspace'));
    return null;
  }
  const runs = planCheckRuns(folders, {
    projectRootIn: findProjectRootIn,
    hasDep: hasSaropaLintsDep,
    exists: fs.existsSync,
    read: (f) => {
      try {
        return fs.readFileSync(f, 'utf-8');
      } catch {
        return undefined;
      }
    },
  });
  if (runs.length === 0) {
    void vscode.window.showErrorMessage(l10n('acceptedFindings.error.missingDep'));
    return null;
  }
  return runs;
}

/**
 * Spawns the scan CLI from `run.host` against `run.target` and reads its
 * JSON file. Null on cancel or failure. The JSON goes under the target's own
 * reports folder so two runs sharing a host do not overwrite each other.
 */
async function runCheckScan(run: CheckRun): Promise<AcceptedCheckResult | null> {
  const { host, target } = run;
  const jsonPath = path.join(saropaLintsDataPath(target), 'accepted_findings.json');
  // A project that never ran a scan has no reports dir; the CLI would ENOENT.
  fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
  // Drop the previous run's output: a run that fails with a quiet exit 1/2
  // writes nothing, and the old file would be reported as the current result.
  fs.rmSync(jsonPath, { force: true });
  const result = await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: l10n('acceptedFindings.progress.checking'),
      cancellable: true,
    },
    (_progress, token) =>
      // shell: false and no analytics, same as the stale-ignore scan: keeps
      // the child process tree flat beside the Flutter daemon.
      runInWorkspaceAsync(
        host,
        'dart',
        ['run', 'saropa_lints:scan', target, '--check-accepted', '--format', 'json', '--json-file-path', jsonPath, '-q'],
        { logToOutput: true, token, shell: false, env: { DART_SUPPRESS_ANALYTICS: 'true' } },
      ),
  );
  if (result.cancelled) return null;
  // Exit 1 means "stale or invalid entries", which is a result, not a failure.
  if (!result.ok && !isExpectedNonZeroExit(result.stderr)) {
    return showCheckError(summarizeError(result.stderr));
  }
  let raw: string;
  try {
    raw = fs.readFileSync(jsonPath, 'utf-8');
  } catch (err) {
    return showCheckError(err instanceof Error ? err.message : String(err));
  }
  // A malformed file is an error, never "clean": the gate must not pass on
  // output it could not read.
  return parseAcceptedCheckJson(raw) ?? showCheckError(l10n('acceptedFindings.error.badOutput'));
}

/** Shows the failure, reveals the Output channel, and returns null. */
function showCheckError(message: string): null {
  void vscode.window.showErrorMessage(l10n('acceptedFindings.error.checkFailed', { message }));
  getSharedOutputChannel().show(true);
  return null;
}

/** Localized Problems entry for one marker. */
function toDiagnostic(m: ListMarker): vscode.Diagnostic {
  // Literal keys (no template string) so the dead-key and missing-key
  // checkers can see every key this module uses.
  const params = { rule: m.rule ?? '', file: m.file ?? '' };
  const message = m.kind === 'invalid'
    ? l10n('acceptedFindings.diagnostic.invalid', { message: m.message ?? '' })
    : m.kind === 'staleFileMissing'
      ? l10n('acceptedFindings.diagnostic.staleFileMissing', params)
      : l10n('acceptedFindings.diagnostic.staleNoFinding', params);
  const d = new vscode.Diagnostic(
    new vscode.Range(m.line, 0, m.line, Number.MAX_SAFE_INTEGER),
    message,
    m.severity === 'error' ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning,
  );
  d.source = DIAGNOSTIC_SOURCE;
  return d;
}

// ── Accept in this file ──────────────────────────────────────────────────────

/**
 * Prompts for kind and reason, then appends one entry. Each early exit shows
 * a message so no invocation ends silently.
 */
async function runAccept(uri: vscode.Uri | undefined, rule: string | undefined): Promise<void> {
  // The palette passes no arguments; the action only works from a finding.
  if (!uri || !rule) {
    void vscode.window.showInformationMessage(l10n('acceptedFindings.error.noFinding'));
    return;
  }
  // The list beside the file's nearest pubspec.yaml, the one the analyzer
  // plugin and the CLI read for this file. The workspace's project root
  // (getProjectRoot) was used before, which for a file in a nested package
  // or a second workspace folder wrote an entry no producer applies. No
  // saropa_lints dependency check here: the finding under the cursor already
  // proves the plugin analyzes this package.
  const root = findPackageRoot(uri.fsPath, fs.existsSync);
  const file = root ? projectRelativePath(root, uri.fsPath) : undefined;
  if (!root || !file) {
    void vscode.window.showErrorMessage(l10n('acceptedFindings.error.outsideProject'));
    return;
  }
  const kind = await pickKind();
  if (!kind) return; // Escape is the user's explicit choice; nothing to report.
  const reason = await vscode.window.showInputBox({
    title: l10n('acceptedFindings.prompt.reasonTitle', { rule, file }),
    placeHolder: l10n('acceptedFindings.prompt.reasonPlaceholder'),
    ignoreFocusOut: true,
    // The Dart parser rejects an entry without a reason; refusing here keeps
    // the user from writing an entry that silently hides nothing.
    validateInput: (v) => (v.trim() ? undefined : l10n('acceptedFindings.prompt.reasonRequired')),
  });
  if (reason === undefined) return;
  await writeEntry(root, { rule, file, kind, reason: reason.trim() });
}

/** Kind picker; undefined when dismissed. */
async function pickKind(): Promise<AcceptedKind | undefined> {
  // `value`, not `kind`: QuickPickItem already defines `kind` (separator).
  const items: (vscode.QuickPickItem & { value: AcceptedKind })[] = [
    { label: l10n('acceptedFindings.prompt.kindAccepted'), value: 'accepted' },
    { label: l10n('acceptedFindings.prompt.kindFalsePositive'), value: 'false_positive' },
  ];
  const picked = await vscode.window.showQuickPick(items, {
    title: l10n('acceptedFindings.prompt.kindTitle'),
    ignoreFocusOut: true,
  });
  return picked?.value;
}

/** Appends the entry to the list file and reports the outcome. */
async function writeEntry(
  root: string,
  entry: { rule: string; file: string; kind: AcceptedKind; reason: string },
): Promise<void> {
  const listPath = path.join(root, ACCEPTED_FILE_NAME);
  const listUri = vscode.Uri.file(listPath);
  try {
    const existing = fs.existsSync(listPath) ? fs.readFileSync(listPath, 'utf-8') : undefined;
    const next = appendEntry(existing, entry);
    if (next === null) {
      // A layout the appender cannot extend without rewriting other lines.
      void vscode.window.showWarningMessage(l10n('acceptedFindings.error.cannotAppend'));
      await vscode.window.showTextDocument(listUri);
      return;
    }
    fs.writeFileSync(listPath, next, 'utf-8');
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    void vscode.window.showErrorMessage(l10n('acceptedFindings.error.writeFailed', { message }));
    return;
  }
  // The analyzer plugin re-reads the list within seconds, but findings
  // already in the Problems panel only refresh when the file is analyzed
  // again; say so, and offer the restart that forces it.
  const restart = l10n('acceptedFindings.action.restartAnalysis');
  const open = l10n('acceptedFindings.action.openList');
  const choice = await vscode.window.showInformationMessage(
    // Name the list written: with one list per package, which file received
    // the entry is no longer obvious.
    l10n('acceptedFindings.info.added', {
      rule: entry.rule,
      file: entry.file,
      list: vscode.workspace.asRelativePath(listPath),
    }),
    restart,
    open,
  );
  if (choice === restart) await vscode.commands.executeCommand('dart.restartAnalysisServer');
  if (choice === open) await vscode.window.showTextDocument(listUri);
}

/**
 * Offers "Accept <rule> in this file…" once per distinct saropa rule among the
 * diagnostics under the cursor. Never preferred: accepting is a reviewed
 * decision, not the default fix.
 */
export class AcceptFindingCodeActionProvider implements vscode.CodeActionProvider {
  provideCodeActions(
    document: vscode.TextDocument,
    _range: vscode.Range,
    context: vscode.CodeActionContext,
  ): vscode.CodeAction[] {
    const byRule = new Map<string, vscode.Diagnostic[]>();
    for (const d of context.diagnostics) {
      const rule = saropaRuleOf(d.message, d.code);
      if (rule) byRule.set(rule, [...(byRule.get(rule) ?? []), d]);
    }
    return [...byRule.entries()].map(([rule, diagnostics]) => {
      const title = l10n('acceptedFindings.quickFix.title', { rule });
      const action = new vscode.CodeAction(title, vscode.CodeActionKind.QuickFix);
      action.diagnostics = diagnostics;
      action.command = { command: 'saropaLints.acceptFindingInFile', title, arguments: [document.uri, rule] };
      return action;
    });
  }
}
