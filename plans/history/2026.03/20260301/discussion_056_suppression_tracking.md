# Discussion: Suppression Tracking (Audit trail of suppressed lints for tech debt tracking)

**Source:** [GitHub Discussion #56](https://github.com/saropa/saropa_lints/discussions/56)  
**Priority:** High  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Record every time a lint is suppressed (via `// ignore:`, `// ignore_for_file:`, or future custom prefixes) to support:

- **Cleanup campaigns** — List all suppressions so teams can fix underlying issues and remove ignores.
- **Security audits** — Answer "are security rules being suppressed?" and where.
- **Tech debt tracking** — Treat suppressions as first-class tech debt items; report in a dedicated view.

---

## 2. Current state in saropa_lints

- **Ignore handling:** `IgnoreUtils` in `lib/src/ignore_utils.dart` parses `// ignore: rule_name` and `// ignore_for_file: rule_name` (with hyphen/underscore flexibility). Used to decide whether to report; if suppressed, the rule does not report.
- **No persistence of suppressions:** There is no central record of "rule X was suppressed at file F, line L" for later reporting or auditing.
- **Baseline:** `BaselineManager` handles baselining existing violations; separate from ignore-comment suppressions.

---

## 3. Proposed design (from Discussion #56)

```dart
class SaropaDiagnosticReporter {
  static final List<SuppressionRecord> suppressions = [];
  // When a diagnostic would be reported but is suppressed by an ignore comment:
  // suppressions.add(SuppressionRecord(rule: code.name, file: path, line: line, ...));
}
// Output: "avoid_print: 12 suppressions in 5 files"
```

- **SuppressionRecord:** rule name, file path, line; optionally raw comment text and prefix (e.g. ignore vs tech-debt).
- **When to record:** In the code path that decides "this diagnostic is suppressed."
- **Output:** Summary (per-rule counts, per-file counts) and optionally full list for report/CI.

---

## 4. Use cases

| Use case | How suppression tracking helps |
|----------|---------------------------------|
| Cleanup campaigns | Generate list of all ignores so teams can fix and remove them. |
| Security audits | Report "security rules suppressed N times" and list files/lines. |
| Tech debt tracking | Report suppressions (e.g. tech-debt prefix) separately. |
| Policy compliance | Enforce "no suppressions for rule X" or "all suppressions must have ticket." |
| Metrics | Track suppression rate (suppressions vs reported violations). |

---

## 5. Research and prior art

- **ESLint:** `--report-unused-disable-directives`; no built-in suppression audit file.
- **SonarQube:** Tracks "won't fix" and resolutions; quality gates can limit suppressions.
- **Dart analyzer:** Applies `// ignore:` internally; custom_lint must record suppressions when it skips reporting due to ignore.

Conclusion: Implementing suppression tracking inside the plugin (record when we skip reporting due to ignore) and exporting a summary/list is feasible and supports tech debt and security use cases.

---

## 6. Implementation considerations

- **Where to hook:** Ensure every suppressed diagnostic results in one SuppressionRecord (e.g. in IgnoreUtils call sites or reporter wrapper).
- **SuppressionRecord fields:** rule, file, line; optional: raw comment, prefix (ignore vs tech-debt).
- **Output:** Text summary and/or JSON/CSV for CI.
- **Performance:** Record only when a diagnostic is actually suppressed; avoid hot-path overhead.

---

## 7. Open questions

- Opt-in (e.g. env flag) or always-on with reporting opt-in?
- Distinguish "suppressed by ignore" vs "suppressed by baseline" in reports?
- Integrate with Custom Ignore Prefixes (Discussion #59): record which prefix was used for filtering?
