# BUG: `prefer_asmap_over_indexed_iteration` — Flags index loops where the index also addresses a second list/string, or where the list grows during iteration

**Status: Open**

Created: 2026-10-31
Rule: `prefer_asmap_over_indexed_iteration`
File: `lib/src/rules/data/collection_rules.dart` (line ~2758)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags index loops where the index also addresses a second list/string, or where the list grows during iteration. In a downstream app review, 13 of 21 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'prefer_asmap_over_indexed_iteration'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:2758:    'prefer_asmap_over_indexed_iteration',
```

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:2758`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
for (int j = 0; j < sortedThis.length; j++) {
  final a = sortedThis[j];
  final b = sortedOther[j]; // second list addressed by same index — LINT but should NOT lint
  ...
}

final group = <ContactModel>[contact];
for (int i = 0; i < group.length; i++) { // list grows inside loop — LINT but should NOT lint
  group.addAll(await loader(group[i].id));
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/json/json_compare.dart:52,178,328; lib/utils/contact/native_linked_device_targets.dart:55 (BFS, list grows); lib/utils/language/pronunciation/name_pronunciation_japanese_moras.dart:44,95; native_import_bookkeeping_diff.dart:63; world_flyover_stops.dart:217.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[prefer_asmap_over_indexed_iteration]` reported at each site above |

---

## Root Cause

The rule only checks that the index is used to read one list. It misses (a) the index used on a second collection (asMap would not remove the index), and (b) mutation of the iterated list inside the loop, where asMap/iteration would throw ConcurrentModificationError.

---

## Suggested Fix

Skip when the loop variable indexes more than one distinct target, or when the loop body adds to/removes from the iterated collection, or when the loop condition re-reads `.length`.

---

## Fixture Gap

The fixture for `prefer_asmap_over_indexed_iteration` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

## Resolution

Fixed 2026-10-31. The rule now skips loops where the index addresses more than one distinct collection, and loops whose body calls add/addAll/insert/remove/removeAt/removeLast/removeWhere/removeRange/clear on the iterated collection. The `.length` re-read case is covered by the mutation check. Fixture cases added (two expect-NO-lint, one near-miss expect-LINT); verified with `dart run saropa_lints:scan --tier comprehensive` on a scratch copy.
