# Task: `avoid_missing_controller`

## Summary
- **Rule Name**: `avoid_missing_controller`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Testing Rules AND §1.62 Widget/Flutter Rules (appears TWICE)

## ⚠️ DUPLICATE ENTRY NOTE

This rule appears TWICE in ROADMAP.md:
1. Testing Rules section: "Widgets with controllers should have controllers provided"
2. Widget/Flutter Rules section: "Widgets requiring controllers should have them provided"

These are identical rules. **Both ROADMAP entries should be deleted** when this rule is implemented.

## Problem Statement

Flutter widgets like `TextField`, `TextEditingController`, `ScrollController`, `AnimationController`, `TabController`, `PageController`, `VideoPlayerController` etc. require a controller to be managed properly. When no controller is provided:

1. Flutter creates an internal controller that cannot be accessed or disposed
2. The developer cannot read the current value (e.g., text field value)
3. The controller cannot be disposed, potentially causing a resource leak
4. Tests cannot inspect or control the widget's state

The fix is to create a controller in `initState()`, use it, and dispose it in `dispose()`.

## Description (from ROADMAP)

> Widgets with controllers should have controllers provided.

## Trigger Conditions

1. `TextField` without a `controller` parameter
2. `TextFormField` without a `controller` parameter (but if using `FormKey`, the form's state can control it — check for this)
3. `ListView` / `GridView` with `physics: ScrollPhysics()` but no `controller`
4. `AnimationController` not assigned to a field (created locally in `build()`)
5. `PageView` without a `PageController` field
6. `TabBarView` / `TabBar` without a `TabController`

## Implementation Approach

### Phase 1 — TextField without controller

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isTextField(node)) return;
  if (_hasControllerArg(node)) return;
  if (_isInForm(node)) return;  // Form manages state via FormKey
  reporter.atNode(node, code);
});
```

`_isTextField`: check constructor is `TextField(...)` or `TextFormField(...)`.
`_hasControllerArg`: check for `controller` named argument.
`_isInForm`: check if the TextField is inside a `Form` widget — in that case, the FormState can access the value.

### Phase 2 — Controller created in build()

```dart
context.registry.addVariableDeclaration((node) {
  if (!_isControllerType(node.declaredElement?.type)) return;
  if (_isInsideBuildMethod(node)) {
    reporter.atNode(node, code);
  }
});
```

Controllers created in `build()` are recreated on every rebuild.

## Code Examples

### Bad (Should trigger)
```dart
// TextField with no controller — can't read value
TextField(
  // ← trigger: no controller
  decoration: InputDecoration(labelText: 'Name'),
)

// AnimationController in build() — recreated every frame!
@override
Widget build(BuildContext context) {
  final controller = AnimationController(  // ← trigger
    vsync: this,
    duration: Duration(seconds: 1),
  );
  return FadeTransition(opacity: controller, child: ...);
}
```

### Good (Should NOT trigger)
```dart
// Proper controller lifecycle ✓
class _FormState extends State<MyForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);  // ✓ controller provided
  }
}

// TextField inside Form — FormState manages it ✓
Form(
  key: _formKey,
  child: TextFormField(  // ✓ Form manages state
    validator: (value) => value!.isEmpty ? 'Required' : null,
  ),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `TextField` inside `Form` with `FormKey` | **Suppress** — FormState manages the field | `TextFormField` without controller in Form is OK |
| `TextField` for search (no need to read value) | **False positive** — `onChanged` callback provides value | Many legit use cases don't need a controller |
| `TextField` with `onChanged` only (no controller) | **Suppress if onChanged is provided** | onChanged is an alternative to controller for reading values |
| Read-only `TextField` (readonly: true) | **Suppress** — no need to control read-only field | |
| Test file | **Suppress or trigger** — tests need controllers too | May want to trigger with note |
| `HookWidget` using `useTextEditingController` | **Suppress** — flutter_hooks provides the controller | Detect `useTextEditingController()` call |
| `AnimationController` created in `initState` and stored | **Suppress** — properly managed | Check if assigned to a field |
| Reactive Forms `ReactiveTextField` | **Suppress** — form control is injected differently | `ProjectContext.usesPackage('reactive_forms')` |

## Unit Tests

### Violations
1. `TextField()` without `controller:` parameter → 1 lint
2. `AnimationController(...)` created inside `build()` → 1 lint

### Non-Violations
1. `TextField(controller: _controller)` → no lint
2. `TextFormField()` inside `Form(key: _formKey, ...)` → no lint
3. `TextField(onChanged: (v) => setState(...))` → no lint (alternate pattern)
4. Test file → no lint

## Quick Fix

Offer "Add a controller field":
```dart
// Suggests adding:
late final TextEditingController _nameController;

// In initState():
_nameController = TextEditingController();

// In dispose():
_nameController.dispose();

// And adding controller: _nameController to the TextField
```

This is a multi-location fix — may not be automatable as a simple quick fix.

## Notes & Issues

1. **DUPLICATE ROADMAP ENTRY** — delete BOTH entries (Testing Rules and Widget/Flutter Rules) when implementing.
2. **`onChanged` vs controller**: Many legitimate Flutter apps use `onChanged` to capture text without a controller. The rule should not flag `TextField` with `onChanged` provided.
3. **The "inside Form" suppression is crucial** — `TextFormField` without a controller inside a `Form` is the canonical Flutter pattern for form handling. Flagging it would cause massive false positives.
4. **Phase 1 (TextField without controller)** is the most impactful. **Phase 2 (AnimationController in build)** is a separate concern but related.
