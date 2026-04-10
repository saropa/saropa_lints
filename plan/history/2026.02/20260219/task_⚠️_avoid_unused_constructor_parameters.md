# Task: `avoid_unused_constructor_parameters`

## Summary
- **Rule Name**: `avoid_unused_constructor_parameters`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §2 Miscellaneous Rules

## Problem Statement

Constructor parameters that are declared but never used in the constructor body, initializer list, or stored as fields are dead code. They mislead callers into thinking the value matters when it doesn't, and they clutter the API surface.

Common causes:
1. Parameter was used during development but later removed without cleaning the constructor
2. Constructor has an abstract/interface that requires the parameter but this implementation doesn't need it
3. Copy-paste error from another constructor

## Description (from ROADMAP)

> Avoid unused constructor parameters; remove or use them.

## Trigger Conditions

1. A constructor has a parameter (not `this.field` shorthand) that is never:
   - Assigned to a field in the initializer list
   - Referenced in the constructor body
   - Passed to `super()`
   - Named with `_` prefix (discard intent)

## Implementation Approach

```dart
context.registry.addConstructorDeclaration((node) {
  for (final param in node.parameters.parameters) {
    if (param is FieldFormalParameter) continue;  // this.field — always used
    if (param is SuperFormalParameter) continue;  // super.field — always used
    final name = param.name?.lexeme;
    if (name == null || name.startsWith('_')) continue;
    if (!_isParameterUsed(param, node)) {
      reporter.atNode(param, code);
    }
  }
});
```

`_isParameterUsed`: check if the parameter's name appears in:
- `node.initializers` (initializer list)
- `node.body` (constructor body statements)
- `node.redirectedConstructor` (redirecting constructors)

## Code Examples

### Bad (Should trigger)
```dart
class Widget {
  final String title;

  Widget(this.title, String subtitle) {  // ← trigger: subtitle never used
    // subtitle is declared but never referenced
  }
}
```

### Good (Should NOT trigger)
```dart
// All params used ✓
Widget(this.title, String subtitle) : _subtitle = subtitle;

// Discarded param ✓
Widget(this.title, String _) { }  // _ = explicit discard

// Used in body ✓
Widget(this.title, String subtitle) {
  _log(subtitle);
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `@required` deprecated param kept for API compat | **Trigger** — still unused | Note as known limitation |
| Abstract class constructor with unused param | **Trigger** — even abstract, if declared and not used | Subclass cannot use abstract constructor params |
| Named params with default values (optional) | **Trigger if never used** — remove optional params too | |
| `super()` call using the param | **Suppress** — passed to super | Check redirectedConstructor / initializers |
| Factory constructor params | **Trigger similarly** | |
| Generated code | **Suppress** | |

## Unit Tests

1. Constructor with `String subtitle` never referenced in body or init list → 1 lint
2. Constructor with `this.field` (FieldFormal) → no lint
3. Constructor with `super.field` (SuperFormal) → no lint
4. Constructor body using the param → no lint
5. `_` named param → no lint

## Quick Fix

Offer "Remove unused parameter":
```dart
// Before: Widget(this.title, String subtitle)
// After:  Widget(this.title)
```

## Notes & Issues

1. **`required` named params**: If a parameter is `required` but unused, removing it is a breaking change. The quick fix should be offered but with a warning.
2. **Override context**: If the constructor overrides/implements an interface, the signature may be dictated by the interface. Consider suppressing when `@override` is present or class `implements` an interface.
