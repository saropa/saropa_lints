# BUG: vibrancy bloat rating uses pub.dev tarball size, not runtime bundle size — `audioplayers` over-reported ~500×, maintainer-quality folders mis-counted as bloat

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-05-13
Rule: N/A — vibrancy extension scoring (not a Dart analyzer rule)
File: `extension/src/vibrancy/scoring/bloat-calculator.ts`, `extension/src/vibrancy/scan-orchestrator.ts`, `extension/src/vibrancy/data/known_issues.json`, `extension/src/vibrancy/providers/hover-provider.ts`
Severity: Wrong rating / Misleading metric (High — drives package-choice decisions and a per-app size budget)
Rule version: N/A | Since: vibrancy bloat-calculator introduction | Updated: current

---

## Summary

Three product calls being made together:

1. **Surface code size, not tarball size.** The primary "size" number shown in the Problems panel, hover, and budget rollups must be what the package contributes to a compiled Flutter app (Dart `lib/` + assets declared in the package's own `pubspec.yaml` `flutter.assets:` + native plugin binaries from the platform sub-packages). The pub.dev tarball total (which includes `example/`, `test/`, `tool/`, `doc/`, sample servers, fixture media) moves to the hover tooltip as supplementary "total on disk" info, with a per-top-level-folder breakdown so the developer sees the asymmetry.
2. **Treat `example/`, `test/`, `tool/`, and `doc/` as positive health signals, not bloat.** Each is a maintainer-quality artifact — runnable demo, regression protection, maintainer automation, extended documentation. A package that ships them is healthier than one that doesn't, and the score must reward it. Currently they all roll into one tarball byte count that drags the bloat rating down — the wrong direction for all four.
3. **Stop conflating "install cost to my users" with "is this package well-maintained."** They want different inputs. One number (`archiveSizeBytes`) is doing both jobs and getting both wrong.

Concrete trigger: `audioplayers-6.6.0` is rated ~20 MB of bloat (rating 9/10) because its 21.62 MB `example/` folder is in the tarball. The actual app-bundle contribution is ~40 KB of `lib/` plus a few hundred KB of native binaries. With the new model, `audioplayers` would show code size ~300 KB, tooltip "21.72 MB on disk · 99% example/ · …", and earn positive health-score components for shipping `example/`, `test/`, and any of `tool/` / `doc/` it includes.

---

## Attribution Evidence

This is NOT a Dart analyzer rule. The surfacing path is the VS Code extension's vibrancy module.

```bash
# Surfacing call chain
grep -rn "archiveSizeBytes" extension/src/vibrancy/
# Matches:
#   extension/src/vibrancy/scoring/bloat-calculator.ts:9   — calcBloatRating()
#   extension/src/vibrancy/scan-orchestrator.ts:139,151,173,226 — resolveArchiveSize → bloatRating
#   extension/src/vibrancy/data/known_issues.json:2008    — audioplayers archiveSizeBytes seed value
#   extension/src/vibrancy/providers/hover-provider.ts:267-269 — renders "Archive: X MB"
#   extension/src/vibrancy/scoring/budget-checker.ts:59-60 — sums into per-app size budget
#   extension/src/vibrancy/scoring/comparison-ranker.ts:40 — ranks packages by archiveSizeBytes
```

**Surfacing files to change:** all six above, plus the health-score assembly site.
**Data file to audit (separate sub-defect):** `extension/src/vibrancy/data/known_issues.json` — the audioplayers entry at line 2002–2023 declares `appliesToMaxVersion: "1.0.0"` and a self-`replacement: "audioplayers"` (lines 2006, 4276); both look wrong.
**Diagnostic `source` / `owner` as seen in Problems panel:** vibrancy / saropa_lints extension hover and report (not a `// ignore:`-suppressible diagnostic).

---

## Reproducer

Project depends on `audioplayers: ^6.5.1`. Vibrancy hover shows:

```
audioplayers — Archive: 20.05 MB  (bloat 9/10)
```

Pub cache reality for `audioplayers-6.6.0`:

```
audioplayers-6.6.0/
  lib/        40 KB    ← compiled into the app
  test/       20 KB    ← never shipped — positive health signal
  example/  21.62 MB   ← never shipped — positive health signal
                          ├─ assets/ambient_c_motion.mp3                       8.02 MB
                          ├─ server/public/files/audio/ambient_c_motion.mp3    8.02 MB  (duplicate)
                          ├─ assets/nasa_on_a_mission.mp3                      1.44 MB
                          ├─ server/public/files/audio/nasa_on_a_mission.mp3   1.44 MB  (duplicate)
                          └─ ... laser.wav and live-stream test fixtures
  (no tool/ or doc/ in this package — neither penalty nor bonus)
```

**Frequency:** Always for any package that ships sample media or example servers in the tarball. Likely also: `video_player`, `lottie`, `rive`, `flutter_svg`, `cached_network_image`. `file_picker` is already flagged in `known_issues.json:2031` at 19.32 MB and almost certainly has the same shape.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected (primary line / Problems panel)** | `audioplayers — Code: ~300 KB` — `lib/` + declared assets + native binaries summed across `audioplayers_<platform>` sub-packages |
| **Expected (hover tooltip)** | `21.72 MB on disk · lib/ 0.2% · example/ 99.4% · test/ 0.1% · other 0.3%` — folder-level breakdown so the developer sees the asymmetry |
| **Expected (health score)** | Positive components for each maintainer-quality folder present: `+example` (runnable demo), `+test` (regression coverage), `+tool` (maintainer automation), `+doc` (extended documentation). `audioplayers` gains `+example` and `+test`. |
| **Actual (primary line)** | `Archive: 20.05 MB  (bloat 9/10)` — wrong by ~500× as a proxy for runtime cost |
| **Actual (hover)** | Same single number, no folder breakdown |
| **Actual (health score)** | All four folders count AGAINST the package via `calcBloatRating(archiveSizeBytes)`. `log10(21027379) ≈ 7.32 → (7.32 − 4.7) / 0.3 ≈ 8.74 → rating 9/10`. Packages that ship demos / tests / docs score worse than packages that don't — wrong direction on every one of the four signals. |

---

## AST Context

N/A — extension-side, no AST. The data flow:

```
scan-orchestrator.ts:139      Promise.all([..., resolveArchiveSize(...)])
  └─ resolveArchiveSize :219  → live pub.dev tarball Content-Length, falls back to known_issues.json
  └─ calcBloatRating :151-152  uses raw tarball bytes
  └─ hover-provider :267-269   "Archive: X MB" (single number, no breakdown)
  └─ budget-checker :59-60     sums totalSizeBytes into per-app budget
  └─ comparison-ranker :40     ranks packages by archiveSizeBytes
```

Every consumer of `archiveSizeBytes` needs to be re-pointed at the new `codeSizeBytes` field, except the hover tooltip which keeps `archiveSizeBytes` (and gains a per-top-level-folder breakdown). Health-score assembly site gains four new boolean inputs (`hasExample`, `hasTests`, `hasTools`, `hasDocs`).

---

## Root Cause

`fetchArchiveSize()` returns the gzipped pub.dev tarball size. That tarball is the full source tree the maintainer publishes — `lib/`, `example/`, `test/`, `tool/`, `doc/`, sample servers, fixture media. Flutter's build only consumes `lib/` (Dart), assets declared in the package's own `pubspec.yaml` under `flutter.assets:`, and native plugin binaries from the platform sub-packages. Nothing else from the tarball reaches APK / IPA / web bundle.

The vibrancy code treats one number (`archiveSizeBytes`) as both:
- the "what does this cost my users to install" metric (which it isn't — that's compressed, not installed, and excludes everything outside `lib/` / declared assets / native binaries)
- the "how clean is this package" health signal (which it isn't — it counts maintainer-friendly extras like demos, tests, tools, and docs *against* the package)

Both jobs need different inputs. Conflating them is the root cause. Worse, the second job has its sign flipped for the four folders that are actually positive signals.

Secondary data defect: the `known_issues.json` fallback at `scan-orchestrator.ts:226` is not version-gated. The `audioplayers` entry declares `appliesToMaxVersion: "1.0.0"` and lists itself as the replacement (line 2006), which is nonsensical. If the live pub.dev fetch ever fails, projects on `^6.5.1` would inherit 1.0-era data.

---

## Suggested Fix

**The chosen direction (per product decisions 2026-05-13):**

### 1. Split the size metric

Introduce two fields in `types.ts`:

- `codeSizeBytes` — sum of `lib/**` bytes + bytes of assets declared in the package's own `pubspec.yaml` `flutter.assets:` section + native binaries from platform sub-packages (`<name>_android`, `<name>_darwin`, `<name>_windows`, `<name>_linux`, `<name>_web` — already enumerated for `audioplayers`).
- `archiveSizeBytes` — keep as-is, raw pub.dev tarball size. Rename downstream usages to `distributionSizeBytes` / `onDiskSizeBytes` in user-facing labels.
- `folderBreakdown: { lib, example, test, tool, doc, other }` (bytes per top-level folder) — feeds the hover tooltip and the health-signal booleans below.

Computation options for `codeSizeBytes` and `folderBreakdown`, cheapest first:
- (a) Use pub.dev's per-file API (`https://pub.dev/api/packages/<name>/versions/<version>`) which lists tarball entries — sum only paths matching the inclusion rules above for `codeSizeBytes`, bucket all paths by top-level folder for `folderBreakdown`. No download required.
- (b) If pub.dev does not expose per-file sizes via API, download the tarball once, list entries, sum / bucket per the rules, cache the result keyed on `<name>@<version>`.

**Where each field is used:**

- `hover-provider.ts:267-269` — primary line shows `codeSizeBytes` via `formatSizeMB`/`formatSizeKB`. Tooltip / hover detail shows `archiveSizeBytes` plus the `folderBreakdown` percentages.
- `budget-checker.ts:59-60` — sum `codeSizeBytes` only. The per-app budget is about shipped bytes, not tarball bytes.
- `comparison-ranker.ts:40` — rank by `codeSizeBytes`.
- `calcBloatRating()` at `bloat-calculator.ts:9` — accepts `codeSizeBytes`. Re-calibrate the breakpoints; the 50 KB / 1 MB / 50 MB anchors were chosen for tarballs and will need to move for code-only sizing. Suggested starting point: 10 KB / 250 KB / 10 MB → rating 0 / 4 / 10. Verify against a corpus of known-lean and known-heavy packages before locking in.

### 2. Reward maintainer-quality folders in the health score

Each of the four folders becomes an independent positive component on the health score. Add to whatever aggregates per-package health (consolidate the scoring assembly if it's scattered):

| Field | True when | Why it's positive |
|---|---|---|
| `hasExample` | `example/` contains at least one `.dart` file | Runnable demo / onboarding |
| `hasTests` | `test/` contains at least one `_test.dart` file | Regression coverage shipped, not just stripped |
| `hasTools` | `tool/` contains at least one `.dart` or `.sh`/`.ps1` script | Maintainer automation / reproducible workflows |
| `hasDocs` | `doc/` contains at least one `.md` (beyond the auto-`api/` Dartdoc dump) | Extended documentation beyond README |

Each adds a positive component to the health score, magnitudes to be calibrated against a corpus before locking in. Surface each in the hover so developers see why the score moved:

```
audioplayers — health 7.5/10
  +example  ships runnable demo (21.6 MB)
  +tests    ships test suite
  no tool/, no doc/
```

This keeps the model legible and lets developers calibrate trust in the score. Optional richer follow-ups (not required for the first fix):
- `exampleQuality` — looks for `example/lib/main.dart`, `example/pubspec.yaml`, `example/README*`. More artifacts → larger contribution.
- `testCoverage` — bytes of `test/` relative to `lib/`. A `test/` with one stub file shouldn't get the same credit as a real suite.

### 3. Secondary data hygiene (independent, low-risk)

- Version-gate `known_issues.json` fallbacks in `resolveArchiveSize` (`scan-orchestrator.ts:219-227`). Only use `knownIssue.archiveSizeBytes` when the installed version is `≤ knownIssue.appliesToMaxVersion`. Without this, projects on 6.5.1 can inherit the 1.0-era 20.05 MB seed when the live API is unreachable.
- Audit `known_issues.json` for self-replacements (`replacement === name`). The `audioplayers` entry has it on lines 2006 and 4276. A package cannot replace itself — either the entry is mis-keyed (the bad version is `audioplayers_v0` at line 1210 and the entry on 2002 is a duplicate) or the dataset has a copy-paste defect. Same audit will likely surface others.

---

## Fixture Gap

Tests the vibrancy module needs once the new model exists:

1. **`audioplayers` shape** — tarball ~21.7 MB, `example/` 21.62 MB of demos, `test/` 20 KB, no `tool/` or `doc/`. Expected `codeSizeBytes` ≈ `lib/` (40 KB) + native binaries from the five `audioplayers_<platform>` sub-packages (~300 KB combined). Expected `folderBreakdown` matches pub cache layout. Expected health bonuses: `+hasExample`, `+hasTests`. No `+hasTools`, no `+hasDocs`.
2. **Lib-only package** (`intl`, `path`) — `codeSizeBytes` ≈ `archiveSizeBytes`. `folderBreakdown` is ~100% `lib/`. Zero maintainer-quality bonuses. Confirms parity in the common case and that absent folders don't cause negative penalties (they're just absent components, not subtractions).
3. **Declared-assets package** (`flutter_svg` or any package with `flutter.assets:` in its own pubspec) — declared assets count toward `codeSizeBytes`. Sample-only assets in `example/` do NOT count toward code size, but DO contribute `+hasExample`. Confirms the inclusion rule reads `pubspec.yaml`, not a glob.
4. **Native-heavy plugin** (`firebase_core`) — platform sub-package native binaries roll up into `codeSizeBytes`. Confirms multi-package roll-up.
5. **Full-house maintainer** — a package with all four of `example/`, `test/`, `tool/`, `doc/` populated. All four positive components apply; total health bonus is the sum. Pick a real package from a corpus walk (e.g. `drift`, `riverpod`).
6. **Stub-folder package** — a package where `example/` exists but contains only a `README.md`, or `test/` contains only a placeholder. The presence-detection rule ("at least one `.dart` file" / "at least one `_test.dart` file") should NOT trigger the bonus. Confirms we don't reward empty gestures.
7. **Stale known-issues fallback** — live fetch fails, `appliesToMaxVersion < installedVersion`. Vibrancy must skip the stale `archiveSizeBytes` and surface "size unknown" rather than the old value. Confirms the version-gate fix.
8. **Self-replacement entry** — `known_issues.json` validator rejects any entry where `name === replacement`. Confirms the data-hygiene fix and prevents regressions.

---

## Changes Made

**Section 1 — Size metric split:**
- `extension/src/vibrancy/types.ts` — added `FolderBreakdown`, `MaintainerQualityFlags`, and the `codeSizeBytes` / `folderBreakdown` / `maintainerQuality` / `maintainerQualityBonus` fields on `VibrancyResult`. `ComparisonData` gains `codeSizeBytes`.
- `extension/src/vibrancy/services/tarball-analyzer.ts` (new) — downloads the pub.dev `.tar.gz`, gunzips, walks tar headers, buckets bytes by top-level folder, parses the package's own `pubspec.yaml` for `flutter.assets:` to compute `codeSizeBytes` correctly (lib + declared assets, NOT example/test fixture media). 64 MB cap on downloads; results cached keyed on archive URL. Inline tar parser (no new dependency).
- `extension/src/vibrancy/services/pub-dev-api.ts` — exported `resolveArchiveUrl` so the analyzer can drive a download without re-fetching package metadata.
- `extension/src/vibrancy/scan-orchestrator.ts` — added `resolveTarballAnalysis`; result population now includes the four new fields; bloat rating runs on `codeSizeBytes` when available; `resolveArchiveSize` got an explicit `appliesToMaxVersion` gate so stale known-issues fallbacks can't leak to newer versions.
- `extension/src/vibrancy/scoring/bloat-calculator.ts` — recalibrated thresholds for code-only sizing: anchors at 10 KB / 250 KB / 10 MB → ratings 0 / 4 / 10. Old tarball anchors (50 KB / 1 MB / 50 MB) were too lenient at the low end and too strict at the high end once example/test/tool/doc no longer counted.
- `extension/src/vibrancy/providers/hover-provider.ts` — primary line shows `Code: …` (with `Archive: …` fallback when the analyzer was unavailable); secondary "X MB on disk" + per-folder breakdown sub-line; new **HEALTH** line with `+example` / `+tests` / `+tools` / `+docs` for the maintainer-quality components.
- `extension/src/vibrancy/scoring/budget-checker.ts` — per-app Total Size sums `codeSizeBytes ?? archiveSizeBytes`.
- `extension/src/vibrancy/scoring/comparison-ranker.ts` — "Archive Size" dimension renamed to "Code Size" and now ranks on `codeSizeBytes` (falls back to archive when unavailable).

**Section 2 — Maintainer-quality bonus:**
- `extension/src/vibrancy/scoring/vibrancy-calculator.ts` — new `calcMaintainerQualityBonus(flags, maxBonus=10)`; each present flag earns an equal share. Returns 0 for null flags (analyzer unavailable → neutral, not penalty). Added to the vibrancy-score composition in `scan-orchestrator.computeScores`.

**Section 3 — Data hygiene:**
- `extension/src/vibrancy/data/known_issues.json` — removed `replacement` field from 30 entries where `replacement === name` (audioplayers, file_picker, flutter_local_notifications × 2, flutter_typeahead, flutter_slidable, simple_animations, flutter_modular, syncfusion_flutter_calendar, badges, curved_navigation_bar, convex_bottom_bar, responsive_builder, flutter_screenutil, flutter_mobx, stacked, flutter_hooks, sembast, flutter_cache_manager, chopper, retrofit, agora_rtc_engine, youtube_player_iframe, camera, flutter_map, location, timeago, supercharged, fluttertoast, timezone). The `appliesToMaxVersion` already scopes the issue to old versions, so the upgrade signal is implicit — the self-replacement was producing misleading "Replace with X" UX where X = X.
- `scan-orchestrator.resolveArchiveSize` — belt-and-braces version gate: skip a known-issue's `archiveSizeBytes` fallback when the installed version is past `appliesToMaxVersion`.

**Test fixture maintenance:**
- 8 test files (`hover-provider.test.ts`, `tree-items.test.ts`, `vibrancy-history.test.ts`, `detail-view-html.test.ts`, `package-detail-html.test.ts`, `report-html.test.ts`, `report-webview.test.ts`, `comparison-html.test.ts`) and `test-helpers.ts` updated to include the new required fields on `VibrancyResult` / `ComparisonData` fixtures.
- `extension-activation.ts` — comparison-by-search lookup path declares `codeSizeBytes: null` (light-weight path; full analyzer runs only on scan results).

---

## Tests Added

- `extension/src/test/vibrancy/services/tarball-analyzer.test.ts` (new) — 9 tests covering the synthetic-tar pure-function path: lib/ sum, declared-flutter-assets inclusion, trailing-slash directory globs, hasExample/hasTests/hasTools/hasDocs flag rules (including stub-folder rejection), and pub.dev `<name>-<version>/` wrapper stripping.
- `extension/src/test/vibrancy/scoring/vibrancy-calculator.test.ts` — added `calcMaintainerQualityBonus` describe block (6 tests).
- `extension/src/test/vibrancy/scoring/bloat-calculator.test.ts` — rewrote `calcBloatRating` tests for the code-size scale; added an audioplayers-shape regression test pinning that 40 KB of lib stays ≤2/10 bloat.
- `extension/src/test/vibrancy/scoring/known-issues.test.ts` — added a self-replacement invariant test (`should never have an entry that replaces itself`) so a future commit can't silently reintroduce one.
- `extension/package.json` — new tarball-analyzer test added to the mocha runlist.

Test run: 1089 passing, 0 failing.

---

## Follow-up — Dashboard surfaces (2026-05-13, second pass)

**What the first pass missed:** the original "Changes Made" listed only the internal scoring sites and the editor hover. Every Package Dashboard webview surface still rendered `archiveSizeBytes`, so users saw the bloated tarball number on the Dashboard table (audioplayers as 20,535 KB), the package detail panel, the package comparison panel, the sidebar detail view, and the Size Distribution chart. The Health Score panel also never gained the four `+example` / `+tests` / `+tools` / `+docs` rows the hover added — the bonus fed the overall score but was invisible per row.

**Dashboard surfaces wired through to `codeSizeBytes ?? archiveSizeBytes`:**

- `extension/src/vibrancy/views/report-html.ts` — `buildSizeCell` now prefers `codeSizeBytes`, the tooltip discloses which dimension is showing ("Code size" vs "Archive size") and adds an "On disk" line when both are known and differ. `buildReportSummary` Total Size summary card sums code size. The row's `data-size` attribute (used for client-side sorting/filtering) reads code size. The JSON export gains a new `codeSize` field alongside the retained `archiveSize`. `buildDetailScoreSection` (Health Score panel) now renders `+example` / `+tests` / `+tools` / `+docs` rows when the respective `maintainerQuality` flags are true; absent flags don't render (non-contribution, not penalty).
- `extension/src/vibrancy/views/package-detail-html.ts` — VERSION section's size row labels itself "Code Size" (or "Archive Size" fallback) and adds an "On Disk" secondary row when the two differ materially. Transitive-footprint own-size uses code size.
- `extension/src/vibrancy/views/comparison-html.ts` — "Archive Size" row renamed to "Code Size", extractor reads `codeSizeBytes ?? archiveSizeBytes`. Matches the comparison-ranker which already ranked by code size.
- `extension/src/vibrancy/views/detail-view-html.ts` — sidebar VERSION section size row labels itself "Code Size" or "Archive" and reads the same fallback.
- `extension/src/vibrancy/views/chart-html.ts` — Size Distribution chart's `prepareChartData` filter and segment sizing both read code size.

**Tests updated:**
- `extension/src/test/vibrancy/views/report-html.test.ts` — the dash-tooltip test now asserts the generalized "Size not available from pub.dev" copy (was "Archive size not available").
- `extension/src/test/vibrancy/views/comparison-html.test.ts` — the "archive size formatted" test renamed to "code size formatted" and asserts "Code Size" instead of "Archive Size".

Test run after follow-up: 1092 passing, 0 failing.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: (current `main`, 2026-05-13)
- Dart SDK version: N/A (extension-side TypeScript)
- custom_lint version: N/A
- Triggering project/file: `d:\src\contacts` — `pubspec.yaml:72` (`audioplayers: ^6.5.1`)
- Local pub cache evidence: `D:\tools\Pub\Cache\hosted\pub.dev\audioplayers-6.6.0` — `lib/` 40 KB, `example/` 21.62 MB, `test/` 20 KB, total 21.72 MB on disk
- Cross-check needed before close: `file_picker` (`known_issues.json:2031`, 19.32 MB) — almost certainly same shape, verify
