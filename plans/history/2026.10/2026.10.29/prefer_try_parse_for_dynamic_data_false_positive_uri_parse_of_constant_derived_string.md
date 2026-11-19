# BUG: `prefer_try_parse_for_dynamic_data` — Uri.parse On A String Built From Constants And Percent-Encoded Parts

**Status: Open**

Created: 2026-10-29
Rule: `prefer_try_parse_for_dynamic_data`
File: `lib/src/rules/data/json_datetime_rules.dart (line ~214)`
Severity: False positive

---

## Summary

The rule reports `Uri.parse('$constBase/path')` and `Uri.parse('scheme:///co?$query')` where `$query` is built from `Uri.encodeComponent` output. Neither string is dynamic or user-controlled in structure: the base is a `static const String`, the scheme/path are literals, and user data is percent-encoded, so the result is always a valid URI. `_isProvablyParseableArgument` only recognizes string literals, digit-only regex captures and regex-validated substrings.

---

## Attribution Evidence

```bash
grep -rn "'prefer_try_parse_for_dynamic_data'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:233:    'prefer_try_parse_for_dynamic_data',
# class PreferTryParseForDynamicDataRule (json_datetime_rules.dart:214)
```

---

## Reproducer

```dart
// Standalone, compiles with plain `dart`.
class Api {
  static const String _baseUrl = 'https://example.com/api/v3';

  static Uri insertUri() => Uri.parse('$_baseUrl/items/primary').replace( // LINT - should NOT lint
    queryParameters: <String, String>{'a': '1'},
  );

  static Uri composeUri(Map<String, String> params) {
    final String query = params.entries
        .map((MapEntry<String, String> e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return Uri.parse('app:///co?$query'); // LINT - should NOT lint
  }
}

void main() => print(Api.composeUri(<String, String>{'q': 'a b'}));
```
Project sources: `lib/service/google_calendar_api/google_calendar_event_insert_utils.dart:141` (base is `MainSettings.googleCalendarApiBaseUrl`, a `static const String`, line 233 of `lib/main_settings.dart`) and `lib/service/native_phone/native_email_utils.dart:361` (`_gmailComposeUri`).

**Frequency:** Always for `Uri.parse` with an interpolated string.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: argument is composed of compile-time constants, literal text and `Uri.encodeComponent` / `Uri.encodeQueryComponent` results |
| **Actual** | `[prefer_try_parse_for_dynamic_data] Using parse methods ... {v4}` at google_calendar_event_insert_utils.dart 141:29-76 and native_email_utils.dart 361:12-49 |

---

## AST Context

```
MethodDeclaration (insertUri)
  └─ ExpressionFunctionBody
      └─ MethodInvocation (.replace)
          └─ MethodInvocation (Uri.parse)      <- reported
              └─ ArgumentList
                  └─ StringInterpolation ('$_baseUrl/calendars/primary/events')
MethodDeclaration (_gmailComposeUri)
  └─ BlockFunctionBody > Block > ReturnStatement
      └─ MethodInvocation (Uri.parse)           <- reported
          └─ StringInterpolation ('googlegmail:///co?$query')
```

---

## Root Cause

`runWithReporter` (json_datetime_rules.dart:247-270) reports any `X.parse` with `X` in {int,double,num,BigInt,Uri} unless inside a `try` (`_isInsideTryCatch`, line 260) or `_isProvablyParseableArgument` (line 261; defined line 290). That helper accepts only `_isValidLiteralForParseType` (a plain `StringLiteral`; an interpolation is a `StringInterpolation`, so it fails), `_isDigitOnlyRegexCapture` and `_isRegexValidatedSubstring`. Interpolations whose parts are all constants or whose dynamic parts are percent-encoded never reach an exemption.

---

## Why the Code Is Correct

A `Uri` built from a constant base cannot be malformed. The dynamic portion in `_gmailComposeUri` is encoded by `Uri.encodeComponent`, which escapes every character that could make the string unparseable. Switching to `Uri.tryParse` would force a null branch that can never run.

---

## Affected Project Locations

`lib/service/google_calendar_api/google_calendar_event_insert_utils.dart` line 141; `lib/service/native_phone/native_email_utils.dart` line 361.

---

## Suggested Fix

In `_isProvablyParseableArgument`, for `parseType == 'Uri'`, accept a `StringInterpolation` when every interpolated expression is (a) a reference to a `const` variable / `static const` field, or (b) a call to `Uri.encodeComponent`, `Uri.encodeQueryComponent` or `Uri.encodeFull`, or (c) a local initialized from `.join` over mapped `Uri.encodeComponent` calls is out of scope (a) and (b) suffice for the first case; the second case is covered by also accepting a local variable whose initializer is such a join.

---

## Fixture Cases

```dart
// LINT expected
Uri a(String user) => Uri.parse(user);
Uri b(String host) => Uri.parse('https://$host/x');

// OK expected
const String base = 'https://example.com/api';
Uri c() => Uri.parse('$base/items');
Uri d(String v) => Uri.parse('app:///co?q=${Uri.encodeComponent(v)}');
```

---

## Environment

- saropa_lints: 17.0.1-beta.2 (installed in the downstream project); rule line numbers below read from the local checkout (pubspec 17.0.1-beta.3), where the cited logic is unchanged.
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Downstream project: Saropa Contacts (`/Users/craighathaway/Documents/src/contacts`), Flutter app.
- Diagnostic `source` / `owner` in Problems panel: `saropa_lints` / `saropaLintsLsp`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
