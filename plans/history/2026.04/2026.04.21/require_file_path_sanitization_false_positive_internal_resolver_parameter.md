# BUG: `require_file_path_sanitization` — fires on internal resolver parameters that never carry user input

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-21
Closed: 2026-04-21
Rule: `require_file_path_sanitization`
File: `lib/src/rules/resources/file_handling_rules.dart` (line ~1702, core check at ~1746)
Severity: False positive
Rule version: v3 | Since: v1.x | Updated: v12.3.4

---

## Summary

The rule flags any `File(...)` / `Directory(...)` whose path interpolates an
enclosing function parameter. The detection is a pure syntactic "parameter
name appears in the first-arg source" check with no taint-source analysis,
so it fires on private helpers that only ever receive hardcoded literals or
values resolved from trusted Dart-SDK APIs (`Isolate.resolvePackageUri`,
`package_config.json` parsing, `Platform.resolvedExecutable`). The
`isFromPlatformPathApi` escape hatch only recognizes a fixed list of Flutter
`path_provider` APIs and misses equivalently trusted Dart-SDK resolvers.

Sibling bug: `avoid_path_traversal_false_positive_internal_resolver_parameter.md`
— same false positive via the same shared helper; fixing the helper closes both.

---

## Reproducer

Minimal reproduction extracted from `saropa_drift_advisor`
(`lib/src/server/generation_handler.dart` lines 225, 401, 410).

```dart
import 'dart:io';
import 'dart:isolate';

class AssetServer {
  // Public entry points pass compile-time literals only.
  Future<void> sendWebStyle() => _sendWebAsset('assets/web/style.css');
  Future<void> sendWebApp()   => _sendWebAsset('assets/web/bundle.js');

  // Private helper — parameter name `relativePath` appears in the
  // interpolated path source, so the rule fires. But every call site
  // passes a StringLiteral; no user input can reach this.
  Future<void> _sendWebAsset(String relativePath) async {
    final packageRoot = await _resolvePackageRoot();
    if (packageRoot == null) return;

    // expect_lint: require_file_path_sanitization  ← FALSE POSITIVE
    final file = File('$packageRoot/$relativePath');
    if (await file.exists()) {
      await file.readAsString();
    }
  }

  // Also flagged: the segment after `packageRoot/` is a compile-time
  // literal, but the parameter name `packageRoot` is in the path source.
  static Future<void> _cacheWebAssets(String packageRoot) async {
    // expect_lint: require_file_path_sanitization  ← FALSE POSITIVE
    final cssFile = File('$packageRoot/assets/web/style.css');
    // expect_lint: require_file_path_sanitization  ← FALSE POSITIVE
    final jsFile  = File('$packageRoot/assets/web/bundle.js');
    if (await cssFile.exists()) await cssFile.readAsString();
    if (await jsFile.exists())  await jsFile.readAsString();
  }

  // Resolver draws only from Dart-SDK APIs that cannot carry HTTP input.
  Future<String?> _resolvePackageRoot() async {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:my_pkg/my_pkg.dart'),
    );
    return uri == null ? null : File.fromUri(uri).parent.parent.path;
  }
}
```

**Frequency:** Always — any private helper whose parameter name appears in a
`File(...)` / `Directory(...)` interpolated path, where the helper is not
called from a scope containing one of the eight hard-coded
`platformPathApis` names *and* the enclosing body lacks a matching
sanitization keyword (`basename`, `isWithin`, `normalize`, `sanitize`,
`replaceAll`, or a literal `..`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. All three sites interpolate values that originate from compile-time string literals (passed by trusted call sites) and from `Isolate.resolvePackageUri` / `package_config.json` — neither is user input. |
| **Actual** | `[require_file_path_sanitization] File path constructed from parameter without sanitization. Path traversal attack possible with ../` fires on all three sites. |

---

## AST Context

```
ClassDeclaration (AssetServer)
  └─ MethodDeclaration (_sendWebAsset)      ← enclosing method (private)
      └─ FormalParameterList
      │   └─ SimpleFormalParameter (relativePath)  ← name appears in path source
      └─ BlockFunctionBody
          └─ …
              └─ VariableDeclaration (file)
                  └─ InstanceCreationExpression  ← node reported here
                      ├─ ConstructorName (File)
                      └─ ArgumentList
                          └─ StringInterpolation
                              ├─ InterpolationString ("")
                              ├─ InterpolationExpression ($packageRoot)
                              ├─ InterpolationString ("/")
                              └─ InterpolationExpression ($relativePath)
```

`_checkForUnsanitizedPath` (lines 1771–1815) walks up to the enclosing
`FunctionBody`, scans its source for any of `basename`, `isWithin`,
`normalize`, `sanitize`, `replaceAll`, or `..` — none are present, so it
continues. It then calls `isFromPlatformPathApi`, which also returns false
because neither the helper's body nor any same-class caller contains one of
the eight hard-coded `platformPathApis` names. It then matches a parameter
name (`relativePath` or `packageRoot`) against the path source and reports.

---

## Root Cause

`_checkForUnsanitizedPath` (line 1771) uses a three-step filter:

1. Is the enclosing body already sanitized? — scan `bodySource` for
   `_sanitizationBodyPatterns` (line 1732): `basename`, `isWithin`,
   `normalize`, `sanitize`, `replaceAll`, `\.\.`.
2. Is the scope trusted? — `isFromPlatformPathApi(node)` (shared with
   `AvoidPathTraversalRule`, see `lib/src/platform_path_utils.dart`).
3. Does any enclosing-function parameter name appear as a substring of the
   path? — if so, report.

Step 3 equates "parameter name appears in path string" with "user input
flows into the path." That assumption is wrong for:

- **Private helpers whose every caller passes a compile-time literal** at
  the flagged parameter's position. The rule's escape hatch already walks
  call sites for private methods — but only accepts a caller as "trusted" if
  the caller's body contains one of eight hard-coded `path_provider` names.
  It does not accept a caller that simply passes a `StringLiteral`.
- **Parameters whose values come from trusted Dart-SDK resolvers** — e.g.
  `Isolate.resolvePackageUri`, `Platform.resolvedExecutable`,
  `Directory.systemTemp.path`, `File.fromUri`. None of these are in
  `platformPathApis`, and none can be reached from an HTTP request without
  developer-written bridging code.

The shared helper `isFromPlatformPathApi` in
`lib/src/platform_path_utils.dart` (line 38) is the single point of failure:
its hard-coded `platformPathApis` set (lines 13–22) lists only Flutter
`path_provider` APIs. Any trusted Dart-SDK path resolver is unrecognized.

### Hypothesis A: widen `platformPathApis` to include Dart-SDK resolvers

Add `resolvePackageUri`, `File.fromUri`, `Directory.fromUri`,
`Directory.systemTemp`, `Platform.resolvedExecutable`, `Platform.script`.
Lowest-risk fix; closes the reproducer here and most other "package root
resolved via SDK API" patterns.

### Hypothesis B: literal-only call sites are trusted

Extend `_callerHasPlatformPathApi` so that a private method whose tainted
parameter receives a `StringLiteral` at every call site is treated as
trusted. More general — covers cases the allowlist misses — but requires
AST arg-position resolution and same-class traversal of all call sites.

### Hypothesis C: proper taint-source analysis

The true boundary is "did this string flow from `HttpRequest.queryParameters`,
`HttpRequest.headers`, request body JSON, or similar?" Large investment;
listed here for completeness. Rule v3 is a heuristic and will keep
producing false positives without it.

---

## Suggested Fix

Shortest path that closes this specific false positive: **Hypothesis A**, in
`lib/src/platform_path_utils.dart` (lines 13–22) — extend `platformPathApis`
with trusted Dart-SDK resolver names. `bodyContainsPlatformPathApi` (line
25) is substring-based, so adding names is sufficient; no other changes
required.

If **Hypothesis B** is implemented, it should replace the allowlist grow
pattern entirely for future rule versions: literal-only arg positions for
private helpers are a more precise, maintenance-free signal than naming
every trusted resolver.

Because both `RequireFilePathSanitizationRule` and `AvoidPathTraversalRule`
call `isFromPlatformPathApi`, a single edit to the shared helper closes this
bug and its sibling (`avoid_path_traversal_false_positive_internal_resolver_parameter.md`).

---

## Fixture Gap

The fixture at `example/lib/file_handling/require_file_path_sanitization_fixture.dart`
should include:

1. **Private helper called only with literals** — expect NO lint
   ```dart
   class X {
     Future<void> readStyle() => _read('assets/style.css');
     Future<void> readJs()    => _read('assets/bundle.js');
     Future<void> _read(String relativePath) async {
       final root = Directory.current.path;
       final f = File('$root/$relativePath'); // should NOT lint
       if (await f.exists()) await f.readAsString();
     }
   }
   ```
2. **Parameter sourced from `Isolate.resolvePackageUri`** — expect NO lint
   ```dart
   Future<File?> fromPackageRoot() async {
     final uri = await Isolate.resolvePackageUri(Uri.parse('package:p/p.dart'));
     if (uri == null) return null;
     final root = File.fromUri(uri).parent.parent.path;
     return _open(root);
   }
   Future<File> _open(String packageRoot) async =>
       File('$packageRoot/assets/web/style.css'); // should NOT lint
   ```
3. **Parameter sourced from `Directory.systemTemp.path`** — expect NO lint
4. **Parameter sourced from `Platform.resolvedExecutable`** — expect NO lint
5. **Regression: HTTP query parameter flows to `File(...)`** — expect LINT
   (to prove the rule still catches the actual vulnerability).

---

## Changes Made

Shared fix with sibling bug [avoid_path_traversal_false_positive_internal_resolver_parameter.md](avoid_path_traversal_false_positive_internal_resolver_parameter.md) — one edit to [lib/src/platform_path_utils.dart](../lib/src/platform_path_utils.dart) closes both. See that bug report for the full "Changes Made" description; the `require_file_path_sanitization`-specific wiring lives in [lib/src/rules/resources/file_handling_rules.dart](../lib/src/rules/resources/file_handling_rules.dart) at line 1816, inside the per-parameter loop of `_checkForUnsanitizedPath`: after the existing `isFromPlatformPathApi(node)` check, the rule calls `isParamPassedOnlyLiteralsAtCallSites(node, paramName)` and `continue`s (so a different parameter could still be the reporting trigger) when literal-only call sites are proven. The private-but-uncalled case (`_badHttpQueryStillLints` in the fixture) correctly still lints because zero observed call sites fail the helper's "at least one caller" precondition.

---

## Tests Added

[example/lib/file_handling/require_file_path_sanitization_fixture.dart](../example/lib/file_handling/require_file_path_sanitization_fixture.dart) gains four regression cases plus a private-but-uncalled BAD regression:

- `AssetReaderLiteralOnly` — private helper `_read` whose every caller passes a `StringLiteral`, `root` sourced from `Directory.current.path`.
- `openFromPackageRoot` / `_openAtPackageRoot` — caller body contains `Isolate.resolvePackageUri` and `File.fromUri` (Hypothesis A allowlist match).
- `openInTemp` / `_openAtTmp` — caller body contains `Directory.systemTemp` (allowlist match via `systemTemp`).
- `openNearExe` / `_openAtExe` — caller body contains `Platform.resolvedExecutable` (allowlist match via `resolvedExecutable`).
- `_badHttpQueryStillLints(String userInput)` — private top-level with `// expect_lint: require_file_path_sanitization`. Zero callers, so literal-only check returns false. Regression guard that the new escape hatches do not over-suppress.

All passing: `dart test test/security_rules_test.dart test/file_handling_rules_test.dart test/false_positive_fixes_test.dart test/fixture_lint_integration_test.dart` → 443/443. `dart analyze --fatal-infos` → clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 12.3.3
- Dart SDK version: (from consumer pubspec — Dart 3.x)
- custom_lint version: (from consumer pubspec)
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/generation_handler.dart` lines 225, 401, 410
