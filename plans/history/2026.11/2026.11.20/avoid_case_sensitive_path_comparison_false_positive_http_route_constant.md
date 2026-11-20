# BUG: `avoid_case_sensitive_path_comparison` — False positive on HTTP API route constant comparison

**Status: Fixed**

Created: 2026-11-20
Rule: `avoid_case_sensitive_path_comparison`
File: `lib/src/rules/platforms/windows_rules.dart` (line ~416)
Severity: False positive
Rule version: v17.2.0

---

## Summary

The rule fires on a comparison between a local `path` variable (derived from `HttpRequest.uri.path`) and a `static const String` route constant (e.g. `ServerConstants.pathApiSchemaDeclaredAlt`). These are HTTP API route strings, not filesystem paths — URL paths are case-sensitive per RFC 3986, so the exact `==` comparison is correct.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_case_sensitive_path_comparison'" lib/src/rules/
# lib/src/rules/platforms/windows_rules.dart:417:    'avoid_case_sensitive_path_comparison',
```

```bash
# Negative — rule is NOT in saropa_drift_advisor
grep -rn "'avoid_case_sensitive_path_comparison'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/platforms/windows_rules.dart:417`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropaLintsLsp`

---

## Reproducer

Minimal structure from `saropa_drift_advisor/lib/src/server/router.dart`:

```dart
import 'dart:io';

class ServerConstants {
  // HTTP API route paths — NOT filesystem paths
  static const String pathApiSchemaDeclared = '/api/schema/declared';
  static const String pathApiSchemaDeclaredAlt = 'api/schema/declared';
}

class Router {
  Future<void> _dispatch(HttpRequest request) async {
    final req = request;
    final String path = req.uri.path; // from HTTP request URI

    // LINT reported here — but should NOT lint (false positive)
    // These are URL route paths, case-sensitive by RFC 3986
    if (path == ServerConstants.pathApiSchemaDeclared ||
        path == ServerConstants.pathApiSchemaDeclaredAlt) { // LINT — wrong
      // handle route
    }
  }
}
```

**Frequency:** Always — fires on every route-matching comparison in the router. At least 6 occurrences in `router.dart` (lines 784–785, 795–796, and similar pairs throughout the file).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `path` is derived from `HttpRequest.uri.path` (an HTTP route, not a filesystem path), and the constant is a URL route string |
| **Actual** | `[avoid_case_sensitive_path_comparison] File path compared without case normalization. Windows filesystem is case-insensitive. {v3}` reported at line 785 |

---

## AST Context

```
MethodDeclaration (_dispatch)
  └─ Block
      └─ VariableDeclarationStatement: final req = request;
      └─ VariableDeclarationStatement: final String path = req.uri.path;
      ... (~640 lines of route-matching if-chains) ...
      └─ IfStatement
          └─ BinaryExpression (||)
              └─ BinaryExpression (==)
              │   └─ SimpleIdentifier (path)         ← left operand
              │   └─ PrefixedIdentifier (ServerConstants.pathApiSchemaDeclared)
              └─ BinaryExpression (==)
                  └─ SimpleIdentifier (path)         ← left operand, flagged
                  └─ PrefixedIdentifier (ServerConstants.pathApiSchemaDeclaredAlt)
                      ↑ name contains "path" → _containsPathPattern fires
```

---

## Root Cause

Two contributing factors — either one would suppress the false positive if fixed:

### Hypothesis A: `_isUriPathAccess` local-variable tracing doesn't reach distant declarations

The `_findLocalDeclaration` method (line ~709) searches for the local variable declaration in enclosing blocks. The variable `path` is declared at line 147 and used at line 785 — roughly 640 lines apart within the same method body, possibly with many intermediate nested blocks (if-chains, try-catch). If `_findLocalDeclaration` stops searching at a nesting boundary or has a depth/distance limit, it won't find the initializer `req.uri.path`, so the `_isUriPathAccess` exemption never fires.

The chain if fully traced would be: `path` → `req.uri.path` → `req` has `staticType` `HttpRequest` (dart:io) → `_isHttpRequestUri` → true → exempt.

### Hypothesis B: `static const` route constants with "path" in the name trigger `_containsPathPattern` on the right operand

The right operand `ServerConstants.pathApiSchemaDeclaredAlt` contains "path" as a camelCase word component in `pathApiSchemaDeclaredAlt`. The `_containsPathPattern` heuristic fires because the identifier name contains "path". But a `static const String` whose value is a URL route segment (`'api/schema/declared'`) is not a filesystem path. The rule currently has no exemption for string constants whose values lack filesystem path separators (`/` on Unix, `\` on Windows) when the value is a URL route.

Note: `_isNonPathStringLiteral` (line 460) only exempts **string literals** that lack a path separator — it does not exempt `static const` references whose **resolved value** lacks a path separator.

### Both hypotheses are actionable

Fix A alone (make `_isUriPathAccess` tracing work over distance) would suppress the specific case where the left operand is known to be an HTTP route. Fix B alone (don't trigger `_containsPathPattern` on static const identifiers whose resolved literal value contains no separator) would suppress the broader class of URL-route-constant comparisons. Ideally both.

---

## Suggested Fix

**Option 1 (narrow):** Ensure `_findLocalDeclaration` can reach declarations at any distance within the same method body, or add a type-based fallback: when the `SimpleIdentifier`'s initializer traces to a `Uri.path` access on an `HttpRequest`, exempt regardless of hop count.

**Option 2 (broader):** In `_containsPathPattern` or at the call site, when the operand is a `PrefixedIdentifier` referencing a `static const String` field, resolve its constant value and apply the `_isNonPathStringLiteral` check to that value. A constant like `'api/schema/declared'` or `'/api/schema/declared'` with only forward slashes and no backslashes, drive letters, or OS path separators is a URL route, not a filesystem path.

**Option 3 (complementary):** Extend `_isUriPathAccess` to recognize a broader "HTTP route context" — when the enclosing method's parameter list includes an `HttpRequest` parameter and the local is demonstrably derived from request URI parsing, exempt it.

---

## Fixture Gap

The fixture should include:

1. **HTTP route comparison via local from `HttpRequest.uri.path`** — expect NO lint
2. **`static const String` route constant with "path" in the name but URL-route value** — expect NO lint
3. **Same pattern but with a distant declaration (100+ lines from use)** — expect NO lint
4. **Actual filesystem path stored in a variable named "path" compared to a constant** — expect LINT (ensure no regression)

---

## Actual Root Cause

Neither hypothesis in the original report was correct. The real issue: `_dispatch` extracts `path` from `request.uri.path` as a local, then passes it as a **`String` parameter** to `_routeSchemaApi(request, response, path, query)` and dozens of similar `_route*` methods. Inside those methods, `path` is a plain `String` parameter — `_isUriPathAccess` can only trace through local variable declarations (`_findLocalDeclaration`), not across method call boundaries to the call site. The parameter has no initializer to trace.

The scan CLI showed zero hits because `router.dart` line 10 has `// ignore_for_file: avoid_case_sensitive_path_comparison` (without the required `saropa_lints/` prefix), which the scan CLI honors but the IDE does not — hence the IDE shows the diagnostics.

## Fix

Added `_isHttpRouteHandlerParameter` to `_isUriPathAccess`: when the identifier is a formal parameter named exactly `path` and a sibling parameter in the same method has type `HttpRequest` (dart:io) or `Request` (package:shelf), the comparison is exempted. The check is narrow by design — only the name `path` qualifies, not `filePath` or `directoryPath`, and only real HTTP request types (verified by declaring library), not user-defined classes.

**File changed:** `lib/src/rules/platforms/windows_rules.dart` — `_isUriPathAccess` + new `_isHttpRouteHandlerParameter`.

---

## Tests Added

- **Fixture:** `example/lib/windows/avoid_case_sensitive_path_comparison_fixture.dart`:
  - `goodHttpRoutePathViaIntermediateReq` — intermediate `req` local + `static const` route
  - `goodRouteHandlerPathParameter` — `String path` param alongside `HttpRequest`
- **Unit tests in** `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`:
  - `does NOT fire when path is a String parameter alongside an HttpRequest parameter` — the actual false-positive pattern
  - `fires on a String path parameter WITHOUT an HttpRequest sibling` — soundness: no HttpRequest sibling → still lints
  - `fires on a String path parameter alongside a user-defined Request class` — soundness: fake Request → still lints
  - `does NOT fire on HttpRequest.uri.path via intermediate local compared to a static const route constant` — bonus coverage
  - `does NOT fire on HttpRequest.uri.path with 200+ intervening statements` — distance stress test
  - `does NOT fire on HttpRequest.uri.path local compared to a static const route constant` — bonus coverage

---

## Commits

<!-- Add commit hash when fix is committed. -->

---

## Environment

- saropa_lints version: 17.2.0
- Triggering project/file: `saropa_drift_advisor` v4.4.2 — `lib/src/server/router.dart:785`
- Diagnostic owner in Problems panel: `saropaLintsLsp`
