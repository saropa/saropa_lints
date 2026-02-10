# Bug: `prefer_edgeinsets_symmetric` false positive with unpaired sides

## Summary

The `prefer_edgeinsets_symmetric` rule fires a warning on `EdgeInsets.only()` calls
that have a symmetric pair (e.g. `top == bottom`) but also contain an unpaired side
(e.g. `right` without `left`). In these cases, `EdgeInsets.symmetric()` cannot
express the padding without chaining `.copyWith()`, making the "fix" longer and
less readable than the original.

## Severity

**Warning shown, no valid auto-fix available.** The auto-fix implementation already
correctly rejects this case (lines 483-485), but the detection logic (line 447)
does not, creating a lint warning that cannot be resolved without an `// ignore`
comment or writing worse code.

## Reproduction

```dart
// This triggers the lint:
Padding(
  padding: EdgeInsets.only(
    right: ThemeCommonSpace.Medium.size,
    top: ThemeCommonSpace.Large.size,
    bottom: ThemeCommonSpace.Large.size,
  ),
  child: Text('Hello'),
),
```

The rule detects `top == bottom` and reports the warning. But there is no clean
`EdgeInsets.symmetric()` replacement because `right` has no matching `left`.

The only alternatives are objectively worse:

```dart
// Option A: longer, two method calls, harder to read
EdgeInsets.symmetric(
  vertical: ThemeCommonSpace.Large.size,
).copyWith(
  right: ThemeCommonSpace.Medium.size,
),

// Option B: verbose, explicit zero
EdgeInsets.fromLTRB(
  0,
  ThemeCommonSpace.Large.size,
  ThemeCommonSpace.Medium.size,
  ThemeCommonSpace.Large.size,
),
```

Neither option is "more concise" than the original `EdgeInsets.only()`.

## Other triggering patterns

Any `EdgeInsets.only()` with 3 arguments where 2 form a matching pair:

```dart
EdgeInsets.only(left: 8, top: 16, bottom: 16)   // top == bottom, left unpaired
EdgeInsets.only(top: 8, left: 16, right: 16)     // left == right, top unpaired
EdgeInsets.only(bottom: 8, left: 16, right: 16)  // left == right, bottom unpaired
EdgeInsets.only(right: 8, top: 16, bottom: 16)   // top == bottom, right unpaired
```

## Root cause

File: `lib/src/rules/stylistic_widget_rules.dart`

**Detection logic (line 443-449)** only checks if any pair is symmetric:

```dart
final horizontalSymmetric =
    left != null && right != null && left == right;
final verticalSymmetric = top != null && bottom != null && top == bottom;

if (horizontalSymmetric || verticalSymmetric) {
  reporter.atNode(node, code);  // <-- fires even with unpaired sides
}
```

**Fix logic (lines 483-485)** correctly rejects unpaired sides:

```dart
// Reject unpaired sides (e.g., left without right)
if ((left == null) != (right == null)) return;
if ((top == null) != (bottom == null)) return;
```

The mismatch means: warning fires, but auto-fix is not offered.

## Suggested fix

Add the same unpaired-side check to the detection logic before reporting:

```dart
final horizontalSymmetric =
    left != null && right != null && left == right;
final verticalSymmetric = top != null && bottom != null && top == bottom;

// Do not report if there are unpaired sides that cannot be expressed
// with EdgeInsets.symmetric() alone
final hasUnpairedHorizontal = (left == null) != (right == null);
final hasUnpairedVertical = (top == null) != (bottom == null);

if ((horizontalSymmetric || verticalSymmetric) &&
    !hasUnpairedHorizontal &&
    !hasUnpairedVertical) {
  reporter.atNode(node, code);
}
```

This limits the rule to cases where the conversion genuinely reduces code:

| Pattern | Currently reports | Should report |
|---------|:-:|:-:|
| `only(left: 8, right: 8)` | Yes | Yes |
| `only(top: 8, bottom: 8)` | Yes | Yes |
| `only(left: 8, right: 8, top: 16, bottom: 16)` | Yes | Yes |
| `only(left: 8, right: 8, top: 16, bottom: 4)` | Yes | Yes |
| `only(right: 8, top: 16, bottom: 16)` | Yes | **No** |
| `only(left: 8, top: 16, bottom: 16)` | Yes | **No** |
| `only(top: 8, left: 16, right: 16)` | Yes | **No** |
| `only(bottom: 8, left: 16, right: 16)` | Yes | **No** |

## Test fixture updates

The fixture file at `example/lib/stylistic/stylistic_widget_rules_fixture.dart`
should add cases that must NOT trigger the lint:

```dart
// GOOD: EdgeInsets.only with symmetric pair but unpaired side - no clean symmetric replacement
Padding(
  padding: EdgeInsets.only(right: 8, top: 16, bottom: 16),
  child: Text('Unpaired right with symmetric vertical'),
),

Padding(
  padding: EdgeInsets.only(left: 8, top: 16, bottom: 16),
  child: Text('Unpaired left with symmetric vertical'),
),

Padding(
  padding: EdgeInsets.only(top: 8, left: 16, right: 16),
  child: Text('Unpaired top with symmetric horizontal'),
),

Padding(
  padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
  child: Text('Unpaired bottom with symmetric horizontal'),
),
```
