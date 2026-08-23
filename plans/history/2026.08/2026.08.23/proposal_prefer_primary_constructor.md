# PROPOSAL: `prefer_primary_constructor` — Flag classes eligible for Dart 3.13+ primary constructor syntax

**Status: Implemented**

Created: 2026-08-23
Category: `config/dart_sdk_migration_rules` (or `core/class_constructor_rules`)
Proposed tier: Professional
Proposed severity: INFO
Source: Whitepaper evaluation — "Overcoming AI Model Regression in Dart 3+"

---

## Summary

Flag simple classes that could use Dart 3.13+ primary constructor syntax instead
of verbose traditional constructors with manual field declarations. AI code
generators consistently produce the pre-3.13 boilerplate pattern even when the
target SDK is >=3.13.0.

---

## Problem

LLMs produce this:

```dart
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;
}
```

When the SDK constraint permits this:

```dart
class UserProfile(final String id, final String displayName);
```

No existing saropa_lints rule or Dart SDK lint flags this pattern.

---

## Detection Logic

Flag a class when ALL of these hold:

1. Has exactly ONE unnamed generative constructor (not factory, not named)
2. Constructor body is empty (no initializer list, no assertion, no method body)
3. ALL constructor parameters are `this.paramName` field formals
4. ALL instance fields are `final`
5. Class does NOT extend anything other than `Object`
6. Class is NOT a mixin class
7. Class does NOT have a `with` clause
8. Class does NOT have any factory constructors
9. Class does NOT have any named constructors
10. The project's SDK lower bound is >=3.13.0 (requires pubspec read)

### Exclusions (expect NO lint)

- Classes with initializer lists (`MyClass(this.x) : assert(x > 0)`)
- Classes with constructor bodies (`MyClass(this.x) { validate(); }`)
- Classes extending another class (`class Foo extends Bar`)
- Mixin classes (`mixin class Foo`)
- Classes with factory constructors
- Classes with multiple constructors
- Classes with non-final fields
- Classes with fields not covered by the constructor
- Extension types (already use primary constructors — no migration needed)
- Widget subclasses (extend StatelessWidget/StatefulWidget — excluded by rule 5)

### Implementation Notes

- Checking the SDK lower bound from pubspec.yaml requires
  `AnalysisContext.contextRoot.root` to locate the pubspec. This is available
  in the analyzer plugin API via `ResolvedUnitResult.session.analysisContext`.
  Cache the parsed version per context root to avoid re-reading on every file.
- If pubspec reading is too expensive or fragile, the rule can be gated on a
  configuration flag (`min_sdk: "3.13.0"`) in `analysis_options.yaml` instead.
- The `ClassDeclaration` AST node provides `members` (fields, methods,
  constructors) for inspection. Check `ConstructorDeclaration.body` is
  `EmptyFunctionBody` and `initializers` is empty.

---

## Quick Fix

Replace the class with primary constructor syntax:

**Before:**
```dart
class Point {
  const Point(this.x, this.y);

  final double x;
  final double y;
}
```

**After:**
```dart
class Point(final double x, final double y);
```

The fix must:
- Preserve `const` if the original constructor was const
- Preserve doc comments on the class
- Preserve annotations on the class
- Move field doc comments to parameter doc comments (if supported)
- Handle named parameters: `({required this.x})` → `({required final double x})`

---

## Fixture Cases

The fixture at `example*/lib/config/prefer_primary_constructor_fixture.dart`
should include:

1. Simple class with two final fields — expect LINT
2. Class with const constructor and final fields — expect LINT
3. Class with named parameters — expect LINT
4. Class with optional parameters and defaults — expect LINT
5. Class extending another class — expect NO lint
6. Class with initializer list — expect NO lint
7. Class with constructor body — expect NO lint
8. Class with factory constructor — expect NO lint
9. Class with non-final fields — expect NO lint
10. Class with fields not in constructor — expect NO lint
11. Widget subclass — expect NO lint
12. Mixin class — expect NO lint
13. Extension type — expect NO lint (already uses primary constructors)
14. Class with multiple constructors — expect NO lint
15. Empty class with no fields — expect NO lint

---

## Risk Assessment

- **False positive risk: MEDIUM** — the eligibility conditions are strict, but
  edge cases around generic type parameters, metadata annotations on fields vs
  constructor params, and mixin applications need thorough fixture coverage.
- **Codebase impact: LOW** — professional tier, INFO severity. No existing code
  breaks; the rule suggests modernization, not correctness.
- **Analyzer compatibility:** Requires analyzer ^12.1.0 (current cap). The
  `ClassDeclaration.primaryConstructor` API is available in analyzer 12.x.
