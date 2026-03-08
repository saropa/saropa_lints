# Bug: `prefer_switch_statement` false positive on getter/method switch expressions

**Status:** Fixed (v2)
**Rule:** `prefer_switch_statement`
**Severity:** False positive — flags valid code that should not trigger
**Plugin version:** saropa_lints v8.0.7 (professional tier)
**Fixed in:** v8.0.9+

## Resolution

Added `_isValuePositionSwitch()` to skip switch expressions in value-producing
positions: arrow bodies (`=> switch (...)`), return statements, variable
initializers, assignments, and yield statements. Rule now only fires for
non-value positions (collection literals, function arguments) where a switch
statement would genuinely be clearer.

## Original Problem

The rule flagged **every** switch expression unconditionally, including the
idiomatic Dart 3 enum-to-value mapping pattern (`=> switch (this) { ... }`).
This contradicted `prefer_returning_shorthands` and generated noise on every
enum extension getter.

## Reproduction

```dart
extension CardTypeExt on CardType {
  String get label => switch (this) {  // was falsely flagged
    CardType.frame => 'Frame',
    CardType.payload => 'Payload',
    CardType.algorithm => 'Algorithm',
  };
}
```
