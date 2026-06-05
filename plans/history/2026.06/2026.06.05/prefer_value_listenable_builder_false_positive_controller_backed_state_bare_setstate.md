# BUG: `prefer_value_listenable_builder` — flags a multi-trigger State whose other state lives in a `final` controller + bare `setState`

**Status: Fixed**

Created: 2026-06-05
Rule: `prefer_value_listenable_builder`
File: `lib/src/rules/core/performance_rules.dart` (line ~1434)
Severity: False positive / Medium (forces an `ignore_for_file`; the suggested single-notifier refactor cannot model the widget)
Rule version: v4

---

## Summary

The rule counts only non-`final` fields to decide "simple single-value state". A screen State holds its scan-summary in a single non-final field (`_lastScanSummary`) but ALSO rebuilds for search filtering, whose state lives in a `final TextEditingController` and is republished via a bare `setState()` (no field assignment) in the search `onChanged`. The rule sees one non-final field + one `setState` and reports "single-value state", but the widget has two independent rebuild triggers. A single `ValueListenableBuilder<T>` cannot model both, and the summary banner sits inside a `spacing:`-ed `Column` where an always-present `ValueListenableBuilder` slot would inject a spurious gap.

This is the same root cause as `prefer_value_listenable_builder_false_positive_inplace_mutation_final_collection` (the rule only counts non-final fields and misses other live state) but a distinct concrete trigger: state held in a `final` controller plus a *bare* `setState()` used purely as a rebuild signal.

---

## Attribution Evidence

```bash
grep -rn "'prefer_value_listenable_builder'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:1451:    'prefer_value_listenable_builder',

grep -rn "'prefer_value_listenable_builder'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1451`
**Rule class:** `PreferValueListenableBuilderRule` — registered in `lib/saropa_lints.dart:1270`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#4`

---

## Reproducer

```dart
class _ScreenState extends State<Screen> {
  final TextEditingController _textController = TextEditingController(); // final → not counted; backs search state
  ScanSummary? _lastScanSummary;                                        // the ONLY counted field → stateFieldCount = 1

  void _setStateSafe([VoidCallback? cb]) {
    if (mounted) setState(() => cb?.call());                            // the ONLY literal setState → count = 1
  }

  Widget _searchField() => TextField(
    controller: _textController,
    onChanged: (_) => _setStateSafe(), // BARE rebuild for search — no field assignment, reads _textController.text
  );

  void _onScan(ScanSummary s) => _setStateSafe(() => _lastScanSummary = s);

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: <Widget>[
        if (_lastScanSummary != null) _Banner(summary: _lastScanSummary!), // collection-if; absent when null (no gap)
        _searchField(),
        _filteredList(_textController.text),                              // rebuilt by the bare setState above
      ],
    );
  }
}
// LINT on the State class name — but it is NOT simple single-value state.
```

**Frequency:** Always, when a State has exactly one non-final field, 1–3 `setState` calls, AND additional rebuild-driving state held in a `final` controller/listenable that the bare `setState` republishes.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the widget rebuilds for two independent reasons (search filter + scan summary); it is not single-value state |
| **Actual** | `[prefer_value_listenable_builder]` reported on the State class name token |

---

## AST Context

```
ClassDeclaration (_ScreenState)        ← reported here (nameToken)
  ├─ FieldDeclaration final TextEditingController _textController   (final → NOT counted, but backs real rebuild state)
  ├─ FieldDeclaration ScanSummary? _lastScanSummary                (COUNTED: stateFieldCount = 1)
  └─ MethodDeclaration _setStateSafe → setState(...)               (COUNTED: setStateCallCount = 1)
        ↑ also invoked bare from the search onChanged as a pure rebuild signal
```

---

## Root Cause

In the field-counting loop (`performance_rules.dart` ~1493-1518) only non-static, non-`final` fields increment `stateFieldCount`. State held in a `final` controller/listenable is invisible to the count even though a bare `setState()` republishes it on change. With `stateFieldCount == 1` and `1 <= setStateCallCount <= 3`, the gate at ~1530-1532 fires.

The heuristic equates "one non-final field" with "one unit of state", but a `final` controller + a bare rebuild `setState()` is a second, independent state the count cannot see — exactly the blind spot already recorded for in-place-mutated `final` collections.

### Hypothesis A: a bare `setState(() {})` / `setState` with an empty-effect callback signals external (non-field) state

If any counted `setState` does not assign the single non-final field (e.g. it is invoked with no callback, or its callback assigns nothing), the State is republishing state that lives elsewhere (a controller, a parent value). Treat that as disqualifying, the same way `mutatesFinalField` already bails.

### Hypothesis B: a `final` controller/`Listenable`/`ChangeNotifier` field counts as additional state

Extend the field scan so a `final` field whose type is a `TextEditingController` / `ScrollController` / `Listenable` / `ChangeNotifier` (read in `build`) counts toward the state tally, lifting the State above the single-value threshold.

---

## Suggested Fix

Prefer Hypothesis A — it is local to the existing `_SetStateCounterVisitor`: record whether each counted `setState` actually assigns the lone non-final field; if a `setState` exists that assigns no field (bare rebuild signal), bail out like the `mutatesFinalField` guard at ~1526.

---

## Fixture Gap

The fixture should include:

1. **One non-final field + a `final` controller + a bare `setState()` rebuild in onChanged** — expect NO lint (this bug).
2. **One non-final field assigned by every `setState`, no controller-backed rebuild** — expect LINT (genuine single-value stays flagged).
3. **One non-final field + a bare `setState()` with no other state** — decide intended behavior; document.

---

## Environment

- saropa_lints version: 13.12.0
- Triggering project/file: `d:\src\contacts\lib\views\contact\contact_audit_issues_screen.dart:102`

---

## Resolution (2026-06-05)

Implemented **Hypothesis A** in `lib/src/rules/core/performance_rules.dart`.

`_SetStateCounterVisitor` now collects each `setState` callback's assignments
into a per-invocation set; when that set is empty the callback assigned no
non-final field, so it is a **bare rebuild signal** and fires a new
`onBareSetState` callback. `runWithReporter` bails (`if (hasBareSetState)
return;`) right after the existing `mutatesFinalField` guard. A bare
`setState(() {})` means the widget rebuilds for state that lives outside the
counted fields (a `final` controller/`Listenable`, a parent value) — a second
independent trigger a single `ValueListenableBuilder<T>` cannot model. This
also covers the common `setState(() => cb?.call())` safe-setState wrapper from
the real-world file (its literal `setState` assigns no field).

The earlier companion-field guard (`reassignedInSetState`) already suppressed
the *wrapper* form by coincidence (the field is assigned only through the
wrapper, never directly in a literal `setState`), but the **direct** form —
`setState(() => _field = x)` for the summary plus a bare `setState(() {})` for
the controller-backed search — still fired. This fix closes that.

Verified with the scan CLI: the direct-setState reproducer went from 1 hit to
0; a genuine single-value `State` (`setState(() => _count++)`) still fires.

**Fixture:** `example/lib/performance/prefer_value_listenable_builder_fixture.dart`
— added `_good790ControllerBackedBareSetStateState` (direct bare `setState`) and
`_good790SafeSetStateWrapperState` (wrapper form), both expecting no lint. The
existing `_bad790*` single-value cases remain `expect_lint`.

**Downstream:** the `// ignore_for_file: prefer_value_listenable_builder` at the
top of `contact_audit_issues_screen.dart` can be removed once the fix ships.

## Finish Report (2026-06-05)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Change:** Added a bare-`setState` guard to `PreferValueListenableBuilderRule`.
`_SetStateCounterVisitor` now collects each `setState` callback's assignments
into a per-invocation set; an empty set means the callback assigned no non-final
field (a bare rebuild signal) and fires `onBareSetState`. `runWithReporter`
bails (`if (hasBareSetState) return;`) immediately after the existing
`mutatesFinalField` guard. A bare rebuild means the widget rebuilds for state
held outside the counted fields (a `final` controller/`Listenable`, a parent
value) — a second trigger a single `ValueListenableBuilder<T>` cannot model.

**Files changed:**
- `lib/src/rules/core/performance_rules.dart` — new `hasBareSetState` flag +
  `onBareSetState` callback; per-invocation assignment set in the visitor.
- `example/lib/performance/prefer_value_listenable_builder_fixture.dart` —
  added `_good790ControllerBackedBareSetStateState` (direct bare `setState`) and
  `_good790SafeSetStateWrapperState` (wrapper form), both no-lint.
- `CHANGELOG.md` — bullet under `[Unreleased]` → Fixed; overview extended.

**Verification:**
- Scan CLI (against a temp project, since `example/` is excluded from scan):
  direct bare-`setState` reproducer 1 → 0 hits; wrapper form 0 hits; genuine
  single-value `setState(() => _count++)` still fires.
- `dart analyze lib/src/rules/core/performance_rules.dart` — No issues found.
- `dart test test/rules/core/performance_rules_test.dart` — 99/99 passed
  (instantiation pin + fixture-exists checks; rule constructor unchanged).

**Outstanding:** none. Downstream `// ignore_for_file` in the contacts repo
(another project — not edited) can be removed once this ships.
