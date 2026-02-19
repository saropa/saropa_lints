# Task: `avoid_bool_in_widget_constructors`

## Summary
- **Rule Name**: `avoid_bool_in_widget_constructors`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Flutter Widgets

## Problem Statement
Boolean parameters in widget constructors (`bool isLoading`, `bool showHeader`, `bool isEnabled`) make call sites unreadable. When a call site reads `MyWidget(true, false, true)` or even `MyWidget(isLoading: true, showHeader: false)`, the reader must look up the constructor signature to understand what the widget does. This problem compounds when multiple boolean flags exist — the combinatorial explosion of possible states (2^n) is a strong signal that the design should use an enum, sealed class, or widget decomposition instead.

The Flutter SDK itself avoids boolean constructor parameters in most cases, preferring specific widget variants (`ElevatedButton`, `TextButton`, `OutlinedButton` over `Button(style: elevated)`). Following this design guidance produces more self-documenting, refactorable widget hierarchies.

## Description (from ROADMAP)
Detects widget constructors that accept named `bool` parameters, encouraging the use of enums, sealed classes, or widget decomposition for clearer call sites.

## Trigger Conditions
- A `ConstructorDeclaration` belongs to a class that extends `StatelessWidget`, `StatefulWidget`, `State`, `InheritedWidget`, `InheritedNotifier`, `InheritedModel`, `RenderObjectWidget`, or any other class that transitively extends `Widget`
- The constructor has at least one named parameter whose declared type is exactly `bool` or `bool?`
- The parameter is not named `enabled` or `disabled` (these are widely used Flutter SDK conventions — see edge cases)

## Implementation Approach

### AST Visitor
```dart
context.registry.addConstructorDeclaration((node) {
  // ...
});
```

### Detection Logic
1. Resolve the enclosing class element.
2. Walk the supertype chain to determine whether the class ultimately extends `Widget` (from `package:flutter/widgets.dart`). Use the type system, not string matching.
3. Iterate over the constructor's `formalParameters`.
4. For each parameter that is a `DefaultFormalParameter` (named) wrapping a `SimpleFormalParameter`, check whether the declared type is `bool` or `bool?`.
5. Skip parameters in an allowlist: `enabled`, `disabled`, `autofocus`, `obscureText`, `readOnly`, `expands`, `autocorrect`, `enableSuggestions`, `selected`, `checked` — these are established Flutter SDK parameter names where `bool` is idiomatic.
6. Report each offending parameter (not the whole constructor) so the diagnostic points to the specific problematic parameter.

## Code Examples

### Bad (triggers rule)
```dart
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.name,
    required this.isLoading, // LINT: use enum or decompose
    required this.showAvatar, // LINT: use enum or decompose
  });

  final String name;
  final bool isLoading;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) { /* ... */ }
}

// Call site is ambiguous:
UserCard(name: 'Alice', isLoading: true, showAvatar: false)
```

```dart
class DataTable extends StatelessWidget {
  const DataTable({
    super.key,
    required this.rows,
    this.zebra = false, // LINT
    this.compact = false, // LINT
    this.sortable = false, // LINT
  });

  final List<Row> rows;
  final bool zebra;
  final bool compact;
  final bool sortable;

  @override
  Widget build(BuildContext context) { /* ... */ }
}
```

### Good (compliant)
```dart
// Option 1: Decompose into separate widgets
class UserCardLoading extends StatelessWidget {
  const UserCardLoading({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) { /* ... */ }
}

class UserCardLoaded extends StatelessWidget {
  const UserCardLoaded({super.key, required this.name, required this.avatarUrl});
  final String name;
  final String avatarUrl;
  @override
  Widget build(BuildContext context) { /* ... */ }
}

// Option 2: Use an enum for state
enum UserCardState { loading, loaded, error }

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.name, required this.state});
  final String name;
  final UserCardState state;
  @override
  Widget build(BuildContext context) { /* ... */ }
}

// Allowlisted names — no lint
class MyTextField extends StatelessWidget {
  const MyTextField({
    super.key,
    this.enabled = true,      // OK: established Flutter convention
    this.readOnly = false,    // OK: established Flutter convention
    this.autofocus = false,   // OK: established Flutter convention
  });
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  @override
  Widget build(BuildContext context) { /* ... */ }
}
```

## Edge Cases & False Positives
- **Allowlisted parameter names**: `enabled`, `disabled`, `autofocus`, `obscureText`, `readOnly`, `expands`, `autocorrect`, `enableSuggestions`, `selected`, `checked`, `dense`, `wrapped`, `visible` — these mirror the Flutter SDK and are idiomatic. Do not flag these.
- **`Checkbox`, `Switch`, `Radio`**: The `value` parameter (bool) is semantically the purpose of the widget. Consider adding `value` to the allowlist for widgets whose name contains `Check`, `Switch`, `Toggle`, or `Radio`.
- **Override of a parent constructor**: If the constructor `@override`s a parent (e.g., implementing an interface or abstract widget), the parameter type is forced — do not flag parameters in overriding constructors.
- **Private widgets**: Internal/private widgets (class name starts with `_`) may legitimately use bool internally — consider a configurable option to skip private widgets, or set a lower default sensitivity.
- **Single boolean parameter**: A constructor with exactly one boolean named parameter is less harmful than three — consider only flagging when there are 2 or more boolean named parameters.
- **Positional bool parameters in widgets**: These are even worse, but are separately addressed by `avoid_positional_boolean_parameters`.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: two bool named params in StatelessWidget
class Card extends StatelessWidget {
  const Card({super.key, required this.isLoading, required this.showBadge}); // LINT x2
  final bool isLoading;
  final bool showBadge;
  @override Widget build(BuildContext context) => const SizedBox();
}

// Test 2: nullable bool named param
class Panel extends StatelessWidget {
  const Panel({super.key, this.collapsed}); // LINT
  final bool? collapsed;
  @override Widget build(BuildContext context) => const SizedBox();
}
```

### Should NOT Trigger (compliant)
```dart
// Test 3: allowlisted name
class Field extends StatelessWidget {
  const Field({super.key, this.enabled = true, this.readOnly = false});
  final bool enabled;
  final bool readOnly;
  @override Widget build(BuildContext context) => const SizedBox();
}

// Test 4: non-Widget class with bool params
class ViewModel {
  ViewModel({required this.isLoading}); // Not a widget — no lint
  final bool isLoading;
}

// Test 5: enum parameter instead of bool
enum LoadState { loading, loaded }
class Feed extends StatelessWidget {
  const Feed({super.key, required this.state});
  final LoadState state;
  @override Widget build(BuildContext context) => const SizedBox();
}
```

## Quick Fix
**Message**: "Replace bool parameter with an enum type for clarity"

The fix is primarily advisory (a fix cannot automatically redesign the widget), but a partial fix can:
1. Generate a companion enum declaration next to the class: `enum <ClassName><ParamName> { true<ParamName>, false<ParamName> }` — with a TODO comment for the developer to rename the cases meaningfully.
2. Change the parameter type from `bool` to the newly generated enum.
3. Note that all call sites will need to be updated manually.

Alternatively, offer a simpler fix: add `// ignore: avoid_bool_in_widget_constructors` with a comment explaining why the bool is intentional.

## Notes & Issues
- This rule is opinionated and Professional-tier — it will generate discussion. The correction message and documentation should clearly explain the rationale (readability, state-space explosion) to avoid pushback.
- The allowlist of parameter names should be configurable via `analysis_options.yaml` in a future iteration.
- Cross-reference with `avoid_positional_boolean_parameters` — together they form a comprehensive policy on boolean parameters.
- The Flutter team has discussed similar guidelines in flutter/flutter#47406 and related issues.
