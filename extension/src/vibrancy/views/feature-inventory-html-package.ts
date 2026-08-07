/**
 * Levels 2-4 of the Package Feature Inventory report: the per-package
 * disclosure, its per-category disclosures, and the individual features with
 * their search links and usage sites.
 *
 * Everything is collapsed by default — the report routinely carries thousands
 * of features, and an expanded document is unreadable and slow to paint.
 */

import { OpportunityCategory } from '../services/changelog-opportunities';
import {
    FeatureApiUsage, FeatureEntry, PackageFeatureRecord,
} from '../services/feature-inventory-types';
import { SymbolOccurrence } from '../services/import-scanner';
import { escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import {
    CATEGORY_ORDER, categoryLabel, docsSearchUrl, featureSearchText, featureState,
    featureTitle, featuresInCategory, moreUsagesLabel, packageAnchor, repoSearchUrl,
    stateChipLabel, usageCountLabel, USAGE_DISPLAY_LIMIT,
} from './feature-inventory-utils';

/** One package: level 2 disclosure, collapsed, counts carried in the summary. */
export function buildPackageSection(record: PackageFeatureRecord): string {
    const summary = escapeHtml(l10n('featureInventory.package.summary', {
        name: record.name,
        version: record.version,
        adopted: String(record.counts.adopted),
        total: String(record.counts.total),
    }));
    return `<details class="fi-package" id="${escapeHtml(packageAnchor(record.name))}">
        <summary>${summary}</summary>
        <div class="fi-package-body">${buildPackageBody(record)}</div>
    </details>`;
}

/** Description, links, and either the category sections or a disclosed gap. */
function buildPackageBody(record: PackageFeatureRecord): string {
    const description = record.description
        ? `<p class="fi-desc">${escapeHtml(record.description)}</p>`
        : '';
    const links = buildPackageLinks(record);
    if (!record.changelogAvailable) {
        return `${description}${links}<p class="fi-note">${escapeHtml(
            l10n('featureInventory.package.noChangelog'),
        )}</p>`;
    }
    if (record.features.length === 0) {
        return `${description}${links}<p class="fi-note">${escapeHtml(
            l10n('featureInventory.package.noFeatures'),
        )}</p>`;
    }
    const sections = CATEGORY_ORDER
        .map(category => buildCategorySection(record, category))
        .join('');
    return `${description}${links}${sections}`;
}

/**
 * Outbound package links; each is omitted when the model has no URL for it.
 *
 * `links.homepage` is deliberately absent: pub.dev collapses `pubspec.homepage`
 * into the repository URL at fetch time, so the model has no distinct value to
 * render and never will without an upstream change. Rendering a branch that
 * cannot execute meant shipping a label for translation into every locale to
 * describe a link nobody can see.
 */
function buildPackageLinks(record: PackageFeatureRecord): string {
    const entries: ReadonlyArray<readonly [string | null, string]> = [
        [record.links.pubDev, 'featureInventory.package.linkPubDev'],
        [record.links.docs, 'featureInventory.package.linkDocs'],
        [record.links.repository, 'featureInventory.package.linkRepository'],
    ];
    const links = entries
        .filter(([url]) => Boolean(url))
        .map(([url, key]) =>
            `<a href="${escapeHtml(url as string)}">${escapeHtml(l10n(key))}</a>`)
        .join(' &middot; ');
    return links ? `<p class="fi-api-links">${links}</p>` : '';
}

/** Level 3: one category. Categories with no features are omitted entirely. */
function buildCategorySection(
    record: PackageFeatureRecord,
    category: OpportunityCategory,
): string {
    const features = featuresInCategory(record, category);
    if (features.length === 0) { return ''; }
    const summary = escapeHtml(l10n('featureInventory.category.heading', {
        category: categoryLabel(category),
        count: String(features.length),
    }));
    const body = features.map(f => buildFeature(record, f)).join('');
    return `<details class="fi-category" data-category="${escapeHtml(category)}">
        <summary>${summary}</summary>
        <div class="fi-category-body">${body}</div>
    </details>`;
}

/** Level 4: one changelog feature, its state chip, links, and usage sites. */
function buildFeature(record: PackageFeatureRecord, feature: FeatureEntry): string {
    const state = featureState(feature);
    const summary = escapeHtml(l10n('featureInventory.feature.summary', {
        symbols: featureTitle(feature),
        usages: usageCountLabel(feature),
        version: feature.version,
    }));
    const chip = `<span class="fi-chip fi-chip-${state}">${escapeHtml(stateChipLabel(state))}</span>`;
    return `<details class="fi-feature" data-state="${state}"`
        + ` data-category="${escapeHtml(feature.category)}"`
        + ` data-text="${escapeHtml(featureSearchText(feature))}">
        <summary>${summary}${chip}</summary>
        <div class="fi-feature-body">
            <p class="fi-desc">${escapeHtml(feature.description)}</p>
            ${feature.apis.map(api => buildApiBlock(record, api)).join('')}
        </div>
    </details>`;
}

/** One named symbol: its search links and every measured usage site. */
function buildApiBlock(record: PackageFeatureRecord, api: FeatureApiUsage): string {
    const repo = repoSearchUrl(record, api.name);
    const links = [
        repo ? `<a href="${escapeHtml(repo)}">${escapeHtml(l10n('featureInventory.feature.viewCode'))}</a>` : '',
        `<a href="${escapeHtml(docsSearchUrl(record, api.name))}">${escapeHtml(l10n('featureInventory.feature.viewDocs'))}</a>`,
    ].filter(Boolean).join(' &middot; ');
    const header = escapeHtml(l10n('featureInventory.feature.apiHeading', {
        symbol: api.name,
        count: String(api.usageCount),
    }));
    return `<div class="fi-api">
        <div class="fi-api-links"><code>${header}</code> ${links}</div>
        ${buildUsageList(api.usages)}
    </div>`;
}

/**
 * Usage sites. At most {@link USAGE_DISPLAY_LIMIT} are listed inline; the rest
 * are nested in a further disclosure labeled with the EXACT remaining count.
 * Nothing is ever dropped silently.
 */
function buildUsageList(usages: readonly SymbolOccurrence[]): string {
    if (usages.length === 0) {
        return `<p class="fi-empty">${escapeHtml(l10n('featureInventory.feature.noUsages'))}</p>`;
    }
    const head = `<ul class="fi-usages">${usageItems(usages.slice(0, USAGE_DISPLAY_LIMIT))}</ul>`;
    if (usages.length <= USAGE_DISPLAY_LIMIT) { return head; }

    const rest = usages.slice(USAGE_DISPLAY_LIMIT);
    const label = escapeHtml(moreUsagesLabel(rest.length));
    return `${head}<details class="fi-overflow">
        <summary>${label}</summary>
        <ul class="fi-usages">${usageItems(rest)}</ul>
    </details>`;
}

/**
 * `path:line` plus the trimmed source line for each occurrence.
 *
 * Dropping the snippet from the overflow list was measured as a document-size
 * fix and rejected: it cut a 100-package report by only ~10% because the bulk
 * is per-feature markup, not snippets, and it cost the reader the one piece of
 * context that makes a call site judgeable. The size warning at export time is
 * the honest lever instead.
 */
function usageItems(usages: readonly SymbolOccurrence[]): string {
    return usages.map(u => `<li><span class="fi-mono">`
        + `${escapeHtml(u.filePath)}:${u.line}</span>`
        + ` <span class="fi-snippet fi-mono">${escapeHtml(u.snippet)}</span></li>`).join('');
}
