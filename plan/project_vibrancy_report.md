# Project Vibrancy Report

> **Last reviewed:** 2026-04-20
> **Status:** Proposed — not started

<!-- cspell:disable -->
## Goal

Apply the package-vibrancy model to the project's **own code** instead of its dependencies. Where the package report asks "how healthy is each dependency?", the project report asks "how healthy is each file/function we wrote ourselves?" — surfacing code that is old, untested, unused, and complex so it can be refactored, deleted, or covered.

## Relationship to Package Vibrancy

| Dimension | Package Vibrancy | Project Vibrancy |
|---|---|---|
| Unit scored | one pub.dev dependency | one project file / function |
| Data sources | pub.dev, GitHub API, pubspec.lock | `git`, LCOV, analyzer element model, AST |
| Categories | vibrant / stable / outdated / abandoned / end-of-life | fresh / stable / stale / rotting / dead |
| Grades | A–F via `scoreToGrade` | A–F, same mapping |
| Refresh cadence | on scan (network) | on scan (local, much faster) |
| Output surfaces | tree, code lens, HTML, SBOM | tree, gutter badge, HTML, CI JSON |

The intent is to reuse the existing scoring → classifier → grade → HTML pipeline where it already fits ([extension/src/vibrancy/scoring/vibrancy-calculator.ts](extension/src/vibrancy/scoring/vibrancy-calculator.ts), [status-classifier.ts](extension/src/vibrancy/scoring/status-classifier.ts), [category-dictionary.ts](extension/src/vibrancy/category-dictionary.ts), [views/report-html.ts](extension/src/vibrancy/views/report-html.ts)) and only add new collectors.

## Signals

### 1. Age (git)
- **Per-line:** `git blame --line-porcelain -w --ignore-revs-file=.git-blame-ignore-revs -- <file>` → author-time epoch per line. The `-w` and ignore-revs flags are mandatory, not optional — see [Mass-format resilience](#mass-format-resilience) below.
- **Per-file:** `git log --follow --format=%at --diff-filter=A -- <file>` → first-seen; most-recent-touched from `%at` of HEAD.
- **Per-function:** aggregate the blame range of the function's AST span (max or median line age).
- **Why per-line:** LCOV is per-line, so blame × LCOV joins cleanly for "old AND uncovered".
- **Normalization:** map age → 0–100 via a decaying curve (e.g. `100 * exp(-days/365)`). Fresh = high score. Matches `calcPublishRecency` shape.

#### Mass-format resilience
A single `dart format` commit or a sweeping rename touches every line in the repo and resets every timestamp. The Age signal would then classify the entire project as `fresh` and hide all real rot. Unacceptable — this would be the single most common way the report lies.

Mitigations, layered:
1. **Always pass `-w` to `git blame`** — ignores whitespace-only changes. Catches the simplest case (pure formatting with no logic change).
2. **Always pass `--ignore-revs-file=.git-blame-ignore-revs`** — honors the project's ignore-revs file, same convention used by `git`, GitHub, and GitLab for surfacing true authorship through formatting commits. If the file doesn't exist, the flag is a no-op; no harm done.
3. **Heuristic detection of suspect commits** — during a scan, the age collector samples HEAD's N most recent commits that touched ≥30% of scored files. If any of them has a commit-message match (`format`, `formatter`, `rename`, `bulk`, `license`) or a whitespace-dominant diff ratio, the report emits a non-fatal warning: "Commit `<sha>` looks like a mass edit and may skew Age. Consider adding to `.git-blame-ignore-revs`." Never auto-edits the file.
4. **Never** blindly trust the blame timestamp. The Age signal's decaying curve is long-tailed (~365 days half-life) precisely so that a single missed ignore-rev doesn't flip categories overnight.

### 2. Test Coverage (LCOV + trivial-assertion detection)
- **Source:** `dart test --coverage=coverage` → `coverage/lcov.info`.
- **Granularity:** per-line hit counts, aggregated to per-function (% of lines hit) and per-file.
- **Score:** direct percentage → 0–100. This is the **highest-weight signal** — untested production code is the chronic risk the report exists to surface.
- **Coverage ≠ correctness.** A `divideBy(n)` that never null-checks `n` can be 100% line-covered by a happy-path test and still crash in production. The report reveals coverage gaps; it does not audit test thoroughness. Users must still read their assertions. The report mitigates this only indirectly — by showing the linked test files for each function so the user can inspect what is actually being asserted.
- **Test files are excluded from scoring but linked.** Test files get no score of their own and do not appear as report rows. Each production-code row shows the test files that cover it (derived from LCOV source-file references). If the user asks, show tests as a separate linked view — never roll their coverage into the headline project grade.

#### Trivial-assertion filter
Raw LCOV hit counts are easy to game. A test that executes every line of a function but never checks the output looks identical to a real test at the LCOV level. The coverage collector therefore runs an AST pass over each test and **discards line hits contributed by tests whose assertions are trivial or absent**. This is enforced as an anti-pattern by design — developers who write `assert(true == true)` or equivalent should see their coverage signal reflect reality.

Patterns classified as trivial (detected by AST + light flow analysis, not string match):
- Tautological equality: `expect(x, x)`, `expect(1, 1)`, `expect(literal, sameLiteral)`.
- Trivially-true asserts: `assert(true)`, `assert(1 == 1)`, `assert(true == true)`, `assert(!false)`.
- Tautological matchers: `expect(obj, isA<Object>())`, `expect(obj, isNotNull)` when `obj` was just constructed non-null in the same test.
- Empty-body tests, print-only bodies, setup-only bodies (arrange + act, no verify).
- Invoke-but-don't-check: the test calls the system under test but no subsequent assertion (any recognized form — see below) references the return value or observable state.

#### Recognized assertion forms (extensible whitelist)
`expect` and `assert` are not the only real assertions. Projects using mocking frameworks assert via `verify`; domain projects register custom `Matcher` subclasses. The filter must recognize them or it will flag robust tests as stubs and destroy trust.

Tokens and call patterns treated as non-trivial assertions by default:
- `expect(...)` / `expectLater(...)` with a non-tautological matcher.
- `assert(...)` with a non-trivially-true expression.
- **mocktail / mockito:** `verify(...).called(N)`, `verifyNever(...)`, `verifyInOrder(...)`, `verifyZeroInteractions(...)`. The `when(...).thenReturn/thenAnswer/thenThrow` calls are recognized as *setup*, not assertions — the pattern only counts as a real test if a subsequent `verify` exists or the stubbed call's return is passed through `expect`.
- **bdd_widget_test / patrol / integration_test:** framework-specific `Then` steps and patrol finders that assert (`expect(find.byType(Foo), findsOneWidget)`).
- **Custom `Matcher` classes:** any call whose static return type resolves to `Matcher` (or a subtype) is treated as a real assertion target.
- **User-declared assertion helpers:** a project can register additional identifiers via `saropaLints.projectVibrancy.assertionIdentifiers: ["verifyDomainEvent", "assertInvariant", ...]`. These are matched against identifiers in the AST, not substrings.

A test counts as non-trivial if it contains ≥1 call that matches any of the above. Tests containing only `when(...)` setup (no `verify`, no `expect` on the result) are still trivial — setup without verification is the exact anti-pattern we're catching.

A test with ≥1 non-trivial assertion contributes its hits normally. A test with zero non-trivial assertions contributes zero hits — the production function it "covers" is treated as uncovered.

Flag: **`stub_tested`** — set on a production function whose only LCOV-reported coverage comes from tests filtered out as trivial. This is strictly worse than `uncovered` because the test file exists and implies coverage that isn't real. Surface these first in the flag inbox.

#### Suspicious-coverage flag (dense-Dart defense)
Line coverage is cheap to game in Dart because a single line can hold multiple decision points (`??`, `?.`, cascades, ternaries, `&&`/`||` short-circuits). A 100%-line-covered function with cyclomatic complexity 12 exercised by one happy-path test is almost certainly not really 100% covered at the branch level. Dart's built-in coverage tool does not emit branch coverage, so we mitigate at the flag layer rather than the signal layer — **keeping the formula explainable is a hard requirement; dynamically rebalancing weights was considered and rejected for that reason**.

Flag: **`suspicious_coverage`** — set when:
- cyclomatic complexity ≥ 10, AND
- line coverage ≥ 90%, AND
- distinct test executions reaching the function (count of `test()` blocks whose hits touch it) < complexity / 3.

The user reads the flag as "coverage looks high but complexity and test-case count don't support it — inspect your tests". No score adjustment; the flag is the whole treatment.

- **Gotcha:** generated files (`*.g.dart`, `*.freezed.dart`) must be excluded or they swamp the average with uncovered codegen.

### 3. Usage / Orphan State
- **Hardest signal** — no `git`-only answer exists.
- **Private symbols:** already covered by analyzer's `unused_element` lint. Consume its diagnostics.
- **Public symbols inside the package:** build a reverse-reference map from the analyzer element model (walk every compilation unit, record `Element.reference` of each `Identifier` that resolves to a declaration in the same package). Zero in-package references = `unused` flag set.
- **Public API is not treated as "always referenced."** Re-exports from `lib/` get scored the same as any other symbol — zero internal callers is still zero internal callers, even if the symbol is exported. "Always" is a useless signal. External callers are the user's problem to know about; the report reports what it can see.
- **Entry-point exclusions (narrow):** `main()`, framework callbacks with runtime entry annotations (`@pragma('vm:entry-point')`), widget `build()`, GetX/Riverpod/Bloc lifecycle methods invoked by their framework. These are invoked by the runtime or framework — not by static callers — so zero-reference measurement is simply wrong for them. Everything else gets its real reference count.
- **Score:** reference count bucketed (0 = 0, 1–2 = 40, 3–9 = 70, 10+ = 100). The bucketing still drives the composite score; the `unused` flag is an independent boolean.
- **Why a flag, not a category override:** dead code is history, and Flutter/Dart tree-shakes at build. A function with zero callers is a strong refactor/delete candidate but it is not categorically different from a function with three callers — the score already captures that. Surfacing `unused` as a filter flag lets the user find these without the report pretending unused code is automatically worthless.

#### Usage requires cross-file cache invalidation (blob-SHA is wrong)
Every other signal is a pure function of one file's content, so a blob-SHA cache works. Usage is not: deleting the only call site of `functionX` in `file_b.dart` by editing `file_a.dart` does not change `file_b.dart`'s blob SHA, yet `functionX` is now `unused`. A per-file blob-SHA cache would silently return the stale reference count and miss the transition. This is a correctness bug, not a performance tax.

**Two-tier cache architecture** — see [Scale](#scale) for mechanics. Per-file signals (age, coverage, complexity, documentation) cache by blob SHA. Usage caches by **project tree SHA** with an incremental rebuild: when any tracked file's blob SHA changes, the Usage collector re-walks only that file and any file that *previously* referenced symbols declared in it (a reverse dirty set). The whole-project reverse-reference map is persisted between scans; individual entries are re-computed only for dirty files.

#### Cascading orphan detection
When a function is flagged `unused`, walk its forward-call graph. Any callee whose *only* non-`unused` caller is the current function becomes unused-in-closure. Enrichment attached to each `unused` result:

```
checkOld()                        [F 2]  🏴 unused (cascades: 3)
  └── transitive dead weight:
       ├── parseLegacyOutput()    [D 38] — only caller was checkOld()
       ├── validateLegacyForm()   [C 51] — only caller was checkOld()
       └── oldSchemaAdapter()     [D 29] — only caller was checkOld()
```

Gives the developer the actual ROI of a deletion — one commit cleans up four functions, not one. The cascade is derived from the reverse-reference map; no extra pass needed. Cascaded functions are listed in the hover tooltip and the peek view on the `unused` flag.

### 4. Cyclomatic Complexity
- **Per-function:** AST visitor counts decision points (if, else, switch case, ternary, `&&`/`||`, catch, loops). Standard McCabe.
- **Score:** inverted — complexity 1 → 100, complexity ≥20 → 0, linear in between. Matches the repo's own `≤10` guideline from `global.md`.

### 5. Documentation / Comment Quality
- **Per-function:** AST walk over comment tokens attached to (or preceding) the declaration, plus `//` comments inside the body.
- **Three sub-measures combined into a 0–100 score:**
  1. **Doc-comment presence:** `///` block preceding the declaration. Presence alone is worth ~40 of the 100.
  2. **In-body comment density:** ratio of meaningful comment lines to code lines. Normalized so ~1 comment per 8–10 code lines hits the cap. Density alone is worth ~40.
  3. **Word-to-symbol ratio in comment bodies:** comments that are mostly prose (alphabetic words, whitespace) score higher than comments that are mostly punctuation or URLs. Prevents `// TODO` / `// !!!` / `// see http://…` from inflating density. Worth ~20.
- **Commented-out code is an anti-pattern, not a comment.** Every comment body is try-parsed as Dart (statement or expression fragment). If it parses, it is **subtracted from the score**, not added. Commented-out code is garbage — it must not reward the function.
- **Copyright/license headers are excluded** from both density and word-ratio measures — they are boilerplate, not documentation of the function.
- **Generated doc comments excluded:** IDE-inserted stubs (`/// TODO: Implement`, single-line `/// {@template ...}` placeholders with no body) count as absent, not present.
- **Low weight in the composite — high weight in flight-risk.** Comments are a tiebreaker for the score (see [Composite Score](#composite-score)) but they are a primary mitigator of [flight-risk](#phase-5--flight-risk-research). A well-documented complex old function is less risky than an undocumented one of the same shape.

## Composite Score

Mirror the package formula:

```
V_project = (W_A * Age) + (W_C * Coverage) + (W_U * Usage)
          + (W_X * Complexity) + (W_D * Documentation) − penalty
```

Default weights (tunable via settings, same pattern as `saropaLints.packageVibrancy.weights.*`):
- `W_A` = 0.15 (age alone is a weak signal; old code is often correct)
- `W_C` = 0.40 (untested code is the highest-leverage finding — weighted up from the initial 0.35 to match its designation as the critical signal)
- `W_U` = 0.25 (low-usage code is a refactor candidate, but tree-shaking makes it cheap to carry)
- `W_X` = 0.15 (complexity is a refactor trigger, not a bug; pulled down from 0.20 to make room for documentation)
- `W_D` = 0.05 (documentation is a tiebreaker in the composite; its real leverage is reducing flight-risk)

Weights sum to 1.00. Changing weights does **not** bust the signals cache — only the final scores recompute.

Penalties (hard deductions, cap at −30):
- Function >50 lines: −5
- Function params >3: −5
- Nesting >3: −5
- Coverage = 0% AND age > 365 days: −10 (the "rotting" combo)

Weights and penalties must be documented in a `ScoringWeights`-equivalent interface so the user can retune without code changes.

## Categories

Reuse `VibrancyCategory` shape and the `scoreToGrade` helper. Rename mappings for clarity:

| Category | Score band | Meaning | Action |
|---|---|---|---|
| fresh | ≥70 | recently touched, covered, used, simple | none |
| stable | 40–69 | mature, acceptable | monitor |
| stale | 20–39 | warning signs | plan refactor |
| rotting | <20 | multiple red flags | prioritize |

**No `dead` category.** Usage is a scored signal and a flag — not a classification override. A zero-caller function with high coverage, low complexity, and a recent commit still scores reasonably; the user filters by the `unused` flag to find delete candidates.

Independent flags attached to each result (orthogonal to category):
- `unused` — zero in-package callers (excluding narrow runtime/framework entry points). Carries a `cascades` count (see [Cascading orphan detection](#cascading-orphan-detection)).
- `uncovered` — coverage = 0% (no test hits at all).
- `stub_tested` — LCOV reports coverage but all contributing tests were filtered out as trivial. Strictly worse than `uncovered` because it implies safety that isn't real.
- `suspicious_coverage` — high complexity + high line coverage + too few distinct test cases to plausibly cover the branches (see [Suspicious-coverage flag](#suspicious-coverage-flag-dense-dart-defense)).
- `complex` — cyclomatic complexity > 10.
- `oversized` — >50 lines, >3 params, or >3 nesting levels (mirrors the repo's own hard limits).
- `undocumented` — documentation signal < 20 AND function has `complex` or `oversized`. Documentation alone is weak, but *missing* documentation on an already-hard-to-read function is a real hazard.
- `test_drift` — the production file has a most-recent-commit timestamp materially newer than the linked test file (thresholds: production touched within 30 days AND test file untouched for ≥6× as long). Catches "I changed the logic but didn't update the test to match the new behavior." Linked-test mapping comes from the LCOV collector, not filename heuristics, so tests in non-matching file names still match.

Hard overrides (same pattern as `classifyStatus`, but only *upward* now):
- Coverage 100% AND complexity ≤5 → `fresh` regardless of age (old + well-tested ≠ stale).

No downward overrides. A low score is reached by the formula, not by shortcut rules — that way the signals always explain the grade.

## Aggregation Units

Primary unit is the **function** (smallest unit where all four signals align). Everything above function is a rollup — views, not new measurements.

Roll up chain (each level is a weighted mean of the level below, weighted by line count):
- **Function** — the scored unit. All four signals join here.
- **Class** — rollup of its methods + any top-level scope it owns. Surfaces "one class is dragging a whole file down" where file-level rollup hid it. Required: the user's answer made this explicit.
- **File** — rollup of its classes + any top-level functions.
- **Directory** — rollup of its files. Surfaces "the `legacy/` folder is a tire fire" without manual drilldown.
- **Project** — single headline grade + per-category counts, exactly like `countByCategory`.

The class level is a genuine insight gap — a 100-line file with one tight class and one rotting class averages to "stable" at the file level; the class rollup shows the split.

Flag rollup: a class/file/directory's flag count is the sum of flagged functions beneath it. Flags never "dissolve" into averages.

## Output Surfaces

1. **CLI / JSON** — fits the existing `cross_file_cli_design.md` plan. `saropa_lints project-vibrancy --format=json`. Exit non-zero if project grade drops below a configurable floor, or if `unused`/`uncovered` flag counts exceed configured thresholds. This is the CI story.
2. **HTML report** — reuse [views/report-html.ts](extension/src/vibrancy/views/report-html.ts) structure. Virtualized table, one row per function, sortable by any signal. Static snapshots suitable for emailing/PR comments.
3. **VS Code sidebar** — primary interactive UI, a `Project Vibrancy` treeview alongside `Package Vibrancy`. Details in the [UI](#ui) section below.
4. **History sparkline** — reuse the `sparkline_vibrancy_history.md` model. Key by function signature (file path + name + arity). Cap snapshots the same way.

## Scale

The report has to work on a 1M-line codebase without turning the IDE into a brick. The controlling insight: a full cold scan is expensive, but 99% of subsequent scans only touch files whose git blob SHA changed. Everything in this section is designed around that.

### Two-tier cache (per-file blob SHA + project-level tree SHA)

Per-file signals are content-local: age, coverage, complexity, documentation all depend only on the bytes of one file. A blob-SHA cache is correct for them. **Usage is not content-local** — it depends on the state of every other file in the project. Caching Usage under blob SHA would silently return stale reference counts whenever a caller is modified without the callee's file changing. This was caught during review and is now a first-class architectural constraint.

**Tier 1 — per-file signals cache:**
- **Store:** `.saropa/project-vibrancy-cache/files/`.
- **Key:** `<blob-sha>-<collector-version>-<exclusion-set-hash>`. Blob SHA gives per-file content identity; collector version busts on code change; exclusion-set hash busts if the user edits the generated-file or entry-point patterns.
- **Value:** the per-file collected signals *except* usage. Weights changing do **not** bust this cache — only signals are stored; scores recompute cheaply.
- **Invalidation:** additive-only; stale entries age out on a size-capped LRU (default 500 MB).

**Tier 2 — project-level reverse-reference map:**
- **Store:** `.saropa/project-vibrancy-cache/usage/<tree-sha>.json` and a rolling `latest.json` symlink/pointer.
- **Key:** git tree SHA (from `git rev-parse HEAD^{tree}` or equivalent for the working tree).
- **Value:** the full project-wide reverse-reference map (`symbol_id → caller_file_set`) plus each symbol's reference count.
- **Incremental rebuild:** on any scan, compute the set of dirty files (blob SHA changed since last tree). For each dirty file: (a) remove its outgoing edges from the map, (b) re-walk it, (c) add its new outgoing edges. Incoming-edge invalidation for any symbol whose declaring file was dirty is handled by a second pass over the reverse-caller set of that symbol. The map is never rebuilt from scratch on normal scans.
- **Why tree-SHA not blob-SHA:** a single blob change can invalidate dozens of functions in other files; only a whole-tree identifier captures that state.
- **Cold-start cost:** full reverse-reference walk is the most expensive collector. Acceptable once; not acceptable per scan.

**One cache root for all scan shapes.** Single-file, single-folder, paused/resumed, full, and CI scans all read and write the same store. A single-file rescan updates Tier 1 for that file and patches Tier 2 incrementally for any symbols whose outgoing or incoming edges touched that file.

### Incremental detection

- `git ls-files -s <path>...` returns the blob SHA for every tracked file in one call (~50 ms on 50k files). Diff against the cache to decide which files need re-collection.
- Uncommitted changes: `git status --porcelain` finds dirty files; we hash their working-tree bytes with `git hash-object --stdin` so dirty and committed versions of the same path never collide in the cache.

### Scoped scans

All scoped scans go through the same worker and the same cache; they differ only in which files they feed in.

- **Single file:** `saropa_lints project-vibrancy --file lib/foo.dart`, or a "Rescan this file" context-menu action in the tree. Runs all collectors on one file, writes cache, updates project result.
- **Single folder:** `--folder lib/features/checkout/`, or "Rescan this subtree" on any tree node. Limited to descendants.
- **Diff scan:** `--since HEAD~10` — re-scans only files changed in the range. The default CI job.
- **Full scan:** `--all` — everything. Only needed once (first run) or after a collector version bump.

### Analyzer isolation (hard requirement on 1M lines)

The Usage collector walks the analyzer element model for the whole project. Dart's analyzer is memory-heavy: loading a 1M-line project into a fresh `AnalysisContext` can consume multiple gigabytes, and doing that inside the VS Code extension host will OOM the whole window — the existing language server is already using analyzer memory.

**The Usage collector always runs in a dedicated CLI subprocess.** Never in the extension host. Never in-process with the other collectors. The extension spawns `dart run saropa_lints:project_vibrancy --collect-usage --tree-sha <sha>` as a child process with its own memory budget. Output streams back via stdout as newline-delimited JSON events. This costs a process-spawn per scan but contains the memory hazard to a killable child.

Chunking inside the subprocess (for projects that still OOM):
- Process packages/directories sequentially, emitting partial reverse-reference summaries to disk.
- Merge summaries into the Tier-2 map after each chunk. Never hold the whole map in memory during the walk.
- On OOM, the subprocess dies; the extension restarts it with a smaller chunk size (binary-backoff). The Tier-2 map's incremental-rebuild design means a restart continues from the last persisted chunk — no full restart from zero.

The other four collectors (age, coverage, complexity, documentation) are per-file and cheap; they can run in the extension worker host or the same CLI subprocess as convenient.

### Background worker + live progress UI

Scanning never runs on the UI thread. The scan is a background worker (CLI process or VS Code extension worker host) that streams events; the UI consumes events and fills the tree incrementally.

- **Event stream:** one event per completed file: `{path, signals, elapsedMs}`. UI applies updates as they arrive — the tree populates live rather than blocking on a final payload.
- **Progress UI (required for every scan shape, including single-file):**
  - Percent complete: files done / files in scope.
  - Progress bar (VS Code `window.withProgress` for the tree; standard bar for CLI).
  - **Updating ETA**, recomputed on a rolling window of the last N file durations. Blame time dominates and correlates with file size, so the estimate is reasonably stable after ~50 files. Never show a frozen estimate — if the rolling average is unstable (variance too high), show "estimating…" instead of a fake number.
  - Per-collector breakdown on expand/hover: "blame: 43s, usage: 12s, lcov: 1s, complexity: 2s" — lets the user see which collector is slow without guessing.
- **Pause / Resume / Stop:**
  - **Pause:** worker finishes the current file, persists its cache entry, then blocks on a signal. Resume unblocks. Safe because each file is atomic in the cache — pausing never leaves half-written state.
  - **Stop:** abort after the current file. Partial results stay in cache; there is no "partial" vs "complete" distinction, only "last seen SHA set". The next scan resumes automatically from where this one stopped.
  - **Crash-safe:** a killed process is indistinguishable from Stop. No recovery step needed on next launch.
- **Responsiveness guarantees:**
  - UI thread never blocks on scan work. The tree remains clickable, scrollable, and filterable while a scan runs.
  - User-initiated rescans (single file/folder) preempt in-flight bulk scans by pushing to the front of the worker queue — a manual rescan never sits behind 10k queued files.
  - Tree expand/collapse, filter toggles, and view switches are instant (they operate on cached data, not pending results).

### Render scale

- 50k function rows is not a rendering problem if the primary view isn't a flat list.
- `TreeDataProvider` virtualizes rows — only visible nodes render. A collapsed tree with 50k descendants is cheap.
- HTML report uses a virtualized table (render ~20 rows, scroll lazily). "Export all rows to static HTML" is explicitly not a goal — use CLI JSON for that.
- Search indexes are built once per scan completion: a flat array sorted by score plus a simple trie on function names. Per-event updates patch both.

## UI

Primary UI is a **VS Code TreeView**. Hierarchy is the dominant axis and VS Code's tree primitive gives virtualization, checkboxes, icons, and sort handling for free. Complementary views sit alongside because a tree alone cannot answer "what's the whole-project heatmap?" or "what regressed this week?".

### Tree structure

Mirrors the aggregation units. Every node shows grade + score; every node can be a checkbox for scope inclusion.

```
Project Vibrancy  [B 64]        ☐ select all
├─ lib/                          [B 62]  ☒
│  ├─ src/                       [C 48]  ☒
│  │  ├─ rules/                  [D 31]  ☒
│  │  │  ├─ legacy_rules.dart    [F 11]  ☒
│  │  │  │  ├─ OldRule (class)   [F 8]   🏴×3 unused  🏴×5 uncovered
│  │  │  │  │  ├─ checkOld()     [F 2]   🏴 unused  🏴 uncovered  🏴 complex
```

### Checkboxes

Every node has an "include in totals" checkbox. Checking/unchecking re-aggregates the headline grade from whatever is checked — the underlying data doesn't change, only the view does. Use cases:
- "Show me my score if I ignore `legacy/`."
- "What's the grade for just `lib/features/checkout/`?"
- "Exclude all test fixtures from the total."

Checkbox state is persisted per workspace (`.saropa/project-vibrancy-ui.json`) so it survives reloads. A reset button clears all overrides.

### Filters (separate from checkboxes)

Checkboxes answer "what counts toward the total?" Filters answer "what do I want to see right now?" They are orthogonal and stack.

Toolbar filters:
- **Category:** fresh / stable / stale / rotting (multi-select).
- **Flags:** unused / uncovered / stub_tested / complex / oversized / undocumented (multi-select). A node matches if *any* of its descendants carry the flag.
- **Search:** free-text on function name, class name, or file path. Fuzzy match.
- **Delta:** "worsened since last scan" toggle — hides anything with non-negative score delta.

### Context-menu actions per node

- Rescan this node (file/folder).
- Open in editor (file or function — jumps to the exact declaration).
- Show linked tests (opens a peek view with the test files that cover this function).
- Copy JSON for this node (for bug reports, PR comments).
- Export HTML for this subtree.
- Exclude from total (equivalent to unchecking the checkbox).

### Complementary views (webview panels, linked from tree toolbar)

- **Directory heatmap:** grid of directories colored by grade. 1000 directories on a 30×30 grid is readable in one glance. Click a cell → jumps to that node in the tree, with it pre-expanded.
- **Delta view:** flat table of functions whose score moved since the last scan. Sorted worst-first by delta. Caps at ~200 rows — this is "what got worse", not an audit log.
- **Flag inbox:** flat list grouped by flag (unused / uncovered / stub_tested / suspicious_coverage / complex / oversized / undocumented / test_drift), paginated, sortable by score. `stub_tested` and `suspicious_coverage` surface first — they are the "false-green" lists. The "what needs attention" view.
- **Signal scatterplot:** 2D plot of every scored function, axes user-selectable. Defaults to **complexity (x) × coverage (y)** — the top-left quadrant (high-complexity, low-coverage) is the danger zone and needs no explanation. Other useful pairings: age × coverage, churn × coverage, usage × complexity. Click a dot → jumps to that function in the tree. A 2D plot shows distribution in a way a tree never can — "most of the project is healthy but there are 12 nasty outliers" is a single-glance answer here.

Tree is home. Heatmap / delta / flag inbox are linked from the tree toolbar and from each other — a user should never need to hunt through a command palette to switch views.

### Editor-surface visibility (fully user-controllable)

Every in-editor indicator is independently toggleable. No single "one true" editor surface — different developers have different noise tolerance, so the choice is theirs. Settings namespace: `saropaLints.projectVibrancy.editor.*`.

| Surface | Setting | Default | Behavior |
|---|---|---|---|
| **Gutter icon** | `gutter` | `on` | Small colored circle in the left gutter beside each function declaration. Color = grade (A green → F red). Clicking jumps to that function's node in the tree, pre-expanded. |
| **Minimap marker** | `minimap` | `on` | Colored tick on the VS Code minimap (`overviewRulerLane`). Lets the user see hot spots on scroll without opening the tree. Same color scale as gutter. |
| **CodeLens** | `codelens` | `off` | Inline `[grade score]` lens above the function declaration. Off by default because lens density is noisy on 1000-function files. When on, click opens the same focused tree-view navigation as the gutter icon. |
| **Hover tooltip** | `hover` | `on` | Rich hover on the gutter icon *or* the function name (whichever surface is active) showing the signal breakdown. This is the "why this grade" answer — always available when any editor surface is on, no extra click needed. |
| **Flag badges on gutter** | `flagBadges` | `on` | Tiny overlay icons on the gutter circle when a function has active flags (small "U" for unused, etc.). Off to reduce visual density; on for a more information-rich margin. |

Hover tooltip content:

```
Grade C (48)
─────────────
Age         old (2.3y)         → 30
Coverage    12% (stub_tested)  → 0       ⚠ tests filtered as trivial
Usage       3 callers          → 70
Complexity  8                  → 60
Comments    no doc, 2 lines    → 20
Penalties   fn >50 lines       → −5
─────────────
Linked tests: foo_test.dart (all filtered as trivial)
Callers: FooService.init, BarWidget.build
Last touched: 847d ago by alice (a3f4c21)

[Open in tree view]  [Rescan]  [Show linked tests]
```

Design principles:
- **Gutter / minimap never occupy code-doc space.** They live in the editor margin, not above or between lines. Doc comments are not pushed down.
- **Any active surface is clickable.** Click → tree view focused on the clicked function, with context on that node. No peek-panel overlay in the editor.
- **Hover is the "cheap look" path.** The user should not have to click or context-switch to understand *why* a function has its grade — the hover tooltip tells them without disturbing their flow.
- **All-off is a valid configuration.** A user who wants zero in-editor decoration should still get the full tree view, CLI, and HTML report. The editor surface is additive convenience, never the only way to see results.

### First-run and empty-state behavior

- First launch shows the tree with a top-level "Scan needed" node and a `Start scan` button. Clicking starts a full scan; the tree fills in live as events arrive.
- During any scan, a persistent progress strip at the top of the tree shows percent, ETA, and pause/stop buttons. The rest of the tree remains fully interactive — click-to-navigate on a partially-scored file works as soon as that file's event has fired.
- If a scan is interrupted, the tree shows partial scores with a subtle "stale" badge on un-scanned nodes. "Resume scan" picks up where it left off.

### What the tree is NOT

- Not a replacement for the VS Code file explorer. Only scored Dart files appear; `build/`, `*.g.dart`, and excluded paths are omitted.
- Not a blocking modal. At no point does the UI lock — cancel is always available.

## Implementation Phases

### Phase 1 — Collectors (parallel, independent)
- **git-age collector:** shell out to `git blame --line-porcelain` and `git log`, parse to `Map<filePath, Map<lineNumber, epochSeconds>>`.
- **lcov collector:** parse `coverage/lcov.info` (simple line-oriented format, no library needed). Second pass: run the trivial-assertion AST filter over every test file referenced in LCOV, discard hits from trivial-only tests, set `stub_tested` flag where all contributing tests were filtered.
- **complexity collector:** AST visitor counting decision points; emits `Map<functionId, int>`.
- **usage collector:** cross-file reference walker using analyzer element model; emits `Map<functionId, int>` (reference count) plus entry-point exclusion set.
- **documentation collector:** AST walk over doc comments and in-body comments, try-parse each comment body as Dart to classify as prose or commented-out-code, emit `Map<functionId, DocMetrics>` with doc-presence / density / word-ratio.

Each collector is independently testable against fixture projects. The trivial-assertion filter in the lcov collector needs its own fixture suite covering every pattern from the [Trivial-assertion filter](#trivial-assertion-filter) list plus variations.

### Phase 2 — Join + Score
- Function ID = `file:class:name(arity)` canonical string.
- Join all five maps on function ID. Missing signals default to neutral (50) — a function with no blame (never committed) should not be penalized.
- Apply the composite formula → `ProjectVibrancyResult { functionId, score, grade, category, signals, flags, penalties }`.

### Phase 3 — Surfaces
- CLI JSON output first (lowest risk, reusable by everything else).
- HTML renderer next (reuses package report templates).
- VS Code tree view last (highest ceremony). Editor-surface decorations (gutter, minimap, CodeLens, hover) ship with the tree view — they share the same data source.

### Phase 4 — History + Trends
- Append to `.saropa/project-vibrancy-history.json` on each scan.
- Sparklines only after a meaningful baseline accumulates.
- **PR delta gate:** GitHub Action that runs `--since <base>`, diffs against cached baseline on `main`, posts PR comment with regressed functions + new flags + grade delta. Gate thresholds (max grade drop, max new flags) configurable per repo.

### Phase 5 — Flight-Risk (research, gated on Phase 1 documentation collector)

Flight-risk is a predictive composite: which functions are most likely to cause an incident if the original author leaves or the code is touched in a hurry? Unlike the four primary signals, this one requires validation before shipping — a score with high wow-factor and low accuracy erodes trust.

**Candidate composition (to be validated, not shipped as-is):**
```
flight_risk = (age_factor × complexity_factor × churn_factor × lone_author_factor)
              × (1 − documentation_factor)
```
- `age_factor` — normalized age of the function. Old ≠ risky on its own, but old + other signals compounds.
- `complexity_factor` — cyclomatic complexity normalized to 0–1.
- `churn_factor` — number of distinct commits touching the function in the last N days. High churn = actively unstable.
- `lone_author_factor` — 1.0 if one author, dropping toward 0 as author count rises. Bus-factor proxy.
- `documentation_factor` — documentation score normalized to 0–1. Well-documented code reduces risk materially even when other factors are high. This is the point of signal #5.

**Why gated on docs:** without the documentation collector, flight-risk would flag every old complex function equally, ignoring that some are old-because-stable-and-well-documented. That would produce a noisy panic list and users would dismiss the feature.

**Research deliverables before shipping:**
- Validate against a set of real project incidents (commits that caused production bugs): does a high flight-risk score predict the offending function better than chance?
- Tune the multiplication vs. weighted-sum decision — multiplicative punishes any low factor heavily, which may be too severe.
- Decide whether flight-risk is a primary column in the tree, a flag, or its own view. Leaning: own view (not a flag — too fuzzy for a binary).
- Document the formula in code comments *and* in the plan, so users can audit *why* the tool called their function risky.

## Non-Goals (explicit)

- **Not** a replacement for existing lint rules. The function-length / param-count / nesting checks in `self-reviewer` stay where they are. The report consumes them as signals; it does not duplicate them.
- **Not** a code quality score in the abstract sense (no style, no naming, no "readability"). Five concrete signals only: age, coverage, usage, complexity, documentation.
- **Not** cross-language. Dart-only, same as the existing package scope.
- **Not** a replacement for per-file analyzer diagnostics. The report runs on demand or in CI, not on save.
- **No LLM-generated narrative, summary, or recommendation.** Copying raw JSON of issues/status is the only export format besides HTML. If users want prose, they write it.
- **No auto-generated test skeletons** for uncovered functions. Stub tests create a false sense of security — the coverage signal already penalizes them (see `stub_tested`). Shipping a generator that produces the exact shape we penalize would be contradictory.
- **No auto-PR for deletions.** `unused` is surfaced as a flag; deletion is always a human decision. One mis-flagged framework callback auto-deleted would destroy trust permanently.
- **No team / per-author heatmap.** Data could be derived from git blame, but the downside risk (blame tool in hostile orgs) outweighs the onboarding/load-balancing upside.

## Risks & Tradeoffs

- **Usage cache is architecturally distinct.** Blob-SHA caching is wrong for cross-file signals. The two-tier cache (blob for per-file, tree SHA for usage) is the response. Any future cross-file signal (e.g. the cascade closure, flight-risk lone-author analysis) inherits this constraint — never let a cross-file signal be cached under a per-file key.
- **Generated code skews every signal.** Blame is meaningless, coverage is 0%, complexity is high. Must be excluded by path pattern (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `build/`) before any collector runs.
- **`unused`-flag false positives.** Framework-driven callbacks and reflection targets can look like orphans. Since `unused` is a flag rather than a category override, the blast radius of a mis-flag is smaller. Still, the entry-point exclusion list for runtime-invoked callbacks is the single highest-leverage piece of this plan and will need ongoing maintenance. Err toward false negatives (miss some unused code) over false positives (flag live code).
- **Coverage ≠ correctness.** Already called out in the coverage signal, repeated here because it is the single most likely way a user will misread the report. A green "100% coverage" row can still contain uncaught null-derefs, unvalidated inputs, or happy-path-only assertions. The `suspicious_coverage` flag catches one shape of this (dense Dart), the trivial-assertion filter catches another (stub tests), but no automated signal replaces reading the assertions.
- **Mock-framework blindness would destroy trust.** The trivial-assertion filter *must* recognize `verify`/`verifyNever`/`verifyInOrder` and custom `Matcher` subclasses (see [Recognized assertion forms](#recognized-assertion-forms-extensible-whitelist)). A filter that flags every mocktail test as a stub and rots production scores `stub_tested` across the board is worse than no filter at all. The extensible `assertionIdentifiers` setting is the escape hatch.
- **Mass-format commits destroy Age.** `dart format` across the whole repo resets every line's blame timestamp and would reclassify the whole project as `fresh`. The Age collector honors `.git-blame-ignore-revs` and passes `-w` to `git blame` by default, and warns when HEAD contains likely mass-edit commits. This is a correctness bug if not mitigated.
- **Analyzer OOM in extension host.** The Usage collector runs in a dedicated CLI subprocess, never in-process with the extension or language server. Non-negotiable on any project large enough to need this tool.
- **Weight tuning.** Default weights will be wrong for most projects. Ship them as tunable from day one; do not hardcode.
- **Refactor churn inflates age.** A file renamed yesterday looks fresh even if the logic is old. `git log --follow` partially mitigates; full semantic history tracking is out of scope.

## Resolved Decisions

These were open questions at draft time; the answers are now folded into the plan above. Recorded here for the reasoning trail.

1. **Test files as scored units?** No — tests are hidden from the report but linked from each production-code row. Test coverage of production code remains the highest-weight signal (`W_C` = 0.40). Users must still inspect test thoroughness manually; coverage ≠ correctness.
2. **Public API treated as always-referenced?** No. "Always referenced" is a useless metric. Public re-exports from `lib/` get scored on their real in-package reference count, same as any private symbol. External callers are outside the report's visibility and outside its job. Only narrow runtime/framework entry points (`main()`, `@pragma('vm:entry-point')`, framework-invoked lifecycle methods) are excluded from usage scoring, because static reference counting is literally wrong for them.
3. **Per-function vs per-class as primary unit?** Per-function, but with explicit class-level rollup (plus file, directory, project). Class rollup is the level where "one rotten class in a healthy file" becomes visible.
4. **Auto-delete quick fix for dead code?** No, and more fundamentally: `unused` is a flag, not a category. Dead code is history, and Dart/Flutter tree-shakes at build. The report surfaces unused symbols via a filter; deletion is always the user's call.

## Success Criteria

- Runs locally in under the time of a full `dart analyze` on this project.
- JSON output is stable enough to diff between runs (same input → same output, ordered deterministically).
- At least one real finding on this project that the existing lint rules do not already surface. If the report tells the user nothing new, it has failed.
