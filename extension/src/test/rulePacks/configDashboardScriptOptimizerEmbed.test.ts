/**
 * Executes the Config dashboard's embedded Analysis Optimizer wiring
 * (`SCRIPT_OPTIMIZER_EMBED` inside configDashboardScript.ts) against a real DOM — mirroring the
 * pattern already used for the standalone panel's own script
 * (analysisOptimizerScript.test.ts) so a runtime error in the embed path is caught the same way.
 *
 * This exercises the FULL `getConfigDashboardScript()` output (not just the embed fragment) since
 * that is what actually ships — the fixture below intentionally omits every element the OTHER
 * script sections (tabs, pack table, filters, etc.) look for, so those sections early-return and
 * only the embedded optimizer wiring does real work. That also doubles as a regression check for
 * plan §7's DOM-collision risk: if a future edit made the embed's selectors unscoped again, they
 * would start matching elements meant for those other sections instead of erroring loudly.
 */

import * as assert from 'assert';
import { JSDOM } from 'jsdom';
import { getConfigDashboardScript } from '../../rulePacks/configDashboardScript';

interface FakeVsCodeApi {
  postMessage: (m: unknown) => void;
  getState: () => unknown;
  setState: (s: unknown) => void;
}

/** Same fake as analysisOptimizerScript.test.ts's — JSON round-tripped to dodge cross-realm identity issues. */
function makeFakeVsCodeApi(messages: unknown[], initialState: unknown = undefined): FakeVsCodeApi {
  let state = initialState;
  return {
    postMessage: (m: unknown) => messages.push(JSON.parse(JSON.stringify(m))),
    getState: () => state,
    setState: (s: unknown) => { state = JSON.parse(JSON.stringify(s)); },
  };
}

/**
 * Minimal fixture mirroring the embedded optimizer markup
 * (`analysisOptimizerWebviewProvider.ts` `_buildExclusionsTable`/`_buildExclusionRow`, reused
 * verbatim for both the standalone panel and this embed) wrapped in `.optimizer-embed-body` —
 * the container `SCRIPT_OPTIMIZER_EMBED` scopes all of its queries to.
 */
function fixtureHtml(): string {
  const rows = [
    { pattern: 'zebra/**', files: 5, cost: 100, priority: 2, status: 0 },
    { pattern: 'alpha/**', files: 50, cost: 900, priority: 0, status: 1 },
    { pattern: 'mid/**', files: 20, cost: 400, priority: 1, status: 0 },
  ];
  const trs = rows
    .map(
      (r, i) => `
      <tr data-status="${r.status}" data-pattern="${r.pattern}" data-files="${r.files}" data-cost="${r.cost}" data-priority="${r.priority}">
        <td><input type="checkbox" class="rec-cb" data-index="${i}" data-pattern="${r.pattern}"></td>
        <td>${r.status}</td><td>${r.pattern}</td><td>${r.files}</td><td>${r.cost}</td><td>${r.priority}</td>
      </tr>`,
    )
    .join('');

  return `<!DOCTYPE html>
<html><body>
  <div class="optimizer-embed-body">
    <button id="apply-all-btn">Apply all</button>
    <button id="apply-selected-btn" disabled>Apply selected</button>
    <table id="exclusions-table">
      <thead>
        <tr>
          <th><input type="checkbox" id="select-all-cb"></th>
          <th class="sortable" data-sort="status">Status<span class="sort-indicator"></span></th>
          <th class="sortable" data-sort="pattern">Pattern<span class="sort-indicator"></span></th>
          <th class="sortable" data-sort="files">Files<span class="sort-indicator"></span></th>
          <th class="sortable" data-sort="cost">Cost<span class="sort-indicator"></span></th>
          <th class="sortable" data-sort="priority">Priority<span class="sort-indicator"></span></th>
        </tr>
      </thead>
      <tbody>${trs}</tbody>
    </table>
  </div>
  <script>${getConfigDashboardScript()}</script>
</body></html>`;
}

function render(initialState: unknown = undefined): { doc: Document; messages: unknown[]; api: FakeVsCodeApi } {
  const messages: unknown[] = [];
  const api = makeFakeVsCodeApi(messages, initialState);
  const dom = new JSDOM(fixtureHtml(), {
    runScripts: 'dangerously',
    beforeParse(window) {
      (window as unknown as { acquireVsCodeApi: () => FakeVsCodeApi }).acquireVsCodeApi = () => api;
    },
  });
  return { doc: dom.window.document, messages, api };
}

function rowPatterns(doc: Document): string[] {
  return [...doc.querySelectorAll('#exclusions-table tbody tr')].map(
    (tr) => tr.getAttribute('data-pattern') ?? '',
  );
}

describe('configDashboardScript SCRIPT_OPTIMIZER_EMBED (executed against a real DOM)', () => {
  it('select-all toggles every .rec-cb and enables apply-selected (§3a fix)', () => {
    const { doc } = render();
    const selectAll = doc.getElementById('select-all-cb') as HTMLInputElement;
    selectAll.checked = true;
    selectAll.dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));

    const boxes = [...doc.querySelectorAll<HTMLInputElement>('.rec-cb')];
    assert.strictEqual(boxes.every((b) => b.checked), true);
    assert.strictEqual((doc.getElementById('apply-selected-btn') as HTMLButtonElement).disabled, false);
  });

  it('unchecking every box re-disables apply-selected (§3a fix)', () => {
    const { doc } = render();
    const box = doc.querySelector<HTMLInputElement>('.rec-cb')!;
    box.checked = true;
    box.dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));
    assert.strictEqual((doc.getElementById('apply-selected-btn') as HTMLButtonElement).disabled, false);

    box.checked = false;
    box.dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));
    assert.strictEqual((doc.getElementById('apply-selected-btn') as HTMLButtonElement).disabled, true);
  });

  it('apply-selected posts only the checked patterns wrapped in the optimizerCommand envelope', () => {
    const { doc, messages } = render();
    const boxes = [...doc.querySelectorAll<HTMLInputElement>('.rec-cb')];
    boxes[0].checked = true;
    boxes[0].dispatchEvent(new doc.defaultView!.Event('change', { bubbles: true }));

    doc.getElementById('apply-selected-btn')!.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(messages, [
      { type: 'optimizerCommand', optimizer: { type: 'applySelected', patterns: ['zebra/**'] } },
    ]);
  });

  it('sorts numerically ascending on first click of a numeric column (§3b)', () => {
    const { doc } = render();
    const filesHeader = doc.querySelector('th[data-sort="files"]')!;
    filesHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(rowPatterns(doc), ['zebra/**', 'mid/**', 'alpha/**']);
    assert.ok(filesHeader.classList.contains('sort-asc'));
  });

  it('reverses to descending on a second click of the same column (§3b)', () => {
    const { doc } = render();
    const costHeader = doc.querySelector('th[data-sort="cost"]')!;
    costHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    costHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(rowPatterns(doc), ['alpha/**', 'mid/**', 'zebra/**']);
    assert.ok(costHeader.classList.contains('sort-desc'));
  });

  it('sorts the pattern column alphabetically as text, not numerically (§3b)', () => {
    const { doc } = render();
    const patternHeader = doc.querySelector('th[data-sort="pattern"]')!;
    patternHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));
    assert.deepStrictEqual(rowPatterns(doc), ['alpha/**', 'mid/**', 'zebra/**']);
  });

  it('persists sort state under state.optimizer, namespaced away from state.activeTab (§3b.2)', () => {
    const { doc, api } = render();
    const filesHeader = doc.querySelector('th[data-sort="files"]')!;
    filesHeader.dispatchEvent(new doc.defaultView!.MouseEvent('click', { bubbles: true }));

    const persisted = api.getState() as { optimizer?: { sortKey?: string; sortDir?: number }; activeTab?: string };
    assert.deepStrictEqual(persisted.optimizer, { sortKey: 'files', sortDir: 1 });
    // The dashboard's own tab-memory key must be untouched by the optimizer's sort click —
    // proves the two features are not sharing (and cannot clobber) the same state key.
    assert.strictEqual(persisted.activeTab, undefined);
  });

  it('restores a previously persisted sort on a fresh render without disturbing an existing activeTab key', () => {
    const { doc } = render({ activeTab: 'config', optimizer: { sortKey: 'cost', sortDir: -1 } });
    assert.deepStrictEqual(rowPatterns(doc), ['alpha/**', 'mid/**', 'zebra/**']);
    const costHeader = doc.querySelector('th[data-sort="cost"]')!;
    assert.ok(costHeader.classList.contains('sort-desc'));
  });
});
