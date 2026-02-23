# Task: `avoid_hive_datetime_local`

## Summary
- **Rule Name**: `avoid_hive_datetime_local`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.52 Hive Advanced Rules

## Problem Statement

> ⚠️ **Verification Required**: Newer versions of Hive's `DateTimeAdapter` may already store `DateTime` as UTC milliseconds since epoch, which would make this rule partially or fully redundant. **Verify the adapter implementation before implementing this rule.** See Note 3.

Hive stores `DateTime` objects using its built-in `DateTimeAdapter`. In older or non-UTC-normalizing versions of the adapter, local `DateTime` objects are serialized as-is — including their timezone offset. This creates a subtle bug:

**Local `DateTime` objects on different devices or after timezone changes are deserialized incorrectly.**

When a `DateTime` in local time is stored and the device's timezone changes (or the data is synced to a device in a different timezone):
1. The stored timestamp appears to represent a different moment in time
2. Appointment/scheduling apps show wrong times
3. Log timestamps become misleading

Example:
```dart
// Stored in New York (UTC-5):
box.put('last_login', DateTime.now()); // ← local time: 10:00 AM EST

// Later read in London (UTC+0):
final lastLogin = box.get('last_login') as DateTime;
// lastLogin.toLocal() shows 10:00 AM — but in London! Wrong!
// Should be 3:00 PM (10:00 AM + 5 hours for timezone offset)
```

The correct approach: always convert to UTC before storing, convert to local after reading.

## Description (from ROADMAP)

> DateTime stored as-is loses timezone. Convert to UTC before storing, local after reading.

## Trigger Conditions

1. `box.put(key, dateTimeValue)` where `dateTimeValue` is a `DateTime` (not `.toUtc()`)
2. `DateTime.now()` stored in Hive without `.toUtc()` conversion

**Phase 1 (Conservative)**: Flag `box.put` where the value argument is a `DateTime` expression that is NOT `.toUtc()` (i.e., the last method call is not `toUtc()`).

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isHivePut(node)) return; // box.put
  final valueArg = _getValueArgument(node);
  if (valueArg == null) return;

  final type = valueArg.staticType;
  if (type == null) return;
  if (!_isDateTimeType(type)) return;

  // Check if the value ends with .toUtc()
  if (_isAlreadyUtc(valueArg)) return;

  reporter.atNode(valueArg, code);
});
```

`_isDateTimeType`: check if type is `DateTime`.
`_isAlreadyUtc`: check if the expression is a `MethodInvocation` with `toUtc()` as the last call, OR if the expression accesses `.utc` (for `DateTime.utc(...)` constructors).

## Code Examples

### Bad (Should trigger)
```dart
final box = Hive.box('settings');

// Local DateTime stored without UTC conversion
box.put('created_at', DateTime.now());       // ← trigger: local time
box.put('last_login', widget.loginTime);     // ← trigger: unknown timezone
box.put('appointment', selectedDateTime);     // ← trigger: may be local

// Local DateTime in a model
box.put('event', Event(
  start: DateTime.now(), // ← trigger: DateTime field without toUtc()
));
```

### Good (Should NOT trigger)
```dart
final box = Hive.box('settings');

// Converted to UTC before storage
box.put('created_at', DateTime.now().toUtc()); // ← OK: UTC
box.put('last_login', widget.loginTime.toUtc()); // ← OK: UTC

// Reading back (convert to local)
final createdAt = (box.get('created_at') as DateTime).toLocal();
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `DateTime.utc(year, month, day)` | **Suppress** — already UTC | Check for `utc` constructor |
| `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)` | **Suppress** — explicitly UTC | |
| Date-only values (no time component matters) | **Trigger** — still stored with local timezone | Could be false positive for date-only use |
| Model class with `DateTime` field | **Complex** — model is put, not DateTime directly | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `box.put('key', DateTime.now())` → 1 lint
2. `box.put('key', someLocalDateTime)` (variable of type DateTime) → 1 lint

### Non-Violations
1. `box.put('key', DateTime.now().toUtc())` → no lint
2. `box.put('key', DateTime.utc(2024, 1, 1))` → no lint
3. `box.put('key', 42)` (not DateTime) → no lint

## Quick Fix

Offer "Add `.toUtc()` conversion":
```dart
// Before
box.put('key', DateTime.now());

// After
box.put('key', DateTime.now().toUtc());
```

## Notes & Issues

1. **hive-only**: Only fire if `ProjectContext.usesPackage('hive')` or `ProjectContext.usesPackage('hive_flutter')`.
2. **Model objects containing DateTime**: If a `@HiveType` model class has a `DateTime` field and the model is stored in Hive, the same timezone issue applies. However, detecting DateTime fields inside model classes is more complex (requires checking model type's fields).
3. **The HiveDateTimeAdapter**: Check whether the built-in Hive `DateTimeAdapter` stores UTC or local time. If it stores as UTC milliseconds (which it does in newer versions), this rule may be partially redundant. Verify the adapter implementation before implementing this rule.
4. **Custom TypeAdapter**: If the project has a custom `DateTimeAdapter` that handles UTC conversion, suppress the lint.
5. **`DateTimeRange`**: `DateTimeRange` contains two `DateTime` objects. If stored in Hive, both should be UTC. Consider extending detection to `DateTimeRange`.
6. **`package:clock`**: Some projects use `package:clock` for testable time. `clock.now()` returns local time — same concern applies.
7. **isUtc property**: Dart `DateTime` has an `isUtc` property. The Hive adapter may preserve this flag. Verify whether the timezone issue is in Hive's adapter or in developer usage.
