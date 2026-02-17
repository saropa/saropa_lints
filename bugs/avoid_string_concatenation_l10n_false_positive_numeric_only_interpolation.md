# `avoid_string_concatenation_l10n` false positive: numeric-only interpolation

## Status: OPEN

## Summary

The `avoid_string_concatenation_l10n` rule (v2) fires on `Text('$completedCount / ${_statuses.length}')`, a **numeric progress counter** (e.g. "3 / 5"). The string contains no natural language words — only integer values separated by ` / `. Word order is irrelevant because there are no words to reorder. No translator would rearrange "3 / 5" into "5 / 3".

The rule counts interpolation expressions without checking whether the string actually contains translatable natural language text.

## Diagnostic Output

```
resource: /D:/src/contacts/lib/components/primitive/dialog/import_progress_dialog.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_string_concatenation_l10n
severity: 4 (warning)
message:  [avoid_string_concatenation_l10n] String concatenation in UI breaks
          word order for translations. {v2}
          Use Intl.message with placeholders or a localization solution that
          supports proper word order.
line:     217
```

## Affected Source

File: `lib/components/primitive/dialog/import_progress_dialog.dart` line 217

```dart
Widget _buildMultiFileView(BuildContext context) {
  final int completedCount = _statuses.where((_StepStatus s) => s == _StepStatus.complete).length;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        '$completedCount / ${_statuses.length}',  // ← triggers the rule
        style: TextStyle(
          fontSize: ThemeCommonFontSize.Small.size,
          color: ThemeCommonColor.ThemeOnSurfaceDim.from(context),
        ),
      ),
      ...
    ],
  );
}
```

The string `'$completedCount / ${_statuses.length}'` renders as "3 / 5" — a numeric progress counter. Both interpolated values are `int`. The only literal text is ` / `, a mathematical separator.

## Root Cause

The rule at `internationalization_rules.dart` lines 2478–2491 counts interpolation expressions and flags when there are 2 or more:

```dart
if (firstArg is StringInterpolation) {
  int interpolationCount = 0;
  for (final element in firstArg.elements) {
    if (element is InterpolationExpression) {
      interpolationCount++;
    }
  }
  // If there are multiple interpolations, likely needs l10n
  if (interpolationCount >= 2) {
    reporter.atNode(firstArg, code);
  }
}
```

The rule has **no analysis** of:
- Whether the interpolated expressions are numeric types (`int`, `double`, `num`)
- Whether the literal text between interpolations contains actual words (letters)
- Whether the string is a format pattern (progress counters, coordinates, dimensions, ratios)

## Why This Is a False Positive

The rule's premise is: "String concatenation breaks word order in translations." This is true for natural language like `'Hello $name, you have $count items'` where a translator might need `'$name, vous avez $count articles'`. But it does not apply when:

1. **No natural language text exists** — The only literal content is ` / `, a mathematical symbol
2. **Both interpolations are numeric** — `int` values have no word order
3. **The format is universal** — "3 / 5" as a progress indicator is language-agnostic
4. **Localization would be a no-op** — Wrapping this in `Intl.message` with placeholders produces the exact same output with extra complexity

Similar patterns that would false-positive:
- `'$width x $height'` — dimensions
- `'$lat, $lng'` — coordinates
- `'$current / $total'` — progress
- `'$hours:$minutes'` — time format
- `'$numerator / $denominator'` — fractions
- `'$score - $opponentScore'` — sports scores

## Scope of Impact

Any `Text()` displaying formatted numeric data with 2+ interpolations will trigger this false positive. This is common in dashboards, progress indicators, data displays, and any UI showing measurements or counts.

## Recommended Fix: Check for Natural Language Content

### Approach A: Require literal text with word characters (simplest, recommended)

Only flag when the literal portions of the string contain actual words (letters), not just symbols/whitespace:

```dart
if (firstArg is StringInterpolation) {
  int interpolationCount = 0;
  bool hasWordContent = false;

  for (final element in firstArg.elements) {
    if (element is InterpolationExpression) {
      interpolationCount++;
    } else if (element is InterpolationString) {
      // Check if the literal text contains word characters (letters),
      // not just separators like ' / ', ' x ', ' : ', ' - ', etc.
      if (RegExp(r'[a-zA-Z]').hasMatch(element.value)) {
        hasWordContent = true;
      }
    }
  }

  // Only flag strings that contain both multiple interpolations
  // AND natural language text that would need translation
  if (interpolationCount >= 2 && hasWordContent) {
    reporter.atNode(firstArg, code);
  }
}
```

This skips pure-numeric formats like `'$a / $b'`, `'$w x $h'`, `'$h:$m:$s'` while still catching `'Hello $name, you have $count items'`.

### Approach B: Check interpolation types via static analysis (more precise, higher cost)

Resolve the static types of interpolated expressions and skip when all are numeric:

```dart
for (final element in firstArg.elements) {
  if (element is InterpolationExpression) {
    final DartType? type = element.expression.staticType;
    if (type != null && _isNumericType(type)) {
      numericInterpolationCount++;
    }
    interpolationCount++;
  }
}

// Skip when all interpolations are numeric
if (interpolationCount >= 2 && numericInterpolationCount < interpolationCount) {
  reporter.atNode(firstArg, code);
}
```

### Approach C: Combine both checks

Use Approach A as the primary filter and Approach B as an additional signal. This provides the best precision: skip when either there are no words in the literals OR all interpolations are numeric.

**Recommendation:** Approach A alone is sufficient. It's simple, zero-cost (regex on string literals), and catches the vast majority of false positives. The key insight is that if there are no letters in the literal parts of the string, there's nothing to translate.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Numeric progress counter — no natural language.
void _good453() {
  final int completed = 3;
  final int total = 5;
  Text('$completed / $total');
}

// GOOD: Dimension format — no words.
void _good454() {
  final int w = 1920;
  final int h = 1080;
  Text('$w x $h');
}

// GOOD: Time format — no words.
void _good455() {
  final int hours = 2;
  final int minutes = 30;
  Text('$hours:$minutes');
}

// GOOD: Score display — no words.
void _good456() {
  final int home = 3;
  final int away = 1;
  Text('$home - $away');
}

// GOOD: Coordinates — no words.
void _good457() {
  final double lat = 51.5;
  final double lng = -0.1;
  Text('$lat, $lng');
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Natural language with interpolations — needs l10n.
// expect_lint: avoid_string_concatenation_l10n
void _bad452() {
  Text('Hello ' + userName + '!');
  Text('$greeting $name');
}
```

### New BAD cases (should still trigger)

```dart
// BAD: Mixed numeric and text — word "of" needs translation.
// expect_lint: avoid_string_concatenation_l10n
void _bad453() {
  final int page = 3;
  final int total = 10;
  Text('Page $page of $total');
}

// BAD: Natural language with numeric interpolations.
// expect_lint: avoid_string_concatenation_l10n
void _bad454() {
  final int count = 5;
  final String item = 'files';
  Text('$count $item remaining');
}
```

## Environment

- **saropa_lints version:** 4.14.5 (rule version v2)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\contacts`
- **Trigger file:** `lib/components/primitive/dialog/import_progress_dialog.dart:217`
- **Trigger expression:** `'$completedCount / ${_statuses.length}'`
- **Interpolation count:** 2 (both `int`)
- **Literal text:** ` / ` (no word characters)

## Severity

Low — warning-level diagnostic. The false positive recommends wrapping a numeric format string in localization infrastructure, which adds complexity with zero localization benefit. The string "3 / 5" is identical in every language. The pattern (numeric-only interpolated strings) is common in progress indicators, data displays, and measurement UIs.
