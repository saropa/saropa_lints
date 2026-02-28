# Task: `prefer_final_fields`

## Summary
- **Rule Name**: `prefer_final_fields`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Class fields that are only ever assigned in the constructor or at the point of declaration
(never reassigned afterward) should be declared `final`. Omitting `final` when a field
never changes misrepresents the design intent, suppresses compiler optimizations (the
compiler cannot inline or constant-fold a mutable field), and allows accidental
reassignment that would otherwise be a compile-time error. Marking such fields `final`
makes immutability explicit and auditable at a glance.

## Description (from ROADMAP)
Flag class fields declared without `final` when the field is never reassigned outside its
initializer or constructor.

## Trigger Conditions
1. A class field is declared with `var` or a bare type annotation (no `final`, `const`, or `late`).
2. The field has exactly one assignment path: either a field initializer (`String name = ''`)
   or an initializing formal in the constructor (`this.name`), or both (field initializer plus
   constructor default).
3. No other method, setter, or callback in the class body ever assigns to that field.

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) { ... });
```
Walk the class body once to collect all field declarations, then walk again to collect all
assignment expressions. Cross-reference: any field with zero assignments outside its
initializer/constructor is a candidate.

### Detection Logic
1. For each `ClassDeclaration`, gather every `FieldDeclaration` whose variables are not
   already `final`, `const`, or `late`.
2. Collect the names of all such mutable field variables.
3. Walk the entire class body (methods, setters, closures, initializer lists) looking for
   `AssignmentExpression` nodes where the left-hand side is a `SimpleIdentifier` or
   `PropertyAccess` (with `this.`) matching a candidate field name.
4. Also scan for prefix/postfix increment/decrement (`++`/`--`) on candidate fields.
5. Any candidate field that has zero such assignments is a violation — report on the
   `FieldDeclaration` node.
6. Skip `abstract` classes if the field is marked `@protected` (subclasses may assign it).
7. Skip fields annotated with `@visibleForTesting` or in test files.

## Code Examples

### Bad (triggers rule)
```dart
class User {
  String name;          // never reassigned — should be final
  int age;              // never reassigned — should be final

  User(this.name, this.age);

  String greet() => 'Hello, $name';
}
```

```dart
class Config {
  String host = 'localhost';   // initializer only, never changed

  Config();

  String get url => 'https://$host';
}
```

### Good (compliant)
```dart
class User {
  final String name;
  final int age;

  User(this.name, this.age);

  String greet() => 'Hello, $name';
}
```

```dart
class Counter {
  int count = 0;          // reassigned below — compliant

  void increment() => count++;
}
```

```dart
class Config {
  String host = 'localhost';   // mutable — assigned in setter

  set hostname(String value) { host = value; }
}
```

## Edge Cases & False Positives
- **Setters**: A field assigned inside a setter must not be flagged, even if no setter is
  called at the callsite visible to analysis — the setter exists and can be called.
- **`late` fields**: Fields marked `late` are excluded; they exist precisely because they
  cannot be made `final` at declaration time in all patterns (though `late final` is valid
  and separately recommended).
- **Abstract classes**: Fields in abstract classes may be assigned by subclasses; unless
  the field is private (`_`), do not flag.
- **Mixins**: Mixin fields can be assigned by the class that uses the mixin; skip fields
  in `mixin` declarations unless the field is private to the mixin.
- **`@protected` fields**: May be assigned by subclasses — skip.
- **Cascades**: `..field = value` is an assignment and must be detected.
- **Closures that capture `this`**: An assignment to a field inside a closure (e.g.,
  `Future.delayed(..., () { name = 'new'; })`) still counts as a reassignment.
- **Compound assignments**: `name += suffix;` is a reassignment.
- **Records and sealed classes**: Typically already use final — low risk, but rule should
  still handle them correctly.
- **Generative vs factory constructors**: Factory constructors do not use initializing
  formals; trace through to the redirected constructor.

## Unit Tests

### Should Trigger (violations)
```dart
// violation: field never reassigned
class Point {
  int x;
  int y;
  Point(this.x, this.y);
}

// violation: initializer only
class Singleton {
  String label = 'default';
}
```

### Should NOT Trigger (compliant)
```dart
// ok: final already
class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}

// ok: reassigned in method
class Toggle {
  bool isOn = false;
  void toggle() { isOn = !isOn; }
}

// ok: reassigned in setter
class Box {
  int width = 0;
  set size(int v) { width = v; }
}

// ok: late field
class Lazy {
  late String value;
  void init(String v) { value = v; }
}

// ok: assigned in cascade
class Builder {
  String result = '';
  void apply(String s) { result = s; }
}
```

## Quick Fix
**Add `final` modifier to the field declaration.**

```dart
// Before
String name;

// After
final String name;
```

The fix inserts `final ` before the type keyword (or `var`, which should be removed).
If the field uses `var`, replace `var` with `final`.

## Notes & Issues
- This rule overlaps with the built-in Dart linter rule `prefer_final_fields` that ships
  with the Dart SDK analyzer plugins. Before implementing, confirm whether the SDK rule
  is already included in the saropa_lints `analysis_options.yaml` baseline. If it is,
  this task becomes about surfacing it at the correct tier rather than reimplementing it.
- The cross-class assignment analysis (through `this`-captures in closures) is the hardest
  part; a conservative first pass can skip closures and only look at direct method/setter
  bodies — add closure analysis in a follow-up.
- Performance note: iterating the full class body twice is acceptable for class sizes in
  typical Dart code; avoid using `CompilationUnit`-wide traversal.
