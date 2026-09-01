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

/** Diagnostic collection shared across all validated files. */
let _collection: vscode.DiagnosticCollection | undefined;

/** Cached flattened catalog from en.json — invalidated on file change. */
let _catalogCache: Map<string, string> | undefined;

/** Watches en.json for changes to invalidate the catalog cache. */
let _watcher: vscode.FileSystemWatcher | undefined;

// Matches l10n('dotted.key') with single or double quotes.
const L10N_RE = /l10n\(\s*(['"])([a-zA-Z0-9_.]+)\1/g;

// Extracts {placeholder} tokens from en.json values.
const PLACEHOLDER_RE = /\{([a-zA-Z0-9_]+)\}/g;

// Extracts JS object keys from a params argument.
// Handles { count: val } and shorthand { message }.
const OBJ_KEY_RE = /(?:^|[{,])\s*(?!\.\.\.)(\w+)\s*(?::|[,}])/g;

/**
 * Flatten a nested JSON object into a Map of dotted keys to string values.
 */
function flattenCatalog(obj: Record<string, unknown>, prefix = ''): Map<string, string> {
  const result = new Map<string, string>();
  for (const [k, v] of Object.entries(obj)) {
    const full = prefix ? `${prefix}.${k}` : k;
    if (typeof v === 'object' && v !== null && !Array.isArray(v)) {
      // Recurse into nested namespaces.
      for (const [fk, fv] of flattenCatalog(v as Record<string, unknown>, full)) {
        result.set(fk, fv);
      }
    } else {
      result.set(full, String(v));
    }
  }
  return result;
}

/**
 * Load and cache the flattened en.json catalog.
 */
function getCatalog(): Map<string, string> | undefined {
  if (_catalogCache) return _catalogCache;

  // Find en.json relative to the extension src directory.
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
        // Malformed en.json — skip validation until it's fixed.
        return undefined;
      }
    }
  }
  return undefined;
}

/**
 * Extract a balanced { ... } block starting at position `start` in
 * `text`, handling nested braces and string literals.
 */
function extractParamsBlock(text: string, start: number): string | undefined {
  // Skip whitespace then look for comma + object.
  let i = start;
  const n = text.length;
  while (i < n && /\s/.test(text[i])) i++;
  if (i >= n || text[i] !== ',') return undefined;
  i++;
  while (i < n && /\s/.test(text[i])) i++;
  if (i >= n || text[i] !== '{') return undefined;

  // Balanced brace scan.
  let depth = 0;
  const objStart = i;
  while (i < n) {
    const c = text[i];
    if (c === "'" || c === '"' || c === '`') {
      // Skip string contents.
      const q = c;
      i++;
      while (i < n) {
        if (text[i] === '\\') { i += 2; continue; }
        if (text[i] === q) break;
        i++;
      }
    } else if (c === '{') {
      depth++;
    } else if (c === '}') {
      depth--;
      if (depth === 0) return text.slice(objStart, i + 1);
    }
    i++;
  }
  return undefined;
}

/**
 * Validate a single TypeScript document for l10n key issues.
 */
function validateDocument(doc: vscode.TextDocument): void {
  // Only validate TypeScript files inside extension/src/.
  if (doc.languageId !== 'typescript' && doc.languageId !== 'typescriptreact') return;
  if (!doc.uri.fsPath.includes(`extension${path.sep}src${path.sep}`)) return;

  const catalog = getCatalog();
  if (!catalog) return;

  const diagnostics: vscode.Diagnostic[] = [];
  const text = doc.getText();

  // Reset the regex state for each document.
  L10N_RE.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = L10N_RE.exec(text)) !== null) {
    const key = match[2];
    const keyStart = match.index + match[0].indexOf(key);
    const keyEnd = keyStart + key.length;
    const range = new vscode.Range(doc.positionAt(keyStart), doc.positionAt(keyEnd));

    // Skip dynamic key prefixes.
    if (key.endsWith('.')) continue;

    // Check 1: key exists in en.json.
    if (!catalog.has(key)) {
      diagnostics.push(
        new vscode.Diagnostic(
          range,
          `l10n key "${key}" is not defined in en.json`,
          vscode.DiagnosticSeverity.Warning,
        ),
      );
      continue;
    }

    // Check 2: interpolation params match.
    const catalogValue = catalog.get(key)!;
    const expectedParams = new Set<string>();
    PLACEHOLDER_RE.lastIndex = 0;
    let pm: RegExpExecArray | null;
    while ((pm = PLACEHOLDER_RE.exec(catalogValue)) !== null) {
      expectedParams.add(pm[1]);
    }
    if (expectedParams.size === 0) continue;

    // Extract the params object from the call site.
    const afterKey = match.index + match[0].length;
    const paramsBlock = extractParamsBlock(text, afterKey);

    if (!paramsBlock) {
      // Catalog expects params but call site doesn't pass any.
      diagnostics.push(
        new vscode.Diagnostic(
          range,
          `l10n key "${key}" expects params {${[...expectedParams].join(', ')}} but none passed`,
          vscode.DiagnosticSeverity.Warning,
        ),
      );
      continue;
    }

    // Extract supplied keys from the params object.
    const supplied = new Set<string>();
    OBJ_KEY_RE.lastIndex = 0;
    let km: RegExpExecArray | null;
    while ((km = OBJ_KEY_RE.exec(paramsBlock)) !== null) {
      supplied.add(km[1]);
    }

    const missingParams = [...expectedParams].filter(p => !supplied.has(p));
    if (missingParams.length > 0) {
      diagnostics.push(
        new vscode.Diagnostic(
          range,
          `l10n key "${key}" missing params: {${missingParams.join(', ')}}`,
          vscode.DiagnosticSeverity.Warning,
        ),
      );
    }
  }

  _collection?.set(doc.uri, diagnostics);
}

/**
 * Register the l10n diagnostic provider. Call once at extension activation.
 */
export function registerL10nDiagnostics(context: vscode.ExtensionContext): void {
  _collection = vscode.languages.createDiagnosticCollection('saropa-l10n');
  context.subscriptions.push(_collection);

  // Validate on save.
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument(validateDocument),
  );

  // Validate when a TypeScript file is opened.
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument(validateDocument),
  );

  // Invalidate catalog cache when en.json changes.
  _watcher = vscode.workspace.createFileSystemWatcher('**/i18n/locales/en.json');
  _watcher.onDidChange(() => {
    // Clear cache so next validation picks up the new keys.
    _catalogCache = undefined;
    // Re-validate all open TS documents.
    for (const doc of vscode.workspace.textDocuments) {
      validateDocument(doc);
    }
  });
  context.subscriptions.push(_watcher);

  // Validate all currently open TypeScript files.
  for (const doc of vscode.workspace.textDocuments) {
    validateDocument(doc);
  }
}
