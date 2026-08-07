/**
 * Executes the report's inline script against a real DOM.
 *
 * Every other test in this feature asserts on the HTML *string* — that a
 * control appears, that the script parses. None of them proved a single control
 * WORKS. A runtime error inside the inline script would leave the page static
 * with the filter, the mode toggles, expand-all, and the column sort all dead,
 * and the whole suite would still pass. That was the largest untested surface
 * at hand-off; this file closes it.
 *
 * jsdom does not enforce the document's Content-Security-Policy, so the inline
 * script runs under `runScripts: 'dangerously'`. That is exactly what is wanted
 * here — the CSP shape is asserted separately as a string, and what needs
 * proving in this file is the behavior.
 */

import '../register-vscode-mock';
import * as assert from 'assert';
import { JSDOM } from 'jsdom';
import { buildFeatureInventoryHtml } from '../../../vibrancy/views/feature-inventory-html';
import { api, feature, pkg, report } from './feature-inventory-fixture';

/** Render the fixture model and evaluate the document, script included. */
function render(model = defaultModel()): Document {
    const dom = new JSDOM(buildFeatureInventoryHtml(model), {
        runScripts: 'dangerously',
    });
    return dom.window.document;
}

/**
 * Three packages spanning the states the controls discriminate: one adopted,
 * one unused, one deprecated, plus a package with no changelog at all — that
 * last one is the filter's documented edge case.
 */
function defaultModel() {
    return report([
        pkg({
            name: 'adopted_pkg',
            features: [feature({
                description: 'Adds ReelText for animated text.',
                apis: [api('ReelText', 3)],
            })],
        }),
        pkg({
            name: 'unused_pkg',
            features: [feature({
                description: 'Adds SparkleBox decoration.',
                apis: [api('SparkleBox', 0)],
            })],
        }),
        pkg({
            name: 'deprecated_pkg',
            features: [feature({
                category: 'deprecated',
                description: 'Deprecates LegacyThing.',
                apis: [api('LegacyThing', 0)],
            })],
        }),
        pkg({
            name: 'no_changelog_pkg',
            changelogAvailable: false,
            features: [],
        }),
    ]);
}

function visibleFeatures(doc: Document): string[] {
    return [...doc.querySelectorAll('.fi-feature:not(.fi-hidden)')]
        .map(n => n.getAttribute('data-text') ?? '');
}

function clickMode(doc: Document, mode: string): void {
    const button = doc.querySelector(`.fi-mode[data-mode="${mode}"]`);
    assert.ok(button, `no mode button for ${mode}`);
    (button as HTMLElement).click();
}

function typeFilter(doc: Document, text: string): void {
    const box = doc.getElementById('fi-search') as HTMLInputElement | null;
    assert.ok(box, 'no filter box');
    box.value = text;
    box.dispatchEvent(new (box.ownerDocument.defaultView as Window & typeof globalThis).Event(
        'input', { bubbles: true },
    ));
}

describe('feature-inventory report behavior in a DOM', () => {
    it('runs its inline script without error and wires every control', () => {
        const doc = render();
        // Proof the script executed at all: the handlers below only exist if it
        // did, and each control is asserted present so a rename fails loudly.
        assert.ok(doc.getElementById('fi-search'), 'filter box');
        assert.ok(doc.getElementById('fi-expand'), 'expand button');
        assert.ok(doc.getElementById('fi-collapse'), 'collapse button');
        assert.ok(doc.getElementById('fi-summary'), 'summary table');
        assert.ok(doc.querySelectorAll('.fi-mode').length >= 3, 'mode buttons');
        assert.strictEqual(
            visibleFeatures(doc).length, 3, 'all features visible before filtering',
        );
    });

    it('expand-all opens every disclosure and collapse-all closes them', () => {
        const doc = render();
        const details = () => [...doc.querySelectorAll('details')];
        assert.ok(details().length > 0, 'fixture produced no disclosures');

        (doc.getElementById('fi-expand') as HTMLElement).click();
        assert.ok(details().every(d => d.open), 'expand-all left a disclosure shut');

        (doc.getElementById('fi-collapse') as HTMLElement).click();
        assert.ok(details().every(d => !d.open), 'collapse-all left a disclosure open');
    });

    it('filters features by text and hides groups left empty', () => {
        const doc = render();
        typeFilter(doc, 'sparklebox');

        const shown = visibleFeatures(doc);
        assert.strictEqual(shown.length, 1);
        assert.ok(shown[0].indexOf('sparklebox') !== -1, shown[0]);

        const hiddenPackages = [...doc.querySelectorAll('.fi-package.fi-hidden')];
        assert.ok(hiddenPackages.length > 0, 'no group was hidden by the filter');
    });

    it('never filters away a package that has no features to match', () => {
        // The documented edge case: a package with no changelog carries a
        // disclosed note instead of rows, so a query it cannot match must not
        // erase the evidence that it was scanned.
        const doc = render();
        typeFilter(doc, 'sparklebox');

        const survivors = [...doc.querySelectorAll('.fi-package:not(.fi-hidden)')];
        const ids = survivors.map(n => n.getAttribute('id') ?? '');
        assert.ok(
            ids.some(id => id.indexOf('no_changelog_pkg') !== -1),
            `changelog-less package was filtered away: ${ids.join(', ')}`,
        );
    });

    it('restores everything when the filter is cleared', () => {
        const doc = render();
        typeFilter(doc, 'sparklebox');
        assert.strictEqual(visibleFeatures(doc).length, 1);

        typeFilter(doc, '');
        assert.strictEqual(visibleFeatures(doc).length, 3, 'clearing did not restore');
    });

    it('unused-only and used-only select opposite feature sets', () => {
        const doc = render();

        clickMode(doc, 'unused');
        const unused = visibleFeatures(doc);
        assert.ok(unused.length > 0, 'unused-only hid everything');
        assert.ok(
            unused.every(t => t.indexOf('reeltext') === -1),
            'an adopted feature survived unused-only',
        );

        clickMode(doc, 'unused');   // toggling the active mode returns to all
        assert.strictEqual(visibleFeatures(doc).length, 3, 'mode did not toggle off');

        clickMode(doc, 'used');
        const used = visibleFeatures(doc);
        assert.ok(
            used.every(t => t.indexOf('sparklebox') === -1),
            'an unused feature survived used-only',
        );
    });

    it('deprecated-only selects by category, not by usage', () => {
        const doc = render();
        clickMode(doc, 'deprecated');
        const shown = visibleFeatures(doc);
        assert.strictEqual(shown.length, 1);
        assert.ok(shown[0].indexOf('legacything') !== -1, shown[0]);
    });

    it('sorts the summary table by a column and reverses on a second click', () => {
        const doc = render();
        const table = doc.getElementById('fi-summary') as HTMLTableElement;
        const header = table.querySelectorAll('thead th')[0] as HTMLElement;
        const names = (): string[] => [...table.tBodies[0].rows]
            .map(r => r.cells[0].getAttribute('data-sort') ?? '');

        const before = names();
        assert.strictEqual(before.length, 4, 'fixture row count');

        header.click();
        const descending = names();
        assert.deepStrictEqual(
            descending, [...before].sort().reverse(), 'first click should sort descending',
        );

        header.click();
        assert.deepStrictEqual(
            names(), [...before].sort(), 'second click should reverse the order',
        );
    });

    it('opens the ancestors of a package linked from the summary table', () => {
        // Clicking a summary row jumps to an anchor inside a collapsed
        // disclosure; without the hash handler the reader lands on nothing.
        const dom = new JSDOM(buildFeatureInventoryHtml(defaultModel()), {
            runScripts: 'dangerously',
        });
        const doc = dom.window.document;
        const link = doc.querySelector('#fi-summary tbody a') as HTMLAnchorElement;
        const anchor = link.getAttribute('href') ?? '';
        assert.ok(anchor.startsWith('#'), anchor);

        const target = doc.getElementById(anchor.substring(1));
        assert.ok(target, `no element for ${anchor}`);

        dom.window.location.hash = anchor;
        dom.window.dispatchEvent(new dom.window.Event('hashchange'));

        let node: Element | null = target;
        while (node) {
            if (node.tagName === 'DETAILS') {
                assert.ok((node as HTMLDetailsElement).open, 'ancestor left closed');
            }
            node = node.parentElement;
        }
    });
});
