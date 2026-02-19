# Task: `prefer_constructors_first`

## Summary
- **Rule Name**: `prefer_constructors_first`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Organization

## Problem Statement
Dart style convention recommends placing constructors before other members in a class for discoverability. When a reader opens a class, they expect to find the constructors first — they define how the object is created, which is the entry point to understanding the class. Placing methods before constructors forces readers to scroll through implementation details before understanding how to construct the object.

The Dart style guide and the `sort_constructors_first` lint (in `package:lints`) both reinforce this convention. Having a project-level lint ensures teams consistently follow this ordering even when the official lints are not enabled.

## Description (from ROADMAP)
Constructors should appear before non-constructor members (methods, getters, setters) in a class body. Fields before constructors are acceptable. The standard ordering is: static fields, instance fields, constructors, getters/setters, methods.

## Trigger Conditions
A constructor declaration (including factory constructors and redirecting constructors) that appears after any method declaration within the same class body. Fields appearing after constructors are not flagged by this rule (that is a separate `prefer_fields_first` concern).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  _checkMemberOrdering(node, reporter);
});
```

### Detection Logic
1. Iterate `node.members` in order.
2. Track a boolean `seenMethod` that becomes `true` once a `MethodDeclaration` (that is not a getter/setter — or include getters/setters depending on scope) is encountered.
3. For each `ConstructorDeclaration` encountered, if `seenMethod` is already `true`, report the constructor node.
4. Alternatively, find the index of the last constructor and the index of the first method. If `firstMethodIndex < lastConstructorIndex`, report.

```dart
void _checkMemberOrdering(ClassDeclaration node, ErrorReporter reporter) {
  int lastConstructorIndex = -1;
  int firstMethodIndex = -1;

  for (int i = 0; i < node.members.length; i++) {
    final member = node.members[i];
    if (member is ConstructorDeclaration) {
      lastConstructorIndex = i;
    } else if (member is MethodDeclaration && !member.isGetter && !member.isSetter) {
      if (firstMethodIndex == -1) firstMethodIndex = i;
    }
  }

  if (firstMethodIndex != -1 &&
      lastConstructorIndex != -1 &&
      firstMethodIndex < lastConstructorIndex) {
    // Report the out-of-order constructor
    final outOfOrderConstructor = node.members
        .whereType<ConstructorDeclaration>()
        .firstWhere((c) => node.members.indexOf(c) > firstMethodIndex);
    reporter.atNode(outOfOrderConstructor, code);
  }
}
```

## Code Examples

### Bad (triggers rule)
```dart
class User {
  final String name;

  void login() {
    // method appears before constructor
    print('Logging in $name');
  }

  // LINT: constructor appears after method declaration
  User(this.name);
}

class Repository {
  static Repository? _instance;

  static Repository get instance => _instance ??= Repository._();

  // LINT: constructor appears after method/getter
  Repository._();

  Future<List<Item>> fetchAll() async => [];
}
```

### Good (compliant)
```dart
class User {
  final String name;

  // Constructor first
  User(this.name);

  void login() {
    print('Logging in $name');
  }
}

class Repository {
  static Repository? _instance;

  // Constructor before methods
  Repository._();

  static Repository get instance => _instance ??= Repository._();

  Future<List<Item>> fetchAll() async => [];
}

class AbstractBase {
  // Abstract classes with no constructor are fine
  void doWork();
}
```

## Edge Cases & False Positives
- **Factory constructors**: Should be treated as constructors and follow the same rule. A `factory` keyword before the name marks it as a constructor declaration in the AST.
- **Abstract class members**: Abstract methods before constructors should still trigger if a constructor follows.
- **Operator declarations**: Operators (`operator ==`, `operator []`) should be treated like methods for ordering purposes.
- **Generated code**: Files with `// generated` or `// GENERATED CODE` header comments should be excluded — generated code often has non-standard ordering.
- **Mixin declarations**: Mixins cannot have generative constructors, so this rule does not apply to `mixin` declarations.
- **Extension declarations**: Extensions cannot have constructors at all; skip extension nodes.
- **`part` files**: Ordering concerns span the whole class, which may be split. Consider skipping `part` files.
- **Single constructor, many methods**: The rule fires even if there is only one constructor after one method — consistency matters.
- **Redirecting constructors**: `MyClass.named() : this(0);` is still a constructor declaration and should be ordered before methods.

## Unit Tests

### Should Trigger (violations)
```dart
// Violation: method before constructor
class Counter {
  int _count = 0;

  void increment() => _count++;  // method first

  Counter();  // LINT: constructor after method
}

// Violation: factory before regular constructor does not trigger,
// but regular constructor after method does
class Config {
  final String host;

  String get url => 'https://$host';  // getter before constructor

  Config(this.host);  // LINT
}
```

### Should NOT Trigger (compliant)
```dart
// Compliant: fields → constructors → methods
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
  Point.origin() : this(0, 0);

  double distanceTo(Point other) => ...;
}

// Compliant: no constructors at all
class Helper {
  static String format(String s) => s.trim();
}

// Compliant: abstract class with no constructor
abstract class Serializable {
  Map<String, dynamic> toJson();
}
```

## Quick Fix
**"Move constructor before methods"** — Reorder the source so the constructor declaration (and its dartdoc comment, if any) is placed immediately after the last field declaration (or at the top of the class body if no fields exist). This is a multi-edit fix involving deletion and insertion of the constructor block.

Priority: 60 (lower than critical fixes; this is a style concern).

## Notes & Issues
- The official `sort_constructors_first` lint in `package:lints` covers a subset of this. Check whether saropa_lints already re-implements or delegates to that rule before implementing.
- The quick fix for multi-constructor classes needs to move ALL out-of-order constructors as a batch, not just the first.
- Ordering between factory and generative constructors is debatable — for this rule, any constructor type placed after any method type is a violation.
- Consider a configuration option `includeGettersSetters: true` to also flag getters/setters that precede constructors, for teams that want strict ordering.
