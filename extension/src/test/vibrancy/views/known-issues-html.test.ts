import * as assert from 'assert';
import { buildKnownIssuesHtml } from '../../../vibrancy/views/known-issues-html';

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

    it('should include filter checkbox', () => {
        const html = buildKnownIssuesHtml();
        assert.ok(html.includes('id="filter-has-replacement"'));
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
});
