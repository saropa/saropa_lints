/**
 * Executes the Analysis Optimizer webview's inline client script against a real
 * DOM, mirroring the pattern used for the opportunities report
 * (feature-inventory-dom.test.ts) — asserting on the HTML string alone would
 * leave a runtime error inside the script undetected while the page still
 * "renders". jsdom does not enforce CSP, so the script runs under
 * `runScripts: 'dangerously'`.
 */

import * as assert from 'assert';
import { JSDOM } from 'jsdom';
import { getOptimizerScript } from '../../analysisOptimizer/analysisOptimizerScript';

/**
 * Minimal fixture mirroring the markup analysisOptimizerWebviewProvider.ts
 * renders for the recommendations table and toolbar — just enough structure
 * for the script's selectors (`#scan-btn`, `.rec-cb`, `#apply-selected-btn`,
 * etc.) to have something real to operate on.
 */
function fixtureHtml(recCount: number): string {
  const rows = Array.from({ length: recCount }, (_, i) => `
    <tr>
      <td><input type="checkbox" class="rec-cb" data-index="${i}" data-pattern="pattern-${i}/**"></td>
    </tr>`).join('');

  return `<!DOCTYPE html>
<html><body>
  <button id="scan-btn">Scan</button>
  <button id="open-config-btn">Open config</button>
  <button id="apply-all-btn">Apply all</button>
  <button id="apply-selected-btn" disabled>Apply selected</button>
  <input type="checkbox" id="select-all-cb">
  <table><tbody>${rows}</tbody></table>
  <button class="apply-one-btn" data-pattern="single/**">Apply</button>
  <button class="remove-btn" data-pattern="removeme/**">&times;</button>
  <script>${getOptimizerScript()}</script>
</body></html>`;
}

interface FakeVsCodeApi {
  postMessage: (m: unknown) => void;
  getState: () => unknown;
  setState: (s: unknown) => void;
}

/** A stub matching the real webview API's getState/setState contract, backed by a plain JS variable — the same durability model VS Code uses across a webview.html reassignment (persisted by the extension host, not the DOM). */
function makeFakeVsCodeApi(messages: unknown[], initialState: unknown = undefined): FakeVsCodeApi {
  let state = initialState;
  return {
    postMessage: (m: unknown) => messages.push(JSON.parse(JSON.stringify(m))),
    getState: () => state,
    setState: (s: unknown) => { state = JSON.parse(JSON.stringify(s)); },
  };
}

/**
 * Renders the fixture and stubs acquireVsCodeApi to capture posted messages.
 * Messages are JSON round-tripped before storage — objects constructed inside
 * jsdom's VM context are structurally identical to but not reference-equal
 * with Node's Object.prototype, which trips assert.deepStrictEqual otherwise.
 */
function render(recCount = 3): { doc: Document; messages: unknown[] } {
  const messages: unknown[] = [];
  const dom = new JSDOM(fixtureHtml(recCount), {
    runScripts: 'dangerously',
    beforeParse(window) {
      (window as unknown as { acquireVsCodeApi: () => FakeVsCodeApi })
        .acquireVsCodeApi = () => makeFakeVsCodeApi(messages);
    },
  });
  return { doc: dom.window.document, messages };
}

/** Minimal fixture mirroring the sortable exclusions table markup. */
function sortableTableHtml(): string {
  const rows = [
    { pattern: 'zebra/**', files: 5, cost: 100, priority: 2 },
    { pattern: 'alpha/**', files: 50, cost: 900, priority: 0 },
    { pattern: 'mid/**', files: 20, cost: 400, priority: 1 },
  ];
  const trs = rows.map(r => `
    <tr data-pattern="${r.pattern}" data-files="${r.files}" data-cost="${r.cost}" data-priority="${r.priority}">
      <td>${r.pattern}</td><td>${r.files}</td><td>${r.cost}</td><td>${r.priority}</td>
    </tr>`).join('');

  return `<!DOCTYPE html>
<html><body>
  <table id="exclusions-table">
    <thead>
      <tr>
        <th class="sortable" data-sort="pattern">Pattern<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="files">Files<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="cost">Cost<span class="sort-indicator"></span></th>
        <th class="sortable" data-sort="priority">Priority<span class="sort-indicator"></span></th>
      </tr>
    </thead>
    <tbody>${trs}</tbody>
  </table>
  <script>${getOptimizerScript()}</script>
</body></html>`;
}

function renderSortableTable(initialState: unknown = undefined): { doc: Document; api: FakeVsCodeApi } {
  const api = makeFakeVsCodeApi([], initialState);
  const dom = new JSDOM(sortableTableHtml(), {
    runScripts: 'dangerously',
    beforeParse(window) {
      (window as unknown as { acquireVsCodeApi: () => FakeVsCodeApi }).acquireVsCodeApi = () => api;
    },
  });
  return { doc: dom.window.document, api };
}

function rowPatterns(doc: Document): string[] {
  return [...doc.querySelectorAll('#exclusions-table tbody tr')].map(
    (tr) => tr.getAttribute('data-pattern') ?? '',
  );
}

describe('analysisOptimizerScript (executed against a real DOM)', () => {
  it('scan button posts a scan message', () => {
    const { doc, messages } = render();
    doc.getElementById('scan-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [{ type: 'scan' }]);
  });

  it('open-config button posts an openConfig message', () => {
    const { doc, messages } = render();
    doc.getElementById('open-config-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [{ type: 'openConfig' }]);
  });

  it('apply-all button posts an applyAll message', () => {
    const { doc, messages } = render();
    doc.getElementById('apply-all-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [{ type: 'applyAll' }]);
  });

  it('a single apply-one button posts its own pattern only', () => {
    const { doc, messages } = render();
    doc.querySelector('.apply-one-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [{ type: 'applyExclusion', pattern: 'single/**' }]);
  });

  it('a remove button posts its own pattern', () => {
    const { doc, messages } = render();
    doc.querySelector('.remove-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [{ type: 'removeExclusion', pattern: 'removeme/**' }]);
  });

  it('select-all toggles every recommendation checkbox and enables apply-selected', () => {
    const { doc } = render(3);
    const selectAll = doc.getElementById('select-all-cb') as HTMLInputElement;
    selectAll.checked = true;
    selectAll.dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));

    const boxes = [...doc.querySelectorAll<HTMLInputElement>('.rec-cb')];
    assert.strictEqual(boxes.every((b) => b.checked), true);
    assert.strictEqual((doc.getElementById('apply-selected-btn') as HTMLButtonElement).disabled, false);
  });

  it('unchecking every box re-disables apply-selected', () => {
    const { doc } = render(1);
    const box = doc.querySelector<HTMLInputElement>('.rec-cb')!;
    box.checked = true;
    box.dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));
    assert.strictEqual((doc.getElementById('apply-selected-btn') as HTMLButtonElement).disabled, false);

    box.checked = false;
    box.dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));
    assert.strictEqual((doc.getElementById('apply-selected-btn') as HTMLButtonElement).disabled, true);
  });

  it('apply-selected posts only the checked patterns', () => {
    const { doc, messages } = render(3);
    const boxes = [...doc.querySelectorAll<HTMLInputElement>('.rec-cb')];
    boxes[0].checked = true;
    boxes[0].dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));
    boxes[2].checked = true;
    boxes[2].dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));

    doc.getElementById('apply-selected-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [
      { type: 'applySelected', patterns: ['pattern-0/**', 'pattern-2/**'] },
    ]);
  });

  it('apply-selected does nothing when no boxes are checked', () => {
    const { doc, messages } = render(2);
    doc.getElementById('apply-selected-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, []);
  });

  describe('sortable exclusions table', () => {
    it('sorts numerically ascending on first click of a numeric column', () => {
      const { doc } = renderSortableTable();
      const filesHeader = doc.querySelector('th[data-sort="files"]')!;
      filesHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
      assert.deepStrictEqual(rowPatterns(doc), ['zebra/**', 'mid/**', 'alpha/**']);
      assert.ok(filesHeader.classList.contains('sort-asc'));
    });

    it('reverses to descending on a second click of the same column', () => {
      const { doc } = renderSortableTable();
      const costHeader = doc.querySelector('th[data-sort="cost"]')!;
      costHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
      costHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
      assert.deepStrictEqual(rowPatterns(doc), ['alpha/**', 'mid/**', 'zebra/**']);
      assert.ok(costHeader.classList.contains('sort-desc'));
    });

    it('sorts the pattern column alphabetically as text, not numerically', () => {
      const { doc } = renderSortableTable();
      const patternHeader = doc.querySelector('th[data-sort="pattern"]')!;
      patternHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
      assert.deepStrictEqual(rowPatterns(doc), ['alpha/**', 'mid/**', 'zebra/**']);
    });

    it('clears the previous header sort indicator when a different column is clicked', () => {
      const { doc } = renderSortableTable();
      const filesHeader = doc.querySelector('th[data-sort="files"]')!;
      const costHeader = doc.querySelector('th[data-sort="cost"]')!;
      filesHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
      costHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
      assert.strictEqual(filesHeader.classList.contains('sort-asc'), false);
      assert.ok(costHeader.classList.contains('sort-asc'));
    });

    it('persists the chosen sort via vscode.setState so it survives a full-HTML re-render', () => {
      const { doc: doc1, api } = renderSortableTable();
      const filesHeader = doc1.querySelector('th[data-sort="files"]')!;
      filesHeader.dispatchEvent(new doc1.defaultView!.MouseEvent('click', { bubbles: true }));

      const persisted = api.getState();
      assert.deepStrictEqual(persisted, { sortKey: 'files', sortDir: 1 });

      // Simulates the extension calling webview.html = ... again: a brand
      // new document/script instance, but the SAME persisted state (which in
      // the real webview survives that reassignment via the extension host).
      const { doc: doc2 } = renderSortableTable(persisted);
      assert.deepStrictEqual(rowPatterns(doc2), ['zebra/**', 'mid/**', 'alpha/**']);
      const filesHeader2 = doc2.querySelector('th[data-sort="files"]')!;
      assert.ok(filesHeader2.classList.contains('sort-asc'));
    });
  });
});
