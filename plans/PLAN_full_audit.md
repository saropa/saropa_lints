# Full Audit — run every rule against a codebase, render a filterable report

**Created:** 2026-08-29
**Status:** Draft (revised after review)

---

## Problem

Users want to run **all** Saropa lint rules against a codebase as a one-off quality audit,
without changing their project tier configuration. Today `scan --tier pedantic` comes close but:

- No single CLI command includes stylistic rules (pedantic + stylistic = everything).
- `RuntimeTierCap` silently caps rules to the project's configured tier even when an explicit
  rule set is passed — an audit must bypass this.
- No visible UI entry point in the extension — the command palette is buried.
- The report webview lacks search, filtering by tier/category/severity, and grouping.

---

## Design

### Naming

`audit` — distinct from `scan` (which is config-aware and incremental). An audit is always
all-rules, always full-resolution, always produces a report.

### CLI: `dart run saropa_lints audit <dir>`

Subcommand of the `saropa_lints` dispatcher (following project convention — most `bin/*.dart`
entry points are invoked via the dispatcher, not registered as separate `pubspec.yaml`
executables). Implemented in `bin/audit.dart`.

Thin orchestrator following the `accuracy_report.dart` pattern:

1. Calls `getAllDefinedRules()` from `tiers.dart` (pedantic ∪ stylistic = everything).
2. Constructs a `ScanRunner` with `enabledRuleNames: allRules`, `resolve: true`,
   and `bypassTierCap: true` (see RuntimeTierCap section below).
3. Runs `runner.runResolved()`.
4. Outputs JSON to stdout (same schema as `scan --format json`, enriched with `tier` +
   `category` per diagnostic).

No separate `audit_runner.dart` — the call site is ~15 lines in `bin/audit.dart`, directly
using `ScanRunner` + `enabledRuleNames` exactly as `accuracy_report.dart` already does.

**Flags:**

| Flag | Default | Purpose |
|------|---------|---------|
| `--format` | `json` | `json` only for v1 |
| `--output` | stdout | Write to a specific path |
| `--exclude-globs` | none | Skip directories (e.g. `build/`, `.dart_tool/`) |
| `--include-globs` | none | Limit to specific paths |
| `--min-severity` | none | Post-filter: hide diagnostics below this severity |
| `--min-impact` | none | Post-filter: hide diagnostics below this impact |
| `--profile` | false | Emit per-rule timing (reuses `writeRuleTimingReport`) |
| `--since` | none | Git ref — only audit files changed since this ref |

No `--tier` flag — audit always means everything. No `--fail-on` — audit is informational,
not a gate (use `quality_gate` for that).

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | Audit completed, diagnostics written |
| 1 | Audit completed but encountered errors during analysis |
| 2 | Invalid arguments, target is not a Dart project, or `pub get` not run |

When the target has zero `.dart` files or is not a Dart project, exit 2 with a clear
message — audit does not prompt for `init` (unlike `scan`), since it is config-independent.
The target project must have had `pub get` run (resolved analysis requires the package
graph); audit checks for `.dart_tool/package_config.json` and exits 2 with guidance if
missing.

### RuntimeTierCap bypass (CRITICAL)

`RuntimeTierCap` is enforced at two sites:

1. **Scan path** — `ScanRunner._prepare()` (`scan_runner.dart:296`) calls
   `RuntimeTierCap.filterRuleSet(resolved)`, silently trimming the rule set to whatever
   `runtime_tier:` / `saropa_tier:` / `SAROPA_TIER` the project specifies.
2. **Native plugin path** — `SaropaContext` (`saropa_context.dart:287`) calls
   `RuntimeTierCap.ruleAllowedByCap(rule.code.lowerCaseName)` per-rule during analysis.

Audit uses the scan path only, so only site 1 needs bypassing.

**Solution:** add a `bypassTierCap` flag to `ScanRunner` (default `false`). When `true`,
`_prepare()` skips the `RuntimeTierCap.filterRuleSet()` call. `bin/audit.dart` passes
`bypassTierCap: true`. Existing callers are unaffected (default is `false`).

The audit JSON output includes a `tierCapBypassed: true` field so consumers can verify
the audit ran uncapped.

### Category mapping

The `_allRuleFactories` list in `lib/saropa_lints.dart` groups factories by section
comment (`// Core rules`, `// Security rules`, etc.). Category is derived by:

1. Instantiating each rule from the factory list (already done by `allSaropaRules` getter).
2. Using the rule's `runtimeType` to find its source file via a static
   `Map<Type, String>` built from the import structure in `all_rules.dart`.
3. Stripping `_rules.dart` from the filename → category slug.

Alternatively (simpler for v1): a hand-maintained `Map<String, String>` in
`rule_tier_index.dart` built from the section comments in the factory list. A unit test
validates that every rule in `_allRuleFactories` appears in the map — same pattern as
the existing tier-registration tests that catch missing entries.

### Audit diff mode — changed-files-only audit

Runs a full audit but filters output to only diagnostics in files changed since a git
ref. Lets teams use audit as a PR review tool without drowning in pre-existing findings.

**CLI:** `dart run saropa_lints audit <dir> --since <ref>` — `<ref>` is any git ref
(branch name, SHA, `HEAD~5`). The CLI calls
`git diff --name-only --diff-filter=ACMR -M <ref>..HEAD -- '*.dart'`
to get the changed file list (Added, Copied, Modified, Renamed — `-M` ensures renamed
files show their new path), then passes it as `--include-globs` to the scan engine.

**Extension UI:** The sidebar audit button shows a quick-pick prompt BEFORE running:

| Option | Behavior |
|--------|----------|
| **Full project audit** | Runs all files (default) |
| **Changed files only (vs main)** | Runs `--since main` |
| **Changed files only (pick branch...)** | Shows branch picker, then runs `--since <selected>` |

This ensures `--since` is never buried as a CLI-only param — the UI surfaces it as an
explicit choice before every audit run. The Explorer context-menu "Audit Folder..." entry
always runs full (no diff mode — it's already scoped to a folder).

### Extension UI

**Sidebar button** — a `$(shield)` icon button in the `saropaLints.editorDashboards` view
title bar, registered as command `saropaLints.fullAudit`.

**Explorer context menu** — "Saropa: Audit Folder..." entry in `explorer/context` for
targeted audits on a specific directory.

**Behavior on click:**

1. Use workspace root as scope. For multi-root workspaces, prompt the user to pick a
   workspace folder (via `vscode.window.showWorkspaceFolderPick()`). The Explorer context
   menu variant uses the right-clicked folder directly.
2. Show progress notification with cancel button.
3. Spawn `dart run saropa_lints audit <dir> --format json` as a child process.
4. Stream progress from stderr (scan already emits file-count progress).
5. On completion, open the Audit Report webview with the JSON payload.

**Audit Report webview** — new `AuditReportPanel` singleton. The Vibrancy report's
`report-html-shared.ts` is mostly vibrancy-locked (`ReportOptions` is typed to
`VibrancyResult[]`, gauge/grid CSS is vibrancy-specific). Reusable pieces: the two date
utilities (`daysSinceIsoDate`, `formatAgeFromDays`) and the CSS token strategy
(`var(--vscode-*)` palette approach, zebra rows, sticky headers). Everything else — options
interface, data table builder, filter chip bar, stylesheet — is audit-specific and new.

**Report features:**

| Feature | Implementation |
|---------|---------------|
| **Search** | Text input filters diagnostics by file path, rule name, or message substring |
| **Tier filter** | Chip bar: Essential / Recommended / Professional / Comprehensive / Pedantic / Stylistic — multi-select, all-on by default |
| **Severity filter** | Chip bar: Error / Warning / Info |
| **Impact filter** | Chip bar: Critical / High / Medium / Low / Minimal |
| **Category grouping** | Collapsible sections by rule category (security, accessibility, performance, etc.) |
| **Sort** | By severity (default), by file, by rule name, by tier |
| **File grouping toggle** | Group diagnostics by file or show flat list |
| **Summary header** | Total count, counts per tier, counts per severity — reuse gauge from `report-html-shared.ts` |
| **Export** | "Copy JSON" button (copies the raw JSON to clipboard) |

All strings externalized via `l10n()` in `en.json` under an `audit` namespace.

### JSON enrichment: tier + category fields

`scan_json.dart`'s `scanDiagnosticsToJson()` gains two new optional fields per diagnostic:

```json
{
  "ruleName": "no_empty_block",
  "tier": "essential",
  "category": "unnecessary_code",
  ...
}
```

**Tier lookup:** `rule_tier_index.dart` — a static `Map<String, String>` built by iterating
the tier sets in `tiers.dart` at startup. Reverse map: `ruleName → tier name`. Rules in
multiple tiers map to their lowest (most inclusive) tier.

**Category lookup (v1):** a static `Map<String, String>` in `rule_tier_index.dart`,
maintained alongside the tier reverse map. Built from the rule registration site — each rule
class is declared in a `*_rules.dart` file, so the category is the file stem minus `_rules`
(e.g., `security_rules.dart` → `security`). This map is generated from the rule factory
list in `lib/saropa_lints.dart`, which already groups factories by source file. No runtime
reflection; the mapping is a build-time constant.

**v2 (future):** add a `category` getter to `SaropaLintRule` so each rule self-declares.
Deferred because it touches every rule class.

---

## File changes

### New files

| File | Purpose |
|------|---------|
| `bin/audit.dart` | CLI entry point (~30 lines, follows `accuracy_report.dart` pattern) |
| `lib/src/scan/rule_tier_index.dart` | `Map<String, String>` reverse lookups: rule → tier, rule → category |
| `extension/src/audit/audit-command.ts` | VS Code command registration + child process spawn |
| `extension/src/audit/audit-report-panel.ts` | Webview panel singleton (reuses `report-html-shared.ts`) |
| `extension/src/audit/audit-report-html.ts` | HTML generation: diagnostic table, filter chips, search |
| `extension/src/audit/audit-report-script.ts` | Client-side JS: search, filter, sort, group |
| `lib/src/scan/git_changed_files.dart` | `git diff --name-only --diff-filter=ACMR -M` wrapper for `--since` |
| `lib/src/scan/audit_baseline.dart` | Baseline save/load/diff logic for `--baseline` / `--save-baseline` |
| `extension/src/audit/audit-report-styles.ts` | Audit-specific CSS (own stylesheet, not shared with vibrancy) |

### Modified files

| File | Change |
|------|--------|
| `lib/src/scan/scan_runner.dart` | Add `bypassTierCap` flag, skip `RuntimeTierCap.filterRuleSet()` when true |
| `lib/src/scan/scan_json.dart` | Add optional `tier` and `category` fields to diagnostic JSON |
| `bin/saropa_lints.dart` | Register `audit` subcommand in dispatcher |
| `extension/package.json` | Add `saropaLints.fullAudit` command, `editorDashboards` title bar icon, `explorer/context` menu entry |
| `extension/src/vibrancy/extension-activation.ts` | Register audit command in `registerCommands()` |
| `extension/src/i18n/locales/en.json` | Add `audit.*` namespace strings |
| `CHANGELOG.md` | Entry under Unreleased |
| `ROADMAP.md` | Audit feature status |

### NOT changed

| File | Why |
|------|-----|
| `analysis_options.yaml` | No new example dirs |
| `pubspec.yaml` version | Never bumped manually |
| `pubspec.yaml` executables | Audit is a dispatcher subcommand, not a separate executable |
| Any tier set or rule registration | Audit reads tiers, doesn't modify them |
| Project config files | Audit is config-independent by design |
| `lib/src/config/runtime_tier_cap.dart` | No changes — `ScanRunner` gates the call, not the cap itself |

---

## Implementation order

### Phase 1 — CLI (Dart)

1. Add `bypassTierCap` flag to `ScanRunner`, gate `RuntimeTierCap.filterRuleSet()` call.
2. `rule_tier_index.dart` — reverse maps: rule → tier, rule → category.
3. Enrich `scan_json.dart` with optional `tier` + `category` fields per diagnostic.
4. `git_changed_files.dart` — `--since <ref>` wrapper: calls `git diff --name-only`,
   returns `.dart` file list for `ScanRunner`'s `includeGlobs`.
5. `bin/audit.dart` — arg parsing, `getAllDefinedRules()`, `ScanRunner(bypassTierCap: true)`,
   `--since` integration, JSON output. Reuse `writeRuleTimingReport` for `--profile`.
6. Register in `bin/saropa_lints.dart` dispatcher.
7. Unit test for `rule_tier_index.dart` — validates every rule in `_allRuleFactories` has
   a tier and category entry (catches registration drift, same pattern as tier tests).
8. Test: run `dart run saropa_lints audit example/` and verify JSON output includes all tiers.

### Phase 2 — Extension UI (TypeScript)

1. `audit-command.ts` — spawn CLI, stream progress, collect JSON.
   Handle multi-root workspaces via `showWorkspaceFolderPick()`.
   Show quick-pick before running: "Full project audit" / "Changed files only (vs main)"
   / "Changed files only (pick branch...)". Pass `--since` to CLI accordingly.
2. `audit-report-panel.ts` — singleton webview, receives JSON via `postMessage`.
   Reuse `report-html-shared.ts` for gauge, base styles, table primitives.
3. `audit-report-html.ts` + script — summary header, diagnostic table with filter chips.
4. Register command + sidebar button + Explorer context menu in `package.json` and
   `extension-activation.ts`.
5. Externalize all strings to `en.json` under `audit.*`.
6. Run locale regeneration (`generate_locales.py`) — coverage gate blocks release on stale
   translations.

### Phase 3 — Polish

1. Search box with debounced filtering.
2. Keyboard navigation in the report.
3. "Copy JSON" export.
4. Empty-state (no diagnostics found) and error-state (audit failed / canceled) UI.

---

## Memory / RAM considerations

Two memory costs to consider:

1. **Resolved AST + element model (dominant cost).** `runResolved()` builds a full
   `AnalysisContextCollection` — the entire package graph's resolved ASTs and element models
   stay live for the duration of the run. For a 1000-file project this can be 500MB–1GB+
   depending on dependency graph size. This is inherent to resolved analysis and is the same
   cost `dart analyze` pays. The `--exclude-globs` / `--include-globs` flags reduce scope.

2. **Diagnostic accumulation (secondary).** `List<ScanDiagnostic>` for 2300 rules × 1000
   files could reach ~100k entries × ~500 bytes = ~50MB. Acceptable.

**Mitigations:**

- `--exclude-globs` and `--include-globs` keep scope manageable for monorepos.
- The extension UI shows a clear warning about expected duration/memory before starting.
- Future (not v1): streaming NDJSON output to avoid buffering all diagnostics before writing,
  and per-directory chunked analysis to cap peak memory.

---

## Resolved decisions (from review)

1. **No `audit_runner.dart`** — `bin/audit.dart` is ~30 lines calling `ScanRunner` directly,
   following the `accuracy_report.dart` precedent.

2. **`RuntimeTierCap` bypassed** via a new `bypassTierCap` flag on `ScanRunner`, not by
   modifying `RuntimeTierCap` itself. Audit JSON includes `tierCapBypassed: true`.

3. **Dispatcher subcommand** (`dart run saropa_lints audit`), not a separate `pubspec.yaml`
   executable — matches project convention.

4. **Minimal reuse from `report-html-shared.ts`** — only date utilities and CSS token
   strategy are reusable. The options interface, table builder, filter chips, and
   stylesheet are audit-specific (vibrancy report is typed to `VibrancyResult[]`).

5. **Category from rule factory grouping** for v1 — static map derived from the factory
   list's source file grouping. `category` getter on `SaropaLintRule` deferred to v2.

6. **JSON-only for CLI v1** — no HTML report from CLI. The webview IS the visual report.

7. **Multi-root workspaces** — `showWorkspaceFolderPick()` when multiple roots present.

8. **Profile flag** reuses existing `writeRuleTimingReport`, no reimplementation.

9. **Category map drift** — unit test validates every factory-registered rule has a
   category entry. Same pattern as the existing tier-registration completeness test.

10. **Diff mode UI exposure** — `--since` is surfaced as a quick-pick prompt in the
    extension UI before every audit run, not buried as a CLI-only flag. Three options:
    Full project / Changed vs main / Pick branch.

---

## Audit baseline diffing

Saves an audit snapshot and on subsequent runs shows only new/resolved findings compared
to the baseline. Turns audit into a ratchet: teams fix new findings without being
overwhelmed by the existing backlog.

### All outputs are datetime-stamped

Every audit output includes a UTC ISO-8601 timestamp at the top level:

```json
{
  "timestamp": "2026-08-29T14:32:00Z",
  "version": 1,
  "tierCapBypassed": true,
  "diagnostics": [...],
  "summary": {...},
  "baseline": {
    "comparedTo": "2026-08-28T10:15:00Z",
    "new": 12,
    "resolved": 5,
    "unchanged": 483
  }
}
```

The `baseline` key is present only when `--baseline` is used. The webview report header
shows the timestamp and, when baseline-diffing, a "vs baseline from <date>" subtitle.

### CLI

| Flag | Purpose |
|------|---------|
| `--save-baseline` | Save this audit's JSON as the project baseline at `.saropa/audit_baseline.json` |
| `--baseline` | Compare against the saved baseline; output includes `baseline.new` / `baseline.resolved` / `baseline.unchanged` counts; diagnostics gain a `baselineStatus` field (`new` / `unchanged` / `resolved`) |
| `--baseline-path <path>` | Use a specific baseline file instead of the default location |

`--save-baseline` and `--baseline` can be combined: compare against existing baseline,
then overwrite it with the current results.

### Extension UI

The sidebar audit quick-pick gains a fourth option when a baseline exists:

| Option | Behavior |
|--------|----------|
| **Full project audit** | All files, no baseline |
| **Changed files only (vs main)** | `--since main` |
| **Changed files only (pick branch...)** | Branch picker + `--since` |
| **Compare to baseline** | `--baseline` — shows new/resolved badges in the report |

A "Save as baseline" button appears in the audit report webview header after any audit
completes. Clicking it calls the CLI with `--save-baseline` on the current results.

The report webview shows three filter chips when baseline data is present:
**New** (red badge) / **Unchanged** (neutral) / **Resolved** (green badge, struck through).

### Baseline file format

`.saropa/audit_baseline.json` — same schema as audit output JSON, datetime-stamped.
The file is project-local (lives in the project root, gitignored by default). Teams
that want shared baselines can commit it.

---

## Verified hardening (reflection items)

### 1. RuntimeTierCap — sole enforcement point confirmed

Verified: `RuntimeTierCap.filterRuleSet()` at `scan_runner.dart:296` is the only
enforcement point in the scan CLI path. `reloadRuntimeTierCapFromProject()` (line 284)
sets the static `_cap` field but does not filter or gate rules — that happens only when
`filterRuleSet` is subsequently called. The `bypassTierCap` flag on `ScanRunner` is
sufficient.

### 2. report-html-shared.ts — mostly vibrancy-locked

Verified: `ReportOptions` is typed to `VibrancyResult[]`. Gauge, grid CSS, and data
helpers (`resolveRepoUrl`, `buildDormancyStatus`, `computeActivitySignal`) are all
vibrancy-specific. Only `daysSinceIsoDate()`, `formatAgeFromDays()`, and the CSS token
strategy (`var(--vscode-*)` palette) are reusable. The audit report needs its own options
interface, table builder, filter chip bar, and stylesheet.

### 3. Git diff renamed files

Verified: `git diff --name-only` without `-M` shows renamed files as delete + add.
The `--since` implementation must use:
`git diff --name-only --diff-filter=ACMR -M <ref>..HEAD -- '*.dart'`
(`-M` enables rename detection; `ACMR` = Added, Copied, Modified, Renamed.)

### 4. Webview row capacity (100k+ diagnostics)

Unverified empirically. Mitigation: the report webview should paginate or virtualize
rows above 5,000. v1 can use simple DOM pagination (show 500 rows, "Load more" button)
rather than full virtual scroll. The filter chips reduce visible rows significantly in
practice.

### 5. postMessage size limit

VS Code's `webview.postMessage()` has no documented hard limit but serializes through
JSON. For 100k diagnostics at ~500 bytes each = ~50MB JSON string. Mitigation: if the
payload exceeds 10MB, write it to a temp file and pass the file URI to the webview via
`postMessage({type: 'auditFile', uri: ...})` instead of inlining the data.

### 6. Multi-root workspace UX

`showWorkspaceFolderPick()` handles any number of folders. For single-root workspaces
it can be skipped entirely (use the one root). For multi-root, the picker shows folder
names — acceptable at any scale.

---

## Finish Report (2026-08-29)

**What was done:** Plan drafted for a "Full Audit" feature — CLI subcommand + visible
extension sidebar/context-menu entry + filterable webview report. Underwent automated
code review that identified two critical issues:

1. `RuntimeTierCap` silently caps the rule set even when an explicit `enabledRuleNames`
   is passed — the plan now specifies a `bypassTierCap` flag on `ScanRunner`.
2. A proposed `audit_runner.dart` duplicated existing `accuracy_report.dart` patterns —
   removed in favor of a thin ~30-line `bin/audit.dart` call site.

Additional review-driven fixes: dispatcher subcommand (not separate executable), reuse
of `report-html-shared.ts`, multi-root workspace handling, resolved-AST memory cost
documentation, exit-code contract, locale regeneration step.

Additional hardening (2026-08-29, reflection gate):

3. Verified `RuntimeTierCap` enforcement sites — two exist: `scan_runner.dart:296`
   (`filterRuleSet`, scan path) and `saropa_context.dart:287` (`ruleAllowedByCap`,
   native plugin path). Audit uses scan path only; plan now documents both sites.
4. Added category-map drift guard: unit test validates every rule in `_allRuleFactories`
   has a tier and category entry, same pattern as existing tier-registration tests.
5. Added "Audit diff mode" (`--since <ref>`) — filters to files changed since a git ref.
   CLI flag + UI quick-pick before every audit run (Full / Changed vs main / Pick branch).
   Ensures the `--since` option is never buried as a CLI-only param.

Additional hardening (2026-08-29, reflection gate, round 2):

6. Verified `RuntimeTierCap.filterRuleSet()` is the sole scan-path enforcement point
   (no indirect gating via `reloadRuntimeTierCapFromProject` side effects).
7. Verified `report-html-shared.ts` is mostly vibrancy-locked — audit report needs its
   own options interface, table builder, filter chips, stylesheet. Only date utilities
   and CSS token strategy reusable.
8. Fixed `--since` git command to use `--diff-filter=ACMR -M` for renamed file handling.
9. Added webview pagination mitigation for 100k+ rows (paginate above 5k, not full DOM).
10. Added `postMessage` size mitigation (temp file for payloads >10MB).
11. Added audit baseline diffing feature — `--save-baseline`, `--baseline`, datetime
    stamps on all outputs, UI quick-pick option + "Save as baseline" button in report.

**Status:** Plan complete and committed. No implementation started. Three phases defined:
CLI (Dart), Extension UI (TypeScript), Polish.

## Finish Report (2026-08-29, code review of hardening commits)

Code review of the two hardening commits (910ed16e, 0681adb9) found one defect: the
`--since` flag row (added during round 1 hardening) was inserted as a standalone table
row separated from the Flags table by a blank line and two lines of prose, so GitHub-
flavored Markdown would not render it as part of the table — it would appear as a stray
line of pipe-delimited text. Fixed by moving the row into the Flags table directly above
the `--tier`/`--fail-on` prose note. No other defects found; plan remains design-only,
no implementation started.

Reflection-gate hardening: re-verified all four line-number citations against current
source (`scan_runner.dart:284`, `scan_runner.dart:296`, `saropa_context.dart:287`,
`saropa_lints.dart:231`, `tiers.dart:3323`) — all unchanged since the plan was drafted,
no drift to correct. VS Code's built-in Markdown preview was not separately checked
against the GFM renderer used above; both use CommonMark-family table parsing so the
same blank-line-breaks-a-table rule applies, but this was not independently confirmed.

### SARIF output (brainstorm only — not scoped for v1)

Deferred, out of scope for the phases above. `--format sarif` would emit SARIF 2.1.0
instead of the native JSON schema, letting `audit` results feed GitHub code-scanning
annotations directly on a PR diff (particularly useful combined with `--since`). Would
require a `sarif_writer.dart` mapping diagnostic severity/impact to SARIF `level` and
`rank`, plus a `physicalLocation` per diagnostic. Not designed further here — raised as
a future-work candidate only.
