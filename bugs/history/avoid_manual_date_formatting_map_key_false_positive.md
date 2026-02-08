# Bug: `avoid_manual_date_formatting` false positive on internal map keys

## Summary

The `avoid_manual_date_formatting` rule incorrectly flags string
interpolations that use 2+ DateTime properties as **map lookup keys** or
internal identifiers. The rule assumes any string composed from multiple date
properties is user-facing date formatting, but strings like
`'${date.year}-${date.month}'` are commonly used as composite map keys,
cache keys, or grouping identifiers that never reach the UI.

The rule's detection logic (count date property accesses in a single
`StringInterpolation` node, flag if >= 2) is correct for display text but
too broad for non-display contexts.

## Severity

**False positive** -- flags a standard data-structure pattern that has no
locale or i18n implications. The resulting string is never displayed to users,
never formatted for human consumption, and serves purely as an internal
grouping identifier.

## Reproduction

### Minimal example (map key from DateTime properties)

```dart
final Map<String, List<Event>> eventsByMonth = <String, List<Event>>{};

for (final DateTime date in dates) {
  // FLAGGED: avoid_manual_date_formatting
  final String monthKey = '${date.year}-${date.month}';
  eventsByMonth.putIfAbsent(monthKey, () => <Event>[]);
  eventsByMonth[monthKey]!.add(getEvent(date));
}
```

### Minimal example (cache key)

```dart
final Map<String, WeatherData> cache = <String, WeatherData>{};

// FLAGGED: avoid_manual_date_formatting
final String cacheKey = '${date.year}-${date.month}-${date.day}';
if (cache.containsKey(cacheKey)) {
  return cache[cacheKey]!;
}
```

### Minimal example (log/debug identifier)

```dart
// FLAGGED: avoid_manual_date_formatting
debug('Processing batch for ${date.year}-${date.month}');
```

### Lint output

```
line:col • [avoid_manual_date_formatting] Manual date formatting is
error-prone, ignores locale, and can produce incorrect or confusing output
for international users. This can break compliance, cause user confusion,
and lead to support issues in global apps.
• avoid_manual_date_formatting • WARNING
```

## Real-world occurrence

Found in `saropa/lib/components/event/event_range_panel.dart` at line 506
(inside `_buildEventColumnWidgets`):

```dart
// First pass: collect event counts per month for mini calendars
// Key is "year-month", value is map of day -> event count
final Map<String, Map<int, int>> eventCountsByMonth = <String, Map<int, int>>{};

for (final DateTime workingDate in workingDates) {
  final List<DisplayEventItem>? weekdayEvents = eventSettings.inRangeEvents(workingDate);
  if (weekdayEvents == null || weekdayEvents.isEmpty) {
    continue;
  }

  // FLAGGED HERE -- but this is a map key, not display text
  final String monthKey = '${workingDate.year}-${workingDate.month}';
  eventCountsByMonth.putIfAbsent(monthKey, () => <int, int>{});
  eventCountsByMonth[monthKey]![workingDate.day] =
      (eventCountsByMonth[monthKey]![workingDate.day] ?? 0) + weekdayEvents.length;
}
```

This string is used exclusively as a `Map<String, Map<int, int>>` key to
bucket event counts by month. It is never displayed to the user, never
formatted for locale, and never leaves the method. The `-` separator is
chosen for key uniqueness (distinguishing `2026-1` from `2026-11`), not for
human readability.

## Root cause

**File:** `lib/src/rules/internationalization_rules.dart`, lines 1508-1580
(`AvoidManualDateFormattingRule`)

The rule registers an `addStringInterpolation` callback and counts how many
`InterpolationExpression` elements access a property from the `_dateProperties`
set (`day`, `month`, `year`, `hour`, `minute`, `second`, `weekday`):

```dart
context.registry.addStringInterpolation((StringInterpolation node) {
  int datePropertyCount = 0;

  for (final element in node.elements) {
    if (element is InterpolationExpression) {
      final expr = element.expression;
      if (expr is PropertyAccess) {
        final propertyName = expr.propertyName.name;
        if (_dateProperties.contains(propertyName)) {
          datePropertyCount++;
        }
      } else if (expr is PrefixedIdentifier) {
        final propertyName = expr.identifier.name;
        if (_dateProperties.contains(propertyName)) {
          datePropertyCount++;
        }
      }
    }
  }

  // If 2+ date properties are used, it's likely manual date formatting
  if (datePropertyCount >= 2) {
    reporter.atNode(node, code);
  }
});
```

The threshold of `>= 2` correctly catches display formatting like
`'${date.day}/${date.month}/${date.year}'`. But it also catches any string
that happens to reference two date properties, regardless of whether the
string is ever displayed to a user.

The rule performs **no context analysis** on how the interpolated string is
used. It cannot distinguish between:

| Usage                              | Is date formatting? | Flagged? |
|------------------------------------|---------------------|----------|
| `Text('${d.day}/${d.month}')}`     | Yes (display text)  | Yes      |
| `map['${d.year}-${d.month}']`      | No (map key)        | Yes      |
| `cache['${d.year}-${d.month}-${d.day}']` | No (cache key) | Yes      |
| `debug('batch ${d.year}-${d.month}')` | No (debug log)   | Yes      |
| `filename_${d.year}_${d.month}.csv`| No (file path)      | Yes      |

### Why the threshold alone is insufficient

The `>= 2` threshold prevents flagging single-property access like
`'Day: ${date.day}'`, which is good. But any composite key, identifier, or
filename that references two date components will be falsely flagged.

These are common patterns in real codebases:
- **Grouping keys**: `'${date.year}-${date.month}'` for monthly aggregation
- **Cache keys**: `'weather-${date.year}-${date.month}-${date.day}'`
- **File names**: `'report_${date.year}_${date.month}.csv'`
- **Log messages**: `'Processing ${date.year}-${date.month}'`

None of these are "date formatting" in the i18n sense. They are internal
identifiers where locale, ordering, and human readability are irrelevant.

## Suggested fix

### Option A: Check if the target is a DateTime type (recommended)

The current rule checks **property names** but not the **target object type**.
Properties named `year`, `month`, `day` etc. exist on many types. Verifying
that the target is actually a `DateTime` would make the rule more precise.
But more importantly, this opens the door for a contextual check:

```dart
context.registry.addStringInterpolation((StringInterpolation node) {
  int datePropertyCount = 0;

  for (final element in node.elements) {
    if (element is InterpolationExpression) {
      final expr = element.expression;
      String? propertyName;
      DartType? targetType;

      if (expr is PropertyAccess) {
        propertyName = expr.propertyName.name;
        targetType = expr.target?.staticType;
      } else if (expr is PrefixedIdentifier) {
        propertyName = expr.identifier.name;
        targetType = expr.prefix.staticType;
      }

      if (propertyName != null &&
          _dateProperties.contains(propertyName) &&
          _isDateTimeType(targetType)) {
        datePropertyCount++;
      }
    }
  }

  // Only flag if used in a display context (see Option B)
  if (datePropertyCount >= 2) {
    reporter.atNode(node, code);
  }
});

bool _isDateTimeType(DartType? type) {
  if (type == null) return false;
  final element = type.element;
  return element is ClassElement && element.name == 'DateTime';
}
```

### Option B: Exclude non-display contexts (heuristic)

Check the parent node of the `StringInterpolation` to determine if the
result is likely used for display or for internal purposes:

```dart
// After counting datePropertyCount >= 2, check context:
final AstNode? parent = node.parent;

// Skip if the string is used as a map key
if (parent is IndexExpression && parent.index == node) return;

// Skip if assigned to a variable whose name suggests internal use
if (parent is VariableDeclaration) {
  final String varName = parent.name.lexeme.toLowerCase();
  if (varName.contains('key') ||
      varName.contains('cache') ||
      varName.contains('id')) {
    return;
  }
}

// Skip if passed to putIfAbsent, containsKey, or similar map methods
if (parent is ArgumentList) {
  final AstNode? grandparent = parent.parent;
  if (grandparent is MethodInvocation) {
    const Set<String> mapMethods = {'putIfAbsent', 'containsKey', 'remove'};
    if (mapMethods.contains(grandparent.methodName.name)) return;
    }
}

reporter.atNode(node, code);
```

### Option C: Require 3+ properties (simplest but loses coverage)

Raising the threshold to `>= 3` would eliminate most map-key false positives
(which typically use 2 properties: year+month) while still catching full date
formatting like `'${d.day}/${d.month}/${d.year}'`. However, this misses
legitimate 2-property formatting like `'${d.hour}:${d.minute}'` for time
display.

**Not recommended** as it trades false positives for false negatives.

### Recommendation

**Option A + B combined.** Verify the target is `DateTime` (more precise
property matching) and then apply the context heuristic to skip
non-display usages. This addresses the root cause without losing legitimate
detection.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Map key from DateTime properties (2 properties, non-display context)
final Map<String, int> counts = <String, int>{};
final String monthKey = '${date.year}-${date.month}';
counts[monthKey] = 42;

// Direct map subscript
counts['${date.year}-${date.month}'] = 42;

// Cache key
final String cacheKey = '${date.year}-${date.month}-${date.day}';
cache.putIfAbsent(cacheKey, () => fetchData());

// File name construction
final String fileName = 'report_${date.year}_${date.month}.csv';

// Debug/logging (not user-facing)
print('Processing ${date.year}-${date.month}');

// Non-DateTime object with same property names
final CustomPeriod period = CustomPeriod(year: 2026, month: 3);
final String key = '${period.year}-${period.month}';

// Should STILL flag (true positives, no change):

// Display text with date properties
Text('${date.day}/${date.month}/${date.year}')

// String assigned to display variable
final String displayDate = '${date.day}/${date.month}/${date.year}';

// Time display
final String timeDisplay = '${date.hour}:${date.minute}';

// toIso8601String().substring() (existing detection, no change)
final String isoDate = date.toIso8601String().substring(0, 10);

// Date in user-facing message
final String message = 'Created on ${date.day}/${date.month}';
```

## Impact

Any Flutter/Dart codebase using DateTime properties in composite keys,
cache identifiers, file names, or log messages will see false positives.
Composite keys from date properties are a standard pattern for:

- **Monthly/daily aggregation**: Grouping data by `year-month` or `year-month-day`
- **Cache invalidation**: Time-based cache keys
- **File organization**: Date-stamped file paths
- **Logging**: Date context in debug messages

The rule's problem message -- "can produce incorrect or confusing output for
international users" -- does not apply to any of these contexts because the
strings never reach international users. Flagging them erodes developer trust
in the rule and encourages blanket suppression, which hides legitimate
formatting violations.
