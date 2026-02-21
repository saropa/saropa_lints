# Task: `prefer_form_bloc_for_complex`

## Summary
- **Rule Name**: `prefer_form_bloc_for_complex`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.9 Forms & Validation Rules / §5.24 Form/TextFormField Rules
- **Priority**: ⭐ Next in line for implementation

## Problem Statement

Forms with more than 5 fields, conditional visibility/enablement logic, or multi-step wizard flows are notoriously error-prone when implemented with raw `StatefulWidget` + `GlobalKey<FormState>`. State mutation is scattered across handlers, field interdependencies are tracked with ad-hoc booleans, and testing requires full widget mounts. A dedicated form state management solution (FormBloc, Reactive Forms, `flutter_form_builder`) centralises validation, submission, and field lifecycle in one testable object.

## Description (from ROADMAP)

> Forms with >5 fields, conditional logic, or multi-step flows benefit from form state management (FormBloc, Reactive Forms).

This rule detects:
1. `Form` widgets whose immediate `Column`/`ListView` children contain more than 5 `TextFormField` (or equivalent) widgets.
2. `TextFormField.onChanged` callbacks that call `setState` and alter other fields' visibility/enabled state.
3. Multi-step `Stepper` / `PageView` + `Form` combos with manual step validation.

## Implementation Approach

### Package Detection
Only fire if the project does NOT already use one of:
- `form_bloc` / `flutter_form_bloc`
- `reactive_forms`
- `flutter_form_builder`
- `formz`

Use `ProjectContext.usesPackage(...)` for each. If any is found, suppress the rule.

### AST Visitor Pattern

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isFormWidget(node)) return;
  final fields = _countTextFormFieldDescendants(node);
  if (fields > 5) {
    reporter.atNode(node, code);
  }
});
```

Key helpers needed:
- `_isFormWidget(node)` — checks `node.staticType` is `Form`
- `_countTextFormFieldDescendants(node)` — walks `children` argument recursively (Column, ListView, Wrap, etc.)

### Counting Fields
Walk the `children` named argument of `Column`/`ListView` found inside the `Form` body. Count nodes whose static type is assignable to `TextFormField`, `TextFormFieldCustom`, or anything with `formField` in the class name (to catch wrapped fields). **Limit recursion depth** to avoid performance issues — cap at 4 levels.

### Conditional Logic Detection (Phase 2)
Detect `onChanged` callbacks inside a `Form` that call `setState(() { _someFieldVisible = ...; })`. This is lower priority than the field count check.

## Code Examples

### Bad (Should trigger)
```dart
// More than 5 TextFormFields with manual state
Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(controller: _name),
      TextFormField(controller: _email),
      TextFormField(controller: _phone),
      TextFormField(controller: _address),
      TextFormField(controller: _city),
      TextFormField(controller: _country),  // 6th field → trigger
      TextFormField(controller: _zipCode),
    ],
  ),
)
```

### Good (Should NOT trigger)
```dart
// Using flutter_form_builder (detected via import / ProjectContext)
FormBuilder(
  key: _fbKey,
  child: Column(children: [...]),
)

// Simple form with ≤5 fields — no suggestion needed
Form(
  child: Column(children: [
    TextFormField(),
    TextFormField(),
    TextFormField(),
  ]),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Project already uses `reactive_forms` | **Suppress** entirely | Use `ProjectContext.usesPackage` |
| Wrapped `TextFormField` subclass | **Count it** | Check static type, not just class name string |
| `TextFormField` inside `Visibility(visible: false)` | **Count it** — it still exists in the tree | The hidden field still represents complexity |
| `ListView.builder` with dynamic fields | **Do NOT count** — count is unknown at static analysis time | Only count literal `children: [...]` arrays |
| `Stepper` widget containing `Form` with 3 fields per step, 3 steps | Total visible at once ≤ 5, but total app fields > 5 — **gray area** | Phase 2: count total across all steps |
| Form inside a `Dialog` / `BottomSheet` | Should still trigger — field count is the same | No special exemption |
| Test files | Should suppress — test files often create large forms as fixtures | Use `ProjectContext.isTestFile(path)` |
| `FormField<T>` that is NOT `TextFormField` | Should count it — it's still a form field | Check assignability to `FormField` not just `TextFormField` |

## Unit Tests

### Violations
1. `Form` with 6 `TextFormField` children in a `Column` → 1 lint
2. `Form` with 7 fields, some wrapped in `Padding` → 1 lint (needs depth traversal)
3. `Form` in a `Stepper` with 3 steps of 3 fields each (9 total) → 1 lint (Phase 2)
4. `Form` with 6 fields AND project has no form management package → 1 lint

### Non-Violations
1. `Form` with 4 fields → no lint
2. `Form` with 6 fields, project imports `reactive_forms` → no lint
3. `Form` with 6 fields, project imports `flutter_form_bloc` → no lint
4. `ListView.builder` with dynamic `TextFormField` builder → no lint (can't count statically)
5. Test file with 10-field form → no lint

## Quick Fix

No automated quick fix — the migration involves architectural changes. The suggestion message should point to relevant packages.

```
correctionMessage: 'Consider flutter_form_bloc, reactive_forms, or flutter_form_builder for complex forms.'
```

## Notes & Issues

1. **Duplicate entry in ROADMAP**: This rule appears in both §1.9 (line 145, with ⭐) and §5.24 (line 777, without ⭐). Delete both entries when implementing.
2. **Depth of AST traversal is expensive** — capping at 4 levels of nesting is important for performance. Consider early exit once count exceeds 5.
3. **The 5-field threshold is opinionated** — consider making it configurable via `analysis_options.yaml` custom lint options.
4. **Phase 1** (field count) is tractable. **Phase 2** (conditional logic detection) is much harder and likely needs deferral — detecting `setState` callbacks that mutate field visibility requires inter-method data flow which is not available in the single-pass AST model.
5. **Package check order matters** — do the `ProjectContext` package check first, before any AST traversal, as it's O(1) vs. O(n) for AST walking.
