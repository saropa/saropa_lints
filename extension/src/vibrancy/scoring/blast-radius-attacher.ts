/**
 * Attaches an upgrade blast-radius verdict to each package that has a newer
 * version available, and answers "should the plain upgrade nudge be shown?".
 *
 * Pure — the caller supplies the graph, constraint index and SDK pins.
 */

import { DepEdge, VibrancyResult } from '../types';
import { ConstraintIndex } from './shared-dep-conflict-detector';
import { computeBlastRadius, BlastRadius, SdkBlock } from './upgrade-blast-radius';
import { l10n } from '../../i18n/runtime';
import { HELD_BACK_UPGRADES, HeldBackEntry } from './held-back-upgrades';

/**
 * FALLBACK ONLY. Used when SDK pins cannot be derived from the environment
 * (see services/sdk-pins.ts). `meta` matches the pin cited in the root
 * pubspec.yaml HARD STOP comment for analyzer 13.
 */
export const SDK_PINNED_PACKAGES: ReadonlyMap<string, string> = new Map([
    ['meta', '1.18.0'],
]);

export interface BlastRadiusContext {
    readonly reverseDeps: ReadonlyMap<string, readonly DepEdge[]>;
    readonly constraints: ConstraintIndex;
    readonly sdkPins?: ReadonlyMap<string, string>;
    readonly heldBack?: readonly HeldBackEntry[];
    /** Optional: target version's own dependency ranges, when known. */
    readonly targetDepsOf?: (pkg: string, version: string) => ReadonlyMap<string, string> | null;
}

/** Dependents of packages with updates: the names whose pubspecs are needed. */
export function blastRadiusCandidates(
    results: readonly VibrancyResult[],
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): Set<string> {
    const names = new Set<string>();
    for (const r of results) {
        if (!hasNewerVersion(r)) { continue; }
        for (const e of reverseDeps.get(r.package.name) ?? []) {
            names.add(e.dependentPackage);
        }
    }
    return names;
}

function hasNewerVersion(r: VibrancyResult): boolean {
    return !!r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date';
}

/** Returns results with `blastRadius` set for every package with an update. */
export function attachBlastRadius<T extends VibrancyResult>(
    results: readonly T[], ctx: BlastRadiusContext,
): T[] {
    return results.map(r => {
        if (!hasNewerVersion(r) || !r.updateInfo) { return r; }
        const blastRadius = computeBlastRadius({
            pkg: r.package.name,
            from: r.updateInfo.currentVersion,
            to: r.updateInfo.latestVersion,
            reverseDeps: ctx.reverseDeps,
            constraints: ctx.constraints,
            targetDeps: ctx.targetDepsOf?.(r.package.name, r.updateInfo.latestVersion) ?? null,
            sdkPins: ctx.sdkPins ?? SDK_PINNED_PACKAGES,
            heldBack: ctx.heldBack ?? HELD_BACK_UPGRADES,
        });
        return { ...r, blastRadius };
    });
}

/** True when the plain "upgrade to latest" nudge must not be shown. */
export function isUpgradeSuppressed(r: VibrancyResult): boolean {
    const b = r.blastRadius;
    return !!b && b.verdict !== 'safe';
}

/** Localized SDK conflict line, e.g. "analyzer 13.1.0 needs meta ^1.18.3; Flutter pins meta 1.18.0". */
export function formatSdkBlock(b: SdkBlock): string {
    return l10n('blastRadius.sdkBlock', { ...b });
}

/** Localized one-line verdict summary (UI edge; computeBlastRadius stays pure). */
export function describeBlastSummary(b: BlastRadius): string {
    return l10n(b.summaryKey, b.sdkBlock
        ? { ...b.summaryParams, sdk: formatSdkBlock(b.sdkBlock) }
        : b.summaryParams);
}

/** Localized breaker lines: "name (^12.0.0) via a -> b". */
export function formatBreakers(b: BlastRadius): string[] {
    return b.breakers.map(x => x.chain
        ? l10n('blastRadius.breakerVia', {
            name: x.name, constraint: x.constraint, chain: x.chain.join(' -> '),
        })
        : l10n('blastRadius.breaker', { name: x.name, constraint: x.constraint }));
}
