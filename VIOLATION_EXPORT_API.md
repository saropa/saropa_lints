# Violation Export API Reference

> **Schema version:** 1.0
> **File:** `reports/.saropa_lints/violations.json`
> **Producer:** `saropa_lints` analysis plugin
> **Consumer:** Saropa Log Capture (and any tool reading structured lint data)

## Overview

The violation export is a JSON file written after every analysis run. It contains the complete set of lint violations, analysis configuration, and aggregate statistics from the session. The file is overwritten atomically on each run so it always reflects the latest analysis state.

### File Location

```
<project_root>/reports/.saropa_lints/violations.json
```

The `.saropa_lints` directory is created automatically under the project's `reports/` folder, which is already in `.gitignore`.

### Write Semantics

- Written after every debounce cycle (alongside the markdown report)
- Atomic write: temp file, delete old, rename (with direct-write fallback)
- Contains **all** violations regardless of the `maxIssues` IDE cap
- Overwritten on each analysis run (only latest session is kept)
- Never deleted by the plugin

---

## Root Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema` | `string` | Yes | Schema version. Always `"1.0"` for this version |
| `version` | `string` | No | saropa_lints package version (e.g. `"4.14.0"`). Absent if config was not captured |
| `timestamp` | `string` | Yes | ISO 8601 UTC timestamp of export generation (e.g. `"2026-02-09T14:30:22.123Z"`) |
| `sessionId` | `string` | Yes | Analysis session identifier (format: `YYYYMMDD_HHMMSS`) |
| `config` | `object` | Yes | [Config object](#config-object) |
| `summary` | `object` | Yes | [Summary object](#summary-object) |
| `violations` | `array` | Yes | Array of [Violation objects](#violation-object), sorted by impact then file then line |

### Example (minimal)

```json
{
  "schema": "1.0",
  "version": "4.14.0",
  "timestamp": "2026-02-09T14:30:22.123456Z",
  "sessionId": "20260209_143022",
  "config": { "tier": "comprehensive", "..." : "..." },
  "summary": { "totalViolations": 42, "..." : "..." },
  "violations": [ { "..." : "..." } ]
}
```

---

## Config Object

Analysis configuration snapshot captured at rule-loading time. If the plugin failed to capture configuration, this object contains only `{ "tier": "unknown" }`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tier` | `string` | Yes | Effective analysis tier. One of: `"essential"`, `"recommended"`, `"professional"`, `"comprehensive"`, `"pedantic"`, or `"unknown"` |
| `enabledRuleCount` | `integer` | Yes | Number of rules enabled after tier selection and user overrides |
| `enabledRuleCountNote` | `string` | Yes | Human-readable explanation: `"After tier selection and user overrides"` |
| `enabledRuleNames` | `string[]` | Yes | Full list of enabled rule names (e.g. `["avoid_print", "prefer_const", ...]`). May be empty if not captured |
| `enabledPlatforms` | `string[]` | Yes | Platforms with rules active (e.g. `["ios", "android"]`) |
| `disabledPlatforms` | `string[]` | Yes | Platforms with rules inactive (e.g. `["macos", "web"]`) |
| `enabledPackages` | `string[]` | Yes | Package-specific rule sets active (e.g. `["firebase", "riverpod"]`) |
| `disabledPackages` | `string[]` | Yes | Package-specific rule sets inactive (e.g. `["isar", "hive"]`) |
| `userExclusions` | `string[]` | Yes | Rules explicitly disabled by the user in `analysis_options_custom.yaml` |
| `maxIssues` | `integer` | Yes | IDE Problems tab cap. `0` means unlimited |
| `maxIssuesNote` | `string` | Yes | Explanation: `"IDE Problems tab cap only; this export contains all violations"` |
| `outputMode` | `string` | Yes | Report output mode. One of: `"both"`, `"report"`, `"json"`, `"none"` |

### Example

```json
{
  "tier": "comprehensive",
  "enabledRuleCount": 1590,
  "enabledRuleCountNote": "After tier selection and user overrides",
  "enabledRuleNames": ["avoid_print", "prefer_const", "..."],
  "enabledPlatforms": ["ios", "android"],
  "disabledPlatforms": ["macos", "web"],
  "enabledPackages": ["firebase"],
  "disabledPackages": ["isar", "hive"],
  "userExclusions": ["no_magic_numbers"],
  "maxIssues": 1000,
  "maxIssuesNote": "IDE Problems tab cap only; this export contains all violations",
  "outputMode": "both"
}
```

---

## Summary Object

Aggregate statistics for the analysis session. All counts are computed from the deduplicated violation set across all isolate batches.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filesAnalyzed` | `integer` | Yes | Total number of Dart files analyzed |
| `filesWithIssues` | `integer` | Yes | Number of files with at least one violation |
| `totalViolations` | `integer` | Yes | Total violation count (matches `violations` array length) |
| `batchCount` | `integer` | Yes | Number of isolate batches that contributed to this session. Values >1 indicate the analyzer restarted isolates during the run |
| `bySeverity` | `object` | Yes | [Severity counts object](#severity-counts) |
| `byImpact` | `object` | Yes | [Impact counts object](#impact-counts) |
| `issuesByFile` | `object` | Yes | [Issues-by-file map](#issues-by-file) |
| `issuesByRule` | `object` | Yes | [Issues-by-rule map](#issues-by-rule) |
| `ruleSeverities` | `object` | Yes | [Rule severities map](#rule-severities) |

### Example

```json
{
  "filesAnalyzed": 247,
  "filesWithIssues": 38,
  "totalViolations": 142,
  "batchCount": 2,
  "bySeverity": { "error": 5, "warning": 42, "info": 95 },
  "byImpact": { "critical": 3, "high": 12, "medium": 45, "low": 72, "opinionated": 10 },
  "issuesByFile": { "lib/auth.dart": 8, "lib/main.dart": 3 },
  "issuesByRule": { "avoid_print": 15, "prefer_const": 42 },
  "ruleSeverities": { "avoid_print": "warning", "prefer_const": "info" }
}
```

### Severity Counts

Violation counts grouped by Dart analyzer severity level.

| Field | Type | Description |
|-------|------|-------------|
| `error` | `integer` | Number of ERROR-severity violations |
| `warning` | `integer` | Number of WARNING-severity violations |
| `info` | `integer` | Number of INFO-severity violations |

### Impact Counts

Violation counts grouped by saropa_lints impact level. All five keys are always present (value `0` if no violations at that level).

| Field | Type | Description |
|-------|------|-------------|
| `critical` | `integer` | Security holes, crashes, memory leaks. Even 1-2 is unacceptable |
| `high` | `integer` | Significant issues that compound. 10+ indicates systemic problems |
| `medium` | `integer` | Code quality issues. 100+ suggests accumulated tech debt |
| `low` | `integer` | Style and consistency. Large counts normal in legacy codebases |
| `opinionated` | `integer` | Preferential patterns. Teams may opt-in or downgrade freely |

Impact levels are ordered by severity: `critical` > `high` > `medium` > `low` > `opinionated`.

### Issues By File

```
Map<string, integer>
```

Keys are **relative file paths** from the project root, forward-slash normalized (matching the `file` field in violation objects). Values are the number of violations in that file. Only files with at least one violation appear.

Use this for quick file-level lookups without iterating the violations array.

### Issues By Rule

```
Map<string, integer>
```

Keys are rule names (e.g. `"avoid_print"`). Values are the number of violations for that rule across all files. Only rules with at least one violation appear.

Use this for trend analysis and dashboard summaries.

### Rule Severities

```
Map<string, string>
```

Keys are rule names. Values are **lowercase** severity strings: `"error"`, `"warning"`, or `"info"`. Contains entries for all rules that produced violations. This is a lookup table so consumers don't need to extract severity from individual violations.

---

## Violation Object

Each element in the `violations` array represents a single lint violation.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | `string` | Yes | Relative file path from project root, forward-slash normalized (e.g. `"lib/auth/login.dart"`) |
| `line` | `integer` | Yes | 1-based line number where the violation occurs |
| `rule` | `string` | Yes | Rule name (e.g. `"avoid_hardcoded_credentials"`) |
| `message` | `string` | Yes | Problem message describing the violation |
| `correction` | `string` | No | Suggested fix. Absent (not `null`) when the rule has no correction message |
| `severity` | `string` | Yes | Dart analyzer severity: `"error"`, `"warning"`, or `"info"` (always lowercase) |
| `impact` | `string` | Yes | saropa_lints impact level: `"critical"`, `"high"`, `"medium"`, `"low"`, or `"opinionated"` (always lowercase) |
| `owasp` | `object` | Yes | [OWASP mapping object](#owasp-object) |

### Sort Order

Violations are sorted by:
1. **Impact** (critical first, opinionated last) — by enum ordinal
2. **File** (alphabetical, case-insensitive)
3. **Line** (ascending)

### Example

```json
{
  "file": "lib/auth/login.dart",
  "line": 42,
  "rule": "avoid_hardcoded_credentials",
  "message": "[avoid_hardcoded_credentials] Hardcoded credential detected...",
  "correction": "Use environment variables or a secure vault instead.",
  "severity": "error",
  "impact": "critical",
  "owasp": {
    "mobile": ["m1"],
    "web": ["a02", "a07"]
  }
}
```

---

## OWASP Object

OWASP Top 10 category mappings for security-relevant rules. Present on every violation; empty arrays for non-security rules.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `mobile` | `string[]` | Yes | OWASP Mobile Top 10 IDs (lowercase, e.g. `["m1", "m9"]`) |
| `web` | `string[]` | Yes | OWASP Web Top 10 IDs (lowercase, e.g. `["a02", "a07"]`) |

### OWASP Mobile Top 10 IDs

| ID | Category |
|----|----------|
| `m1` | Improper Credential Usage |
| `m2` | Inadequate Supply Chain Security |
| `m3` | Insecure Authentication / Authorization |
| `m4` | Insufficient Input/Output Validation |
| `m5` | Insecure Communication |
| `m6` | Inadequate Privacy Controls |
| `m7` | Insufficient Binary Protections |
| `m8` | Security Misconfiguration |
| `m9` | Insecure Data Storage |
| `m10` | Insufficient Cryptography |

### OWASP Web Top 10 IDs

| ID | Category |
|----|----------|
| `a01` | Broken Access Control |
| `a02` | Cryptographic Failures |
| `a03` | Injection |
| `a04` | Insecure Design |
| `a05` | Security Misconfiguration |
| `a06` | Vulnerable and Outdated Components |
| `a07` | Identification and Authentication Failures |
| `a08` | Software and Data Integrity Failures |
| `a09` | Security Logging and Monitoring Failures |
| `a10` | Server-Side Request Forgery (SSRF) |

### Examples

Security rule with OWASP mapping:
```json
{ "mobile": ["m1"], "web": ["a02", "a07"] }
```

Non-security rule (empty arrays):
```json
{ "mobile": [], "web": [] }
```

---

## Impact vs. Severity

The export contains two orthogonal classification axes for each violation:

| Axis | Source | Values | Purpose |
|------|--------|--------|---------|
| **severity** | Dart analyzer (`ErrorSeverity`) | `error`, `warning`, `info` | IDE integration — controls Problems tab icons, squiggle colors |
| **impact** | saropa_lints (`LintImpact`) | `critical`, `high`, `medium`, `low`, `opinionated` | Business priority — how harmful is this pattern in production? |

A rule can be `severity: "info"` (mild IDE indicator) but `impact: "high"` (genuinely harmful pattern). Consumers should use `impact` for prioritization and `severity` for IDE-level filtering.

---

## Schema Versioning

- **`schema: "1.0"`** — current version (this document)
- Schema changes follow semver principles:
  - **Minor** (1.1, 1.2): New optional fields, new enum values. Existing consumers unaffected
  - **Major** (2.0): Breaking changes to existing field types, removals, or structural changes

### Planned for v1.1

- `column` field on violations (1-based column number)
- `endLine` / `endColumn` fields for range-based violations

Consumers should ignore unknown fields for forward compatibility.

---

## Full Example

```json
{
  "schema": "1.0",
  "version": "4.14.0",
  "timestamp": "2026-02-09T14:30:22.123456Z",
  "sessionId": "20260209_143022",
  "config": {
    "tier": "comprehensive",
    "enabledRuleCount": 1590,
    "enabledRuleCountNote": "After tier selection and user overrides",
    "enabledRuleNames": ["avoid_print", "prefer_const", "avoid_hardcoded_credentials"],
    "enabledPlatforms": ["ios", "android"],
    "disabledPlatforms": ["macos", "web"],
    "enabledPackages": ["firebase"],
    "disabledPackages": [],
    "userExclusions": [],
    "maxIssues": 1000,
    "maxIssuesNote": "IDE Problems tab cap only; this export contains all violations",
    "outputMode": "both"
  },
  "summary": {
    "filesAnalyzed": 247,
    "filesWithIssues": 38,
    "totalViolations": 3,
    "batchCount": 1,
    "bySeverity": {
      "error": 1,
      "warning": 1,
      "info": 1
    },
    "byImpact": {
      "critical": 1,
      "high": 0,
      "medium": 1,
      "low": 1,
      "opinionated": 0
    },
    "issuesByFile": {
      "lib/auth/login.dart": 1,
      "lib/main.dart": 1,
      "lib/utils.dart": 1
    },
    "issuesByRule": {
      "avoid_hardcoded_credentials": 1,
      "avoid_print": 1,
      "prefer_const": 1
    },
    "ruleSeverities": {
      "avoid_hardcoded_credentials": "error",
      "avoid_print": "warning",
      "prefer_const": "info"
    }
  },
  "violations": [
    {
      "file": "lib/auth/login.dart",
      "line": 42,
      "rule": "avoid_hardcoded_credentials",
      "message": "[avoid_hardcoded_credentials] Hardcoded credential detected in string literal assignment to variable 'apiKey'. Hardcoded secrets are extracted trivially from compiled binaries and version-control history.",
      "correction": "Use environment variables or a secure vault instead of hardcoding credentials.",
      "severity": "error",
      "impact": "critical",
      "owasp": {
        "mobile": ["m1"],
        "web": ["a02", "a07"]
      }
    },
    {
      "file": "lib/main.dart",
      "line": 15,
      "rule": "avoid_print",
      "message": "[avoid_print] print() statement found. Use a proper logging framework for production code.",
      "severity": "warning",
      "impact": "medium",
      "owasp": {
        "mobile": [],
        "web": []
      }
    },
    {
      "file": "lib/utils.dart",
      "line": 8,
      "rule": "prefer_const",
      "message": "[prefer_const] This value could be declared as const for better performance.",
      "correction": "Add the const keyword.",
      "severity": "info",
      "impact": "low",
      "owasp": {
        "mobile": [],
        "web": []
      }
    }
  ]
}
```

---

## Consumer Notes

### Reading the Export

1. Parse `violations.json` as UTF-8 JSON
2. Check `schema` field for compatibility (currently `"1.0"`)
3. Ignore unknown fields for forward compatibility
4. Use `summary.issuesByFile` and `summary.issuesByRule` for quick lookups instead of iterating the violations array
5. Use `summary.ruleSeverities` as a lookup table for rule severity

### File Path Handling

- `violations[].file` paths are **relative** to the project root, using forward slashes (`/`) on all platforms
- `summary.issuesByFile` keys use the **same relative forward-slash format** as `violations[].file`
- All paths are normalized at export time — no absolute or platform-specific paths appear in the JSON

### Absent vs. Empty

- `correction`: **absent from JSON** when the rule has no correction message. Never `null`
- `version`: **absent from JSON** when config was not captured. Never `null`
- All array fields (`enabledRuleNames`, `owasp.mobile`, etc.): always present, may be empty `[]`
- All map fields (`issuesByFile`, `issuesByRule`, `ruleSeverities`): always present, may be empty `{}`

### Freshness

The export is overwritten on every analysis debounce cycle (default 3 seconds after the last file visit). Check the `timestamp` field to determine freshness. The `sessionId` changes when a new analysis session starts (e.g. after a file save triggers re-analysis).

---

## Implementation Files

| File | Description |
|------|-------------|
| `lib/src/report/violation_export.dart` | `ViolationExporter` class and `toRelativePath()` utility |
| `lib/src/report/analysis_reporter.dart` | Integration point — calls `ViolationExporter.write()` in `_writeReport()` |
| `lib/src/report/report_consolidator.dart` | `ConsolidatedData` — merged data from all isolate batches |
| `lib/src/report/batch_data.dart` | `BatchData` — per-isolate serialization including `ViolationRecord.correction` |
| `lib/src/saropa_lint_rule.dart` | `ViolationRecord`, `LintImpact`, `OwaspMapping` definitions |
| `lib/saropa_lints.dart` | `_buildOwaspLookup()` — constructs rule-name-to-OWASP mapping |
| `test/violation_export_test.dart` | 22 unit tests covering all fields and edge cases |
| `bugs/discussion/log_capture_integration.md` | Design specification document |
