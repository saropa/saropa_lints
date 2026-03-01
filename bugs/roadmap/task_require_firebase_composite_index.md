# Task: `require_firebase_composite_index`

## Summary
- **Rule Name**: `require_firebase_composite_index`
- **Tier**: Essential
- **Severity**: ERROR
- **Status**: Implemented (ROADMAP shows implemented; task file for reference/triage)
- **Source**: ROADMAP.md — 5.29 Firebase Advanced Rules

## Problem Statement

RTDB compound queries need `.indexOn` in Firebase rules. Queries that use `orderByChild` plus filter without a matching index fail at runtime.

## Description (from ROADMAP)

> RTDB compound queries need `.indexOn`. Detect `orderByChild` + filter without index.

## Code Examples

### Bad (should trigger)

```dart
ref.orderByChild('status').equalTo('active'); // LINT: needs index
```

### Good (should not trigger)

```dart
// When rules have .indexOn: ['status'] or composite.
ref.orderByChild('status').equalTo('active');
```

## Detection: True Positives

- **Goal**: Detect Firebase RTDB query calls that combine `orderByChild` (and similar) with filters; warn when project may not have corresponding index (e.g. check rules or document required index). Single-file: at least report the pattern and suggest adding index.
- **Approach**: Find `orderByChild`/`orderByKey`/etc. and `equalTo`/`startAt`/`endAt` on same query; report with message to add `.indexOn` in rules.

## False Positives

- **Mitigation**: Cannot fully verify rules from Dart; rule documents that index must be added in Firebase console/rules. ERROR severity so teams fix before deploy.

## External References

- [Firebase RTDB Indexing](https://firebase.google.com/docs/database/security/indexing-data)
- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Use `ProjectContext.usesPackage('firebase_database')`; target method invocations on query objects. Early exit when package not used.

## Notes & Issues

- Rule is implemented. This task file may be removed by `scripts/check_roadmap_implemented.py` when run.
