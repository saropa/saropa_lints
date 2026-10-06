/**
 * Drives the REAL generated Rule packs page (RulePacksWebviewProvider._buildHtml) in jsdom,
 * not a hand-written fixture. Proves a finder "in <pack>" link reveals a pack row that lives
 * inside nested <details> far below the finder, and that search/finder/opened pack survive a
 * host rebuild (state round-trips through vscode.setState).
 */
import '../vibrancy/register-vscode-mock';
import * as assert from 'assert';
import * as path from 'node:path';
import { JSDOM } from 'jsdom';
import { RulePacksWebviewProvider } from '../../rulePacks/rulePacksWebviewProvider';
import { mockWorkspaceFolders } from '../vibrancy/vscode-mock';
import type * as vscode from 'vscode';

function buildRealHtml(): string {
  const repoRoot = path.resolve(__dirname, '../../../..');
  mockWorkspaceFolders.value = [{ uri: { fsPath: repoRoot } }];
  try {
    const mem = { get: <T>(_k: string, d?: T) => d as T, update: async () => {}, keys: () => [] } as unknown as vscode.Memento;
    const p = new RulePacksWebviewProvider({ fsPath: repoRoot } as unknown as vscode.Uri, mem);
    (p as unknown as { _activeTab: string })._activeTab = 'packs';
    return (p as unknown as { _buildHtml(): string })._buildHtml();
  } finally {
    mockWorkspaceFolders.value = undefined;
  }
}

interface Page { dom: JSDOM; doc: Document; getState: () => unknown; scrollTargets: Element[] }

function open(html: string, initialState: unknown): Page {
  let state = initialState;
  const scrollTargets: Element[] = [];
  const dom = new JSDOM(html, {
    runScripts: 'dangerously',
    pretendToBeVisual: true,
    beforeParse(w) {
      const win = w as unknown as Record<string, unknown>;
      win.acquireVsCodeApi = () => ({
        postMessage() {},
        getState: () => state,
        setState: (s: unknown) => { state = JSON.parse(JSON.stringify(s)); },
      });
      win.requestAnimationFrame = (cb: () => void) => { cb(); return 0; };
      w.HTMLElement.prototype.scrollIntoView = function (this: Element) { scrollTargets.push(this); };
      win.scrollTo = () => undefined;
    },
  });
  return { dom, doc: dom.window.document, getState: () => state, scrollTargets };
}

function typeSearch(p: Page, value: string): void {
  const input = p.doc.getElementById('pack-search') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new p.dom.window.Event('input', { bubbles: true }));
}

describe('Rule packs REAL page: finder reveals pack', () => {
  let html: string;
  const pages: Page[] = [];
  before(() => { html = buildRealHtml(); });
  afterEach(() => { while (pages.length) { pages.pop()!.dom.window.close(); } });
  const mk = (s?: unknown): Page => { const p = open(html, s); pages.push(p); return p; };

  it('clicking the Isar finder link opens every ancestor and focuses the checkbox', () => {
    const p = mk();
    const { doc } = p;
    typeSearch(p, 'isar');
    const link = doc.querySelector('#rule-finder .rf-pack[data-pack="isar"]') as HTMLElement;
    assert.ok(link, 'finder must offer an Isar pack link');
    link.dispatchEvent(new p.dom.window.MouseEvent('click', { bubbles: true, cancelable: true }));

    const row = doc.querySelector('tr[data-pack="isar"]') as HTMLElement;
    assert.ok(row, 'real page has an Isar row');
    let nestedDetails = 0;
    for (let n = row.parentElement; n; n = n.parentElement) {
      if (n.tagName === 'DETAILS') { nestedDetails++; assert.ok((n as HTMLDetailsElement).open, 'ancestor <details> open'); }
      assert.ok(!n.hidden, `ancestor ${n.tagName}#${n.id} must not be hidden`);
      assert.notStrictEqual(n.style.display, 'none');
    }
    assert.ok(nestedDetails >= 1, 'Isar row sits inside <details>');
    assert.ok(doc.getElementById('rt-panel-packs')!.contains(row), 'row is inside the packs panel');
    assert.strictEqual(doc.getElementById('rt-panel-packs')!.hidden, false, 'packs panel visible');
    assert.notStrictEqual(row.style.display, 'none');
    const detail = doc.querySelector('tr.rules-detail[data-detail-for="isar"]') as HTMLElement;
    assert.ok(detail, 'rules-detail row exists');
    assert.strictEqual(detail.hidden, false);
    assert.ok(row.classList.contains('pack-flash'));
    const cb = row.querySelector('input[type=checkbox][data-pack]');
    assert.strictEqual(doc.activeElement, cb, 'focus on the pack checkbox');
    assert.ok(p.scrollTargets.includes(row), 'scrollIntoView called on the pack row itself');
  });

  it('search, finder and opened Isar pack survive a rebuild', () => {
    const first = mk();
    typeSearch(first, 'isar');
    (first.doc.querySelector('#rule-finder .rf-pack[data-pack="isar"]') as HTMLElement)
      .dispatchEvent(new first.dom.window.MouseEvent('click', { bubbles: true, cancelable: true }));
    const saved = JSON.parse(JSON.stringify(first.getState()));

    const second = mk(saved);
    const { doc } = second;
    assert.strictEqual((doc.getElementById('pack-search') as HTMLInputElement).value, 'isar');
    const finder = doc.getElementById('rule-finder') as HTMLElement;
    assert.strictEqual(finder.hidden, false, 'finder visible after rebuild');
    assert.ok(finder.querySelector('.rf-pack[data-pack="isar"]'), 'finder content restored');
    const detail = doc.querySelector('tr.rules-detail[data-detail-for="isar"]') as HTMLElement;
    assert.strictEqual(detail.hidden, false, 'Isar rule list still open');
    const row = doc.querySelector('tr[data-pack="isar"]') as HTMLElement;
    assert.notStrictEqual(row.style.display, 'none');
  });
});
