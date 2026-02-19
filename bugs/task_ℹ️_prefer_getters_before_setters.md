# Task: `prefer_getters_before_setters`

## Summary
- **Rule Name**: `prefer_getters_before_setters`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Organization

## Problem Statement
Getter/setter pairs in Dart classes should list the getter before the setter. The getter is the read accessor and is more frequently accessed in normal usage — readers encountering a property want to see its type and return value first. Placing the setter first reverses this expectation and creates a subtle cognitive friction when navigating class members.

The Dart style guide does not explicitly mandate getter-before-setter, but all official Dart SDK examples and the Flutter framework source consistently place getters first. Making this explicit as a lint prevents the ordering from drifting in large codebases.

## Description (from ROADMAP)
Within a class, mixin, or extension, when a getter and a setter share the same name, the getter should be declared before the setter. The rule flags a setter that appears before its paired getter.

## Trigger Conditions
A setter declaration where a getter with the same name exists later in the same class, mixin, or extension body. The setter must appear at a lower index in `members` than the getter with the matching name.

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  _checkGetterSetterOrder(node.members, reporter);
});
context.registry.addMixinDeclaration((node) {
  _checkGetterSetterOrder(node.members, reporter);
});
context.registry.addExtensionDeclaration((node) {
  _checkGetterSetterOrder(node.members, reporter);
});
```

### Detection Logic
1. Build a map of `memberName -> {getterIndex, setterIndex}` by iterating `members`.
2. For each `MethodDeclaration` that is a setter (`member.isSetter`), record its index.
3. For each `MethodDeclaration` that is a getter (`member.isGetter`), record its index.
4. After full iteration, for any name where both a getter and setter exist, if `setterIndex < getterIndex`, report the setter node.

```dart
void _checkGetterSetterOrder(
  NodeList<ClassMember> members,
  ErrorReporter reporter,
) {
  final getterIndexes = <String, int>{};
  final setterNodes = <String, MethodDeclaration>{};
  final setterIndexes = <String, int>{};

  for (int i = 0; i < members.length; i++) {
    final member = members[i];
    if (member is! MethodDeclaration) continue;
    if (member.isGetter) {
      getterIndexes[member.name.lexeme] = i;
    } else if (member.isSetter) {
      setterIndexes[member.name.lexeme] = i;
      setterNodes[member.name.lexeme] = member;
    }
  }

  for (final name in setterIndexes.keys) {
    final getterIdx = getterIndexes[name];
    final setterIdx = setterIndexes[name]!;
    if (getterIdx != null && setterIdx < getterIdx) {
      reporter.atNode(setterNodes[name]!, code);
    }
  }
}
```

## Code Examples

### Bad (triggers rule)
```dart
class Config {
  Duration _timeout = const Duration(seconds: 30);

  // LINT: setter appears before getter
  set timeout(Duration v) {
    _timeout = v;
  }

  Duration get timeout => _timeout;
}

class Theme {
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.green;

  // LINT: setter before getter
  set primaryColor(Color c) => _primaryColor = c;
  Color get primaryColor => _primaryColor;

  // Also LINT: setter before getter
  set secondaryColor(Color c) => _secondaryColor = c;
  Color get secondaryColor => _secondaryColor;
}
```

### Good (compliant)
```dart
class Config {
  Duration _timeout = const Duration(seconds: 30);

  // Getter declared first
  Duration get timeout => _timeout;

  set timeout(Duration v) {
    _timeout = v;
  }
}

class ReadOnlyModel {
  final String _name;
  ReadOnlyModel(this._name);

  // Getter-only property — no setter, no rule
  String get name => _name;
}

class WriteOnlyLog {
  final _buffer = StringBuffer();

  // Setter-only — no matching getter, not flagged
  set entry(String line) => _buffer.writeln(line);
}
```

## Edge Cases & False Positives
- **Getter-only properties**: A getter with no corresponding setter is not flagged — there is no pair to order.
- **Setter-only properties**: A setter with no corresponding getter is not flagged by this rule (that is a separate smell — preferring explicit getters where setters exist is a different concern).
- **Inherited getter with local setter**: If the getter is defined in a superclass and the setter is defined in the subclass, the pair straddles classes. This rule only checks within the same declaration body — inherited members are not visible in `members`. Do not flag this case.
- **Abstract getters/setters**: Ordering still matters for abstract members; the rule applies equally.
- **Private vs public names**: `get _value` and `set _value` are paired correctly by name match including underscore prefix.
- **Extension types**: Extension types can have getters; apply the same check if they support setters in future Dart versions.
- **Generated files**: Skip files ending in `.g.dart` or `.freezed.dart` — generated code ordering should not trigger style rules.

## Unit Tests

### Should Trigger (violations)
```dart
class Paginator {
  int _page = 1;

  set page(int p) => _page = p;  // LINT: setter before getter

  int get page => _page;
}

mixin Resizable {
  double _scale = 1.0;

  set scale(double s) => _scale = s;  // LINT

  double get scale => _scale;
}
```

### Should NOT Trigger (compliant)
```dart
class Paginator {
  int _page = 1;

  int get page => _page;        // getter first
  set page(int p) => _page = p; // setter second
}

class Logger {
  final _buffer = StringBuffer();

  // No getter for this setter — not flagged
  set logLine(String line) => _buffer.writeln(line);
}

abstract class Sizeable {
  // Both abstract, getter first
  double get width;
  set width(double v);
}
```

## Quick Fix
**"Swap getter and setter order"** — Move the setter declaration to immediately after its paired getter. The fix must preserve any dartdoc comments attached to the setter. If the getter and setter are not adjacent, the fix moves the setter to immediately after the getter (insertion + deletion at original position).

Priority: 55 (style ordering fix, lower priority).

## Notes & Issues
- Consider whether this rule should also check `EnumDeclaration` — Dart enums can have getters but not setters, so the rule would be a no-op for enums. Skip enum declarations to avoid unnecessary AST traversal.
- When generating the quick fix, check that any `@override` annotation on the setter is also moved.
- This rule is closely related to `prefer_constructors_first` and `prefer_static_before_instance`. Consider grouping them under a single "member ordering" category in the documentation.
- The rule name mirrors the pattern of `sort_pub_dependencies` — clearly descriptive, action-oriented.
