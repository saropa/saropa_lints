# Task: `prefer_static_before_instance`

## Summary
- **Rule Name**: `prefer_static_before_instance`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Organization

## Problem Statement
Static members define the type-level API of a class — factory methods, named constructors, singleton accessors, and constant pools. Instance members define object-level behavior. Grouping static members before instance members makes the type-level API immediately discoverable without requiring the reader to scroll through instance implementation. This is the ordering convention recommended by the Effective Dart guide and followed throughout the Flutter framework and Dart SDK.

When static and instance members are interleaved, class-level entry points (like `MyClass.create()` or `MyClass.fromJson()`) are buried in the middle of instance methods, reducing readability and making the class harder to use at a glance.

## Description (from ROADMAP)
Within the same visibility group and member type category (fields, methods), static members should be declared before instance members. The rule flags an instance field or method that precedes a static field or method of the same category within the same class body.

## Trigger Conditions
A static method or static field declaration that appears after a non-static method or non-static field of the same category in the same class. Constructors and operators are excluded from this check (they follow their own ordering rules).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  _checkStaticOrdering(node.members, reporter);
});
```

### Detection Logic
1. Separate `members` into: `FieldDeclaration` entries and `MethodDeclaration` entries (excluding getters, setters, constructors separately if desired).
2. For field declarations: find the first non-static field index and the last static field index. If `lastStaticFieldIndex > firstInstanceFieldIndex`, report the out-of-order static field.
3. For method declarations (excluding getters/setters): find the first non-static method index and the last static method index. If `lastStaticMethodIndex > firstInstanceMethodIndex`, report the out-of-order static method.

```dart
void _checkStaticOrdering(
  NodeList<ClassMember> members,
  ErrorReporter reporter,
) {
  _checkCategoryOrdering<FieldDeclaration>(
    members,
    isStatic: (m) => m.isStatic,
    reporter: reporter,
  );
  _checkCategoryOrdering<MethodDeclaration>(
    members,
    isStatic: (m) => m.isStatic && !m.isGetter && !m.isSetter,
    reporter: reporter,
  );
}

void _checkCategoryOrdering<T extends ClassMember>(
  NodeList<ClassMember> members, {
  required bool Function(T) isStatic,
  required ErrorReporter reporter,
}) {
  int firstInstanceIndex = -1;
  final outOfOrderStatics = <T>[];

  for (int i = 0; i < members.length; i++) {
    final member = members[i];
    if (member is! T) continue;
    if (isStatic(member)) {
      if (firstInstanceIndex != -1) {
        outOfOrderStatics.add(member);
      }
    } else {
      if (firstInstanceIndex == -1) firstInstanceIndex = i;
    }
  }

  for (final node in outOfOrderStatics) {
    reporter.atNode(node, code);
  }
}
```

## Code Examples

### Bad (triggers rule)
```dart
class Parser {
  String _input;

  Parser(this._input);

  // Instance method appears before static factory
  String parse() => _input.trim();

  // LINT: static method after instance method
  static Parser? fromJson(Map<String, dynamic> json) {
    final input = json['input'] as String?;
    return input == null ? null : Parser(input);
  }
}

class AppConfig {
  // Instance field first
  final String apiKey;

  AppConfig(this.apiKey);

  // LINT: static field after instance field
  static const String defaultBaseUrl = 'https://api.example.com';
}
```

### Good (compliant)
```dart
class Parser {
  // Static members first
  static Parser? fromJson(Map<String, dynamic> json) {
    final input = json['input'] as String?;
    return input == null ? null : Parser(input);
  }

  // Instance members after
  String _input;
  Parser(this._input);
  String parse() => _input.trim();
}

class AppConfig {
  // Static fields first
  static const String defaultBaseUrl = 'https://api.example.com';

  // Instance fields after
  final String apiKey;
  AppConfig(this.apiKey);
}
```

## Edge Cases & False Positives
- **Private vs public ordering**: This rule does not distinguish between private and public members. A future rule (`prefer_public_before_private`) could handle that separately.
- **Constants vs regular statics**: `static const` fields are a special category — some teams prefer grouping all `const` together regardless of static/instance distinction. The rule treats `static const` as static, which is correct.
- **Abstract static members**: Dart does not allow abstract static members; not applicable.
- **`@visibleForTesting` statics**: Testing helpers marked static should still be ordered with other statics.
- **Mixed visibility with static**: `static final _cache = <String, Parser>{}` (private static) after a public instance field — still flagged, since the ordering concern is static vs instance, not visibility.
- **Operator declarations**: Operators (`operator ==`, `operator []`) are neither clearly "static" nor "instance" in the ordering sense. Exclude from this check.
- **Enum members**: Dart enum `static` members are uncommon but valid. Apply the same rule to `EnumDeclaration` members.
- **Extension members**: Extensions cannot have static members that are fields (only static methods in some contexts). Apply where applicable.
- **Overridden members**: An `@override` instance member that logically groups with other overrides may feel wrong to move after a static. Still flag — ordering is about structure, not grouping by annotation.

## Unit Tests

### Should Trigger (violations)
```dart
class Cache<T> {
  final Map<String, T> _store = {};

  T? get(String key) => _store[key];  // instance method first

  // LINT: static after instance
  static Cache<String> get stringCache => Cache<String>();
}

class Validator {
  final String _pattern;
  Validator(this._pattern);

  bool validate(String input) => RegExp(_pattern).hasMatch(input);

  // LINT: static field after instance method area
  static final Validator email = Validator(r'^[\w.]+@[\w]+\.\w+$');
}
```

### Should NOT Trigger (compliant)
```dart
class Cache<T> {
  // Static first
  static Cache<String> get stringCache => Cache<String>();

  final Map<String, T> _store = {};
  T? get(String key) => _store[key];
}

class MathUtils {
  // All static — no instance members — no ordering concern
  static double square(double x) => x * x;
  static double cube(double x) => x * x * x;
}

class PureDataClass {
  // All instance — no static members — no ordering concern
  final String name;
  final int age;
  PureDataClass(this.name, this.age);
}
```

## Quick Fix
**"Move static member before instance members"** — Relocate the flagged static member (and its dartdoc/annotations) to just before the first instance member of the same category. For multiple violations, group moves together to avoid thrashing.

Priority: 55 (style/ordering concern, lower priority than correctness fixes).

## Notes & Issues
- This rule interacts with `prefer_constructors_first`. When both rules are active, they define a full ordering: static fields → instance fields → constructors → getters/setters → static methods → instance methods (or static methods → instance methods depending on interpretation). Document the intended combined ordering in the rule's dartdoc.
- Consider whether static getters/setters should be treated as "static methods" or as a separate "static accessors" group. Recommend treating them as static methods for ordering purposes.
- The rule name is clear and consistent with the `prefer_*` family of organizational rules.
- Performance: this check is O(n) in members per class, which is fast enough for typical class sizes.
