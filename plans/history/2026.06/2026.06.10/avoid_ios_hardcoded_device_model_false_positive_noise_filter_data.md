# BUG: `avoid_ios_hardcoded_device_model` — Fires on device-name DATA (email-signature noise list), not a runtime device check

**Status: Open**

Created: 2026-06-10
Rule: `avoid_ios_hardcoded_device_model`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line ~871)
Severity: False positive
Rule version: v3

---

## Summary

The rule flags any string literal matching `iPhone\d|iPad|iPod touch`, on the theory that the code branches on a hardcoded device model and will break on new releases. But the same regex matches device names that appear as **data** — e.g. an email-signature noise-filter list (`'sent from my iphone'`, `'sent from my ipad'`). That data is not a runtime device-capability check; it is a corpus of taglines to strip. New device releases do not break it; it is supposed to contain these literal strings.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_ios_hardcoded_device_model'" lib/src/rules/
# lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:849:    'avoid_ios_hardcoded_device_model',

# Negative — NOT in sibling repo
grep -rn "'avoid_ios_hardcoded_device_model'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:849`
**Rule class:** `AvoidIosHardcodedDeviceModelRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
abstract final class SignatureNoiseFilter {
  // A corpus of email-signature taglines to STRIP. These device names are
  // data, not a runtime device-capability branch. New devices do not break
  // anything — the list simply grows.
  static const List<String> _mobileTaglines = <String>[
    'sent from my iphone',  // LINT (false positive)
    'sent from my ipad',    // LINT (false positive)
    'sent from my android',
    // ...
  ];
}
```

Real site: `D:\src\contacts\lib\utils\contact\signature\signature_noise_filter.dart:12-14`.

**Frequency:** Always, for any string literal containing a device name, regardless of whether it is a runtime check or static data.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — these are noise-filter data literals, not a device-model branch. |
| **Actual** | `[avoid_ios_hardcoded_device_model] Hardcoded iOS device model detected...` reported on each matching list element. |

---

## AST Context

```
ClassDeclaration (SignatureNoiseFilter)
  └─ FieldDeclaration (static const List<String> _mobileTaglines)
      └─ ListLiteral
          └─ SimpleStringLiteral ('sent from my iphone')   ← node reported here
```

The literal is an element of a `const List<String>` field — never the operand of a comparison, switch, or device-detection call.

---

## Root Cause

`ios_platform_lifecycle_rules.dart:871-883`:

```dart
context.addSimpleStringLiteral((SimpleStringLiteral node) {
  final String value = node.value;
  // (skips test files)
  if (_deviceModelPattern.hasMatch(value)) {
    reporter.atNode(node);
  }
});
```

The rule reports on **any** `SimpleStringLiteral` whose value matches `_deviceModelPattern` (`\biPhone\s*\d+|\biPad\b...`). It performs no context analysis: it does not check whether the literal is used in a conditional/switch/equality against a `deviceModel`/`utsname`/`Platform` value (the actual anti-pattern), nor whether it is merely an element of a data collection. A noise-filter corpus, a test-asset manifest, a documentation string, or a localized message that mentions "iPad" all trip it identically.

The rule's own doc comment claims word-boundary matching "avoids substring false positives" — but that only prevents `tripadvisor`→`iPad`; it does nothing about a genuine device name sitting in a data list.

---

## Suggested Fix

Require a device-check context before reporting, instead of flagging bare literals. Report only when the matching literal is:

- an operand of a `BinaryExpression` (`==`/`!=`) or a `SwitchCase` expression, AND
- the other side / switch target resolves to a device-identity source (e.g. an identifier/member named `model`, `deviceModel`, `utsname`, `machine`, or a `Platform`/`DeviceInfo` access).

Literals that are elements of a `ListLiteral`/`SetOrMapLiteral` field, or arguments to string operations (`contains`, `startsWith`, `replaceAll`), are data and should be exempt. At minimum, exempt elements of a `const`/`static` collection field.

---

## Fixture Gap

`example*/lib/platforms/avoid_ios_hardcoded_device_model_fixture.dart` should include:

1. `if (device.model == 'iPhone 14') {...}` — expect LINT (runtime device branch).
2. `const taglines = ['sent from my iphone', 'sent from my ipad'];` — expect **NO** lint (data corpus).
3. `text.contains('iPad')` in a string-cleanup routine — expect **NO** lint.
4. A localized user-facing message mentioning "iPhone 15" — expect **NO** lint.

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/file: `D:\src\contacts\lib\utils\contact\signature\signature_noise_filter.dart:12-14`
