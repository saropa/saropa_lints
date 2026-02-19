# Task: `require_input_validation`

## Summary
- **Rule Name**: `require_input_validation`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.19 http Package Security Rules

## Problem Statement

Sending raw, unvalidated user input to APIs or databases is a security vulnerability:

1. **Injection attacks**: SQL injection, NoSQL injection, LDAP injection — raw input in query strings
2. **XSS**: Storing raw HTML/JavaScript user input that gets displayed in web contexts
3. **Server-side validation bypass**: Even if the server validates, client-side validation improves UX and reduces load
4. **OWASP M1: Improper Platform Usage** — not validating inputs properly

The classic pattern:
```dart
// BUG: raw user input in API call
final name = _nameController.text; // ← raw input
await api.createUser(name: name);  // ← sent directly, no validation
```

## Description (from ROADMAP)

> Validate user input before sending. Detect raw input in API calls.

## Trigger Conditions

1. `TextEditingController.text` (or similar user input source) passed directly to a network call, database write, or persistence method
2. No `validate()`, `trim()`, `isEmpty`, `length`, or regex check between the `.text` access and the API call

**HIGH FALSE POSITIVE RISK**: Many inputs are valid as-is (e.g., user selects from a dropdown, input is numeric only via keyboard type). This rule must be conservative.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isNetworkOrDatabaseCall(node)) return;
  final args = node.argumentList.arguments;
  for (final arg in args) {
    if (_isRawControllerText(arg)) {
      reporter.atNode(arg, code);
    }
  }
});
```

`_isRawControllerText`: check if the expression is `identifier.text` where `identifier` is a `TextEditingController`.

`_isNetworkOrDatabaseCall`: check if the method is an HTTP call (`http.post`, `dio.post`, etc.) or database write (`db.insert`, `db.update`, `firestore.set`, etc.).

### Flow Analysis Alternative
A more accurate approach: track `TextEditingController.text` assignments and check if any validation method is called on the value before it's used in a network call. This requires data flow analysis beyond what's typically available in lint rules.

## Code Examples

### Bad (Should trigger)
```dart
Future<void> onSubmit() async {
  final name = _nameController.text; // raw input
  await api.createUser(name: name);  // ← trigger: raw input in API call
}

// Direct inline use
await http.post(
  Uri.parse('/users'),
  body: {'name': _nameController.text}, // ← trigger
);
```

### Good (Should NOT trigger)
```dart
Future<void> onSubmit() async {
  final name = _nameController.text.trim();
  if (name.isEmpty) {
    _showError('Name is required');
    return;
  }
  if (name.length > 100) {
    _showError('Name is too long');
    return;
  }
  await api.createUser(name: name); // ← validation performed before call
}

// Using FormField validation
Form(
  key: _formKey,
  child: TextFormField(
    validator: (value) => value?.isEmpty == true ? 'Required' : null,
  ),
)
// ← formKey.currentState?.validate() called before submission
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `TextFormField` with `validator` | **Suppress** if form `.validate()` called before API call | Cross-file analysis needed |
| Dropdown/Select input (not freeform) | **Suppress** — user can't type arbitrary text | |
| `TextInputType.number` keyboard | **Suppress** — limited to numeric input | Runtime only, can't detect statically |
| `inputFormatters` applied | **Suppress** — formatted input is pre-validated | |
| `.trim()` applied | **Suppress** — minimal processing, treat as validated | |
| Empty check before call | **Suppress** — minimum validation present | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `_controller.text` passed to `http.post()` body without any processing → 1 lint
2. `_controller.text` assigned to variable then passed to API without validation → 1 lint

### Non-Violations
1. `_controller.text.trim()` before use → no lint
2. `_formKey.currentState?.validate()` called before API → no lint
3. Explicit `isEmpty` check before API call → no lint

## Quick Fix

No automated fix — validation requirements depend on the input type. Suggest adding a `validator` to the associated `TextFormField`.

## Notes & Issues

1. **OWASP**: Maps to **M1: Improper Platform Usage** and **M8: Code Tampering** (client-side validation bypass).
2. **VERY HIGH FALSE POSITIVE RISK**: This rule would flag enormous amounts of legitimate code. Flutter apps routinely pass `_controller.text` to functions — many of these are internal state updates, not API calls. Phase 1 must be extremely conservative.
3. **Phase 1 recommendation**: ONLY fire when `_controller.text` is directly in an HTTP call's body (not as an intermediate variable). This catches the most obvious case.
4. **The real solution**: The Dart analyzer already checks for some of these patterns. A better approach might be a `// VALIDATE` comment convention or using typed form fields that enforce validation.
5. **TextFormField vs TextField**: `TextFormField` with a `validator` and form validation is the Flutter-idiomatic validation approach. Detecting this as "validated" is the key suppression condition.
6. **Scope**: This is a general security rule that applies beyond just "http package" rules. The ROADMAP places it in §5.19 but it applies to all network clients, database writes, and persistence calls.
