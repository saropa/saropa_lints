# Task: `prefer_const_constructors_in_immutables`

## Summary
- **Rule Name**: `prefer_const_constructors_in_immutables`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Performance / Flutter

## Problem Statement
Classes annotated with `@immutable` (or extending an immutable base class like `StatelessWidget`) promise that all their fields are final and the object's observable state does not change after construction. If such a class does not expose a `const` constructor, callers are forced to allocate a new instance every time, even when all constructor arguments are compile-time constants. Adding a `const` constructor to an `@immutable` class costs nothing (fields must already be `final`) and unlocks compile-time constant instantiation at all call sites. Missing `const` constructors in immutable classes is a common oversight, especially when developers add new fields incrementally and forget to re-check const eligibility.

## Description (from ROADMAP)
Flags `@immutable`-annotated classes (including `StatelessWidget` subclasses) that have at least one constructor but no `const` constructor, when all fields are `final` and const-compatible.

## Trigger Conditions
- A `ClassDeclaration` is annotated with `@immutable` OR extends/implements a class that is annotated with `@immutable` (e.g., `StatelessWidget`, `StatefulWidget`).
- The class has at least one generative constructor (not factory).
- None of the generative constructors are declared `const`.
- All instance fields of the class are `final` (a necessary precondition for const constructors).
- The class does not have any `late` fields (late fields are incompatible with const constructors).
- The class does not contain any mixin that introduces non-final fields (which would prevent const).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  // inspection happens here
});
```

### Detection Logic
1. Obtain the `ClassElement` from `node.declaredElement`.
2. Check if the class or any superclass is annotated with `@immutable`:
   - Check `element.metadata` for an annotation from `package:meta` or `package:flutter/foundation.dart` with name `immutable`.
   - Walk up `element.supertype` and check supertypes (excluding `Object`).
   - Cache results per element to avoid redundant walks.
3. Check if all instance fields satisfy const preconditions:
   - All instance fields must be `final` (`field.isFinal && !field.isLate`).
   - No non-final fields from mixins (check `element.mixins` for each mixin's fields).
4. Check if there is at least one generative constructor (`constructor.isFactory == false`).
5. Check if any generative constructor is `const` (`constructor.isConst == true`).
6. If no `const` generative constructor exists AND all fields are final AND class has @immutable, report the class name node.

## Code Examples

### Bad (triggers rule)
```dart
// @immutable class without const constructor
@immutable
class Config {
  Config({required this.url, required this.timeout}); // LINT: no const
  final String url;
  final Duration timeout;
}

// StatelessWidget subclass without const constructor
class MyButton extends StatelessWidget {
  MyButton({required this.label}); // LINT: StatelessWidget is @immutable
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

// Multiple constructors, none const
@immutable
class Point {
  Point(this.x, this.y); // LINT: no const constructor
  Point.origin() : x = 0, y = 0; // also not const

  final double x;
  final double y;
}
```

### Good (compliant)
```dart
// Has a const constructor
@immutable
class Config {
  const Config({required this.url, required this.timeout});
  final String url;
  final Duration timeout;
}

// StatelessWidget with const constructor
class MyButton extends StatelessWidget {
  const MyButton({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

// Has at least one const named constructor
@immutable
class Point {
  const Point(this.x, this.y);
  const Point.origin() : x = 0, y = 0;
  final double x;
  final double y;
}

// Not @immutable — rule doesn't apply
class Mutable {
  Mutable(this.name);
  String name; // mutable field
}

// @immutable but has non-final field — would be a different error
// (Dart itself prevents const constructors when fields are non-final)
```

## Edge Cases & False Positives
- **Classes with non-final fields**: If any instance field is non-final (or `late final`), a `const` constructor is impossible. Do not report in this case — report nothing or let the `@immutable` violation detector (a different rule) handle it.
- **`late` fields**: `late` is incompatible with `const` constructors. Skip classes with any `late` field.
- **Abstract classes**: Abstract `@immutable` classes may intentionally omit constructors or const. Consider skipping abstract classes, or reporting only if they have at least one non-abstract constructor.
- **Mixin application**: `class Foo extends Bar with MyMixin` — if `MyMixin` introduces non-final fields, const is impossible. Check all applied mixins.
- **Factory constructors only**: If the class only has factory constructors (no generative constructors), a const generative constructor may still be needed. Report if there are fields that support it, but the factory-only pattern sometimes intentionally avoids const (e.g., `fromJson` factories).
- **Classes with `super` parameters needing non-const super**: If the superclass constructor is not `const`, the subclass cannot have a `const` constructor. Verify that the superclass (if not `Object`) has a `const` constructor before reporting.
- **Enum-like patterns**: Classes simulating enums with static const instances — usually fine, these typically already have const constructors.
- **`StatefulWidget`**: `StatefulWidget` is `@immutable` for the widget itself but `State` is mutable. The rule should apply to `StatefulWidget` subclasses (their constructor parameters are final fields) but NOT to `State` subclasses.
- **Generated code**: `.freezed.dart`, `.g.dart` files — skip generated files.
- **Private constructors**: If all constructors are private (`_name()`), adding a const constructor is still valid. Flag normally.
- **Generics with non-const type parameters**: A class `class Foo<T>` with `const Foo()` is valid — generic type parameters don't affect const eligibility of the constructor itself.

## Unit Tests

### Should Trigger (violations)
```dart
import 'package:meta/meta.dart';

// Violation: @immutable class with no const constructor
@immutable
class UserProfile {
  UserProfile({required this.name, required this.age}); // LINT
  final String name;
  final int age;
}

// Violation: StatelessWidget without const constructor
class HeaderWidget extends StatelessWidget {
  HeaderWidget({required this.title}); // LINT
  final String title;

  @override
  Widget build(BuildContext context) => Text(title);
}

// Violation: @immutable with named constructors, none const
@immutable
class Color3 {
  Color3.rgb(this.r, this.g, this.b); // LINT
  final int r, g, b;
}
```

### Should NOT Trigger (compliant)
```dart
// OK: has const constructor
@immutable
class Ok1 {
  const Ok1({required this.value});
  final int value;
}

// OK: non-final field (const impossible anyway)
@immutable
class Ok2 {
  Ok2({required this.value});
  int value; // mutable — can't be const
}

// OK: late field
@immutable
class Ok3 {
  Ok3();
  late final String computed; // late — can't be const
}

// OK: not @immutable
class Ok4 {
  Ok4({required this.name});
  final String name;
}

// OK: abstract class with no constructors
@immutable
abstract class Ok5 {
  String get name;
}
```

## Quick Fix
Add the `const` modifier to the primary (unnamed) generative constructor.

- `Config({required this.url});` → `const Config({required this.url});`
- `MyButton({required this.label});` → `const MyButton({required this.label, super.key});`

**Fix steps:**
1. Identify the unnamed generative constructor (or the first generative constructor if no unnamed one exists).
2. Insert the `const` keyword before the constructor name token.
3. If the constructor is for a `StatelessWidget` subclass and lacks `super.key`, also suggest adding `super.key` (separate fix or combined).

**Note**: If the class has multiple generative constructors (named and unnamed), offer to add `const` to each one that lacks it (as separate fix actions). All generative constructors should ideally be `const` if the class is `@immutable`.

**Caveat**: If any field initializer uses a non-const expression, adding `const` to the constructor will cause a compile error. The fix must verify that all field initializers are const-capable before offering the fix.

## Notes & Issues
- Dart SDK: 2.0+ (const constructors are fundamental). Flutter: any version.
- The `@immutable` annotation check must use the element's library URI to identify `package:meta/meta.dart` or `package:flutter/foundation.dart`. Do not use string matching on the annotation name alone, as user code could define a different `@immutable` annotation.
- The `ClassElement.constructors` list includes all constructors. Filter for `!constructor.isFactory && !constructor.isSynthetic`.
- The default constructor is synthetic if not explicitly written. If a class has no constructors, Dart generates a default non-const one. The rule should flag this: "class has no explicit constructor and no const constructor" — suggest adding `const ClassName();`.
- The official Dart lint `prefer_const_constructors_in_immutables` exists. Verify overlap with saropa's version.
- Performance: `addClassDeclaration` is called once per class. The ancestry walk for `@immutable` should be cached at the element level. Classes in Flutter projects will commonly trigger this (many `StatelessWidget` subclasses), so caching is important.
- Related rules: `prefer_const_constructors` (for call sites), `prefer_const_declarations` (for variables). These three work together to maximize const propagation.
