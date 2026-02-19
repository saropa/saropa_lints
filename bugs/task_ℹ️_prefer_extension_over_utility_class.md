# Task: `prefer_extension_over_utility_class`

## Summary
- **Rule Name**: `prefer_extension_over_utility_class`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns

## Problem Statement
The utility class anti-pattern — a class with only static methods, often named `XxxUtils`, `XxxHelper`, or `XxxExtensions` — is a Java-ism that predates Dart's extension method system. In Dart, when all static methods in a utility class operate on the same type (e.g., all take a `String` as their first parameter), the semantically correct and ergonomically superior alternative is to write an extension on that type.

Extensions are:
1. **Discoverable**: IDE autocompletion surfaces extension methods on the target type directly.
2. **Ergonomic**: `myString.capitalize()` instead of `StringUtils.capitalize(myString)`.
3. **Idiomatic**: Modern Dart code prefers extensions over utility classes.
4. **Composable**: Extensions can be selectively imported, avoiding name conflicts.

This rule detects the pattern and recommends conversion.

## Description (from ROADMAP)
A class with only static methods where all (or the majority of) methods have the same first parameter type should be converted to an extension on that type. The class should not be instantiable (no public constructor, or the constructor is private/factory-only).

## Trigger Conditions
A `ClassDeclaration` where ALL of the following hold:
1. All `MethodDeclaration` members are static (`member.isStatic`).
2. There are no instance fields (`FieldDeclaration` with `!isStatic`).
3. Either: no constructor, or only a private constructor (preventing instantiation).
4. All static methods have at least one parameter, AND the type of the first parameter is the same type across all methods (or ≥75% of methods for a soft threshold).
5. The class has at least 2 static methods (single-method utility classes are a different smell).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  _checkUtilityClassPattern(node, reporter);
});
```

### Detection Logic
```dart
void _checkUtilityClassPattern(
  ClassDeclaration node,
  ErrorReporter reporter,
) {
  // Must have no instance members
  final hasInstanceMembers = node.members.any((m) {
    if (m is FieldDeclaration && !m.isStatic) return true;
    if (m is MethodDeclaration && !m.isStatic && !m.isGetter && !m.isSetter) return true;
    return false;
  });
  if (hasInstanceMembers) return;

  // Must have no public generative constructor
  final hasPublicConstructor = node.members
      .whereType<ConstructorDeclaration>()
      .any((c) => c.factoryKeyword == null &&
                  (c.name == null || !c.name!.lexeme.startsWith('_')));
  if (hasPublicConstructor) return;

  // Collect static methods with parameters
  final staticMethods = node.members
      .whereType<MethodDeclaration>()
      .where((m) => m.isStatic && !m.isGetter && !m.isSetter)
      .toList();
  if (staticMethods.length < 2) return;

  // Check if all methods share the same first parameter type
  final firstParamTypes = staticMethods
      .map((m) => m.parameters?.parameters.firstOrNull?.declaredElement?.type)
      .where((t) => t != null)
      .toSet();

  if (firstParamTypes.length == 1) {
    reporter.atNode(node.name, code);
  }
}
```

## Code Examples

### Bad (triggers rule)
```dart
// LINT: all methods operate on String — should be extension
class StringUtils {
  StringUtils._(); // private constructor

  static String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static bool isBlank(String s) => s.trim().isEmpty;

  static String truncate(String s, int maxLength) =>
      s.length <= maxLength ? s : '${s.substring(0, maxLength)}...';
}

// LINT: all methods operate on DateTime
class DateTimeUtils {
  static bool isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  static bool isWeekend(DateTime dt) =>
      dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;

  static DateTime startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
```

### Good (compliant)
```dart
// Correct: use extension instead
extension StringExtensions on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);

  bool get isBlank => trim().isEmpty;

  String truncate(int maxLength) =>
      length <= maxLength ? this : '${substring(0, maxLength)}...';
}

extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  DateTime get startOfDay => DateTime(year, month, day);
}

// Compliant: mixed first parameter types — not a single-type utility class
class ConversionUtils {
  static String intToHex(int value) => value.toRadixString(16);
  static int hexToInt(String hex) => int.parse(hex, radix: 16);
  static double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;
}

// Compliant: has instance state — not a utility class
class StringProcessor {
  final String _prefix;
  StringProcessor(this._prefix);

  static bool isEmpty(String s) => s.isEmpty;
  String process(String s) => '$_prefix$s';
}
```

## Edge Cases & False Positives
- **Methods operating on different types**: If the first parameter types differ across methods, do not flag — this is a genuine namespace grouping, not a single-type utility class.
- **Classes used as namespaces for constants**: `class AppConstants { static const String apiKey = '...'; }` — these have fields, not just methods. The rule already excludes classes with static fields (or should check separately). Clarify: if the class has ONLY static `const` fields and no methods, it is a constants namespace — exclude.
- **Generic utility classes**: `class ListUtils { static T first<T>(List<T> list) => list.first; }` — the first parameter is generic. Consider whether to flag. For simplicity, exclude classes with all-generic first parameters.
- **Classes with `extends` or `implements`**: A class implementing an interface or extending another cannot be trivially converted to an extension. Exclude.
- **Public API in packages**: Converting a utility class to an extension is a breaking API change. Classes in `lib/src/` are safe to convert; classes in `lib/` of a published package should be flagged with a note that the fix is a breaking change.
- **`@deprecated` members**: Utility classes with deprecated methods may be in a transition state — still flag, but note in the correction message.
- **Methods that call each other**: If `capitalize` calls `isBlank` internally (as a static call), conversion to extension is still valid since extensions can call `this.isBlank`.

## Unit Tests

### Should Trigger (violations)
```dart
class ListUtils {
  ListUtils._();

  static List<T> unique<T>(List<T> list) => list.toSet().toList();
  static T? firstOrNull<T>(List<T> list) => list.isEmpty ? null : list.first;
  static List<T> compact<T>(List<T?> list) =>
      list.whereType<T>().toList();
}
// LINT: all methods take List as first param
```

### Should NOT Trigger (compliant)
```dart
// Mixed types — not single-type utility
class FormatUtils {
  static String formatInt(int n) => NumberFormat('#,###').format(n);
  static String formatDate(DateTime d) => DateFormat.yMd().format(d);
  static String formatDuration(Duration d) => '${d.inMinutes}m';
}

// Only one static method — below threshold
class UrlUtils {
  static bool isValid(String url) => Uri.tryParse(url) != null;
}

// Has instance state — not a utility class
class Formatter {
  final String locale;
  Formatter(this.locale);
  static String trim(String s) => s.trim();
}
```

## Quick Fix
**"Convert to extension on [TypeName]"** — Generate an extension declaration on the detected common type, converting each `static method(TypeName param, ...)` to `returnType methodName(...)` using `this` in place of the first parameter. Remove the original class. This is a significant source transformation; the fix should be provided but marked as potentially requiring manual review for complex cases.

Priority: 60.

## Notes & Issues
- The 75% threshold (most methods share first parameter type) makes the rule more lenient for classes where a minority of methods operate on a different type. The threshold is configurable in theory but defaults to 100% (all methods) for initial implementation to reduce false positives.
- Cross-file callers of the utility class methods will need updating after the fix. The quick fix cannot address cross-file changes — document this limitation.
- The rule name `prefer_extension_over_utility_class` clearly communicates intent without ambiguity.
