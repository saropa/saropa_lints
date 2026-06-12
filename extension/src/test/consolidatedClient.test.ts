/**
 * Headless execution coverage for the consolidated dashboard's webview client.
 *
 * The client ([getConsolidatedClient]) is an un-typechecked template-literal
 * string that runs inside the webview — the compiler never sees it, so a syntax
 * slip, a reference error, or a regex literal mangled by template-literal
 * escaping would ship undetected and only surface as a blank dashboard on a real
 * render. These tests EXECUTE the string against a minimal recording-DOM harness
 * (no jsdom dependency — the client uses a small, stubbable DOM surface) so the
 * load path, the `model` patch path, and the `occurrences` render path all run
 * in CI. They cannot replace a visual render (pixels, theme, real event
 * bubbling), but they convert "never executed" into "executes and patches the
 * expected nodes".
 */

import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { getConsolidatedClient } from '../views/consolidated/consolidatedClient';

/* ----------------------------- recording DOM ----------------------------- */

interface StubEl {
  id: string;
  textContent: string;
  innerHTML: string;
  value: string;
  className: string;
  dataset: Record<string, string>;
  _style: Record<string, string>;
  _attrs: Record<string, string>;
  _q: Record<string, StubEl>;
  _children: StubEl[];
  _removed: boolean;
  style: { setProperty(k: string, v: string): void };
  classList: {
    _set: Set<string>;
    toggle(c: string, on?: boolean): void;
    add(c: string): void;
    remove(c: string): void;
    contains(c: string): boolean;
  };
  _listeners: Record<string, Array<(e: unknown) => void>>;
  setAttribute(k: string, v: string): void;
  getAttribute(k: string): string | undefined;
  addEventListener(type: string, fn: (e: unknown) => void): void;
  appendChild(child: StubEl): StubEl;
  remove(): void;
  // querySelector caches per selector so a node patched after creation
  // (occ.innerHTML = …) is the SAME node a later read sees — faithful enough to
  // assert on without parsing innerHTML.
  querySelector(sel: string): StubEl;
  querySelectorAll(): StubEl[];
}

function makeEl(id: string): StubEl {
  const el: StubEl = {
    id,
    textContent: '',
    innerHTML: '',
    value: '',
    className: '',
    dataset: {},
    _style: {},
    _attrs: {},
    _q: {},
    _children: [],
    _removed: false,
    style: { setProperty: (k, v) => { el._style[k] = v; } },
    classList: {
      _set: new Set<string>(),
      toggle(c, on) {
        const want = on === undefined ? !this._set.has(c) : on;
        if (want) this._set.add(c); else this._set.delete(c);
      },
      add(c) { this._set.add(c); },
      remove(c) { this._set.delete(c); },
      contains(c) { return this._set.has(c); },
    },
    _listeners: {},
    setAttribute(k, v) { el._attrs[k] = v; },
    getAttribute(k) { return el._attrs[k]; },
    addEventListener(type, fn) { (el._listeners[type] ||= []).push(fn); },
    appendChild(child) { el._children.push(child); return child; },
    remove() { el._removed = true; },
    querySelector(sel) { return el._q[sel] ||= makeEl(`${id}>${sel}`); },
    querySelectorAll() { return []; },
  };
  // A real DOM coerces the textContent setter to a string (the client assigns a
  // raw number, e.g. gaugeScore.textContent = m.score). Mirror that so the stub
  // reflects what the browser would store, not the raw assigned value.
  let text = '';
  Object.defineProperty(el, 'textContent', {
    get: () => text,
    set: (v: unknown) => { text = v === null || v === undefined ? '' : String(v); },
    enumerable: true,
  });
  return el;
}

interface Harness {
  document: { getElementById(id: string): StubEl; createElement(tag: string): StubEl };
  window: { SL: Record<string, string>; addEventListener(type: string, fn: (e: unknown) => void): void };
  acquireVsCodeApi(): { postMessage(m: unknown): void };
  byId: Record<string, StubEl>;
  created: StubEl[];
  messageHandlers: Array<(e: unknown) => void>;
  posted: unknown[];
}

function makeHarness(): Harness {
  const byId: Record<string, StubEl> = {};
  const created: StubEl[] = [];
  const messageHandlers: Array<(e: unknown) => void> = [];
  const posted: unknown[] = [];
  return {
    byId,
    created,
    messageHandlers,
    posted,
    document: {
      getElementById: (id) => byId[id] ||= makeEl(id),
      createElement: (tag) => { const el = makeEl(tag); created.push(el); return el; },
    },
    window: {
      SL: { fetching: 'Fetching…', noOccurrences: 'No occurrences' },
      addEventListener: (type, fn) => { if (type === 'message') messageHandlers.push(fn); },
    },
    acquireVsCodeApi: () => ({ postMessage: (m) => { posted.push(m); } }),
  };
}

// Execute the client string with the harness symbols injected as params (they
// shadow the absent globals). Returns the harness for assertions.
function runClient(): Harness {
  const h = makeHarness();
  // eslint-disable-next-line no-new-func
  const run = new Function('document', 'window', 'acquireVsCodeApi', getConsolidatedClient());
  run(h.document, h.window, h.acquireVsCodeApi);
  return h;
}

// Pull a single `function name(...) {...}` out of the client and make it
// callable, brace-balanced (the same technique the scanning-state test uses).
function extractFn(name: string): (...args: unknown[]) => unknown {
  const src = getConsolidatedClient();
  const start = src.indexOf(`function ${name}(`);
  if (start < 0) throw new Error(`${name} not found in client`);
  let depth = 0;
  let end = src.indexOf('{', start);
  for (let i = end; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}' && --depth === 0) { end = i + 1; break; }
  }
  // eslint-disable-next-line no-eval
  return eval(`(${src.slice(start, end)})`) as (...args: unknown[]) => unknown;
}

function modelMessage(): unknown {
  return {
    data: {
      type: 'model',
      score: 87,
      grade: 'B',
      color: '#3aa',
      label: 'Good',
      summaryLine: '12 findings · 5 rules',
      chips: [
        { kind: 'error', n: 2, label: 'Errors' },
        { kind: '', n: 5, label: 'Files' },
      ],
      groups: [{ rule: 'avoid_print', count: 3, worst: 'warning' }],
    },
  };
}

/* -------------------------------- tests ---------------------------------- */

describe('consolidated dashboard client (headless execution)', () => {
  it('loads without throwing, acquires the API, and posts ready', () => {
    const h = runClient();
    assert.deepStrictEqual(h.posted, [{ type: 'ready' }]);
    assert.strictEqual(h.messageHandlers.length, 1, 'no message listener registered');
  });

  it('esc() escapes HTML entities — proves the regex literals survived', () => {
    // The memory trap: a backslash in a regex inside a template literal can be
    // eaten. esc uses /&/g, /</g, /</g, /"/g; eval-ing it confirms they work.
    const esc = extractFn('esc') as (s: unknown) => string;
    assert.strictEqual(esc('<a href="x">b&c</a>'), '&lt;a href=&quot;x&quot;&gt;b&amp;c&lt;/a&gt;');
    assert.strictEqual(esc(null), '');
    assert.strictEqual(esc(undefined), '');
  });

  it('a model message patches the gauge, grade label, summary, and chips', () => {
    const h = runClient();
    h.messageHandlers[0](modelMessage());
    assert.strictEqual(h.byId.gauge._style['--gauge-val'], '87');
    assert.strictEqual(h.byId.gauge._style['--gauge-col'], '#3aa');
    assert.strictEqual(h.byId.gaugeGrade.textContent, 'B');
    assert.strictEqual(h.byId.gaugeScore.textContent, '87');
    assert.strictEqual(h.byId.gradeLabel.textContent, 'Good');
    assert.strictEqual(h.byId.summary.textContent, '12 findings · 5 rules');
    assert.ok(h.byId.chips.innerHTML.includes('Errors'), 'chip label not rendered');
    assert.ok(h.byId.chips.innerHTML.includes('Files'), 'second chip not rendered');
  });

  it('a model message builds a group row and toggles the empty state off', () => {
    const h = runClient();
    h.messageHandlers[0](modelMessage());
    // reconcile appendChild's the created group into #groups, and hides #empty.
    assert.strictEqual(h.byId.groups._children.length, 1, 'group row not appended');
    assert.strictEqual(h.byId.empty.classList.contains('hidden'), true, 'empty state not hidden');
    // The created group carries its rule on the dataset (navigation key).
    assert.strictEqual(h.created[0].dataset.rule, 'avoid_print');
  });

  it('an occurrences message renders rows into the matching group without throwing', () => {
    const h = runClient();
    h.messageHandlers[0](modelMessage());
    h.messageHandlers[0]({
      data: {
        type: 'occurrences',
        rule: 'avoid_print',
        items: [{ file: 'lib/a.dart', line: 3, message: 'avoid print' }],
        more: '',
      },
    });
    // renderOcc writes into the group's `.occ` child (querySelector is cached,
    // so this is the same node the client wrote).
    const occ = h.created[0].querySelector('.occ');
    assert.ok(occ.innerHTML.includes('lib/a.dart'), 'occurrence file not rendered');
    assert.ok(occ.innerHTML.includes('avoid print'), 'occurrence message not rendered');
  });

  it('an empty model shows the empty state and hides the group list', () => {
    const h = runClient();
    h.messageHandlers[0]({
      data: {
        type: 'model', score: 100, grade: 'A', color: '#0a0', label: 'Excellent',
        summaryLine: '0 findings · 0 rules', chips: [], groups: [],
      },
    });
    assert.strictEqual(h.byId.empty.classList.contains('hidden'), false, 'empty state hidden on 0 groups');
    assert.strictEqual(h.byId.groups.classList.contains('hidden'), true, 'group list shown on 0 groups');
  });
});
