/**
 * Data-payload builders for the vibrancy report: the per-package copy-as-JSON
 * map embedded for the copy/save buttons, the GitHub-stars sub-block (paired
 * with repo URL + monorepo-sibling count), and the dependency-network <details>
 * payload. These serialize results into webview-embedded data rather than
 * rendering visible chrome.
 */

import { VibrancyResult, activeFileUsages } from '../types';
import { categoryToGrade, categoryLabel } from '../scoring/status-classifier';
import { formatSizeKB } from '../scoring/bloat-calculator';
import { escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import { resolveRepoUrl, computeActivitySignal } from './report-html-shared';
import { buildAiPromptBundle } from '../services/ai-prompt-bundle';

export function buildNetworkSection(results: VibrancyResult[]): string {
    const direct = results.filter(r => r.package.isDirect);
    const nodes = direct.map(d => {
        const links = (d.transitiveInfo?.transitives ?? [])
            .filter(t => results.some(r => r.package.name === t))
            .slice(0, 20);
        return { name: d.package.name, links };
    });
    const payload = escapeHtml(JSON.stringify(nodes));
    return `<details class="network-wrap">
        <summary>${escapeHtml(l10n('packageDashboard.network.summary'))}</summary>
        <div id="dep-network" data-network="${payload}" class="network-canvas"></div>
    </details>`;
}

/**
 * Build a canonical-repo → count map so the JSON export can flag packages
 * that share a repo URL with other project packages. Stars on GitHub apply
 * to the whole repository (not to a subdirectory), so a high star count on
 * a monorepo sibling like `firebase_core` doesn't signal anything
 * `firebase_core`-specific — every Firebase package in the project would
 * report the same number. The sibling count lets consumers of the row JSON
 * disambiguate "this repo has 12k stars on its own merit" from "this repo
 * has 12k stars shared across 8 project packages".
 */
export function buildRepoShareMap(
    results: readonly VibrancyResult[],
): ReadonlyMap<string, number> {
    const counts = new Map<string, number>();
    for (const r of results) {
        const url = resolveRepoUrl(r);
        if (!url) { continue; }
        counts.set(url, (counts.get(url) ?? 0) + 1);
    }
    return counts;
}

// ---------------------------------------------------------------------------
// Copy-as-JSON data map
// ---------------------------------------------------------------------------

/** Build a script block embedding per-package JSON for the copy button. */
export function buildPackageDataScript(
    results: VibrancyResult[],
    overrideNames: ReadonlySet<string>,
    repoShareMap: ReadonlyMap<string, number>,
): string {
    const entries = results.map(r => {
        const key = JSON.stringify(r.package.name);
        const val = JSON.stringify(buildPackageJson(r, overrideNames, repoShareMap));
        return `${key}:${val}`;
    });
    /* Escape < to \u003c so embedded JSON cannot break out of the script tag */
    const raw = `var packageData={${entries.join(',')}};`;
    return raw.replace(/</g, '\\u003c');
}

/**
 * Build the `stars` JSON block: the raw GitHub star count paired with the
 * canonical repo URL and a monorepo-sibling count. Repo stars are not a
 * reliable per-package signal because every package in a monorepo
 * (firebase/flutterfire, bloclibrary/bloc, flutter/packages, ...) reports
 * the same number. We still surface the count because it's useful context
 * for the repo as a whole, but we pair it with `repoUrl` (so consumers can
 * click through) and `monorepoSiblings` (so they can discount the number
 * when >0). Returns null when no GitHub data was fetched.
 */
function buildStarsBlock(
    r: VibrancyResult,
    repoShareMap: ReadonlyMap<string, number>,
): { count: number; repoUrl: string | null; monorepoSiblings: number } | null {
    const count = r.github?.stars;
    if (count == null) { return null; }
    const repoUrl = resolveRepoUrl(r) ?? null;
    /* `repoShareMap` counts how many results resolve to the same repo URL;
       subtract this row to get the number of OTHER packages in the project
       sharing the repo. 0 siblings = dedicated repo, so the star count is
       reliable per-package. */
    const shared = repoUrl ? (repoShareMap.get(repoUrl) ?? 1) - 1 : 0;
    return { count, repoUrl, monorepoSiblings: Math.max(0, shared) };
}

/** Build a comprehensive JSON-safe object for one package row. */
function buildPackageJson(
    r: VibrancyResult,
    overrideNames: ReadonlySet<string>,
    repoShareMap: ReadonlyMap<string, number>,
): Record<string, unknown> {
    const name = r.package.name;
    const encoded = encodeURIComponent(name);
    const activeFiles = activeFileUsages(r.fileUsages);
    const repoBase = resolveRepoUrl(r) ?? null;
    const activity = computeActivitySignal(r);
    /* Pre-build the "Copy for AI" prompt here (extension side) so the webview
       button only has to copy a precomputed string. Uses the FULL-history
       opportunities (r.opportunities), so up-to-date packages with unadopted
       features get a prompt too — not just outdated ones. Null when nothing is
       adoptable, which hides the button. */
    const aiPrompt = r.opportunities
        ? buildAiPromptBundle({
            packageName: name,
            currentVersion: r.package.version,
            latestVersion: r.updateInfo?.latestVersion ?? r.package.version,
            opportunities: r.opportunities,
            fileUsages: activeFiles,
        })
        : null;
    return {
        name,
        version: r.package.version,
        constraint: r.package.constraint,
        section: r.package.section,
        isOverridden: overrideNames.has(name),
        health: {
            score: Math.round(r.score / 10),
            grade: categoryToGrade(r.category),
            resolutionVelocity: Math.round(r.resolutionVelocity),
            engagementLevel: Math.round(r.engagementLevel),
            popularity: Math.round(r.popularity),
            publisherTrust: Math.round(r.publisherTrust),
            activityScore: activity.score,
            activityGrade: activity.grade,
        },
        category: categoryLabel(r.category),
        published: r.pubDev?.publishedDate.split('T')[0] ?? null,
        /* Per-package pub.dev signals (what the Likes / Downloads table
           columns now show). These are the primary trust indicators we
           expose in the report because, unlike repo stars, they measure
           this specific package. */
        likes: r.likes ?? null,
        downloadCount30Days: r.downloadCount30Days ?? null,
        /* Repo-level context retained for consumers that still want the
           GitHub star count, paired with the repo URL and the count of
           other project packages sharing the same repo (monorepo
           detection). See buildStarsBlock for the rationale. */
        stars: buildStarsBlock(r, repoShareMap),
        openIssues: r.github?.trueOpenIssues ?? r.github?.openIssues ?? null,
        openPullRequests: r.github?.openPullRequests ?? null,
        /* Exported JSON keeps both fields so consumers can tell code size
           (what reaches the app) from on-disk archive (the gzipped tarball).
           `archiveSize` retained for backwards-compatibility with existing
           downstream parsers; `codeSize` is the new authoritative number. */
        codeSize: r.codeSizeBytes !== null ? formatSizeKB(r.codeSizeBytes) : null,
        archiveSize: r.archiveSizeBytes !== null
            ? formatSizeKB(r.archiveSizeBytes) : null,
        license: r.license ?? null,
        update: r.updateInfo ? {
            status: r.updateInfo.updateStatus,
            latestVersion: r.updateInfo.latestVersion,
        } : null,
        /* Ready-to-paste prompt that hands an AI the classified changelog
           opportunities plus this project's call sites. Null hides the
           "Copy for AI" button (no opportunities to adopt). */
        aiPrompt,
        /* Adoption-needle signals: the 0–100 relevance score that drives the
           Opportunities column sort and the count of unadopted features. Both
           0 when nothing is adoptable, so the sweep button can skip them. */
        opportunityScore: r.opportunityScore ?? 0,
        unadoptedCount: r.unadoptedApiNames?.length ?? 0,
        isUnused: r.isUnused,
        fileCount: activeFiles.length,
        // One entry per source file. Now that the scanner dedupes by
        // (filePath, isCommented), a file that both imports and
        // re-exports the same package is a single object with both
        // `import` and `export` line numbers populated — previously it
        // showed up as two separate `"path:line"` strings, which made
        // `fileCount` double-count the file.
        files: activeFiles.map(u => {
            const entry: Record<string, unknown> = { path: u.filePath };
            if (u.importLine != null) { entry.import = u.importLine; }
            if (u.exportLine != null) { entry.export = u.exportLine; }
            return entry;
        }),
        transitives: r.transitiveInfo ? {
            count: r.transitiveInfo.transitiveCount,
            flagged: r.transitiveInfo.flaggedCount,
            // Full dep list + shared markers mirrors the expander's
            // "Transitive Dependencies" section so the JSON has
            // everything the expander reveals visually.
            deps: [...r.transitiveInfo.transitives],
            sharedDeps: [...r.transitiveInfo.sharedDeps],
        } : null,
        vulnerabilities: r.vulnerabilities.map(v => ({
            id: v.id,
            summary: v.summary,
            severity: v.severity,
            cvssScore: v.cvssScore,
            fixedVersion: v.fixedVersion,
            url: v.url,
        })),
        description: r.pubDev?.description ?? null,
        platforms: r.platforms ?? null,
        verifiedPublisher: r.verifiedPublisher,
        wasmReady: r.wasmReady,
        links: {
            pubDev: `https://pub.dev/packages/${encoded}`,
            versions: `https://pub.dev/packages/${encoded}/versions`,
            /* Score page is the destination for the Likes / Downloads
               cells; including it here lets JSON consumers jump to the
               same view without rebuilding the URL. */
            score: `https://pub.dev/packages/${encoded}/score`,
            license: `https://pub.dev/packages/${encoded}/license`,
            changelog: `https://pub.dev/packages/${encoded}/changelog`,
            repository: r.pubDev?.repositoryUrl ?? null,
            issues: repoBase ? `${repoBase}/issues` : null,
            pullRequests: repoBase ? `${repoBase}/pulls` : null,
        },
    };
}
