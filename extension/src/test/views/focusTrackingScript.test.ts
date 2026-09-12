/**
 * Executes the shared focus-tracking script (dashboardHero.getFocusTrackingScript)
 * against a real DOM, following analysisOptimizerScript.test.ts: asserting on the
 * emitted string alone would not show which controls actually latch
 * `_userInteracting` on the host side.
 *
 * The contract under test: only controls holding *uncommitted keystrokes* may
 * post `uiFocus`. A checkbox or `<select>` commits its value on change and then
 * keeps focus, so counting it would queue the redraw its own change asked for
 * behind a `uiBlur` that never fires — the Config Dashboard's pack toggle would
 * sit permanently on "Update pending".
 */

import * as assert from 'assert';
import { JSDOM } from 'jsdom';
import { getFocusTrackingScript } from '../../views/dashboardHero';

/** Renders the fixture with a `vscode` stub that records posted message types. */
function render(): { doc: Document; types: () => string[] } {
  const posted: string[] = [];
  const html = `<!DOCTYPE html>
<html><body>
  <input id="search" type="search">
  <input id="untyped">
  <textarea id="notes"></textarea>
  <div id="rich" contenteditable="true" tabindex="0"></div>
  <div id="readonlyRich" contenteditable="false" tabindex="0"></div>
  <input id="packToggle" type="checkbox">
  <input id="tierRadio" type="radio">
  <select id="typeFilter"><option>a</option></select>
  <button id="run">Run</button>
  <script>
    var vscode = { postMessage: function(m) { window.__posted.push(String(m.type)); } };
  </script>
  <script>${getFocusTrackingScript()}</script>
</body></html>`;

  const dom = new JSDOM(html, {
    runScripts: 'dangerously',
    beforeParse(window) {
      (window as unknown as { __posted: string[] }).__posted = posted;
    },
  });
  return { doc: dom.window.document, types: () => [...posted] };
}

/** Lets the script's deferred (setTimeout 0) focusout handler run. */
function flush(): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, 0));
}

function focus(doc: Document, id: string): void {
  (doc.getElementById(id) as HTMLElement).focus();
}

describe('getFocusTrackingScript (executed against a real DOM)', () => {
  for (const id of ['search', 'untyped', 'notes', 'rich']) {
    it(`defers a refresh while #${id} holds focus`, () => {
      const { doc, types } = render();
      focus(doc, id);
      assert.deepStrictEqual(types(), ['uiFocus']);
    });
  }

  for (const id of ['packToggle', 'tierRadio', 'typeFilter', 'run', 'readonlyRich']) {
    it(`does not defer a refresh for #${id}`, () => {
      const { doc, types } = render();
      focus(doc, id);
      assert.deepStrictEqual(types(), []);
    });
  }

  it('releases the gate when focus moves from a text field to a checkbox', async () => {
    // The Config Dashboard case: the user types in the rule search box, then
    // clicks a pack toggle. The toggle's own refresh() must not be stranded.
    const { doc, types } = render();
    focus(doc, 'search');
    focus(doc, 'packToggle');
    await flush();
    assert.deepStrictEqual(types(), ['uiFocus', 'uiBlur']);
  });

  it('holds the gate while tabbing between two text fields', async () => {
    const { doc, types } = render();
    focus(doc, 'search');
    focus(doc, 'notes');
    await flush();
    assert.deepStrictEqual(types(), ['uiFocus', 'uiFocus']);
  });
});
