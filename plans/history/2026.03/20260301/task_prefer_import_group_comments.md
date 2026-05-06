# Task: `prefer_import_group_comments`

## Summary
- **Rule Name**: `prefer_import_group_comments`
- **Tier**: Stylistic
- **Severity**: INFO
- **Status**: Implemented (ROADMAP shows implemented; task file for reference/triage)
- **Source**: ROADMAP.md — Import & File Organization

## Problem Statement

Add `///` section headers between import groups for readability.

## Description (from ROADMAP)

> Add `///` section headers between import groups (with quick fix)

## Code Examples

### Bad (should trigger)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
```

### Good (should not trigger)

```dart
/// Dart SDK
import 'dart:async';
/// Flutter
import 'package:flutter/material.dart';
```

## Detection: True Positives

- Detect import groups (dart vs package vs relative) and report when a group is not preceded by a doc comment. Optional quick fix: insert `/// Group name` before first import of each group.

## False Positives

- Allow single-group files; allow existing alternate comment style. Stylistic so INFO and team-configurable.

## External References

- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Single-file; import directives and preceding comments. Use `addImportDirective`.

## Notes & Issues

- Rule is implemented. This task file may be removed by `scripts/check_roadmap_implemented.py` when run.
