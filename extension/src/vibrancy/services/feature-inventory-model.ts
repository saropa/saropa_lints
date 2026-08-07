/**
 * Consolidation step of the Package Opportunities report: scan results in,
 * complete report model out.
 *
 * The three in-editor opportunity surfaces each render a FILTERED slice — only
 * packages with an unadopted API name, and only `added`/`changed` bullets. That
 * is right for a "what should I act on" panel and wrong for a report an AI
 * reviews: a fully-adopted package, a package with no changelog, and a
 * `security` bullet are all evidence, and their absence reads as "nothing
 * there" rather than "nothing shown". This model keeps everything.
 *
 * Deterministic: data in, data out, no I/O of its own. It is NOT free of
 * `vscode` at load time — `activeFileUsages` comes from `import-scanner`, which
 * imports the module — so tests must register the vscode mock before importing
 * this file. Dropping that one import would sever the dependency if the mock
 * ever becomes a burden.
 */

import { VibrancyResult } from '../types';
import { ChangelogBullet, PackageOpportunities } from './changelog-opportunities';
import {
    FeatureApiUsage,
    FeatureCounts,
    FeatureEntry,
    FeatureInventoryReport,
    FEATURE_INVENTORY_SCHEMA_VERSION,
    PackageFeatureRecord,
    PackageLinks,
} from './feature-inventory-types';
import { activeFileUsages, SymbolOccurrence } from './import-scanner';

/** Occurrence sites keyed by API symbol name; absent key means zero usages. */
type OccurrenceMap = ReadonlyMap<string, readonly SymbolOccurrence[]>;

/**
 * Measurement limits the reviewing AI must weigh. Always emitted — an empty
 * array would imply the numbers are exact, and each caveat names a way a count
 * misleads in a direction the number alone does not reveal.
 */
const CAVEATS: readonly string[] = [
    'Usage counts are textual matches, not resolved references: a local '
    + 'variable or a same-named symbol from another package is counted. Treat '
    + 'short, common names (Text, State, Duration) as over-counted.',
    'Features are mined from changelog text, so a package whose changelog is '
    + 'missing, unpublished, or unparsed shows zero features. That is a gap in '
    + 'the source, not evidence the package added nothing.',
    'A null usage count means the entry named no API, so adoption was never '
    + 'measured — distinct from zero, where the API was searched for and missed.',
    'Only project source directories are searched (lib, bin, test, web, tool, '
    + 'integration_test); usage inside dependencies is not counted.',
];

/**
 * Build the complete report model from a finished vibrancy scan. EVERY result
 * becomes a record, unfiltered — that completeness is the point.
 */
export function buildFeatureInventory(
    results: readonly VibrancyResult[],
    occurrences: OccurrenceMap,
    meta: { generatedAt: string; extensionVersion: string },
): FeatureInventoryReport {
    return {
        schemaVersion: FEATURE_INVENTORY_SCHEMA_VERSION,
        generatedAt: meta.generatedAt,
        extensionVersion: meta.extensionVersion,
        caveats: CAVEATS,
        packages: results.map(r => buildPackageRecord(r, occurrences)),
    };
}

/** One package's record, present even when it has no changelog and no features. */
function buildPackageRecord(
    result: VibrancyResult,
    occurrences: OccurrenceMap,
): PackageFeatureRecord {
    const { package: pkg, pubDev } = result;
    // `null` and `undefined` both mean "no changelog was mined" — the field is
    // optional for source compatibility with pre-opportunities result literals.
    const opportunities = result.opportunities ?? null;
    const features = buildFeatures(opportunities, occurrences);

    return {
        name: pkg.name,
        version: pkg.version,
        latestVersion: pubDev?.latestVersion ?? pkg.version,
        description: pubDev?.description ?? null,
        links: buildLinks(result),
        importFiles: activeImportFiles(result),
        changelogAvailable: opportunities !== null,
        opportunityScore: result.opportunityScore ?? 0,
        counts: countFeatures(features),
        features,
    };
}

/**
 * Every mined bullet in every category, newest version first. Reads
 * `opportunities.all`, not the adoptable subset: a `removed` or `security`
 * bullet is not adoptable but is exactly what a reviewer needs to see.
 */
function buildFeatures(
    opportunities: PackageOpportunities | null,
    occurrences: OccurrenceMap,
): readonly FeatureEntry[] {
    if (opportunities === null) { return []; }
    return sortNewestFirst(opportunities.all)
        .map(bullet => buildEntry(bullet, occurrences));
}

/** One bullet plus its measured usage. */
function buildEntry(
    bullet: ChangelogBullet,
    occurrences: OccurrenceMap,
): FeatureEntry {
    const apis: FeatureApiUsage[] = bullet.apiNames.map(name => {
        const usages = occurrences.get(name) ?? [];
        return { name, usageCount: usages.length, usages };
    });
    // Three states, never two: a bullet naming no API is UNMEASURABLE, not
    // unused. Collapsing null into 0/false tells the reviewing AI a feature is
    // dead when nothing was ever searched for.
    const measurable = apis.length > 0;
    return {
        category: bullet.category,
        description: bullet.text,
        version: bullet.version,
        apis,
        usageCount: measurable
            ? apis.reduce((sum, a) => sum + a.usageCount, 0) : null,
        adopted: measurable ? apis.every(a => a.usageCount > 0) : null,
    };
}

/**
 * Newest version first, unparseable versions last in mined order. They sort to
 * the end rather than comparing equal to everything, because such a key is not
 * transitive and silently strands neighboring parseable versions.
 */
function sortNewestFirst(
    bullets: readonly ChangelogBullet[],
): readonly ChangelogBullet[] {
    return [...bullets].sort((a, b) => compareVersionsDesc(a.version, b.version));
}

/** Descending semver compare; unparseable sorts after anything parseable. */
function compareVersionsDesc(a: string, b: string): number {
    const left = parseVersion(a);
    const right = parseVersion(b);
    if (left === null || right === null) {
        return left === right ? 0 : (left === null ? 1 : -1);
    }
    for (let i = 0; i < 3; i++) {
        if (left[i] !== right[i]) { return right[i] - left[i]; }
    }
    return 0;
}

/**
 * Numeric `major.minor.patch`, or null when the string is not semver-ish. A
 * pre-release suffix is ignored, not rejected — `1.2.0-rc.1` belongs beside
 * `1.2.0`, not at the bottom of the list.
 */
function parseVersion(version: string): readonly number[] | null {
    const match = /^v?(\d+)\.(\d+)(?:\.(\d+))?/.exec(version.trim());
    if (!match) { return null; }
    return [Number(match[1]), Number(match[2]), Number(match[3] ?? 0)];
}

/** Counts stay internally consistent: total === adopted + unadopted + unmeasurable. */
function countFeatures(features: readonly FeatureEntry[]): FeatureCounts {
    let adopted = 0;
    let unadopted = 0;
    let unmeasurable = 0;
    let totalUsages = 0;
    for (const f of features) {
        if (f.adopted === null) { unmeasurable++; }
        else if (f.adopted) { adopted++; }
        else { unadopted++; }
        totalUsages += f.usageCount ?? 0;
    }
    return { total: features.length, adopted, unadopted, unmeasurable, totalUsages };
}

/** Deduped, sorted workspace-relative paths of ACTIVE imports only. */
function activeImportFiles(result: VibrancyResult): readonly string[] {
    const paths = activeFileUsages(result.fileUsages).map(u => u.filePath);
    return [...new Set(paths)].sort();
}

/**
 * Outbound links; null whenever the input is missing. A guessed URL that 404s
 * is worse than an absent one — the reader cannot tell until they click.
 */
function buildLinks(result: VibrancyResult): PackageLinks {
    const name = encodeURIComponent(result.package.name);
    return {
        pubDev: `https://pub.dev/packages/${name}`,
        // `latest`, not the installed version: pub.dev serves no docs for a
        // retracted version, so pinning would 404 for exactly the packages a
        // reader most needs to look up. Matches the URL the package detail
        // pane already builds, so the two cannot drift.
        docs: `https://pub.dev/documentation/${name}/latest/`,
        // pub.dev collapses `homepage` into `repository` at fetch time
        // (pub-dev-api), so no distinct homepage value survives to here.
        homepage: null,
        repository: result.github?.repoUrl ?? result.pubDev?.repositoryUrl ?? null,
    };
}
