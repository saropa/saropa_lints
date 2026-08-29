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

`ScanRunner._prepare()` unconditionally calls `RuntimeTierCap.filterRuleSet()`, which
silently trims the rule set to whatever `runtime_tier:` / `saropa_tier:` / `SAROPA_TIER`
the project specifies. This defeats the "always all-rules" guarantee.

**Solution:** add a `bypassTierCap` flag to `ScanRunner` (default `false`). When `true`,
`_prepare()` skips the `RuntimeTierCap.filterRuleSet()` call. `bin/audit.dart` passes
`bypassTierCap: true`. Existing callers are unaffected (default is `false`).

The audit JSON output includes a `tierCapBypassed: true` field so consumers can verify
the audit ran uncapped.

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

**Audit Report webview** — new `AuditReportPanel` singleton. Reuse existing shared
infrastructure from the Vibrancy report (`report-html-shared.ts`, shared styles, gauge
component) rather than building a parallel report system from scratch. The audit-specific
parts (diagnostic table with tier/category facets, search) are new; the summary header,
gauge, and base table/sort/group patterns are shared.

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
4. `bin/audit.dart` — arg parsing, `getAllDefinedRules()`, `ScanRunner(bypassTierCap: true)`,
   JSON output. Reuse `writeRuleTimingReport` for `--profile`.
5. Register in `bin/saropa_lints.dart` dispatcher.
6. Test: run `dart run saropa_lints audit example/` and verify JSON output includes all tiers.

### Phase 2 — Extension UI (TypeScript)

1. `audit-command.ts` — spawn CLI, stream progress, collect JSON.
   Handle multi-root workspaces via `showWorkspaceFolderPick()`.
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

4. **Reuse `report-html-shared.ts`** for the webview — shared gauge, styles, table patterns.
   Only audit-specific parts (diagnostic table, tier/category facets, search) are new.

5. **Category from rule factory grouping** for v1 — static map derived from the factory
   list's source file grouping. `category` getter on `SaropaLintRule` deferred to v2.

6. **JSON-only for CLI v1** — no HTML report from CLI. The webview IS the visual report.

7. **Multi-root workspaces** — `showWorkspaceFolderPick()` when multiple roots present.

8. **Profile flag** reuses existing `writeRuleTimingReport`, no reimplementation.
