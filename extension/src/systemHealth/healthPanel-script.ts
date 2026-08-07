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
