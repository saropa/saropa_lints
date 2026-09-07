// Client-side JS for the Machine Health webview. Owns the single
// `acquireVsCodeApi()` call for this panel (VS Code throws if it is called
// more than once per webview).
export function getMachineDashboardScript(): string {
  return `
const vscode = acquireVsCodeApi();

document.addEventListener('click', function(e) {
  const btn = e.target.closest('button[data-action]');
  if (!btn || !btn.dataset) return;
  const action = btn.dataset.action;

  if (action === 'refresh') {
    vscode.postMessage({ type: 'refresh' });
  } else if (action === 'kill' && btn.dataset.pid) {
    btn.disabled = true;
    vscode.postMessage({ type: 'kill', pid: Number(btn.dataset.pid), group: btn.dataset.group });
  } else if (action === 'runCommand' && btn.dataset.command) {
    // The extension host owns every one of these commands' confirmation
    // dialogs (if any) — the webview never runs a destructive action itself.
    btn.disabled = true;
    var args = btn.dataset.args ? JSON.parse(btn.dataset.args) : [];
    vscode.postMessage({ type: 'runCommand', command: btn.dataset.command, recId: btn.dataset.recId, args: args });
  }
});
`;
}
