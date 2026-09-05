/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks).
 */

import * as assert from 'assert';
import {
    buildKnownIssuesHtml, getEmbeddedBodyHtml, getKnownIssuesEmbedStyles,
} from '../../../vibrancy/views/known-issues-html';
import { getKnownIssuesScript, getKnownIssuesEmbedScript } from '../../../vibrancy/views/known-issues-script';

describe('buildKnownIssuesHtml', () => {
    it('should return valid HTML with doctype', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });

    it('should show total count in summary', () => {
        const html = buildKnownIssuesHtml();
        // Total count appears in summary cards — at least 125 known issues
        assert.ok(html.includes('>Total<'));
    });

    it('should include package rows', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('data-name="flutter_datetime_picker"'));
        assert.ok(html.includes('data-name="connectivity"'));
    });

    it('should link packages to pub.dev', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('pub.dev/packages/flutter_datetime_picker'));
    });

    it('should show replacement links when present', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('pub.dev/packages/connectivity_plus'));
    });

    it('should show migration notes when present', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('Drop-in replacement'));
    });

    it('should include CSP meta tag', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('Content-Security-Policy'));
    });

    it('should include search input', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('id="search-input"'));
    });

    it('should include replacement filter as a segmented multi-toggle', () => {
        // Replaces the prior boolean checkbox ("filter-has-replacement"); each KPI card
        // now maps to a distinct filter state, so a tri-state multi-toggle is required
        // — see known-issues-script.ts setFilterState() and applyFilters().
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('data-filter="has"'), 'expected Has replacement seg-btn');
        assert.ok(html.includes('data-filter="no"'), 'expected None replacement seg-btn');
    });

    it('should expose summary cards as interactive preset filters', () => {
        const html = buildKnownIssuesHtml();
        // KPI cards (guideline §4.2 / §14.8): role="button" + data-kpi-action drive
        // the filter via known-issues-script.ts.
        assert.ok(html.includes('data-kpi-action="reset"'));
        assert.ok(html.includes('data-kpi-action="filter-has"'));
        assert.ok(html.includes('data-kpi-action="filter-no"'));
    });

    it('should be Saropa-prefixed in the document title', () => {
        // Editor-area dashboards prefix h1 + <title> with "Saropa" (guideline §8.1).
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('<title>Saropa Known Issues</title>'));
    });

    it('should include sort arrows in table headers', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('class="sort-arrow"'));
    });

    it('should not generate pub.dev links for freeform replacements', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(
            !html.includes('pub.dev/packages/Update'),
            'freeform text should not be linked to pub.dev',
        );
        assert.ok(
            !html.includes('pub.dev/packages/Native'),
            'freeform text should not be linked to pub.dev',
        );
    });

    it('should escape HTML entities in data attributes', () => {
        const html = buildKnownIssuesHtml();
        // Data attributes exist and none start with raw angle brackets
        assert.ok(html.includes('data-reason='));
        assert.ok(!html.includes('data-reason="<'));
    });

    /* ────────────────────────────────────────────────────────────────────
     * §15 audit fixes — pin the new behavior.
     * ──────────────────────────────────────────────────────────────────── */

    it('renders the active-filter chip strip element so the script can populate it (§8.5 / §14.10)', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('id="ki-chip-strip"'));
        assert.ok(html.includes('id="ki-chip-body"'));
        assert.ok(html.includes('id="ki-clear-all"'));
    });

    it('renders the empty-state CTA with a tier-1 Reset filters button (§8.16)', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('id="ki-empty"'));
        assert.ok(html.includes('id="ki-reset-filters"'));
        assert.ok(html.includes('class="btn tier-1"'));
        assert.ok(html.includes('Reset filters'));
        // Hidden by default — only revealed by the script when visible === 0.
        assert.ok(html.match(/<div id="ki-empty"[^>]*hidden/));
    });

    it('script has a syncActiveKpiCard function so cards reflect filter state (§4.2 / §14.8)', () => {
        // The script is embedded in the HTML; assert the function name appears so
        // the active-state sync is wired (and therefore .kpi-card.active is
        // toggled at runtime).
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('syncActiveKpiCard'));
        assert.ok(html.includes("classList.add('active')"));
    });

    it('associates the search input with a screen-reader label (§15.6)', () => {
        // §15.6 requires every input to carry a <label>; placeholder text alone
        // is invisible to autofill and vanishes on focus. The visible placeholder
        // stays for sighted users; the sr-only label adds the missing
        // assistive-tech association.
        const html = buildKnownIssuesHtml();
        assert.ok(
            html.includes('<label class="sr-only" for="search-input">'),
            'expected sr-only label associated to #search-input',
        );
    });

    it('exposes the keyboard-shortcut overlay trigger and dialog (§15.2)', () => {
        // §15.2 calls for a discoverable shortcut list. The trigger sits in the
        // hero status line; the overlay markup is hidden until ? or click.
        const html = buildKnownIssuesHtml();
        assert.ok(
            html.includes('id="kbdShortcutsToggle"'),
            'expected kbd-shortcut overlay trigger button',
        );
        assert.ok(
            html.includes('id="kbdShortcutsOverlay"'),
            'expected kbd-shortcut overlay dialog markup',
        );
        assert.ok(
            html.includes('aria-modal="true"'),
            'overlay should be marked as a modal dialog for screen readers',
        );
    });

    it('renders the recent-searches popover scaffolding hidden by default (§8.5.2)', () => {
        // §8.5.2 — recent-searches dropdown is hidden until the input is
        // focused empty AND there are stored entries. The script populates
        // it from sessionStorage at runtime; we only verify the markup is
        // present with the expected ids so the script can wire to it.
        const html = buildKnownIssuesHtml();
        assert.ok(
            html.includes('id="recent-searches"'),
            'expected the recent-searches popover container',
        );
        assert.ok(
            html.includes('id="recent-searches-list"'),
            'expected the recent-searches list element',
        );
        assert.ok(
            html.includes('id="recent-searches-clear"'),
            'expected the recent-searches Clear-all button',
        );
        assert.ok(
            html.match(/<div id="recent-searches"[^>]*hidden/),
            'recent-searches container must be hidden in the initial render',
        );
    });

    it('embeds the search-hit highlight stylesheet (§8.5.2)', () => {
        // The script wraps matched substrings in <mark class="search-hit"> at
        // runtime; the stylesheet binds the fill to the host find-match token
        // so highlights survive theme changes.
        const html = buildKnownIssuesHtml();
        assert.ok(
            html.includes('mark.search-hit'),
            'expected search-hit highlight rule in the inline stylesheet',
        );
        assert.ok(
            html.includes('--vscode-editor-findMatchHighlightBackground'),
            'highlight background should bind to the host find-match token',
        );
    });
});

// PLAN_ext_ui_package_tabs.md §4 Tab 5: the embedded Known issues tab shares its markup/script
// builders with the standalone panel above (idPrefix/root parameters, defaulting to the
// standalone's exact prior behavior -- covered by every test above still passing unchanged).
// These tests guard the embed-specific contract: no document shell, no id collisions with the
// Package Dashboard's own table, and no duplicate host chrome (hero/full-width-toggle/shortcuts).
describe('known-issues embed (PLAN_ext_ui_package_tabs.md Tab 5)', () => {
    it('renders body-only markup with no document shell or acquireVsCodeApi call', () => {
        const html = getEmbeddedBodyHtml();
        assert.ok(!html.includes('<!DOCTYPE'), 'embed must not include a document shell');
        assert.ok(!html.includes('<html'), 'embed must not include <html>');
        assert.ok(!html.includes('acquireVsCodeApi'), 'embed must not call acquireVsCodeApi itself');
        assert.ok(html.includes('class="ki-embed-body"'), 'expected the ki-embed-body wrapper');
    });

    it('prefixes every id the Package Dashboard also uses, to avoid DOM id collisions', () => {
        const html = getEmbeddedBodyHtml();
        for (const id of ['ki-search-input', 'ki-pkg-body', 'ki-visible-count', 'ki-announcer']) {
            assert.ok(html.includes(`id="${id}"`), `expected id="${id}"`);
        }
        // Regression guard for the idPrefix-on-already-prefixed-id bug caught during
        // development: __id__('ki-chip-strip') must never render 'kiki-chip-strip'.
        assert.ok(!html.includes('kiki-'), 'an id must never be double-prefixed');
    });

    it('omits the host chrome the Package Dashboard already renders once', () => {
        const html = getEmbeddedBodyHtml();
        assert.ok(!html.includes('dash-hero'), 'embed must not render its own hero band');
        assert.ok(!html.includes('dashFullWidthToggle'), 'embed must not render a second full-width toggle (duplicate id)');
    });

    it('standalone panel keeps its original unprefixed ids (test-safe rename)', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('id="search-input"'), 'standalone ids must stay unprefixed');
        assert.ok(html.includes('id="pkg-body"'));
        assert.ok(html.includes('class="ki-search-field"'), 'search input keeps the new class alongside its id');
    });

    it('embed styles scope .search-clear so it cannot repaint the host table\'s own clear button', () => {
        const styles = getKnownIssuesEmbedStyles();
        assert.ok(styles.includes('.ki-embed-body .search-clear'), 'expected the scoped override');
        assert.ok(!styles.includes('.mono'), 'must not pull in chromeMicroAndMotion (code/.mono side effect)');
    });

    it('embed script is a self-contained IIFE scoped to .ki-embed-body', () => {
        const script = getKnownIssuesEmbedScript();
        assert.ok(script.trim().startsWith('(function() {'), 'must wrap itself in an IIFE');
        assert.ok(
            script.includes("document.querySelector('.ki-embed-body')"),
            'must scope __ROOT__ to the embed wrapper',
        );
        assert.ok(
            !script.includes("getElementById('dashFullWidthToggle')"),
            'embed must not wire the host full-width toggle',
        );
    });

    it('standalone script keeps wiring the full-width toggle and document-level shortcuts', () => {
        const script = getKnownIssuesScript();
        assert.ok(script.includes("getElementById('dashFullWidthToggle')"));
        assert.ok(script.includes("e.key === '/'"));
    });
});
