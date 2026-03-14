/**
 * D3: Inline annotations — Error Lens style line-end decorations.
 *
 * Shows violation messages at the end of affected lines in the editor.
 * One decoration type per severity (error, warning, info) for performance.
 * Respects the `saropaLints.inlineAnnotations` toggle setting.
 */

import * as vscode from 'vscode';
import { readViolations, Violation } from './violationsReader';

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

/** Truncate message to MAX_MESSAGE_LENGTH, appending rule name. */
function formatAnnotation(v: Violation): string {
  const msg = v.message.length > MAX_MESSAGE_LENGTH
    ? v.message.slice(0, MAX_MESSAGE_LENGTH) + '…'
    : v.message;
  return `${msg} (${v.rule})`;
}

function decorationTypeForSeverity(
  severity: string | undefined,
): vscode.TextEditorDecorationType {
  switch (severity) {
    case 'error':
      return errorDecorationType;
    case 'warning':
      return warningDecorationType;
    default:
      return infoDecorationType;
  }
}

/**
 * Update inline annotations for a single editor.
 * Clears existing decorations and re-applies from violations data.
 */
export function updateAnnotationsForEditor(editor: vscode.TextEditor): void {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  const annotationsEnabled = cfg.get<boolean>('inlineAnnotations', true) ?? true;

  // Clear all decorations first — whether enabled or not.
  editor.setDecorations(errorDecorationType, []);
  editor.setDecorations(warningDecorationType, []);
  editor.setDecorations(infoDecorationType, []);

  if (!annotationsEnabled) return;

  const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
  if (!root) return;

  const data = readViolations(root);
  if (!data?.violations) return;

  // Normalize the editor file path to forward slashes for comparison.
  const editorRelative = vscode.workspace.asRelativePath(editor.document.uri, false)
    .replace(/\\/g, '/');

  // Filter violations for this file.
  const fileViolations = data.violations.filter((v) => {
    const normalized = v.file.replace(/\\/g, '/');
    return normalized === editorRelative;
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

    const range = new vscode.Range(lineIndex, 0, lineIndex, 0);
    const deco: vscode.DecorationOptions = {
      range,
      renderOptions: {
        after: { contentText: formatAnnotation(v) },
      },
    };

    const decoType = decorationTypeForSeverity(severity);
    if (decoType === errorDecorationType) {
      errorDecos.push(deco);
    } else if (decoType === warningDecorationType) {
      warningDecos.push(deco);
    } else {
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
