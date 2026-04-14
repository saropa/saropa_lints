# Discussion: Suppression Tracking (Audit trail of suppressed lints for tech debt tracking)

**Source:** [GitHub Discussion #56](https://github.com/saropa/saropa_lints/discussions/56)  
**Priority:** High  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)  
**Last reviewed:** 2026-04-14

---

## 1. Goal

Record every time a lint is suppressed (via `// ignore:`, `// ignore_for_file:`, baseline, or future custom prefixes) to support:

- **Cleanup campaigns** — List all suppressions so teams can fix underlying issues and remove ignores.
- **Security audits** — Answer "are security rules being suppressed?" and where.
- **Tech debt tracking** — Treat suppressions as first-class tech debt items; report in the VS Code extension sidebar and/or exported reports.

---

## 2. Current state in saropa_lints (as of 2026-04-14)

### Dart plugin side

- **IgnoreUtils** (`lib/src/ignore_utils.dart`): Parses `// ignore: rule_name` and `// ignore_for_file: rule_name` with hyphen/underscore flexibility. Handles leading comments, trailing same-line comments, ancestor chains, and special cases (MethodInvocation mid-chain, PropertyAccess, CatchClause).
- **SaropaDiagnosticReporter** (`lib/src/saropa_lint_rule.dart:2651`): Central reporter wrapping the native `AnalysisRule` reporting. Three reporting methods (`atNode`, `atToken`, `atOffset`) each check suppression before reporting. The private `_isSuppressed()` method checks baseline, file-level ignore, and node-level ignore in sequence.
- **Violation tracking already exists:** When a violation is *not* suppressed, `_trackViolation()` records it via both `ImpactTracker.record()` and `ProgressTracker.recordViolation()`. These write to `violations.json` and impact/progress outputs. **No equivalent tracking exists for suppressions** — when `_isSuppressed()` returns true, the method simply returns without recording anything.
- **BaselineManager** (`lib/src/baseline/baseline_manager.dart`): Handles baselining existing violations. Baseline suppressions are distinct from ignore-comment suppressions but both are checked in the reporter's `_isSuppressed()` path.

### VS Code extension side

- **suppressionsStore.ts** (`extension/src/suppressionsStore.ts`): Manages *UI-level view suppressions* (hidden folders, files, rules, severities, impacts in the Issues tree). This is unrelated to code-level `// ignore:` tracking — it controls what the user sees in the sidebar, not what the analyzer suppresses.
- **violationsReader.ts**: Reads `violations.json` produced by the plugin. Currently only contains reported (non-suppressed) violations.
- **Issues tree, Security Posture tree, Overview tree**: Existing sidebar trees that display violations. A "Suppressions" tree or section could integrate here.
- **reportWriter.ts / owaspExport.ts**: Existing report export infrastructure that could include suppression data.

### Gap

There is no central record of "rule X was suppressed at file F, line L" persisted for later reporting or auditing. The suppression decision happens silently inside `_isSuppressed()` / `_isBaselined()` / `_isIgnoredForFile()` and is not recorded anywhere.

---

## 3. Proposed design

### 3.1 Dart plugin: SuppressionRecord and SuppressionTracker

```dart
/// A single suppressed diagnostic.
class SuppressionRecord {
  final String rule;
  final String file;
  final int line;
  final SuppressionKind kind; // ignore, ignoreForFile, baseline
  // Future: prefix field for custom prefixes (Discussion #59)

  SuppressionRecord({
    required this.rule,
    required this.file,
    required this.line,
    required this.kind,
  });
}

enum SuppressionKind { ignore, ignoreForFile, baseline }

/// Collects suppression records during analysis, mirrors ImpactTracker pattern.
class SuppressionTracker {
  static final List<SuppressionRecord> records = [];

  static void record({
    required String rule,
    required String file,
    required int line,
    required SuppressionKind kind,
  }) {
    records.add(SuppressionRecord(rule: rule, file: file, line: line, kind: kind));
  }

  /// Write to suppressions.json alongside violations.json.
  static void flush(String outputDir) { /* ... */ }
}
```

### 3.2 Hook point: SaropaDiagnosticReporter

The natural insertion point is `_isSuppressed()`, `_isBaselined()`, `_isIgnoredForFile()`, and the individual `atToken`/`atOffset` methods where ignore checks happen inline. When any check returns true, call `SuppressionTracker.record()` before returning.

```dart
// In _isSuppressed():
if (_isBaselined(offset)) {
  SuppressionTracker.record(rule: _ruleName, file: path, line: line, kind: SuppressionKind.baseline);
  return true;
}
if (_isIgnoredForFile()) {
  SuppressionTracker.record(rule: _ruleName, file: path, line: line, kind: SuppressionKind.ignoreForFile);
  return true;
}
if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {
  SuppressionTracker.record(rule: _ruleName, file: path, line: line, kind: SuppressionKind.ignore);
  return true;
}
return false;
```

### 3.3 Output: suppressions.json

Write a `suppressions.json` file alongside the existing `violations.json`, using the same output directory and flush timing. Format:

```json
{
  "suppressions": [
    { "rule": "avoid_print", "file": "lib/app.dart", "line": 42, "kind": "ignore" },
    { "rule": "require_https", "file": "lib/api.dart", "line": 10, "kind": "ignoreForFile" }
  ],
  "summary": {
    "totalSuppressions": 14,
    "byKind": { "ignore": 8, "ignoreForFile": 4, "baseline": 2 },
    "byRule": { "avoid_print": 5, "require_https": 3 }
  }
}
```

### 3.4 VS Code extension: Suppressions sidebar section

- **New tree provider** or section within the existing Issues tree that reads `suppressions.json`.
- **Group by:** rule name (default), file, suppression kind, or severity/impact.
- **Click-to-navigate:** Each suppression entry navigates to the file and line.
- **Counts in sidebar header:** "Suppressions (14)" similar to existing issue counts in `sidebarSectionCounts.ts`.
- **Filter/hide controls:** Reuse the existing `suppressionsStore.ts` pattern for UI-level hiding, or add new filter dimensions (by kind, by rule).
- **Report export:** Include suppression data in the existing report infrastructure (`reportWriter.ts`), and optionally in OWASP exports for security-relevant suppressions.

---

## 4. Use cases

| Use case | How suppression tracking helps |
|----------|---------------------------------|
| Cleanup campaigns | Generate list of all ignores so teams can fix and remove them. Extension shows clickable list. |
| Security audits | Report "security rules suppressed N times" and list files/lines. Filter by OWASP-mapped rules. |
| Tech debt tracking | Report suppressions (e.g. tech-debt prefix) separately; dedicated sidebar section. |
| Policy compliance | Enforce "no suppressions for rule X" or "all suppressions must have ticket." CI reads suppressions.json. |
| Metrics | Track suppression rate (suppressions / (suppressions + violations)). Show in Overview tree. |
| Baseline burn-down | Track how many baseline suppressions remain vs. initial count. Show trend over time. |

---

## 5. Research and prior art

- **ESLint:** `--report-unused-disable-directives` flags stale ignores; no built-in suppression audit file.
- **SonarQube:** Tracks "won't fix" and resolutions; quality gates can limit suppressions.
- **Dart analyzer:** Applies `// ignore:` internally; our plugin must record suppressions itself since the analyzer doesn't expose what it suppressed.
- **This project's existing pattern:** `ImpactTracker` and `ProgressTracker` already record reported violations. SuppressionTracker follows the same static-list + flush pattern, keeping implementation consistent.

---

## 6. Implementation plan

### Quick wins (implemented 2026-04-14)

Three quick wins shipped as the foundation for full suppression tracking:

**QW1: Suppression counting in the Dart plugin**
- Added `SuppressionKind` enum (`ignore`, `ignoreForFile`, `baseline`) and `SuppressionTracker` class in `lib/src/saropa_lint_rule.dart` following the `ImpactTracker` pattern.
- Hooked all three suppression check paths in `SaropaDiagnosticReporter`: `_isSuppressed()` (covers `atNode`), `atToken()`, and `atOffset()`. Every suppressed diagnostic now increments the appropriate counter.
- Added `SuppressionTracker.reset()` call in `AnalysisReporter._startNewSession()` so counters reset between analysis runs.

**QW2: Suppression summary in the console log**
- Added a "SUPPRESSED DIAGNOSTICS" section to `ProgressTracker.reportSummary()` showing counts by kind (ignore, ignore_for_file, baseline) with a total. Only appears when at least one diagnostic was suppressed.

**QW3: Suppression counts in violations.json and the extension Overview tree**
- Added a `suppressions` object (`total` + `byKind`) to the `summary` section of `violations.json` via `ViolationExporter._buildSummary()`.
- Added `SuppressionsSummary` and `SuppressionsByKind` interfaces to the extension's `violationsReader.ts` and wired parsing.
- Added a suppression count row ("N suppressed") to the Overview tree dashboard and the embedded Health Summary section in `overviewTree.ts`.

### Phase 1: Per-file suppression records (next)

1. Expand `SuppressionTracker` to store full `SuppressionRecord` objects (rule, file, line, kind) in addition to counts.
2. Write a separate `suppressions.json` file alongside `violations.json` with the full record list and summary.
3. Add per-rule and per-file suppression breakdowns to `violations.json` summary.

### Phase 2: Extension sidebar section

1. Add a dedicated "Suppressions" tree provider or sidebar section that reads suppression records.
2. Group by rule name (default), file, or suppression kind.
3. Click-to-navigate for each suppression entry.
4. Filter/hide controls (by kind, by rule, by file).

### Phase 3: Reporting and CI

1. Include suppression summary in text report exports (`reportWriter.ts`).
2. Include security-rule suppressions in OWASP export (`owaspExport.ts`).
3. Document `suppressions.json` schema for CI consumption.
4. Add suppression-rate metric (suppressions / total) to Overview tree.

### Phase 4: Custom prefixes (depends on Discussion #59)

1. When custom ignore prefixes land, add a `prefix` field to `SuppressionRecord`.
2. Support filtering by prefix in the extension UI and reports.

---

## 7. Resolved questions

| Question | Resolution |
|----------|-----------|
| Opt-in or always-on? | Always-on for recording; reporting is opt-in (user opens the sidebar section or reads the JSON). No env flag needed — the overhead is one list append per suppression. |
| Distinguish ignore vs baseline? | Yes — `SuppressionKind` enum with `ignore`, `ignoreForFile`, `baseline` covers all current suppression paths. |
| Integrate with Discussion #59? | Yes, as Phase 4. `SuppressionRecord` gains a `prefix` field when custom prefixes ship. Tracked separately to avoid blocking this work. |

## 8. Open questions

- Should `suppressions.json` be cumulative across runs (append) or replaced each run? Replaced is simpler and matches `violations.json` behavior.
- Should the extension show a suppression-rate percentage (suppressions / total) in the Overview tree, or is that too noisy?
- Should there be a command to "go to next suppression" for cleanup workflows, similar to "go to next error"?
