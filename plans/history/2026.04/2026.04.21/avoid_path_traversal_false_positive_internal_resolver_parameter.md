# BUG: `avoid_path_traversal` — fires on internal resolver parameters that never carry user input

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-21
Closed: 2026-04-21
Rule: `avoid_path_traversal`
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~2104, run at ~2148)
Severity: False positive
Rule version: v8 | Since: v1.x | Updated: v12.3.4

---

## Summary

The rule flags any `File(...)` / `Directory(...)` whose path interpolates an
enclosing function parameter, treating every parameter as potentially tainted
user input. It has no taint-source analysis, so it fires on private helpers
that only ever receive hardcoded literals or values resolved from trusted
internal APIs (package root resolution, isolate URI resolution,
`.dart_tool/package_config.json` parsing). The escape hatch
(`isFromPlatformPathApi`) only recognizes a fixed list of Flutter
`path_provider` APIs and misses equivalently trusted Dart SDK APIs.

---

## Reproducer

Minimal reproduction extracted from `saropa_drift_advisor`
(`lib/src/server/generation_handler.dart` lines 225, 401, 410).

```dart
import 'dart:io';
import 'dart:isolate';

class AssetServer {
  // PUBLIC ENTRY POINTS — both pass hardcoded literals. No user input reaches
  // `_sendWebAsset` or `_cacheWebAssets`.
  Future<void> sendWebStyle() => _sendWebAsset('assets/web/style.css');
  Future<void> sendWebApp()   => _sendWebAsset('assets/web/bundle.js');

  // PRIVATE HELPER — `relativePath` is a *function parameter*, but its only
  // call sites pass string literals. The rule flags the `File(...)` below
  // because the parameter name `relativePath` appears in the interpolated
  // source — a pure syntactic match, no dataflow considered.
  Future<void> _sendWebAsset(String relativePath) async {
    final packageRoot = await _resolvePackageRoot();
    if (packageRoot == null) return;

    // expect_lint: avoid_path_traversal  ← FALSE POSITIVE
    final file = File('$packageRoot/$relativePath');
    if (await file.exists()) {
      await file.readAsString();
    }
  }

  // Also flagged: `packageRoot` is a parameter, and the path source contains
  // its name — even though the string after `packageRoot/` is a compile-time
  // constant literal.
  static Future<void> _cacheWebAssets(String packageRoot) async {
    // expect_lint: avoid_path_traversal  ← FALSE POSITIVE
    final cssFile = File('$packageRoot/assets/web/style.css');
    // expect_lint: avoid_path_traversal  ← FALSE POSITIVE
    final jsFile  = File('$packageRoot/assets/web/bundle.js');
    if (await cssFile.exists()) await cssFile.readAsString();
    if (await jsFile.exists())  await jsFile.readAsString();
  }

  // Resolver uses only Dart SDK APIs — no HTTP, no query params, no headers.
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
`platformPathApis` names.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The interpolated values come from (a) compile-time string literals passed by trusted call sites inside the same class, and (b) a package-root path resolved from `Isolate.resolvePackageUri` / `package_config.json`. Neither can carry `../` from an attacker. |
| **Actual** | `[avoid_path_traversal] File paths constructed from user input may allow path traversal attacks…` fires on all three `File(...)` sites. |

---

## AST Context

```
ClassDeclaration (AssetServer)
  └─ MethodDeclaration (_sendWebAsset)    ← enclosing method (private)
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

`isFromPlatformPathApi(node)` walks up to `_sendWebAsset`'s body, then — because
the method is private — walks every call site in the `ClassDeclaration`
(`sendWebStyle`, `sendWebApp`). None of those call-site bodies contain the
eight hard-coded names in `platformPathApis` (`getApplicationDocumentsDirectory`
et al.), so the escape hatch returns false.

---

## Root Cause

The detection in `runWithReporter` (lines ~2153–2192) is pure syntactic
substring matching with one narrow escape hatch:

1. Node is `File` or `Directory` construction — yes.
2. First-arg source contains `$` or `+` — yes (string interpolation).
3. Enclosing function has parameters, and at least one parameter *name*
   appears as a substring of the first-arg source — yes (`relativePath`,
   `packageRoot`).
4. `isFromPlatformPathApi(node)` — **false**, because the helper is called
   from `sendWebStyle`/`sendWebApp`, whose bodies contain neither
   `getApplicationDocumentsDirectory` nor any other name in the hard-coded
   `platformPathApis` set (`lib/src/platform_path_utils.dart` lines 13–22).
5. `_hasPathValidation(node)` — false (no `basename`, `isWithin`, etc. in the
   enclosing scope).

The rule equates "parameter name appears in the path string" with "user input
flows into the path." That assumption is wrong for two large classes of code:

- **Private helpers called only from same-class public methods that pass
  compile-time literals.** The rule's inter-procedural escape hatch already
  walks call sites for private methods — but it only accepts a caller as
  "trusted" if the caller's body contains one of eight hard-coded
  `path_provider` names. It does not accept a caller that simply passes a
  `StringLiteral` to the private method.
- **Parameters whose values come from trusted Dart-SDK resolvers** such as
  `Isolate.resolvePackageUri`, `Directory.systemTemp.path`,
  `Platform.resolvedExecutable`, `File.fromUri(...).path`, or
  `package_config.json` parsing. None of these are in `platformPathApis`, and
  none can be reached from an HTTP request parameter without the developer
  explicitly bridging them.

### Hypothesis A: widen `platformPathApis` to include trusted Dart-SDK resolvers

Adding `Isolate.resolvePackageUri`, `Directory.systemTemp`,
`Platform.resolvedExecutable`, `File.fromUri` would cover this case and
similar ones across the ecosystem. Low risk because these APIs genuinely
cannot carry an HTTP-origin `../` without developer-written bridging code.

### Hypothesis B: treat "all call sites pass literals" as trusted for private helpers

Extend the `_callerHasPlatformPathApi` inter-procedural check so that, for a
private method whose tainted parameter is `p`, the method is trusted if
**every** call site passes a literal (or a trusted-API expression) at `p`'s
position. This is a more general fix and avoids growing the `platformPathApis`
allowlist forever, but requires AST arg-position resolution.

### Hypothesis C: add a taint-source allowlist based on enclosing HTTP types

The real false-positive boundary is "did this string flow from
`HttpRequest.uri.queryParameters`, `HttpRequest.headers`, body JSON, etc.?"
The proper fix is a small taint-source analysis. Too large for this bug — but
the honest answer is that rule v8 is a heuristic and will keep producing
false positives without it.

---

## Suggested Fix

Shortest path that closes this specific false positive and stays proportional
to the rule's complexity: **Hypothesis A.**

1. In `lib/src/platform_path_utils.dart` (line 13), expand `platformPathApis`
   (or add a sibling set) to include trusted Dart-SDK path/resolver APIs:
   - `Isolate.resolvePackageUri` (method name `resolvePackageUri`)
   - `File.fromUri` (constructor name)
   - `Directory.fromUri`
   - `Directory.systemTemp`
   - `Platform.resolvedExecutable`
   - `Platform.script`
2. Update `bodyContainsPlatformPathApi` (line 25) to match these as
   substrings (consistent with the existing implementation).
3. Optionally: also accept when the private-helper call site passes a
   `StringLiteral` at the tainted parameter's position (Hypothesis B) — this
   is the more durable fix and covers the `_sendWebAsset('assets/web/...')`
   case directly, without relying on the resolver's name being in the
   allowlist.

Both rules share `isFromPlatformPathApi`, so fixing it once closes this bug
and its sibling (`require_file_path_sanitization_false_positive_internal_resolver_parameter.md`).

---

## Fixture Gap

The fixture at `example/lib/security/avoid_path_traversal_fixture.dart`
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

Shared with sibling bug [require_file_path_sanitization_false_positive_internal_resolver_parameter.md](require_file_path_sanitization_false_positive_internal_resolver_parameter.md) — a single edit to `lib/src/platform_path_utils.dart` closes both.

1. **Hypothesis A implemented** — `platformPathApis` widened in [lib/src/platform_path_utils.dart](../lib/src/platform_path_utils.dart) with trusted Dart-SDK resolver names: `resolvePackageUri`, `resolvedExecutable`, `systemTemp`, `Platform.script`, `Directory.current`, `File.fromUri`, `Directory.fromUri`. Substring-matched against body source, so qualified forms (`Isolate.resolvePackageUri`, `Directory.systemTemp.path`) match. Rationale: none of these APIs can carry HTTP-origin input without developer-written bridging code. Library-level dartdoc updated to document the two trust classes (Flutter `path_provider` and Dart-SDK resolvers).
2. **Hypothesis B implemented** — new helper `isParamPassedOnlyLiteralsAtCallSites(AstNode node, String paramName)` in the same file. For a private enclosing method, locates the tainted parameter's declared position (positional index OR named label), visits every call site within the same class (or compilation unit for top-level functions), and returns true only when at least one call site exists AND every call site passes a compile-time string literal (`SimpleStringLiteral`, all-literal `AdjacentStrings`, or a `StringInterpolation` whose `elements` are exclusively `InterpolationString` parts). Zero-call-site case deliberately returns false — we cannot prove all callers pass literals if we see none.
3. **Rule wiring** — `AvoidPathTraversalRule.runWithReporter` in [lib/src/rules/security/security_network_input_rules.dart](../lib/src/rules/security/security_network_input_rules.dart) (line 2192) invokes the new helper *after* the existing `isFromPlatformPathApi(node)` check, passing the already-computed `usedParam`. Early return if literal-only call sites are proven. `_checkForUnsanitizedPath` in [lib/src/rules/resources/file_handling_rules.dart](../lib/src/rules/resources/file_handling_rules.dart) (line 1816) gets the same wiring inside its per-parameter loop — `continue`s past the matched parameter instead of reporting.
4. **Regression guard preserved** — HTTP-origin taint still lints: a public function with a user-input parameter, a private helper reachable from a non-literal caller, and a private helper with zero observed call sites all fail both escape hatches and the rule reports as before.

---

## Tests Added

1. [example/lib/security/avoid_path_traversal_fixture.dart](../example/lib/security/avoid_path_traversal_fixture.dart) gains five regression cases documented inline as *"GOOD (v12.3.4 regression — internal-resolver-parameter false positive)"*:
   - `AssetServer` class — two private helpers (`_sendWebAsset`, `_cacheWebAssets`) whose every call site passes a `StringLiteral`, exercising Hypothesis B including the `_cacheWebAssets('/opt/my_pkg/root')` case. Resolver `_resolvePackageRoot` uses `Isolate.resolvePackageUri` + `File.fromUri` (Hypothesis A).
   - `fromPackageRoot` / `_openFromPackageRoot` — caller body contains `Isolate.resolvePackageUri` directly (Hypothesis A allowlist match via `resolvePackageUri`).
   - `fromSystemTemp` / `_openInTemp` — caller body contains `Directory.systemTemp` (allowlist match via `systemTemp`).
   - `fromResolvedExe` / `_openNearExe` — caller body contains `Platform.resolvedExecutable` (allowlist match via `resolvedExecutable`).
   - `badFromHttpQuery(String userInput)` — public function, `expect_lint: avoid_path_traversal` remains asserted. Proves the fix doesn't leak to HTTP-origin taint.
2. [example/lib/file_handling/require_file_path_sanitization_fixture.dart](../example/lib/file_handling/require_file_path_sanitization_fixture.dart) gains parallel cases plus a private-but-uncalled regression (`_badHttpQueryStillLints`) whose zero call sites fail the literal-only check and preserve the lint.
3. `test/security_rules_test.dart`, `test/file_handling_rules_test.dart`, `test/false_positive_fixes_test.dart`, and `test/fixture_lint_integration_test.dart` all pass (408/408 for the first three; 443/443 when run together with concurrency 2).

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 12.3.3
- Dart SDK version: (from consumer pubspec — Dart 3.x)
- custom_lint version: (from consumer pubspec)
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/generation_handler.dart` lines 225, 401, 410
