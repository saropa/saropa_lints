# BUG: `avoid_large_list_copy` — fires on structurally-required `.toList()` that is a cascade target or wrapped in an expression

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-05-21
Rule: `avoid_large_list_copy`
File: `lib/src/rules/core/performance_rules.dart` (line ~1841)
Severity: False positive
Rule version: v4 | Since: (unknown) | Updated: (unknown)

---

## Summary

The rule's own message and fixtures state that "structurally-required `.toList()`" is exempt, and `_isToListRequired` implements that exemption. But the exemption only inspects the **immediate parent** node and has no case for `CascadeExpression`. So `values.map(...).toList()..sort()` — where `.toList()` is the cascade target and `sort()` is a List-only method — is flagged even though a concrete `List` is unavoidable. The same gap flags `.toList()` nested in a `ConditionalExpression` or string interpolation that is ultimately assigned/returned.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_large_list_copy'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:1858:    'avoid_large_list_copy',
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1858`
**Rule class:** `AvoidLargeListCopyRule` — registered in `lib/saropa_lints.dart:792` (`AvoidLargeListCopyRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `avoid_large_list_copy` (via `dart analyze`, ground truth)

---

## Reproducer

Condensed from `saropa_dart_utils/lib/num/num_stats_utils.dart`:

```dart
double? median(Iterable<num> values) {
  // LINT — but a concrete, sorted, indexable List is required here.
  final List<double> list = values.map((num n) => n.toDouble()).toList()..sort();
  if (list.isEmpty) return null;
  final int mid = list.length ~/ 2;
  if (list.length.isOdd) return list[mid];
  return (list[mid - 1] + list[mid]) / 2; // random access requires List
}
```

`sort()` does not exist on `Iterable`; the `.toList()` is mandatory. There is no lazy alternative.

**Frequency:** Always, whenever `.where/.map/.expand/.take/.skip(...).toList()` is followed by a cascade (`..sort()`, `..shuffle()`, `..add(...)`), or is wrapped in a `ConditionalExpression` / interpolation that is then assigned or returned.

### Other real-world instances (saropa_dart_utils)

- **Cascade target** (`..sort()`): `num/num_stats_utils.dart:25` and `:34` (median/percentile), `parsing/canonicalize_json_utils.dart:9` (sorted keys).
- **Wrapped in a `ConditionalExpression` assigned to a typed `List`**: `string/diff_render_utils.dart:55-56` — `raw.endsWith('\n') ? raw…split('\n').map(...).toList() : raw.split('\n').map(...).toList()` assigned to `final List<String> lines`, later indexed (`lines[lines.length - 1]`).
- **Bounded `take(N).toList()` inside interpolation**: `testing/debug_utils.dart:25` — `'${list.take(maxItems).toList()}... '`. `take(maxItems)` is bounded, so it is never a "large" copy; also the immediate parent is an `InterpolationExpression`, which the exemption does not handle.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the `.toList()` result is structurally required (cascade target needing a List-only method; assigned/returned via a wrapper). |
| **Actual** | `[avoid_large_list_copy] List.from() and toList() allocate a new list…` reported on `.toList()`. |

---

## AST Context

For `values.map(...).toList()..sort()`:

```
VariableDeclaration (list)
  └─ CascadeExpression                       ← parent of the .toList() node
      ├─ target: MethodInvocation (.toList)  ← node reported here
      │    └─ target: MethodInvocation (.map)
      └─ cascadeSections: [ MethodInvocation (..sort) ]
```

`_isToListRequired` receives the `.toList()` `MethodInvocation` and reads `node.parent`, which is a `CascadeExpression` — not any of the node types it checks — so it returns `false` (not required) and the rule reports.

For the ternary case the parent is a `ConditionalExpression`; for the interpolation case it is an `InterpolationExpression`. Neither is handled.

---

## Root Cause

`AvoidLargeListCopyRule._isToListRequired` (lines ~1911-1932) only examines the single immediate parent:

```dart
static bool _isToListRequired(MethodInvocation node) {
  final AstNode? parent = node.parent;
  if (parent is ReturnStatement) return true;
  if (parent is ExpressionFunctionBody) return true;
  if (parent is VariableDeclaration) return true;
  if (parent is AssignmentExpression) return true;
  if (parent is MethodInvocation && parent.target == node) return true; // chain
  if (parent is ArgumentList) return true;
  return false;
}
```

Gaps:

1. **No `CascadeExpression` case.** When `.toList()` is the target of a cascade, the cascade sections (`..sort()`, `..shuffle()`, `..add()`) are List/`mutable`-only operations — a concrete List is required. This is morally identical to the existing "method chain target" case (`parent is MethodInvocation && parent.target == node`) but for cascades.
2. **No unwrapping of transparent wrappers.** A `.toList()` inside a `ConditionalExpression`, `ParenthesizedExpression`, or `InterpolationExpression` whose enclosing context is a `VariableDeclaration`/`ReturnStatement`/`ArgumentList` is still required, but the single-parent check stops at the wrapper.
3. **`take(N)` is treated as unbounded.** `take`/`skip` produce bounded results; flagging `take(maxItems).toList()` as a "large" copy contradicts the rule's intent (memory pressure from large collections).

---

## Suggested Fix

In `_isToListRequired` (line ~1911):

1. **Add a cascade case:**
   ```dart
   // .toList() is the target of a cascade (..sort(), ..shuffle(), ..add()) —
   // those mutating List APIs do not exist on Iterable, so a List is required.
   if (parent is CascadeExpression && parent.target == node) return true;
   ```
2. **Walk through transparent wrappers** before deciding: climb past `ParenthesizedExpression`, `ConditionalExpression`, `InterpolationExpression`, and `CascadeExpression` to the nearest semantically-meaningful ancestor, then apply the existing checks.
3. **(Optional) Exempt bounded sources.** If the receiver chain begins with `take(...)` / `skip(...)` over a non-growing source, suppress — the copy is bounded by construction.

The cascade case (step 1) alone resolves the `..sort()` instances, which are the most common.

---

## Fixture Gap

`example/lib/performance/avoid_large_list_copy_fixture.dart` covers return-statement and variable-assignment exemptions but not cascade/wrapped contexts. Add NO-LINT cases:

1. **Cascade target** — `final s = list.map((e) => e).toList()..sort();` → expect **NO** lint.
2. **Conditional expression assigned to a typed List** — `final List<int> r = cond ? a.where(p).toList() : b.where(p).toList();` → expect **NO** lint.
3. **`take(N).toList()`** — `final preview = items.take(10).toList();` → expect **NO** lint (bounded).
4. **Positive control** — `someList.where(p).toList();` as a bare expression statement (result discarded) → expect **LINT**.

---

## Changes Made

`lib/src/rules/core/performance_rules.dart` (`AvoidLargeListCopyRule`):

1. **Dropped `take` from the lazy-chain triggers.** `take(N)` caps the result at N elements, so `take(...).toList()` is bounded by construction and is never a "large" copy — it no longer fires regardless of context (cascade, interpolation, or discarded). `skip(N)` keeps the potentially large tail, so it stays a trigger.
2. **Rewrote `_isToListRequired` to climb transparent wrappers and recognize cascades.** It now walks up through `ParenthesizedExpression` and `ConditionalExpression` to the nearest semantically meaningful ancestor before applying the existing required-context checks, and treats a `.toList()` (or wrapper around it) that is the *target* of a `CascadeExpression` as required — the cascade sections (`..sort()`, `..shuffle()`, `..add()`) are List-only mutators absent from `Iterable`.

Net effect: the cascade `..sort()` case, the ternary-assigned-to-typed-`List` case, and both `take(N)` cases (discarded and interpolated) stop firing; a bare lazy chain whose result is discarded still fires.

---

## Tests Added

`example/lib/performance/avoid_large_list_copy_fixture.dart` — added four NO-LINT cases (`_good794e` cascade target, `_good794f` ternary→typed List, `_good794g` bounded `take`) and one positive control (`_bad794b` bare discarded lazy chain → `expect_lint`).

Verified with the in-repo standalone scanner against a file holding all reproducer shapes (cascade median, ternary, bounded `take`, `take` in interpolation, bare discarded chain, return): only the bare discarded chain reports `avoid_large_list_copy`; every structurally-required case is clean. `dart analyze lib` → no issues.

---

## Commits

<!-- Filled at commit time. -->

---

## Environment

- saropa_lints version: 13.10.3
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: (as pinned by saropa_lints 13.10.3)
- Triggering project/file: `saropa_dart_utils` — `lib/num/num_stats_utils.dart:25`, `:34`; `lib/parsing/canonicalize_json_utils.dart:9`; `lib/string/diff_render_utils.dart:55-56`; `lib/testing/debug_utils.dart:25` (verified via `dart analyze`)
