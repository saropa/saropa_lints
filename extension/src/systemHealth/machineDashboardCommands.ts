/**
 * Actionable commands surfaced by the Machine Health dashboard's
 * Recommendations panel: setting an analysis-server heap cap and unloading a
 * loaded Ollama model. Kept separate from `machineDashboard.ts` (the webview
 * class) for the same reason `cleanupCommand.ts` is separate from
 * `healthPanel.ts` — the webview only ever fires the registered command by
 * name, so the command's own confirmation/input flow can be reused by a
 * future command-palette entry without the panel knowing it exists.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { HEAP_CAP_FLAG } from './processQuery';
import { unloadModel } from './ollamaQuery';

/**
 * Insert or replace `--old_gen_heap_size=<mb>` in the user's global
 * `dart.analyzerVmAdditionalArgs` setting. Prompts for the value via a plain
 * input box rather than the dashboard's own webview — VS Code settings
 * writes belong to the extension host regardless of which UI surface
 * triggered them, and a webview `<input>` would need its own round-trip
 * message protocol to achieve the same thing with no added benefit.
 */
async function setAnalysisServerHeapCap(): Promise<void> {
  const raw = await vscode.window.showInputBox({
    prompt: l10n('machineDashboard.heapCap.prompt'),
    validateInput: (value) => {
      const n = Number(value);
      // Reject non-numeric, fractional, zero, and negative input up front —
      // a bad flag value silently no-ops in the analysis server rather than
      // erroring, so validation here is the only feedback the user gets.
      return Number.isInteger(n) && n > 0 ? undefined : l10n('machineDashboard.heapCap.invalid');
    },
  });
  if (raw === undefined) return;
  const mb = Number(raw);

  const config = vscode.workspace.getConfiguration('dart');
  const current = config.get<string[]>('analyzerVmAdditionalArgs', []);
  // Strip any existing heap-cap flag before appending the new one — leaving
  // a stale `--old_gen_heap_size=2048` alongside a fresh `=4096` would pass
  // both to the VM, and only one of the two duplicate flags wins depending
  // on VM argument-parsing order, which is not a behavior to depend on.
  const withoutOldCap = current.filter((a) => !a.includes(HEAP_CAP_FLAG));
  const updated = [...withoutOldCap, `${HEAP_CAP_FLAG}=${mb}`];
  await config.update('analyzerVmAdditionalArgs', updated, vscode.ConfigurationTarget.Global);

  const restartLabel = l10n('machineDashboard.heapCap.restartNow');
  const choice = await vscode.window.showInformationMessage(
    l10n('machineDashboard.heapCap.applied', { mb: String(mb) }),
    restartLabel,
  );
  if (choice === restartLabel) {
    // dart.restartAnalysisServer is Dart-Code's own command — a VM flag
    // change only takes effect on the next server process, and this is the
    // only way to launch one without asking the user to reload the window.
    void vscode.commands.executeCommand('dart.restartAnalysisServer');
  }
}

/**
 * Unload one named Ollama model. The model name is a required command
 * argument (not read from any ambient state) because the dashboard can show
 * multiple loaded models at once, each with its own recommendation card and
 * its own button — there is no single "the loaded model" to default to.
 */
async function unloadOllamaModelCommand(modelName: string): Promise<void> {
  // Guard against command-palette invocation with no argument — VS Code passes
  // undefined when a user runs a command from the palette that expects args,
  // and `execFile('ollama', ['stop', undefined])` throws ERR_INVALID_ARG_TYPE.
  if (!modelName || typeof modelName !== 'string') {
    void vscode.window.showWarningMessage(
      l10n('machineDashboard.unload.failed', { model: '?' }),
    );
    return;
  }
  const success = await unloadModel(modelName);
  const message = success
    ? l10n('machineDashboard.unload.succeeded', { model: modelName })
    : l10n('machineDashboard.unload.failed', { model: modelName });
  if (success) {
    void vscode.window.showInformationMessage(message);
  } else {
    void vscode.window.showWarningMessage(message);
  }
}

export function registerMachineDashboardCommands(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.setAnalysisServerHeapCap', setAnalysisServerHeapCap),
    vscode.commands.registerCommand('saropaLints.unloadOllamaModel', unloadOllamaModelCommand),
  );
}
