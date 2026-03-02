# Task: `prefer_adjective_bool_getters`

## Summary
- **Rule Name**: `prefer_adjective_bool_getters`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Naming Conventions

## Problem Statement
Boolean getters in Dart should use names that read naturally as a predicate or adjective when accessed without parentheses. The idiomatic Dart style is to prefix boolean getters with `is`, `has`, `can`, `should`, `was`, `will`, or similar predicate words that make the access site read like plain English:

```dart
if (user.isAuthenticated) { ... }
if (form.hasErrors) { ... }
if (action.canUndo) { ... }
```

When a boolean getter uses a verb name (`bool get load`, `bool get validate`, `bool get check`), the access site becomes grammatically confusing:

```dart
if (user.validate) { ... }   // validate what? by whom?
if (widget.load) { ... }     // load it? is it loaded?
if (state.check) { ... }     // a noun or verb?
```

This also creates confusion with methods: a boolean getter named with a verb looks like it should be a method call with side effects (`validate()`) rather than a state query (`isValid`).

The Dart style guide states that boolean properties should "prefer adjectives over verbs." This rule enforces that guidance for getters explicitly declared to return `bool`.

## Description (from ROADMAP)
Flag boolean getter declarations (`bool get name`) whose names start with a verb rather than a recognized predicate prefix (`is`, `has`, `can`, `should`, `was`, `will`, `needs`, `allows`, `contains`, `includes`, `supports`, `requires`, `provides`, `matches`), and suggest renaming to a predicate form.

## Trigger Conditions
The rule triggers when:
1. A `MethodDeclaration` is a getter (`isGetter == true`).
2. The getter's declared return type is `bool` (checked via the type annotation or the inferred type element).
3. The getter name does NOT start with any recognized predicate prefix from the allowlist.
4. The getter name starts with a common verb that is not a predicate word.

It does NOT trigger for:
- Getters that start with recognized prefixes: `is`, `has`, `can`, `should`, `was`, `will`, `needs`, `allows`, `contains`, `includes`, `supports`, `requires`, `provides`, `matches`, `exists`.
- Override getters (inherited name from supertype).
- Getters in generated code.
- Getters in test files.
- Getters whose return type is NOT `bool`.

## Implementation Approach

### AST Visitor
```dart
context.registry.addMethodDeclaration((node) {
  if (!node.isGetter) return;
  if (_isOverride(node)) return;
  if (!_returnsBool(node)) return;
  _checkGetterName(node, reporter);
});
```

### Detection Logic

**Step 1 — Confirm bool return type:**

```dart
bool _returnsBool(MethodDeclaration node) {
  final returnType = node.returnType;
  if (returnType == null) return false; // inferred — skip for safety
  return returnType.type?.isDartCoreBool ?? false;
}
```

**Step 2 — Check name against predicate allowlist:**

```dart
const _predicatePrefixes = {
  'is', 'has', 'can', 'should', 'was', 'will',
  'needs', 'allows', 'contains', 'includes', 'supports',
  'requires', 'provides', 'matches', 'exists', 'enables',
  'disables', 'accepts', 'rejects', 'handles',
};

bool _hasPredicatePrefix(String name) =>
    _predicatePrefixes.any((prefix) => name.startsWith(prefix));
```

**Step 3 — Check name against verb blocklist (optional, higher precision):**

To avoid false positives on names like `empty` (which is an adjective), optionally check that the name starts with a known verb:

```dart
const _verbPrefixes = {
  'get', 'set', 'load', 'save', 'fetch', 'send', 'receive',
  'check', 'validate', 'verify', 'compute', 'calculate',
  'parse', 'format', 'convert', 'process', 'execute',
  'run', 'start', 'stop', 'create', 'build', 'make',
  'update', 'delete', 'remove', 'add', 'insert', 'clear',
  'read', 'write', 'open', 'close', 'show', 'hide',
};

bool _hasVerbPrefix(String name) =>
    _verbPrefixes.any((v) => name.startsWith(v));
```

Trigger only if the name lacks a predicate prefix AND has a verb prefix. This reduces false positives for short adjective-named getters like `bool get empty` or `bool get active`.

**Step 4 — Report:**

```dart
void _checkGetterName(MethodDeclaration node, ErrorReporter reporter) {
  final name = node.name.lexeme;
  if (_hasPredicatePrefix(name)) return;
  if (!_hasVerbPrefix(name)) return; // only flag if verb-named
  reporter.atToken(node.name, code);
}
```

## Code Examples

### Bad (triggers rule)
```dart
class AuthController {
  // Verb names on bool getters — reads oddly at call site
  bool get load => _isLoading;          // bad: widget.load is confusing
  bool get validate => _formIsValid;    // bad: should be isValid
  bool get check => _hasChecked;        // bad: should be hasBeenChecked
  bool get save => _isSaving;           // bad: should be isSaving (already predicate form)
  bool get fetch => _isFetching;        // bad: should be isFetching
  bool get verify => _emailVerified;    // bad: should be isEmailVerified
}
```

### Good (compliant)
```dart
class AuthController {
  // Predicate names — read naturally as questions
  bool get isLoading => _isLoading;
  bool get isValid => _formIsValid;
  bool get hasChecked => _hasChecked;
  bool get isSaving => _isSaving;
  bool get isFetching => _isFetching;
  bool get isEmailVerified => _emailVerified;

  // These are also fine — adjectives not verbs
  bool get empty => _items.isEmpty;
  bool get active => _state == State.active;
  bool get visible => _visibility;
}
```

## Edge Cases & False Positives
- **Single-word adjective getters**: `bool get empty`, `bool get active`, `bool get visible`, `bool get ready`, `bool get enabled` — these do NOT start with a predicate prefix but are perfectly valid adjective-named getters. The verb blocklist (Step 3) prevents these from triggering, since `empty`, `active`, `visible` etc. are not in the verb prefix set.
- **Override getters**: When implementing an interface that defines `bool get validate()`, the implementation must use the same name. Detect via `@override` annotation or by checking the element's overriding status. Skip silently.
- **Framework getters**: Flutter's own framework includes `bool get mounted`, `bool get debugNeedsPaint`, etc. These are not in the format this rule cares about, but ensure the framework's own internal overrides are not flagged.
- **Abstract getters in interfaces**: An abstract class defining `bool get check()` as part of an interface contract should arguably also be flagged — the convention applies to declarations, not just implementations. Whether to flag abstract getters too is a design decision.
- **Getter with no type annotation**: If the developer omits the return type (`get isLoading => _isLoading;`), the return type must be inferred. Using `node.returnType == null` and then falling back to the declared element's type. For safety, skip getters with no explicit type annotation to avoid false positives.
- **Extension getters**: Extension getters on external types (`extension on String { bool get load => ...; }`) should be treated the same as regular getters.
- **Generated code**: Suppress for files with `.g.dart`, `.freezed.dart`, `.gr.dart` suffixes.

## Unit Tests

### Should Trigger (violations)
```dart
class FormState {
  bool get validate => _isValid;        // LINT — verb-named bool getter
  bool get check => _hasBeenChecked;    // LINT
  bool get load => _loaded;             // LINT
  bool get verify => _verified;         // LINT
  bool get fetch => _fetched;           // LINT
}
```

### Should NOT Trigger (compliant)
```dart
class FormState {
  // Correct predicate-prefix getters
  bool get isValid => _isValid;         // OK
  bool get hasBeenChecked => _checked;  // OK
  bool get isLoaded => _loaded;         // OK
  bool get isVerified => _verified;     // OK

  // Adjective-named getters without predicate prefix — also OK
  bool get empty => _items.isEmpty;     // OK — adjective, not verb
  bool get active => _active;           // OK — adjective
  bool get visible => _visible;         // OK — adjective
  bool get ready => _ready;             // OK — adjective

  // Non-bool getter — not checked by this rule
  String get name => _name;             // OK — not bool

  // Override — excluded
  @override
  bool get validate => super.validate;  // OK — override
}
```

## Quick Fix
Suggest renaming by prepending `is` as the default transform:

```dart
// If getter name is 'validate', suggest 'isValidated' or 'isValid'
// If getter name is 'load', suggest 'isLoaded' or 'isLoading'
// If getter name is 'check', suggest 'hasChecked' or 'isChecked'
```

The quick fix should prepend `is` to the name and apply camelCase:
- `load` → `isLoad` (minimal) or prompt for better name.

Because the best rename is context-dependent, provide the fix as a suggestion with a placeholder, not as an automatic rename:

```
correctionMessage: 'Rename this getter to start with "is", "has", "can", or "should" to read naturally as a predicate. For example, rename "validate" to "isValid" or "hasValidated".',
```

A quick fix could offer a single mechanical transform (`isLoad`, `isValidate`) as a starting point that the developer refines. Priority: 70.

## Notes & Issues
- This rule is closely related to the Effective Dart guideline "PREFER using lowerCamelCase for constant names" and "DO name boolean properties/variables with adjectives."
- The verb blocklist may need ongoing maintenance as new verb patterns are encountered.
- Consider allowing configuration of additional predicate prefixes via `analysis_options.yaml` for domain-specific terminology (e.g., some domains use `did` as a prefix for past-state booleans: `didComplete`, `didTimeout`).
- Severity is INFO because this is a style guideline, not a correctness issue. Teams can choose to ignore it without affecting correctness.
- The rule does not check local `bool` variable names — that would be a separate rule and would have a very high false positive rate.
