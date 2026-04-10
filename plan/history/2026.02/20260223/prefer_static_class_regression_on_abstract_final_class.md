# Bug: `prefer_static_class` still triggers on `abstract final class`

## Resolution

**Fixed.** Added `if (node.abstractKeyword != null) return;` early-return at top of the rule's handler. Abstract classes (including `abstract final`) are now skipped since they can't be instantiated and are the correct namespace pattern.

## Summary

`prefer_static_class` fires on classes already declared `abstract final`, contradicting the fix claimed in v5.0.0-beta.15 changelog:

> **Fixed** - prefer_static_class: conflicting diagnostic with prefer_abstract_final_static_class -- static-only classes that are abstract final no longer trigger prefer_static_class

The conflict between `prefer_abstract_final_static_class` ("make it `abstract final`") and `prefer_static_class` ("don't use a class at all") persists. Following one rule's advice guarantees violating the other.

## Reproduction

**analysis_options.yaml** (both rules enabled):

```yaml
saropa_lints: ^5.0.0-beta.15

# ...
prefer_abstract_final_static_class: true
prefer_static_class: true
```

**Minimal reproducing code:**

```dart
abstract final class Base64Utils {
  static String? compressText(String value) => /* ... */;
}
```

**All 6 affected locations in `saropa_dart_utils`:**

| # | File | Line | Class |
|---|------|------|-------|
| 1 | `lib/base64/base64_utils.dart` | 18 | `Base64Utils` |
| 2 | `lib/datetime/date_constants.dart` | 13 | `DateConstants` |
| 3 | `lib/datetime/date_constants.dart` | 109 | `MonthUtils` |
| 4 | `lib/datetime/date_constants.dart` | 156 | `WeekdayUtils` |
| 5 | `lib/datetime/date_constants.dart` | 193 | `SerialDateUtils` |
| 6 | `lib/datetime/date_time_utils.dart` | 10 | `DateTimeUtils` |

**Diagnostic message produced:**

```
[prefer_static_class] Class contains only static members and acts as a namespace.
Static-only classes cannot be instantiated meaningfully, add unnecessary boilerplate,
and prevent tree-shaking of unused members in the class. {v6}
Replace with top-level functions and constants...
```

## Expected behavior

`prefer_static_class` should **not** fire when a class is declared `abstract final`, because:

1. The v5.0.0-beta.15 changelog explicitly states this conflict was fixed.
2. `abstract final class` is the Dart-recommended idiom for non-instantiable namespace classes (prevents both instantiation and subclassing).
3. `prefer_abstract_final_static_class` actively directs users to adopt this pattern -- the two rules must not conflict.

## Actual behavior

`prefer_static_class` fires on all 6 `abstract final class` declarations with severity **Warning**, producing the same diagnostic as for plain `class` declarations. The `abstract final` modifiers are not detected or not checked.

## Root cause analysis

The `prefer_static_class` rule (v6) does not appear to check for `abstract final` class modifiers before reporting. The fix described in the v5.0.0-beta.15 changelog is either:

- Not applied to the v6 revision of the rule
- Checking for the modifiers incorrectly (e.g., checking for `abstract` and `final` separately rather than together, or checking AST node properties that differ between Dart language versions)
- Overridden by a later rule revision that reintroduced the conflict

## Environment

- **saropa_lints version:** 5.0.0-beta.15
- **Severity:** 2 (Warning)
- **OS:** Windows 11 Pro 10.0.22631
- **Dart SDK constraint:** >=3.9.0 <4.0.0
- **Flutter constraint:** >=3.41.2
- **Consuming package:** saropa_dart_utils 1.0.7
