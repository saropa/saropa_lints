// Returned as a raw string, not a .js file, because it is injected inline
// into the webview's <script nonce="..."> tag — the extension host has no
// build step for webview-side code, so the script text lives here.
export function getHealthPanelScript(): string {
  return `
const vscode = acquireVsCodeApi();

document.addEventListener('click', function(e) {
  const target = e.target;
  if (!target || !target.dataset) return;
  if (target.dataset.action === 'refresh') {
    vscode.postMessage({ type: 'refresh' });
  } else if (target.dataset.action === 'kill' && target.dataset.pid) {
    target.disabled = true;
    vscode.postMessage({ type: 'killProcess', pid: Number(target.dataset.pid) });
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
`;
}
