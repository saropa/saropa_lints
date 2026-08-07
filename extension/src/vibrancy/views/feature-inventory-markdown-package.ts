/**
 * Per-package body of the Markdown twin of the Package Feature Inventory.
 *
 * Uses `<details>` blocks (GitHub renders them) so a huge report stays
 * navigable, while every feature also carries a plain `###`/`####` heading and
 * literal body text — a raw-text ingestion pass, which is the whole point of the
 * Markdown artifact, still sees every feature even with the blocks unopened.
 */

import { OpportunityCategory } from '../services/changelog-opportunities';
import {
    FeatureApiUsage, FeatureEntry, PackageFeatureRecord,
} from '../services/feature-inventory-types';
import { SymbolOccurrence } from '../services/import-scanner';
import { l10n } from '../../i18n/runtime';
import {
    CATEGORY_ORDER, categoryLabel, docsSearchUrl, featureState, featureTitle,
    featuresInCategory, moreUsagesLabel, repoSearchUrl, stateChipLabel, usageCountLabel,
    USAGE_DISPLAY_LIMIT,
} from './feature-inventory-utils';

/** Collapse newlines so a multi-line bullet cannot break the enclosing list. */
export function oneLine(text: string): string {
    return text.split('\n').map(s => s.trim()).filter(Boolean).join(' ');
}

/** One package: heading, links, and either its categories or a disclosed gap. */
export function renderPackage(record: PackageFeatureRecord): string {
    const heading = `### ${record.name} ${record.version}`;
    const counts = l10n('featureInventory.package.summary', {
        name: record.name,
        version: record.version,
        adopted: String(record.counts.adopted),
        total: String(record.counts.total),
    });
    const description = record.description ? `\n${oneLine(record.description)}\n` : '';
    const body = renderPackageBody(record);
    return `${heading}\n\n${counts}\n${description}${renderLinks(record)}\n`
        + `<details>\n<summary>${counts}</summary>\n\n${body}\n</details>\n`;
}

function renderPackageBody(record: PackageFeatureRecord): string {
    if (!record.changelogAvailable) {
        return `> ${l10n('featureInventory.package.noChangelog')}\n`;
    }
    if (record.features.length === 0) {
        return `> ${l10n('featureInventory.package.noFeatures')}\n`;
    }
    return CATEGORY_ORDER
        .map(category => renderCategory(record, category))
        .filter(Boolean)
        .join('\n');
}

/** Matches the HTML renderer's link set; `homepage` is unrenderable there too. */
function renderLinks(record: PackageFeatureRecord): string {
    const entries: ReadonlyArray<readonly [string | null, string]> = [
        [record.links.pubDev, 'featureInventory.package.linkPubDev'],
        [record.links.docs, 'featureInventory.package.linkDocs'],
        [record.links.repository, 'featureInventory.package.linkRepository'],
    ];
    const links = entries
        .filter(([url]) => Boolean(url))
        .map(([url, key]) => `[${l10n(key)}](${url as string})`)
        .join(' · ');
    return links ? `\n${links}\n` : '';
}

/** One category. Omitted entirely when the package has no features in it. */
function renderCategory(
    record: PackageFeatureRecord,
    category: OpportunityCategory,
): string {
    const features = featuresInCategory(record, category);
    if (features.length === 0) { return ''; }
    const heading = l10n('featureInventory.category.heading', {
        category: categoryLabel(category),
        count: String(features.length),
    });
    const body = features.map(f => renderFeature(record, f)).join('\n');
    return `#### ${heading}\n\n${body}`;
}

/** One feature: summary line, state chip, description, and its API blocks. */
function renderFeature(record: PackageFeatureRecord, feature: FeatureEntry): string {
    const summary = l10n('featureInventory.feature.summary', {
        symbols: featureTitle(feature),
        usages: usageCountLabel(feature),
        version: feature.version,
    });
    const chip = `\`${stateChipLabel(featureState(feature))}\``;
    const apis = feature.apis.map(api => renderApi(record, api)).join('\n');
    return `<details>\n<summary>${summary} ${chip}</summary>\n\n`
        + `${oneLine(feature.description)}\n\n${apis}\n</details>\n`;
}

/** One named symbol: its search links and every measured usage site. */
function renderApi(record: PackageFeatureRecord, api: FeatureApiUsage): string {
    const repo = repoSearchUrl(record, api.name);
    const links = [
        repo ? `[${l10n('featureInventory.feature.viewCode')}](${repo})` : '',
        `[${l10n('featureInventory.feature.viewDocs')}](${docsSearchUrl(record, api.name)})`,
    ].filter(Boolean).join(' · ');
    const heading = l10n('featureInventory.feature.apiHeading', {
        symbol: api.name,
        count: String(api.usageCount),
    });
    return `**${heading}** — ${links}\n\n${renderUsages(api.usages)}`;
}

/**
 * Usage sites. At most {@link USAGE_DISPLAY_LIMIT} inline; the remainder is
 * nested in a further `<details>` labeled with the EXACT remaining count, so
 * the Markdown artifact drops nothing silently either.
 */
function renderUsages(usages: readonly SymbolOccurrence[]): string {
    if (usages.length === 0) {
        return `_${l10n('featureInventory.feature.noUsages')}_\n`;
    }
    const head = usageLines(usages.slice(0, USAGE_DISPLAY_LIMIT));
    if (usages.length <= USAGE_DISPLAY_LIMIT) { return `${head}\n`; }

    const rest = usages.slice(USAGE_DISPLAY_LIMIT);
    const label = moreUsagesLabel(rest.length);
    return `${head}\n<details>\n<summary>${label}</summary>\n\n`
        + `${usageLines(rest)}\n</details>\n`;
}

function usageLines(usages: readonly SymbolOccurrence[]): string {
    return usages
        .map(u => `- \`${u.filePath}:${u.line}\` — \`${oneLine(u.snippet)}\``)
        .join('\n');
}
