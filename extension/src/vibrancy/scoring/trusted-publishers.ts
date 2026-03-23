/**
 * # Trusted pub.dev publishers (Package Vibrancy)
 *
 * This module is the **single source of truth** for which pub.dev `publisherId`
 * values count as organizationally trusted when scoring and classifying dependencies.
 *
 * ## Consumers
 *
 * - **`calcPublisherTrust`** (`vibrancy-calculator.ts`) — adds the configurable
 *   publisher bonus when the resolved publisher matches this set.
 * - **`classifyStatus`** (`status-classifier.ts`) — if the numeric score would map
 *   to **Quiet** (mid tier driven largely by GitHub churn), trusted publishers are
 *   promoted to **Vibrant** so stable first-party release trains are not mislabeled.
 *
 * ## Safety / ordering
 *
 * Hard overrides in `classifyStatus` (discontinued on pub.dev, known end-of-life
 * entries, archived GitHub repo) run **before** the quiet-band logic, so trusted
 * publisher promotion **never** masks true EOL signals.
 *
 * ## Maintenance
 *
 * Publisher IDs are **case-sensitive** and must match pub.dev’s API exactly.
 * When Dart / Flutter / Google adds a new verified publisher for core packages,
 * append it here and extend unit tests in `status-classifier.test.ts` /
 * `vibrancy-calculator.test.ts` if behavior should be locked in.
 */
export const TRUSTED_PUBLISHERS = new Set<string>([
    'dart.dev',
    'google.dev',
    'flutter.dev',
    /** FlutterFire / Firebase packages (e.g. firebase_core, firebase_auth). */
    'firebase.google.com',
]);

/** True when the package is published under a trusted publisher (see `TRUSTED_PUBLISHERS`). */
export function isTrustedPublisher(publisher: string | null | undefined): boolean {
    if (publisher == null || publisher === '') {
        return false;
    }
    return TRUSTED_PUBLISHERS.has(publisher);
}
