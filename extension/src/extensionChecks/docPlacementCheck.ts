/**
 * Extension-native check: flags a markdown file whose path matches the
 * configured "archive/history" glob but whose own content still reads as
 * open, unresolved work (an open `Status:`/`Severity:` field, or an
 * unaddressed action-items heading) with no closing signal overriding it.
 *
 * Mirror image of `bugArchivalCheck.ts` (which flags a *closed* report left
 * in `bugs/` instead of being archived). See
 * `bugs/proposal_infra_doc_history_vs_bugs_placement.md` for the design and
 * `bugs/ISSUE_REPORT_GUIDE.md`'s "Rule Sources" section for why this lives
 * here rather than as a Dart AST rule: detecting it needs full markdown
 * content plus which directory the file landed in, neither of which the
 * Dart analyzer ever sees.
 *
 * Neither `markdownUtils.ts` (MarkdownString escaping only) nor
 * `pathUtils.ts` (path normalization + fs-exists cache) has structural
 * markdown parsing or glob matching, and there's no glob-matching dependency
 * in this package — `globToRegExp` below is a small, purpose-built matcher
 * (`**`/`*` only, no brace/bracket expansion) rather than a dependency for
 * one setting.
 */
import * as path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { ARCHIVE_DIR, OPEN_ISSUES_DIR } from './docConventions';

const execFileAsync = promisify(execFile);

const CONFIG_SECTION = 'saropaLints.docPlacement';

/** Diagnostic `code` used to scope the quick fix to this check's own diagnostics. */
const DIAGNOSTIC_CODE = 'docPlacement';

/** Command id for the "move to open-issues directory" quick fix. */
const MOVE_COMMAND = 'saropaLints.docPlacement.moveToOpenIssues';

/**
 * Default glob for the "closed/archive" directory convention. Matches this
 * repo's own convention (`plans/history/YYYY.MM/YYYYMMDD/*.md`, per
 * ISSUE_REPORT_GUIDE.md and `bugArchivalCheck.ts`'s archive target) so the
 * check fires out of the box here, not just for workspaces that opt in with
 * an override. Built from the shared `ARCHIVE_DIR` constant so it can't
 * silently drift out of sync with `bugArchivalCheck.ts`'s archive target.
 */
const DEFAULT_ARCHIVE_GLOB = `**/${ARCHIVE_DIR}/**/*.md`;

/** Default directory suggested in the diagnostic message. */
const DEFAULT_OPEN_ISSUES_DIR = `${OPEN_ISSUES_DIR}/`;

/**
 * Default "still open" signal patterns. Each is matched with the `m` flag
 * against the whole document text. Kept anchored to structural positions
 * (a field line, a table cell, or a heading) rather than bare substrings,
 * so prose mentioning "critical" or "open" in passing never fires — see
 * Edge Case 2 in the proposal doc. The extra `\*{0,2}` after the field's
 * colon AND before its value absorbs every bold style this repo's own docs
 * use — `**Status: Fixed**` (bold wraps the whole field), `**Status:**
 * Fixed` (bold wraps only the label), and `Severity: **Critical**` (bold
 * wraps only the value).
 */
const DEFAULT_OPEN_SIGNALS = [
  String.raw`^\*{0,2}Status:\*{0,2}\s*\*{0,2}Open\*{0,2}\s*$`,
  String.raw`^\*{0,2}Severity:\*{0,2}\s*\*{0,2}(Critical|High|Major)\*{0,2}\s*$`,
  String.raw`\|\s*(Critical|High|Major)\s*\|`,
  String.raw`^#{1,6}\s*(Recommended [Nn]ext [Ss]teps|Work [Ss]till to [Dd]o|TODO|Open [Ii]tems)\s*$`,
];

/**
 * Default "closed" signals that override the open signals above — teams
 * often update just the status line in place rather than rewriting an
 * entire findings section (Edge Case 3 in the proposal doc).
 */
const DEFAULT_CLOSED_SIGNALS = [
  String.raw`^\*{0,2}Status:\*{0,2}\s*\*{0,2}(Fixed|Closed|Done)\*{0,2}\s*$`,
];

/** Setting keys relative to `CONFIG_SECTION`. */
const CONFIG_SECTION_KEY = {
  enabled: 'enabled',
  archiveGlob: 'archiveGlob',
  openIssuesDir: 'openIssuesDir',
  openSignals: 'openSignals',
  closedSignals: 'closedSignals',
} as const;

let _collection: vscode.DiagnosticCollection | undefined;

/** Reads one setting under `saropaLints.docPlacement`. */
function getSetting<T>(key: string, fallback: T): T {
  return vscode.workspace.getConfiguration(CONFIG_SECTION).get<T>(key, fallback);
}

/**
 * Converts a glob pattern to a RegExp. Supports `**` (any path segment
 * span, including `/`) and `*` (any span within one segment); every other
 * character is escaped literally. Deliberately minimal — no brace
 * expansion, no character classes — sufficient for the archive-directory
 * globs this setting is meant to hold (e.g. the default archive glob).
 *
 * The whole pattern is anchored (`^...$`) against the full path — there is
 * no implicit `**` prefix/suffix, so a bare `notes.md` matches only a file
 * whose entire path is exactly that (never as a "somewhere under this
 * name" shorthand). A pattern meant to match at any depth needs an
 * explicit leading `**\/`, same as the default archive glob.
 */
export function globToRegExp(glob: string): RegExp {
  let out = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*' && glob[i + 1] === '*') {
      out += '.*';
      i++;
      // Absorb a following '/' so '**/x' also matches 'x' with nothing before it.
      if (glob[i + 1] === '/') i++;
    } else if (c === '*') {
      out += '[^/]*';
    } else if ('.+^${}()|[]\\'.includes(c)) {
      out += '\\' + c;
    } else {
      out += c;
    }
  }
  return new RegExp('^' + out + '$');
}

/** True when the (forward-slash-normalized) path matches the archive glob. */
export function matchesArchiveGlob(fsPath: string, archiveGlob: string): boolean {
  const normalized = fsPath.replaceAll('\\', '/');
  try {
    return globToRegExp(archiveGlob).test(normalized);
  } catch {
    return false;
  }
}

/**
 * Compiles a list of regex source strings, skipping ones a user mistyped
 * rather than breaking the whole check. A skip is logged via
 * `console.warn` (visible in the extension host's Output/Dev Tools) so a
 * bad pattern doesn't fail silently forever — there is no settings-schema
 * validation for regex strings in `package.json`.
 */
function compilePatterns(sources: string[]): RegExp[] {
  const compiled: RegExp[] = [];
  for (const source of sources) {
    try {
      compiled.push(new RegExp(source, 'm'));
    } catch (err) {
      console.warn(`[Saropa Lints] docPlacement: invalid regex "${source}" — ${String(err)}`);
    }
  }
  return compiled;
}

/**
 * Pure check: given a document's text and the configured signal lists,
 * returns the diagnostic to publish (an open signal fired, with no closed
 * signal overriding it) or `null`. Separated from `validateDocument` so it
 * can be unit tested without a full VS Code document mock.
 */
export function computeDocPlacementDiagnostic(
  text: string,
  openSignalSources: string[],
  closedSignalSources: string[],
  openIssuesDir: string,
): vscode.Diagnostic | null {
  const closedSignals = compilePatterns(closedSignalSources);
  if (closedSignals.some((pattern) => pattern.test(text))) return null;

  const openSignals = compilePatterns(openSignalSources);
  if (!openSignals.some((pattern) => pattern.test(text))) return null;

  // The defect is the file's *location*, not any single line of body content — always line 1.
  const range = new vscode.Range(0, 0, 0, Number.MAX_SAFE_INTEGER);
  const diag = new vscode.Diagnostic(
    range,
    l10n('docPlacement.diagnostic.message', { openIssuesDir }),
    vscode.DiagnosticSeverity.Information,
  );
  diag.source = 'Saropa Lints';
  diag.code = DIAGNOSTIC_CODE;
  return diag;
}

/** Scans one document for an archive-path placement issue and publishes/clears its diagnostic. */
function validateDocument(doc: vscode.TextDocument): void {
  if (!_collection || doc.languageId !== 'markdown') return;

  if (!getSetting(CONFIG_SECTION_KEY.enabled, true)) {
    _collection.set(doc.uri, []);
    return;
  }

  const archiveGlob = getSetting(CONFIG_SECTION_KEY.archiveGlob, DEFAULT_ARCHIVE_GLOB);
  if (!matchesArchiveGlob(doc.uri.fsPath, archiveGlob)) {
    _collection.set(doc.uri, []);
    return;
  }

  const openSignals = getSetting(CONFIG_SECTION_KEY.openSignals, DEFAULT_OPEN_SIGNALS);
  const closedSignals = getSetting(CONFIG_SECTION_KEY.closedSignals, DEFAULT_CLOSED_SIGNALS);
  const openIssuesDir = getSetting(CONFIG_SECTION_KEY.openIssuesDir, DEFAULT_OPEN_ISSUES_DIR);

  const diag = computeDocPlacementDiagnostic(doc.getText(), openSignals, closedSignals, openIssuesDir);
  _collection.set(doc.uri, diag ? [diag] : []);
}

/**
 * Quick fix offered on this check's own diagnostics (scoped via `code`,
 * not `source` — `source: 'Saropa Lints'` is shared by every check in this
 * extension, so filtering on it alone would also surface this fix for
 * unrelated diagnostics). Delegates the actual move to `MOVE_COMMAND`
 * rather than editing text, since moving a file is a workspace-fs
 * operation, not a text edit.
 */
export class DocPlacementCodeActionProvider implements vscode.CodeActionProvider {
  provideCodeActions(
    document: vscode.TextDocument,
    _range: vscode.Range,
    context: vscode.CodeActionContext,
  ): vscode.CodeAction[] {
    const diags = context.diagnostics.filter((d) => d.code === DIAGNOSTIC_CODE);
    if (diags.length === 0) return [];

    const openIssuesDir = getSetting(CONFIG_SECTION_KEY.openIssuesDir, DEFAULT_OPEN_ISSUES_DIR);
    const action = new vscode.CodeAction(
      l10n('docPlacement.quickFix.title', { openIssuesDir }),
      vscode.CodeActionKind.QuickFix,
    );
    action.diagnostics = diags;
    action.isPreferred = true;
    action.command = {
      command: MOVE_COMMAND,
      title: l10n('docPlacement.quickFix.title', { openIssuesDir }),
      arguments: [document.uri, openIssuesDir],
    };
    return [action];
  }
}

/**
 * Moves the given document to `openIssuesDir` (relative to its workspace
 * folder), preferring `git mv` so the rename is tracked in history; falls
 * back to a plain filesystem rename when `git mv` fails (not a git repo,
 * file not yet tracked, git not on PATH). Refuses to overwrite an existing
 * file at the destination.
 */
async function moveToOpenIssuesCommand(uri: vscode.Uri, openIssuesDir: string): Promise<void> {
  const folder = vscode.workspace.getWorkspaceFolder(uri);
  if (!folder) {
    void vscode.window.showErrorMessage(l10n('docPlacement.error.noWorkspaceFolder'));
    return;
  }

  const targetPath = path.join(folder.uri.fsPath, openIssuesDir, path.basename(uri.fsPath));
  const targetUri = vscode.Uri.file(targetPath);
  try {
    await vscode.workspace.fs.stat(targetUri);
    void vscode.window.showErrorMessage(l10n('docPlacement.error.targetExists', { targetPath }));
    return;
  } catch {
    // stat throwing means nothing exists at the destination yet — proceed.
  }

  try {
    await execFileAsync('git', ['mv', uri.fsPath, targetPath], { cwd: folder.uri.fsPath });
  } catch {
    // Not a git repo, file untracked, or git unavailable — fall back to a plain rename.
    await vscode.workspace.fs.rename(uri, targetUri);
  }

  await vscode.window.showTextDocument(targetUri);
}

/** Registers the doc-placement check. Call once at extension activation. */
export function registerDocPlacementCheck(context: vscode.ExtensionContext): void {
  _collection = vscode.languages.createDiagnosticCollection('saropa-doc-placement');
  context.subscriptions.push(_collection);

  context.subscriptions.push(vscode.workspace.onDidSaveTextDocument(validateDocument));
  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument(validateDocument));
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (!e.affectsConfiguration(CONFIG_SECTION)) return;
      // Only markdown docs can ever get a diagnostic — skip the rest up front
      // rather than relying on validateDocument's early return per doc.
      for (const doc of vscode.workspace.textDocuments) {
        if (doc.languageId === 'markdown') validateDocument(doc);
      }
    }),
  );
  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(
      { language: 'markdown' },
      new DocPlacementCodeActionProvider(),
      { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
    ),
  );
  context.subscriptions.push(
    vscode.commands.registerCommand(MOVE_COMMAND, moveToOpenIssuesCommand),
  );

  for (const doc of vscode.workspace.textDocuments) {
    validateDocument(doc);
  }
}
