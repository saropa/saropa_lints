// Returned as a raw string, not a .js file, because it is injected inline
// into the webview's <script nonce="..."> tag — the extension host has no
// build step for webview-side code, so the script text lives here.
//
// Owns the single `acquireVsCodeApi()` call for the whole panel (VS Code
// throws if it is called more than once per webview) — this is why the
// former Debug Panel's engine-toggle / kill-all / restart-all handling was
// folded into this script rather than concatenated as its own IIFE that
// also called acquireVsCodeApi().
export function getHealthPanelScript(): string {
  return `
const vscode = acquireVsCodeApi();

document.addEventListener('click', function(e) {
  const btn = e.target.closest('button[data-action], [data-action]');
  if (!btn || !btn.dataset) return;
  const action = btn.dataset.action;

  if (action === 'refresh') {
    vscode.postMessage({ type: 'refresh' });
  } else if (action === 'kill' && btn.dataset.pid) {
    btn.disabled = true;
    vscode.postMessage({ type: 'killProcess', pid: Number(btn.dataset.pid) });
  } else if (action === 'toggleOn' || action === 'toggleOff') {
    const card = btn.closest('.engine-card');
    if (card) {
      vscode.postMessage({ type: 'toggle', engine: card.dataset.engine, enabled: action === 'toggleOn' });
    }
  } else if (action === 'reclaimOrphans') {
    // Fires the same command as the palette entry; the extension host owns
    // the confirmation modal, so the webview never terminates anything.
    vscode.postMessage({ type: 'reclaimOrphans' });
  } else if (action === 'killAll') {
    vscode.postMessage({ type: 'killAll' });
  } else if (action === 'restartAll') {
    vscode.postMessage({ type: 'restartAll' });
  } else if (action === 'ciCopyCommands') {
    // Handed to the extension host rather than written with the webview's own
    // navigator.clipboard: clipboard access from a webview depends on document
    // focus and is blocked outright in some hosts, whereas vscode.env.clipboard
    // always works. The host also owns the confirmation message.
    vscode.postMessage({ type: 'ciCopyCommands', commands: btn.dataset.commands || '' });
  } else if (action === 'ciPublish') {
    // Disabled immediately: cutting a branch and pushing is not idempotent, and
    // a double click would otherwise start a second run against a repository the
    // first run has already moved.
    btn.disabled = true;
    btn.textContent = btn.dataset.labelRunning || btn.textContent;
    vscode.postMessage({ type: 'ciPublish' });
  } else if (action === 'ciPublishDismiss') {
    vscode.postMessage({ type: 'ciPublishDismiss' });
  }
});

window.addEventListener('message', function(event) {
  var msg = event.data;
  // Looks the button up by pid rather than tracking a reference, because
  // the extension host may re-render the whole panel HTML between the
  // kill request being sent and this result arriving.
  if (msg.type === 'killResult') {
    var btn = document.querySelector('[data-pid="' + msg.pid + '"]');
    if (btn) {
      btn.textContent = msg.success ? btn.dataset.labelKilled : btn.dataset.labelFailed;
      btn.disabled = true;
    }
  }
});

// Auto-scroll the engine log to the bottom on load so the newest entries
// are visible without manual scrolling.
var logContainer = document.querySelector('.log-container');
if (logContainer) {
  logContainer.scrollTop = logContainer.scrollHeight;
}
`;
}
