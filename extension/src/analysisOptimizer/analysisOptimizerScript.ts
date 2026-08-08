export function getOptimizerScript(): string {
  return `
(function() {
  const vscode = acquireVsCodeApi();

  document.addEventListener('click', function(e) {
    const target = e.target;
    if (!target) return;

    if (target.id === 'scan-btn') {
      vscode.postMessage({ type: 'scan' });
      return;
    }
    if (target.id === 'open-config-btn') {
      vscode.postMessage({ type: 'openConfig' });
      return;
    }
    if (target.id === 'apply-all-btn') {
      vscode.postMessage({ type: 'applyAll' });
      return;
    }
    if (target.id === 'apply-selected-btn') {
      const checked = document.querySelectorAll('.rec-cb:checked');
      const patterns = Array.from(checked).map(function(cb) { return cb.dataset.pattern; });
      if (patterns.length > 0) {
        vscode.postMessage({ type: 'applySelected', patterns: patterns });
      }
      return;
    }
    if (target.classList.contains('apply-one-btn')) {
      vscode.postMessage({ type: 'applyExclusion', pattern: target.dataset.pattern });
      return;
    }
    if (target.classList.contains('remove-btn')) {
      vscode.postMessage({ type: 'removeExclusion', pattern: target.dataset.pattern });
      return;
    }
  });

  var selectAll = document.getElementById('select-all-cb');
  if (selectAll) {
    selectAll.addEventListener('change', function() {
      var cbs = document.querySelectorAll('.rec-cb');
      for (var i = 0; i < cbs.length; i++) { cbs[i].checked = selectAll.checked; }
      updateApplySelected();
    });
  }

  document.addEventListener('change', function(e) {
    if (e.target && e.target.classList.contains('rec-cb')) {
      updateApplySelected();
    }
  });

  function updateApplySelected() {
    var btn = document.getElementById('apply-selected-btn');
    if (!btn) return;
    var count = document.querySelectorAll('.rec-cb:checked').length;
    btn.disabled = count === 0;
  }
})();
`;
}
