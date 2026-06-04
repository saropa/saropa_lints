# BUG: `prefer_value_listenable_builder` — false positive when a second state is an in-place-mutated `final` collection

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-04
Rule: `prefer_value_listenable_builder`
File: `lib/src/rules/core/performance_rules.dart` (class `PreferValueListenableBuilderRule`, line ~1434; detection ~1463-1505; reports at line 1504)
Severity: Medium — suggests a refactor (single `ValueListenableBuilder`) that cannot express the widget's actual state, and the suggestion cannot be suppressed with a line-level `// ignore:` (see related suppression bug), so it forces `// ignore_for_file:`.
Rule version: v4 | Since: ≤ v13.11.11 | Updated: —

---

## Summary

The rule's "single-value state" heuristic counts only **non-`final` fields** (`stateFieldCount`). A `State` that has one non-final field PLUS a `final` collection field that is **mutated in place** and republished via `setState` is genuinely two-state, but the rule counts it as one and suggests `ValueListenableBuilder`. Converting to a single notifier drops the second state. False positive.

---

## Attribution Evidence

```text
# Rule IS defined here
lib\src\rules\core\performance_rules.dart:1451:    'prefer_value_listenable_builder',
# Detection: counts non-final fields, then reports
lib\src\rules\core\performance_rules.dart:1478:          if (!member.isStatic && !member.fields.isFinal) {
lib\src\rules\core\performance_rules.dart:1501:      if (stateFieldCount == 1 &&
lib\src\rules\core\performance_rules.dart:1504:        reporter.atToken(node.nameToken, code);
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1434` (`PreferValueListenableBuilderRule`), registered in `lib/src/rules/all_rules.dart`.
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`, owner `_generated_diagnostic_collection_name_#2`, code `prefer_value_listenable_builder`.

---

## Reproducer

```dart
class _PickerState<T extends Object> extends State<_Picker<T>> { // LINT — but two-state, FP
  // Counted by the rule (non-final). 1 of the rule's "state fields".
  List<T> _filtered = <T>[];

  // NOT counted (field is `final`), yet it is live mutable state: the LIST
  // is mutated in place and the change is published via setState below.
  late final List<T> _selected = <T>[];

  void _onSearch() => setState(() => _filtered = _recompute()); // setState #1
  void _toggle(T v) => setState(() {                            // setState #2
    _selected.contains(v) ? _selected.remove(v) : _selected.add(v);
  });

  List<T> _recompute() => _filtered;

  @override
  Widget build(BuildContext context) {
    // BOTH states feed the same rows: _filtered drives item set,
    // _selected drives each row's checkmark/color. A single
    // ValueListenableBuilder<List<T>> cannot express both.
    return const SizedBox.shrink();
  }
}
```

Counts the rule computes: `stateFieldCount == 1` (only `_filtered`; `_selected` excluded because `final`), `setStateCallCount == 2` → fires.

**Frequency:** Always, for a `State` with exactly one non-final field + 1–3 setState calls, even when other `final` collection/object fields are mutated in place and republished via setState.

Real-world site (downstream `saropa/contacts`): `lib/components/contact/culture/culture_multi_select_dialog.dart:82` (`_CultureMultiSelectEditorState`) — `_filtered` (non-final, reassigned on search) + `_selected` (`late final List`, mutated in place on toggle), 2 setState calls.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the widget has two independent mutable states driving rebuilds; it is not "simple single-value state." |
| **Actual** | `[prefer_value_listenable_builder]` reported on the class name; suggests replacing setState with a single `ValueNotifier` + `ValueListenableBuilder`. |

---

## AST Context

```
ClassDeclaration (_CultureMultiSelectEditorState)        ← reported on node.nameToken
  ├─ FieldDeclaration  late final List<T> _selected      ← final → NOT counted (but mutated in place)
  ├─ FieldDeclaration  late final List<T> _sorted        ← final → NOT counted
  ├─ FieldDeclaration  List<T> _filtered = []            ← non-final → stateFieldCount = 1
  ├─ MethodDeclaration _onSearchChanged → setState(...)  ← setStateCallCount++
  └─ MethodDeclaration _toggle → setState(... _selected mutate ...) ← setStateCallCount++
```

---

## Root Cause

`runWithReporter` (`performance_rules.dart:1476-1505`) tallies `stateFieldCount` only for fields where `!member.isStatic && !member.fields.isFinal` (line 1478). A `final` field whose **referenced object is mutated in place** (`List.add`/`remove`, `Map[...]=`, `Set.add`, custom mutable model) is live UI state when its change is published via `setState`, but `isFinal` excludes it. The rule therefore undercounts state and treats a multi-state widget as single-value.

The `setState` bodies already reveal the missed state: a `setState` that mutates a `final` collection (rather than reassigning a non-final field) is a strong signal of additional state the field-count heuristic can't see.

---

## Suggested Fix

Tighten the "single-value" precondition so an in-place-mutated `final` collection counts as state. Options (maintainer's call):

1. **Count `final` collection/notifier fields that are mutated in a `setState` body.** During the existing `_SetStateCounterVisitor` pass, also record identifiers that are the target of a mutating call (`.add`/`.remove`/`.clear`/`[index]=`/`.removeWhere`/…) or an index-assignment. If any such target is a `final` field of the class, treat the widget as multi-state and do NOT fire. This directly matches the `_selected.add/remove` idiom.
2. **Cheaper, looser guard:** if any `setState` body mutates a `final List`/`Map`/`Set` field (syntactic check on the invocation target's declared field), bail out. Less precise but kills this FP class with little code.
3. At minimum, document that the rule only models reassigned non-final fields, and that in-place mutation of `final` collections is a known blind spot, so the suggestion is advisory.

Note the related suppression bug: even when a developer correctly judges this an FP, a line-level `// ignore: prefer_value_listenable_builder` does not work because the rule reports via `reporter.atToken(node.nameToken)` — see `infra_ignore_comment_not_honored_attoken_declaration_name.md`. Until that lands, the only working suppression is `// ignore_for_file:`.

---

## Fixture Gap

Add to the rule's fixture:

1. **One non-final field + a `final` List mutated in place via setState** — expect NO lint (this FP).
2. **One non-final field + 1–3 setState that only reassign it** — expect LINT (true positive baseline).
3. **One non-final field + a `final` Map index-assigned (`m[k]=v`) in setState** — expect NO lint.
4. **Single non-final field, single setState, no other mutable state** — expect LINT (control).

---

## Changes Made

Implemented Suggested Fix option 1 (the precise variant) in `lib/src/rules/core/performance_rules.dart`:

- `runWithReporter` now does a first pass collecting the names of all non-static `final` fields (`finalFieldNames`) before walking method bodies, since declaration order is not guaranteed.
- `_SetStateCounterVisitor` takes the `finalFieldNames` set plus an `onFinalFieldMutated` callback. When it hits a `setState(...)` call it walks the callback argument with a new `_FinalFieldMutationVisitor`.
- `_FinalFieldMutationVisitor` flags two patterns against a `final` field name: a mutating method call (`add`/`addAll`/`remove`/`removeWhere`/`clear`/`sort`/`putIfAbsent`/… — read-only members like `contains` are intentionally excluded) and an index-assignment `field[k] = v` (`IndexExpression` on the LHS of an `AssignmentExpression`).
- If any in-place mutation of a `final` field is seen inside a `setState` body, the rule returns early (treats the widget as multi-state) and does not report. A `final` collection only *read* in `setState` does not suppress the lint.

---

## Tests Added

`example/lib/performance/prefer_value_listenable_builder_fixture.dart`:

1. `_good790InPlaceListState` — one non-final field + `final List` mutated via `.add`/`.remove` in `setState` → expect NO lint (the FP).
2. `_good790IndexAssignMapState` — one non-final field + `final Map` index-assigned (`m[k] = v`) in `setState` → expect NO lint.
3. `_bad790ReadOnlyFinalState` — one non-final field + `final List` only *read* in two `setState` calls → expect LINT (guard does not over-suppress).
4. `_bad790__MyState` (pre-existing) — single non-final field, single `setState` → expect LINT (control).

Verified via `dart run saropa_lints scan` against a temp copy (example dirs are excluded from the scanner): lints fired only on cases 3 and 4; cases 1 and 2 produced none. `dart analyze` clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.11.11 (path/published parity; downstream `contacts` pins `^13.11.11`)
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: n/a — runs as a native `analysis_server_plugin`
- Triggering project/file: `saropa/contacts` — `lib/components/contact/culture/culture_multi_select_dialog.dart:82`

---

## Related

- `infra_ignore_comment_not_honored_attoken_declaration_name.md` — why the line-level `// ignore:` for this rule does not suppress (rule reports via `atToken(node.nameToken)`).

---

## Finish Report (2026-06-04)



**Scope:** (A) Dart lint rule / analyzer plugin.

### What changed (core logic)

`lib/src/rules/core/performance_rules.dart`, `PreferValueListenableBuilderRule.runWithReporter`:

- Added a first pass collecting the names of every non-static `final` field (`finalFieldNames`) before any method body is walked — declaration order between fields and methods is not guaranteed, so the names must be known up front.
- `_SetStateCounterVisitor` now also receives `finalFieldNames` and an `onFinalFieldMutated` callback. On each `setState(...)` call it walks the callback argument with a new `_FinalFieldMutationVisitor`.
- `_FinalFieldMutationVisitor` flags, against a `final` field name: (a) a mutating collection method call (`add`/`addAll`/`insert`/`remove`/`removeWhere`/`clear`/`sort`/`putIfAbsent`/… — read-only members like `contains` are deliberately excluded), and (b) an index-assignment `field[k] = v` (`IndexExpression` LHS of an `AssignmentExpression`).
- If any in-place mutation of a `final` field is seen inside a `setState` body, the rule returns early (multi-state) and does not report. The `stateFieldCount == 1 && 1..3 setState` condition is otherwise unchanged.

### Why

A `final` collection mutated in place and republished via `setState` is a second, independent state. `ValueListenableBuilder<T>` exposes exactly one value, so the rule's single-notifier suggestion would silently drop that state — a false positive that could not be line-suppressed (the rule reports on `node.nameToken`; see related `infra_*` bug).

### Tests

`example/lib/performance/prefer_value_listenable_builder_fixture.dart` gained:

- `_good790InPlaceListState` — non-final field + `final List` mutated via `.add`/`.remove` in `setState` → NO lint (the FP).
- `_good790IndexAssignMapState` — non-final field + `final Map` index-assigned in `setState` → NO lint.
- `_bad790ReadOnlyFinalState` — non-final field + `final List` only *read* in two `setState` calls → LINT (guard does not over-suppress).
- `_bad790__MyState` (pre-existing control) — single non-final field, single `setState` → LINT.

Verification: `dart run saropa_lints scan` against a temp copy (the `example/` tree is excluded from the scanner) reported the rule only on `_bad790__MyState` and `_bad790ReadOnlyFinalState`; the two new GOOD cases produced no diagnostic. `dart test test/rules/core/performance_rules_test.dart` → 99 passed. `dart analyze --fatal-infos lib` → No issues found.

### Outstanding

None. The line-level suppression limitation is tracked separately in `infra_ignore_comment_not_honored_attoken_declaration_name.md` and is out of scope here.
