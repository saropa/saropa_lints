# Task: `prefer_sealed_classes`

## Summary
- **Rule Name**: `prefer_sealed_classes`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns

## Problem Statement
Dart 3.0 introduced the `sealed` keyword, which marks a class as having a closed set of known subclasses. This enables the Dart analyzer to perform exhaustiveness checking on `switch` expressions over sealed type hierarchies — similar to Rust enums or Kotlin sealed classes.

When an `abstract class` has a fixed, known set of subclasses all defined in the same library, and when the author has no intention of allowing external subclassing, the `abstract` modifier is the wrong tool. Using `abstract` instead of `sealed`:
1. Loses exhaustiveness checking — `switch (shape) { case Circle(): ... }` will not warn if `Rectangle` is unhandled.
2. Misleads readers about the open/closed nature of the hierarchy.
3. Prevents the compiler from flagging non-exhaustive pattern matches.
4. Is a missed opportunity to document design intent explicitly.

## Description (from ROADMAP)
An abstract class that has multiple concrete subclasses defined within the same compilation unit (file or part group) and that is not otherwise extended externally should be declared `sealed`. The rule detects abstract class + subclass co-location patterns and suggests adding the `sealed` modifier.

## Trigger Conditions
A `ClassDeclaration` where ALL of the following hold:
1. The class is abstract (`node.abstractKeyword != null`).
2. The class is NOT already sealed (`node.sealedKeyword == null`).
3. The class has at least 2 concrete subclasses defined in the same file.
4. The class itself has at least one abstract method or no concrete implementation (pure interface/hierarchy root).
5. The class has no `extends` clause (sealed classes cannot extend other classes, only implement or use `with`).
6. The Dart language version in `pubspec.yaml` is ≥ 3.0.

## Implementation Approach

### AST Visitor
```dart
// Two-pass approach: collect all class declarations first,
// then check subclass relationships.

context.registry.addCompilationUnit((unit) {
  _checkSealedCandidates(unit, reporter);
});
```

### Detection Logic
```dart
void _checkSealedCandidates(
  CompilationUnit unit,
  ErrorReporter reporter,
) {
  // Pass 1: Collect all class declarations in the unit
  final classes = unit.declarations.whereType<ClassDeclaration>().toList();

  // Pass 2: For each abstract class, count concrete subclasses in the same unit
  for (final cls in classes) {
    if (cls.abstractKeyword == null) continue;
    if (cls.sealedKeyword != null) continue;  // already sealed
    if (cls.extendsClause != null) continue;  // cannot be sealed if extends

    final className = cls.name.lexeme;
    int subclassCount = 0;

    for (final other in classes) {
      if (other == cls) continue;
      final extendsName = other.extendsClause?.superclass.name2.lexeme;
      if (extendsName == className && !other.isAbstract) {
        subclassCount++;
      }
    }

    if (subclassCount >= 2) {
      reporter.atToken(cls.abstractKeyword!, code);
    }
  }
}
```

## Code Examples

### Bad (triggers rule)
```dart
// LINT: abstract class with 2+ concrete subclasses in same file
// Should be sealed to enable exhaustive pattern matching
abstract class Shape {
  double get area;
}

class Circle extends Shape {
  final double radius;
  Circle(this.radius);

  @override
  double get area => 3.14159 * radius * radius;
}

class Rectangle extends Shape {
  final double width;
  final double height;
  Rectangle(this.width, this.height);

  @override
  double get area => width * height;
}

class Triangle extends Shape {
  final double base;
  final double height;
  Triangle(this.base, this.height);

  @override
  double get area => 0.5 * base * height;
}

// Without sealed, this switch has no exhaustiveness checking:
double describeShape(Shape shape) => switch (shape) {
  Circle c => c.area,
  Rectangle r => r.area,
  // Triangle missing — compiler won't warn without sealed!
};
```

### Good (compliant)
```dart
// Correct: sealed class enables exhaustiveness checking
sealed class Shape {
  double get area;
}

class Circle extends Shape { ... }
class Rectangle extends Shape { ... }
class Triangle extends Shape { ... }

// Now the compiler warns if Triangle is not handled:
double describeShape(Shape shape) => switch (shape) {
  Circle c => c.area,
  Rectangle r => r.area,
  Triangle t => t.area,  // must handle all cases
};

// Compliant: abstract class designed for external extension
abstract class Plugin {
  void initialize();
  void dispose();
  // Users are expected to create their own Plugin subclasses
}

// Compliant: only one concrete subclass — sealed is premature
abstract class Formatter {
  String format(Object value);
}
class DefaultFormatter extends Formatter {
  @override String format(Object value) => value.toString();
}

// Compliant: already sealed
sealed class Result<T> { }
class Success<T> extends Result<T> { final T value; Success(this.value); }
class Failure<T> extends Result<T> { final Object error; Failure(this.error); }
```

## Edge Cases & False Positives
- **Subclasses in different files**: If `Circle` is in `circle.dart` and `Rectangle` is in `rectangle.dart`, the two-pass analysis within a single compilation unit will not detect the relationship. This rule conservatively only flags when ALL subclasses are in the same file. Cross-file sealing is a stronger change requiring more analysis.
- **Abstract subclasses**: If a subclass is itself abstract, it doesn't count toward the "concrete subclass" count unless it also has its own concrete subclasses in the file.
- **Dart version constraint**: Sealed classes require Dart 3.0. Check `pubspec.yaml` SDK constraint `sdk: '>=3.0.0 ...'`. Skip the rule entirely if the constraint is below 3.0.
- **Classes with `base`, `interface`, `final` modifiers**: These Dart 3 class modifiers affect inheritance. A `final abstract class` cannot be subclassed externally anyway — but `sealed` is still more appropriate. Flag and suggest `sealed` as the clearer intent.
- **Classes in the public API of a package**: Converting `abstract` to `sealed` is a breaking change for any external code that subclasses the class. Flag but include a breaking-change warning in the correction message.
- **Generic abstract classes**: `abstract class Result<T>` with concrete generic subclasses — the type parameter propagates to subclasses. Sealed works fine with generics; the rule applies.
- **`@visibleForTesting` subclasses**: Test subclasses of an otherwise sealed hierarchy should be in test files. If the only subclasses are in test files, do not flag the abstract class — it's intentionally unsealed for testability.
- **Mixin application (`class Foo = Bar with Baz`)**: These synthetic classes should be excluded from the subclass count.

## Unit Tests

### Should Trigger (violations)
```dart
// 3 concrete subclasses, same file — LINT
abstract class Event {}
class ClickEvent extends Event { final int x, y; ClickEvent(this.x, this.y); }
class KeyEvent extends Event { final String key; KeyEvent(this.key); }
class ScrollEvent extends Event { final double delta; ScrollEvent(this.delta); }
```

### Should NOT Trigger (compliant)
```dart
// Only 1 concrete subclass — not enough to seal
abstract class Comparable<T> {
  int compareTo(T other);
}
class MyComparable extends Comparable<String> {
  @override int compareTo(String other) => 0;
}

// Already sealed
sealed class Token {}
class IdentifierToken extends Token { final String name; IdentifierToken(this.name); }
class NumberToken extends Token { final num value; NumberToken(this.value); }

// Subclasses in different files (not detectable by single-file analysis)
// abstract class Widget {} — in widget.dart
// class Button extends Widget {} — in button.dart
// class Text extends Widget {} — in text.dart
// Not flagged because cross-file analysis is out of scope
```

## Quick Fix
**"Add sealed modifier"** — Replace `abstract class ClassName` with `sealed class ClassName`. No other changes are needed to the file — existing subclasses in the same file automatically become part of the sealed family.

Priority: 70 (enabling exhaustiveness checking is a meaningful correctness improvement).

## Notes & Issues
- This rule is closely related to `prefer_sealed_for_state` (File 8), which is a more targeted version for BLoC/Cubit state classes. The two rules share detection logic but differ in trigger heuristics. `prefer_sealed_classes` is the general case; `prefer_sealed_for_state` is a domain-specific specialization.
- The threshold of 2+ concrete subclasses is intentional — a single concrete subclass does not benefit from sealed because there is nothing to be exhaustive over. Re-evaluate whether the threshold should be 1 (i.e., flag as soon as there is any concrete subclass, since sealed with one subclass still prevents external extension).
- Consider excluding abstract classes named with `Base` prefix (e.g., `BaseRepository`) — these are often intentionally open for testing. Or detect this via naming convention heuristics.
