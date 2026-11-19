# Vibrancy: upgrade blast-radius check

## Problem

The Package Vibrancy advisor recommends `analyzer` 13 because pub.dev's latest is 13.x. That upgrade breaks
the project: analyzer 13 needs `meta ^1.18.3`, Flutter stable pins `meta 1.18.0`, and several dependents cap
analyzer below 13. The knowledge already exists (pubspec.yaml HARD STOP comment,
plans/history/2026.06/2026.06.04/analyzer-12-support.md) but the advisor cannot read it.

## Goal

Before recommending `pkg X -> Y`, compute what the upgrade would break, and suppress or annotate the nudge.

## Scope (extension/src/vibrancy)

### Part A — pure scoring module (Agent A)

New `scoring/upgrade-blast-radius.ts`. Pure: no I/O, no VS Code API. Reuse `DepEdge` (types.ts),
`ConstraintIndex` (shared-dep-conflict-detector.ts), `pathToDirectDep`/`formatChain` (constraint-chain.ts).

Interface (Part B depends on this exactly):

```ts
export type BlastVerdict = 'safe' | 'breaks-dependents' | 'sdk-blocked' | 'held-back';

export interface BlastBreaker {
    readonly name: string;                 // dependent whose range excludes the target
    readonly constraint: string;           // its declared range on the package
    readonly chain: readonly string[] | null; // path from a direct dep (null when itself direct)
    readonly fixedInLatest: boolean | null;   // true/false when its own latest is known, else null
}

export interface BlastRadius {
    readonly pkg: string;
    readonly from: string;
    readonly to: string;
    readonly verdict: BlastVerdict;
    readonly breakers: readonly BlastBreaker[];
    readonly sdkBlock: string | null;      // e.g. "analyzer 13.1.0 needs meta ^1.18.3; Flutter pins meta 1.18.0"
    readonly heldBackReason: string | null;
    readonly summary: string;              // one line, user-facing
}

export function computeBlastRadius(input: {
    pkg: string; from: string; to: string;
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>;
    constraints: ConstraintIndex;
    targetDeps: ReadonlyMap<string, string> | null;   // target version's own dependency ranges (e.g. meta)
    sdkPins: ReadonlyMap<string, string>;             // package -> exact version pinned by the SDK
    heldBack: readonly HeldBackEntry[];
    latestOf?: ReadonlyMap<string, string>;           // dependents' latest versions
}): BlastRadius;
```

Rules: semver-check each dependent's range against `to` (`semver.satisfies`, unparseable range => not a
breaker); check `targetDeps` ranges against `sdkPins` (a pinned version outside the range => `sdk-blocked`);
match `heldBack` by package + version range. Precedence: held-back > sdk-blocked > breaks-dependents > safe.

Also new `scoring/held-back-upgrades.ts` exporting `HeldBackEntry { pkg; range; reason }` and a seeded
`HELD_BACK_UPGRADES` list with one entry: `analyzer`, `>=13.0.0`, reason mirroring the pubspec.yaml HARD STOP
(meta ^1.18.3 vs Flutter's meta 1.18.0 pin).

Tests: `extension/src/test/vibrancy/scoring/upgrade-blast-radius.test.ts` covering each verdict, the precedence
order, unparseable ranges, empty graph, direct vs transitive breaker chains.

### Part B — wiring (Agent B, after A lands its interface; may stub against the interface above)

1. Find where the advisor produces an upgrade recommendation / "update available" nudge (start from
   `scoring/blocker-analyzer.ts`, `scoring/upgrade-sequencer.ts`, `services/bulk-updater.ts`, and the report
   views). Attach `BlastRadius` to the per-package result type.
2. Build inputs: reverse deps via `buildReverseDeps` (services/dep-graph.ts), constraint index as the existing
   shared-dep-conflict code does, SDK pins from `sdk-packages.ts` / `flutter-releases.ts` (add `meta` and other
   Flutter-pinned packages only if a source already exists; otherwise a small documented table).
3. When verdict is not `safe`: suppress the plain "upgrade" nudge, show `summary` plus the breaker list in the
   tree/report/CodeLens, and exclude the package from bulk "upgrade all".
4. Tests for the wiring with fixtures, incl. the analyzer 12 -> 13 scenario end to end.

### Docs

CHANGELOG entry under the current `[Unreleased]` section following the MAINTENANCE NOTES rules in CHANGELOG.md
(one sentence per bullet, no file paths or code names). Update PACKAGE_VIBRANCY.md if it lists advisor behaviour.

## Out of scope

Auto-resolving conflicts; network fetch of every dependent's changelog; non-pub ecosystems.

## Verification

`cd extension && npm run compile && npm test` (or the repo's documented equivalents); lint clean.
