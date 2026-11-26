# prefer_try_parse_for_dynamic_data: false positive on Uri.parse of a static const class field interpolation

- **Status:** Fixed
- **Created:** 2026-11-25
- **Rule:** `prefer_try_parse_for_dynamic_data` {v4}
- **Version:** saropa_lints 17.9.1

## Summary

`Uri.parse('$_baseUrl/calendars/primary/events')` is flagged although `_baseUrl` is a `static const String` class field. The argument is a compile-time constant. `_isConstOrEncodedInterpolation` (lib/src/rules/data/json_datetime_rules.dart:305) is meant to exempt exactly this shape. It exempts the top-level const case in the fixture, but not a static const class field.

## Attribution Evidence

```
OK    prefer_try_parse_for_dynamic_data: defined at lib/src/rules/data/json_datetime_rules.dart:233
```

## Reproducer

```dart
abstract final class Settings {
  static const String apiBase = 'https://www.googleapis.com/calendar/v3';
}

abstract final class Client {
  static const String _baseUrl = Settings.apiBase;

  // LINT (current, wrong): argument is a const-only interpolation.
  // OK (expected): no diagnostic.
  static Uri insertUri() => Uri.parse('$_baseUrl/calendars/primary/events').replace(
    queryParameters: <String, String>{'sendUpdates': 'all'},
  );
}

const String _apiBase = 'https://example.com';
// OK (already exempt today, fixture line 54)
Uri goodConstBaseUri() => Uri.parse('$_apiBase/items');
```

## Expected vs Actual

- Expected: no diagnostic. Only compile-time constants are interpolated.
- Actual: ERROR diagnostic on the `Uri.parse(...)` call, live in the VS Code Problems panel (source `saropa_lints`).

## AST Context

`MethodInvocation(Uri.parse)` is the target of `MethodInvocation(replace)`. Its single argument is a `StringInterpolation` with one `InterpolationExpression(SimpleIdentifier _baseUrl)`. `_baseUrl` resolves to the implicit getter of a static const `FieldElement` whose initializer is a `PrefixedIdentifier` to another class's static const.

## Root Cause

Unknown. `_isConstReference` reads `e.element` and checks `PropertyAccessorElement.variable.isConst`. Two differences from the passing fixture exist: the identifier is a static class field (not top-level), and the call is the target of a `.replace(...)` chain. Which one defeats the check is not yet isolated. A third candidate: the scan path that feeds the Problems panel runs with `e.element == null`, which makes `_isConstReference` return false.

## Suggested Fix

Add the reproducer to the fixture, find which branch returns false, and make `_isConstReference` accept static const fields (getter of a const `FieldElement`). If `element` can be null in the scan path, fall back to the expression's constant value or report nothing.

## Fixture Gap

`example/lib/json_datetime/prefer_try_parse_for_dynamic_data_fixture.dart` covers only a top-level const (`_apiBase`). No case for a static const class field, a const aliasing another class's const, or `Uri.parse(...)` as the target of a method chain.

## Environment

- saropa_lints 17.9.1 (contacts `pubspec.yaml` `^17.9.1`)
- Consumer site: contacts `lib/service/google_calendar_api/google_calendar_event_insert_utils.dart:141`
- Windows 11, VS Code extension scan

---

## Finish Report (2026-11-26)

**Root cause:** the causes suspected above were mostly wrong. Neither the static class field nor the `.replace(...)` chain defeats the check; resolved analysis already handled both. The defect was the third candidate only: in the unresolved scan `element` is null, so every constant looked dynamic.

**Fix** (`lib/src/rules/data/json_datetime_rules.dart`, rule version v5): when there is no element, the reference is checked against `const` declarations in the same file (top-level, local, static field, `Type.name`), rejecting any binding that can shadow it. Imported constants cannot be proven and are still reported in the unresolved scan.

**Related, not fixed:** the fixture's existing GOOD cases `goodRegexGuardedSubstring` and `goodRegexCaptureGroup` still report, filed as `bugs/prefer_try_parse_for_dynamic_data_false_positive_regex_validated_inputs.md`.

Tests: `dart test test/rules/data/prefer_try_parse_const_uri_test.dart test/rules/data/json_datetime_rules_test.dart test/scan/fixture_lint_integration_test.dart` - passed.
