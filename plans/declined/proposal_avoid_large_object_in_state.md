# PROPOSAL: Avoid Large Object In State

**Status: Declined**

Created: 2026-09-02

## Summary

Flags a large object (big list, decoded image, byte buffer) held directly as a field on a `State` class instead of behind a cache or repository layer.

## Existing Coverage

This rule already ships. `lib/src/rules/resources/memory_management_rules.dart` defines `AvoidLargeObjectsInStateRule` (lint id `avoid_large_objects_in_state`, since v0.1.4, currently at rule version v4):

```dart
class AvoidLargeObjectsInStateRule extends SaropaLintRule {
  ...
  static const LintCode _code = LintCode(
    'avoid_large_objects_in_state',
    '[avoid_large_objects_in_state] Unbounded List, Map, Set, or ByteData '
        'field declared in a State class grows without limit as data '
        'accumulates. ...',
    ...
  );

  static const Set<String> _largeTypePatterns = <String>{
    'List<', 'Map<', 'Set<', 'Uint8List', 'ByteData', 'ByteBuffer',
  };
}
```

It detects `List`/`Map`/`Set`/`Uint8List`/`ByteData`/`ByteBuffer` fields on `State` subclasses and cross-references accumulating mutation calls (`add`, `addAll`, `addEntries`, `insert`, `insertAll`, `putIfAbsent`) via AST `MethodInvocation` visitation. This is the same rule the task describes (large object in widget `State` instead of cache/repository).

**No new rule is proposed.** This file exists to document that the requested behavior is already implemented and to record the exact scope for anyone re-proposing changes to it (e.g. widening the type patterns, or adding decoded-`ui.Image`/`Picture` detection, which the current `_largeTypePatterns` set does not include).

## Motivation

N/A — see Existing Coverage. If a future gap is found (e.g. `ui.Image`/`Picture` objects held in `State` are not currently in `_largeTypePatterns`), file that as its own targeted proposal rather than reopening this one.

## Detection / Behavior

See `AvoidLargeObjectsInStateRule` in `lib/src/rules/resources/memory_management_rules.dart` (line 42 onward) for the shipped Bad/Good examples and detection logic.

## Quick Fix

None currently shipped for this rule — confirm against `lib/src/fixes/` before assuming a fix is missing; not investigated as part of this proposal since the rule itself is not new.

## Alternatives Considered

None — this proposal is a coverage confirmation, not a new-rule request.
