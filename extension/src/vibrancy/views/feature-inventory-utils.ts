/**
 * Shared, presentation-neutral helpers for the Package Feature Inventory
 * renderers (HTML and Markdown).
 *
 * Both renderers must agree on category ordering, adoption state naming, the
 * usage-disclosure limit, and the per-symbol search URLs. Keeping that agreement
 * in one module is what stops the two artifacts from disagreeing about the same
 * report — a disagreement a reviewing AI would read as a data conflict.
 */

import { OpportunityCategory } from '../services/changelog-opportunities';
import { FeatureEntry, PackageFeatureRecord } from '../services/feature-inventory-types';
import { l10n } from '../../i18n/runtime';

/**
 * Number of usage sites shown before the remainder is nested in a further
 * disclosure. Nothing is ever dropped — the overflow carries an exact count.
 */
export const USAGE_DISPLAY_LIMIT = 20;

/**
 * Fixed category order. Changelog mining emits categories in whatever order the
 * source file happened to use; a stable presentation order lets a reader compare
 * two packages (or two runs) without re-reading the section list each time.
 */
export const CATEGORY_ORDER: readonly OpportunityCategory[] = [
    'added', 'changed', 'deprecated', 'removed', 'security', 'fixed', 'other',
];

/**
 * Adoption state of a single feature.
 *
 * `unmeasurable` is deliberately NOT merged with `unused`: a bullet that named
 * no API was never measured, and showing it as "never used" would invent a
 * finding the data does not support.
 */
export type FeatureState = 'adopted' | 'partial' | 'unused' | 'unmeasurable';

export function featureState(feature: FeatureEntry): FeatureState {
    if (feature.usageCount === null) { return 'unmeasurable'; }
    if (feature.usageCount === 0) { return 'unused'; }
    return feature.adopted === true ? 'adopted' : 'partial';
}

/** Localized display label for a category heading. */
export function categoryLabel(category: OpportunityCategory): string {
    return l10n(`featureInventory.category.${category}`);
}

/** Localized chip text for a feature's adoption state. */
export function stateChipLabel(state: FeatureState): string {
    return l10n(`featureInventory.chip.${state}`);
}

/** Features of one category, in model order (newest version first). */
export function featuresInCategory(
    record: PackageFeatureRecord,
    category: OpportunityCategory,
): readonly FeatureEntry[] {
    return record.features.filter(f => f.category === category);
}

/**
 * Stable in-document anchor for a package section.
 *
 * Package names are lower-case identifiers already, but the id is sanitized
 * anyway so a malformed name cannot break the summary table's jump links.
 */
export function packageAnchor(name: string): string {
    let out = '';
    for (const ch of name) {
        const safe = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
            || (ch >= '0' && ch <= '9') || ch === '_' || ch === '-';
        out += safe ? ch : '-';
    }
    return `pkg-${out}`;
}

/** Documentation search URL for one symbol, matching the detail pane's shape. */
export function docsSearchUrl(record: PackageFeatureRecord, symbol: string): string {
    const base = record.links.docs
        ?? `https://pub.dev/documentation/${encodeURIComponent(record.name)}/latest/`;
    return `${base}?search=${encodeURIComponent(symbol)}`;
}

/**
 * Repository code-search URL for one symbol, or null when the package has no
 * known repository. Same `/search?q=` shape the package detail pane uses.
 */
export function repoSearchUrl(record: PackageFeatureRecord, symbol: string): string | null {
    const repo = record.links.repository;
    if (!repo) { return null; }
    const trimmed = repo.endsWith('/') ? repo.slice(0, -1) : repo;
    return `${trimmed}/search?q=${encodeURIComponent(symbol)}`;
}

/** Symbol names a feature named, or the localized "no API named" stand-in. */
export function featureTitle(feature: FeatureEntry): string {
    if (feature.apis.length === 0) { return l10n('featureInventory.feature.noApiNamed'); }
    return feature.apis.map(a => a.name).join(', ');
}

/**
 * Usage count rendered for display; unmeasurable features get their own label.
 *
 * Singular and plural are separate catalog entries rather than an `if` picking
 * between two English literals — the choice belongs to the translator, whose
 * language may split the forms differently than English does.
 */
export function usageCountLabel(feature: FeatureEntry): string {
    if (feature.usageCount === null) { return l10n('featureInventory.feature.usagesUnknown'); }
    const key = feature.usageCount === 1
        ? 'featureInventory.feature.usagesOne'
        : 'featureInventory.feature.usages';
    return l10n(key, { count: String(feature.usageCount) });
}

/**
 * Overflow label for a usage list truncated at {@link USAGE_DISPLAY_LIMIT}.
 * Shared by both renderers so the disclosure wording — and its singular form,
 * reachable whenever a feature has exactly one usage past the limit — cannot
 * drift between HTML and Markdown.
 */
export function moreUsagesLabel(count: number): string {
    const key = count === 1
        ? 'featureInventory.feature.moreUsagesOne'
        : 'featureInventory.feature.moreUsages';
    return l10n(key, { count: String(count) });
}

/** Lower-cased haystack the client-side text filter matches against. */
export function featureSearchText(feature: FeatureEntry): string {
    const symbols = feature.apis.map(a => a.name).join(' ');
    return `${feature.description} ${symbols} ${feature.version}`.toLowerCase();
}
