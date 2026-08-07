/**
 * Tests **feature-inventory-markdown**: the Markdown twin of the Package
 * Feature Inventory report. It covers the same cases as the HTML test because
 * the two artifacts describe the same model — if they disagree, the reviewing
 * AI that reads the Markdown gets a different answer from the human reading the
 * HTML, which is the failure this file exists to prevent.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import { buildFeatureInventoryMarkdown } from '../../../vibrancy/views/feature-inventory-markdown';
import { l10n } from '../../../i18n/runtime';
import { api, feature, occurrences, pkg, report } from './feature-inventory-fixture';

describe('feature-inventory-markdown', () => {
    it('labels zero-usage and unmeasurable features differently', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg({
            features: [
                feature({ apis: [api('NeverUsed', 0)] }),
                feature({ apis: [] }),
            ],
        })]));
        assert.ok(md.includes(l10n('featureInventory.chip.unused')));
        assert.ok(md.includes(l10n('featureInventory.chip.unmeasurable')));
        assert.ok(md.includes(l10n('featureInventory.feature.noApiNamed')));
    });

    it('renders a fully adopted package rather than filtering it out', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg({
            name: 'fully_adopted',
            features: [feature({ apis: [api('Used', 3)] })],
        })]));
        assert.ok(md.includes('### fully_adopted 0.4.0'));
        assert.ok(md.includes(l10n('featureInventory.chip.adopted')));
    });

    it('renders the fixed and security categories as headings', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg({
            features: [
                feature({ category: 'fixed' }),
                feature({ category: 'security' }),
            ],
        })]));
        assert.ok(md.includes(`#### ${l10n('featureInventory.category.heading', {
            category: l10n('featureInventory.category.fixed'), count: '1',
        })}`));
        assert.ok(md.includes(l10n('featureInventory.category.security')));
    });

    it('discloses the exact remaining count past the usage display limit', () => {
        const many = { name: 'Busy', usageCount: 25, usages: occurrences(25) };
        const md = buildFeatureInventoryMarkdown(report([pkg({
            features: [feature({ apis: [many] })],
        })]));
        assert.ok(md.includes(l10n('featureInventory.feature.moreUsages', { count: '5' })));
        assert.ok(md.includes('`lib/main.dart:25`'));
    });

    it('renders an explicit note when no changelog is available', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg({
            name: 'no_changelog', changelogAvailable: false, features: [],
        })]));
        assert.ok(md.includes(l10n('featureInventory.package.noChangelog')));
    });

    it('matches the model counts in the summary table row', () => {
        const record = pkg({
            features: [
                feature({ apis: [api('A', 1)] }),
                feature({ apis: [api('B', 0)] }),
                feature({ apis: [] }),
            ],
        });
        const md = buildFeatureInventoryMarkdown(report([record]));
        const expected = `| ${record.name} | ${record.version} | 3 | 1 | 1 | `
            + `${record.counts.totalUsages} | ${record.opportunityScore} |`;
        assert.ok(md.includes(expected), `missing summary row: ${expected}`);
    });

    it('places the caveats above the data', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg()], ['Textual matching only.']));
        assert.ok(md.indexOf('Textual matching only.')
            < md.indexOf(l10n('featureInventory.summary.title')));
    });

    it('emits per-symbol repo and docs search links', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg({
            features: [feature({ apis: [api('ReelText.rich', 1)] })],
        })]));
        assert.ok(md.includes('https://github.com/example/reel_text/search?q=ReelText.rich'));
        assert.ok(md.includes('search=ReelText.rich'));
    });

    it('keeps a multi-line description on one line and neutralizes table pipes', () => {
        const md = buildFeatureInventoryMarkdown(report([pkg({
            name: 'a|b',
            features: [feature({ description: 'first line\nsecond line' })],
        })]));
        assert.ok(md.includes('first line second line'));
        assert.ok(md.includes('| a\\|b |'));
    });

    it('resolves every visible string through the catalog', () => {
        const md = buildFeatureInventoryMarkdown(report([
            pkg(),
            pkg({ name: 'no_changelog', changelogAvailable: false, features: [] }),
        ]));
        assert.ok(!md.includes('featureInventory.'), 'unresolved l10n key in output');
    });

    it('renders an empty-state note when no packages were scanned', () => {
        const md = buildFeatureInventoryMarkdown(report([]));
        assert.ok(md.includes(l10n('featureInventory.empty.body')));
    });
});
