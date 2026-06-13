/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import {
    PubOutdatedEntry, DepEdge, VibrancyResult,
    BlockerInfo, UpgradeBlockStatus, ConstrainedReason,
} from '../types';
import { compareVersions } from '../services/changelog-service';

/**
 * Classify upgrade status for a single pub outdated entry.
 * - up-to-date: current == latest
 * - upgradable: current < upgradable (can upgrade freely)
 * - blocked: resolvable < latest (something constrains it)
 * - constrained: upgradable < resolvable (your own constraint limits it)
 */
export function classifyUpgradeStatus(
    entry: PubOutdatedEntry,
): UpgradeBlockStatus {
    if (!entry.current || !entry.latest) { return 'up-to-date'; }
    if (compareVersions(entry.current, entry.latest) === 'up-to-date') {
        return 'up-to-date';
    }
    if (entry.resolvable && entry.latest
        && compareVersions(entry.resolvable, entry.latest) !== 'up-to-date') {
        return 'blocked';
    }
    if (entry.upgradable && entry.resolvable
        && compareVersions(entry.upgradable, entry.resolvable) !== 'up-to-date') {
        return 'constrained';
    }
    return 'upgradable';
}

/**
 * Find which packages block upgrades for blocked packages.
 *
 * For each package where resolvable < latest, walks the reverse dependency
 * graph to find which direct dependency is the likely blocker. Enriches
 * with the blocker's vibrancy score and category from scan results.
 */
export function findBlockers(
    outdated: readonly PubOutdatedEntry[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    results: readonly VibrancyResult[],
    directDeps: ReadonlySet<string>,
): BlockerInfo[] {
    const resultMap = new Map(results.map(r => [r.package.name, r]));
    const blockers: BlockerInfo[] = [];

    for (const entry of outdated) {
        if (classifyUpgradeStatus(entry) !== 'blocked') { continue; }
        const blocker = findBlockerForPackage(
            entry, reverseDeps, resultMap, directDeps,
        );
        if (blocker) { blockers.push(blocker); }
    }

    return blockers;
}

/**
 * Plain-text detail for a diamond / shared-transitive-dependency block, or
 * null for an ordinary reverse-dependency block. Names the shared dep, the
 * constraint that binds it, and the resolvable/latest gap so the user sees
 * WHY the sibling holds the package back — e.g. "via analyzer — saropa_lints
 * caps >=9.0.0 <13.0.0 (12.x resolvable, 13.x latest)".
 */
export function formatSharedDepDetail(blocker: BlockerInfo): string | null {
    if (!blocker.sharedDependency) { return null; }
    const parts = [`via ${blocker.sharedDependency}`];
    // SDK pins are opaque — there is no readable range, so name the SDK as the
    // pinner instead of printing a constraint that was never read.
    if (blocker.blockerIsSdkPin) {
        parts.push(`— pinned by ${blocker.blockerPackage} (Flutter SDK)`);
    } else if (blocker.blockerConstraint) {
        parts.push(`— ${blocker.blockerPackage} caps ${blocker.blockerConstraint}`);
    }
    if (blocker.sharedDependencyResolvable && blocker.sharedDependencyLatest) {
        parts.push(
            `(${blocker.sharedDependencyResolvable} resolvable, `
            + `${blocker.sharedDependencyLatest} latest)`,
        );
    }
    return parts.join(' ');
}

/**
 * Plain-text label for a documented pin intent ("Held: <reason>" /
 * "Do not use: <reason>"), or null when there is no intent. Lets the UI mark a
 * deliberate hold instead of presenting the dep as a missed upgrade.
 */
export function formatPinIntent(
    intent: { reason: string; kind: 'do-not-upgrade' | 'do-not-use' } | null | undefined,
): string | null {
    if (!intent) { return null; }
    const label = intent.kind === 'do-not-use' ? 'Do not use' : 'Held';
    return intent.reason ? `${label}: ${intent.reason}` : label;
}

/**
 * Only hosted (pub.dev) packages can be upgraded by editing a version
 * constraint. Git, path, and SDK deps are managed elsewhere, so a pub.dev
 * "latest" gap for them is not an actionable upgrade.
 */
export function isHostedUpgradeable(source: string): boolean {
    return source === 'hosted';
}

/**
 * Short note explaining why a non-hosted package's version gap is not a pub
 * upgrade (e.g. "via git override", "via path override", "SDK-managed"), or
 * null for a normal hosted package. Keeps the version arrow from reading as a
 * stuck pub bump when the dep is actually managed by an override or the SDK.
 */
export function managedSourceNote(source: string): string | null {
    switch (source) {
        case 'git': return 'via git override';
        case 'path': return 'via path override';
        case 'sdk': return 'SDK-managed';
        default: return null;
    }
}

/**
 * Plain-text reason for a `constrained` row — names the user's own constraint
 * and the version pub could otherwise reach, so the cap reads as actionable
 * ("your constraint ^1.9.0 caps this — 1.9.2 resolvable, 1.9.2 latest") rather
 * than a bare "constrained" label. Returns null when no reason is attached.
 */
export function formatConstrainedReason(
    reason: ConstrainedReason | null | undefined,
): string | null {
    if (!reason || !reason.constraint) { return null; }
    const tail = reason.resolvable
        ? ` — ${reason.resolvable} resolvable`
        + (reason.latest ? `, ${reason.latest} latest` : '')
        : '';
    return `your constraint ${reason.constraint} caps this${tail}`;
}

function findBlockerForPackage(
    entry: PubOutdatedEntry,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
    resultMap: ReadonlyMap<string, VibrancyResult>,
    directDeps: ReadonlySet<string>,
): BlockerInfo | null {
    const edges = reverseDeps.get(entry.package);
    if (!edges || edges.length === 0) { return null; }

    // Prefer direct dependencies as the reported blocker
    const directBlocker = edges.find(
        e => directDeps.has(e.dependentPackage),
    );
    const blockerName = directBlocker
        ? directBlocker.dependentPackage
        : edges[0].dependentPackage;

    const blockerResult = resultMap.get(blockerName);
    return {
        blockedPackage: entry.package,
        currentVersion: entry.current ?? '',
        latestVersion: entry.latest ?? '',
        blockerPackage: blockerName,
        blockerVibrancyScore: blockerResult?.score ?? null,
        blockerCategory: blockerResult?.category ?? null,
    };
}
