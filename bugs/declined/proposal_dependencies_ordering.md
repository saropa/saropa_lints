# PROPOSAL: Dependencies Ordering

**Status: Declined**

Created: 2026-09-02

## Summary

Flags `dependencies:`, `dev_dependencies:`, or `dependency_overrides:` entries in `pubspec.yaml` that are not in alphabetical order.

## Motivation

An unsorted dependency list is harder to scan when checking whether a package is already declared, and it increases merge-conflict noise when two branches each add a dependency at the end of the list instead of in its alphabetical slot. `dart pub add` inserts new dependencies alphabetically by default, so an unsorted list is usually the result of manual edits drifting from that convention.

## Detection / Behavior

Fires when any dependency section has two consecutive top-level keys where the later key sorts before the earlier one.

**BAD:**
```yaml
dependencies:
  http: ^1.0.0
  args: ^2.0.0
```

**GOOD:**
```yaml
dependencies:
  args: ^2.0.0
  http: ^1.0.0
```

## Quick Fix

Re-sort the entries within each section alphabetically, preserving each entry's own value/sub-map and any attached comment.

## Alternatives Considered

None — narrower scoping (e.g. `dependencies:` only, ignoring `dev_dependencies:`/`dependency_overrides:`) was not considered necessary since the existing implementation already treats all three sections uniformly.

## Existing Coverage

**Already implemented.** `SortPubDependenciesRule` (code `sort_pub_dependencies_extended`) in `lib/src/rules/config/config_rules.dart` (~line 1078) does exactly this: it matches `dependencies:` / `dev_dependencies:` / `dependency_overrides:` section headers, collects each section's 2-space-indented entry names, and reports when any adjacent pair is out of order (`_isUnsorted`), reporting once per project root via the same "attach to top of a `lib/` Dart file" pattern used elsewhere in the pubspec rules. A new `dependencies_ordering` rule would be a straight duplicate — recommend closing this proposal rather than implementing, unless the intent is specifically to change behavior the existing rule doesn't have (e.g. case-insensitive comparison, or excluding `dependency_overrides:`).
