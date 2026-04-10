# Task: `prefer_sorted_imports`

## Summary
- **Rule Name**: `prefer_sorted_imports`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Implemented (task file for reference)
- **Source**: ROADMAP.md — Import and File Organization

## Problem Statement

Imports should be alphabetically sorted within groups. Improves consistency and merge conflicts.

## Description (from ROADMAP)

> Alphabetically sort imports within groups (with quick fix)

## Code Examples

### Bad (should trigger)

```dart
import 'package:b/b.dart';
import 'package:a/a.dart';
```

### Good (should not trigger)

```dart
import 'package:a/a.dart';
import 'package:b/b.dart';
```

## Detection: True Positives

- Within each import group (dart, package, relative), imports must be sorted alphabetically. Use addImportDirective and compare adjacent directives.

## False Positives

- Respect group boundaries. Do not reorder across groups.

## External References

- Dart Lint Rules, custom_lint

## Quality and Performance

- Single-file; import list traversal. Quick fix: sort and replace.

## Notes and Issues

- Rule is implemented. This task file may be removed by scripts/check_roadmap_implemented.py when run.
