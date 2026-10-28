/**
 * Curated list of package upgrades known to break this project even though
 * pub.dev offers them. The advisor consults it so a "newer version available"
 * nudge is suppressed for versions a maintainer has deliberately held back.
 *
 * Pure data — no I/O, no VS Code API.
 */

export interface HeldBackEntry {
    readonly pkg: string;
    /** Semver range of target versions that must not be recommended. */
    readonly range: string;
    /** User-facing explanation of why the upgrade is held back. */
    readonly reason: string;
}

/**
 * CURATED FALLBACK: consulted only when lock/target-dependency data cannot
 * decide (see computeBlastRadius). Data-driven checks win when available.
 * Mirrors the HARD STOP comment on `analyzer` in the root pubspec.yaml. */
export const HELD_BACK_UPGRADES: readonly HeldBackEntry[] = [
    {
        pkg: 'analyzer',
        range: '>=13.0.0',
        reason: '(curated fallback) analyzer 13.0.0 needs meta ^1.18.0; 13.1.0 and later need meta ^1.18.3; Flutter 3.47+ satisfies it',
    },
];
