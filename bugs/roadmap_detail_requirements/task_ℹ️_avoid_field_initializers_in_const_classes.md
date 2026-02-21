# Task: `avoid_field_initializers_in_const_classes`

## Summary
- **Rule Name**: `avoid_field_initializers_in_const_classes`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Performance / Constructor Patterns

## Problem Statement
In Dart, a class that has `const` constructors must satisfy strict rules for its fields. When a non-static instance field has an inline initializer (e.g., `final double magnitude = 0.0;` inside the class body), that initializer is evaluated at construction time but it is NOT part of the initializer list and the constant evaluator treats it differently. Field body initializers (`final x = expr;` directly on the field) in a class with const constructors can prevent the entire expression graph from being treated as a compile-time constant in some cases, and they obscure where initialization actually happens. The Dart idiom for const classes is to move all computed field values to the constructor's initializer list, making the computation explicit and unambiguously part of the const evaluation. This also makes the initialization order clear to the reader.

## Description (from ROADMAP)
Detects non-static field initializers (value assignments on the field declaration itself) in classes that have `const` constructors, and suggests moving the initialization to the constructor initializer list.

## Trigger Conditions
- A `ClassDeclaration` has at least one `const` generative constructor.
- The class has one or more instance fields with inline initializers (i.e., `FieldDeclaration` where the `VariableDeclaration` has an initializer).
- The field is `final` (non-final fields with const constructors would be a compile error anyway).
- The field initializer is NOT a compile-time constant by itself (if it were, it could be `static const` and removed from the field entirely).
- The field is NOT `static`.

**Why only non-constant initializers?** If the field initializer is a compile-time constant (e.g., `final int x = 0;`), Dart evaluates it as a constant and the compiler handles it correctly in const classes. These can still be in the initializer list for clarity, but it is less critical. The rule should flag initializers that reference constructor parameters — those are the ones that MUST be in the initializer list.

Actually, per Dart semantics: in a class with `const` constructors, ALL field initializers (whether simple constants or computed from parameters) must be deterministic and computable at const time. The issue is specifically when a field initializer references a constructor parameter — that pattern is illegal in Dart (field initializers in the body cannot reference constructor parameters). So the actual issue is: field initializers in const class bodies that reference constructor parameters are already a compile error. The rule should therefore focus on the converse: calling out field initializers that look like they should be in the initializer list (i.e., computed values that are hardcoded in the field body but that belong to specific constructor contexts).

**Revised trigger**: Flag field declarations in const classes where the field has an inline initializer that is a computed expression (not a simple literal), suggesting it should be moved to the initializer list for clarity.

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  // inspection happens here
});
```

### Detection Logic
1. Obtain `ClassElement` from `node.declaredElement`.
2. Check if the class has at least one `const` generative constructor. Use `element.constructors.any((c) => c.isConst && !c.isFactory)`.
3. Iterate over `node.members` and find `FieldDeclaration` nodes where `!declaration.isStatic`.
4. For each field declaration, check its `VariableDeclaration` entries:
   a. Check `variable.initializer != null`.
   b. Check `variable.declaredElement?.isFinal == true`.
   c. Check that the initializer is NOT a simple compile-time constant literal (int, double, String, bool, null, const constructor call). If it is a simple literal, it is already optimal.
   d. If the initializer is a more complex expression (method call, arithmetic on parameters, string interpolation, etc.), report the `FieldDeclaration` node.
5. Note: Field initializers in Dart class bodies cannot reference constructor parameters (this would be a compile error). So the case where a field initializer IS computed from parameters is caught by the Dart compiler. The rule thus focuses on field initializers that are computed expressions that could logically be moved to an initializer list to improve clarity and grouping.

## Code Examples

### Bad (triggers rule)
```dart
// Class with const constructor and field initializer using computation
class Circle {
  const Circle(this.radius);
  final double radius;
  final double area = 0.0; // LINT: should be in initializer list as: area = 3.14159 * radius * radius
  // (Note: in real Dart, area can't reference radius here — so the 0.0 is a placeholder
  //  that should be replaced with the actual computation in the initializer list)
}

// More realistic: the field has a non-trivial default that should be explicit
class ApiClient {
  const ApiClient({required this.baseUrl});
  final String baseUrl;
  final Duration timeout = Duration(seconds: 30); // LINT: computed from const constructor call
  // Better: : timeout = const Duration(seconds: 30) in initializer list
}

// Field initializer that is a const constructor call (not a simple literal)
class Config {
  const Config(this.name);
  final String name;
  final List<String> tags = []; // LINT: non-const empty list (would fail const class too!)
  // Better: : tags = const [] in initializer list
}

// Computed double from expression
class BoundingBox {
  const BoundingBox(this.width, this.height);
  final double width;
  final double height;
  // This would be a compile error to write: final double area = width * height;
  // But developers sometimes write a hardcoded default:
  final double aspectRatio = 1.0; // LINT if there's a better place for it
}
```

### Good (compliant)
```dart
// All field values in initializer list
class Circle {
  const Circle(this.radius) : area = 3.14159 * radius * radius;
  final double radius;
  final double area; // no inline initializer — value comes from initializer list
}

// Simple constant literal as field initializer (acceptable)
class ApiClient {
  const ApiClient({required this.baseUrl});
  final String baseUrl;
  static const Duration defaultTimeout = Duration(seconds: 30); // static const — fine
}

// No field initializers — all set by constructor
class Point {
  const Point(this.x, this.y);
  final double x;
  final double y;
}

// Non-const class — rule doesn't apply
class MutablePoint {
  MutablePoint(this.x, this.y);
  double x;
  double y = 0.0; // non-const class — this pattern is fine
}
```

## Edge Cases & False Positives
- **Static fields**: `static final x = expr;` in a const class is perfectly fine. Do NOT flag static fields.
- **Simple literal initializers**: `final int version = 1;` is a constant literal. While it could technically be in the initializer list, it's not a problem to leave it as a field initializer. Consider NOT flagging simple literals (int, double, String, bool, null) to reduce noise.
- **`const` constructor calls as initializers**: `final Duration timeout = const Duration(seconds: 30);` — this is a const expression and is fine in a const class. Do NOT flag if the field initializer is itself a const expression.
- **Non-const class with const constructor mix**: If a class has both const and non-const constructors, the rule still applies because the const constructor path must be valid.
- **Mixin fields**: Fields introduced by mixins — these are in the mixin declaration, not the class. Skip mixin field analysis (handled when analyzing the mixin directly).
- **Abstract classes with const constructors**: Unusual but possible. Apply the same logic.
- **`late` fields**: `late final x = expr;` is not valid in a const class (late + const is illegal). The Dart compiler already flags this. Do not duplicate.
- **Factory constructors**: Factory constructors cannot be const. If the class has ONLY factory constructors, the rule does not apply. Check for generative const constructors specifically.
- **Override fields**: If a field overrides an abstract getter from an interface, the field declaration may look different. Handle carefully.
- **Null-initialized optional fields**: `final String? name = null;` — null is a const expression. Do not flag (it's equivalent to `final String? name;`).

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: const class with computed const constructor call in field
class WithTimeout {
  const WithTimeout(this.endpoint);
  final String endpoint;
  final Duration timeout = Duration(seconds: 5); // LINT: non-const field init
}

// Violation: const class with non-const list initializer
class WithItems {
  const WithItems(this.name);
  final String name;
  final List<String> items = []; // LINT: non-const list literal
}
```

### Should NOT Trigger (compliant)
```dart
// OK: field initializer is a const literal (simple int)
class WithVersion {
  const WithVersion(this.name);
  final String name;
  final int version = 1; // simple int literal — acceptable
}

// OK: static field
class WithStatic {
  const WithStatic(this.name);
  final String name;
  static final List<String> registry = []; // static — not flagged
}

// OK: no field initializers (all from constructor)
class NoInitializers {
  const NoInitializers(this.x, this.y);
  final int x;
  final int y;
}

// OK: non-const class
class Mutable {
  Mutable(this.name);
  final String name;
  final Duration timeout = Duration(seconds: 5); // non-const class — fine
}
```

## Quick Fix
Move the field initializer to the constructor's initializer list.

**Fix steps:**
1. Find the field initializer expression.
2. Find the const constructor's initializer list (create one if it doesn't exist).
3. Add an entry `fieldName = initializer` to the constructor's initializer list.
4. Remove the initializer from the field declaration (leave the field as `final Type fieldName;` with no initializer).

**Example:**
```dart
// Before
class ApiClient {
  const ApiClient({required this.baseUrl});
  final String baseUrl;
  final Duration timeout = Duration(seconds: 30);
}

// After
class ApiClient {
  const ApiClient({required this.baseUrl})
      : timeout = const Duration(seconds: 30);
  final String baseUrl;
  final Duration timeout;
}
```

**Note**: The fix must also add `const` to the moved expression if it is a const constructor call (e.g., `Duration(seconds: 30)` → `const Duration(seconds: 30)`) because the initializer list context requires const expressions for const constructors.

**Multiple constructors**: If the class has multiple const constructors, the fix must add the initializer to ALL const constructors, or the user must manually add it. Offer the fix only when there is exactly one const constructor, and note when multiple exist.

## Notes & Issues
- Dart SDK: 2.0+ (const constructors and initializer lists).
- This rule is subtle. The Dart compiler already prevents certain invalid patterns (like referencing constructor parameters in field initializers). The rule adds value by guiding developers toward the idiomatic initializer-list style for computed values in const classes.
- Implementation note: the `FieldDeclaration` node contains the `VariableDeclarationList`. Check `VariableDeclarationList.variables` for each `VariableDeclaration` and its `initializer`.
- The checker for "is this a const expression" can use `VariableDeclaration.declaredElement?.constantValue` (returns non-null for compile-time constants). Alternatively, check whether `node.initializer` evaluates via the constant evaluator without errors.
- Performance: `addClassDeclaration` fires once per class. The check is bounded by the number of fields per class, which is typically small (< 20).
- Related rules: `prefer_const_constructors_in_immutables`, `prefer_asserts_in_initializer_lists`, `prefer_const_declarations`.
