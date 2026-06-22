# Package Analyzer — Dependency-Chain Reasoning + Pubspec Annotation

**Status:** Implemented (WS1–WS6 landed 2026-06-22)
**Date:** 2026-06-22
**Scope:** vibrancy extension dependency analysis (`extension/src/vibrancy/`)
**Decision (user, 2026-06-22):** "Both" — improve the in-tool reasoning AND emit the chain
explanations as pubspec annotations.

## Problem

The package analyzer reasons about dependency conflicts only **one hop deep**, only for
**hosted-package ceilings**, and **never emits the chain explanation**. The user hand-pastes
pub's own solver output (`Because … is forbidden` / `… is required`) and override rationale
(e.g. `disabled due to analyzer ^9.0.0 vs dart_style/isar <8.3.0 conflict`,
`D:\src\contacts\pubspec_overrides.yaml`) as comments. The analyzer should produce this.

Three motivating examples, each a different gap:

1. `dart_style >=3.1.9 depends on analyzer ^13.0.0` → `dart_style: ^3.1.8`
   A **ceiling** diamond: a sibling caps `analyzer <13`, so `dart_style`'s newer version is
   held back. The detector *can* catch this but only one hop and only if the constrainer is hosted.
2. `Because every version of flutter_test depends on characters 1.4.0 and saropa depends on
   characters ^1.4.1, flutter_test is forbidden`
   A **hard incompatibility** between a direct constraint and an SDK pin. Current model frames
   this as a "blocked upgrade," not "your constraint forbids an SDK package."
3. `Because saropa depends on device_calendar from git which depends on timezone ^0.11.0,
   timezone ^0.11.0 is required`
   A **git-sourced** chain forcing a **floor** (required-minimum). Two misses: the constraint
   index isn't built for git deps, and the analyzer reasons about ceilings only, never floors.

## Current state (grounded)

| Module | What it does | Limit |
|---|---|---|
| [blocker-analyzer.ts](../extension/src/vibrancy/scoring/blocker-analyzer.ts) `findBlockerForPackage` (L162) | Reverse-dep walk to find a blocker | **Single hop**; picks first/direct dependent, no chain |
| [shared-dep-conflict-detector.ts](../extension/src/vibrancy/scoring/shared-dep-conflict-detector.ts) | Diamond/sibling conflict | One pivot, **ceiling only**, hosted constrainers |
| [shared-dep-constraints.ts](../extension/src/vibrancy/services/shared-dep-constraints.ts) `buildConstraintIndex` | Reads constraint ranges from pub cache | Built only for caller-flagged **candidate** names |
| [override-analyzer.ts](../extension/src/vibrancy/scoring/override-analyzer.ts) `findTransitiveConstraint` (L113) | — | **Dead stub: always returns `null`**, so the transitive-conflict branch (L70-81) never fires |
| [annotate-packages.ts](../extension/src/vibrancy/providers/annotate-packages.ts) `formatAnnotation` | Writes `# description` + `# pub.dev URL` | **No constraint/chain text emitted** |

Enabling facts:
- `resolvePackagePaths` ([package-code-analyzer.ts](../extension/src/vibrancy/services/package-code-analyzer.ts#L55)) reads
  `.dart_tool/package_config.json`, which lists **every** resolved package incl. git/path —
  so any package's `pubspec.yaml` (and its declared constraints) is readable, not just hosted.
- `parsePubspecYaml` already returns a `constraints` map; `buildConstraintIndex` already turns
  per-package pubspecs into a `ConstraintIndex`. The data layer mostly exists; it is under-built
  and under-wired.

Inherent constraint: pub only prints `Because …` text on **resolution failure**. In a
resolved project (`pub get` succeeded) that text does not exist, so for the common case we must
**reconstruct** the chain from the resolved graph + per-package constraints. Where a resolution
genuinely fails, we can additionally **capture** pub's verbatim text (authoritative).

## Target model

One shared **constraint-chain resolver** that, for any dependency, answers:
- who constrains it (direct, sibling, transitive N-hops, or SDK pin),
- through what **path** (the edge list, each with its declared constraint),
- **direction**: ceiling (caps below latest) or floor (forces a minimum),
- **source** of each hop (hosted / git / path / sdk).

All four consumers (blocker-analyzer, conflict-detector, override-analyzer, annotation) read
from this one resolver instead of each re-deriving a slice.

## Workstreams

### WS1 — Full constraint index + kill the dead stub (foundation)
- Build the constraint index over **all** resolved packages and **all** sources (git/path
  included) via `resolvePackagePaths` + per-package `parsePubspecYaml`. Bound I/O with caching;
  reuse the existing pub-cache reads.
- Wire `override-analyzer.findTransitiveConstraint` to the real index, removing the stub so the
  transitive-conflict branch finally fires. Add a regression test that fails today.
- **Verifiable:** a test where an override resolves a multi-hop transitive cap now reports the
  real constrainer instead of falling through to the SDK heuristic.

### WS2 — Multi-hop chain walk
- BFS/DFS over `reverseDeps` from the blocked dep up to the binding constrainer, recording the
  path and each edge's declared constraint. Replace `findBlockerForPackage`'s single-hop pick
  with the full chain (keep the direct-dep preference as the *reported* head).
- Output a `ConstraintChain` value (ordered edges) the UI and annotator both consume.
- **Verifiable:** test `A → B → C → analyzer` reports the C-caps-analyzer edge, not B.

### WS3 — Floor constraints (required-minimum)
- Extend the binding test beyond ceilings: detect when a chain **forces a minimum** (example 3,
  `timezone ^0.11.0 required`). Add direction to the chain model.
- **Verifiable:** test git-dep `device_calendar` forcing `timezone ^0.11.0` reports a floor.

### WS4 — Hard-incompatibility class (forbidden)
- Detect the example-2 shape: a direct constraint vs an SDK/sibling exact pin that makes a
  package **forbidden** (not merely held back). Distinct status + message.
- **Verifiable:** test `characters ^1.4.1` vs SDK-pinned `characters 1.4.0` yields "forbidden".

### WS5 — Pubspec annotation emission
- Extend [annotate-packages.ts](../extension/src/vibrancy/providers/annotate-packages.ts) to
  write the chain explanation as a comment block above each blocked/constrained/floored package,
  in the same voice as pub (`# Because … is required`). Reuse `findExistingAnnotations` so
  re-runs replace, never duplicate; never clobber user `NOTE:`/`TODO:` lines.
- Gate behind the existing annotate command; idempotent round-trip.
- **Verifiable:** annotate → re-annotate produces a stable diff; user comments preserved.

### WS6 — Capture pub's verbatim text on failure (authoritative fallback)
- When a resolution attempt fails, capture pub's actual `Because …` lines and prefer them over
  the reconstruction for that package. Optional/last — strictly additive.

## Risks
- **Reconstruction vs pub.** Our derived chain can diverge from pub's true reasoning. Mitigate:
  capture verbatim text where available (WS6); keep reconstruction conservative (only emit a
  chain when the binding edge is unambiguous).
- **Annotation churn / clobbering.** Mitigate via `findExistingAnnotations` round-trip + the
  `NOTE:/TODO:/IMPORTANT` guard already in `isAutoDescription`.
- **Performance.** Reading many pubspecs. Mitigate: cache, and scope full reads to the contested
  subgraph as `buildConstraintIndex` already does.

## Sequencing
WS1 (foundation, includes a clear bug fix) → WS2 → WS3 → WS4 → WS5 → WS6.
Each lands with its own targeted test (run the single touched test file, `--no-pub`, backgrounded).

## Finish Report (2026-06-22)

The Package Vibrancy dependency analyzer reasoned about upgrade blocks only one
reverse-dependency hop deep, only for hosted-package ceilings, and never emitted
the reasoning anywhere editable. Three real-world conflict shapes were either
misreported or invisible: a held-back ceiling whose constrainer is buried
transitively, a required-minimum floor (common with git deps), and a declared
constraint that cannot coexist with a Flutter SDK pin. WS1–WS6 added the missing
reasoning and wired it through to pubspec annotations.

### Defects fixed
- `override-analyzer.findTransitiveConstraint` was a stub returning `null`, so the
  transitive-conflict branch in `findConflict` was dead code; overrides resolving
  a multi-hop transitive cap were misreported as removable ("stale") unless the
  SDK heuristic happened to catch them. It now reads declared ranges from the
  constraint index and names the binding sibling.
- The shared vscode test mock's `Range` accepted only the 4-number form, so the
  production `Range(Position, Position)` overload stored Positions in the line
  fields (`range.start.line` returned a Position, not a number). The mock now
  matches the real vscode overloads. This also exposed that two new test files
  were absent from `tsconfig.test.json`'s explicit include list and were being
  silently glob-skipped by mocha; all test files are now registered.

### What changed
- **Constraint index (WS1).** `buildConstraintIndex` reads every resolved
  package's pubspec via `package_config.json`, so git/path deps contribute
  declared ranges, not just hosted. The override runner stays vscode-free and
  receives the prebuilt index from the activation caller.
- **Multi-hop chain (WS2).** `constraint-chain.ts` BFS-walks the reverse-dep
  graph from a deep constrainer to the nearest direct dep (cycle-safe), recorded
  on `BlockerInfo.blockerChain` and rendered in `formatSharedDepDetail`.
- **Floor detection (WS3).** `floor-constraints.ts` finds the dependent imposing
  the highest lower bound on a shared dep.
- **Forbidden detection (WS4).** `forbidden-constraints.ts` flags a direct
  constraint that excludes the version an SDK package pins (resolved-yet-excluded,
  the state an override masks); conservative — only emits on a provable exclusion.
- **Annotation emission (WS5).** `constraint-notes.ts` assembles ceiling/floor/
  forbidden lines per direct dep. The enricher computes floor/forbidden findings
  (free for forbidden; bounded pub-cache reads for floor), returns them on
  `BlockerEnrichResult`, stored in activation state and exposed via
  `getLatestConstraintFindings`. The "Annotate pubspec" command writes the notes
  as comments tagged with a `↳` marker so re-runs replace them in place while
  hand-written `Because…`/`####` notes are preserved.
- **Verbatim pub text (WS6).** On a failed `dart pub get`/`deps`, the scan log
  captures pub's own "Because … is forbidden / is required" reasoning, the only
  place the authoritative cause is available since the reconstruction detectors
  need a resolved graph.

### Inherent limit
In a successfully-resolved project pub prints no explanation, so ceiling/floor/
forbidden are reconstructed from the resolved graph plus declared ranges; pub's
verbatim text is captured only on resolution failure.

### Test coverage
constraint-chain (8), floor-constraints (7), forbidden-constraints (6),
constraint-notes (5), pub-conflict-text (4); plus annotate-command round-trip (3)
and override-analyzer constraint-index regressions (2). Production type-check
clean.
