# Task: `prefer_extension_methods`

## Summary
- **Rule Name**: `prefer_extension_methods`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns

## Problem Statement
Top-level helper functions that take a single typed object as their primary parameter are a common pattern imported from other languages. In Dart, extension methods provide a better alternative: they are discoverable via IDE autocomplete, they read like natural method calls on the type (`myDate.format()` vs `formatDate(myDate)`), and they make the association between the function and the type explicit.

Top-level functions are harder to discover — a developer must know the function name and the file it lives in. Extension methods on the type are surfaced automatically when the type is used, reducing the documentation burden and improving code readability.

This rule detects top-level functions that are strong candidates for conversion to extension methods: single typed parameter (or first parameter is the primary one), return type unrelated to "construction", and the function name follows a pattern suggesting an operation on the type.

## Description (from ROADMAP)
A top-level function that takes a single parameter of a known class type (not a primitive like `int` or `bool`) as its first (and ideally only) parameter is a candidate for conversion to an extension method on that type. The rule is particularly triggered when the function name follows an `<action><TypeName>` or `<typeName><Action>` naming pattern.

## Trigger Conditions
A `FunctionDeclaration` at the top level (not inside a class) where:
1. The function has exactly one parameter, OR the first parameter's type is a concrete class type (not `Object`, `dynamic`, or a generic).
2. The function is not a constructor, operator, or `main`.
3. The function is not already inside an extension.
4. The function name contains the simple name of the first parameter's type (case-insensitive), OR the function performs a transformation returning the same type as the parameter (strongly suggesting it is an operation on that type).
5. The parameter type is not a Dart primitive (`int`, `double`, `bool`, `String` — these are common extension targets but require explicit opt-in to avoid over-flagging).

## Implementation Approach

### AST Visitor
```dart
context.registry.addFunctionDeclaration((node) {
  if (_isExtensionMethodCandidate(node)) {
    reporter.atNode(node.name, code);
  }
});
```

### Detection Logic
```dart
bool _isExtensionMethodCandidate(FunctionDeclaration node) {
  // Skip main, operators
  if (node.name.lexeme == 'main') return false;
  if (node.functionExpression.parameters == null) return false;

  final params = node.functionExpression.parameters!.parameters;
  if (params.isEmpty) return false;

  final firstParam = params.first;
  final firstParamType = firstParam.declaredElement?.type;
  if (firstParamType == null) return false;

  // Skip primitives and generic types (too broad)
  if (_isPrimitive(firstParamType)) return false;
  if (firstParamType is TypeParameterType) return false;
  if (firstParamType.isDynamic || firstParamType.isVoid) return false;

  // Check if function name relates to the type name
  final typeName = firstParamType.element?.name ?? '';
  final funcName = node.name.lexeme;
  final typeNameLower = typeName.toLowerCase();
  final funcNameLower = funcName.toLowerCase();

  if (typeName.isNotEmpty && funcNameLower.contains(typeNameLower)) {
    return true;
  }

  // Single-parameter functions transforming to same or related type
  if (params.length == 1) {
    final returnType = node.returnType?.type;
    if (returnType != null && returnType == firstParamType) return true;
  }

  return false;
}

bool _isPrimitive(DartType type) =>
    type.isDartCoreInt ||
    type.isDartCoreDouble ||
    type.isDartCoreBool ||
    type.isDartCoreString ||
    type.isDartCoreNum;
```

## Code Examples

### Bad (triggers rule)
```dart
// LINT: function name contains 'DateTime', single typed param
String formatDateTime(DateTime dt) =>
    DateFormat('yyyy-MM-dd HH:mm').format(dt);

// LINT: function name contains 'Duration'
String formatDuration(Duration d) =>
    '${d.inHours}h ${d.inMinutes.remainder(60)}m';

// LINT: single param of class type, function is a transformation
Color darkenColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
}

// LINT: single param, name pattern matches
Uri buildUserUri(User user) =>
    Uri.https('api.example.com', '/users/${user.id}');
```

### Good (compliant)
```dart
// Correct: extension method — discoverable and ergonomic
extension DateTimeFormatting on DateTime {
  String format() => DateFormat('yyyy-MM-dd HH:mm').format(this);
}

extension DurationFormatting on Duration {
  String get formatted =>
      '${inHours}h ${inMinutes.remainder(60)}m';
}

extension ColorUtils on Color {
  Color get darkened {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }
}

extension UserUriBuilder on User {
  Uri toUri() => Uri.https('api.example.com', '/users/$id');
}

// Compliant: multiple parameters of different types — not single-type operation
String buildQuery(String baseUrl, Map<String, String> params) {
  final uri = Uri.parse(baseUrl);
  return uri.replace(queryParameters: params).toString();
}

// Compliant: top-level utility function with no strong type association
bool isValidEmail(String email) =>
    RegExp(r'^[\w.]+@[\w]+\.\w+$').hasMatch(email);

// Compliant: factory-style function that creates an object
User createGuestUser() => User(id: 'guest', name: 'Guest');
```

## Edge Cases & False Positives
- **Functions in `main.dart` or entry files**: Top-level functions near `main()` are often app initialization helpers, not extension candidates. Consider excluding functions in files containing a `main` function.
- **Test helper functions**: Functions in `test/` directories are often one-off helpers that do not warrant conversion to extensions. Exclude test files.
- **Functions in generated files**: Skip `.g.dart`, `.freezed.dart`, `.gr.dart` files.
- **Callback functions**: `void onTap(BuildContext context)` — functions passed as callbacks and named in callback style should not be flagged. Heuristic: if the function name starts with `on` or `handle`, skip.
- **Named constructors expressed as functions**: Some code uses top-level factory functions before factory constructors were idiomatic. These may be intentionally top-level for API reasons.
- **Functions with multiple parameters**: The rule should be more lenient when there are multiple parameters. Only flag when the function has 1–2 parameters and the first clearly dominates.
- **Generic functions**: `T? firstOrNull<T>(List<T> list)` — already effectively an extension candidate, but the generic nature means `firstOrNull` could live in an `extension ... on List<T>`. Flag these but with awareness that the fix requires a generic extension.
- **Functions in package public API (`lib/`)**: Converting a top-level function to an extension method is a breaking API change for callers. Flag, but the correction message should note the breaking change risk.

## Unit Tests

### Should Trigger (violations)
```dart
// Top-level, single param of class type, name matches type
Widget wrapWithSafeArea(Widget widget) => SafeArea(child: widget);

// Single param, return type is same
Color toGrayscale(Color color) {
  final lum = (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114).round();
  return Color.fromRGBO(lum, lum, lum, 1.0);
}
```

### Should NOT Trigger (compliant)
```dart
// Already in an extension
extension on Color {
  Color get grayscale {
    final lum = (red * 0.299 + green * 0.587 + blue * 0.114).round();
    return Color.fromRGBO(lum, lum, lum, 1.0);
  }
}

// Multiple params, different types — not a clear extension candidate
String formatAddress(String street, String city, String country) =>
    '$street, $city, $country';

// Factory-style — creates the type, doesn't transform it
Color randomColor() => Color(Random().nextInt(0xFFFFFFFF));
```

## Quick Fix
**"Convert to extension method on [TypeName]"** — Generate an extension on the detected type:
1. Create `extension on TypeName { returnType functionName(remainingParams) { ... } }`.
2. Replace `firstParam` usage in the body with `this`.
3. Remove the original top-level function declaration.

Priority: 60.

## Notes & Issues
- The name pattern matching (`funcNameLower.contains(typeNameLower)`) is a heuristic that may over-fire for common type names like `List` or `Map`. Fine-tune the threshold or restrict to non-collection types initially.
- Consider a `@allowTopLevel` annotation or a comment suppression mechanism for intentionally top-level functions that are public API.
- This rule has significant overlap with `prefer_extension_over_utility_class`. Both detect patterns that should be extensions. The key distinction: this rule targets top-level functions; the other targets utility classes. Document this distinction clearly in the rule's dartdoc.
