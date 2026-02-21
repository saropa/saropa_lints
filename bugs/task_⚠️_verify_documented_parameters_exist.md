# Task: `verify_documented_parameters_exist`

## Summary
- **Rule Name**: `verify_documented_parameters_exist`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.63 Documentation Rules

## Problem Statement

When developers use `[paramName]` in doc comments to reference parameters, those references should correspond to actual parameter names. After refactoring (renaming a parameter), doc comments often lag behind and contain stale references to parameters that no longer exist.

Example:
```dart
/// Processes [value] and returns result.
/// Throws if [maxRetries] is exceeded.  ← but 'maxRetries' doesn't exist!
int process(String value, int attempts) { ... }
```

Stale doc references are misleading and erode trust in documentation.

## Description (from ROADMAP)

> Doc `[paramName]` references must match actual parameters.

## Trigger Conditions

1. A doc comment contains `[identifier]` references
2. The identifier is NOT one of: a parameter name, a type name, a method name, a known Dart keyword
3. The doc comment is on a method, function, or constructor declaration

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addMethodDeclaration((node) {
  final docComment = node.documentationComment;
  if (docComment == null) return;
  final docText = _getDocText(docComment);
  final refs = _extractBracketedRefs(docText);
  final paramNames = node.parameters?.parameters
      .map((p) => p.name?.lexeme)
      .whereNotNull()
      .toSet() ?? {};
  for (final ref in refs) {
    if (!paramNames.contains(ref) && !_isKnownNonParam(ref)) {
      reporter.atToken(/* token for the ref */, code);
    }
  }
});
```

`_extractBracketedRefs`: regex `\[(\w+)\]` to find all `[name]` patterns in doc text.
`_isKnownNonParam`: whitelist of common non-parameter doc references: `null`, `true`, `false`, type names visible in scope.

### Extracting `[name]` from doc comments
```dart
final refPattern = RegExp(r'\[(\w+)\]');
final refs = refPattern.allMatches(docText)
    .map((m) => m.group(1)!)
    .toSet();
```

### Reporting Accurately
The token for the specific `[paramName]` reference needs to be found within the doc comment token. This requires offset arithmetic:
- `docComment.offset + offset of '[paramName]' in the text`

## Code Examples

### Bad (Should trigger)
```dart
/// Validates the [email] address.
/// Returns true if [isValid] and [timeout] is not exceeded.  // ← trigger: 'timeout' doesn't exist
bool validateEmail(String email, {bool isValid = true}) {
  return email.contains('@') && isValid;
}
```

### Good (Should NOT trigger)
```dart
/// Validates the [email] address.
/// Returns true if [isValid] is not exceeded.  // ✓ 'isValid' is a real param
bool validateEmail(String email, {bool isValid = true}) {
  return email.contains('@') && isValid;
}

/// Processes data using the [DataProcessor] class.  // ✓ class reference, not param
/// See also [otherMethod].  // ✓ method reference, not param
void process() { ... }
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `[String]`, `[int]`, `[bool]` type references | **Suppress** — these are type references, not params | Whitelist all built-in types |
| `[null]`, `[true]`, `[false]` | **Suppress** — value literals | Whitelist |
| `[T]`, `[E]`, `[R]` type parameters | **Suppress** — generic type params | Check if it's a type param name |
| `[See also xyz]` patterns | **Complex** — some doc patterns don't use `[name]` for params | |
| `[otherMethod]` — method reference in doc | **Suppress** — method references are valid | Check if it's a method in scope |
| `[https://...]` URL reference | **Suppress** — URL is not a param | Detect URL pattern |
| Constructor doc comment with positional params | **Check positional param names too** | |
| Class-level doc comment | **Suppress or check class fields** | |
| `/// {@macro ...}` template docs | **Suppress** — macro expansion | |
| Generated files | **Suppress** | |

## Unit Tests

### Violations
1. Method with `[timeout]` in doc but no `timeout` param → 1 lint
2. Constructor with `[value]` in doc but renamed to `data` → 1 lint

### Non-Violations
1. `[String]` in doc (type reference) → no lint
2. All `[param]` references match actual parameters → no lint
3. Generated file → no lint

## Quick Fix

Offer "Remove stale reference `[paramName]`" from doc comment:
```dart
// Before:
/// Processes [data] and [timeout] values.  // 'timeout' doesn't exist

// After:
/// Processes [data] values.
```

Or "Update reference to `[newName]`" if a rename is detectable.

## Notes & Issues

1. **Type references vs. param references**: In Dart docs, `[String]`, `[int]`, `[Widget]` are valid references to types. Distinguishing "is this a type or a parameter name?" requires either a whitelist or checking if the identifier resolves to a type in scope.
2. **Method references** like `[parse]` or `[toString]` are also valid doc references and should not be flagged.
3. **Accurate error location**: Pointing to the exact `[staleParam]` token in the doc comment requires offset arithmetic within the comment token. This is doable but fiddly.
4. **Performance**: Walking doc comment text for every method is fast (string regex) but fires on every method. Using `head_limit` or similar to prioritize public API docs would be useful.
