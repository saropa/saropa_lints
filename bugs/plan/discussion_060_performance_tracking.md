# Discussion: Performance Tracking (Measure rule execution time for optimization)

**Source:** [GitHub Discussion #60](https://github.com/saropa/saropa_lints/discussions/60)  
**Priority:** Medium  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Measure rule execution time to identify slow rules that impact analysis performance.

---

## 2. Current state in saropa_lints

- **RuleTimingTracker** in `lib/src/saropa_lint_rule.dart` already provides:
  - Per-rule cumulative time, call count, average time; `sortedTimings` and `RuleTimingRecord`.
  - **SAROPA_LINTS_PROFILE:** when set, timing is recorded; rules over 10 ms are logged.
  - **SAROPA_LINTS_DEFER / SAROPA_LINTS_DEFERRED:** rules over 50 ms can be deferred or run only in deferred pass.
  - **ReportWriter:** with SAROPA_LINTS_REPORT=true, writes timing report and slow rules report.
- So performance tracking is largely implemented; the enhancement is to stabilize the report format and document it.

---

## 3. Proposed design (from Discussion #60)

```dart
abstract class SaropaLintRule extends DartLintRule {
  static final Map<String, Duration> executionTimes = {};
}
// Output: avoid_excessive_widget_depth: 2.3s (needs optimization!); require_dispose: 0.1s
```

- This matches RuleTimingTracker’s map and summary output. Remaining work: document env vars and optionally expose a stable JSON/API for CI.

---

## 4. Use cases

- Optimize slow rules; move very slow rules to higher tiers or defer.
- CI: detect analysis time regressions and which rule regressed.
- User summary: show slow rules so users can disable or defer.

---

## 5. Research and prior art

- ESLint: no built-in per-rule timing. Roslyn: profiled via IDE. saropa_lints’ implementation is already strong.

---

## 6. Implementation considerations

- Keep timing opt-in (SAROPA_LINTS_PROFILE or SAROPA_LINTS_REPORT) to avoid overhead.
- Standardize report format (e.g. JSON: ruleName, totalMs, callCount, avgMs) for CI.
- Document SAROPA_LINTS_PROFILE, SAROPA_LINTS_REPORT, SAROPA_LINTS_DEFER, SAROPA_LINTS_DEFERRED in README.

---

## 7. Open questions

- Print a short timing summary (top 5 slow) in default run?
- Expose RuleTimingTracker via public API for IDE/init?
- Document all four env vars in one place.
