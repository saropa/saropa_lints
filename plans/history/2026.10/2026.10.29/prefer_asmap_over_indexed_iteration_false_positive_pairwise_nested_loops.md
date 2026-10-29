# BUG: `prefer_asmap_over_indexed_iteration` — Pairwise Combination Loops (Inner Start Depends On Outer Index)

**Status: Open**

Created: 2026-10-29
Rule: `prefer_asmap_over_indexed_iteration`
File: `lib/src/rules/data/collection_rules.dart (line ~2739)`
Severity: False positive

---

## Summary

The rule reports both loops of an unordered-pairs scan (`for i ... for j = i + 1 ...`). The index is the algorithm (inner range starts at `i + 1`), not a bookkeeping counter; `asMap().entries` cannot express "the elements after this one" without `skip`/`sublist`, which is longer and allocates.

---

## Attribution Evidence

```bash
grep -rn "'prefer_asmap_over_indexed_iteration'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:2758:    'prefer_asmap_over_indexed_iteration',
# class PreferAsmapOverIndexedIterationRule (collection_rules.dart:2739)
```

---

## Reproducer

```dart
// Standalone, compiles with plain `dart`.
bool allPairsSeen(List<String> ids, Set<String> seen) {
  for (int i = 0; i < ids.length; i++) { // LINT - should NOT lint
    for (int j = i + 1; j < ids.length; j++) { // LINT - should NOT lint
      if (!seen.contains('${ids[i]}|${ids[j]}')) return false;
    }
  }
  return true;
}

void main() => print(allPairsSeen(<String>['a', 'b', 'c'], <String>{'a|b', 'a|c', 'b|c'}));
```
Project source: `lib/utils/contact/matching/contact_match_exclusions.dart:277-286` (`isGroupFullyExcluded`).

**Frequency:** Always for `i < x.length` loops whose body reads `x[i]`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on a loop whose inner loop starts at `i + 1` (pair enumeration), or whose index feeds a second loop bound |
| **Actual** | `[prefer_asmap_over_indexed_iteration] Prefer asMap().entries for indexed iteration over manual index variable.` at 278:7-284:8 (outer) and 279:9-283:10 (inner) |

---

## AST Context

```
MethodDeclaration (isGroupFullyExcluded)
  └─ Block
      └─ TryStatement
          └─ Block
              └─ ForStatement (i)              <- reported (278:7)
                  └─ ForStatement (j = i + 1)  <- reported (279:9)
                      └─ Block
                          └─ IfStatement
                              └─ IndexExpression (uuids[i], uuids[j])
```

---

## Root Cause

`runWithReporter` (collection_rules.dart:2770-2793) matches any `ForStatement` with one declared variable, condition `<` on `.length`, one updater, and a body containing any `IndexExpression` whose index is the loop variable (`_bodyUsesIndex`, line 2791; `_IndexAccessVisitor` at ~2799). It never inspects the declaration initializer. For the inner loop the initializer is `i + 1` (not a literal `0`), which already shows the loop is not a plain element walk; the outer loop is flagged only because its index is read again by the inner initializer and `uuids[i]`.

---

## Why the Code Is Correct

The pair scan must visit each unordered pair once. With `asMap().entries` the inner loop would need `ids.asMap().entries.skip(i + 1)` (allocating a view and iterator per outer step) or an index anyway. The index form is the clearer and cheaper code.

---

## Affected Project Locations

`lib/utils/contact/matching/contact_match_exclusions.dart` lines 278 and 279.

---

## Suggested Fix

Skip a `ForStatement` when:
- its initializer is not the literal `0` (e.g. `i + 1`, `start`), or
- the loop variable is read in a nested `ForStatement`'s initializer or condition.

---

## Fixture Cases

```dart
// LINT expected (plain index walk from 0)
void a(List<int> l) { for (int i = 0; i < l.length; i++) { print(l[i]); } }

// OK expected (starts after another index)
void b(List<int> l) {
  for (int i = 0; i < l.length; i++) {
    for (int j = i + 1; j < l.length; j++) { print(l[i] + l[j]); }
  }
}
```
(The outer loop in `b` is the second fixture: OK because its index seeds the inner initializer.)

---

## Environment

- saropa_lints: 17.0.1-beta.2 (installed in the downstream project); rule line numbers below read from the local checkout (pubspec 17.0.1-beta.3), where the cited logic is unchanged.
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Downstream project: Saropa Contacts (`/Users/craighathaway/Documents/src/contacts`), Flutter app.
- Diagnostic `source` / `owner` in Problems panel: `saropa_lints` / `saropaLintsLsp`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
