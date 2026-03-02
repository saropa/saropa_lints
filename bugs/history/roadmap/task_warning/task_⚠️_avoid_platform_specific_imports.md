> **========================================================**
> **IMPLEMENTED -- v5.1.0**
> **========================================================**
>
> `AvoidPlatformSpecificImportsRule` in
> `lib/src/rules/config_rules.dart`. Recommended tier.
>
> **========================================================**

# Task: `avoid_platform_specific_imports`

## Summary
- **Rule Name**: `avoid_platform_specific_imports`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.35 Platform-Specific Rules

## Problem Statement

Dart's `dart:io` library is only available on native platforms (Android, iOS, macOS, Linux, Windows). It is NOT available on Flutter Web. When a file imports `dart:io` without conditional imports, it will fail to compile for web:

```dart
import 'dart:io'; // ← compiles on native, crashes on web

void downloadFile(String url, String path) {
  final file = File(path); // ← File class from dart:io — not available on web!
  // ...
}
```

For code that needs to run on both web and native, use **conditional imports**:
```dart
import 'platform_file.dart'
    if (dart.library.io) 'platform_file_native.dart'
    if (dart.library.html) 'platform_file_web.dart';
```

Or use packages that abstract platform differences (`universal_io`, `path_provider` already handles this).

## Description (from ROADMAP)

> Use conditional imports for platform code. Detect dart:io in web code.

## Trigger Conditions

1. `import 'dart:io'` in a file that is NOT in a native-only directory (`lib/src/native/`, `lib/src/mobile/`)
2. `import 'dart:html'` in a file that is NOT in a web-only directory
3. Direct `dart:io` usage without a conditional import guard

**Phase 1 (Conservative)**: Flag `import 'dart:io'` in non-native-specific files when the project targets web (has `web/` directory).

## Implementation Approach

```dart
context.registry.addImportDirective((node) {
  if (!_isDartIoImport(node)) return;
  if (!_projectTargetsWeb(context)) return; // web/ directory exists
  if (_isNativeSpecificFile(node)) return; // in native/ subdirectory
  reporter.atNode(node, code);
});
```

`_isDartIoImport`: check if URI is `dart:io`.
`_projectTargetsWeb`: check for `web/` directory at project root (requires file system access).
`_isNativeSpecificFile`: check if the file path contains `native/`, `mobile/`, `android/`, `ios/`.

## Code Examples

### Bad (Should trigger — in a web-capable project)
```dart
import 'dart:io'; // ← trigger: dart:io without conditional import in web-targeting project

class FileService {
  Future<String> readFile(String path) async {
    return File(path).readAsString(); // ← dart:io - will fail on web
  }
}
```

### Good (Should NOT trigger)
```dart
// Conditional import
import 'file_service.dart'
    if (dart.library.io) 'file_service_native.dart'
    if (dart.library.html) 'file_service_web.dart';

// Or: using a platform-agnostic alternative
import 'package:universal_io/io.dart'; // wrapper for both platforms
```

```dart
// In a native-only file:
// lib/src/native/file_service_native.dart
import 'dart:io'; // ← OK: this file is native-only
class NativeFileService { ... }
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Mobile-only project (no web/ dir) | **Suppress** — dart:io is fine | |
| File in `lib/src/native/` | **Suppress** — clearly native-only | |
| `dart:io` in `test/` | **Suppress** — tests may be native-only | |
| Generated code | **Suppress** | |
| `dart:io` with conditional: `if (dart.library.io)` | **Suppress** — properly guarded | |

## Unit Tests

### Violations
1. `import 'dart:io'` in lib file when project has web/ dir → 1 lint

### Non-Violations
1. `import 'dart:io'` in mobile-only project → no lint
2. `import 'dart:io'` in `lib/src/native/` file → no lint
3. Conditional `import 'dart:io'` only via `if (dart.library.io)` → no lint

## Quick Fix

Offer "Wrap in conditional import":
```dart
// Before
import 'dart:io';

// After
import 'stub.dart' // must create stub
    if (dart.library.io) 'dart:io';
```

Note: This fix is non-trivial because it requires creating a stub file. Suggest as a manual step.

## Notes & Issues

1. **Project web detection**: Detecting that the project targets web requires checking for a `web/` directory. This file system access is available to lint tools but may not be in standard `ProjectContext`. Check `ProjectContext` API.
2. **`dart:html` detection**: Similarly, `import 'dart:html'` should be flagged in non-web contexts (though this is less common).
3. **`package:universal_io`**: This is the standard replacement for `dart:io` in cross-platform packages. Detect its use as a suppression (the developer has already made the right choice).
4. **Pub.dev package constraint**: If the package has `platforms: android, ios` only in `pubspec.yaml`, `dart:io` is fine. If it lists `web` as a supported platform, then `dart:io` without conditional imports is a bug.
5. **The real scope**: This rule is most valuable for **library packages** (pub.dev packages) that must support multiple platforms. Application code usually knows its platform and `dart:io` is often fine.
6. **`File` vs `dart:io`**: Some apps import `dart:io` just for the `File` class to read local files. On web, `path_provider` and `file_picker` are the alternatives.
