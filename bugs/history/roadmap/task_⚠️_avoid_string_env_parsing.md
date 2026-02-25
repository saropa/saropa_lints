> **========================================================**
> **IMPLEMENTED -- v5.1.0**
> **========================================================**
>
> `AvoidStringEnvParsingRule` in
> `lib/src/rules/config_rules.dart`. Recommended tier.
>
> **========================================================**

# Task: `avoid_string_env_parsing`

## Summary
- **Rule Name**: `avoid_string_env_parsing`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.41 Configuration & Environment Rules

## Problem Statement

`String.fromEnvironment()`, `bool.fromEnvironment()`, and `int.fromEnvironment()` read compile-time constants set via `--dart-define`. They have important limitations:

1. **Type coercion is not validated**: `bool.fromEnvironment('ENABLE_DEBUG')` returns `false` if the value is anything other than the string `"true"`. Typos like `"True"`, `"1"`, `"yes"` silently fail.

2. **Missing values return defaults silently**: If `String.fromEnvironment('API_URL')` is called without `--dart-define=API_URL=...`, it returns an empty string. There's no error.

3. **Raw string usage**: Passing the raw string to URL parsers, JSON decoders, etc. without validation can cause runtime errors.

```dart
// BUG: No validation of environment values
static const _apiUrl = String.fromEnvironment('API_URL'); // ← may be empty string!

Future<void> init() async {
  // This will throw if API_URL wasn't defined at compile time
  final uri = Uri.parse(_apiUrl); // ← no check if _apiUrl is empty
  await http.get(uri);
}
```

4. **Boolean parsing pitfall**:
```dart
// BUG: 'ENABLE_LOGS=1' returns false, not true!
static const enableLogs = bool.fromEnvironment('ENABLE_LOGS'); // ← '1' → false
```

## Description (from ROADMAP)

> Parse environment strings properly. Detect raw String.fromEnvironment usage.

## Trigger Conditions

1. `String.fromEnvironment('KEY')` where the result is used without:
   - An `isEmpty` check
   - An `isNotEmpty` guard
   - A `defaultValue` parameter that makes the behavior intentional
2. `bool.fromEnvironment('KEY')` without documentation that `"true"` (lowercase) is the required format

**Phase 1 (Conservative)**: Flag `String.fromEnvironment()` without a `defaultValue` argument when the result is directly used in a URL parse or JSON decode context.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isFromEnvironment(node)) return; // String.fromEnvironment, etc.
  if (_hasDefaultValue(node)) return; // has defaultValue: parameter
  // Check if result is used unsafely
  if (_isUsedWithoutValidation(node)) {
    reporter.atNode(node, code);
  }
});
```

`_isFromEnvironment`: check if the invocation is `String.fromEnvironment`, `bool.fromEnvironment`, or `int.fromEnvironment`.
`_hasDefaultValue`: check if the `defaultValue:` named argument is present.
`_isUsedWithoutValidation`: check if result is passed to `Uri.parse`, `jsonDecode`, or stored in a const without isEmpty check.

## Code Examples

### Bad (Should trigger)
```dart
// No default value + no validation
static const apiUrl = String.fromEnvironment('API_URL'); // ← trigger: may be empty

void init() {
  final uri = Uri.parse(apiUrl); // ← runtime error if apiUrl is empty
}

// Boolean pitfall
static const debug = bool.fromEnvironment('DEBUG'); // ← trigger: "1", "yes" silently fail
```

### Good (Should NOT trigger)
```dart
// With explicit validation
static const _rawApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://api.example.com', // ← has fallback
);

// Or with assertion
static const apiUrl = String.fromEnvironment('API_URL');
// In main():
assert(apiUrl.isNotEmpty, 'API_URL must be set via --dart-define=API_URL=...');

// Boolean: document the requirement
/// Set via --dart-define=ENABLE_DEBUG=true (lowercase 'true' only)
static const enableDebug = bool.fromEnvironment('ENABLE_DEBUG');
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `defaultValue: 'fallback'` provided | **Suppress** — has fallback | |
| Result checked with `isEmpty` before use | **Suppress** — validated | |
| `const` used in compile-time expression only | **Suppress** — value known at compile time | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `String.fromEnvironment('KEY')` used in `Uri.parse()` directly → 1 lint
2. `bool.fromEnvironment('KEY')` without defaultValue (for awareness) → 1 lint

### Non-Violations
1. `String.fromEnvironment('KEY', defaultValue: 'fallback')` → no lint
2. `final url = String.fromEnvironment('URL'); if (url.isEmpty) throw...` → no lint

## Quick Fix

Offer "Add `defaultValue` parameter":
```dart
// Before
static const apiUrl = String.fromEnvironment('API_URL');

// After
static const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://api.example.com',
);
```

## Notes & Issues

1. **Dart-specific**: `String.fromEnvironment` is a Dart feature, not Flutter-specific. Applicable to all Dart projects.
2. **The bool.fromEnvironment pitfall**: Only the string literal `"true"` returns `true`. This is counterintuitive for developers coming from other platforms. A comment about this would be valuable.
3. **`--dart-define-from-file`**: Newer Flutter versions support `--dart-define-from-file=config.json`. Same parsing issues apply.
4. **`envied` package**: `package:envied` wraps `String.fromEnvironment` with validation and obfuscation. If detected, suppress — the developer is handling environment parsing correctly.
5. **`flutter_dotenv`**: Another common approach to configuration. If used, `String.fromEnvironment` patterns may be less common.
6. **Security consideration**: Environment variables set via `--dart-define` are visible in compiled Dart code (not truly secret). They are not suitable for storing actual secrets — use server-side configuration or `flutter_secure_storage`.
