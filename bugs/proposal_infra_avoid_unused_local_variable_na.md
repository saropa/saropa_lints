# PROPOSAL: DCM `avoid-unused-local-variable` — Declined, Duplicates Built-in Analyzer Lint

**Status: Declined**

Created: 2026-09-02
Type: Tooling / Infrastructure

---

## Summary

DCM's `avoid-unused-local-variable` flags an unused local variable. Dart's own analyzer already ships this exact check as the built-in `unused_local_variable` lint, enabled via any standard `analysis_options.yaml` (it's part of `core`/`recommended`/`flutter_lints`/`very_good_analysis` presets and Dart's own default lint set). Implementing a saropa-side duplicate would produce a redundant second diagnostic for the same code smell.

**Gap status:** DCM `avoid-unused-local-variable` is classified N/A/Declined — see Decision section below for why this does not need implementation to be considered resolved.

---

## Motivation

`plans/GAP_ANALYSIS.md` lists `avoid-unused-local-variable` under "DCM proper" TRUE GAPS, structural/code-quality group, already annotated "N/A: covered by Dart analyzer built-in." Confirming against the same file's own VGA (very_good_analysis) audit section (`plans/GAP_ANALYSIS.md`, "VGA — ~206 stock rules"): saropa's own analysis explicitly notes that stock Dart SDK `linter: rules:` entries — including exactly this class of check — live in a separate namespace from saropa's custom `analyzer_plugin` rules, and that "users running saropa_lints still need `flutter_lints` or VGA for stock rule coverage." `unused_local_variable` is one of those stock rules, not a saropa gap.

---

## Detection / Behavior

N/A — not implementing. The Dart analyzer's built-in `unused_local_variable` lint already does this:

```dart
void example() {
  final unused = 5; // Dart analyzer's built-in unused_local_variable already flags this
  print('done');
}
```

Any project with `include: package:flutter_lints/flutter.yaml` (or `package:lints/recommended.yaml`, or VGA) already gets this diagnostic without saropa_lints doing anything.

---

## Proposed Tier

N/A — not implementing.

---

## Edge Cases

N/A — not implementing.

---

## Alternatives Considered

- **Implement anyway for saropa-branded consistency in the Problems panel** — rejected; produces a duplicate diagnostic (two `source` labels for the same violation, one from `dart` and one from `saropa_lints`), which actively confuses triage (see `ISSUE_REPORT_GUIDE.md`'s "Confirm Attribution Before Filing" section — ambiguous overlapping diagnostic sources are a known source of misattributed bug reports).
- **Implement a stricter superset** (e.g. also catching unused variables in patterns the built-in lint misses) — no such gap identified during this investigation; the built-in lint's coverage is comprehensive for this pattern class. If a specific false-negative in the built-in lint is found later, that would justify a narrower, differently-named proposal — not this one.

---

## Decision

**Declined.** Duplicate of Dart analyzer's built-in `unused_local_variable` lint, already available via any standard preset (`flutter_lints`, `lints/recommended`, `very_good_analysis`). Implementing a saropa-side equivalent adds no coverage and risks duplicate/conflicting diagnostics in the Problems panel. Recommend consumers ensure their `analysis_options.yaml` includes a standard lint preset alongside saropa_lints rather than saropa_lints reimplementing stock analyzer behavior.

---

## Implementation Notes

None — no implementation planned.

---

## Commits
