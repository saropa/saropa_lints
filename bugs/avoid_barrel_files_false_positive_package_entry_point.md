# `avoid_barrel_files` false positive: mandatory Dart package entry point file

## Status: OPEN

## Summary

The `avoid_barrel_files` rule (v6) fires on `lib/saropa_dart_utils.dart`, the **mandatory package entry point** for the `saropa_dart_utils` Dart package. This file exists because the official Dart package layout convention requires `lib/<package_name>.dart` as the primary public API surface. Every consumer imports the package via `import 'package:saropa_dart_utils/saropa_dart_utils.dart';` — this file MUST exist and MUST contain only export statements. The rule cannot distinguish between an internal barrel file (which is a legitimate code smell) and the required package entry point (which is a Dart ecosystem requirement).

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/saropa_dart_utils.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_barrel_files
severity: 2 (info)
message:  [avoid_barrel_files] File contains only export statements (barrel file).
          Barrel files increase build times by pulling in unused code and obscure
          dependency tracking, making it harder to identify which modules depend
          on which implementations. {v6}
          Import specific files where needed instead of using barrel files.
          Direct imports make dependency graphs explicit and enable tree-shaking.
line:     0
```

## Affected Source

File: `lib/saropa_dart_utils.dart` — the main library entry point (87 lines, 35 exports)

```dart
/// Saropa Dart Utils - Boilerplate reduction tools and human-readable
/// extension methods by Saropa.
library;

// Base64 utilities
export 'base64/base64_utils.dart';

// Bool extensions
export 'bool/bool_iterable_extensions.dart';
export 'bool/bool_string_extensions.dart';

// DateTime extensions and utilities
export 'datetime/date_constant_extensions.dart';
export 'datetime/date_constants.dart';
export 'datetime/date_time_extensions.dart';
export 'datetime/date_time_nullable_extensions.dart';
export 'datetime/date_time_range_utils.dart';
export 'datetime/date_time_utils.dart';
export 'datetime/time_emoji_utils.dart';

// ... (35 total exports covering all public API categories)

// URL extensions and utilities
export 'url/url_extensions.dart';

// UUID utilities
export 'uuid/uuid_utils.dart';
```

Key characteristics of this file:

| Property | Value | Implication |
|----------|-------|-------------|
| File name | `lib/saropa_dart_utils.dart` | Matches package name from `pubspec.yaml` |
| Package name | `saropa_dart_utils` | Published on pub.dev |
| Contents | 35 `export` statements | Defines the public API surface |
| `library` directive | Present (`library;`) | Official library declaration |
| Required by | Dart package conventions | Removing it breaks all consumers |

## Root Cause

The rule flags any file that contains only `export` (and optionally `library`) statements as a "barrel file." The detection logic does not check whether the file is the package's **mandatory entry point** — the file whose path matches `lib/<package_name>.dart`.

The rule's intent is valid for internal barrel files like `lib/src/all_widgets.dart` or `lib/src/utils/index.dart`, which aggregate internal modules unnecessarily. However, `lib/<package_name>.dart` is structurally different:

1. **It is required by the Dart package layout specification** — https://dart.dev/tools/pub/package-layout#public-libraries
2. **pub.dev scoring penalizes packages without it** — The "Follow Dart file conventions" check requires this file
3. **It is the ONLY way to provide a single-import API** — Consumers cannot import `package:saropa_dart_utils` without this file
4. **The Dart team explicitly recommends this pattern** — Every official Dart/Flutter package uses it

The rule has no mechanism to identify the package name (available from `pubspec.yaml`) and exempt the matching library file.

## Why This Is a False Positive

1. **Mandatory file** — `lib/<package_name>.dart` is required by the Dart package layout convention. It is not optional. Removing it breaks every consumer.

2. **No alternative exists** — The rule's correction message says "Import specific files where needed instead of using barrel files." This would require every consumer to know the internal file structure of the package (e.g., `import 'package:saropa_dart_utils/string/string_extensions.dart';` instead of `import 'package:saropa_dart_utils/saropa_dart_utils.dart';`). This is explicitly against Dart package design principles.

3. **pub.dev scoring** — The `pana` scoring tool that pub.dev uses to evaluate packages checks for the existence of `lib/<package_name>.dart`. Removing it reduces the package score.

4. **100% of published packages have this file** — Every Dart package on pub.dev has `lib/<package_name>.dart`. Flagging it produces a false positive for every published package.

5. **The file IS the public API** — This is not an internal convenience barrel. It is the intentional, versioned public API surface that defines what consumers can access.

6. **Tree-shaking concern is invalid here** — The Dart compiler already tree-shakes unused symbols. The entry point file does not cause unused code to be included in builds.

## Scope of Impact

Every published Dart package on pub.dev will trigger this rule. This includes:

- All packages published by Google (`provider`, `riverpod`, `bloc`, etc.)
- All community packages
- Any project structured as a Dart package with a public API

The false positive rate for package entry point files is 100%.

## Recommended Fix

### Approach A: Skip the package entry point file (recommended)

Check whether the flagged file matches `lib/<package_name>.dart` by reading the package name from the nearest `pubspec.yaml`:

```dart
context.addCompilationUnit((CompilationUnit node) {
  final String? filePath = context.filePath;
  if (filePath == null) return;

  // Skip the mandatory package entry point
  final String packageName = context.packageName; // from pubspec.yaml
  final String entryPointPath = 'lib/$packageName.dart';
  if (filePath.endsWith(entryPointPath)) return;

  // ... existing barrel file detection logic ...
});
```

### Approach B: Skip files with a `library` directive

Files with an explicit `library;` or `library <name>;` directive are intentional library entry points, not accidental barrels:

```dart
// Check for library directive
final bool hasLibraryDirective = node.directives.any(
  (Directive d) => d is LibraryDirective,
);
if (hasLibraryDirective) return;
```

### Approach C: Only flag files inside `lib/src/`

The Dart convention is that `lib/src/` contains implementation details and `lib/` root contains public API files. Only flag barrel files inside `lib/src/`:

```dart
if (!filePath.contains('/src/') && !filePath.contains('\\src\\')) return;
```

**Recommendation:** Approach A is the most precise and correct. The package name is a definitive identifier, not a heuristic. Approach B is a reasonable supplement. Approach C is too broad (it would also skip legitimate barrels at `lib/` root that are not the entry point).

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Mandatory package entry point — must not trigger.
// File: lib/my_package.dart
library;

export 'src/feature_a.dart';
export 'src/feature_b.dart';
export 'src/feature_c.dart';
```

```dart
// GOOD: Named library directive — intentional public API.
// File: lib/my_package.dart
library my_package;

export 'src/widget.dart';
export 'src/utils.dart';
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Internal barrel file aggregating implementation files.
// File: lib/src/all_widgets.dart
// expect_lint: avoid_barrel_files
export 'button.dart';
export 'card.dart';
export 'dialog.dart';
```

```dart
// BAD: Convenience barrel inside src directory.
// File: lib/src/utils/index.dart
// expect_lint: avoid_barrel_files
export 'string_utils.dart';
export 'date_utils.dart';
export 'math_utils.dart';
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v6)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (published Dart utility package)
- **Trigger file:** `lib/saropa_dart_utils.dart`
- **Package name:** `saropa_dart_utils` (from `pubspec.yaml`)
- **File contents:** `library;` directive + 35 `export` statements
- **pub.dev URL:** https://pub.dev/packages/saropa_dart_utils

## Severity

Low — info-level diagnostic. The false positive is benign in that it does not suggest a harmful action, but it is misleading: the correction advice ("Import specific files where needed") would break the package's public API contract. More importantly, since this affects 100% of published Dart packages, the rule's signal-to-noise ratio is severely degraded. Developers may disable the rule entirely rather than suppress it per-file, losing the legitimate value it provides for internal barrel files.
