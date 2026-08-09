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
    if (target.id === 'fix-syntax-btn') {
      vscode.postMessage({ type: 'fixSyntax' });
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
    if (target.classList.contains('preview-toggle-btn')) {
      var previewRow = document.getElementById(target.dataset.target);
      if (previewRow) {
        // Re-anchor immediately after the owning row every time — a prior
        // column sort can leave the preview row's DOM position stale
        // relative to its (now reordered) parent row.
        var ownerRow = target.closest('tr');
        if (ownerRow && ownerRow.nextSibling !== previewRow) {
          ownerRow.after(previewRow);
        }
        previewRow.hidden = !previewRow.hidden;
      }
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

  var exclusionsTable = document.getElementById('exclusions-table');
  if (exclusionsTable) {
    // Uses the webview's own getState/setState (not localStorage) because
    // that's the API VS Code guarantees persists across a webview.html
    // reassignment — this panel re-renders its full HTML on every Apply /
    // Remove, so without this the user's chosen sort would silently reset
    // each time.
    function loadSortState() {
      var state = vscode.getState() || {};
      return { key: state.sortKey || null, dir: state.sortDir === -1 ? -1 : 1 };
    }

    function saveSortState(sortState) {
      var state = vscode.getState() || {};
      state.sortKey = sortState.key;
      state.sortDir = sortState.dir;
      vscode.setState(state);
    }

    var sortState = loadSortState();
    var headers = exclusionsTable.querySelectorAll('th.sortable');

    function applySort(key, dir) {
      var tbody = exclusionsTable.querySelector('tbody');
      // Preview rows (toggled via preview-toggle-btn) have no sort data and
      // are visually anchored under one specific data row — collapse them
      // and exclude them from the reorder so a sort can never leave one
      // sitting under the wrong row.
      var previewRows = tbody.querySelectorAll('.preview-row');
      for (var p = 0; p < previewRows.length; p++) { previewRows[p].hidden = true; }

      var rows = Array.from(tbody.querySelectorAll('tr:not(.preview-row)'));
      var attr = 'data-' + key;
      var numeric = key === 'files' || key === 'cost' || key === 'priority' || key === 'status';

      rows.sort(function(a, b) {
        var av = a.getAttribute(attr) || '';
        var bv = b.getAttribute(attr) || '';
        if (numeric) {
          return (parseFloat(av) - parseFloat(bv)) * dir;
        }
        return av.localeCompare(bv) * dir;
      });

      for (var k = 0; k < rows.length; k++) {
        tbody.appendChild(rows[k]);
      }
    }

    function markActiveHeader(key, dir) {
      for (var j = 0; j < headers.length; j++) {
        headers[j].classList.remove('sort-asc', 'sort-desc');
        if (headers[j].dataset.sort === key) {
          headers[j].classList.add(dir === 1 ? 'sort-asc' : 'sort-desc');
        }
      }
    }

    for (var h = 0; h < headers.length; h++) {
      headers[h].addEventListener('click', function() {
        var key = this.dataset.sort;
        if (sortState.key === key) {
          sortState.dir = -sortState.dir;
        } else {
          sortState.key = key;
          sortState.dir = 1;
        }
        applySort(sortState.key, sortState.dir);
        markActiveHeader(sortState.key, sortState.dir);
        saveSortState(sortState);
      });
    }

    // Re-applies the sort the user last chose so it survives the full-HTML
    // re-render every Apply/Remove triggers (the panel has no partial DOM
    // update path — the server always redraws the whole table from scratch).
    if (sortState.key) {
      applySort(sortState.key, sortState.dir);
      markActiveHeader(sortState.key, sortState.dir);
    }
  }
})();
`;
}
