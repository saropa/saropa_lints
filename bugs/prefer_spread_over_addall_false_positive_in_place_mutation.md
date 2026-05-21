# BUG: `prefer_spread_over_addall` — fires on every `addAll`, including in-place mutation with no spread equivalent

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-05-21
Rule: `prefer_spread_over_addall`
File: `lib/src/rules/stylistic/stylistic_null_collection_rules.dart` (line ~600)
Severity: False positive
Rule version: v2 | Since: (unknown) | Updated: (unknown)

---

## Summary

The rule reports **every** method invocation named `addAll`, with zero context analysis. It flags the canonical correct use of `addAll` — mutating an existing collection in place (including `this`) — for which the spread operator has no equivalent, since spread always constructs a *new* collection. It also matches any unrelated user-defined method named `addAll`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_spread_over_addall'" lib/src/rules/
# lib/src/rules/stylistic/stylistic_null_collection_rules.dart:623:    'prefer_spread_over_addall',
```

**Emitter registration:** `lib/src/rules/stylistic/stylistic_null_collection_rules.dart:623`
**Rule class:** `PreferSpreadOverAddAllRule` — registered in `lib/saropa_lints.dart:1061` (`PreferSpreadOverAddAllRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `prefer_spread_over_addall` (via `dart analyze`, ground truth)

---

## Reproducer

Condensed from `saropa_dart_utils/lib/list/unique_list_extensions.dart` (`toUniqueByInPlace`), an extension method that mutates the receiver list in place:

```dart
extension UniqueListExtensions<T> on List<T> {
  void toUniqueByInPlace<E>(KeyExtractor<T, E> keyExtractor) {
    final List<T> uniqueItems = toUniqueBy(keyExtractor);
    clear();
    addAll(uniqueItems); // LINT — but this mutates `this`; spread cannot replace `this`
  }
}
```

The method's contract is to mutate the receiver in place (`void`, paired with `clear()`). `[...this, ...uniqueItems]` would build a new list that is then discarded — there is no way to spread *into* `this`. `clear(); addAll(x)` is the correct idiom.

**Frequency:** Always — the rule flags 100% of `addAll` calls.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when `addAll` mutates an existing collection in place (no receiver to spread into, or the surrounding code is an explicit in-place mutation such as `clear(); addAll(...)`). |
| **Actual** | `[prefer_spread_over_addall] Collection uses addAll() instead of the spread operator…` reported on the `addAll` invocation. |

---

## AST Context

```
MethodDeclaration (toUniqueByInPlace)
  └─ BlockFunctionBody
      └─ Block
          ├─ VariableDeclarationStatement (uniqueItems)
          ├─ ExpressionStatement
          │    └─ MethodInvocation (clear)
          └─ ExpressionStatement
               └─ MethodInvocation (addAll)   ← node reported here; target is implicit `this`
```

The invocation has no explicit `target` (it is `this.addAll(...)`), so there is no expression that could become a spread source.

---

## Root Cause

`PreferSpreadOverAddAllRule.runWithReporter` (lines ~630-640) reports unconditionally:

```dart
context.addMethodInvocation((node) {
  if (node.methodName.name == 'addAll') {
    reporter.atNode(node);
  }
});
```

There is no check for any of:

1. **Receiver presence.** `node.target == null` (implicit `this`) means there is nothing to spread into.
2. **In-place mutation intent.** The spread operator only substitutes for `addAll` when *constructing* a new collection. `addAll` on an existing collection that continues to be used (the receiver is not a throwaway literal) is precisely what `addAll` is for; the rewrite is not equivalent.
3. **Receiver type.** The rule matches the *name* `addAll` on any type, including user-defined classes with an `addAll` method that are not `List`/`Set`/`Map`/`Queue`.

The suggested replacement in the rule's own `correctionMessage` (`[...list1, ...list2]`) is an *expression* that yields a new list — it cannot express "mutate the existing collection," so applying it to in-place mutation changes behavior.

---

## Suggested Fix

In `PreferSpreadOverAddAllRule` (line ~635), gate the report:

1. **Skip implicit-`this` / no-target receivers:**
   ```dart
   final Expression? target = node.realTarget;
   if (target == null) return; // mutating `this` in place — no spread source
   ```
2. **Only flag when building a fresh collection.** Report when the receiver is a collection *literal* or a freshly-allocated list (e.g. `<T>[]..addAll(x)`, `List.of(a)..addAll(b)`) where a spread literal is the natural form. Do not flag when the receiver is a previously-declared variable being mutated for later use.
3. **Confirm the receiver type** resolves to `List`/`Set`/`Map`/`Iterable`-mutable via `target.staticType` (use `isDartCoreList` etc.) rather than matching the method name alone, to avoid flagging unrelated `addAll` methods.

Step 1 alone removes the in-place `this` false positives.

---

## Fixture Gap

`example/lib/stylistic_null_collection/prefer_spread_over_addall_fixture.dart` should add NO-LINT cases:

1. **In-place mutation of `this`** — an extension/instance method calling `clear(); addAll(items);` → expect **NO** lint.
2. **In-place mutation of an existing variable** — `final acc = <int>[]; … acc.addAll(more); return acc;` where `acc` is used after → expect **NO** lint (or treat per chosen policy).
3. **Unrelated `addAll`** — a user class `class Bag { void addAll(x) {} }` then `bag.addAll(x)` → expect **NO** lint.
4. **Positive control** — `someList.addAll([3, 4]);` building onto a literal/fresh list → expect **LINT** (matches the rule's `exampleBad`).

---

## Changes Made

<!-- Not yet fixed. Filed from downstream corpus saropa_dart_utils. -->

---

## Tests Added

<!-- Pending fix. -->

---

## Commits

<!-- Pending fix. -->

---

## Environment

- saropa_lints version: 13.10.3
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: (as pinned by saropa_lints 13.10.3)
- Triggering project/file: `saropa_dart_utils` — `lib/list/unique_list_extensions.dart:73` (verified via `dart analyze`)
