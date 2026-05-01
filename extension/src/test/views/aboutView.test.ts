/**
 * Regression tests for the About Saropa Lints markdown renderer.
 * The renderer is intentionally narrow (only constructs used by
 * about-saropa.md). The original implementation flattened indented
 * sub-bullets into siblings, breaking the parent/child hierarchy in
 * sections like "VS Code Extensions". These tests pin the nested-list
 * behavior so that regression cannot recur silently.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { markdownToHtml } from '../../views/aboutView';

describe('aboutView markdownToHtml', () => {
    it('renders a flat unordered list as a single <ul>', () => {
        const md = '- one\n- two\n- three\n';
        const html = markdownToHtml(md);
        // Three sibling <li> in one <ul>, no nesting introduced.
        assert.strictEqual(
            html.replace(/\s+/g, ''),
            '<ul><li>one</li><li>two</li><li>three</li></ul>',
        );
    });

    it('nests a 2-space indented sub-bullet inside the parent <li>', () => {
        // Mirrors the "VS Code Extensions" pattern in about-saropa.md where
        // each parent product had a description line as a sub-bullet.
        const md = '- parent\n  - child\n';
        const html = markdownToHtml(md);
        // The inner <ul> must appear *inside* the parent <li> (before its
        // </li>), not as a sibling. Anything else flattens the hierarchy.
        assert.strictEqual(
            html.replace(/\s+/g, ''),
            '<ul><li>parent<ul><li>child</li></ul></li></ul>',
        );
    });

    it('unwinds back to the outer level when a sibling appears after a nested child', () => {
        // The original bug: this exact shape rendered all four lines as
        // same-level siblings. Verify each parent owns its own nested child.
        const md = [
            '- parentA',
            '  - childA',
            '- parentB',
            '  - childB',
        ].join('\n');
        const html = markdownToHtml(md);
        assert.strictEqual(
            html.replace(/\s+/g, ''),
            '<ul>'
            + '<li>parentA<ul><li>childA</li></ul></li>'
            + '<li>parentB<ul><li>childB</li></ul></li>'
            + '</ul>',
        );
    });

    it('closes nested lists when a horizontal rule ends the section', () => {
        // The closeBlocks() path on `---` must fully unwind the indent stack
        // before <hr> is emitted. Normalize whitespace because the renderer
        // joins emitted tokens with '\n' for readability.
        const md = '- parent\n  - child\n\n---\n';
        const html = markdownToHtml(md).replace(/\s+/g, '');
        assert.ok(
            html.includes('</li></ul></li></ul><hr>'),
            `expected fully-closed nesting before <hr>, got: ${html}`,
        );
    });

    it('preserves inline formatting (bold/italic/links) inside nested bullets', () => {
        const md = '- **[Saropa Log Capture](https://example.com)**\n'
            + '  - _The Debugger\'s Safety Net:_ Saves logs.\n';
        const html = markdownToHtml(md);
        // Parent retains the bolded anchor; child retains the italicized lead.
        assert.ok(
            html.includes('<strong><a href="https://example.com"'),
            `expected bolded link in parent, got: ${html}`,
        );
        assert.ok(
            html.includes('<em>The Debugger\'s Safety Net:</em>'),
            `expected italic lead in child, got: ${html}`,
        );
    });
});
