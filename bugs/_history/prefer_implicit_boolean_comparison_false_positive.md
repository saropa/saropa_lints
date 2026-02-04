# Bug: `prefer_implicit_boolean_comparison` false positive on nullable booleans

## Summary

The `prefer_implicit_boolean_comparison` rule fires on `== true` and `== false`
comparisons where the left operand is a **nullable** `bool?`. In these cases the
explicit comparison is semantically necessary — removing it either changes
behaviour or produces a compile error. The rule should only fire when the left
operand is a non-nullable `bool`.

## Severity

**Warning shown, no valid fix exists.** Following the lint advice introduces
compile errors (`!nullableBool` does not compile) or changes runtime semantics
(treating `null` the same as `false`/`true`). Users must add `// ignore` comments
or write worse code.

## Reproduction

### Case 1: Nullable field — `== false`

```dart
class IconButtonOptions {
  final bool? isAnimated;
  const IconButtonOptions({this.isAnimated});
}

void example(IconButtonOptions options) {
  // LINT FIRES HERE — but removing `== false` is a compile error
  if (options.isAnimated == false) {
    // Only enters when isAnimated is explicitly false, NOT when null
  }
}
```

Removing the comparison:

```dart
// Option A: Compile error — `!` cannot be applied to `bool?`
if (!options.isAnimated) { ... }

// Option B: Changes semantics — null now treated as false
if (!(options.isAnimated ?? true)) { ... }

// Option C: Verbose, not cleaner
if (options.isAnimated != null && !options.isAnimated!) { ... }
```

None of these are equivalent to the original `== false`.

### Case 2: Tristate checkbox — `== true` and `== false`

```dart
class CheckboxWidget {
  final bool? value; // null = indeterminate, true = checked, false = unchecked

  void onTap() {
    // LINT FIRES on both comparisons — but these are a 3-way branch on bool?
    if (value == true) {
      handleChecked();
    } else if (value == false) {
      handleUnchecked();
    } else {
      handleIndeterminate(); // value is null
    }
  }
}
```

### Case 3: Null-aware method call — `?.method() == true`

```dart
class SpecialHolidayTypeEnum {
  final List<String>? nameAlternates;
  // ...
}

void example(SpecialHolidayTypeEnum holiday, String name) {
  // LINT FIRES — but `?.contains()` returns `bool?`, not `bool`
  if (holiday.nameAlternates?.contains(name) == true) {
    // Only enters when list is non-null AND contains the name
  }
}
```

The `?.` operator makes `contains()` return `bool?`. Removing `== true` is a
compile error.

## Real-world occurrences

Found in the `contacts` project across 3 files, 6 warnings:

| File | Line | Expression | Type |
|------|------|-----------|------|
| `common_icon_button.dart` | 196 | `options.isAnimated == false` | `bool?` field |
| `common_checkbox_list_tile.dart` | 128 | `value == true` | `bool?` tristate |
| `common_checkbox_list_tile.dart` | 130 | `value == false` | `bool?` tristate |
| `today_islamic_prayer_times_information.dart` | 483 | `.nameAlternates?.contains(holidayName) == true` | `?.` → `bool?` |
| `today_islamic_prayer_times_information.dart` | 488 | `.nameAlternates?.contains(holidayName) == true` | `?.` → `bool?` |
| `today_islamic_prayer_times_information.dart` | 490 | `.nameAlternates?.contains(holidayName) == true` | `?.` → `bool?` |

## Root cause

File: `lib/src/rules/stylistic_additional_rules.dart`

**Lines 1402-1409** — the detection logic only checks whether the right operand is
a `BooleanLiteral`, without inspecting the static type of the left operand:

```dart
context.registry.addBinaryExpression((node) {
  if (node.operator.lexeme != '==' && node.operator.lexeme != '!=') return;

  final right = node.rightOperand;
  if (right is BooleanLiteral) {
    reporter.atNode(node, code);  // <-- fires regardless of left operand type
  }
});
```

The rule makes no distinction between:
- `nonNullBool == true` (redundant, should lint)
- `nullableBool == true` (necessary, should NOT lint)

## Internal contradiction

The fixture file (`example/lib/stylistic/stylistic_v270_fixture.dart`) documents
at lines 425-428 that `isValid == true` on a `bool?` is the **GOOD** pattern for
the sibling rule `prefer_explicit_boolean_comparison`:

```dart
// GOOD: Explicit == true for nullable
bool checkNullableExplicit(bool? isValid) {
  return isValid == true;  // <-- GOOD per prefer_explicit_boolean_comparison
}
```

But `prefer_implicit_boolean_comparison` fires on this same code, telling the user
to remove the `== true`. The two rules directly conflict on nullable booleans.
Enabling both rules simultaneously creates an unresolvable lint loop on any
`bool?` comparison.

## Suggested fix

Check the **static type** of the left operand before reporting. Only lint when the
type is non-nullable `bool`:

```dart
@override
void runWithReporter(
  CustomLintResolver resolver,
  SaropaDiagnosticReporter reporter,
  CustomLintContext context,
) {
  context.registry.addBinaryExpression((node) {
    if (node.operator.lexeme != '==' && node.operator.lexeme != '!=') return;

    final right = node.rightOperand;
    if (right is! BooleanLiteral) return;

    // Do NOT lint nullable booleans — the comparison is semantically necessary
    final leftType = node.leftOperand.staticType;
    if (leftType == null || leftType.nullabilitySuffix != NullabilitySuffix.none) {
      return;
    }

    reporter.atNode(node, code);
  });
}
```

This requires importing `NullabilitySuffix` from `package:analyzer/dart/element/type.dart`.

## Decision table after fix

| Expression | Left type | Currently reports | Should report |
|-----------|-----------|:-:|:-:|
| `isValid == true` | `bool` | Yes | Yes |
| `isValid == false` | `bool` | Yes | Yes |
| `isValid != true` | `bool` | Yes | Yes |
| `isValid != false` | `bool` | Yes | Yes |
| `isValid == true` | `bool?` | Yes | **No** |
| `isValid == false` | `bool?` | Yes | **No** |
| `list?.contains(x) == true` | `bool?` | Yes | **No** |
| `map?.containsKey(k) == false` | `bool?` | Yes | **No** |

## Test fixture updates

Add these cases to `example/lib/stylistic/stylistic_v270_fixture.dart` inside the
`BooleanComparisonExamples` class:

```dart
// GOOD: Nullable bool requires explicit comparison — NOT a lint violation
bool checkNullableTrue(bool? isValid) {
  if (isValid == true) {
    return true;
  }
  return false;
}

// GOOD: Nullable bool == false (distinct from null)
bool checkNullableFalse(bool? isValid) {
  return isValid == false;
}

// GOOD: Null-aware chain produces bool? — explicit comparison required
bool checkNullAwareChain(List<String>? items, String target) {
  return items?.contains(target) == true;
}

// GOOD: Tristate logic — all three branches are meaningful
String checkTristate(bool? value) {
  if (value == true) return 'yes';
  if (value == false) return 'no';
  return 'unknown';
}

// BAD: Non-nullable bool — comparison IS redundant (should still lint)
// expect_lint: prefer_implicit_boolean_comparison
bool checkNonNullableStillLints(bool isValid) {
  return isValid == true;
}
```
