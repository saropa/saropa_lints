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

/** Mirrors the HARD STOP comment on `analyzer` in the root pubspec.yaml. */
export const HELD_BACK_UPGRADES: readonly HeldBackEntry[] = [
    {
        pkg: 'analyzer',
        range: '>=13.0.0',
        reason: 'analyzer 13 needs meta ^1.18.3, but Flutter stable pins meta 1.18.0',
    },
];
