# Bug: `require_deep_link_fallback` false positive on lazy-loading `Uri?` getter

## Summary

The `require_deep_link_fallback` rule incorrectly flags `Uri? get uri => _uri ??= UrlUtilsLocal.getSecureUriFromUrl(url);` as a deep link handler missing fallback. This is a simple lazy-loading cached getter on a data model class (`SocialMediaItem`), not a deep link handler. Two existing exclusions should have prevented this but both appear to be failing.

## Severity

**Medium** -- INFO-level false positive on a common data model pattern. The getter is a lazy-loading property cache, not navigation/deep-link handling code.

## Affected Rule

- **Rule**: `require_deep_link_fallback`
- **File**: `lib/src/rules/navigation_rules.dart` (lines 865-1037)
- **Detection path**: `addMethodDeclaration` handler matches method name containing `"uri"`, then checks for fallback patterns

## Reproduction

### Triggering code (from `contacts` project)

File: `lib/models/web/social_media_item.dart` (line 433)

```dart
class SocialMediaItem extends BaseModel {
  String? url;

  Uri? _uri;

  Uri? get uri => _uri ??= UrlUtilsLocal.getSecureUriFromUrl(url);
}
```

### Expected behavior

No lint warning. This is a lazy-loading getter that caches a `Uri?` computed from a URL string. It has nothing to do with deep link handling.

### Actual behavior

```
require_deep_link_fallback: Deep link handler should handle missing/invalid content.
Add fallback for when linked content is not found or unavailable.
```

## Root Cause Analysis

Two exclusions in the rule should have prevented this false positive, but both are failing:

### Exclusion 1: Return type check (lines 904-910)

```dart
final String? returnTypeStr = node.returnType?.toSource();
if (returnTypeStr != null) {
  final String trimmed = returnTypeStr.replaceAll('?', '').trim();
  if (trimmed == 'String' || trimmed == 'Uri') {
    return;
  }
}
```

The getter `Uri? get uri` has an explicit return type of `Uri?`. After stripping `?`, `trimmed` should equal `"Uri"`, which should trigger the early return. **This exclusion should work but appears to not be firing.**

Possible cause: For Dart getters declared as `Uri? get uri => ...`, `node.returnType` may behave differently than for regular methods in the analyzer AST. The `get` keyword may affect how the return type annotation node is parsed. Needs investigation to determine if `node.returnType` is `null` for getters in the version of `analyzer` used by `custom_lint`.

### Exclusion 2: Lazy-loading `??=` pattern (lines 954-958)

```dart
// Lazy-loading pattern: _field ??= value
if (expr is AssignmentExpression &&
    expr.operator.type == TokenType.QUESTION_QUESTION_EQ) {
  return;
}
```

The expression `_uri ??= UrlUtilsLocal.getSecureUriFromUrl(url)` is an `AssignmentExpression` with `TokenType.QUESTION_QUESTION_EQ`. **This exclusion should also work.**

Possible cause: The `ExpressionFunctionBody` check on line 947 (`if (body is ExpressionFunctionBody)`) might not match if the analyzer wraps getter bodies differently. Or the `MethodInvocation` check on lines 962-970 might be running first and short-circuiting before the `??=` check — but the `??=` check is sequenced before the `MethodInvocation` check, so this shouldn't happen.

### Most likely root cause

The `ExpressionFunctionBody` block (lines 947-991) may not be reached because `body` is not classified as `ExpressionFunctionBody` for this getter. If the body type doesn't match, execution falls through to the string-based fallback check on lines 1019-1027. The body source `_uri ??= UrlUtilsLocal.getSecureUriFromUrl(url)` does not contain any of the fallback keywords (`NotFound`, `404`, `error`, `null)`, `return null`, `== null`, `isEmpty`, `try`, `catch`), so the rule reports a violation.

## Fixture Coverage Gap

The fixture file at `example/lib/navigation/require_deep_link_fallback_fixture.dart` line 81 tests:

```dart
// OK: Lazy-loading pattern - not a handler
Uri? get uri => _initialUri ??= Uri.parse(_url);
```

This uses `Uri.parse()` — a constructor-like static method on `Uri` itself. The real-world code uses `UrlUtilsLocal.getSecureUriFromUrl(url)` — a static method on a utility class. Both should produce the same AST structure. If the fixture test passes but the real code fails, the difference may be in class context (the fixture class is `DeepLinkStateManager` while the real class is `SocialMediaItem`) or in how the analyzer resolves types across packages.

## Suggested Fix

### Option A: Add broader getter exclusion (recommended)

Any `Uri?` getter on a data model class is unlikely to be a deep link handler. Add a check early in the method:

```dart
// Skip all getters that return Uri? or String? — these are data accessors, not handlers
if (node.isGetter) {
  final String? returnTypeStr = node.returnType?.toSource();
  if (returnTypeStr != null) {
    final String trimmed = returnTypeStr.replaceAll('?', '').trim();
    if (trimmed == 'String' || trimmed == 'Uri') {
      return;
    }
  }
  // Also skip short getter names (1-3 chars like "uri", "url")
  // These are always data properties, not deep link handlers
  if (methodName.length <= 3) {
    return;
  }
}
```

### Option B: Debug the existing exclusions

Add logging to determine which exclusion path is failing:
1. Is `node.returnType` null for this getter?
2. Is `body is ExpressionFunctionBody` false for this getter?
3. Is the `??=` check reached and if so, is `expr is AssignmentExpression` true?

### Option C: Add `??=` detection to the string-based fallback check

As a safety net, add `??=` to the fallback pattern strings on line 1019:

```dart
final bool hasFallback = bodySource.contains('NotFound') ||
    bodySource.contains('404') ||
    bodySource.contains('error') ||
    bodySource.contains('null)') ||
    bodySource.contains('return null') ||
    bodySource.contains('== null') ||
    bodySource.contains('??=') ||   // <-- lazy-loading is inherently safe
    bodySource.contains('isEmpty') ||
    bodySource.contains('try') ||
    bodySource.contains('catch');
```

## Additional False Positive Risk

The name-matching heuristic on line 895 (`methodName.contains('uri')`) is very broad. Any data model with a `Uri` property (getter, method, etc.) whose name contains "uri" will be evaluated by this rule. Consider narrowing the trigger to methods that also contain navigation-related terms like `handle`, `navigate`, `route`, `open`, `launch`, or `process`.

## Test Case to Add

```dart
// FALSE POSITIVE TEST: Lazy-loading getter with utility method call
class SocialMediaModel {
  String? url;
  Uri? _uri;

  // OK: Lazy-loading getter using utility class - not a handler
  Uri? get uri => _uri ??= UrlUtilsLocal.getSecureUriFromUrl(url);
}

class UrlUtilsLocal {
  static Uri? getSecureUriFromUrl(String? url) => Uri.tryParse(url ?? '');
}
```
