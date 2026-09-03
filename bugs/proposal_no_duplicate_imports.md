# PROPOSAL: No Duplicate Imports

**Status: Open**

Created: 2026-09-02

**Closes gap:** `pyramid_lint` `no_duplicate_imports` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags files that import the same URI more than once (with or without different prefixes/show/hide combinators). Duplicate imports add noise and can cause confusion about which prefix is canonical.

## Existing Coverage

Saropa already has `delete_duplicate_import_fix.dart` in `lib/src/fixes/structure/` and `structure_rules.dart` imports it — this gap may already be closed. Verify before implementing.

## Detection / Behavior

```dart
// Bad
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

// Good
import 'package:flutter/material.dart';
```

## Quick Fix

Remove the duplicate import directive.

## Alternatives Considered

- Dart analyzer already warns on exact duplicate imports. This rule's value is in catching near-duplicates (same URI, different show/hide).
