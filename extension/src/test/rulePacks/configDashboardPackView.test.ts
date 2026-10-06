/**
 * Executes the Config dashboard script's Rule packs view wiring against a real DOM, covering
 * the v16.4.1 regressions:
 *
 *   - A host rebuild (`webview.html` reassignment) must not lose the pack search, filters or
 *     the rule lists the user opened — they round-trip through `vscode.setState`.
 *   - A "Matching rules" finder "in <pack>" link must reveal that pack's row (and its on/off
 *     toggle), even when another filter currently hides it.
 *   - A deferred refresh that turns out to be a no-op clears the "Update pending" hint.
 *
 * A rebuild is simulated by rendering a fresh DOM with the previous page's saved state, which
 * is exactly what VS Code hands the new document.
 */

import * as assert from 'assert';
import { JSDOM } from 'jsdom';
import { getConfigDashboardScript } from '../../rulePacks/configDashboardScript';

interface FakeVsCodeApi {
  postMessage: (m: unknown) => void;
  getState: () => unknown;
  setState: (s: unknown) => void;
}

function makeFakeVsCodeApi(messages: unknown[], initialState: unknown): FakeVsCodeApi {
  let state = initialState;
  return {
    postMessage: (m: unknown) => messages.push(JSON.parse(JSON.stringify(m))),
    getState: () => state,
    setState: (s: unknown) => { state = JSON.parse(JSON.stringify(s)); },
  };
}

function packRow(id: string, label: string, rules: string[], enabled: boolean): string {
  const links = rules.map((r) => `<a href="#" class="rule-link" data-rule="${r}">${r}</a>`).join(' ');
  return `
    <tr data-pack="${id}" data-type="package" data-detected="1" data-enabled="${enabled ? '1' : '0'}"
        data-rules="${rules.length}" data-label="${label.toLowerCase()}" data-pack-label="${label}"
        data-rules-text="${rules.join(' ')}" data-domain="database">
      <td><input type="checkbox" data-pack="${id}"${enabled ? ' checked' : ''}></td>
      <td>${label}</td>
      <td><button type="button" class="rules-toggle" data-pack="${id}" aria-expanded="false">${rules.length} rules</button></td>
    </tr>
    <tr class="rules-detail" data-detail-for="${id}" hidden><td colspan="6"><div class="rules-detail-body">${links}</div></td></tr>`;
}

function fixtureHtml(): string {
  return `<!DOCTYPE html>
<html><body>
  <p><span id="refresh-pending-indicator" hidden>Update pending</span></p>
  <input id="pack-search" type="search" />
  <span id="pack-match-count" hidden></span>
  <select id="type-filter"><option value="all">All types</option><option value="sdk">SDK</option><option value="package">Package</option></select>
  <button class="seg-btn" data-toggle-filter="detected" aria-pressed="false">Detected</button>
  <button class="seg-btn" data-toggle-filter="enabled" aria-pressed="false">Enabled</button>
  <div id="filter-strip" hidden></div>
  <div class="rule-finder" id="rule-finder" hidden></div>
  <details id="packs-all">
    <summary>All packages</summary>
    <table><tbody class="packs-tbody">
      ${packRow('isar', 'Isar', ['avoid_cached_isar_stream', 'require_isar_id_field'], false)}
      ${packRow('drift', 'Drift', ['avoid_isar_import_with_drift', 'require_drift_database_close'], true)}
    </tbody></table>
  </details>
  <script>${getConfigDashboardScript()}</script>
</body></html>`;
}

interface Rendered {
  dom: JSDOM;
  doc: Document;
  messages: unknown[];
  api: FakeVsCodeApi;
}

function render(initialState: unknown = undefined): Rendered {
  const messages: unknown[] = [];
  const api = makeFakeVsCodeApi(messages, initialState);
  const dom = new JSDOM(fixtureHtml(), {
    runScripts: 'dangerously',
    beforeParse(window) {
      (window as unknown as { acquireVsCodeApi: () => FakeVsCodeApi }).acquireVsCodeApi = () => api;
      // jsdom implements neither; the script calls both.
      window.HTMLElement.prototype.scrollIntoView = () => undefined;
      window.scrollTo = (() => undefined) as typeof window.scrollTo;
    },
  });
  return { dom, doc: dom.window.document, messages, api };
}

function typeSearch(r: Rendered, text: string): void {
  const input = r.doc.getElementById('pack-search') as HTMLInputElement;
  input.value = text;
  input.dispatchEvent(new r.dom.window.Event('input', { bubbles: true }));
}

function click(r: Rendered, el: Element): void {
  el.dispatchEvent(new r.dom.window.MouseEvent('click', { bubbles: true, cancelable: true }));
}

function detailHidden(doc: Document, packId: string): boolean {
  return (doc.querySelector(`tr.rules-detail[data-detail-for="${packId}"]`) as HTMLElement).hidden === true;
}

describe('configDashboardScript Rule packs view (executed against a real DOM)', () => {
  it('restores the search and the Matching rules finder after a host rebuild', () => {
    const first = render();
    typeSearch(first, 'isar');
    const finder = first.doc.getElementById('rule-finder')!;
    assert.strictEqual(finder.hidden, false);

    const rebuilt = render(first.api.getState());
    assert.strictEqual((rebuilt.doc.getElementById('pack-search') as HTMLInputElement).value, 'isar');
    const rebuiltFinder = rebuilt.doc.getElementById('rule-finder')!;
    assert.strictEqual(rebuiltFinder.hidden, false);
    assert.strictEqual(rebuiltFinder.querySelectorAll('.rf-rule').length, 3);
  });

  it('restores Detected/Enabled and type filters after a host rebuild', () => {
    const first = render();
    click(first, first.doc.querySelector('.seg-btn[data-toggle-filter="enabled"]')!);

    const rebuilt = render(first.api.getState());
    const enabledBtn = rebuilt.doc.querySelector('.seg-btn[data-toggle-filter="enabled"]')!;
    assert.strictEqual(enabledBtn.getAttribute('aria-pressed'), 'true');
    const isarRow = rebuilt.doc.querySelector('tr[data-pack="isar"]') as HTMLElement;
    assert.strictEqual(isarRow.style.display, 'none');
  });

  it('finder pack link reveals the pack row, opens its rules and focuses its toggle', () => {
    const r = render();
    typeSearch(r, 'isar');
    const link = r.doc.querySelector('#rule-finder .rf-pack[data-pack="isar"]')!;
    click(r, link);

    assert.strictEqual((r.doc.getElementById('packs-all') as HTMLDetailsElement).open, true);
    assert.strictEqual(detailHidden(r.doc, 'isar'), false);
    const row = r.doc.querySelector('tr[data-pack="isar"]')!;
    assert.ok(row.classList.contains('pack-flash'));
    assert.strictEqual(r.doc.activeElement, row.querySelector('input[type=checkbox][data-pack]'));
  });

  it('finder pack link clears a filter that hides the pack but keeps the search', () => {
    const r = render();
    // "Enabled" hides the (disabled) Isar pack, but the finder still lists it by search match.
    click(r, r.doc.querySelector('.seg-btn[data-toggle-filter="enabled"]')!);
    typeSearch(r, 'isar');
    const row = r.doc.querySelector('tr[data-pack="isar"]') as HTMLElement;
    assert.strictEqual(row.style.display, 'none');

    click(r, r.doc.querySelector('#rule-finder .rf-pack[data-pack="isar"]')!);
    assert.strictEqual(row.style.display, '');
    assert.strictEqual(
      r.doc.querySelector('.seg-btn[data-toggle-filter="enabled"]')!.getAttribute('aria-pressed'),
      'false',
    );
    assert.strictEqual((r.doc.getElementById('pack-search') as HTMLInputElement).value, 'isar');
  });

  it('keeps a pack opened from the finder open across a host rebuild', () => {
    const first = render();
    // "isar" matches the Isar pack by label, so the search alone would keep its rules collapsed.
    typeSearch(first, 'isar');
    assert.strictEqual(detailHidden(first.doc, 'isar'), true);
    click(first, first.doc.querySelector('#rule-finder .rf-pack[data-pack="isar"]')!);

    const rebuilt = render(first.api.getState());
    assert.strictEqual(detailHidden(rebuilt.doc, 'isar'), false);
  });

  it('a new search forgets rule lists opened for the previous one', () => {
    const r = render();
    typeSearch(r, 'isar');
    click(r, r.doc.querySelector('#rule-finder .rf-pack[data-pack="isar"]')!);
    typeSearch(r, 'isa');
    assert.strictEqual(detailHidden(r.doc, 'isar'), true);
  });

  it('clears the "Update pending" hint when the host skips a no-op refresh', () => {
    const r = render();
    const indicator = r.doc.getElementById('refresh-pending-indicator') as HTMLElement;
    r.dom.window.dispatchEvent(new r.dom.window.MessageEvent('message', { data: { type: 'refreshPending' } }));
    assert.strictEqual(indicator.hidden, false);
    r.dom.window.dispatchEvent(new r.dom.window.MessageEvent('message', { data: { type: 'refreshSkipped' } }));
    assert.strictEqual(indicator.hidden, true);
  });
});
