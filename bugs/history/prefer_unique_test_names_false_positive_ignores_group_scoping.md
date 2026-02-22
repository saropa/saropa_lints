# Bug: `prefer_unique_test_names` false positive — ignores group() scoping

## Summary

The `prefer_unique_test_names` rule flags tests as duplicates when they share the same local name but live in different `group()` blocks. Flutter's test runner prepends group names to produce fully-qualified test names, so these tests are **not** duplicates at runtime. The rule compares bare `test()` name strings within a file without accounting for the enclosing group hierarchy.

## Impact

**410 false positives** across 29 test files in this project alone. The highest-hit files:

| File | FP count |
|------|------:|
| `string_extensions_test.dart` | 81 |
| `string_case_extensions_test.dart` | 54 |
| `date_time_extensions_test.dart` | 46 |
| `string_search_extensions_test.dart` | 42 |
| `string_character_extensions_test.dart` | 22 |
| `string_between_extensions_test.dart` | 22 |
| `num_extensions_test.dart` | 22 |
| `date_constants_test.dart` | 21 |
| *(21 more files)* | 100 |

This is the **single largest source of false positives** in the entire lint suite for this project.

## Reproduction

### Case 1: `base64_utils_test.dart`

```dart
void main() {
  group('Base64Utils', () {
    group('compressText', () {
      test('returns null for null input', () {       // line 15
        expect(Base64Utils.compressText(null), isNull);
      });

      test('returns null for empty string', () {     // line 19
        expect(Base64Utils.compressText(''), isNull);
      });
    });

    group('decompressText', () {
      test('returns null for null input', () {       // line 52 — FLAGGED
        expect(Base64Utils.decompressText(null), isNull);
      });

      test('returns null for empty string', () {     // line 56 — FLAGGED
        expect(Base64Utils.decompressText(''), isNull);
      });
    });
  });
}
```

**Fully-qualified names at runtime:**
- `Base64Utils compressText returns null for null input`
- `Base64Utils decompressText returns null for null input`

These are **different tests** with **different fully-qualified names**. The rule incorrectly flags lines 52 and 56.

### Case 2: `date_constants_test.dart`

```dart
group('MonthUtils', () {
  group('monthLongNames', () {
    test('1. January', () => expect(MonthUtils.monthLongNames[1], 'January'));
    // ...
    test('13. Invalid month 0', () => expect(MonthUtils.monthLongNames[0], isNull));   // line 61
    test('14. Invalid month 13', () => expect(MonthUtils.monthLongNames[13], isNull)); // line 62
    test('15. Has 12 entries', () => expect(MonthUtils.monthLongNames, hasLength(12)));  // line 63
  });

  group('monthShortNames', () {
    test('1. Jan', () => expect(MonthUtils.monthShortNames[1], 'Jan'));
    // ...
    test('13. Invalid month 0', () => expect(MonthUtils.monthShortNames[0], isNull));   // line 79 — FLAGGED
    test('14. Invalid month 13', () => expect(MonthUtils.monthShortNames[13], isNull)); // line 80 — FLAGGED
    test('15. Has 12 entries', () => expect(MonthUtils.monthShortNames, hasLength(12)));  // line 81 — FLAGGED
  });
});
```

**Fully-qualified names:**
- `MonthUtils monthLongNames 13. Invalid month 0`
- `MonthUtils monthShortNames 13. Invalid month 0`

Again, different groups → different fully-qualified names → **not duplicates**.

### Case 3: `bool_iterable_extensions_test.dart`

```dart
group('anyTrue', () {
  test('returns true for list with alternating true and false elements', () { ... });
  // ...
});

group('anyFalse', () {
  test('returns true for list with alternating true and false elements', () { ... }); // FLAGGED
  // ...
});
```

Testing the same behavioral pattern ("alternating elements") across symmetric methods (`anyTrue` / `anyFalse`) is idiomatic. The group names disambiguate them.

## Why this pattern is standard practice

Reusing descriptive test names across groups is the **recommended Flutter testing convention**:

```dart
group('compressText', () {
  test('returns null for null input', () { ... });
  test('handles empty string', () { ... });
  test('handles unicode', () { ... });
});

group('decompressText', () {
  test('returns null for null input', () { ... });   // Same name, different group — idiomatic
  test('handles empty string', () { ... });           // Same name, different group — idiomatic
  test('handles unicode', () { ... });                // Same name, different group — idiomatic
});
```

This pattern is clear, consistent, and produces unambiguous output:
```
✓ compressText returns null for null input
✓ decompressText returns null for null input
```

Forcing globally-unique names within a file would produce verbose, redundant names like:
```dart
test('compressText returns null for null input', () { ... });
test('decompressText returns null for null input', () { ... });
```

This duplicates the group name inside the test name, violating DRY and adding noise.

## Root cause

The rule collects all `test()` name strings in a file and checks for duplicates using only the bare string argument, without walking up the AST to resolve enclosing `group()` names.

The correct approach is to build the fully-qualified test name by concatenating all enclosing `group()` names with the `test()` name, separated by spaces (matching Flutter's test runner behavior), and only flag tests whose fully-qualified names collide.

## Suggested fix

When visiting a `test()` invocation, walk up the AST to collect enclosing `group()` names and build the fully-qualified name:

```dart
String _getFullyQualifiedTestName(MethodInvocation testNode) {
  final parts = <String>[];

  // Walk up the AST collecting group names
  AstNode? current = testNode.parent;
  while (current != null) {
    if (current is MethodInvocation && current.methodName.name == 'group') {
      final groupName = _extractStringLiteral(current.argumentList.arguments.first);
      if (groupName != null) {
        parts.insert(0, groupName);
      }
    }
    current = current.parent;
  }

  // Add the test name itself
  final testName = _extractStringLiteral(testNode.argumentList.arguments.first);
  if (testName != null) parts.add(testName);

  return parts.join(' ');
}
```

Then compare fully-qualified names instead of bare test names:

```dart
// Before (broken):
final testNames = <String>{};
// ... if testNames.contains(name) → report duplicate

// After (correct):
final fullyQualifiedNames = <String>{};
final fqName = _getFullyQualifiedTestName(node);
if (fullyQualifiedNames.contains(fqName)) {
  reporter.atNode(node, code);
}
fullyQualifiedNames.add(fqName);
```

## What should still be flagged

Tests with the same name in the **same group** are genuine duplicates:

```dart
group('compressText', () {
  test('handles null', () { ... });
  test('handles null', () { ... });  // ← TRUE duplicate, should be flagged
});
```

Tests with the same name at the **top level** (no group) are also genuine duplicates:

```dart
void main() {
  test('handles null', () { ... });
  test('handles null', () { ... });  // ← TRUE duplicate, should be flagged
}
```

## Test fixture updates

Add cases that must NOT trigger the lint:

```dart
// GOOD: Same test name in different groups — fully-qualified names differ
void main() {
  group('encrypt', () {
    test('returns null for null input', () {
      expect(encrypt(null), isNull);
    });
  });

  group('decrypt', () {
    test('returns null for null input', () {  // NOT a duplicate
      expect(decrypt(null), isNull);
    });
  });
}
```

Add cases that MUST trigger the lint:

```dart
// BAD: Same test name in the SAME group — true duplicate
void main() {
  group('encrypt', () {
    test('returns null for null input', () {
      expect(encrypt(null), isNull);
    });
    test('returns null for null input', () {  // TRUE duplicate
      expect(encrypt(null), isNull);
    });
  });
}
```

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **IDE:** VS Code
- **Rule version:** v5
- **saropa_lints version:** (current)
- **Dart SDK:** (current stable)
- **Project:** saropa_dart_utils (29 test files, 410 violations)
---

## Resolution

**Fixed in v5.0.0 (rule v6).** Rewrote `_UniqueTestNameVisitor` to track `group()` nesting via a stack and build fully-qualified test names by joining group hierarchy with test name, matching Flutter's test runner behavior. Tests in different groups with the same local name are no longer flagged.
