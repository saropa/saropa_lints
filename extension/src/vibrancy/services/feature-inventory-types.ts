/**
 * Data contract for the consolidated Package Opportunities report.
 *
 * The three existing opportunity surfaces (dashboard cell, detail pane section,
 * opportunities panel) each render a FILTERED slice: only packages with at least
 * one unadopted API name, and only `added`/`changed` bullets. This model is the
 * unfiltered consolidation — every scanned package, every mined changelog
 * bullet in every category, with usage counted from 0 to n and every usage site
 * located.
 *
 * Pure types only. Shared by the model builder (`feature-inventory-model`) and
 * the renderers (`feature-inventory-html`, `feature-inventory-markdown`) so they
 * can be built and tested independently.
 */

import { OpportunityCategory } from './changelog-opportunities';
import { SymbolOccurrence } from './import-scanner';

/** Schema version stamped into the JSON export. Bump on breaking changes. */
export const FEATURE_INVENTORY_SCHEMA_VERSION = 1;

/** One API symbol named by a changelog bullet, with its measured project usage. */
export interface FeatureApiUsage {
    /** Symbol as extracted from the changelog (`ReelText`, `ReelText.rich`). */
    readonly name: string;
    /** Number of textual references in project source. 0 means never used. */
    readonly usageCount: number;
    /** Every reference site. Empty when `usageCount` is 0. Never truncated. */
    readonly usages: readonly SymbolOccurrence[];
}

/**
 * One changelog bullet, consolidated with its usage measurement.
 *
 * A bullet that names no API (`apis` empty) is NOT the same as one used zero
 * times: usage is unmeasurable, not absent. `usageCount` is `null` in that case
 * so a reviewing AI does not read "no API named" as "dead feature".
 */
export interface FeatureEntry {
    readonly category: OpportunityCategory;
    /** The bullet text — the feature description. */
    readonly description: string;
    /** Version the bullet shipped in. */
    readonly version: string;
    /** Per-symbol usage. Empty when the bullet named no identifiable API. */
    readonly apis: readonly FeatureApiUsage[];
    /** Sum of `apis[].usageCount`, or `null` when `apis` is empty. */
    readonly usageCount: number | null;
    /**
     * True when every named API has at least one usage. False when any is
     * unused. `null` when unmeasurable (no API named) — same three-state
     * discipline as `usageCount`.
     */
    readonly adopted: boolean | null;
}

/** Outbound links for a package. Any field is null when unknown. */
export interface PackageLinks {
    readonly pubDev: string | null;
    readonly docs: string | null;
    readonly homepage: string | null;
    readonly repository: string | null;
}

/** Per-package feature counts, precomputed so renderers stay presentational. */
export interface FeatureCounts {
    readonly total: number;
    /** Entries where every named API is used. */
    readonly adopted: number;
    /** Entries with at least one unused named API. */
    readonly unadopted: number;
    /** Entries naming no API — usage unmeasurable. */
    readonly unmeasurable: number;
    /** Sum of every measured usage across the package's entries. */
    readonly totalUsages: number;
}

/** One package's consolidated record. Present even when it has no features. */
export interface PackageFeatureRecord {
    readonly name: string;
    readonly version: string;
    /** Latest published version, or `version` when unknown / up to date. */
    readonly latestVersion: string;
    readonly description: string | null;
    readonly links: PackageLinks;
    /**
     * Project files with an active import/export of this package. Carried for
     * the JSON artifact only — the HTML and Markdown renderers locate features
     * by their per-usage call sites, which are more specific than the file that
     * merely imports the package.
     */
    readonly importFiles: readonly string[];
    /**
     * False when the package has no changelog at all — a disclosed limit of the
     * changelog-derived feature source, not a silently empty section.
     */
    readonly changelogAvailable: boolean;
    /** Existing 0–100 adoption-needle score from the scan. 0 when absent. */
    readonly opportunityScore: number;
    readonly counts: FeatureCounts;
    /** Every mined bullet, newest version first. */
    readonly features: readonly FeatureEntry[];
}

/** The complete report model. Serialized verbatim as the JSON artifact. */
export interface FeatureInventoryReport {
    readonly schemaVersion: number;
    /** ISO 8601 generation timestamp. */
    readonly generatedAt: string;
    /** Extension version that produced the report. */
    readonly extensionVersion: string;
    /**
     * Measurement limits the reviewing AI must weigh. Always populated — an
     * empty array would imply the numbers are exact, which they are not.
     */
    readonly caveats: readonly string[];
    readonly packages: readonly PackageFeatureRecord[];
}
