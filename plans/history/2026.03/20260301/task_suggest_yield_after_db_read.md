# Task: `suggest_yield_after_db_read`

## Summary
- **Rule Name**: `suggest_yield_after_db_read`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.10 Database & Storage Rules, DB/IO Yield (All DB Packages + File I/O)

## Problem Statement

Bulk database or I/O read without a following `yieldToUI()` call can cause frame drops when deserializing large payloads. This rule suggests yielding to the UI after heavy reads; `findFirst` is excluded.

This rule aims to improve responsiveness and avoid jank during bulk DB or file I/O.

## Description (from ROADMAP)

> Bulk database or I/O read without a following `yieldToUI()` call. Deserializing large payloads can cause frame drops. `findFirst` is excluded.

## Code Examples

### Bad (should trigger)

```dart
// Bulk read with no yield — can block UI.
Future<void> loadAll() async {
  final items = await box.getAll(ids); // LINT: bulk read, no yield
  setState(() => _items = items);
}
```

### Good (should not trigger)

```dart
Future<void> loadAll() async {
  final items = await box.getAll(ids);
  await yieldToUI(); // or SchedulerBinding.instance.endOfFrame
  setState(() => _items = items);
}

// findFirst excluded.
final first = await box.findFirst(); // OK
```

## Detection: True Positives

- **Goal**: Detect async functions that perform bulk DB/I/O reads (e.g. `getAll`, `findAll`, `readAsString` on large files) without a subsequent `yieldToUI()` (or equivalent) before heavy work or setState.
- **Approach**: Use `ProjectContext.usesPackage` for DB packages (isar, hive, sqflite, etc.); identify bulk read methods vs single-item (e.g. `findFirst` excluded); check for yield in same function after await.
- **AST**: Method invocations in async functions; control flow to ensure yield is required after read.

## False Positives

- **Risk**: Small reads or reads that are already off main isolate flagged.
- **Mitigation**: Exclude `findFirst`, single-record reads; consider only flagging when payload size is inferrable (e.g. `getAll` with list arg). Use INFO severity.
- **Allowlist**: Test files, generated code.

## External References

- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [Flutter SchedulerBinding](https://api.flutter.dev/flutter/scheduler/SchedulerBinding-class.html)
- [custom_lint](https://pub.dev/packages/custom_lint)
- Package docs: isar, hive, sqflite

## Quality & Performance

- Use `ProjectContext` for package detection; prefer targeted `addMethodInvocation` or similar.
- Early exit when no DB/I/O package used.

## Notes & Issues

- Define "bulk" clearly (e.g. getAll, findAll, readAsString); document excluded methods in rule doc. Check CODE_INDEX for existing yield/async helpers.
