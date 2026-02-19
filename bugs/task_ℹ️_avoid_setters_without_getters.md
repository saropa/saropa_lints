# Task: `avoid_setters_without_getters`

## Summary
- **Rule Name**: `avoid_setters_without_getters`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
A setter without a corresponding getter creates an asymmetric, write-only API. The caller
can push a value into the object but has no way to observe it. This pattern is almost
always a design flaw for one of several reasons:

1. **Testability**: You cannot verify that the set value was actually used or stored
   correctly without a getter.
2. **Debuggability**: You cannot inspect the current value during debugging without a
   getter.
3. **API coherence**: If a concept has a setter, callers naturally expect a getter — the
   absence of one is surprising and violates the principle of least surprise.
4. **Alternative exists**: If a value is truly write-only (e.g., a password), the idiomatic
   Dart pattern is to use a method (`setPassword(String p)`) that documents the one-way
   nature explicitly, rather than a setter that implies get-set symmetry.

## Description (from ROADMAP)
Flag setter declarations where no corresponding getter with the same name exists in the
same class (or its hierarchy).

## Trigger Conditions
1. A `MethodDeclaration` is a setter (`node.isSetter == true`).
2. The class containing the setter does not declare a getter with the same name anywhere
   in its body.
3. The setter name does not match an accessible getter inherited from a superclass
   (check inherited members via element lookup).
4. The class is not abstract (abstract classes often define partial contracts completed
   by subclasses).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) { ... });
```
Collect all setters and getters for each class in a single pass, then cross-reference.

Alternatively:
```dart
context.registry.addMethodDeclaration((node) { ... });
```
When visiting a setter, look up the class's members to check for a matching getter.

### Detection Logic

**Approach A (class-level scan — preferred for completeness):**
1. For each `ClassDeclaration`, collect:
   - All `MethodDeclaration` nodes where `isSetter == true` → setter names set.
   - All `MethodDeclaration` nodes where `isGetter == true` → getter names set.
   - All `FieldDeclaration` nodes → field names (a field provides both getter and setter
     implicitly; if a field exists, any explicit setter for the same name is complemented).
2. For each setter name, check:
   a. Is it in the getter names set? If yes, skip (getter exists in class).
   b. Is it in the field names set? If yes, skip (field acts as getter).
   c. Does the resolved `ClassElement` have an inherited getter with that name (not from
      `Object`)? If yes, skip.
3. Report setters that pass none of the above checks.

**Approach B (setter-level scan — simpler implementation):**
1. For each setter `MethodDeclaration`, extract `name.lexeme`.
2. Get the enclosing `ClassElement` from the setter's `declaredElement.enclosingElement`.
3. Use `classElement.lookUpGetter(name, library)` to find a getter (declared or
   inherited).
4. If no getter is found, report the setter.

Approach B is simpler and sufficient for most cases. Start with B.

## Code Examples

### Bad (triggers rule)
```dart
class Config {
  Duration _timeout = const Duration(seconds: 30);

  // Setter without getter — BAD
  set timeout(Duration d) {
    _timeout = d;
  }

  void execute() {
    // _timeout is used internally but never readable from outside
  }
}
```

```dart
class FormField {
  String? _error;

  // Write-only error — caller can't check what the current error is
  set error(String? message) {
    _error = message;
    _rebuild();
  }

  void _rebuild() { /* ... */ }
}
```

### Good (compliant)
```dart
// ok: symmetric getter + setter
class Config {
  Duration _timeout = const Duration(seconds: 30);

  Duration get timeout => _timeout;

  set timeout(Duration d) {
    _timeout = d;
  }
}
```

```dart
// ok: use a method for write-only semantics (documents intent)
class SecureStore {
  void setPassword(String password) {
    // store hashed password — write-only by design
  }
}
```

```dart
// ok: abstract class — getter may be in subclass
abstract class Configurable {
  set timeout(Duration d);
}
```

```dart
// ok: field provides both getter and setter implicitly
class Box {
  int width = 0;   // implicit getter and setter
}
```

```dart
// ok: setter complements an inherited getter
class Base {
  int get value => _value;
  int _value = 0;
}

class Derived extends Base {
  set value(int v) { _value = v; }  // ok: getter inherited from Base
}
```

## Edge Cases & False Positives
- **Abstract classes**: An abstract class may declare only a setter, expecting the
  subclass to provide the getter (or vice versa). Do not flag setters in abstract classes
  unless no known concrete subclass provides the getter (that is too expensive to check).
  Conservative: skip all abstract class setters.
- **Inherited getters**: If the getter is defined in a superclass, `lookUpGetter` should
  find it. Verify that `lookUpGetter` searches the full hierarchy including mixins.
- **Mixins providing the getter**: A mixin applied to the class may provide the getter.
  The `ClassElement.lookUpGetter` should resolve through mixins as well.
- **Extension methods**: An extension may provide a getter for the class. This is harder
  to detect statically (extensions are not part of the class's element model). Conservative:
  do not check extensions — document this as a known limitation.
- **`noSuchMethod` overridden**: Classes that override `noSuchMethod` to intercept all
  method calls effectively have all getters "available" dynamically. Skip classes with
  `noSuchMethod` overrides.
- **`@protected` setters**: A protected setter may have a protected getter in a subclass.
  Flag but note in the message that a subclass or extension may supply the getter.
- **Operator `[]=` without `[]`**: The `[]=` operator is effectively a setter; `[]` is
  the getter. A class with `[]=` but not `[]` should also be flagged (extend the rule to
  cover operators).
- **`covariant` parameters in setters**: Does not affect this rule — the setter is still
  a setter.

## Unit Tests

### Should Trigger (violations)
```dart
class Timer {
  Duration _interval = Duration.zero;

  set interval(Duration d) { _interval = d; }  // LINT: no getter
}

class Label {
  String _text = '';
  set text(String v) { _text = v; }            // LINT: no getter
}
```

### Should NOT Trigger (compliant)
```dart
// ok: getter exists
class Timer {
  Duration _interval = Duration.zero;
  Duration get interval => _interval;
  set interval(Duration d) { _interval = d; }
}

// ok: abstract class
abstract class Sizeable {
  set size(int s);
}

// ok: field acts as both getter and setter
class Box {
  int width = 0;
}

// ok: inherited getter
class Base { int get value => 0; }
class Sub extends Base {
  set value(int v) { /* override store */ }
}
```

## Quick Fix
**Suggest adding a getter or converting the setter to a method.**

Option 1: Generate a getter backed by the private field:
```dart
// Add getter
Duration get timeout => _timeout;
```

Option 2: Convert the setter to a named method:
```dart
// Before
set timeout(Duration d) { _timeout = d; }

// After
void setTimeout(Duration d) { _timeout = d; }
```

The auto-fix for option 1 inserts a generated getter declaration immediately before the
setter. The backing field is inferred from the setter body if it is a simple assignment
(`_field = value`).

## Notes & Issues
- The rule name aligns with analogous rules in other linters (e.g., SonarQube's
  "Getters and setters should access the expected fields").
- `lookUpGetter` in the analyzer API may require the `LibraryElement` context; ensure
  the correct library element is passed.
- The `[]=` operator extension is a nice-to-have v2 feature. Ship the basic setter
  detection first.
- Consider a companion rule: `avoid_getters_without_setters` for the reverse asymmetry
  (though that is far less common and less of a bug — read-only properties are idiomatic).
- Document in the rule message that the preferred alternative to a write-only setter is
  a clearly named method (e.g., `setPassword`, `updateConfig`).
