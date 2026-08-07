/**
 * Hand-written model fixtures for the Package Feature Inventory renderer tests.
 *
 * The renderers are pure functions over `FeatureInventoryReport`, so they can be
 * tested against a literal model without running a scan. Shared by the HTML and
 * Markdown test files so both assert against the SAME shapes — a divergence
 * between the two artifacts is exactly what these tests exist to catch.
 */
import {
    FeatureApiUsage, FeatureCounts, FeatureEntry, FeatureInventoryReport,
    PackageFeatureRecord, FEATURE_INVENTORY_SCHEMA_VERSION,
} from '../../../vibrancy/services/feature-inventory-types';
import { SymbolOccurrence } from '../../../vibrancy/services/import-scanner';

/** `count` synthetic occurrences, one per line, in a single file. */
export function occurrences(count: number): SymbolOccurrence[] {
    const out: SymbolOccurrence[] = [];
    for (let i = 1; i <= count; i++) {
        out.push({ filePath: 'lib/main.dart', line: i, column: 3, snippet: `use ${i}` });
    }
    return out;
}

export function api(name: string, usageCount: number): FeatureApiUsage {
    return { name, usageCount, usages: occurrences(usageCount) };
}

export function feature(over: Partial<FeatureEntry> = {}): FeatureEntry {
    const apis = over.apis ?? [api('ReelText', 2)];
    const measurable = apis.length > 0;
    return {
        category: 'added',
        description: 'Adds ReelText for animated text.',
        version: '1.2.0',
        apis,
        usageCount: measurable ? apis.reduce((sum, a) => sum + a.usageCount, 0) : null,
        adopted: measurable ? apis.every(a => a.usageCount > 0) : null,
        ...over,
    };
}

/** Counts derived from `features` so fixtures cannot drift from their own data. */
function countsFor(features: readonly FeatureEntry[]): FeatureCounts {
    return {
        total: features.length,
        adopted: features.filter(f => f.adopted === true).length,
        unadopted: features.filter(f => f.adopted === false).length,
        unmeasurable: features.filter(f => f.adopted === null).length,
        totalUsages: features.reduce((sum, f) => sum + (f.usageCount ?? 0), 0),
    };
}

export function pkg(over: Partial<PackageFeatureRecord> = {}): PackageFeatureRecord {
    const features = over.features ?? [feature()];
    return {
        name: 'reel_text',
        version: '0.4.0',
        latestVersion: '0.5.0',
        description: 'Animated text widgets.',
        links: {
            pubDev: 'https://pub.dev/packages/reel_text',
            docs: 'https://pub.dev/documentation/reel_text/latest/',
            homepage: null,
            repository: 'https://github.com/example/reel_text',
        },
        importFiles: ['lib/main.dart'],
        changelogAvailable: true,
        opportunityScore: 42,
        counts: over.counts ?? countsFor(features),
        features,
        ...over,
    };
}

export function report(
    packages: readonly PackageFeatureRecord[] = [pkg()],
    caveats: readonly string[] = ['Usage is matched textually, not by resolved reference.'],
): FeatureInventoryReport {
    return {
        schemaVersion: FEATURE_INVENTORY_SCHEMA_VERSION,
        generatedAt: '2026-08-07T10:00:00.000Z',
        extensionVersion: '14.5.0',
        caveats,
        packages,
    };
}
