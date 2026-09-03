/**
 * Dead-key detector + quick-fix for the l10n catalog.
 * Reports en.json keys never referenced in source as Hint diagnostics.
 * Quick-fix removes dead keys from all locale files (single or bulk).
 */
import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';

let _collection: vscode.DiagnosticCollection | undefined;
let _timer: ReturnType<typeof setTimeout> | undefined;
/** Flatten nested JSON into dotted key strings. */
function flattenKeys(obj: Record<string, unknown>, prefix = ''): string[] {
  const keys: string[] = [];
  for (const [k, v] of Object.entries(obj)) {
    const full = prefix ? `${prefix}.${k}` : k;
    if (typeof v === 'object' && v !== null && !Array.isArray(v)) {
      keys.push(...flattenKeys(v as Record<string, unknown>, full));
    } else { keys.push(full); }
  }
  return keys;
}

/**
 * Find offset of a dotted key's leaf in JSON source. Walks each segment
 * in order and requires `:` or `{` after the match (a JSON key position)
 * so string values containing segment names don't cause false matches.
 */
function findKeyOffset(text: string, dottedKey: string): number {
  const segments = dottedKey.split('.');
  let searchFrom = 0;
  let lastIdx = -1;
  for (const seg of segments) {
    const needle = `"${seg}"`;
    let idx = text.indexOf(needle, searchFrom);
    while (idx >= 0) {
      let j = idx + needle.length;
      while (j < text.length && /\s/.test(text[j])) j++;
      if (j < text.length && (text[j] === ':' || text[j] === '{')) break;
      idx = text.indexOf(needle, idx + needle.length);
    }
    if (idx < 0) return -1;
    lastIdx = idx;
    searchFrom = idx + needle.length;
  }
  return lastIdx;
}

/** Resolve the locales directory, or undefined if not found. */
function getLocalesDir(): string | undefined {
  const ws = vscode.workspace.workspaceFolders?.[0];
  if (!ws) return undefined;
  const dir = path.join(ws.uri.fsPath, 'extension', 'src', 'i18n', 'locales');
  return fs.existsSync(dir) ? dir : undefined;
}

/** Scan source files and report unreferenced en.json keys. */
async function scanDeadKeys(): Promise<void> {
  if (!_collection) return;
  const localesDir = getLocalesDir();
  if (!localesDir) return;
  const enPath = path.join(localesDir, 'en.json');
  if (!fs.existsSync(enPath)) return;
  let allKeys: string[];
  try {
    const raw = JSON.parse(fs.readFileSync(enPath, 'utf-8')) as Record<string, unknown>;
    allKeys = flattenKeys(raw);
  } catch { return; }
  const unreferenced = new Set(allKeys);
  const tsFiles = await vscode.workspace.findFiles(
    'extension/src/**/*.{ts,tsx}', '**/node_modules/**',
  );
  for (const uri of tsFiles) {
    if (unreferenced.size === 0) break;
    try {
      const content = fs.readFileSync(uri.fsPath, 'utf-8');
      for (const key of [...unreferenced]) {
        if (content.includes(key)) unreferenced.delete(key);
      }
    } catch { /* skip unreadable */ }
  }
  if (unreferenced.size === 0) { _collection.clear(); return; }
  const enDoc = await vscode.workspace.openTextDocument(vscode.Uri.file(enPath));
  const enText = enDoc.getText();
  const diagnostics: vscode.Diagnostic[] = [];
  for (const key of unreferenced) {
    const leaf = key.split('.').pop()!;
    const idx = findKeyOffset(enText, key);
    const pos = idx >= 0 ? enDoc.positionAt(idx) : new vscode.Position(0, 0);
    diagnostics.push(new vscode.Diagnostic(
      new vscode.Range(pos, pos.translate(0, leaf.length + 2)),
      `l10n key "${key}" is never referenced in source files`,
      vscode.DiagnosticSeverity.Hint,
    ));
  }
  _collection.set(enDoc.uri, diagnostics);
}

/** Remove a key's line from one locale file, fixing trailing commas. */
function removeKeyLine(
  edit: vscode.WorkspaceEdit, doc: vscode.TextDocument, dottedKey: string,
): boolean {
  const idx = findKeyOffset(doc.getText(), dottedKey);
  if (idx < 0) return false;
  const line = doc.positionAt(idx).line;
  edit.delete(doc.uri, doc.lineAt(line).rangeIncludingLineBreak);
  // Last entry (no trailing comma) — strip comma from previous line if present.
  if (!doc.lineAt(line).text.trimEnd().endsWith(',') && line > 0) {
    const prev = doc.lineAt(line - 1).text.trimEnd();
    if (prev.endsWith(',')) {
      const ci = doc.lineAt(line - 1).text.lastIndexOf(',');
      edit.delete(doc.uri, new vscode.Range(line - 1, ci, line - 1, ci + 1));
    }
  }
  return true;
}
/** Open all locale docs and apply removeKeyLine to each. */
async function applyToAllLocales(
  localesDir: string, keys: string[],
): Promise<void> {
  const edit = new vscode.WorkspaceEdit();
  for (const f of fs.readdirSync(localesDir).filter(f => f.endsWith('.json'))) {
    const doc = await vscode.workspace.openTextDocument(
      vscode.Uri.file(path.join(localesDir, f)),
    );
    for (const key of keys) { removeKeyLine(edit, doc, key); }
  }
  await vscode.workspace.applyEdit(edit);
  scheduleDeadKeyScan();
}

/** Remove ALL dead keys from every locale file in one batch. */
async function removeAllDeadKeys(): Promise<void> {
  const localesDir = getLocalesDir();
  if (!localesDir || !_collection) return;
  const diags = _collection.get(vscode.Uri.file(path.join(localesDir, 'en.json')));
  if (!diags || diags.length === 0) {
    void vscode.window.showInformationMessage('No dead l10n keys found.');
    return;
  }
  const deadKeys = diags
    .map(d => d.message.match(DEAD_KEY_RE)?.[1])
    .filter((k): k is string => k !== undefined);
  if (deadKeys.length === 0) return;
  const pick = await vscode.window.showWarningMessage(
    `Remove ${deadKeys.length} dead l10n key(s) from all locale files?`,
    { modal: true }, 'Remove',
  );
  if (pick !== 'Remove') return;
  // Reverse order so line deletions don't shift earlier key positions.
  await applyToAllLocales(localesDir, deadKeys.reverse());
}

// Regex shared by the code-action provider and bulk removal.
const DEAD_KEY_RE = /^l10n key "(.+)" is never/;

/** Quick-fix provider — offers key removal on dead-key diagnostics. */
class DeadKeyFixProvider implements vscode.CodeActionProvider {
  provideCodeActions(doc: vscode.TextDocument, range: vscode.Range): vscode.CodeAction[] {
    return (_collection?.get(doc.uri) ?? [])
      .filter(d => d.range.intersection(range))
      .map(d => {
        const m = d.message.match(DEAD_KEY_RE);
        if (!m) return undefined;
        const a = new vscode.CodeAction(`Remove "${m[1]}" from all locales`, vscode.CodeActionKind.QuickFix);
        a.diagnostics = [d]; a.isPreferred = true;
        a.command = { command: 'saropaLints.l10n.removeDeadKey', title: 'Remove dead key', arguments: [m[1]] };
        return a;
      }).filter((a): a is vscode.CodeAction => a !== undefined);
  }
}

/** Debounced dead-key scan trigger (500ms). */
export function scheduleDeadKeyScan(): void {
  if (_timer) clearTimeout(_timer);
  _timer = setTimeout(() => { void scanDeadKeys(); }, 500);
}

/** Register the dead-key detector + quick-fix. Call once at activation. */
export function registerL10nDeadKeys(context: vscode.ExtensionContext): void {
  _collection = vscode.languages.createDiagnosticCollection('saropa-l10n-dead');
  context.subscriptions.push(_collection);
  const watcher = vscode.workspace.createFileSystemWatcher('**/i18n/locales/en.json');
  watcher.onDidChange(scheduleDeadKeyScan);
  context.subscriptions.push(watcher);
  context.subscriptions.push(vscode.commands.registerCommand(
    'saropaLints.l10n.removeDeadKey',
    async (key: string) => { const d = getLocalesDir(); if (d) await applyToAllLocales(d, [key]); },
  ));
  context.subscriptions.push(vscode.commands.registerCommand(
    'saropaLints.l10n.removeAllDeadKeys', () => removeAllDeadKeys(),
  ));
  context.subscriptions.push(vscode.languages.registerCodeActionsProvider(
    { language: 'json', pattern: '**/i18n/locales/en.json' },
    new DeadKeyFixProvider(),
    { providedCodeActionKinds: [vscode.CodeActionKind.QuickFix] },
  ));
  scheduleDeadKeyScan();
}
