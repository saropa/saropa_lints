import { FlutterRelease } from '../services/flutter-releases';

export type DriftLabel =
    'current' | 'recent' | 'drifting' | 'stale' | 'abandoned';

export interface DriftInfo {
    readonly releasesBehind: number;
    readonly driftScore: number;
    readonly label: DriftLabel;
    readonly latestFlutterVersion: string;
}

/** Compute drift between a package's publish date and Flutter releases. */
export function calcDrift(
    publishedDate: string | null,
    releases: readonly FlutterRelease[],
): DriftInfo | null {
    if (!publishedDate || releases.length === 0) { return null; }
    const publishMs = Date.parse(publishedDate);
    if (isNaN(publishMs)) { return null; }

    const behind = releases.filter(
        r => new Date(r.releaseDate).getTime() > publishMs,
    ).length;

    return {
        releasesBehind: behind,
        driftScore: mapDriftScore(behind),
        label: driftLabel(behind),
        latestFlutterVersion: releases[0].version,
    };
}

function mapDriftScore(behind: number): number {
    if (behind === 0) { return 10; }
    if (behind === 1) { return 8; }
    if (behind === 2) { return 6; }
    if (behind <= 5) { return 4; }
    if (behind <= 6) { return 2; }
    return 0;
}

/** Human-readable label for a drift count. */
export function driftLabel(behind: number): DriftLabel {
    if (behind === 0) { return 'current'; }
    if (behind <= 2) { return 'recent'; }
    if (behind <= 5) { return 'drifting'; }
    if (behind <= 6) { return 'stale'; }
    return 'abandoned';
}
