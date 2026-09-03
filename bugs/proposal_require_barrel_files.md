# PROPOSAL: Require Barrel Files

**Status: Open**

Created: 2026-09-02

## Summary

Flags a directory whose sibling files are imported individually from many other files across the project, where a single barrel file (a `directory.dart` re-exporting the siblings) would reduce that import fan-out.

## Existing Coverage

`AvoidBarrelFilesRule` (`lib/src/rules/architecture/structure_rules.dart`) flags the opposite pattern — a file that IS a barrel (export-only) — as a build-time and dependency-tracking cost. `require_barrel_files` targets directories that *lack* one and would benefit from consolidating scattered individual imports. The two rules represent a deliberate tension (barrel files trade import ergonomics for build/tree-shaking cost) and are kept as separate, opt-in checks rather than merged — which convention applies depends on the directory's actual import fan-out, not a single project-wide policy.

## Motivation

When a directory's files are each imported piecemeal from dozens of call sites across the project, adding, removing, or renaming a file in that directory means touching every import site individually instead of one barrel export list. A barrel file centralizes that surface for genuinely cohesive modules (e.g. a `models/` directory consumed widely).

## Cross-File Requirement

Cannot be implemented as a per-file analyzer rule — needs the project-wide import graph (which files in a directory are imported individually, by how many other files, across the whole project) to detect that many siblings are imported piecemeal; this can't be seen from any single file's AST. Build as a `dart run saropa_lints:cross_file` check rather than a `custom_lint` visitor. See `plans/cross_file_cli_design.md`.

## Detection / Behavior

#### BAD (project-wide import graph):
```dart
// lib/features/checkout/cart_page.dart
import 'package:app/src/models/user.dart';
import 'package:app/src/models/order.dart';
import 'package:app/src/models/product.dart';
```
```dart
// lib/features/profile/profile_page.dart
import 'package:app/src/models/user.dart';
import 'package:app/src/models/order.dart';
```

#### GOOD:
```dart
// lib/src/models/models.dart
export 'user.dart';
export 'order.dart';
export 'product.dart';
```
```dart
import 'package:app/src/models/models.dart';
```

## Quick Fix

Generate the barrel file with `export` statements for the directory's public files. Rewriting call-site imports to use the new barrel is left as an optional follow-up pass, since it touches many files at once.

## Alternatives Considered

A hard fan-out threshold (e.g. 5+ external importers each pulling in 2+ siblings) versus a ratio-based heuristic was considered; the CLI implementation should expose this as configuration rather than pick one at proposal time.
