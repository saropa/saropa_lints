> **========================================================**
> **DUPLICATE -- COVERED BY EXISTING RULES**
> **========================================================**
>
> `ProperSuperCallsRule` in `class_constructor_rules.dart`
> already checks super.initState() ordering (must be first)
> and super.dispose() ordering (must be last). The "missing
> super" case is enforced by Dart SDK's `@mustCallSuper`
> annotation on State lifecycle methods. Nothing left to add.
>
> **========================================================**

# Task: `avoid_suspicious_super_overrides`

## Summary
- **Rule Name**: `avoid_suspicious_super_overrides`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.58 Class & Inheritance Rules

## Problem Statement

When overriding methods, `super.methodName(args)` calls the parent implementation. Suspicious patterns include:

1. **Calling `super` with completely different arguments** — suggests the override is not correctly forwarding state
2. **Not calling `super` at all in lifecycle methods** (e.g., `dispose()`, `initState()`) — common cause of memory leaks and missing initialization
3. **Calling `super` multiple times** — calls the parent implementation twice, which may cause double initialization or double disposal
4. **Calling `super` in the wrong position** (e.g., `super.dispose()` before doing cleanup that the parent's dispose may depend on)

## Description (from ROADMAP)

> Detect suspicious super.method() calls in overrides.

## Trigger Conditions

### Phase 1 — Missing `super` in lifecycle overrides
1. `@override` method named `dispose()`, `initState()`, `didChangeDependencies()`, `deactivate()` that does NOT call `super.method()`
2. These methods MUST call super in Flutter's widget lifecycle

### Phase 2 — Double `super` calls
Detect `super.method()` called twice in the same override body.

### Phase 3 — Wrong position for `dispose`
`super.dispose()` called BEFORE doing cleanup work (resources disposed before parent's disposal may affect order).

## Implementation Approach

### Phase 1 AST Pattern

```dart
const _requiredSuperMethods = {
  'dispose', 'initState', 'didChangeDependencies', 'deactivate',
  'didUpdateWidget', 'reassemble',
};

context.registry.addMethodDeclaration((node) {
  if (!_isOverride(node)) return;
  if (!_requiredSuperMethods.contains(node.name.lexeme)) return;
  if (!_isFlutterLifecycleContext(node)) return;
  if (_callsSuper(node)) return;
  reporter.atNode(node, code);
});
```

`_isOverride`: check for `@override` annotation.
`_isFlutterLifecycleContext`: enclosing class extends `State<T>`, `StatefulWidget`, or `RenderObject`.
`_callsSuper`: look for `super.${node.name}(...)` in the method body.

## Code Examples

### Bad (Should trigger)
```dart
// Missing super.dispose() — memory leak!
class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {  // ← trigger: no super.dispose()
    _controller.dispose();
    // Missing: super.dispose();
  }
}

// Missing super.initState()
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {  // ← trigger: no super.initState()
    _initializeController();
    // Missing: super.initState();
  }
}

// Calling super twice
class _MyState extends State<Widget> {
  @override
  void dispose() {
    super.dispose();  // ← trigger: called twice
    _controller.dispose();
    super.dispose();  // ← second call is suspicious
  }
}
```

### Good (Should NOT trigger)
```dart
// Proper super call ✓
class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();  // ✓ calls super
  }

  @override
  void initState() {
    super.initState();  // ✓ super first
    _initializeController();
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `dispose()` in a mixin that intentionally skips super | **False positive** — mixins have complex super call chains | Check if mixin; may need to suppress |
| Method that calls super via a helper | **False negative** — can't trace into helper | Known limitation |
| `AutomaticKeepAliveClientMixin` overrides | **Suppress** — this mixin has specific super call requirements | |
| `SingleTickerProviderStateMixin.dispose()` | **Suppress** if mixin is in chain | Complex mixin hierarchy |
| `@mustCallSuper` annotation on parent method | **Strengthen** — if parent is annotated `@mustCallSuper`, the no-super case is definitely wrong | Use `@mustCallSuper` as a stronger signal |
| Test file | **Suppress** | |
| `dispose()` calling `super.dispose()` in the wrong order | **Phase 3 detection** — deferred | |

## Unit Tests

### Violations
1. `State.dispose()` override without `super.dispose()` → 1 lint
2. `State.initState()` override without `super.initState()` → 1 lint
3. Override with `super.dispose()` called twice → 1 lint

### Non-Violations
1. `dispose()` with proper `super.dispose()` → no lint
2. Non-lifecycle override without super → no lint (not in the required set)
3. Test file → no lint
4. Abstract class override → no lint

## Quick Fix

Offer "Add `super.dispose()` call":
```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();  // ← added
}
```

## Notes & Issues

1. **`@mustCallSuper` annotation** in the Dart SDK already flags missing super calls for methods annotated with it. Check if `State.dispose()` is already annotated — if so, the SDK already handles this and our rule should focus on other suspicious patterns (double-super, wrong-order-super).
2. **Phase 1 (missing super in lifecycle)** may be largely covered by the existing `@mustCallSuper` detection. Focus Phase 1 on the double-super and argument-mismatch cases instead.
3. **Mixin chains** make super call analysis complex. Mixins in Flutter (e.g., `SingleTickerProviderStateMixin`) have their own `dispose()` implementations and must also be called. The rule needs to be aware of mixin stacking.
