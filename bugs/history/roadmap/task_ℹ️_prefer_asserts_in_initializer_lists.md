# Task: `prefer_asserts_in_initializer_lists`

## Summary
- **Rule Name**: `prefer_asserts_in_initializer_lists`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Constructor Patterns

## Problem Statement
When `assert()` statements appear as the first statements in a constructor body, they can often be moved to the constructor's initializer list instead. Initializer list asserts (`ClassName(this.x) : assert(x > 0)`) run at construction time before the constructor body executes and before `super()` is called (actually: initializer list runs in order, with super being called within it). This is the idiomatic Dart pattern, it is clearer about preconditions, and in debug mode it can catch violations earlier in the construction process. Additionally, initializer list asserts work in `const` constructors — body asserts do not. Moving asserts to the initializer list is both a style improvement and sometimes a functional requirement for const constructors.

## Description (from ROADMAP)
Detects `assert()` statements appearing in constructor bodies that could be moved to the constructor's initializer list, following the Dart idiom for precondition checking.

## Trigger Conditions
- The node is an `AssertStatement` found as a statement inside a `ConstructorDeclaration`'s body block.
- The assert is the first statement in the body OR among leading assert statements (multiple consecutive asserts at the top of the body).
- The assert's condition expression does NOT reference `this` in a way that is invalid in an initializer list (e.g., calling an instance method or accessing an instance field that could be overridden).
- The assert's condition only references constructor parameters (accessible in initializer list) or static members.

## Implementation Approach

### AST Visitor
```dart
context.registry.addConstructorDeclaration((node) {
  // inspection happens here
});
```

### Detection Logic
1. Check that `node.body` is a `BlockFunctionBody` (not expression body or empty body).
2. Get the statements list from `node.body.block.statements`.
3. Scan the leading statements: collect consecutive `AssertStatement` nodes at the start of the body.
4. If no leading `AssertStatement` is found, skip.
5. For each leading `AssertStatement`:
   a. Analyze the assert condition expression.
   b. Check that it does NOT call any instance methods or access instance fields that are not constructor parameters (e.g., `this.computedProperty` or `_helperMethod()`).
   c. Check that it only uses: constructor parameters (via `this.param` or just `param`), literals, static members, top-level functions.
   d. If the condition is safe to move, report the `AssertStatement`.
6. If the constructor already has an initializer list, the assert can simply be added to it. If not, a new initializer list must be created.
7. Skip constructors that are redirecting (`this(...)`) — they cannot have an initializer list.

**Safety check for initializer-list compatibility:**
- An expression is safe to move to the initializer list if it only references:
  - Constructor parameters (including `this.` parameters).
  - Literals (numbers, strings, booleans, null).
  - Static methods and fields.
  - Top-level functions.
  - Operators applied to the above.
- An expression is NOT safe if it:
  - Calls an instance method (e.g., `validate()` on `this`).
  - Accesses an instance property that isn't a constructor parameter.
  - Uses `super.anything`.
  - Contains a closure that captures `this`.

## Code Examples

### Bad (triggers rule)
```dart
class UserProfile {
  UserProfile({required this.name, required this.age}) {
    assert(name.isNotEmpty); // LINT: move to initializer list
    assert(age >= 0);        // LINT: move to initializer list
    _init();
  }

  final String name;
  final int age;
  void _init() {}
}

class Radius {
  Radius(this.value) {
    assert(value >= 0, 'Radius must be non-negative'); // LINT
  }

  final double value;
}

class Config {
  Config({required this.host, required this.port}) {
    assert(host.isNotEmpty, 'Host cannot be empty');    // LINT
    assert(port > 0 && port < 65536, 'Invalid port');  // LINT
    _connect();
  }

  final String host;
  final int port;
  void _connect() {}
}
```

### Good (compliant)
```dart
// Already in initializer list
class UserProfile {
  UserProfile({required this.name, required this.age})
      : assert(name.isNotEmpty),
        assert(age >= 0) {
    _init();
  }

  final String name;
  final int age;
  void _init() {}
}

// Only in initializer list (no body needed)
class Radius {
  const Radius(this.value) : assert(value >= 0, 'Radius must be non-negative');
  final double value;
}

// Assert that references an instance method — can't move
class Validator {
  Validator(this.data) {
    assert(_isValid(data)); // OK: _isValid is an instance method — cannot move
  }

  final String data;
  bool _isValid(String s) => s.length > 3;
}

// Assert after non-assert statements — not a "leading" assert
class Late {
  Late(this.x) {
    print('constructing');
    assert(x > 0); // OK: not a leading assert — skip
  }

  final int x;
}
```

## Edge Cases & False Positives
- **Asserts referencing instance methods**: `assert(_isValid())` where `_isValid` is an instance method — these CANNOT be moved to the initializer list because instance methods are not accessible there. Do NOT flag these.
- **Asserts in redirecting constructors**: `MyClass.named() : this(0)` — redirecting constructors cannot have any other initializer list entries. Do NOT flag asserts in the body of redirecting constructors.
- **Asserts in const constructors**: If the constructor is already `const`, asserts in the body are a compile error in Dart (const constructors cannot have a body with statements). However, the analyzer would already flag this. Do not double-report.
- **Multiple asserts with non-assert statements in between**: Only treat consecutive leading asserts as a group. If a non-assert statement appears between two asserts, only flag the ones before the non-assert.
- **`assert()` with message expressions that call instance methods**: `assert(x > 0, 'Value is $toStringMethod()')` — the message expression can be arbitrary, but initializer list asserts also support message expressions. However, if the message expression calls an instance method, it cannot be moved. Check both condition and message.
- **Named constructors**: Apply the same logic to named constructors (e.g., `MyClass.named()`).
- **Factory constructors**: Factory constructors do not have initializer lists. Skip entirely.
- **`super` constructor calls**: If the constructor body has `super.method()` in asserts (very unusual), those cannot move. Skip.
- **Asserts that reference `this` explicitly**: `assert(this.name != null)` — `this` is not available in an initializer list. Do NOT flag. However, `this.name` in an initializer list via a formal parameter (`this.name`) IS valid as a simple field reference but NOT as a method call.
- **Shadowed parameters**: If a constructor has `this.name` as a formal parameter, inside the initializer list `name` refers to the parameter value (the incoming value before assignment). This is subtly different from `this.name` in the body (which reads the field). Usually equivalent for validation, but be aware.

## Unit Tests

### Should Trigger (violations)
```dart
class TriggerLeadingAssert {
  TriggerLeadingAssert(this.x) {
    assert(x > 0); // LINT
  }
  final int x;
}

class TriggerMultipleLeadingAsserts {
  TriggerMultipleLeadingAsserts({required this.a, required this.b}) {
    assert(a.isNotEmpty); // LINT
    assert(b >= 0);       // LINT
    _setup();
  }
  final String a;
  final int b;
  void _setup() {}
}

class TriggerWithMessage {
  TriggerWithMessage(this.value) {
    assert(value != null, 'Value must not be null'); // LINT
  }
  final Object value;
}
```

### Should NOT Trigger (compliant)
```dart
// OK: already in initializer list
class AlreadyGood {
  AlreadyGood(this.x) : assert(x > 0);
  final int x;
}

// OK: assert references instance method
class InstanceMethodAssert {
  InstanceMethodAssert(this.data) {
    assert(_validate()); // cannot move
  }
  final String data;
  bool _validate() => data.isNotEmpty;
}

// OK: assert is not leading (preceded by other statement)
class NotLeading {
  NotLeading(this.x) {
    print('hello');
    assert(x > 0); // not leading
  }
  final int x;
}

// OK: factory constructor (no initializer list possible)
class FactoryConstructor {
  factory FactoryConstructor.create(int x) {
    assert(x > 0);
    return FactoryConstructor._internal(x);
  }
  FactoryConstructor._internal(this.x);
  final int x;
}

// OK: redirecting constructor
class RedirectingCtor {
  RedirectingCtor(int x) : this._internal(x);
  RedirectingCtor._internal(this.x) {
    assert(x > 0); // in body of non-redirecting — this WOULD be flagged
  }
  final int x;
}
```

## Quick Fix
Move the `assert()` statement(s) from the constructor body to the initializer list.

**Fix steps:**
1. Collect all leading `AssertStatement` nodes from the constructor body.
2. Extract the condition and optional message from each assert.
3. Build initializer list entries: `assert(condition)` or `assert(condition, message)`.
4. If the constructor has no existing initializer list:
   - Insert ` : assert(cond)` after the parameter list closing `)` and before the `{`.
   - If multiple asserts: ` : assert(cond1), assert(cond2)`.
5. If the constructor has an existing initializer list:
   - Append the assert entries to the existing initializer list (after the last entry, before `{`).
6. Remove the assert statements from the body.
7. If the body becomes empty after removal, optionally suggest removing the body braces and using `;` (but only if there were no other body statements — this is a secondary suggestion).

**Example transformation:**
```dart
// Before
MyClass(this.x) : super() {
  assert(x > 0);
  doWork();
}

// After
MyClass(this.x) : super(), assert(x > 0) {
  doWork();
}
```

## Notes & Issues
- Dart SDK: 2.0+. Assert in initializer list was introduced in Dart 2.0.
- The `AssertStatement` vs `AssertInitializer`: In the AST, `assert` in an initializer list is represented as `AssertInitializer` (a type of `ConstructorInitializer`), while `assert` in a body is an `AssertStatement`. The fix must convert between these AST representations.
- The `context.registry.addConstructorDeclaration` visitor fires once per constructor. For classes with many constructors, each is analyzed independently.
- This rule applies to all Dart code, not just Flutter. It is a general Dart idiom.
- Related rules: `prefer_const_constructors_in_immutables` (which makes const constructors feasible — and const constructors require initializer list asserts, not body asserts).
- The message in `assert(condition, message)` in an initializer list follows the same rules as in the body. The message can be any expression, but for initializer list placement the same restrictions apply (no instance method calls in the message either).
- The official Dart lint `prefer_asserts_in_initializer_lists` exists. Verify overlap.
