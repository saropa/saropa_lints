# BUG: `avoid_large_objects_in_state` — Fires on Bounded Collections That Are Reassigned, Not Accumulated

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-08-16
Rule: `avoid_large_objects_in_state`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~59, class at line ~38)
Severity: False positive
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule fires on any `List<`/`Map<`/`Set<`/`Uint8List`/`ByteData`/`ByteBuffer`-typed
field declared in a `State<...>` class, regardless of whether the field
**accumulates** data over the widget's lifetime (the pattern the rule's own
message describes: "grows without limit as data accumulates") or is simply
**reassigned to a fresh, size-bounded collection** on every recompute. The
detection logic never inspects assignment sites — only the field declaration
line's type annotation and a magic-string check on that same declaration
(`// bounded`, `maxSize`, `limit`). A field that is always replaced wholesale,
never appended to, and bounded by the same input the widget already holds a
reference to, produces the same warning as a genuine unbounded accumulator.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_large_objects_in_state'" lib/src/rules/
lib/src/rules/resources/memory_management_rules.dart:59:    'avoid_large_objects_in_state',
```

Registered in `lib/src/rules/all_rules.dart` (barrel export of
`resources/memory_management_rules.dart`) and confirmed present in
`lib/src/tiers.dart` / `lib/tiers/professional.yaml`.

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:59`
**Rule class:** `AvoidLargeObjectsInStateRule` (`memory_management_rules.dart:38`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Minimal reduction of the real hit at
`d:\src\contacts\lib\components\activity\activity_day_grouped_list.dart:56,59,105`:

```dart
class _MyWidgetState extends State<MyWidget> {
  List<DateTime>? _groupValues; // LINT — but should NOT lint (false positive)
  Map<DateTime, List<String>>? _groupedByDate; // LINT — but should NOT lint (false positive)

  void _recompute(Map<DateTime, List<String>> byDate) {
    // Every recompute REPLACES both fields with a fresh collection sized
    // to the current input — never appended to across recomputes.
    _groupValues = byDate.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));
    _groupedByDate = <DateTime, List<String>>{};
    for (final DateTime key in _groupValues!) {
      _groupedByDate![key] = byDate[key]!;
    }
  }
}
```

Both fields are bounded by `byDate`, a value the widget already holds
(typically a `widget.activities`-derived prop) — there is no accumulation
across widget lifetime, no `addAll`/`+=` in a loop that persists between
recomputes, and no growth beyond the caller's own input size.

**Frequency:** Always — fires on every `List`/`Map`/`Set`/`Uint8List`/`ByteData`/`ByteBuffer`
field declaration in a `State` class that lacks the literal substrings
`// bounded`, `maxSize`, or `limit` anywhere in the field's declaration
source, independent of how the field is used elsewhere in the class.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the field is reassigned to a bounded, replaced-not-accumulated collection every recompute |
| **Actual** | `[avoid_large_objects_in_state] Unbounded List, Map, Set, or ByteData field declared in a State class grows without limit as data accumulates...` reported at the field declaration |

---

## AST Context

```
ClassDeclaration (_MyWidgetState, extends State<MyWidget>)
  └─ FieldDeclaration (_groupedByDate)          ← node reported here
      └─ VariableDeclarationList
          └─ TypeAnnotation (Map<DateTime, List<String>>?)  ← only this + declaration-line source checked
  └─ MethodDeclaration (_recompute)
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression (_groupedByDate = <DateTime, List<String>>{})
                  ← never visited by the rule; reassignment sites are ignored entirely
```

---

## Root Cause

`runWithReporter` (`memory_management_rules.dart:78-108`) only visits
`ClassDeclaration` → `FieldDeclaration` nodes. For each field whose type
annotation source contains one of the `_largeTypePatterns` strings
(`List<`, `Map<`, `Set<`, `Uint8List`, `ByteData`, `ByteBuffer`), it checks
whether `member.toSource()` — the **field declaration statement itself**,
not any usage site — contains `// bounded`, `maxSize`, or `limit`. If none
of those substrings appear on the declaration line(s), it reports.

The rule never looks at:
- Assignment expressions elsewhere in the class that reassign the field to a
  fresh collection (as opposed to `addAll`/`+=`/`.add()` in a loop, which is
  the actual accumulator pattern the rule's message describes).
- Whether the field's size is provably bounded by another parameter/prop
  already held by the widget (e.g. derived from `widget.activities`).

So "large object in state" and "unbounded accumulator" are conflated: the
rule's message and doc comment describe the latter ("grows without limit as
data accumulates"), but the implementation detects the former (any large
*type*, regardless of mutation pattern).

### Hypothesis A: Require an accumulating mutation to be present

Only fire when the class contains an `addAll`/`+=`/`.add()`/`.[]=` call site
on the field that is NOT preceded by a full reassignment (`field = ...`) in
the same method — i.e. genuinely detect growth-without-bound, not just
"large-typed field exists."

### Hypothesis B: Suppress when every assignment site replaces the whole collection

Walk assignment expressions targeting the field; if every non-declaration
assignment is a direct `field = <fresh collection literal or transform>`
(never `field!.addAll(...)`, `field![k] = v` in a loop that isn't cleared
first, etc.), treat it as bounded-by-replacement and skip the diagnostic.

---

## Suggested Fix

Extend `runWithReporter` to also visit the class's method bodies for
assignment expressions targeting the flagged field. If every assignment is a
full replacement (`field = <expr>`) and no accumulating mutation
(`.addAll(`, `.add(`, `+=`, indexed-assignment inside a loop without a
preceding clear) is found anywhere in the class, do not report. This keeps
the magic-string escape hatch (`// bounded`, `maxSize`, `limit`) for cases
the heuristic still can't decide, but stops the common "recomputed cache
field" pattern from tripping the rule at all.

---

## Fixture Gap

The fixture at `example*/lib/resources/avoid_large_objects_in_state_fixture.dart`
should include:

1. **Field always reassigned to a fresh, non-accumulating collection in a
   `setState`/recompute method** — expect NO lint.
2. **Field accumulated via `.addAll()`/`.add()` across multiple calls without
   a preceding clear/reassignment** — expect LINT (existing true-positive
   case, should remain covered).
3. **Field reassigned via `..sort()` cascade on a fresh `.toList()`** (the
   exact `_groupValues` pattern) — expect NO lint.

---

## Changes Made

- **`lib/src/rules/resources/memory_management_rules.dart`**: Rewrote `AvoidLargeObjectsInStateRule` accumulation detection to use AST walking (`_FieldMutationVisitor`, a `RecursiveAstVisitor`) instead of string scanning. Added `_isReplacedNotAccumulated()` which walks each method/constructor body independently via the visitor, classifying field mutations as hard accumulation (`.add()`, `.addAll()`, `+=`, self-cascade), soft accumulation (subscript-assignment `field[k] = v`), or full reassignment (`field = <expr>`). Soft accumulation is only treated as unbounded when no full reassignment co-occurs in the same method body — allowing the "reassign to fresh map, then populate in a loop" pattern while still catching `store()` + `reset()` in separate methods.

---

## Tests Added

- **`example/lib/memory_management/avoid_large_objects_in_state_fixture.dart`**: Added 6 new fixture classes:
  - `_bad468__AccumulatedState`: Field accumulated via `.add()` without clear — expects LINT
  - `_bad469__SubscriptGrownState`: Field grown via `cache[k] = v` with unrelated `reset()` — expects LINT
  - `_bad470__CascadeAccumulatedState`: Field accumulated via cascade `..addAll()` — expects LINT
  - `_bad471__SelfReassigningCascadeState`: Self-reassigning cascade `field = field..add(x)` — expects LINT
  - `_good468__RecomputedCacheState`: Fields reassigned wholesale in a recompute method — expects NO LINT
  - `_good469__SortedListState`: Field reassigned via `..sort()` cascade on `.toList()` — expects NO LINT

---

## Finish Report (2026-08-16)

### Defect

`AvoidLargeObjectsInStateRule` flagged any `List<`/`Map<`/`Set<`/`Uint8List`/`ByteData`/`ByteBuffer` field in a `State<>` class regardless of usage pattern. Fields reassigned wholesale to a fresh bounded collection (the common "recomputed cache" pattern) produced the same diagnostic as genuine unbounded accumulators.

### Root Cause

The rule's `runWithReporter` only inspected the field declaration's type annotation and magic-string markers (`// bounded`, `maxSize`, `limit`). It never visited method bodies to determine whether the field was accumulated into or simply replaced.

### Fix

Replaced string-based scanning with AST-walking via `_FieldMutationVisitor` (a `RecursiveAstVisitor`). Each method/constructor body is walked independently, classifying field mutations into three tiers:

- **Hard accumulation** (`.add()`, `.addAll()`, `.insert()`, `.insertAll()`, `.addEntries()`, `.putIfAbsent()`, `+=`, `??=`, self-reassigning cascade `field = field..add(x)`) — always indicates unbounded growth, diagnostic fires regardless of other usage.
- **Soft accumulation** (`field[k] = v` subscript-assignment) — fires only when no full reassignment co-occurs in the same method body. Allows the "reassign to fresh map, then populate in a loop" pattern while catching `store()` + `reset()` split across methods.
- **Full reassignment** (`field = <expr>`) — replaces the collection wholesale. When present with no accumulation, the diagnostic is suppressed.

The AST approach resolves structural gaps the string scanner had: cascade vs. single-dot (`.add(` vs `..add(`), self-reassigning cascades (`field = field..add(x)`), field names inside string literals or comments, and shadowed local variable names.

### Known Limitations

- **No cross-method control-flow analysis.** The per-method heuristic cannot detect that `store()` always calls `reset()` first, or that a `build()` method always calls `_recompute()` before reading the field. This is conservative: mutations in separate methods are treated as independent.
- **SimpleIdentifier name matching, not element resolution.** The visitor checks `SimpleIdentifier.name` against field names rather than resolving to the `FieldElement`. A local variable shadowing a field name in the same method could produce a false positive or negative. Risk is low: private field names (prefixed with `_`) rarely shadow locals.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: resolved via `d:\src\contacts\pubspec.yaml` (pub cache; local checkout at `d:\src\saropa_lints` had an unrelated pre-existing compile error at report time, not used for detection)
- Dart SDK version: (not captured this session)
- custom_lint version: (not captured this session)
- Triggering project/file: `d:\src\contacts\lib\components\activity\activity_day_grouped_list.dart:56,59` (fields), reassignment at line 105
