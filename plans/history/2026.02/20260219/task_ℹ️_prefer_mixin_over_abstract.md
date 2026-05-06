# Task: `prefer_mixin_over_abstract`

## Summary
- **Rule Name**: `prefer_mixin_over_abstract`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns

## Problem Statement
Before Dart had the `mixin` keyword, developers used abstract classes as a workaround to share concrete behavior across unrelated class hierarchies. The pattern is: an abstract class with no abstract methods and no constructor, used purely for `with` mixing (or `extends` in older code). Since Dart 2.1 introduced the `mixin` keyword, this pattern should be replaced with a proper mixin declaration.

Using an abstract class for pure code sharing has real drawbacks:
1. It misleadingly implies the class can be subclassed with `extends` (which creates tight coupling).
2. It does not communicate the "code sharing" intent — mixins explicitly communicate composability.
3. It prevents using the class as a mixin on classes that already `extend` something (abstract classes used with `with` work, but the `extends` constraint on mixins is more explicit).
4. IDEs and documentation tools treat abstract classes and mixins differently — using the right construct improves tooling accuracy.

## Description (from ROADMAP)
An abstract class that has no abstract methods, no generative constructor, and no `extends` clause is a candidate for conversion to a mixin. The rule flags such classes and suggests converting to `mixin ClassName { ... }`.

## Trigger Conditions
A `ClassDeclaration` where ALL of the following hold:
1. The class is abstract (`node.abstractKeyword != null`).
2. No member is an abstract method (no `MethodDeclaration` where `node.isAbstract`).
3. No member is an abstract getter or setter.
4. No generative constructor is declared.
5. No `extends` clause is present (`node.extendsClause == null`).
6. No `on` clause (already a proper mixin if it had one).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  if (_isPureMixinCandidate(node)) {
    reporter.atToken(node.abstractKeyword!, code);
  }
});
```

### Detection Logic
```dart
bool _isPureMixinCandidate(ClassDeclaration node) {
  // Must be abstract
  if (node.abstractKeyword == null) return false;

  // Must have no extends clause
  if (node.extendsClause != null) return false;

  // Must have no abstract members
  for (final member in node.members) {
    if (member is MethodDeclaration && member.isAbstract) return false;
    if (member is FieldDeclaration && member.isAbstract) return false;
  }

  // Must have no generative constructors
  final hasGenerativeConstructor = node.members
      .whereType<ConstructorDeclaration>()
      .any((c) => !c.factoryKeyword != null);
  if (hasGenerativeConstructor) return false;

  // Must have at least one member (empty abstract class is a different smell)
  if (node.members.isEmpty) return false;

  return true;
}
```

Note: The detection needs to exclude factory constructors — an abstract class CAN have factory constructors (for interface purposes). Only generative constructors prevent mixin conversion.

## Code Examples

### Bad (triggers rule)
```dart
// LINT: abstract class with no abstract methods and no constructor
// — should be a mixin
abstract class Serializable {
  String toJson() => jsonEncode(_toMap());
  Map<String, dynamic> _toMap() => {};
}

// LINT: logging behavior shared across classes — should be a mixin
abstract class Loggable {
  void log(String message) => print('[${runtimeType}] $message');
  void logError(Object error) => print('[${runtimeType}] ERROR: $error');
}

// Usage that triggers the lint:
class UserModel extends Serializable {  // extends mixin-candidate
  final String name;
  UserModel(this.name);
}
```

### Good (compliant)
```dart
// Correct: use mixin for pure code sharing
mixin Serializable {
  String toJson() => jsonEncode(_toMap());
  Map<String, dynamic> _toMap() => {};
}

mixin Loggable {
  void log(String message) => print('[${runtimeType}] $message');
  void logError(Object error) => print('[${runtimeType}] ERROR: $error');
}

// Compliant: abstract class WITH abstract methods (legitimate interface)
abstract class Repository<T> {
  Future<T?> findById(String id);     // abstract method — keep as abstract class
  Future<void> save(T entity);        // abstract method
  Future<void> delete(String id);     // abstract method
}

// Compliant: abstract class WITH extends clause (inheritance chain)
abstract class BaseRepository extends ChangeNotifier {
  void notifyAll() => notifyListeners();
}

// Compliant: abstract class with generative constructor
abstract class BaseWidget {
  final String id;
  BaseWidget(this.id);  // generative constructor — cannot be mixin
}
```

## Edge Cases & False Positives
- **Abstract classes with factory constructors**: A factory constructor does not prevent mixin conversion technically, but in practice a factory constructor means the class is being used as an interface or abstract factory. Do NOT flag abstract classes with factory constructors.
- **Classes that are intended to be extended externally** (in a published package): Cannot know from AST alone if the class is public-facing. Consider excluding `public` abstract classes in package-root libraries (heuristic: no `_` prefix and lives in `lib/`). Or provide a `@allowAbstract` annotation escape hatch.
- **Sealed classes**: A `sealed` class is always abstract. Sealed classes are not candidates for mixin conversion — they define sealed hierarchies. Exclude `sealedKeyword != null`.
- **Classes in `part` files**: The full picture of the class hierarchy may not be available. Consider skipping analysis of part files for this rule.
- **`implements` clause**: An abstract class with `implements SomeInterface` may have a reason for being a class (to implement an interface while providing defaults). Flag with lower confidence or exclude.
- **Type parameter constraints**: `abstract class Processor<T extends Comparable<T>>` — type parameters are fine for mixins too, but check Dart mixin constraints.
- **`@immutable` annotation**: If an abstract class has `@immutable`, it is likely a value class candidate, not a mixin. Exclude.

## Unit Tests

### Should Trigger (violations)
```dart
// Pure concrete-only abstract class — LINT
abstract class Disposable {
  void dispose() {}
}

// Loggable with only concrete methods — LINT
abstract class Auditable {
  void auditLog(String action) => print('AUDIT: $action');
  void auditError(String action, Object e) => print('AUDIT ERROR: $action $e');
}
```

### Should NOT Trigger (compliant)
```dart
// Has abstract method — legitimate interface
abstract class Drawable {
  void draw(Canvas canvas);  // abstract
  void clear(Canvas canvas) {}  // concrete
}

// Has extends — part of hierarchy
abstract class AnimatedWidget extends StatefulWidget {
  void animate();
}

// Has generative constructor — cannot be mixin
abstract class BaseEntity {
  final String id;
  BaseEntity(this.id);
}

// Empty abstract class — different smell, not this rule
abstract class Marker {}

// Sealed class — never a mixin candidate
sealed class Result<T> {}
```

## Quick Fix
**"Convert to mixin"** — Replace `abstract class ClassName` with `mixin ClassName`. Update any `extends ClassName` references in the same file to `with ClassName`. Cannot auto-fix cross-file references — the fix should note this limitation and provide a partial fix for the declaration itself.

Priority: 65.

## Notes & Issues
- Cross-file references to the converted class (callers that use `extends Serializable`) will break after the fix — the fix must either fix them all (complex) or warn the user about manual follow-up.
- The rule should check Dart language version in `pubspec.yaml` — `mixin` keyword requires Dart 2.1+. Since saropa_lints targets modern Dart, this is always satisfied, but document it.
- Consider the `base`, `interface`, `final` class modifiers (Dart 3.0+). If an abstract class has any of these modifiers, it is intentionally constraining inheritance and should not be flagged.
