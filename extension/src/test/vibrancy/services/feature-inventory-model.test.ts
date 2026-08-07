/**
 * Tests **feature-inventory-model**: the unfiltered consolidation behind the
 * Package Opportunities report. These guard what the three existing UI surfaces
 * hide — fully-adopted packages, packages with no changelog, and
 * `fixed`/`security`/`removed` bullets — plus the three-state usage discipline
 * (null unmeasurable vs 0 unused) that stops a reviewing AI from reading "no
 * API named" as "dead feature".
 */
// Must precede any import that transitively pulls in 'vscode' (the model uses
// import-scanner's activeFileUsages), so it resolves to the local mock.
import '../register-vscode-mock';
import * as assert from 'assert';
import { buildFeatureInventory } from '../../../vibrancy/services/feature-inventory-model';
import {
    ChangelogBullet,
    OpportunityCategory,
    PackageOpportunities,
} from '../../../vibrancy/services/changelog-opportunities';
import {
    PackageUsage,
    SymbolOccurrence,
} from '../../../vibrancy/services/import-scanner';
import { VibrancyResult } from '../../../vibrancy/types';
import { makeMinimalResult } from '../test-helpers';

const META = { generatedAt: '2026-08-07T00:00:00Z', extensionVersion: '14.5.0' };

const occ = (filePath: string, line: number): SymbolOccurrence =>
    ({ filePath, line, column: 3, snippet: 'const x = 1;' });

const bullet = (
    category: OpportunityCategory,
    version: string,
    apiNames: readonly string[],
): ChangelogBullet =>
    ({ text: `${category} in ${version}`, version, category, apiNames });

/** Minimal PackageOpportunities around a bullet list — `all` is what we read. */
function opps(all: readonly ChangelogBullet[]): PackageOpportunities {
    const adoptable = all.filter(
        b => b.category === 'added' || b.category === 'changed');
    return {
        all, opportunities: adoptable, opportunityCount: adoptable.length,
        apiNames: adoptable.flatMap(b => b.apiNames),
    };
}

const usage = (filePath: string, isCommented: boolean): PackageUsage =>
    ({ filePath, line: 1, isCommented, importLine: 1, exportLine: null });

const result = (name: string, over: Partial<VibrancyResult>): VibrancyResult =>
    ({ ...makeMinimalResult({ name }), ...over });

// `used` is referenced twice, `missing` never — the 0-vs-null distinction.
const OCCURRENCES = new Map<string, readonly SymbolOccurrence[]>([
    ['used', [occ('lib/a.dart', 4), occ('lib/b.dart', 9)]],
    ['alsoUsed', [occ('lib/a.dart', 12)]],
]);

const ADOPTED = result('all_adopted', {
    opportunities: opps([bullet('added', '2.0.0', ['used', 'alsoUsed'])]),
});

const MIXED = result('mixed_pkg', {
    opportunities: opps([
        bullet('fixed', '1.1.0', ['used', 'missing']),
        bullet('security', '1.2.0', ['used']),
        bullet('removed', '1.0.0', []),
        bullet('changed', '1.3.0', []),
    ]),
});

const build = (results: readonly VibrancyResult[]) =>
    buildFeatureInventory(results, OCCURRENCES, META);

/** The single MIXED entry of a given category. */
function mixedEntry(category: OpportunityCategory) {
    return build([MIXED]).packages[0].features
        .find(f => f.category === category)!;
}

describe('feature-inventory-model', () => {
    it('keeps a fully-adopted package (the regression this report exists for)', () => {
        const record = build([ADOPTED]).packages[0];
        assert.strictEqual(record.name, 'all_adopted');
        assert.strictEqual(record.counts.adopted, 1);
        assert.strictEqual(record.counts.unadopted, 0);
        assert.strictEqual(record.features[0].adopted, true);
        // Every usage site travels with the entry — the model never truncates.
        const api = record.features[0].apis.find(a => a.name === 'used')!;
        assert.deepStrictEqual(
            api.usages.map(u => `${u.filePath}:${u.line}`),
            ['lib/a.dart:4', 'lib/b.dart:9'],
        );
    });

    it('keeps a package with no changelog, marked unavailable', () => {
        const report = build([result('no_changelog', { opportunities: null })]);
        const record = report.packages[0];
        assert.strictEqual(record.changelogAvailable, false);
        assert.deepStrictEqual(record.features, []);
        assert.deepStrictEqual(record.counts, {
            total: 0, adopted: 0, unadopted: 0, unmeasurable: 0, totalUsages: 0,
        });
    });

    it('treats an absent opportunities field the same as null', () => {
        const report = build([result('legacy_literal', {})]);
        assert.strictEqual(report.packages[0].changelogAvailable, false);
    });

    it('keeps fixed / security / removed bullets the UI drops', () => {
        const categories = build([MIXED]).packages[0].features
            .map(f => f.category);
        assert.ok(categories.includes('fixed'), 'fixed dropped');
        assert.ok(categories.includes('security'), 'security dropped');
        assert.ok(categories.includes('removed'), 'removed dropped');
    });

    it('distinguishes usageCount 0 from null', () => {
        const missing = mixedEntry('fixed').apis.find(a => a.name === 'missing')!;
        assert.strictEqual(missing.usageCount, 0, 'unused API must count 0');
        assert.deepStrictEqual(missing.usages, []);

        const removed = mixedEntry('removed');
        assert.strictEqual(removed.usageCount, null, 'no API named => null');
        assert.deepStrictEqual(removed.apis, []);
    });

    it('reports adopted true / false / null', () => {
        assert.strictEqual(mixedEntry('security').adopted, true);
        assert.strictEqual(mixedEntry('fixed').adopted, false);
        assert.strictEqual(mixedEntry('removed').adopted, null);
    });

    it('counts stay internally consistent and match the occurrence map', () => {
        const counts = build([MIXED]).packages[0].counts;
        assert.strictEqual(
            counts.total, counts.adopted + counts.unadopted + counts.unmeasurable,
        );
        assert.strictEqual(counts.unmeasurable, 2, 'two bullets name no API');
        // `used` has 2 occurrences and is named by both measurable bullets.
        assert.strictEqual(counts.totalUsages, 4);
    });

    it('orders features newest version first, stable when unparseable', () => {
        const record = build([result('ordered', {
            opportunities: opps([
                bullet('added', '1.0.0', []),
                bullet('added', 'nightly-a', []),
                bullet('added', '1.10.0', []),
                bullet('added', 'nightly-b', []),
                bullet('added', '1.2.0', []),
            ]),
        })]).packages[0];
        // Unparseable versions sort last, in mined order; parseable ones must
        // not be stranded out of order by sitting next to them.
        assert.deepStrictEqual(record.features.map(f => f.version), [
            '1.10.0', '1.2.0', '1.0.0', 'nightly-a', 'nightly-b',
        ]);
    });

    it('lists active import files only, deduped and sorted', () => {
        const record = build([result('imports', {
            fileUsages: [
                usage('lib/z.dart', false),
                usage('lib/a.dart', false),
                usage('lib/a.dart', true),
                usage('lib/dead.dart', true),
            ],
        })]).packages[0];
        assert.deepStrictEqual(record.importFiles, ['lib/a.dart', 'lib/z.dart']);
    });

    it('nulls repository and homepage rather than guessing a URL', () => {
        const links = build([result('lonely_pkg', {})]).packages[0].links;
        assert.strictEqual(links.repository, null);
        assert.strictEqual(links.homepage, null);
        assert.strictEqual(links.pubDev, 'https://pub.dev/packages/lonely_pkg');
        // `latest`, not the installed version — a retracted version serves no
        // docs on pub.dev, so a pinned URL would 404.
        assert.strictEqual(links.docs, 'https://pub.dev/documentation/lonely_pkg/latest/');
    });

    it('prefers the GitHub repo URL over the pub.dev repository URL', () => {
        const record = build([result('linked', {
            github: { repoUrl: 'https://github.com/a/b' } as never,
            pubDev: { repositoryUrl: 'https://example.com/x' } as never,
        })]).packages[0];
        assert.strictEqual(record.links.repository, 'https://github.com/a/b');
    });

    it('stamps meta and always discloses caveats', () => {
        const report = build([]);
        assert.strictEqual(report.schemaVersion, 1);
        assert.strictEqual(report.generatedAt, META.generatedAt);
        assert.strictEqual(report.extensionVersion, META.extensionVersion);
        assert.ok(report.caveats.length >= 3, 'caveats must never be empty');
        assert.ok(report.caveats.some(c => c.includes('textual matches')));
        assert.ok(report.caveats.some(c => c.includes('changelog')));
    });
});
