/**
 * Tests **changelog-opportunities**: heuristic mining of changelog bullets into
 * adoption opportunities, API-name extraction, and project-usage ranking.
 *
 * Fixtures mirror two real changelog shapes:
 *  - plain bullet lists with no section headers (reel_text style), where
 *    category is inferred from each bullet's leading verb;
 *  - Keep-a-Changelog with `### Added` / `### Fixed` headers (firebase style),
 *    where the section governs the bullets beneath it.
 */
import * as assert from 'assert';
import {
    mineOpportunities,
    extractApiNames,
    rankOpportunities,
} from '../../../vibrancy/services/changelog-opportunities';
import { ChangelogEntry } from '../../../vibrancy/types';

// reel_text-style: plain bullets, no Keep-a-Changelog headers.
const REEL_TEXT_ENTRIES: ChangelogEntry[] = [
    {
        version: '0.4.0',
        body: [
            '- Reworked plain rolling text slots to paint through cached render objects.',
            '- Added a full-screen performance stress screen to the example app.',
            '- Fixed RTL rolling slot alignment while animated slot widths change.',
            '- Added intrinsic/dry layout support for painted rolling slots.',
            '- No public API changes.',
        ].join('\n'),
    },
    {
        version: '0.3.0',
        body: [
            '- Added WidgetSpan support to `ReelText.rich`: inline widgets stay in the row.',
            '- Reworked the internal roll planner around a shared measured token pipeline.',
        ].join('\n'),
    },
];

// Keep-a-Changelog style: section headers govern the bullets beneath them.
const KEEP_A_CHANGELOG: ChangelogEntry[] = [
    {
        version: '2.1.0',
        date: '2026-01-10',
        body: [
            '### Added',
            '- `FirebaseAuth.signInWithProvider` for federated sign-in.',
            '- New `AppCheck` token auto-refresh option.',
            '',
            '### Fixed',
            '- Null crash when `currentUser` is reused after sign-out.',
            '',
            '### Deprecated',
            '- `signInWithPopup` — use `signInWithProvider`.',
        ].join('\n'),
    },
];

describe('changelog-opportunities', () => {
    describe('mineOpportunities (plain bullets, keyword inference)', () => {
        const result = mineOpportunities(REEL_TEXT_ENTRIES);

        it('counts only added/changed bullets as opportunities', () => {
            // 0.4.0: 1 reworked (changed) + 2 added + 1 fixed + 1 "No public API" (other)
            // 0.3.0: 1 added + 1 reworked (changed)
            // opportunities = 2 added + 1 changed (0.4.0) + 1 added + 1 changed (0.3.0) = 5
            assert.strictEqual(result.opportunityCount, 5);
        });

        it('excludes Fixed bullets from opportunities', () => {
            const texts = result.opportunities.map(o => o.text).join(' | ');
            assert.ok(!texts.includes('Fixed RTL'), 'fixed bullet leaked in');
        });

        it('tags an "Added ..." bullet as added', () => {
            const widgetSpan = result.opportunities.find(
                o => o.text.includes('WidgetSpan'),
            );
            assert.ok(widgetSpan, 'WidgetSpan opportunity missing');
            assert.strictEqual(widgetSpan!.category, 'added');
        });

        it('tags a "Reworked ..." bullet as changed', () => {
            const reworked = result.opportunities.find(
                o => o.text.startsWith('Reworked plain'),
            );
            assert.ok(reworked, 'reworked opportunity missing');
            assert.strictEqual(reworked!.category, 'changed');
        });

        it('surfaces the API name from the WidgetSpan bullet', () => {
            assert.ok(
                result.apiNames.includes('ReelText.rich'),
                `expected ReelText.rich in ${JSON.stringify(result.apiNames)}`,
            );
        });
    });

    describe('mineOpportunities (Keep-a-Changelog headers)', () => {
        const result = mineOpportunities(KEEP_A_CHANGELOG);

        it('treats bullets under ### Added as opportunities', () => {
            assert.strictEqual(result.opportunityCount, 2);
        });

        it('excludes ### Fixed and ### Deprecated bullets', () => {
            const cats = result.all.map(b => b.category);
            assert.ok(cats.includes('fixed'), 'fixed section not classified');
            assert.ok(cats.includes('deprecated'), 'deprecated not classified');
            for (const o of result.opportunities) {
                assert.strictEqual(o.category, 'added');
            }
        });

        it('extracts dotted API names from backtick spans', () => {
            assert.ok(result.apiNames.includes('FirebaseAuth.signInWithProvider'));
        });
    });

    describe('extractApiNames', () => {
        it('captures backtick spans and strips trailing ()', () => {
            assert.deepStrictEqual(
                extractApiNames('Use `runWhile()` for async labels.'),
                ['runWhile'],
            );
        });

        it('captures multi-hump PascalCase but not plain capitalized words', () => {
            const names = extractApiNames('Added WidgetSpan support. Fixed alignment.');
            assert.ok(names.includes('WidgetSpan'));
            assert.ok(!names.includes('Added'));
            assert.ok(!names.includes('Fixed'));
        });

        it('captures dotted member access off a PascalCase owner', () => {
            const names = extractApiNames('Now ReelText.rich accepts inline widgets.');
            assert.ok(names.includes('ReelText.rich'));
        });

        it('ignores all-caps acronyms like RTL', () => {
            assert.deepStrictEqual(extractApiNames('Fixed RTL alignment.'), []);
        });

        it('ignores README.md referenced via dotted member access shape', () => {
            const names = extractApiNames('See README.md for migration notes.');
            assert.ok(!names.includes('README.md'), `README.md leaked in: ${JSON.stringify(names)}`);
        });

        it('ignores documentation filenames inside backtick spans', () => {
            const names = extractApiNames('Updated `CHANGELOG.md` and `pubspec.yaml`.');
            assert.ok(!names.includes('CHANGELOG.md'), `CHANGELOG.md leaked in: ${JSON.stringify(names)}`);
            assert.ok(!names.includes('pubspec.yaml'), `pubspec.yaml leaked in: ${JSON.stringify(names)}`);
        });

        it('still captures a real dotted API name alongside a filename reference', () => {
            const names = extractApiNames('ReelText.rich now supports this; see README.md.');
            assert.ok(names.includes('ReelText.rich'));
            assert.ok(!names.includes('README.md'));
        });
    });

    describe('rankOpportunities', () => {
        const opp = mineOpportunities(REEL_TEXT_ENTRIES);

        it('counts an unused API name as adoptable', () => {
            const ranking = rankOpportunities(opp, {
                importFileCount: 2,
                usedSymbols: new Set<string>(),
            });
            assert.ok(ranking.adoptableCount >= 1);
            assert.ok(ranking.unusedApiNames.includes('ReelText.rich'));
        });

        it('drops an opportunity from adoptable once its symbol is used', () => {
            const ranking = rankOpportunities(opp, {
                importFileCount: 2,
                usedSymbols: new Set<string>(['ReelText.rich']),
            });
            assert.ok(!ranking.unusedApiNames.includes('ReelText.rich'));
        });

        it('halves the score for packages with zero imports', () => {
            const used = rankOpportunities(opp, {
                importFileCount: 10,
                usedSymbols: new Set<string>(),
            });
            const unused = rankOpportunities(opp, {
                importFileCount: 0,
                usedSymbols: new Set<string>(),
            });
            assert.ok(used.score > unused.score);
        });

        it('clamps the score to 100', () => {
            const ranking = rankOpportunities(opp, {
                importFileCount: 50,
                usedSymbols: new Set<string>(),
            });
            assert.ok(ranking.score <= 100);
        });
    });
});
