/**
 * D3: Inline annotations — Error Lens style line-end decorations.
 *
 * Shows violation messages at the end of affected lines in the editor.
 * One decoration type per severity (error, warning, info) for performance.
 * Respects the `saropaLints.inlineAnnotations` toggle setting.
 *
 * Known limitation: decorations are line-number-based and do not shift when
 * the user edits a file. They refresh on the next violations.json write
 * (via the file watcher) or on editor switch.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { readViolations, Violation, ViolationsData } from './violationsReader';
import { getProjectRoot } from './projectRoot';

// --- Decoration types (one per severity for VS Code perf) ---

const errorDecorationType = vscode.window.createTextEditorDecorationType({
  after: {
    margin: '0 0 0 2em',
    color: new vscode.ThemeColor('editorError.foreground'),
    fontStyle: 'italic',
  },
  isWholeLine: true,
});

const warningDecorationType = vscode.window.createTextEditorDecorationType({
  after: {
    margin: '0 0 0 2em',
    color: new vscode.ThemeColor('editorWarning.foreground'),
    fontStyle: 'italic',
  },
  isWholeLine: true,
});

const infoDecorationType = vscode.window.createTextEditorDecorationType({
  after: {
    margin: '0 0 0 2em',
    color: new vscode.ThemeColor('editorInfo.foreground'),
    fontStyle: 'italic',
  },
  isWholeLine: true,
});

const MAX_MESSAGE_LENGTH = 80;

// --- Violations cache ---
// Avoids re-reading violations.json from disk on every editor switch.
// Invalidated by `invalidateAnnotationCache()` (called from refreshAll).

let cachedData: { root: string; data: ViolationsData | null } | null = null;

function getCachedViolations(root: string): ViolationsData | null {
  if (cachedData?.root === root) return cachedData.data;
  const data = readViolations(root);
  cachedData = { root, data };
  return data;
}

/** Invalidate the violations cache. Call when violations.json changes. */
export function invalidateAnnotationCache(): void {
  cachedData = null;
}

// --- Formatting helpers ---

/** Truncate message to MAX_MESSAGE_LENGTH, appending rule name. */
function formatAnnotation(v: Violation): string {
  const msg = v.message.length > MAX_MESSAGE_LENGTH
    ? v.message.slice(0, MAX_MESSAGE_LENGTH) + '…'
    : v.message;
  return `${msg} (${v.rule})`;
}

function clearAllDecorations(editor: vscode.TextEditor): void {
  editor.setDecorations(errorDecorationType, []);
  editor.setDecorations(warningDecorationType, []);
  editor.setDecorations(infoDecorationType, []);
}

/**
 * Update inline annotations for a single editor.
 * Clears existing decorations and re-applies from cached violations data.
 */
export function updateAnnotationsForEditor(editor: vscode.TextEditor): void {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const annotationsEnabled = cfg.get<boolean>('inlineAnnotations', true) ?? true;

  // Clear all decorations first — whether enabled or not.
  clearAllDecorations(editor);

  if (!annotationsEnabled) return;

  const root = getProjectRoot();
  if (!root) return;

  // Use cached data to avoid disk I/O on every editor switch.
  const data = getCachedViolations(root);
  if (!data?.violations) return;

  // Compute path relative to project root (where violations.json lives),
  // not workspace root — these differ when pubspec is in a subdirectory.
  const editorRelative = path.relative(root, editor.document.uri.fsPath).replace(/\\/g, '/');

  // Filter violations for this file.
  const fileViolations = data.violations.filter((v) => {
    return v.file.replace(/\\/g, '/') === editorRelative;
  });

  if (fileViolations.length === 0) return;

  // Group by severity, keeping only the first violation per line per severity
  // to avoid clutter.
  const errorDecos: vscode.DecorationOptions[] = [];
  const warningDecos: vscode.DecorationOptions[] = [];
  const infoDecos: vscode.DecorationOptions[] = [];
  const seenLines = new Map<string, Set<number>>();

  for (const v of fileViolations) {
    const severity = v.severity ?? 'info';
    const lineSet = seenLines.get(severity) ?? new Set<number>();
    seenLines.set(severity, lineSet);

    // violations.json uses 1-based lines; VS Code uses 0-based.
    const lineIndex = Math.max(0, v.line - 1);
    if (lineSet.has(lineIndex)) continue;
    lineSet.add(lineIndex);

    // Column values are irrelevant for isWholeLine decorations — the `after`
    // pseudo-element always renders at the line end regardless of range.
    const range = new vscode.Range(lineIndex, 0, lineIndex, 0);
    const deco: vscode.DecorationOptions = {
      range,
      renderOptions: {
        after: { contentText: formatAnnotation(v) },
      },
    };

    switch (severity) {
      case 'error':
        errorDecos.push(deco);
        break;
      case 'warning':
        warningDecos.push(deco);
        break;
      default:
        infoDecos.push(deco);
    }
  }

  editor.setDecorations(errorDecorationType, errorDecos);
  editor.setDecorations(warningDecorationType, warningDecos);
  editor.setDecorations(infoDecorationType, infoDecos);
}

/** Update annotations for all visible text editors. */
export function updateAnnotationsForAllEditors(): void {
  for (const editor of vscode.window.visibleTextEditors) {
    updateAnnotationsForEditor(editor);
  }
}

/** Register event listeners and toggle command. Returns disposables. */
export function registerInlineAnnotations(
  context: vscode.ExtensionContext,
): void {
  // Update when the active editor changes.
  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor((editor) => {
      if (editor) updateAnnotationsForEditor(editor);
    }),
  );

  // Update when visible editors change (e.g. split view).
  context.subscriptions.push(
    vscode.window.onDidChangeVisibleTextEditors(() => {
      updateAnnotationsForAllEditors();
    }),
  );

  // Toggle command.
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.toggleInlineAnnotations', async () => {
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const current = cfg.get<boolean>('inlineAnnotations', true) ?? true;
      await cfg.update('inlineAnnotations', !current, vscode.ConfigurationTarget.Workspace);
      updateAnnotationsForAllEditors();
      const state = !current ? 'on' : 'off';
      void vscode.window.setStatusBarMessage(`Saropa Lints: Inline annotations ${state}`, 3000);
    }),
  );

  // Dispose decoration types on deactivation.
  context.subscriptions.push(errorDecorationType, warningDecorationType, infoDecorationType);
}
