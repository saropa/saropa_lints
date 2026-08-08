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
      (window as unknown as { acquireVsCodeApi: () => { postMessage: (m: unknown) => void } })
        .acquireVsCodeApi = () => ({
          postMessage: (m: unknown) => messages.push(JSON.parse(JSON.stringify(m))),
        });
    },
  });
  return { doc: dom.window.document, messages };
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
});
