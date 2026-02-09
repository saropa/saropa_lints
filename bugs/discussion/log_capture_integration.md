# Feature: Saropa Log Capture integration via structured violation export

## Status: Implemented (v1.0)

## Problem

A developer using both **Saropa Lints** (static analysis) and **Saropa Log Capture**
(runtime debug log capture) has two independent data sets about the same codebase:

1. **Lint violations** — Known code quality issues with file, line, rule, impact, and
   OWASP classification. Produced *before* runtime.
2. **Runtime errors** — Actual crashes, exceptions, and warnings captured from debug
   sessions. Produced *during* runtime. Includes stack traces, error fingerprints,
   correlation tags, cross-session recurrence data, and source references.

These two data sets share a natural join key — `file:line` — but today there is no
machine-readable bridge between them. The developer must mentally cross-reference a
markdown lint report with a separate log viewer to answer questions like:

- "Was this crash predicted by a lint rule?"
- "Which critical lint violations have actually caused runtime errors?"
- "Are the files in my stack trace flagged for anything?"

Saropa Log Capture already generates rich bug reports with stack traces, git blame,
source code previews, cross-session history, and symbol resolution. Adding a "Known
Lint Issues" section would make these reports significantly more actionable — but only
if Saropa Lints provides a stable, machine-readable export.

## Scope

This requirement covers **only the Saropa Lints side**: a new structured JSON export
written alongside the existing markdown report. No changes to the markdown report
format, rule execution, or analysis pipeline are proposed.

The consuming side (Saropa Log Capture) will implement its own reader in a separate
effort. This document defines the contract between the two projects.

---

## What the developer sees (end state)

### In Saropa Log Capture bug reports

When a runtime error occurs and the developer generates a bug report, Log Capture
checks for the structured lint export. If found, the bug report includes:

```markdown
## Known Lint Issues

3 lint violations found in files appearing in this stack trace.

| File | Line | Rule | Impact | Message |
|------|------|------|--------|---------|
| lib/services/auth_service.dart | 42 | require_field_dispose | critical | TextEditingController is never disposed |
| lib/services/auth_service.dart | 87 | avoid_context_across_async | critical | BuildContext used after async gap |
| lib/screens/login_screen.dart | 156 | avoid_setstate_after_dispose | high | setState called in async callback without mounted check |

> Source: saropa_lints v4.12.2, comprehensive tier, analyzed 2026-02-09T14:30:22Z
```

### In cross-session analysis

When the same error fingerprint recurs across sessions, Log Capture can show:

```markdown
## Lint Correlation

This error has occurred in 4 sessions. The following lint violations have been
present in affected files across all 4 sessions:

- `require_field_dispose` on auth_service.dart:42 — present since first occurrence
- `avoid_context_across_async` on auth_service.dart:87 — introduced in session 3
```

---

## Requirements

### R1: Structured violation export file

Saropa Lints MUST write a JSON file alongside the existing markdown report containing
all deduplicated violations from the current analysis session.

**File path:**

```
{project_root}/reports/.saropa_lints/violations.json
```

Rationale for `.saropa_lints/` subdirectory:
- Separates machine-readable output from human-readable reports
- Avoids collision with Log Capture's own files in `reports/`
- The leading dot keeps it out of casual directory listings
- Single well-known path means consumers don't need to parse session IDs or timestamps

**This file is overwritten on every analysis run.** It represents the current state, not
a history. Consumers can snapshot it if they need historical tracking.

### R2: Export file schema

```jsonc
{
  // Schema version for forward compatibility. Consumers MUST check this
  // and ignore the file if the major version is unrecognized.
  "schema": "1.0",

  // Saropa Lints package version that produced this file.
  "version": "4.12.2",

  // ISO 8601 timestamp of when this analysis completed.
  "timestamp": "2026-02-09T14:30:22.123456Z",

  // Session ID matching the markdown report filename prefix.
  "sessionId": "20260209_143022",

  // Analysis configuration snapshot.
  "config": {
    "tier": "comprehensive",
    "enabledRuleCount": 1590,
    "enabledRuleCountNote": "After tier selection and user overrides",
    "enabledPlatforms": ["ios", "android"],
    "disabledPlatforms": ["macos", "web", "windows", "linux"],
    "enabledPackages": ["firebase", "riverpod"],
    "maxIssues": 1000,
    "maxIssuesNote": "IDE Problems tab cap only; this export contains all violations",
    "outputMode": "both"
  },

  // Aggregate counts for quick consumption without parsing violations.
  "summary": {
    "filesAnalyzed": 147,
    "filesWithIssues": 42,
    "totalViolations": 234,
    "bySeverity": {
      "error": 45,
      "warning": 89,
      "info": 100
    },
    "byImpact": {
      "critical": 12,
      "high": 34,
      "medium": 88,
      "low": 95,
      "opinionated": 5
    }
  },

  // All deduplicated violations.
  // Ordered by: impact (critical first), then file path, then line number.
  "violations": [
    {
      // Relative path from project root. Forward slashes on all platforms.
      // Consumers join this with the project root to get an absolute path.
      "file": "lib/services/auth_service.dart",

      // 1-indexed line number.
      "line": 42,

      // Rule identifier. Matches the rule name in analysis_options.yaml.
      "rule": "require_field_dispose",

      // Human-readable violation message.
      "message": "TextEditingController is never disposed",

      // Optional correction message. Omitted when the rule has no
      // correctionMessage. Consumers MUST treat this field as optional.
      "correction": "Add a dispose() method that calls controller.dispose()",

      // Diagnostic severity as reported to the IDE.
      // One of: "error", "warning", "info".
      "severity": "error",

      // Business impact level.
      // One of: "critical", "high", "medium", "low", "opinionated".
      "impact": "critical",

      // OWASP mappings, if any. Empty arrays when not applicable.
      // Mobile: m1-m10 (OWASP Mobile Top 10 2024, lowercase).
      // Web: a01-a10 (OWASP Top 10 2021, lowercase).
      "owasp": {
        "mobile": ["m9"],
        "web": []
      }
    }
  ]
}
```

### R3: File path normalization

All `file` values in the violations array MUST use:

- **Relative paths** from the project root (not absolute paths)
- **Forward slashes** as separator on all platforms (not backslashes on Windows)
- **No leading slash** (e.g., `lib/main.dart`, not `/lib/main.dart`)

Rationale: Log Capture also normalizes source references to relative paths for
cross-platform compatibility. Using the same convention eliminates path-matching
ambiguity.

### R4: Violation ordering

Violations MUST be ordered by:

1. Impact: `critical` > `high` > `medium` > `low` > `opinionated`
2. File path: alphabetical (case-insensitive)
3. Line number: ascending

This ordering lets consumers efficiently find the highest-impact violations for a
given file without sorting.

### R5: No violation cap

The export file MUST contain **all** deduplicated violations, regardless of the
`max_issues` setting. The `max_issues` cap applies only to the IDE Problems tab.

Rationale: The export serves offline analysis tools that benefit from the complete
picture. A consumer correlating stack traces against lint data needs violations from
every file, not just the first 1,000.

### R6: Idempotent overwrite

Each analysis run overwrites `violations.json` completely. There is no append or
merge behavior. The file represents a point-in-time snapshot.

If an analysis run produces zero violations, the file MUST still be written with an
empty `violations` array. Consumers distinguish "no violations" from "linter not run"
by the file's existence and timestamp.

### R7: Atomic write

The file MUST be written atomically to prevent consumers from reading a
partially-written file. The implementation writes to a `.tmp` file, deletes
the existing target, then renames. If any step fails (e.g., filesystem
permissions), it falls back to a direct write.

### R8: OWASP field population

The `owasp` object MUST be present on every violation. When a rule has no OWASP
mapping, both arrays MUST be empty (`{"mobile": [], "web": []}`).

OWASP IDs use the format already defined in `owasp_category.dart`:
- Mobile: lowercase `m1` through `m10`
- Web: lowercase `a01` through `a10`

### R9: Schema versioning

The `schema` field uses semantic versioning (`major.minor`):

- **Major bump:** Breaking change (field removed, field type changed, field renamed).
  Consumers MUST reject unrecognized major versions.
- **Minor bump:** Additive change (new optional field added). Consumers MUST ignore
  unrecognized fields.

The initial version is `"1.0"`.

---

## Implementation notes

### Where to hook in

The export should be written in `ReportConsolidator` or `AnalysisReporter`, immediately
after the consolidated markdown report is written. At that point, `ConsolidatedData` is
fully populated with deduplicated violations, severity counts, and impact breakdown.

The data needed maps directly to existing structures:

| Export field | Source |
|--------------|--------|
| `version` | `ReportConfig.version` |
| `timestamp` | `DateTime.now().toUtc().toIso8601String()` |
| `sessionId` | `_sessionId` |
| `config.*` | `ReportConfig` fields |
| `summary.*` | `ConsolidatedData` aggregate fields |
| `violations[].file` | `ViolationRecord.file` (make relative, normalize slashes) |
| `violations[].line` | `ViolationRecord.line` |
| `violations[].rule` | `ViolationRecord.rule` |
| `violations[].message` | `ViolationRecord.message` |
| `violations[].correction` | `ViolationRecord.correction` (optional, from `LintCode.correctionMessage`) |
| `violations[].severity` | `ConsolidatedData.ruleSeverities[rule]` (lowercased) |
| `violations[].impact` | Key from `ConsolidatedData.violations` map |
| `violations[].owasp` | `AnalysisReporter._owaspLookup` (built from rule registry at config time) |

### Data gaps (resolved)

1. **Column number:** Omitted from v1.0. `ViolationRecord` does not store `column`.
   Candidate for v1.1 alongside `endLine`/`endColumn`.

2. **OWASP mapping:** Resolved. `_buildOwaspLookup()` in `saropa_lints.dart` iterates
   all rule factories once at config time and passes the map via
   `AnalysisReporter.setOwaspLookup()`.

3. **Relative path conversion:** Resolved. Shared `toRelativePath()` utility in
   `violation_export.dart` normalizes separators and strips the project root prefix.

4. **Correction message:** Resolved. `ViolationRecord.correction` added, populated from
   `LintCode.correctionMessage` at violation tracking time, serialized through the
   batch pipeline (`c2` key).

### Estimated size

For a project with 2,400 violations (the self-analysis benchmark), the JSON file would
be approximately 400-600 KB uncompressed. This is acceptable for a file that's
overwritten each run.

### Cleanup

The export file is **never** deleted during `cleanupSession()`. It persists as the
latest snapshot and is overwritten on the next analysis run. Zero-violation runs still
write the file with an empty `violations` array.

The `reports/.saropa_lints/` directory is created on first write and left in place.
It lives under the existing `reports/` directory which is already in `.gitignore`.

---

## Consumer contract (for Saropa Log Capture)

This section documents how Saropa Log Capture will consume the export. It is
informational for the Saropa Lints implementation — no Lints code changes are needed
to support these behaviors.

### Discovery

Log Capture will look for the export at:

```
{workspace_root}/reports/.saropa_lints/violations.json
```

If not found, the "Known Lint Issues" section is silently omitted from bug reports.

### Matching strategy

When generating a bug report for a runtime error, Log Capture will:

1. Collect all unique file paths from the stack trace (`StackFrame.sourceRef.filePath`)
2. Normalize each to a relative forward-slash path
3. Filter `violations.json` entries where `violation.file` matches any stack trace file
4. Further filter to violations within N lines of the stack frame line (configurable,
   default: same file = include all, same function = highlight)
5. Sort remaining violations by impact, then line proximity to the error

### Staleness detection

Log Capture will compare the export's `timestamp` against the current debug session
start time. If the export is older than 24 hours, the bug report will include a note:

```markdown
> Lint data may be stale (analyzed 2 days ago). Run `dart run custom_lint` to refresh.
```

### Runtime pattern → rule mapping (future)

A separate future feature could map runtime error patterns to lint rule names. For
example, if a `setState() called after dispose` error is captured, Log Capture could
suggest enabling `avoid_setstate_after_dispose`. This mapping would live in Log Capture
and does not require any Saropa Lints changes.

---

## File index for Saropa Lints implementation

| File | Role |
|------|------|
| `lib/src/report/violation_export.dart` | `ViolationExporter` class, `toRelativePath()` utility |
| `lib/src/report/analysis_reporter.dart` | Calls `ViolationExporter.write()` after markdown report; stores OWASP lookup |
| `lib/src/report/report_consolidator.dart` | `ConsolidatedData` definition, session management |
| `lib/src/report/batch_data.dart` | Serializes `correction` field (`c2` key) in batch JSON |
| `lib/src/saropa_lint_rule.dart` | `ViolationRecord` (with `correction`), `LintImpact`, `ImpactTracker` |
| `lib/src/owasp/owasp_category.dart` | `OwaspMapping`, `OwaspMobile`, `OwaspWeb` |
| `lib/saropa_lints.dart` | `_buildOwaspLookup()` iterates rule factories at config time |
| `test/violation_export_test.dart` | 16 unit tests for the export |

## File index for Saropa Log Capture implementation

| File | Relevance |
|------|-----------|
| `src/modules/bug-report-formatter.ts` | Add "Known Lint Issues" section |
| `src/modules/bug-report-collector.ts` | Read and parse `violations.json` |
| `src/modules/source-linker.ts` | Path normalization utilities |
| `src/modules/session-metadata.ts` | Potential lint snapshot storage |

---

## Testing

### Saropa Lints side

1. **Export written:** After analysis completes, `reports/.saropa_lints/violations.json`
   exists and is valid JSON matching the schema.
2. **All violations included:** Violation count in export matches `ConsolidatedData.total`
   (not capped by `max_issues`).
3. **Path normalization:** Absolute Windows paths (`D:\src\lib\main.dart`) converted to
   relative forward-slash (`lib/main.dart`).
4. **Ordering:** Violations sorted by impact, then file, then line.
5. **OWASP populated:** Rules with OWASP mappings have non-empty arrays; rules without
   have empty arrays.
6. **Zero violations:** File written with empty `violations` array when project is clean.
7. **Atomic write:** Concurrent reads during write don't see partial content.
8. **Overwrite:** Second analysis run replaces previous export completely.
9. **Schema version:** `schema` field is `"1.0"`.

### Saropa Log Capture side (separate effort)

1. **File missing:** Bug report generated without lint section when export absent.
2. **File stale:** Staleness note shown when export older than 24 hours.
3. **Matching:** Only violations in stack trace files appear in bug report.
4. **Schema mismatch:** Unrecognized major version causes silent skip with log warning.
5. **Large file:** 2,400-violation export parsed within 100ms.

---

## Implementation status

**Status: Implemented** — v1.0 export landed in the Saropa Lints codebase.

### Files created

| File | Purpose |
|------|---------|
| `lib/src/report/violation_export.dart` | `ViolationExporter` class — builds JSON, writes atomically |
| `test/violation_export_test.dart` | 16 unit tests covering schema, ordering, OWASP, paths, atomicity |

### Files modified

| File | Change |
|------|--------|
| `lib/src/saropa_lint_rule.dart` | Added `correction` field to `ViolationRecord`; pass `correction` in `ImpactTracker.record()` and `_trackViolation()` |
| `lib/src/report/batch_data.dart` | Serialize/deserialize `correction` (`c2` key) in batch JSON |
| `lib/src/report/analysis_reporter.dart` | Added `_owaspLookup` storage, `setOwaspLookup()` setter, and `ViolationExporter.write()` call after markdown report |
| `lib/saropa_lints.dart` | Added `_buildOwaspLookup()` function; called from `_applyReportConfig()` |

### Deviations from original spec

The following issues were identified during review and addressed in the implementation:

1. **R5/R2 `maxIssues` confusion** — The original spec included `maxIssues` in the
   config section without clarifying that the export is uncapped. The implementation adds
   `"maxIssuesNote": "IDE Problems tab cap only; this export contains all violations"`
   to make this explicit.

2. **Missing `correctionMessage`** — The original schema had no correction/fix suggestion
   field. The implementation adds an optional `"correction"` field per violation,
   populated from `LintCode.correctionMessage` when available. Omitted from the JSON
   when null to save space.

3. **OWASP ID format inconsistency** — The spec text said lowercase (`m1`, `a01`) but
   the schema example showed uppercase (`M9`). The implementation uses lowercase
   consistently, derived from `OwaspMobile.id.toLowerCase()` / `OwaspWeb.id.toLowerCase()`.

4. **`column` field omitted** — `ViolationRecord` does not carry column data. Rather than
   adding a placeholder `1`, the field is omitted entirely from v1.0. Documented as a
   v1.1 candidate.

5. **`endLine`/`endColumn` omitted** — Not available in `ViolationRecord`. Documented as
   a v1.1 candidate for improved function-level matching in Log Capture.

6. **Windows atomicity** — The spec said "write to temp file, then rename" which is not
   atomic on Windows (`File.rename()` fails if target exists). The implementation uses a
   delete-then-rename pattern with a fallback to direct write if any step fails.

7. **`enabledRuleCount` clarity** — Added `"enabledRuleCountNote"` field explaining this
   is the post-tier-selection, post-override count.

8. **Cleanup semantics clarified** — The export file is never deleted during
   `cleanupSession()`. It persists as the latest snapshot and is overwritten on the
   next analysis run. Zero-violation runs still write the file with an empty array.

9. **Output path** — Uses `reports/.saropa_lints/violations.json` under the existing
   `reports/` directory which is already in `.gitignore`. No separate `.gitignore`
   changes needed.

---

## Open questions

1. **Should the export include rule descriptions?** Each rule has a `code.message` that
   describes what the rule checks. Including it would make the export self-documenting
   but adds size. Current recommendation: omit, since the `message` field on each
   violation already describes the specific issue.

2. **Should file importance scores be included?** The `FILE IMPORTANCE` section in the
   markdown report computes fan-in, layer depth, and importance scores. Including these
   would let Log Capture show "this file is a critical hub (importance: 92/100)" in bug
   reports. Current recommendation: defer to v1.1 if consumers request it.

3. **Should the export include a per-file summary?** A `files` object mapping filenames
   to `{violationCount, maxImpact, importanceScore}` would let consumers quickly check
   if a file has any violations without scanning the full array. Current recommendation:
   defer to v1.1.

4. **Should disabled rules be listed?** Knowing which rules were *not* run helps
   consumers distinguish "no violations for rule X" from "rule X was disabled." Current
   recommendation: the `config.enabledRuleCount` and `config.tier` fields provide
   sufficient context. A full enabled/disabled rule list can be added in v1.1 if needed.
