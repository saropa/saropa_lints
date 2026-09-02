/**
 * VS Code diagnostic provider for l10n key validation.
 *
 * On save of any TypeScript file under extension/src/, scans for
 * l10n() calls and reports missing keys or mismatched interpolation
 * params as diagnostics (yellow squiggles in the editor).
 */
import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  blankComments,
  extractParamsBlock,
  extractTopLevelKeys,
} from './l10nParsers';

/** Diagnostic collection shared across all validated files. */
let _collection: vscode.DiagnosticCollection | undefined;

/** Cached flattened catalog from en.json — invalidated on file change. */
let _catalogCache: Map<string, string> | undefined;

/** Watches en.json for changes to invalidate the catalog cache. */
let _watcher: vscode.FileSystemWatcher | undefined;

// Captures the quoted key argument from each l10n() call.
const L10N_RE = /l10n\(\s*(['"])([a-zA-Z0-9_.]+)\1/g;

// Extracts {placeholder} tokens from en.json values.
const PLACEHOLDER_RE = /\{([a-zA-Z0-9_]+)\}/g;

/**
 * Flatten a nested JSON object into a Map of dotted keys to string values.
 */
function flattenCatalog(obj: Record<string, unknown>, prefix = ''): Map<string, string> {
  const result = new Map<string, string>();
  for (const [k, v] of Object.entries(obj)) {
    const full = prefix ? `${prefix}.${k}` : k;
    if (typeof v === 'object' && v !== null && !Array.isArray(v)) {
      for (const [fk, fv] of flattenCatalog(v as Record<string, unknown>, full)) {
        result.set(fk, fv);
      }
    } else {
      result.set(full, String(v));
    }
  }
  return result;
}

/** Load and cache the flattened en.json catalog. */
function getCatalog(): Map<string, string> | undefined {
  if (_catalogCache) return _catalogCache;
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (!workspaceFolders) return undefined;
  for (const folder of workspaceFolders) {
    const enJsonPath = path.join(
      folder.uri.fsPath, 'extension', 'src', 'i18n', 'locales', 'en.json',
    );
    if (fs.existsSync(enJsonPath)) {
      try {
        const raw = JSON.parse(fs.readFileSync(enJsonPath, 'utf-8')) as Record<string, unknown>;
        _catalogCache = flattenCatalog(raw);
        return _catalogCache;
      } catch {
        return undefined;
      }
    }
  }
  return undefined;
}

/** Validate a single TypeScript document for l10n key issues. */
function validateDocument(doc: vscode.TextDocument): void {
  if (doc.languageId !== 'typescript' && doc.languageId !== 'typescriptreact') return;
  if (!doc.uri.fsPath.includes(`extension${path.sep}src${path.sep}`)) return;

  const catalog = getCatalog();
  if (!catalog) return;

  const diagnostics: vscode.Diagnostic[] = [];
  const text = doc.getText();
  // Comment-blanked text for regex matching — prevents false positives
  // from example l10n() calls inside code comments.
  const scanText = blankComments(text);

  L10N_RE.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = L10N_RE.exec(scanText)) !== null) {
    const key = match[2];
    const keyStart = match.index + match[0].indexOf(key);
    const keyEnd = keyStart + key.length;
    const range = new vscode.Range(doc.positionAt(keyStart), doc.positionAt(keyEnd));

    if (key.endsWith('.')) continue;

    if (!catalog.has(key)) {
      diagnostics.push(new vscode.Diagnostic(
        range,
        `l10n key "${key}" is not defined in en.json`,
        vscode.DiagnosticSeverity.Warning,
      ));
      continue;
    }

    const catalogValue = catalog.get(key)!;
    const expectedParams = new Set<string>();
    PLACEHOLDER_RE.lastIndex = 0;
    let pm: RegExpExecArray | null;
    while ((pm = PLACEHOLDER_RE.exec(catalogValue)) !== null) {
      expectedParams.add(pm[1]);
    }
    if (expectedParams.size === 0) continue;

    // Use original text for param extraction — comment blanking only
    // affects the L10N_RE scan, not the structural parse.
    const afterKey = match.index + match[0].length;
    const paramsBlock = extractParamsBlock(text, afterKey);

    if (!paramsBlock) {
      diagnostics.push(new vscode.Diagnostic(
        range,
        `l10n key "${key}" expects params {${[...expectedParams].join(', ')}} but none passed`,
        vscode.DiagnosticSeverity.Warning,
      ));
      continue;
    }

    const supplied = extractTopLevelKeys(paramsBlock);
    const missingParams = [...expectedParams].filter(p => !supplied.has(p));
    if (missingParams.length > 0) {
      diagnostics.push(new vscode.Diagnostic(
        range,
        `l10n key "${key}" missing params: {${missingParams.join(', ')}}`,
        vscode.DiagnosticSeverity.Warning,
      ));
    }
  }

  _collection?.set(doc.uri, diagnostics);
}

/** Register the l10n diagnostic provider. Call once at extension activation. */
export function registerL10nDiagnostics(context: vscode.ExtensionContext): void {
  _collection = vscode.languages.createDiagnosticCollection('saropa-l10n');
  context.subscriptions.push(_collection);

  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument(validateDocument),
  );
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument(validateDocument),
  );

  _watcher = vscode.workspace.createFileSystemWatcher('**/i18n/locales/en.json');
  _watcher.onDidChange(() => {
    _catalogCache = undefined;
    for (const doc of vscode.workspace.textDocuments) { validateDocument(doc); }
  });
  context.subscriptions.push(_watcher);

  for (const doc of vscode.workspace.textDocuments) { validateDocument(doc); }
}
