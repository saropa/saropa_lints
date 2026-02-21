# Task: `avoid_classes_with_only_static_members`

## Summary
- **Rule Name**: `avoid_classes_with_only_static_members`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Classes where every member is static are effectively namespaces pretending to be classes. Dart is not Java — it has top-level functions, top-level variables, and `extension`s. Using a class solely as a namespace:

1. **Misrepresents intent**: A class implies instantiation, inheritance, and polymorphism. A static-only class can never be instantiated meaningfully and the type is never used.
2. **Prevents tree-shaking**: Top-level symbols can be tree-shaken by `dart compile`; static members inside a class cannot be individually eliminated — the whole class is included.
3. **Reduces discoverability**: IDEs surface top-level symbols in autocomplete more prominently than static members.
4. **Encourages anti-patterns**: Developers extend static-only utility classes or implement them as mixins, neither of which works.

The correct Dart idiom is top-level functions and constants, or (for grouping related extensions) `extension` declarations.

## Description (from ROADMAP)
Detects class declarations where all members are static (methods, fields, getters, setters), encouraging refactoring to top-level declarations or extension methods.

## Trigger Conditions
- A `ClassDeclaration` (not `EnumDeclaration`, `MixinDeclaration`, or `ExtensionDeclaration`)
- The class has at least one member
- Every member of the class is either:
  - A `MethodDeclaration` with `isStatic == true`
  - A `FieldDeclaration` with `isStatic == true`
  - A constructor (private constructor preventing instantiation) — see edge cases
- The class does not extend anything other than `Object` implicitly (no `extends`, `implements`, `with` clauses that are non-trivial)
- The class is not annotated with `@sealed`, `@immutable` (which may indicate intentional design pattern)

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  // ...
});
```

### Detection Logic
1. Skip abstract classes — they may serve as type contracts.
2. Retrieve `node.members`.
3. Skip if `node.members` is empty (the empty class lint is separate).
4. Separate members into:
   - Constructors (`ConstructorDeclaration`)
   - Fields (`FieldDeclaration`)
   - Methods/Getters/Setters (`MethodDeclaration`)
4. Check whether there are any non-constructor members.
5. For all non-constructor members: verify each is static (`isStatic == true`).
6. For constructors: a private constructor (`ClassName._()`) is acceptable as a "prevent instantiation" guard — do not count this as a non-static member.
7. If all non-constructor members are static and the only constructors are private (or there are no constructors), report the class.
8. Skip if the class has `extends`, `implements`, or `with` clauses pointing to non-`Object` types.

## Code Examples

### Bad (triggers rule)
```dart
// Classic Java-style utility class.
class MathUtils {
  static const double pi = 3.14159265358979;

  static double circleArea(double radius) => pi * radius * radius;

  static double squareArea(double side) => side * side;
}

// With private constructor guard — still a smell.
class StringUtils {
  StringUtils._(); // private constructor

  static String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static bool isBlank(String s) => s.trim().isEmpty;
}

// Constants namespace.
class AppColors {
  static const Color primary = Color(0xFF1A237E);
  static const Color secondary = Color(0xFF283593);
  static const Color surface = Color(0xFFFFFFFF);
}
```

### Good (compliant)
```dart
// Top-level constants — preferred.
const double pi = 3.14159265358979;
double circleArea(double radius) => pi * radius * radius;
double squareArea(double side) => side * side;

// Top-level functions.
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
bool isBlank(String s) => s.trim().isEmpty;

// Or use an extension for grouping.
extension StringExtensions on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
  bool get isBlank => trim().isEmpty;
}

// Constants in a file — no class wrapper needed.
const Color appPrimaryColor = Color(0xFF1A237E);
const Color appSecondaryColor = Color(0xFF283593);

// Enum for a fixed set of named values.
enum AppStatus { loading, loaded, error }
```

## Edge Cases & False Positives
- **Flutter `Icons`, `Colors`, `Fonts` pattern**: Flutter's own `Icons` and `Colors` classes are static-only. This is a deliberate SDK design choice — the developer cannot change them. Consider an allowlist for classes that mirror Flutter SDK patterns (containing only static const fields).
- **Abstract classes**: Abstract classes with only static members may serve as type tagging or as namespace anchors for static factory methods. Skip abstract classes.
- **`@immutable` or `@sealed`**: These annotations indicate deliberate design decisions. Do not flag annotated classes.
- **Classes with `extends`**: A class that `extends SomeBase` has an inheritance relationship — it is not purely a namespace. Do not flag.
- **Classes that `implements` an interface**: Even if all current members are static, the interface may require future instance members. Do not flag.
- **Classes with `with` mixins**: Mixin application implies instance usage. Do not flag.
- **Classes with `@visibleForTesting` annotation**: These are sometimes static-only test helper classes. Consider skipping.
- **Classes from generated code**: Skip `*.g.dart`, `*.freezed.dart`.
- **Empty classes**: An empty class body is a different problem. Skip empty classes.
- **Private classes**: Private classes (`_MyUtils`) that are static-only may be intentionally scoped to a file — consider a separate or reduced severity for private classes.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: simple static utility class
class Calc {
  static int add(int a, int b) => a + b; // LINT
  static int sub(int a, int b) => a - b;
}

// Test 2: with private constructor
class Formatter {
  Formatter._();
  static String format(double v) => v.toStringAsFixed(2); // LINT
}

// Test 3: constants-only class
class Sizes {
  static const double small = 8.0; // LINT
  static const double large = 16.0;
}
```

### Should NOT Trigger (compliant)
```dart
// Test 4: has instance member
class Validator {
  static final _instance = Validator._();
  Validator._();
  bool validate(String s) => s.isNotEmpty; // instance method — no lint
}

// Test 5: extends something
class SpecialList extends ListBase<String> {
  static int count = 0;
  // has instance members from ListBase
  @override int get length => 0;
  @override void set length(int l) {}
  @override String operator [](int i) => '';
  @override void operator []=(int i, String v) {}
}

// Test 6: abstract class
abstract class Repository {
  static Repository get instance => _instance;
  static final Repository _instance = _RepositoryImpl();
}
```

## Quick Fix
**Message**: "Convert static class members to top-level declarations"

The fix is complex and should be advisory only:
1. Suggest moving each static member to the top-level of the file, prefixing the name with the class name if needed to avoid collisions (e.g., `MathUtils.circleArea` → `mathUtilsCircleArea` or just `circleArea`).
2. Note that the class declaration should be deleted after the move.
3. Note that all references (`MathUtils.circleArea(r)`) must be updated to the top-level form (`circleArea(r)`) — this is a cross-file change the quick fix cannot perform automatically.

An alternative quick fix: "Add private constructor to suppress instantiation" — this is a weaker fix that at least prevents accidental instantiation while the developer plans the refactor.

## Notes & Issues
- This rule generates significant discussion because patterns like `AppColors` and `AppStrings` are extremely common in Flutter projects. The correction message should be diplomatic and explain why top-level symbols are preferred, not just that the pattern is wrong.
- Consider making the rule skip classes that contain only `static const` fields (pure constant namespaces) at the Recommended tier, and flag them only at Pedantic tier.
- Dart's official linter has `avoid_classes_with_only_static_members` — review its implementation and known exclusions before implementing.
- The fix suggestion to use `extension` methods is only appropriate when the static methods operate on a specific type — not for general utility functions.
