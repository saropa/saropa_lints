# Task: `prefer_const_literals_to_create_immutables`

## Summary
- **Rule Name**: `prefer_const_literals_to_create_immutables`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Performance / Flutter

## Problem Statement
Collection literals (lists, sets, maps) passed as arguments to constructors of `@immutable`-annotated classes should use the `const` keyword to avoid unnecessary object allocation on each widget rebuild. In Flutter, widgets rebuild frequently. If a `BoxDecoration` is reconstructed with a non-const `[BoxShadow()]` list on every build, it creates new list and object instances even though the values are identical every time. Making such literals `const` allows the Dart runtime to share a single canonical instance, reducing GC pressure and improving rebuild performance. This is especially important in `build()` methods and other hot paths.

## Description (from ROADMAP)
Flags non-const collection literals passed to `@immutable`-annotated class constructors when all elements of the literal are compile-time constants.

## Trigger Conditions
- An `InstanceCreationExpression` creates an instance of a class annotated with `@immutable` (directly or via inheritance from an `@immutable` class).
- One or more arguments to the constructor are collection literals (`ListLiteral`, `SetOrMapLiteral`) that are NOT already prefixed with `const`.
- All elements within those collection literals are compile-time constants (literals, `const` constructor calls, `const` references).
- The collection literal type parameters (if explicit) are also const-capable.

## Implementation Approach

### AST Visitor
```dart
context.registry.addInstanceCreationExpression((node) {
  // inspection happens here
});
```

### Detection Logic
1. Obtain the class element of `node.staticType`.
2. Check if the class or any of its superclasses has the `@immutable` annotation:
   - Walk the inheritance chain and check `element.metadata` for an annotation whose element is `package:meta/meta.dart`'s `immutable`.
   - `flutter/foundation.dart` re-exports `@immutable` — handle both import paths.
3. For each argument in `node.argumentList.arguments`:
   a. Get the argument's expression (unwrap `NamedExpression` if needed).
   b. Check if it is a `ListLiteral` or `SetOrMapLiteral` without `const` keyword (`literal.constKeyword == null`).
   c. Check if all elements of the literal are constant expressions:
      - For `ListLiteral`: each element in `literal.elements`.
      - For `SetOrMapLiteral`: each element in `literal.elements` (which are `CollectionElement` — `MapLiteralEntry`, `ExpressionCollectionElement`, `SpreadElement`).
      - A `SpreadElement` with a non-const iterable is not const-capable.
      - `IfElement` and `ForElement` (collection-if and collection-for) are never const.
   d. If the literal has no `const` prefix AND all elements are constant, report the literal node.
4. Alternatively (broader approach): use `context.registry.addListLiteral` and `addSetOrMapLiteral` visitors and check the parent context to determine if it is an `@immutable` constructor argument.

## Code Examples

### Bad (triggers rule)
```dart
// Non-const list passed to BoxDecoration
Container(
  decoration: BoxDecoration(
    boxShadow: [            // LINT: should be const [...]
      BoxShadow(
        color: Colors.black,
        blurRadius: 4,
      ),
    ],
  ),
)

// Non-const list passed to custom immutable widget
@immutable
class MyWidget extends StatelessWidget {
  const MyWidget({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// Call site:
MyWidget(
  items: ['alpha', 'beta', 'gamma'], // LINT: all elements are const strings
)

// Non-const map in an immutable constructor
InputDecoration(
  suffixIconConstraints: BoxConstraints(
    maxHeight: 20,
  ),
  // hypothetical:
  // metadata: {'key': 'value'}, // LINT if such a param existed
)
```

### Good (compliant)
```dart
// Already const
Container(
  decoration: BoxDecoration(
    boxShadow: const [       // OK: already has const
      BoxShadow(
        color: Colors.black,
        blurRadius: 4,
      ),
    ],
  ),
)

// Elements are not all const (contains a runtime variable)
String getLabel() => DateTime.now().toIso8601String();
MyWidget(
  items: ['alpha', getLabel()], // OK: getLabel() is not const
)

// Collection-if — never const
MyWidget(
  items: [
    'alpha',
    if (condition) 'beta',   // OK: collection-if is not const-capable
  ],
)

// Non-immutable class
class Mutable {
  Mutable({required this.items});
  List<String> items;
}
Mutable(items: ['x', 'y']); // OK: Mutable is not @immutable
```

## Edge Cases & False Positives
- **Inherited `@immutable`**: `StatelessWidget` inherits from `Widget` which is annotated `@immutable`. Any `StatelessWidget` subclass constructor call should trigger this rule. The inheritance walk must be comprehensive.
- **`const` already present**: If the literal already has `const`, skip. Check `literal.constKeyword != null`.
- **`const` keyword on the outer `InstanceCreationExpression`**: If the outer `new`/`const` applies to the whole expression (e.g., `const BoxDecoration(...)`), the inner literals are implicitly const. In this case, skip inner literals.
- **Collection-if (`[if (x) y]`)**: Not a constant expression. Do NOT flag.
- **Collection-for (`[for (var x in xs) x]`)**: Not a constant expression. Do NOT flag.
- **Spread operator (`[...other]`)**: If `other` is a const list, the spread is const-capable. If `other` is a runtime list, it is not. Handle carefully.
- **Empty collection literals**: `[]` is trivially const-capable. Flag and suggest `const []`.
- **Nested non-const constructors**: If an element of the list is `MyClass()` (no `const`) where `MyClass` has a const constructor, it is not automatically const — the caller must write `const MyClass()`. In this case, we'd need to also add `const` to the element — this may be outside scope. Consider only flagging when all elements are already const or primitive literals.
- **Type arguments**: `<String>['a', 'b']` — the type argument `String` is always a constant type, so this is fine. Explicit type arguments do not prevent const.
- **`@sealed` classes**: Similar to `@immutable` — consider extending the check to `@sealed` classes, though they are less common.
- **Third-party packages**: The rule should work for any `@immutable`-annotated class, not just Flutter. The check is annotation-based, not package-specific.

## Unit Tests

### Should Trigger (violations)
```dart
import 'package:meta/meta.dart';

@immutable
class Config {
  const Config({required this.tags});
  final List<String> tags;
}

void triggerTest() {
  // LINT: ['a', 'b'] is all const strings but not marked const
  Config(tags: ['alpha', 'beta']);
}

@immutable
class PaddingWidget extends StatelessWidget {
  const PaddingWidget({required this.colors, super.key});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget buildWidget() {
  return PaddingWidget(
    colors: [Colors.red, Colors.blue], // LINT
  );
}
```

### Should NOT Trigger (compliant)
```dart
// OK: already const
Config(tags: const ['alpha', 'beta']);

// OK: non-const element
String getTag() => 'dynamic';
Config(tags: ['alpha', getTag()]);

// OK: collection-if
bool show = true;
Config(tags: ['alpha', if (show) 'beta']);

// OK: class is not @immutable
class NotImmutable {
  NotImmutable({required this.items});
  final List<String> items;
}
NotImmutable(items: ['x', 'y']); // no @immutable — skip
```

## Quick Fix
Add the `const` keyword before the collection literal.

- `['a', 'b']` → `const ['a', 'b']`
- `{'key': 'value'}` → `const {'key': 'value'}`
- `{'a', 'b'}` → `const {'a', 'b'}`

**Fix steps:**
1. Find the start of the `ListLiteral` or `SetOrMapLiteral` source range.
2. Insert `const ` before the opening bracket.
3. Do not modify the enclosing `InstanceCreationExpression`.

**Note**: If elements of the literal are themselves `InstanceCreationExpression` without `const`, the fix should ideally add `const` to those too (cascading const). However, this is complex and may be best handled as a follow-up. For the initial fix, only add `const` to the top-level collection literal and let the user address nested non-const constructors separately (they will likely get separate lint warnings from `prefer_const_constructors`).

## Notes & Issues
- Dart SDK: 2.0+. Flutter: any version.
- The `@immutable` annotation is defined in `package:meta`. Flutter's `package:flutter/foundation.dart` re-exports it. The annotation check must handle both import paths by using the element's library URI rather than the import alias.
- The official Dart lint rule `prefer_const_literals_to_create_immutables` exists in `package:lints`. Verify whether this is redundant with the saropa version. If overlapping, ensure the saropa rule adds differentiated value (better fix, narrower scope, or project-context integration).
- Performance: Walking the inheritance chain for `@immutable` on every `InstanceCreationExpression` can be costly if not cached. Cache the result per `ClassElement` using the element's identity hash.
- The visitor approach of `addInstanceCreationExpression` may be broad. Consider `addListLiteral` and filtering based on parent context — this is more targeted but requires upward AST traversal which can be slower.
