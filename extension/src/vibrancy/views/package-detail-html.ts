/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import {
    VibrancyResult, VersionGapResult, ReviewEntry, activeFileUsages, PackageUsage,
} from '../types';
import { ReviewSummary } from '../services/review-state';
import { categoryLabel, categoryToGrade, scoreToGrade } from '../scoring/status-classifier';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { formatRelativeTime } from '../scoring/time-formatter';
import { formatPrereleaseTag } from '../scoring/prerelease-classifier';
import { createWebviewCspNonce, escapeHtml, resolveRepoUrl } from './html-utils';
import { l10n } from '../../i18n/runtime';
import { getPackageDetailStyles } from './package-detail-styles';
import { getPillButtonStyles } from './pill-button-styles';
import { getPackageDetailScript } from './package-detail-script';
import { getDashboardChromeStyles } from '../../views/dashboardChromeStyles';
import { buildDetailScoreSection } from './report-html';
import { markdownToHtml } from '../../views/aboutView';
import {
    buildDashboardHero,
    buildDocumentTitle,
    buildStatusLine,
    getFullWidthToggleScript,
} from '../../views/dashboardHero';
import {
    buildKeyboardShortcutsButton,
    buildKeyboardShortcutsOverlay,
    getKeyboardShortcutsScript,
    getKeyboardShortcutsStyles,
} from '../../views/keyboard-shortcuts';

// Single-package drill-down HTML (versions, review, license, links).

/**
 * Per-fetch error flags surfaced via the partial-state banner (§8.16.3). A
 * lazy fetch sets its flag in `package-detail-panel.ts` on `catch`; the
 * banner renders when any flag is true and offers a single Retry button
 * that re-runs all lazy fetches via `postMessage({ type: 'retryFetches' })`.
 */
export interface PackageDetailFetchErrors {
    readonly readme: boolean;
    readonly gap: boolean;
    readonly reverseDeps: boolean;
}

const NO_FETCH_ERRORS: PackageDetailFetchErrors = {
    readme: false, gap: false, reverseDeps: false,
};

/**
 * Build the full HTML for the package detail webview panel.
 * All sections are rendered — version-gap section shows spinner if data is pending.
 */
export function buildPackageDetailHtml(
    result: VibrancyResult,
    reviews: readonly ReviewEntry[],
    reviewSummary: ReviewSummary | null,
    fetchErrors: PackageDetailFetchErrors = NO_FETCH_ERRORS,
): string {
    return wrapHtml(
        result.package.name,
        buildPackageDetailBody(result, reviews, reviewSummary, fetchErrors),
    );
}

/**
 * Render only the detail SECTIONS (no document/CSP/script wrapper) so the same
 * content can live in two hosts: the standalone panel (via [buildPackageDetailHtml])
 * and the dashboard's docked master-detail pane, which injects this body into a
 * region and supplies the chrome itself. The version-gap and README-image
 * sections degrade to empty when their lazy-fetched data is absent, so this is
 * safe to render from a freshly-scanned VibrancyResult before any fetch lands.
 */
export function buildPackageDetailBody(
    result: VibrancyResult,
    reviews: readonly ReviewEntry[],
    reviewSummary: ReviewSummary | null,
    fetchErrors: PackageDetailFetchErrors = NO_FETCH_ERRORS,
    options: { paneMode?: boolean } = {},
): string {
    // In the dashboard's docked pane the page already owns the hero/banner, so
    // the detail uses a compact header instead of a second `<header>` (which
    // would duplicate the banner landmark and surface a stray full-width toggle).
    const header = options.paneMode ? buildPaneHeader(result) : buildHeader(result);
    const parts = [
        header,
        buildPartialFetchBanner(fetchErrors),
        buildDescriptionSection(result),
        buildTopicsSection(result),
        buildVersionSection(result),
        buildChangelogSection(result),
        buildCommunitySection(result),
        // Health Score breakdown (score factors + maintainer-quality bonuses).
        // Only in the dashboard pane, where report-styles supplies its CSS; the
        // retired standalone panel did not load those styles. This is the one
        // section the inline detail card rendered that the pane otherwise lacks.
        ...(options.paneMode ? [buildDetailScoreSection(result)] : []),
        buildFileUsagesSection(result),
        buildDependenciesSection(result),
        buildAlertsSection(result),
        buildVersionGapSection(result.versionGap, l10n('packageDetail.versionGap.versionTitle'), reviews, reviewSummary),
        buildVersionGapSection(result.overrideGap, l10n('packageDetail.versionGap.overrideTitle'), reviews, reviewSummary),
        buildPlatformsSection(result),
        buildSuggestionsSection(result),
        buildImagesSection(result),
        buildLinksRow(result),
    ];

    return parts.join('\n');
}

/**
 * §8.16.3 — Partial-state banner. Shows when any lazy fetch has failed so the
 * user can see why a section is missing data and retry. Hidden entirely
 * (returns empty string) when every fetch is clean.
 */
function buildPartialFetchBanner(errors: PackageDetailFetchErrors): string {
    const failed: string[] = [];
    if (errors.readme) { failed.push(l10n('packageDetail.partialBanner.partReadme')); }
    if (errors.gap) { failed.push(l10n('packageDetail.partialBanner.partGap')); }
    if (errors.reverseDeps) { failed.push(l10n('packageDetail.partialBanner.partReverseDeps')); }
    if (failed.length === 0) { return ''; }
    const list = failed.length === 1
        ? failed[0]
        : failed.length === 2
            ? l10n('packageDetail.partialBanner.listTwo', { first: failed[0], second: failed[1] })
            : l10n('packageDetail.partialBanner.listMany', {
                head: failed.slice(0, -1).join(', '),
                last: failed[failed.length - 1],
            });
    return `<div class="partial-banner" role="status" aria-live="polite">
        <span class="glyph" aria-hidden="true">⚠</span>
        <span class="partial-msg">${escapeHtml(l10n('packageDetail.partialBanner.message', { list }))}</span>
        <button type="button" class="btn tier-2" id="retry-fetches"
            title="${l10n('packageDetail.partialBanner.retryTitle')}">${l10n('packageDetail.partialBanner.retry')}</button>
    </div>`;
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

function buildHeader(r: VibrancyResult): string {
    const grade = categoryToGrade(r.category);
    const cat = categoryLabel(r.category);
    const license = r.license ?? '';

    // Logo (when available) takes the gauge slot in the hero band — it's the visual focal
    // anchor for a single-package view and parallels how the package dashboard uses a gauge.
    const logoHtml = r.readme?.logoUrl
        ? `<div class="hero-gauge package-logo-frame"><img class="package-logo" src="${escapeHtml(r.readme.logoUrl)}" alt="${escapeHtml(l10n('packageDetail.header.logoAlt', { name: r.package.name }))}" /></div>`
        : '';

    // Status line carries the package's identity facts: vibrancy grade, version, license,
    // category. These were buried below the title in the old layout and now sit on the same
    // line as the title where the user expects to see them at a glance (guideline §4.1).
    const statusLineHtml = buildStatusLine([
        { glyph: '🏆', label: l10n('packageDetail.header.grade', { grade }), title: cat, tone: gradeTone(grade) },
        { label: `v${r.package.version}` },
        ...(license ? [{ label: license, title: l10n('packageDetail.header.licenseTitle') }] : []),
        ...(r.pubDev?.publishedDate ? [{ label: l10n('packageDetail.header.published', { date: r.pubDev.publishedDate.split('T')[0] }) }] : []),
    ]);
    // §8.1 — pass the bare package name; the helper prepends "Saropa ". The
    // previous "Package: ${name}" title double-noun'd the heading
    // ("Saropa Package: foo"), pushing the actual identifier behind two
    // labels that add no information.
    const heroHtml = buildDashboardHero({
        title: r.package.name,
        statusLineHtml,
        gaugeHtml: logoHtml,
        extraToggleHtml: buildKeyboardShortcutsButton(),
    });

    // §14.14 — external-link strip used to render here, immediately below the
    // hero, AND again at the bottom of the page via buildLinksRow. The user
    // saw the same row of doc / repo / pub.dev links twice on every visit.
    // Drop the header copy; the bottom band is reference content per §14.14
    // and stays the single source of truth for navigation links.
    return heroHtml;
}

/**
 * Compact header for the dashboard's docked detail pane: package name as a
 * section heading plus the same identity status line as the full panel, but
 * without the `dash-hero` banner, gauge, or full-width toggle — those belong to
 * the dashboard chrome that already surrounds the pane.
 */
function buildPaneHeader(r: VibrancyResult): string {
    const grade = categoryToGrade(r.category);
    const cat = categoryLabel(r.category);
    const license = r.license ?? '';
    const logo = r.readme?.logoUrl
        ? `<img class="pane-logo" src="${escapeHtml(r.readme.logoUrl)}" alt="${escapeHtml(l10n('packageDetail.header.logoAlt', { name: r.package.name }))}" />`
        : '';
    const statusLineHtml = buildStatusLine([
        { glyph: '🏆', label: l10n('packageDetail.header.grade', { grade }), title: cat, tone: gradeTone(grade) },
        { label: `v${r.package.version}` },
        ...(license ? [{ label: license, title: l10n('packageDetail.header.licenseTitle') }] : []),
        ...(r.pubDev?.publishedDate ? [{ label: l10n('packageDetail.header.published', { date: r.pubDev.publishedDate.split('T')[0] }) }] : []),
    ]);
    return `<div class="pane-header">${logo}<div class="pane-header-text"><h2 class="pane-title">${escapeHtml(r.package.name)}</h2>${statusLineHtml}</div></div>`;
}

/** Map letter grade to status-pill tone for the hero status line. */
function gradeTone(grade: string): 'good' | 'warn' | 'bad' | 'neutral' {
    if (grade === 'A' || grade === 'A+') return 'good';
    if (grade === 'B') return 'neutral';
    if (grade === 'C') return 'warn';
    if (grade === 'D' || grade === 'F') return 'bad';
    return 'neutral';
}

function buildDescriptionSection(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return ''; }

    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const maxLen = 100;

    if (desc.length <= maxLen) {
        return `<div class="description-text">${escapeHtml(desc)}</div>`;
    }

    // Truncate at the last word boundary within maxLen. If no whitespace
    // exists (e.g. a single long URL), falls back to the hard maxLen cut.
    const slice = desc.substring(0, maxLen);
    const truncated = slice.replace(/\s+\S*$/, '') || slice;
    return `<div class="description-text">${escapeHtml(truncated)}&hellip; ${actionLink(pubUrl, l10n('packageDetail.description.readMore'))}</div>`;
}

function buildTopicsSection(r: VibrancyResult): string {
    const topics = r.pubDev?.topics;
    if (!topics?.length) { return ''; }

    const badges = topics.map(t => {
        const url = `https://pub.dev/packages?q=topic%3A${encodeURIComponent(t)}`;
        return `<a href="#" class="topic-badge" data-action="openUrl" data-url="${escapeHtml(url)}">#${escapeHtml(t)}</a>`;
    }).join(' ');

    return `<div class="topics-row">${badges}</div>`;
}

function buildVersionSection(r: VibrancyResult): string {
    const rows: string[] = [];

    rows.push(row(l10n('packageDetail.version.constraint'), escapeHtml(r.package.constraint)));
    if (r.pubDev) {
        rows.push(row(l10n('packageDetail.version.latest'), escapeHtml(r.pubDev.latestVersion)));
        if (r.latestPrerelease) {
            const tag = formatPrereleaseTag(r.prereleaseTag);
            rows.push(row(l10n('packageDetail.version.prerelease'), `${escapeHtml(r.latestPrerelease)} (${escapeHtml(tag)})`));
        }
        rows.push(row(l10n('packageDetail.version.published'), escapeHtml(r.pubDev.publishedDate.split('T')[0])));
    }
    if (r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date') {
        rows.push(row(l10n('packageDetail.version.update'),
            `${escapeHtml(r.updateInfo.currentVersion)} &rarr; ${escapeHtml(r.updateInfo.latestVersion)} (${escapeHtml(r.updateInfo.updateStatus)})`));
        if (r.blocker) {
            rows.push(row(l10n('packageDetail.version.blockedBy'), `<strong>${escapeHtml(r.blocker.blockerPackage)}</strong>`));
            // Diamond conflict: name the shared transitive dep and the binding
            // ceiling so the user sees WHY the sibling holds this back, not just
            // that it does. Absent for ordinary reverse-dependency blocks. The
            // SDK variant has no readable range, so it uses different wording.
            if (r.blocker.sharedDependency) {
                const key = r.blocker.blockerIsSdkPin
                    ? 'packageDetail.version.blockedViaSdk'
                    : 'packageDetail.version.blockedVia';
                rows.push(row('', escapeHtml(l10n(key, {
                    blocker: r.blocker.blockerPackage,
                    dep: r.blocker.sharedDependency,
                    constraint: r.blocker.blockerConstraint ?? '',
                    resolvable: r.blocker.sharedDependencyResolvable ?? '',
                    latest: r.blocker.sharedDependencyLatest ?? '',
                }))));
            }
        }
        // Constrained by the user's own pubspec line — name it so the cap is
        // actionable rather than an unexplained "constrained" label.
        if (r.constrainedReason) {
            rows.push(row(l10n('packageDetail.version.constrained'),
                escapeHtml(l10n('packageDetail.version.constrainedBy', {
                    constraint: r.constrainedReason.constraint,
                    resolvable: r.constrainedReason.resolvable,
                    latest: r.constrainedReason.latest,
                }))));
        }
    }
    // Documented do-not-upgrade / do-not-use intent — shown regardless of the
    // update status so a deliberately-frozen dep reads as a hold, not neglect.
    if (r.pinIntent) {
        const pinLabel = r.pinIntent.kind === 'do-not-use'
            ? l10n('packageDetail.version.pinDoNotUse')
            : l10n('packageDetail.version.pinHeld');
        rows.push(row(`🔒 ${pinLabel}`, escapeHtml(r.pinIntent.reason)));
    }
    // Cross-project drift: this package lags (or differs from) a sibling repo's
    // major — an implicit upgrade blocker pub-outdated can't see on its own.
    if (r.crossProjectDrift) {
        const d = r.crossProjectDrift;
        const siblings = d.siblings.map(s => `${s.repo} ${s.constraint}`).join(', ');
        const key = d.behind
            ? 'packageDetail.version.driftBehind'
            : 'packageDetail.version.driftDiffers';
        rows.push(row(`🔀 ${l10n('packageDetail.version.drift')}`,
            escapeHtml(l10n(key, { siblings, own: d.ownConstraint }))));
    }
    /* Prefer code size — what the package contributes to a built app.
       Falls back to the archive total when the tarball analyzer couldn't run.
       Labels the row "Code Size" or "Archive Size" so the developer knows
       which is being shown. See plans/history/2026.05/2026.05.13/
       infra_vibrancy_bloat_uses_tarball_size_not_runtime.md. */
    const sizeBytes = r.codeSizeBytes ?? r.archiveSizeBytes;
    if (sizeBytes !== null) {
        const sizeMB = formatSizeMB(sizeBytes);
        const bloat = r.bloatRating !== null ? ` ${l10n('packageDetail.version.bloat', { rating: String(r.bloatRating) })}` : '';
        const label = r.codeSizeBytes !== null ? l10n('packageDetail.version.codeSize') : l10n('packageDetail.version.archiveSize');
        rows.push(row(label, `${sizeMB}${bloat}`));
        /* When on-disk total differs materially from code size, surface it
           as a secondary row so the asymmetry (e.g. 40 KB code / 20 MB on
           disk for packages that ship example media) is visible. */
        if (r.codeSizeBytes !== null && r.archiveSizeBytes !== null
            && r.archiveSizeBytes !== r.codeSizeBytes) {
            rows.push(row(l10n('packageDetail.version.onDisk'), formatSizeMB(r.archiveSizeBytes)));
        }
    }

    const buttons: string[] = [];
    if (r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date' && !r.blocker) {
        buttons.push(
            `<button class="action-btn" data-action="upgrade" `
            + `data-name="${escapeHtml(r.package.name)}" `
            + `data-version="${escapeHtml(r.updateInfo.latestVersion)}">${l10n('packageDetail.version.upgrade')}</button>`,
        );
    }
    const changelogUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}/changelog`;
    // Styled as a secondary button (not an <a>) to match the Upgrade button visually
    buttons.push(
        `<button class="action-btn secondary" data-action="openUrl" `
        + `data-url="${escapeHtml(changelogUrl)}">${l10n('packageDetail.version.viewChangelog')}</button>`,
    );

    return section(l10n('packageDetail.section.version'), `
        <table class="metrics-table"><tbody>${rows.join('')}</tbody></table>
        <div>${buttons.join('')}</div>
    `);
}

/**
 * Consolidated changelog between the installed version and latest, rendered
 * inline so adopting a newer version is a reviewed decision rather than a blind
 * one — the reason the unsolicited one-click "Update All" was removed (a
 * supply-chain risk). Entries are fetched during the scan (GitHub CHANGELOG.md
 * first, pub.dev fallback) and already filtered to versions > current and
 * <= latest, capped at 20 with `truncated` set when more exist.
 *
 * Bodies are external, untrusted text, so they pass through the XSS-safe
 * `markdownToHtml` (escapes HTML, allow-lists link schemes). Renders nothing
 * when there is no update or no parsed entries; the external "View Changelog"
 * link in the version section stays as the fallback in that case.
 */
function buildChangelogSection(r: VibrancyResult): string {
    const info = r.updateInfo;
    if (!info || info.updateStatus === 'up-to-date') { return ''; }
    const changelog = info.changelog;
    if (!changelog || changelog.entries.length === 0) { return ''; }

    const intro = `<p class="changelog-intro">${escapeHtml(l10n('packageDetail.changelog.intro', {
        from: info.currentVersion,
        to: info.latestVersion,
    }))}</p>`;

    const entries = changelog.entries.map(entry => {
        // Date is optional in the parsed entry; only the dated form needs l10n
        // (it interpolates two tokens), a bare version is just escaped text.
        const heading = entry.date
            ? l10n('packageDetail.changelog.versionDated', { version: entry.version, date: entry.date })
            : entry.version;
        return '<div class="changelog-entry">'
            + `<div class="changelog-version">${escapeHtml(heading)}</div>`
            + `<div class="changelog-body">${markdownToHtml(entry.body)}</div>`
            + '</div>';
    }).join('');

    // Only when the 20-entry cap dropped older releases: name the count shown
    // and link out to the full history so nothing is silently hidden.
    let footer = '';
    if (changelog.truncated) {
        const changelogUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}/changelog`;
        footer = `<p class="changelog-truncated">`
            + escapeHtml(l10n('packageDetail.changelog.truncated', { count: String(changelog.entries.length) }))
            + ` <a href="#" class="action-link" data-action="openUrl" data-url="${escapeHtml(changelogUrl)}">`
            + `${escapeHtml(l10n('packageDetail.changelog.viewFull'))}</a></p>`;
    }

    return section(l10n('packageDetail.section.changelog'), `${intro}${entries}${footer}`);
}

function buildCommunitySection(r: VibrancyResult): string {
    if (!r.github && !r.pubDev) { return ''; }
    const rows: string[] = [];

    if (r.github) {
        const gh = r.github;
        const repoUrl = resolveRepoUrl(gh.repoUrl, r.pubDev?.repositoryUrl);
        rows.push(row(l10n('packageDetail.community.stars'), `${gh.stars}`));
        if (r.likes !== null) {
            rows.push(row(l10n('packageDetail.community.likes'), `${r.likes}`));
        }
        const issues = gh.trueOpenIssues ?? gh.openIssues;
        // Make issue/PR counts clickable links to the GitHub pages
        const issueLink = repoUrl
            ? `${actionLink(`${repoUrl}/issues`, `${issues}`)} · ${actionLink(`${repoUrl}/issues/new`, l10n('packageDetail.community.report'))}`
            : `${issues}`;
        rows.push(row(l10n('packageDetail.community.openIssues'), issueLink));
        if (gh.openPullRequests !== undefined) {
            const prLink = repoUrl
                ? actionLink(`${repoUrl}/pulls`, `${gh.openPullRequests}`)
                : `${gh.openPullRequests}`;
            rows.push(row(l10n('packageDetail.community.openPrs'), prLink));
        }
        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        rows.push(row(l10n('packageDetail.community.activity'),
            activity > 0
                ? l10n('packageDetail.community.activityValue', {
                    closed: String(gh.closedIssuesLast90d),
                    merged: String(gh.mergedPrsLast90d),
                })
                : l10n('packageDetail.community.noActivity')));
        if (gh.daysSinceLastCommit !== undefined) {
            rows.push(row(l10n('packageDetail.community.lastCommit'), formatRelativeTime(gh.daysSinceLastCommit)));
        }
    }

    if (r.pubDev) {
        rows.push(row(l10n('packageDetail.community.pubPoints'), `${r.pubDev.pubPoints}`));
        if (r.pubDev.publisher) {
            const badge = r.verifiedPublisher ? ` ${l10n('packageDetail.community.verified')}` : '';
            rows.push(row(l10n('packageDetail.community.publisher'), `${escapeHtml(r.pubDev.publisher)}${badge}`));
        }
    }
    if (r.transitiveInfo && r.transitiveInfo.transitiveCount > 0) {
        const flagged = r.transitiveInfo.flaggedCount > 0
            ? ` ${l10n('packageDetail.community.flagged', { count: String(r.transitiveInfo.flaggedCount) })}` : '';
        rows.push(row(l10n('packageDetail.community.transitiveDeps'), `${r.transitiveInfo.transitiveCount}${flagged}`));

        // True footprint: own code (or archive fallback) + transitives this
        // dep pulls in. Distinguish unique (eliminated by removing this dep)
        // from shared (still pulled in by other direct deps after removal).
        // When neither size field is populated (null/undefined for fixtures
        // from older builds), skip the row so we don't render a misleading
        // 0 MB. Uses codeSizeBytes when available so the footprint reflects
        // what actually ships, not the gzipped tarball total.
        const own = r.codeSizeBytes ?? r.archiveSizeBytes ?? 0;
        const uniqueT = r.transitiveInfo.uniqueTransitiveSizeBytes;
        const sharedT = r.transitiveInfo.sharedTransitiveSizeBytes;
        const haveData = (uniqueT !== null && uniqueT !== undefined)
            || (sharedT !== null && sharedT !== undefined);
        if (haveData) {
            const unique = uniqueT ?? 0;
            const shared = sharedT ?? 0;
            const ifRemoved = own + unique;
            const total = own + unique + shared;
            const breakdown = shared > 0
                ? l10n('packageDetail.community.footprintBreakdown', {
                    unique: formatSizeMB(ifRemoved),
                    shared: formatSizeMB(shared),
                    total: formatSizeMB(total),
                })
                : `${formatSizeMB(total)}`;
            rows.push(row(
                l10n('packageDetail.community.trueFootprint'),
                `<span title="${escapeHtml(l10n('packageDetail.community.footprintTooltip', {
                    own: formatSizeMB(own),
                    unique: formatSizeMB(unique),
                    shared: formatSizeMB(shared),
                    saved: formatSizeMB(ifRemoved),
                }))}">`
                + `${breakdown}</span>`,
            ));
        }
    }
    if (r.reverseDependencyCount !== null && r.reverseDependencyCount > 0) {
        // Link to pub.dev search for packages depending on this one
        const depSearchUrl = `https://pub.dev/packages?q=dependency%3A${encodeURIComponent(r.package.name)}`;
        rows.push(row(l10n('packageDetail.community.dependents'), `${actionLink(depSearchUrl, l10n('packageDetail.community.packagesCount', { count: r.reverseDependencyCount.toLocaleString('en-US') }))}`));
    }

    return section(l10n('packageDetail.section.community'), `<table class="metrics-table"><tbody>${rows.join('')}</tbody></table>`);
}

function buildFileUsagesSection(r: VibrancyResult): string {
    const active = activeFileUsages(r.fileUsages);
    const commented = r.fileUsages.filter(u => u.isCommented);
    if (active.length === 0 && commented.length === 0) { return ''; }

    // Each usage is one source file after the scanner dedupe. Render a
    // link per directive kind the file contains (import and/or export)
    // so both line locations stay clickable, even though the header
    // count is now files-not-directives.
    const items: string[] = [];
    for (const u of active) {
        items.push(...renderFileUsageLinks(u, /* isCommentedBlock */ false));
    }
    if (commented.length > 0) {
        items.push(`<div class="file-usage-commented">${escapeHtml(l10n('packageDetail.fileUsages.commentedOut'))}</div>`);
        for (const u of commented) {
            items.push(...renderFileUsageLinks(u, /* isCommentedBlock */ true));
        }
    }

    const count = active.length;
    const label = l10n('packageDetail.fileUsages.fileCount', { count: String(count) });
    // Headline note when ANY active usage is an export — surfaces the public-
    // API status without requiring the reader to scan the file list.
    const reexportNote = active.some(u => u.isExport)
        ? ` <span class="reexport-note" title="${l10n('packageDetail.fileUsages.exportNoteTitle')}">&middot; ${l10n('packageDetail.fileUsages.publicApiSurface')}</span>`
        : '';
    return section(l10n('packageDetail.fileUsages.header', { label }) + reexportNote, items.join(''));
}

/**
 * Render one link per directive kind (import and/or export) for a single
 * file's usage. A file that both imports and re-exports the package
 * produces two links — one to the export line tagged "re-export", one
 * to the import line — so the user can jump to either directive. Files
 * predating the split fields (test fixtures without importLine/exportLine)
 * fall back to the single-line display driven off `u.line` / `u.isExport`.
 */
function renderFileUsageLinks(u: PackageUsage, isCommentedBlock: boolean): string[] {
    const itemClass = isCommentedBlock ? 'file-usage-item commented' : 'file-usage-item';
    const badgeTitle = isCommentedBlock
        ? l10n('packageDetail.fileUsages.commentedReexportTitle')
        : l10n('packageDetail.fileUsages.reexportTitle');
    const path = escapeHtml(u.filePath);
    const rows: string[] = [];

    if (u.exportLine != null) {
        rows.push(buildUsageLink(itemClass, path, u.filePath, u.exportLine, badgeTitle, true));
    }
    if (u.importLine != null) {
        // Plain import — no re-export badge even if the same file also
        // re-exports (the export row above already carries the badge).
        rows.push(buildUsageLink(itemClass, path, u.filePath, u.importLine, badgeTitle, false));
    }
    if (u.exportLine == null && u.importLine == null) {
        // Fixture fallback — no directive line splits, honor legacy
        // `isExport` flag for the badge.
        rows.push(buildUsageLink(itemClass, path, u.filePath, u.line, badgeTitle, !!u.isExport));
    }
    return rows;
}

function buildUsageLink(
    itemClass: string,
    escapedPath: string,
    rawPath: string,
    line: number,
    badgeTitle: string,
    showBadge: boolean,
): string {
    const display = escapeHtml(`${rawPath}:${line}`);
    const reexportBadge = showBadge
        ? ` <span class="file-usage-reexport" title="${escapeHtml(badgeTitle)}">${l10n('packageDetail.fileUsages.reexportBadge')}</span>`
        : '';
    return `<div class="${itemClass}">`
        + `<a href="#" data-action="openFile" data-path="${escapedPath}" data-line="${line}">${display}</a>`
        + reexportBadge
        + `</div>`;
}

function buildDependenciesSection(r: VibrancyResult): string {
    const deps = r.pubDev?.dependencies;
    if (!deps?.length) { return ''; }

    const chips = deps.map(name => {
        const url = `https://pub.dev/packages/${encodeURIComponent(name)}`;
        return `<a href="#" class="dep-chip" data-action="openUrl" data-url="${escapeHtml(url)}">${escapeHtml(name)}</a>`;
    }).join(' ');

    return section(l10n('packageDetail.section.dependencies'), `<div class="dep-list">${chips}</div>`);
}

function buildAlertsSection(r: VibrancyResult): string {
    const items: string[] = [];

    if (r.github?.isArchived) {
        items.push(alertItem(escapeHtml(l10n('packageDetail.alerts.archived')), 'critical'));
    }
    if (r.knownIssue?.reason) {
        items.push(alertItem(escapeHtml(l10n('packageDetail.alerts.knownIssue', { reason: r.knownIssue.reason })), 'critical'));
    }
    if (r.isUnused) {
        items.push(alertItem(escapeHtml(l10n('packageDetail.alerts.unused')), 'info'));
    }

    // Flagged issues
    const flagged = r.github?.flaggedIssues ?? [];
    for (const issue of flagged) {
        const signals = issue.matchedSignals.join(', ');
        items.push(alertItem(
            `<a href="#" data-action="openUrl" data-url="${escapeHtml(issue.url)}">`
            + `#${issue.number}</a>: ${escapeHtml(truncate(issue.title, 80))} `
            + `<em>(${escapeHtml(signals)})</em>`,
            'info',
        ));
    }

    // Vulnerabilities
    for (const vuln of r.vulnerabilities) {
        const icon = severityEmoji(vuln.severity);
        const fixInfo = vuln.fixedVersion ? ` ${escapeHtml(l10n('packageDetail.alerts.fix', { version: vuln.fixedVersion }))}` : '';
        items.push(alertItem(
            `${icon} <a href="#" data-action="openUrl" data-url="${escapeHtml(vuln.url)}">`
            + `${escapeHtml(vuln.id)}</a>: `
            + `<span class="vuln-severity-${vuln.severity}">${escapeHtml(vuln.summary)}</span>`
            + fixInfo,
            vuln.severity === 'critical' || vuln.severity === 'high' ? 'critical' : 'info',
        ));
    }

    if (items.length === 0) { return ''; }
    return section(l10n('packageDetail.section.alerts'), items.join(''));
}

function buildVersionGapSection(
    gap: VersionGapResult | null,
    label: string,
    reviews: readonly ReviewEntry[],
    summary: ReviewSummary | null,
): string {
    if (!gap) { return ''; }
    if (gap.items.length === 0 && !gap.fromDate) {
        // Could not determine version dates — show empty message
        return section(buildVersionGapTitle(label, gap),
            `<div class="loading-spinner">${escapeHtml(l10n('packageDetail.versionGap.noDates'))}</div>`);
    }
    if (gap.items.length === 0) {
        return section(buildVersionGapTitle(label, gap),
            `<div class="loading-spinner">${escapeHtml(l10n('packageDetail.versionGap.noItems'))}</div>`);
    }

    // Unique prefix per section so IDs don't collide when both gaps render
    const sectionId = label.toLowerCase().replace(/\s+/g, '-');

    const reviewMap = new Map(reviews.map(r => [r.itemNumber, r]));

    const prCount = gap.items.filter(i => i.type === 'pr').length;
    const issueCount = gap.items.filter(i => i.type === 'issue').length;

    const summaryCards = `
        <div class="gap-summary">
            <div class="gap-card">
                <div class="count">${prCount}</div>
                <div class="label">${l10n('packageDetail.versionGap.prsMerged')}</div>
            </div>
            <div class="gap-card">
                <div class="count">${issueCount}</div>
                <div class="label">${l10n('packageDetail.versionGap.issuesClosed')}</div>
            </div>
        </div>
    `;

    // §4.3 / §14.15 — radio-style segmented control. Buttons share a .seg
    // band so they read as a single control surface, and the active state
    // uses the inactive-selection backdrop tint instead of the primary-
    // button vocabulary (which is reserved for tier-1 actions like
    // *Upgrade*). One option is always selected; *All* is the resting
    // default.
    const toolbar = `
        <div class="gap-toolbar" data-section="${sectionId}">
            <label class="sr-only" for="gap-search-${sectionId}">${l10n('packageDetail.versionGap.searchLabel')}</label>
            <input type="text" id="gap-search-${sectionId}" class="gap-search" placeholder="${l10n('packageDetail.versionGap.searchPlaceholder')}">
            <span class="seg" role="radiogroup" aria-label="${l10n('packageDetail.versionGap.filterAria')}">
                <button class="filter-btn active" role="radio" aria-checked="true" data-filter="all">${l10n('packageDetail.versionGap.filterAll')}</button>
                <button class="filter-btn" role="radio" aria-checked="false" data-filter="unreviewed">${l10n('packageDetail.versionGap.filterUnreviewed')}</button>
                <button class="filter-btn" role="radio" aria-checked="false" data-filter="prs">${l10n('packageDetail.versionGap.filterPrs')}</button>
                <button class="filter-btn" role="radio" aria-checked="false" data-filter="issues">${l10n('packageDetail.versionGap.filterIssues')}</button>
            </span>
        </div>
    `;

    const tableRows = gap.items.map(item => {
        const review = reviewMap.get(item.number);
        const status = review?.status ?? 'unreviewed';
        const notes = review?.notes ?? '';
        const typeClass = item.type === 'pr' ? 'type-pr' : 'type-issue';
        const typeLabel = item.type === 'pr' ? l10n('packageDetail.versionGap.typePr') : l10n('packageDetail.versionGap.typeIssue');
        const searchText = [
            `#${item.number}`, item.title, item.author,
            ...item.labels, typeLabel, status,
        ].join(' ').toLowerCase();

        return `
            <tr data-number="${item.number}"
                data-type="${item.type}"
                data-review="${status}"
                data-searchtext="${escapeHtml(searchText)}">
                <td data-sort-number="${item.number}">
                    <a href="#" data-action="openUrl" data-url="${escapeHtml(item.url)}"
                       class="${typeClass}">#${item.number}</a>
                </td>
                <td class="${typeClass}" data-sort-type="${item.type}">${typeLabel}</td>
                <td data-sort-title="${escapeHtml(item.title)}">
                    ${escapeHtml(truncate(item.title, 80))}
                    ${item.labels.length > 0
                        ? `<br><small>${item.labels.map(l => escapeHtml(l)).join(', ')}</small>`
                        : ''}
                </td>
                <td data-sort-author="${escapeHtml(item.author)}">${escapeHtml(item.author)}</td>
                <td>
                    <select class="review-select" value="${status}">
                        <option value="unreviewed"${status === 'unreviewed' ? ' selected' : ''}>—</option>
                        <option value="reviewed"${status === 'reviewed' ? ' selected' : ''}>${l10n('packageDetail.versionGap.reviewReviewed')}</option>
                        <option value="applicable"${status === 'applicable' ? ' selected' : ''}>${l10n('packageDetail.versionGap.reviewApplicable')}</option>
                        <option value="not-applicable"${status === 'not-applicable' ? ' selected' : ''}>${l10n('packageDetail.versionGap.reviewNotApplicable')}</option>
                    </select>
                    <input class="notes-input" type="text"
                           placeholder="${l10n('packageDetail.versionGap.notesPlaceholder')}"
                           value="${escapeHtml(notes)}">
                </td>
            </tr>
        `;
    }).join('');

    const table = `
        <table class="gap-table">
            <thead>
                <tr>
                    <th data-col="number">#<span class="sort-arrow"></span></th>
                    <th data-col="type">${l10n('packageDetail.versionGap.colType')}<span class="sort-arrow"></span></th>
                    <th data-col="title">${l10n('packageDetail.versionGap.colTitle')}<span class="sort-arrow"></span></th>
                    <th data-col="author">${l10n('packageDetail.versionGap.colAuthor')}<span class="sort-arrow"></span></th>
                    <th>${l10n('packageDetail.versionGap.colReview')}</th>
                </tr>
            </thead>
            <tbody>${tableRows}</tbody>
        </table>
    `;

    const footerText = summary
        ? l10n('packageDetail.versionGap.summaryFooter', {
            triaged: String(summary.triaged),
            total: String(summary.total),
            applicable: String(summary.applicable),
            notApplicable: String(summary.notApplicable),
            unreviewed: String(summary.unreviewed),
        })
        : '';
    const footer = `<div class="gap-footer review-summary">${footerText}</div>`;

    const truncatedNote = gap.truncated
        ? `<div class="gap-footer"><em>${escapeHtml(l10n('packageDetail.versionGap.truncated', { limit: '100' }))}</em></div>` : '';

    const title = buildVersionGapTitle(label, gap);
    return section(title, summaryCards + toolbar + table + footer + truncatedNote);
}

/**
 * Section title for a version-gap block: the localized label plus the
 * current→latest version range. The arrow is a glyph (not a word), so only
 * the surrounding versions interpolate; the label is already localized by
 * the caller.
 */
function buildVersionGapTitle(label: string, gap: VersionGapResult): string {
    return `${label} (${escapeHtml(gap.currentVersion)} → ${escapeHtml(gap.latestVersion)})`;
}

function buildPlatformsSection(r: VibrancyResult): string {
    if (!r.platforms?.length) { return ''; }
    const platforms = r.platforms.map(p => escapeHtml(p)).join(', ');
    const wasm = r.wasmReady ? ` &middot; ${l10n('packageDetail.platforms.wasm')}` : '';
    return section(l10n('packageDetail.section.platforms'), `<div>${platforms}${wasm}</div>`);
}

function buildSuggestionsSection(r: VibrancyResult): string {
    if (!r.alternatives?.length) { return ''; }
    const items = r.alternatives.map(alt => {
        /* Letter grade only (alts don't carry a category, so derive from score). */
        const gradeText = alt.score !== null ? ` (${scoreToGrade(alt.score)})` : '';
        const url = `https://pub.dev/packages/${encodeURIComponent(alt.name)}`;
        return `<div>
            <a href="#" data-action="openUrl" data-url="${escapeHtml(url)}">${escapeHtml(alt.name)}</a>${gradeText}
        </div>`;
    }).join('');
    return section(l10n('packageDetail.section.suggestions'), items);
}

function buildImagesSection(r: VibrancyResult): string {
    const images = r.readme?.imageUrls;
    if (!images?.length) { return ''; }

    // Exclude the logo (already shown in header) and cap at 4 gallery images
    const galleryImages = images
        .filter(url => url !== r.readme?.logoUrl)
        .slice(0, 4);
    if (galleryImages.length === 0) { return ''; }

    const items = galleryImages.map(url =>
        `<a href="#" data-action="openUrl" data-url="${escapeHtml(url)}">`
        + `<img src="${escapeHtml(url)}" alt="${escapeHtml(l10n('packageDetail.images.alt'))}" loading="lazy" />`
        + `</a>`,
    ).join('');

    return section(l10n('packageDetail.section.readmeImages'), `<div class="image-gallery">${items}</div>`);
}

function buildLinksRow(r: VibrancyResult): string {
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(r.package.name)}`;
    const docUrl = `https://pub.dev/documentation/${encodeURIComponent(r.package.name)}/latest/`;
    const repoUrl = resolveRepoUrl(r.github?.repoUrl, r.pubDev?.repositoryUrl);
    const links: string[] = [];
    links.push(actionLink(pubUrl, l10n('packageDetail.links.viewOnPubDev')));
    links.push(actionLink(docUrl, l10n('packageDetail.links.documentation')));
    links.push(actionLink(`${pubUrl}/changelog`, l10n('packageDetail.links.changelog')));
    links.push(actionLink(`${pubUrl}/versions`, l10n('packageDetail.links.versions')));
    if (repoUrl) {
        links.push(actionLink(repoUrl, l10n('packageDetail.links.repository')));
        links.push(actionLink(`${repoUrl}/issues`, l10n('packageDetail.links.openIssues')));
        links.push(actionLink(`${repoUrl}/issues/new`, l10n('packageDetail.links.reportIssue')));
    }
    return `<div class="links-row">${links.join(' &middot; ')}</div>`;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build an <a> tag styled as a link that opens a URL via the webview message handler. */
function actionLink(url: string, label: string): string {
    return `<a href="#" class="action-link" data-action="openUrl" data-url="${escapeHtml(url)}">${escapeHtml(label)}</a>`;
}

function section(title: string, body: string): string {
    return `
        <div class="section">
            <div class="section-header">${title}</div>
            <div class="section-body">${body}</div>
        </div>
    `;
}

function row(label: string, value: string): string {
    return `<tr><td>${escapeHtml(label)}</td><td>${value}</td></tr>`;
}

function alertItem(html: string, severity: 'critical' | 'info'): string {
    return `<div class="alert-item ${severity}">${html}</div>`;
}

function truncate(text: string, max: number): string {
    return text.length > max ? text.substring(0, max - 3) + '...' : text;
}

function wrapHtml(title: string, body: string): string {
    // Nonce-based CSP instead of `'unsafe-inline'`. With `unsafe-inline` any
    // registry-supplied string that escapes `escapeHtml` (e.g. via an attribute-context
    // edge case) can execute as script; a nonce blocks that fallback. Every other
    // editor-area panel in this extension uses the same nonce pattern — see html-utils.ts.
    const nonce = createWebviewCspNonce();
    // §8.1 — pass the bare package name; buildDocumentTitle prepends
    // "Saropa ". Previously this string read "Saropa Package: foo" — two
    // nouns in front of the actual package identifier.
    const docTitle = escapeHtml(buildDocumentTitle(title));
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}'; img-src https:;">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${docTitle}</title>
    <style nonce="${nonce}">${getDashboardChromeStyles()}${getPillButtonStyles()}${getPackageDetailStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
    <a href="#package-detail-main" class="skip-link">${l10n('packageDetail.a11y.skipToDetails')}</a>
    <div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
    <main id="package-detail-main" tabindex="-1">
    ${body}
    </main>
    ${buildKeyboardShortcutsOverlay([
        { key: '?', label: l10n('packageDetail.shortcuts.showOverlay') },
        { key: 'Esc', label: l10n('packageDetail.shortcuts.closeOverlay') },
    ])}
    <script nonce="${nonce}">
        ${getPackageDetailScript()}
        (function() { ${getFullWidthToggleScript()} ${getKeyboardShortcutsScript()} })();
    </script>
</body>
</html>`;
}
