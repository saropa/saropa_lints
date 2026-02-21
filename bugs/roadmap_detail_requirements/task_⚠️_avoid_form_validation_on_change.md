# Task: `avoid_form_validation_on_change`

## Summary
- **Rule Name**: `avoid_form_validation_on_change`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.24 Form/TextFormField Rules

## Problem Statement

Calling `Form.of(context)?.validate()` or `_formKey.currentState?.validate()` inside `onChanged` (or `onChange`) callbacks runs form validation on every single keystroke. This is:

1. **Performance waste**: Validation runs 10-20x more than needed for a typical word
2. **UX anti-pattern**: Showing validation errors before the user finishes typing is annoying
3. **Unnecessary `setState` calls**: If validation changes state, it rebuilds the form constantly

The established UX best practice (Google Material Design, iOS HIG):
- Validate on **submit** (when form is submitted)
- Or validate on **focus lost** (`onEditingComplete`, `focusNode.addListener`)
- NOT on every keystroke

```dart
// BAD: validates every keystroke
TextField(
  onChanged: (value) {
    _formKey.currentState?.validate(); // ← runs on every keystroke
  },
)
```

## Description (from ROADMAP)

> Validating every keystroke is expensive. Detect onChanged triggering validation.

## Trigger Conditions

1. A `TextField` or `TextFormField`'s `onChanged` callback contains:
   - `_formKey.currentState?.validate()`
   - `Form.of(context)?.validate()`
   - `validate()` method call with a form key receiver
2. `setState` inside `onChanged` that triggers expensive recomputation

## Implementation Approach

```dart
context.registry.addNamedExpression((node) {
  if (node.name.label.name != 'onChanged') return;
  final value = node.expression;
  if (value is! FunctionExpression) return;
  // Walk the function body for validate() calls
  value.body.accept(ValidateCallVisitor(reporter));
});
```

`ValidateCallVisitor`: looks for method invocations where:
- Method name is `validate`
- Receiver contains `currentState` or is `Form.of(context)`

## Code Examples

### Bad (Should trigger)
```dart
TextFormField(
  onChanged: (value) {
    _formKey.currentState?.validate();  // ← trigger: validate on every keystroke
  },
  validator: (value) => value?.isEmpty == true ? 'Required' : null,
)

// Also bad with setState
TextField(
  onChanged: (value) {
    setState(() {
      _isValid = _validateEmail(value); // ← revalidates and rebuilds on keystroke
    });
  },
)
```

### Good (Should NOT trigger)
```dart
// Validate on submit only
ElevatedButton(
  onPressed: () {
    if (_formKey.currentState?.validate() == true) { // ← validate on submit
      _formKey.currentState?.save();
      _submitForm();
    }
  },
  child: const Text('Submit'),
)

// Validate on focus lost (acceptable)
Focus(
  onFocusChange: (hasFocus) {
    if (!hasFocus) {
      _formKey.currentState?.validate(); // ← validate when field loses focus
    }
  },
  child: TextFormField(...),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `onChanged` with debounce (e.g., `Timer` delay) | **Suppress** — rate-limited | |
| `onChange` vs `onChanged` | **Same treatment** | |
| Live search/autocomplete (by design validates on change) | **Consider suppress** | Live search is a different use case |
| `onEditingComplete` or `onSubmitted` (not `onChanged`) | **Suppress** — appropriate time | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `TextFormField(onChanged: (v) { _formKey.currentState?.validate(); })` → 1 lint
2. `TextField(onChanged: (v) { Form.of(context)?.validate(); })` → 1 lint

### Non-Violations
1. `TextFormField(onChanged: (v) { setState(() { _text = v; }); })` (no validate) → no lint
2. `ElevatedButton(onPressed: () { _formKey.currentState?.validate(); })` → no lint

## Quick Fix

Offer "Move validation to `onSubmitted`":
```dart
// Before
TextFormField(
  onChanged: (v) {
    _formKey.currentState?.validate();
  },
)

// After
TextFormField(
  onSubmitted: (_) {
    _formKey.currentState?.validate();
  },
)
```

Or "Remove from onChanged" (just remove the validate call).

## Notes & Issues

1. **Debounced validation is acceptable**: Some apps debounce onChanged validation (e.g., show error 500ms after user stops typing). This is a legitimate pattern — detect `Timer` in onChanged as suppression.
2. **Live search is different**: Search fields that query an API on keystroke are a different use case from form validation. If the `validate()` call is part of search logic (e.g., checking if input is long enough to search), it may be acceptable.
3. **`autovalidateMode`**: `TextFormField` has an `autovalidateMode` parameter that controls when validation runs. If `AutovalidateMode.onUserInteraction` is set, validation runs on every interaction. Consider flagging this as well.
4. **Performance vs UX trade-off**: For simple validators (regex, isEmpty), the performance cost is negligible. For async validators or validators that trigger network calls, this is a real performance issue. Phase 1 should only flag cases where the validator is clearly expensive or the full form validation is triggered.
