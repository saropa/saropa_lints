# Task: `prefer_lowercase_constants`

## Summary
- **Rule Name**: `prefer_lowercase_constants`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Naming Conventions

## Problem Statement
Dart's style guide explicitly specifies `lowerCamelCase` for all constants, including those declared with `const` and `static final`. Using `SCREAMING_SNAKE_CASE` (e.g., `MAX_RETRIES`, `API_BASE_URL`) is a Java and C++ convention that does not belong in idiomatic Dart code. Developers migrating from those languages often carry this habit, making Dart codebases inconsistent and harder to read for the wider Dart/Flutter community.

The Dart linter already provides `constant_identifier_names` in the core lints, but that rule is opt-in and not always activated. This rule provides a project-specific enforcement mechanism with clearer messaging tailored to the saropa_lints tier system, and can be selectively tuned for edge cases such as generated code and Android interop constants.

## Description (from ROADMAP)
Flag constant declarations (`const` or `static final`) whose names use `SCREAMING_SNAKE_CASE` (all uppercase letters with underscores), and suggest renaming to `lowerCamelCase` per the official Dart style guide.

## Trigger Conditions
The rule triggers when:
1. A `const` variable declaration at top-level, class level, or local scope has a name matching the pattern `^[A-Z][A-Z0-9_]+$` (i.e., starts with an uppercase letter, and consists exclusively of uppercase letters, digits, and underscores).
2. A `static final` field declaration at class level has the same naming pattern.

It does NOT trigger for:
- `final` instance fields (non-static) — already handled by other conventions.
- Enum member names — enums have their own convention debate and are excluded.
- Names that are mixed-case (e.g., `MyConst`) — those are a different naming issue.

## Implementation Approach

### AST Visitor
```dart
context.registry.addVariableDeclaration((node) {
  // Check const or static final parent
});

context.registry.addFieldDeclaration((node) {
  // Check static final
});
```

Use `addVariableDeclaration` for local and top-level `const` declarations. Use `addFieldDeclaration` for class-level `static final` and `static const` fields.

### Detection Logic
1. Obtain the variable name string from `node.name.lexeme`.
2. Apply regex: `RegExp(r'^[A-Z][A-Z0-9_]+$')`.
3. For `addVariableDeclaration`: confirm the variable is declared with `const` keyword. Check `node.parent` to find `VariableDeclarationList` and inspect its `keyword`.
4. For `addFieldDeclaration`: confirm both `isStatic` is true and the variable list keyword is `final` or `const`.
5. If the regex matches and conditions are met, report at the variable name token.

```dart
final _screamingCaseRegex = RegExp(r'^[A-Z][A-Z0-9_]+$');

bool _isScreamingCase(String name) =>
    _screamingCaseRegex.hasMatch(name) && name.contains('_');
```

Note: require at least one underscore to avoid flagging single-word uppercase names that might be legitimate in certain contexts (though even those are non-idiomatic). Consider making the underscore requirement configurable.

## Code Examples

### Bad (triggers rule)
```dart
// Top-level const — SCREAMING_SNAKE_CASE
const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 5000;
const EMPTY_STRING = '';

class ApiConfig {
  // Static const field
  static const API_BASE_URL = 'https://api.example.com';
  static const AUTH_HEADER_KEY = 'Authorization';

  // Static final field
  static final INSTANCE = ApiConfig._();
}
```

### Good (compliant)
```dart
// Top-level const — lowerCamelCase
const maxRetries = 3;
const defaultTimeoutMs = 5000;
const emptyString = '';

class ApiConfig {
  // Static const field
  static const apiBaseUrl = 'https://api.example.com';
  static const authHeaderKey = 'Authorization';

  // Static final field
  static final instance = ApiConfig._();
}
```

## Edge Cases & False Positives
- **Generated code**: Files ending in `.g.dart` or `.freezed.dart` may contain SCREAMING_SNAKE_CASE constants from code generators. Consider suppressing the rule for generated files by checking the file path or a `// GENERATED CODE` header comment.
- **Enum values**: Dart enum members like `enum Status { ACTIVE, INACTIVE }` are technically uppercase identifiers. Exclude `EnumConstantDeclaration` nodes from this rule — enums have a separate convention debate.
- **Android interop**: Constants mirroring Android SDK constants (e.g., `static const ACTION_VIEW = 'android.intent.action.VIEW'`) are intentionally kept as-is for readability alongside Android documentation. These should be suppressable with `// ignore: prefer_lowercase_constants`.
- **External API mirroring**: When wrapping an external C library or platform API that uses uppercase constants, the Dart wrapper may legitimately mirror those names. Document that `// ignore:` is the escape hatch.
- **Single uppercase letter**: Names like `T`, `E`, `K`, `V` are type parameter names — not constants. The regex `^[A-Z][A-Z0-9_]+$` with the underscore requirement already excludes single characters, but verify the regex handles single-char names.
- **ALL_CAPS with no underscore**: A name like `TIMEOUT` matches the regex if the underscore requirement is dropped. Decide on the policy: require underscore for triggering, or flag any all-caps name.

## Unit Tests

### Should Trigger (violations)
```dart
// Top-level const with SCREAMING_SNAKE_CASE
const MAX_VALUE = 100; // LINT

// Static const in class
class Config {
  static const API_URL = 'https://example.com'; // LINT
  static const MAX_POOL_SIZE = 10; // LINT
}

// Static final with SCREAMING_SNAKE_CASE
class Singleton {
  static final INSTANCE = Singleton._(); // LINT
}
```

### Should NOT Trigger (compliant)
```dart
// Correct lowerCamelCase constants
const maxValue = 100;

class Config {
  static const apiUrl = 'https://example.com';
  static const maxPoolSize = 10;
}

// Non-static final — not a constant in the same sense
class Widget {
  final String label; // Not flagged
  Widget(this.label);
}

// Enum members — excluded from this rule
enum Status { ACTIVE, INACTIVE }

// Single uppercase character — excluded
const T = 42; // Not flagged (no underscore)
```

## Quick Fix
Suggest renaming the constant to `lowerCamelCase`. The fix should:
1. Convert the SCREAMING_SNAKE_CASE name to lowerCamelCase by splitting on `_`, lowercasing all segments, then capitalising all but the first.
2. Use `DartFileEditBuilder` to rename all references in the same file.
3. Note that cross-file renaming is outside the scope of a quick fix — warn that other files may need manual updating.

Example conversion: `MAX_RETRY_COUNT` → `maxRetryCount`.

```dart
String _toLower CamelCase(String screaming) {
  final parts = screaming.toLowerCase().split('_');
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
```

## Notes & Issues
- The official Dart linter rule `constant_identifier_names` covers this but is not always enabled. This rule is a deliberate duplicate for projects that use saropa_lints without the core lints package. Mention in the rule documentation that enabling `constant_identifier_names` from `lints` or `flutter_lints` achieves the same effect.
- Severity set to INFO because renaming public constants is a breaking change in a library. Teams publishing packages need to treat this more carefully than internal apps.
- Consider adding a `publicOnly` configuration option to limit the rule to publicly visible constants (no `_` prefix).
