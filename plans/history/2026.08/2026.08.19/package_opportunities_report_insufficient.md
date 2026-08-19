# BUG: `package_opportunities` — Report output is a raw changelog dump, not an actionable analysis

**Status: Fixed** (2026-08-19)

Created: 2026-08-18
Feature: `package_opportunities` report generator
Severity: High — the report exists but does not serve its purpose

---

## Resolution note (2026-08-18)

Investigation found the `.log` file this bug was filed against does not match
any report this codebase currently generates — no code produces a `.log`
artifact for opportunities. It was traced to the per-package **"Copy for AI"**
clipboard button (`ai-prompt-bundle.ts`) in the in-editor Opportunities panel,
pasted once per package into a hand-assembled file. That is a SEPARATE,
older/simpler artifact from the newer `exportOpportunitiesReport` command
(`feature-inventory-*`, added 2026-08-07), which already does structured
per-category disclosure, usage tracking, and adopted/unadopted states — none
of that newer report's shortcomings apply here.

**Implemented** (scoped to the "Copy for AI" prompt, confirmed as the actual
target — see files below):

- **Deprecation audit** (§1) — deprecated-category changelog bullets are now
  cross-referenced against actual project call sites (via a shared
  `collectSymbolOccurrences` pass) and surfaced as a `## Deprecated APIs this
  project calls` section with file:line sites, ahead of the feature list.
- **Retrofit/greenfield reframing** (§2) — the task instruction now asks both
  questions instead of only "does it fit an existing call site".
- **Package health signals** (§4) — pulled from the already-computed
  `VibrancyResult` (score, category, license, pub.dev points, vulnerability
  count/severity, known-issue status) with zero new fetching.
- **GitHub issues triage** (§5) — `GitHubMetrics.flaggedIssues` (already
  fetched and signal-matched) is now included in the prompt.
- **Dev-only package filtering** — packages with zero active file usages are
  excluded from the Opportunities panel entirely instead of appearing with an
  explanatory "not imported" line.

Files touched: `extension/src/vibrancy/services/ai-prompt-bundle.ts`,
`extension/src/vibrancy/views/opportunities-panel.ts`,
`extension/src/vibrancy/extension-activation.ts` (async caller fix).
Tests: `extension/src/test/vibrancy/services/ai-prompt-bundle.test.ts` (+6).

**Deliberately NOT changed:** version-delta filtering of the mined
changelog. `opportunity-scan.ts` mines the *entire* changelog history on
purpose (documented rationale: "up-to-date" means the version constraint is
satisfied, not that every feature a caret constraint silently carried the
project through was adopted). The original bug's "Filter OUT: changelog
entries older than the previously installed version" would reverse that
intentional design and was dropped from scope.

**Implemented (2026-08-19)**:

- **Dual-dependency risk detection** (§3) — a new `## Dual dependency risk`
  section flags when a direct dependency is ALSO reachable transitively
  through another direct dependency (e.g. `flutter_cache_manager` required
  directly AND via `cached_network_image_ce`). Reused the reverse-dependency
  graph already computed during blocker analysis
  (`blocker-enricher.ts`/`dep-graph.ts`) rather than parsing `pubspec.lock`
  directly — `dart pub deps --json` already resolves the full graph and pub
  always resolves to one version per package, so the risk is framed as
  type-identity divergence (project code and a sibling package may each
  assume a shared exported class is "theirs"), not a version conflict. The
  via-package's own declared constraint on the shared dep is read via the
  existing `buildConstraintIndex` helper (same bounded pub-cache read used
  for diamond-conflict detection), so I/O stays limited to the packages
  actually involved in a detected risk.
  **Known limitation:** the Opportunities panel only creates a card for a
  package with unadopted changelog features; a package whose ONLY finding is
  a dual-dependency risk (no changelog opportunities) currently gets no card
  at all and the risk is silently uncomputed for it. This limitation is
  pre-existing and shared by the health/vulnerability sections added in the
  first pass — not new to this section. Loosening panel eligibility to
  "any risk section has content" is a follow-up, not done here.

Files touched: `extension/src/vibrancy/scoring/dual-dependency-detector.ts`
(new, pure), `extension/src/vibrancy/services/ai-prompt-bundle.ts`,
`extension/src/vibrancy/views/opportunities-panel.ts`,
`extension/src/vibrancy/extension-activation.ts` (passes the cached
reverse-dep graph through).
Tests: `extension/src/test/vibrancy/scoring/dual-dependency-detector.test.ts`
(new, 6 tests), `ai-prompt-bundle.test.ts` (+2).

**Implemented (2026-08-19)**:

- **Local reimplementation detection** (§6) — a new `## Possible local
  reimplementation` section flags project declarations (class/mixin/
  extension/top-level function/extension member) whose NAME matches
  something a dependency's own source exports. Reads the package's `lib/`
  tree from the local pub cache (`resolvePackagePaths`, the same
  `.dart_tool/package_config.json` resolution `enrichReplacementComplexity`
  already uses for LOC metrics) and extracts declared symbol names with a
  new heuristic brace-depth-tracked scanner
  (`local-reimplementation-detector.ts`), then cross-references against the
  project's own declarations extracted the same way. Deliberately
  name-only matching, not AST/type comparison — a same-named symbol with a
  different signature still surfaces, so the prompt explicitly tells the
  reader to confirm behavior before deleting local code (see the bug's own
  "deeper AST comparison is a later refinement" framing for §6).
  **Known limitations:**
  (1) scans the package's full `lib/` tree, not its actual re-exported
  public surface (following `export ... show/hide` chains through the
  barrel file is a further refinement) — an internal, non-exported symbol
  can produce a false "you could use this" match;
  (2) shares the same panel-eligibility limitation noted under §3 — a
  package with a reimplementation match but no changelog opportunities gets
  no card.

Files touched: `extension/src/vibrancy/services/local-reimplementation-detector.ts`
(new, pure), `extension/src/vibrancy/services/ai-prompt-bundle.ts`,
`extension/src/vibrancy/views/opportunities-panel.ts`.
Tests: `extension/src/test/vibrancy/services/local-reimplementation-detector.test.ts`
(new, 11 tests), `ai-prompt-bundle.test.ts` (+2).

---

## Summary

The `package_opportunities` report (e.g. `reports/20260816_package_opportunities.log`)
dumps every changelog entry since initial release for each package, appends a list
of importing files, and pastes an identical generic task prompt. It does not
surface deprecations the project calls, missed adoption opportunities, package
health signals, or known issues. The report is not useful for its stated purpose:
finding what a project should be doing differently with the packages it already
imports.

**Root cause:** The opportunity report pipeline is an island — it ignores the
vibrancy subsystem that already collects health scores, vulnerability data,
GitHub issue signals, license classification, staleness metrics, pub.dev scores,
and flagged issues. The data exists; the report doesn't use it.

---

## What the report delivers today

1. Raw changelog dump — full history, not delta from previously installed version
2. Files that import the package (file:line)
3. Symbols mentioned in changelog entries
4. Copy-paste task prompt: "decide whether it fits an existing call site"

## What the report should deliver

The report's job is to produce a **triage-ready brief per package** that an AI
session (or human) can act on without heavy background research. It does not need
to contain the answers — it needs to raise the right questions with enough context
to make investigation efficient.

---

## Required sections per package

### 1. Deprecation audit (CRITICAL — missing entirely)

**Feasibility: Medium — integration + symbol matching.**
The changelog parser already classifies `deprecated` bullets (`changelog-opportunities.ts`).
`issue-signals.ts` detects deprecation patterns in GitHub issues (16 regex patterns).
`collectSymbolOccurrences` already matches symbols against project source.
**Work:** Wire existing deprecation data into the report. Cross-reference deprecated
symbols from changelogs against project call sites via the existing symbol scanner.

Cross-reference the project's actual call sites against the package's deprecated
API surface. For each deprecated symbol the project uses, emit:

```
DEPRECATED: errorWidget (CachedNetworkImage)
  Replaced by: errorBuilder
  Used at: lib/components/primitive/web/link_preview_horizontal_view.dart:438
  Risk: will break on next major version
```

This is the highest-value section. It is machine-checkable and currently missing.

### 2. Adoption opportunities (present but broken)

**Feasibility: High — template and classification rework.**
`rankOpportunities` and `buildAiPromptBundle` already exist. `extractApiNames`
already parses changelog symbols. `collectSymbolOccurrences` already scans
project source.
**Work:** Add retrofit/greenfield classification to `mineOpportunities`. Rework
the AI prompt template to be package-specific based on scan findings.

The current "does it fit an existing call site" framing is backward-looking. The
report should ask TWO questions:

- **Retrofit:** Does a new API replace something the project does manually?
- **Greenfield:** Does a new API solve a problem the project has but hasn't
  addressed?

**Spot-check example — `cached_network_image_ce` (4.10.0, 7 files):**

| Feature | Type | Finding |
|---------|------|---------|
| `disablePlaceholderOnCacheHit` | Retrofit | Both `CachedNetworkImage` call sites show placeholder even on cache hits. Setting `true` eliminates the flash-of-spinner for revisited images. `common_network_image.dart:291`, `link_preview_horizontal_view.dart:155` |
| `CleanupStrategy` / LRU eviction | Greenfield | `SaropaImageCacheManager` uses default time-based eviction only. No user-facing "clear image cache" exists. With 500 cached objects at 1-5MB each, potential 2.5GB storage with no recourse. LRU would bound this. `saropa_image_cache_manager.dart:1` |
| `connectionParameters` (timeout) | Greenfield | No HTTP timeout configured. Under Wikimedia rate-limiting (429s), requests hang for default timeout. `common_network_image.dart` handles 429 errors (line 368) but doesn't prevent them structurally. |
| `httpClientFactory` | Retrofit | Wikimedia User-Agent header is passed per-request via `httpHeaders:`. A factory would centralize this and make it testable. |

**Spot-check example — `saropa_dart_utils` (1.6.3, 1,301 files):**

| Feature | Type | Finding |
|---------|------|---------|
| `retry_utils.dart` / `exponential_backoff_utils.dart` | Retrofit | Project has local `lib/utils/primitive/retry_utils.dart` that reimplements retry+backoff. Library version exists, is tested, and maintained. |
| `fuzzy_search_utils.dart` / `did_you_mean_utils.dart` | Greenfield | Project depends on `fuzzywuzzy` AND has local `string_list_fuzzy_match.dart`. Library may eliminate the third-party dep entirely. |
| `list_nullable_extensions.dart` | Retrofit | Local `isListNullOrEmpty` reimplements what the library exports. |
| `double_aspect_ratio_extensions.dart` | Retrofit | Local `toAspectRatio()` duplicates library version. |
| `json_diff_patch_utils.dart` | Retrofit | Local `json_compare.dart` does deep JSON diff. Library has equivalent — APIs need comparison. |

The current report would list none of these because it only asks "does changelog
item X fit an existing call site" — it never asks "does the project have local
code that duplicates what the package offers."

### 3. Dual-dependency and type-system risks (missing entirely)

**Feasibility: Medium — lockfile parsing + existing dep data.**
The scan orchestrator already resolves dependencies and their constraints.
Pubspec parsing exists in `override-parser.ts`. Transitive dependency data is
available from the pub cache lockfile.
**Work:** Parse `pubspec.lock` for transitive deps, cross-reference against
direct deps in `pubspec.yaml`, flag overlaps with divergent constraints.

Flag when the project imports a package AND its transitive dependency separately,
creating type-system divergence risk:

```
RISK: dual dependency on flutter_cache_manager
  Direct: pubspec.yaml:235 (flutter_cache_manager ^3.4.2)
  Transitive: via cached_network_image_ce → flutter_cache_manager ^3.4.1
  Used for: HttpExceptionWithStatus (common_network_image.dart:9)
  Risk: major version bump of either breaks type identity
  Action: import HttpExceptionWithStatus from cached_network_image_ce's re-export
```

### 4. Package health signals (ALREADY BUILT — just not piped to this report)

**Feasibility: High — pure integration, no new data collection.**
The vibrancy subsystem already collects ALL of these signals:
- `VibrancyResult.installedVersionDate` + `calcPublishRecency()` → last release / staleness
- `GitHubMetrics.trueOpenIssues` + `closedIssuesLast90d` → issue count + maintainer activity
- `PubDevMetrics.pubPoints` (max 160) → maintenance score
- `Vulnerability` type + OSV/GHSA scanning (`osv-api.ts`, `github-advisory-api.ts`) → CVEs
- `classifyLicense()` in `license-classifier.ts` → license tier (permissive/copyleft/unknown)
- `flagHighSignalIssues()` in `issue-signals.ts` → breaking change signals
- `KnownIssue` curated DB in `known_issues.json` → known problematic packages
- `calcEngagementLevel()`, `calcResolutionVelocity()` → maintainer responsiveness
- `vibrancy-history.ts` → trend data (rolling 50 snapshots)

**Work:** Pass `VibrancyResult` into the report renderer. It's already computed
during the scan — the opportunity pipeline just doesn't read it.

Per package, emit:

- **Last release date** — stale packages are risk
- **Open issues count** — high count with low maintainer activity is risk
- **Test coverage** — if the package advertises it (pub.dev badge)
- **Maintenance score** — pub.dev grants/maintenance score
- **Known CVEs or security advisories** — if any
- **License** — flag changes (e.g. `archive` changed to MIT)
- **Breaking change warnings** — any GitHub issue tagged "breaking" that affects
  the pinned version range

### 5. GitHub issues triage (ALREADY BUILT — just not piped to this report)

**Feasibility: High — pure integration.**
`flagHighSignalIssues()` in `issue-signals.ts` already fetches open GitHub issues,
matches titles against 16 signal patterns (`deprecated`, `breaking change`,
`crash`, `memory leak`, etc.) and 6 label signals (`breaking`, `critical`,
`blocker`, `regression`). Results are stored in `GitHubMetrics.flaggedIssues`
as `FlaggedIssue[]` with `matchedSignals` and `commentCount`.

**Work:** Include `flaggedIssues` from the existing `VibrancyResult` in the
report output. Format with project-relevance context from call-site data.

For each package, scan the top issues by reactions/comments for:

- Confirmed bugs affecting the version the project uses
- Workarounds the project should apply
- Features the project requested or would benefit from
- Migration guides for upcoming breaking changes

Emit as:

```
ISSUE: cached_network_image#NNN — "CachedNetworkImage flickers on rebuild"
  Status: Open, 47 reactions
  Affects: current version
  Workaround: set disablePlaceholderOnCacheHit: true
  Project relevance: HIGH — both call sites affected
```

### 6. Local reimplementation detection (missing — highest value for internal packages)

**Feasibility: Medium — extends existing symbol scanning.**
`extractApiNames` already parses symbols from changelogs. `collectSymbolOccurrences`
already scans project source for symbol matches. Pub downloads package source to
the local pub cache, so exported APIs are readable from disk.
**Work:** Scan the package's exported API surface from its pub cache source (not
just changelogs). Compare exported symbol/function names against the project's
own utility files. Name-based matching catches obvious duplicates; deeper AST
comparison is a later refinement.

For packages like `saropa_dart_utils` where the source is available, scan the
consuming project for:

- Extension methods that duplicate library extensions
- Utility classes that reimplement library utilities
- Import shims that could be simplified
- Library features the project has never imported but clearly needs

This is the scanner's unique value proposition: no human or AI session can
efficiently do this cross-project comparison at scale. The linter can.

---

## Filtering and priority (currently absent)

### Filter OUT

- Dev-only packages with zero source imports (e.g. `build_runner` — the current
  report includes it and then says "not imported in any scanned source file")
- ~~Changelog entries older than the previously installed version~~ —
  **rejected, see Resolution note above.** Full-history mining is deliberate:
  it is how an up-to-date package's unadopted features (shipped across
  releases a caret constraint silently carried the project through) get
  surfaced at all.
- Documentation-only changes, README updates, example app changes
- Platform support additions for platforms the project doesn't target

### Rank BY

1. Deprecations the project actively calls (fix or it breaks)
2. Local reimplementations of library features (delete code)
3. Features that address known project pain points (improve)
4. Package health warnings (risk)
5. Greenfield opportunities (nice-to-have)

### Group BY

- **Action required** — deprecated APIs, breaking changes, health warnings
- **Action recommended** — reimplementations, high-value retrofits
- **Informational** — greenfield opportunities, version notes

---

## Task prompt problem

The current task prompt is identical for every package:

> "For each new feature above, decide whether it fits an existing call site in
> this project. Read the real API before recommending — do not assume behavior
> from the changelog wording. Reject decorative-only changes that do not clarify
> a state transition. Output per feature: `file:line → concrete change`, or
> 'no fit' with one reason."

This is backward-looking (existing call sites only), generic (same prompt for a
2-file zip utility and a 373-file collection library), and asks the reader to do
the research the scanner should have done.

**Better:** Tailor the prompt per package based on what the scanner found. For
`cached_network_image_ce`:

> "This package has 7 call sites across image loading, cache management, and
> link previews. The project configures a shared DefaultCacheManager with 500
> objects / 30-day stale period but no LRU strategy, no user-facing cache clear,
> and no connection timeouts. Investigate: (1) does disablePlaceholderOnCacheHit
> eliminate the placeholder flash on cache hits at common_network_image.dart:291
> and link_preview_horizontal_view.dart:155? (2) does CleanupStrategy.lru bound
> disk usage without the 30-day wait? (3) should connectionParameters set a
> timeout to prevent hung Wikimedia requests?"

---

## What the scanner should NOT do

- **Do not resolve the opportunities.** The report raises questions; the AI
  session or human investigates. The scanner lacks project intent context.
- **Do not recommend version bumps.** That is a separate concern (dependency
  update tooling).
- **Do not rewrite call sites.** Surface the finding; the consumer decides.

---

## Acceptance criteria

A useful report lets a reader answer in under 30 seconds per package:

1. Am I calling anything deprecated? → **Yes/no + list** — ✅ done
2. Am I reimplementing something the package already does? → **Yes/no + list** — ✅ done (name-based match, see limitations under §6)
3. Is there a package feature that solves a problem I have? → **Ranked list** — ✅ reframed as retrofit/greenfield questions (not resolved, by design — see "What the scanner should NOT do")
4. Is this package healthy and maintained? → **Dashboard** — ✅ done
5. Are there known issues I should worry about? → **Top issues** — ✅ done (flagged GitHub issues)

Five of five now answered by the "Copy for AI" prompt. Dual-dependency risk
(§3) was not one of the five acceptance-criteria questions but is now also
implemented (see above).

---

## Implementation priority

| Priority | Section | Status | Notes |
|----------|---------|--------|-----|
| ~~P0~~ | ~~Version-delta filtering~~ | Rejected | Full-history mining is intentional design — see Resolution note |
| **P0** | Filter dev-only packages | ✅ Done | Excluded from Opportunities panel entirely |
| **P1** | Health signals (§4) | ✅ Done | Piped from existing `VibrancyResult` — zero new data collection |
| **P1** | GitHub issues (§5) | ✅ Done | `flaggedIssues` from `GitHubMetrics` — already fetched |
| **P1** | Deprecation audit (§1) | ✅ Done | Deprecated bullets cross-referenced against call sites |
| **P2** | Adoption reframing (§2) | ✅ Done | Task prompt asks retrofit + greenfield questions |
| **P2** | Dual-dependency risks (§3) | ✅ Done | Reused existing reverse-dep graph, not raw lockfile parsing |
| **P3** | Reimplementation detection (§6) | ✅ Done | Name-based match against project's own declarations; see limitations above |

---

## Environment

- Report file: `d:\src\contacts\reports\20260816_package_opportunities.log`
- Scanned packages: 10 (showing top 10 by relevance of 104 total)
- saropa_lints version: (check current)
- Dart SDK: (check current)
