# Plan: Scan Public API, File-List Support, and Tier Override

**Status:** Implemented (see [plan_scan_public_api_file_list_tier_history.md](plan_scan_public_api_file_list_tier_history.md))  
**Last updated:** 2026-03-19  
**Consumer context:** [saropa_drift_advisor plans/saropa_lints_integration.md](https://github.com/saropa/saropa_drift_advisor/blob/main/plans/saropa_lints_integration.md) (optional tighter integration)

---

## Summary

Extend the **scan** command and its backing implementation so that:

1. **Public API** — The scan implementation is exported from `package:saropa_lints` so that other packages (e.g. saropa_drift_advisor) or scripts can run scans programmatically without shelling out to the CLI.
2. **File-list support** — Scan can run against an explicit list of Dart files (e.g. from a prior scan report or a "changed files" list) instead of only discovering all `.dart` files under a directory.
3. **Tier override** — Scan can use a tier name (e.g. `essential`, `recommended`, `pedantic`) to determine the rule set for that run, without changing the project's `analysis_options.yaml`.

Optionally:

4. **Stable machine-readable output** — Add a `--format json` (or similar) so consumers can parse results without screen-scraping the human-readable report.

All changes remain backward-compatible: existing `dart run saropa_lints scan [path]` behavior is unchanged when new options are not used.

---

## 1. Public Scan API

### 1.1 Current state

- `ScanRunner`, `ScanConfig`, `loadScanConfig`, and `ScanDiagnostic` live under `lib/src/scan/` and are **not** exported from `package:saropa_lints`. Only `bin/scan.dart` uses them.
- Consumers that want to run a scan programmatically must shell out to `dart run saropa_lints scan .` and parse stdout/stderr or the report file.

### 1.2 Goal

Expose a minimal, stable API so that code can:

- Resolve the project root and load rule configuration (or use a tier).
- Run a scan over a directory or an explicit list of files.
- Receive a list of diagnostics (and optionally write a report) without invoking the CLI.

### 1.3 Design

**Export surface**

- **Option A (recommended):** Add a single export file, e.g. `lib/scan.dart`, that exports:
  - `ScanRunner`
  - `ScanConfig`
  - `ScanDiagnostic`
  - `loadScanConfig` (from `scan_config.dart`)
- **Option B:** Export the same symbols from the main `lib/saropa_lints.dart` (increases main lib surface; some consumers may prefer a smaller import like `package:saropa_lints/scan.dart`).

**API stability**

- Document that `ScanRunner`, `ScanConfig`, `ScanDiagnostic`, and `loadScanConfig` are part of the public API and will follow semver. Internal helpers (e.g. `ScanRuleContext`, `ScanWalker`, `CapturingRuleVisitorRegistry`) remain in `lib/src/` and are not exported.

**Print behavior**

- Today `ScanRunner.run()` calls `print()` for progress and error messages. For programmatic use, either:
  - Add an optional `io: void Function(String)?` (or `Sink<String>`) so callers can suppress or redirect output, or
  - Document that programmatic callers should expect stdout/stderr to be written and, if needed, run the runner in an isolate or capture stdout.  
- Recommendation: add an optional **callback** or **sink** for messages (default: print to stdout/stderr) so that scripts can run quietly or log to a file.

### 1.4 Acceptance criteria

- [x] A new export (e.g. `lib/scan.dart`) exposes `ScanRunner`, `ScanConfig`, `ScanDiagnostic`, and `loadScanConfig`.
- [x] The export is documented in the package README or API docs (e.g. "Programmatic scan" section).
- [x] `bin/scan.dart` continues to use the same types/functions (no behavior change when invoked from CLI).
- [x] (Optional) `ScanRunner` accepts an optional way to redirect or suppress progress/error output (e.g. `messageSink` or `quiet: bool`).

---

## 2. File-List Support

### 2.1 Current state

- `ScanRunner` takes a single `targetPath` (directory). It uses `_findDartFiles(targetPath)` to discover all `.dart` files under that directory, with standard exclusions (`.dart_tool/`, `build/`, `bin/`, `example`, `.g.dart`, etc.).
- There is no way to run the scan on a fixed list of files (e.g. files named in a previous scan report, or a git diff list).

### 2.2 Goal

Allow scan to run on an explicit list of Dart file paths. Config (enabled rules, baseline, etc.) continues to be resolved from the project root; only the set of files to analyze changes.

### 2.3 Design

**ScanRunner**

- Add an optional parameter, e.g. `dartFiles: List<String>?`. Semantics:
  - If `dartFiles` is `null` or empty and no other file-list source is provided: keep current behavior — use `_findDartFiles(targetPath)`.
  - If `dartFiles` is non-null and non-empty: use this list as the set of files to scan. Do **not** call `_findDartFiles`.
- Path handling:
  - Each entry in `dartFiles` may be absolute or relative. If relative, resolve against `targetPath` (project root) so that the same root is used for config and for path consistency in diagnostics.
  - Filter to paths that end in `.dart` and (optionally) apply the same exclusion rules as `_findDartFiles` (e.g. skip `.g.dart` if desired), or document that the caller is responsible for passing only the files they want.
- Recommendation: **Do** apply the same exclusions (e.g. `.g.dart`, `build/`, etc.) to the provided list so that accidentally passing generated files doesn't change behavior unexpectedly. Alternatively, add a parameter `applyExclusions: bool` (default true) so advanced callers can disable it.

**CLI**

- Add optional arguments to `bin/scan.dart`:
  - `--files <path1> [path2 ...]` — pass one or more Dart file paths. Remaining positional args after `path` could be interpreted as files if a sentinel like `--` is used, or use `--files` explicitly.
  - `--files-from-stdin` — read one path per line from stdin. Project root still comes from the single positional `[path]` (default `.`).
- Examples:
  - `dart run saropa_lints scan . --files lib/a.dart lib/b.dart`
  - `echo "lib/foo.dart" | dart run saropa_lints scan . --files-from-stdin`
  - From a report: extract paths from a previous `..._scan_report.log` and pass them to `--files` or stdin.

**Backward compatibility**

- If neither `--files` nor `--files-from-stdin` is present, behavior is unchanged: scan the directory.

### 2.4 Acceptance criteria

- [x] `ScanRunner(targetPath, dartFiles: [...])` runs only on the given files; config is still loaded from `targetPath`.
- [x] Relative paths in `dartFiles` are resolved against `targetPath`.
- [x] CLI supports `--files file1.dart file2.dart` (and optionally `--files-from-stdin`).
- [x] When `--files` or `--files-from-stdin` is used, only those files are scanned; when omitted, behavior matches current directory discovery.
- [x] Documentation (README and/or help text) describes how to run scan on specific files (e.g. from a report or from git).

---

## 3. Tier Override for Scan

### 3.1 Current state

- The set of rules run by scan is determined solely by the project's `analysis_options.yaml` (and `analysis_options_custom.yaml`), as parsed by `loadScanConfig`. The `init` and `write_config` commands write that config based on a tier (e.g. `dart run saropa_lints init --tier recommended`).
- There is no way to say "run this scan with tier X" without editing the project's config. Consumers (e.g. drift_advisor) may want to run a "quick" scan with `essential` only or a "full" scan with `pedantic` without changing the user's analysis_options.

### 3.2 Goal

Allow a single scan run to use a tier name to define the rule set, overriding (for that run only) the project's `diagnostics:` section for "which rules are enabled."

### 3.3 Design

**Tier source**

- Tiers are already defined in `lib/src/init/cli_args.dart` (`tierOrder`: essential, recommended, professional, comprehensive, pedantic) and implemented in `lib/src/tiers.dart` (`getRulesForTier(String tier)`).

**ScanRunner**

- Add an optional parameter, e.g. `tier: String?`. Semantics:
  - If `tier` is `null`: keep current behavior — load enabled/disabled rules from config via `loadScanConfig(targetPath)`.
  - If `tier` is non-null: resolve the rule set with `getRulesForTier(tier)`. Do **not** read the project's `diagnostics:` for the enabled set. Still use `targetPath` for project root (e.g. for `analysis_options_custom.yaml` severity overrides, if desired; or ignore custom for tier override — clarify in docs).
  - Invalid tier name: either throw or fall back to config. Recommendation: if `tier` is provided and unknown, treat as error (throw or return null with message) so callers don't silently get wrong rule set.

**CLI**

- Add optional `--tier <name>` to `bin/scan.dart`. When present, pass the tier to `ScanRunner`. When absent, current behavior (config-only) is unchanged.
- Example: `dart run saropa_lints scan . --tier essential` runs only essential rules regardless of what's in analysis_options.yaml.

**Interaction with config**

- When tier is used, the project's `diagnostics:` section is **not** used for "enabled set." Optionally, the project's `analysis_options_custom.yaml` severity overrides could still be applied on top of the tier's rule set; document the chosen behavior.

### 3.4 Acceptance criteria

- [x] `ScanRunner(targetPath, tier: 'recommended')` runs with the rule set from `getRulesForTier('recommended')` and does not use the project's `diagnostics:` for enabled list.
- [x] CLI supports `--tier essential|recommended|professional|comprehensive|pedantic`.
- [x] Invalid tier (e.g. `--tier foo`) produces a clear error and non-zero exit (or documented fallback).
- [x] When `--tier` is omitted, behavior is unchanged (config-only).
- [x] README or help text documents that `--tier` overrides the project config for that run.

---

## 4. Optional: Machine-Readable Output (e.g. JSON)

### 4.1 Current state

- Scan writes a human-readable report to `reports/<date>/<timestamp>_scan_report.log` (path and format as in `bin/scan.dart`). Consumers that want to parse results must rely on the current text format (file path lines, then rule/line/severity lines).

### 4.2 Goal

Provide a stable, machine-readable format (e.g. JSON) so that scripts or other tools can consume scan results without ad-hoc parsing of the log file.

### 4.3 Design

- Add an optional flag, e.g. `--format json` (and keep default as human-readable text or "log").
- When `--format json`:
  - Output to stdout (or to a separate file, e.g. `..._scan_report.json`) a JSON structure that includes at least: list of diagnostics, each with file path, line, column, rule name, severity, message; optional summary (total count, by file, by rule).
- Schema: document the JSON shape (e.g. in README or a separate doc) so consumers can rely on it.
- API: `ScanRunner.run()` already returns `List<ScanDiagnostic>?`. The CLI can serialize that list to JSON when `--format json` is set. Optionally, expose a small helper in the public API to serialize `List<ScanDiagnostic>` to the same JSON structure so that programmatic callers can produce identical output without going through the CLI.

### 4.4 Acceptance criteria (optional)

- [x] `dart run saropa_lints scan . --format json` writes JSON to stdout or to a documented file path.
- [x] JSON schema or shape is documented (fields: filePath, line, column, ruleName, severity, problemMessage, etc.).
- [x] (Optional) Public API exposes a function to serialize `List<ScanDiagnostic>` to the same JSON format.

---

## 5. Implementation Order

Suggested order of work:

1. **Public API (Section 1)** — Done.
2. **File-list support (Section 2)** — Done.
3. **Tier override (Section 3)** — Done.
4. **Optional: JSON output (Section 4)** — Done.

---

## 6. Dependencies and Compatibility

- **Dart SDK:** No change; existing constraints apply.
- **analyzer / analyzer_plugin:** No change; scan continues to use the same analysis utilities.
- **Consumers:** saropa_drift_advisor (and any other package) can add a dev_dependency on saropa_lints and use the new scan API and CLI options without breaking existing workflows. All new parameters are optional.

---

## 7. References

- **Consumer plan:** [saropa_drift_advisor plans/saropa_lints_integration.md](https://github.com/saropa/saropa_drift_advisor/blob/main/plans/saropa_lints_integration.md)
- **Current scan CLI:** `bin/scan.dart`
- **Current scan implementation:** `lib/src/scan/scan_runner.dart`, `scan_config.dart`, `scan_diagnostic.dart`
- **Tiers:** `lib/src/init/cli_args.dart` (`tierOrder`), `lib/src/tiers.dart` (`getRulesForTier`)
