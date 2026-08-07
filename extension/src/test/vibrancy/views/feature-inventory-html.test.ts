/**
 * Tests **feature-inventory-html**: the standalone Package Feature Inventory
 * report. The report is the exhaustive artifact — nothing may be filtered out
 * and nothing may be truncated silently — so these tests pin the disclosure
 * rules, the three-state adoption chips, escaping, and l10n coverage.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import { buildFeatureInventoryHtml } from '../../../vibrancy/views/feature-inventory-html';
import { getFeatureInventoryScript } from '../../../vibrancy/views/feature-inventory-script';
import { l10n } from '../../../i18n/runtime';
import { api, feature, occurrences, pkg, report } from './feature-inventory-fixture';

describe('feature-inventory-html', () => {
    it('renders zero-usage and unmeasurable chips distinguishably', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            features: [
                feature({ apis: [api('NeverUsed', 0)] }),
                feature({ apis: [] }),
            ],
        })]));
        assert.ok(html.includes('fi-chip-unused'), 'zero-usage chip class');
        assert.ok(html.includes('fi-chip-unmeasurable'), 'unmeasurable chip class');
        assert.ok(html.includes(l10n('featureInventory.chip.unused')));
        assert.ok(html.includes(l10n('featureInventory.chip.unmeasurable')));
        assert.notStrictEqual(
            l10n('featureInventory.chip.unused'),
            l10n('featureInventory.chip.unmeasurable'),
            'the two states must not read alike',
        );
    });

    it('renders a fully adopted package rather than filtering it out', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            name: 'fully_adopted',
            features: [feature({ apis: [api('Used', 3)] })],
        })]));
        assert.ok(html.includes('fully_adopted'));
        assert.ok(html.includes('fi-chip-adopted'));
    });

    it('renders the fixed and security categories', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            features: [
                feature({ category: 'fixed', description: 'Fixes a crash.' }),
                feature({ category: 'security', description: 'Patches an advisory.' }),
            ],
        })]));
        assert.ok(html.includes(l10n('featureInventory.category.fixed')));
        assert.ok(html.includes(l10n('featureInventory.category.security')));
        assert.ok(html.includes('data-category="security"'));
    });

    it('omits categories that have no features', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            features: [feature({ category: 'added' })],
        })]));
        assert.ok(!html.includes('data-category="removed"'));
    });

    it('discloses the exact remaining count past the usage display limit', () => {
        const many = { name: 'Busy', usageCount: 25, usages: occurrences(25) };
        const html = buildFeatureInventoryHtml(report([pkg({
            features: [feature({ apis: [many] })],
        })]));
        assert.ok(html.includes(l10n('featureInventory.feature.moreUsages', { count: '5' })));
        // Every occurrence is still present — the overflow nests, never drops.
        assert.ok(html.includes('lib/main.dart:25'));
    });

    it('renders an explicit note when no changelog is available', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            name: 'no_changelog', changelogAvailable: false, features: [],
        })]));
        assert.ok(html.includes(l10n('featureInventory.package.noChangelog')));
    });

    it('matches the model counts in the summary table', () => {
        const record = pkg({
            features: [
                feature({ apis: [api('A', 1)] }),
                feature({ apis: [api('B', 0)] }),
                feature({ apis: [] }),
            ],
        });
        const html = buildFeatureInventoryHtml(report([record]));
        assert.strictEqual(record.counts.total, 3);
        assert.strictEqual(record.counts.adopted, 1);
        assert.strictEqual(record.counts.unadopted, 1);
        assert.ok(html.includes(`<td data-sort="${record.counts.total}">`));
        assert.ok(html.includes(`<td data-sort="${record.counts.totalUsages}">`));
        assert.ok(html.includes(`<td data-sort="${record.opportunityScore}">`));
    });

    it('renders the caveats and provenance in the header', () => {
        const html = buildFeatureInventoryHtml(report([pkg()], ['Textual matching only.']));
        assert.ok(html.includes(l10n('featureInventory.caveats.title')));
        assert.ok(html.includes('Textual matching only.'));
        assert.ok(html.includes('2026-08-07T10:00:00.000Z'));
        assert.ok(html.includes('14.5.0'));
    });

    it('links each summary row to its package section anchor', () => {
        const html = buildFeatureInventoryHtml(report([pkg({ name: 'reel_text' })]));
        assert.ok(html.includes('href="#pkg-reel_text"'));
        assert.ok(html.includes('id="pkg-reel_text"'));
    });

    it('emits per-symbol repo and docs search links', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            features: [feature({ apis: [api('ReelText.rich', 1)] })],
        })]));
        assert.ok(html.includes('https://github.com/example/reel_text/search?q=ReelText.rich'));
        assert.ok(html.includes('search=ReelText.rich'));
    });

    it('escapes HTML in package and feature data', () => {
        const html = buildFeatureInventoryHtml(report([pkg({
            description: '<script>alert(1)</script>',
            features: [feature({ description: '<img onerror="x">' })],
        })]));
        assert.ok(!html.includes('<script>alert(1)</script>'));
        assert.ok(html.includes('&lt;script&gt;alert(1)&lt;/script&gt;'));
        assert.ok(!html.includes('<img onerror='));
    });

    it('resolves every visible string through the catalog', () => {
        const html = buildFeatureInventoryHtml(report([
            pkg(),
            pkg({ name: 'no_changelog', changelogAvailable: false, features: [] }),
        ]));
        // l10n falls back to the raw dotted key when a key is missing, so any
        // surviving 'featureInventory.' text is an unlocalized string.
        assert.ok(!html.includes('featureInventory.'), 'unresolved l10n key in output');
    });

    it('renders an empty-state note when no packages were scanned', () => {
        const html = buildFeatureInventoryHtml(report([]));
        assert.ok(html.includes(l10n('featureInventory.empty.body')));
    });

    it('emits an inline script that parses, with no backslash to be eaten', () => {
        // This repo has shipped broken webview scripts because a backslash in a
        // TS template literal is consumed at build time ('\d' arrives as 'd').
        // Compile the emitted source rather than asserting on substrings, and
        // require it to contain no backslash at all.
        const script = getFeatureInventoryScript();
        assert.ok(!script.includes('\\'), 'inline script must contain no backslash');
        assert.doesNotThrow(() => new Function(script), 'inline script must parse');
    });
});
