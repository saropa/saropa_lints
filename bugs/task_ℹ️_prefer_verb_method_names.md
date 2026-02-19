# Task: `prefer_verb_method_names`

## Summary
- **Rule Name**: `prefer_verb_method_names`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Naming Conventions

## Problem Statement
Method names in Dart should communicate that they perform an action. When a method is named after a noun (`error()`, `data()`, `status()`) rather than a verb (`reportError()`, `fetchData()`, `getStatus()`), it blurs the distinction between methods and property getters. Callers cannot tell from the name whether calling the method triggers side effects, performs computation, or simply returns a stored value. This ambiguity makes code harder to reason about and maintain.

The Dart style guide states: "Name methods and functions using lowercase camelCase ... Methods that are imperative should be named with a verb." While not enforced by the standard linter, this convention is important enough for a Professional-tier rule.

This rule is acknowledged to be difficult without NLP or an exhaustive word list. The implementation strategy focuses on a high-confidence, low-false-positive subset: methods whose names exactly match a field name on the same class, or methods whose names are drawn from a curated list of common non-verb method names seen in real codebases.

## Description (from ROADMAP)
Flag method declarations (not getters, not constructors) whose names begin with a noun or adjective commonly mistaken for a verb, suggesting the developer add a clarifying verb prefix such as `get`, `fetch`, `compute`, `build`, `report`, or `handle`.

## Trigger Conditions
The rule triggers when:
1. A `MethodDeclaration` is found that is NOT a getter (`isGetter == false`) and NOT an operator.
2. The method name matches one of the curated high-confidence noun/non-verb patterns.
3. (Optional, higher confidence) The method name exactly matches an instance field name declared on the same class.

It does NOT trigger for:
- Getters (they are expected to be noun-like: `get status`).
- Constructors and factory constructors.
- Overriding methods (the name is inherited from the supertype).
- Methods on test classes (`_test.dart` files).
- Methods whose name starts with a recognised verb prefix: `get`, `set`, `fetch`, `load`, `save`, `compute`, `calculate`, `build`, `create`, `make`, `handle`, `on`, `process`, `parse`, `format`, `convert`, `validate`, `check`, `find`, `search`, `update`, `delete`, `remove`, `add`, `insert`, `append`, `clear`, `reset`, `init`, `start`, `stop`, `run`, `execute`, `dispatch`, `emit`, `send`, `receive`, `read`, `write`, `open`, `close`, `show`, `hide`, `toggle`, `apply`, `render`, `notify`, `publish`, `subscribe`.

## Implementation Approach

### AST Visitor
```dart
context.registry.addMethodDeclaration((node) {
  if (node.isGetter || node.isSetter || node.isOperator) return;
  if (node.isOverride) return; // skip @override
  _checkMethodName(node, reporter);
});
```

### Detection Logic

**Strategy 1 — Curated noun/state-word blocklist (high confidence, low false positives):**

Maintain a `Set<String>` of common method names that are clearly nouns or state adjectives rather than verbs:

```dart
const _suspectNames = {
  'error', 'errors', 'data', 'result', 'results',
  'status', 'state', 'value', 'values',
  'response', 'request', 'output', 'input',
  'content', 'info', 'detail', 'details',
  'item', 'items', 'entry', 'entries',
  'key', 'keys', 'name', 'names',
  'type', 'types', 'kind', 'category',
  'size', 'count', 'length', 'total',
  'message', 'messages', 'text', 'label',
  'title', 'description', 'summary',
};
```

If the method name is in this set, report it.

**Strategy 2 — Field name collision (medium confidence):**

Collect all field names on the enclosing class, then flag methods whose name matches a field name:

```dart
final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
final fieldNames = _collectFieldNames(classDecl);
if (fieldNames.contains(node.name.lexeme)) {
  reporter.atToken(node.name, code);
}
```

**Strategy 3 — Suffix heuristics:**

Flag methods whose name ends in a noun suffix with no leading verb:
- Ends with `Data`, `Info`, `Result`, `Status`, `State`, `Error`, `Response` (without a verb prefix from the allowlist above).

```dart
const _nounSuffixes = ['Data', 'Info', 'Result', 'Status', 'State', 'Error', 'Response'];
final name = node.name.lexeme;
final hasVerbPrefix = _verbPrefixes.any((v) => name.startsWith(v));
final hasNounSuffix = _nounSuffixes.any((s) => name.endsWith(s));
if (!hasVerbPrefix && hasNounSuffix) {
  reporter.atToken(node.name, code);
}
```

Combine strategies, deduplicate, and report once per node.

## Code Examples

### Bad (triggers rule)
```dart
class ApiService {
  String? _lastError;

  // Method named exactly like a noun — what does this DO?
  void error(String msg) {
    _lastError = msg;
  }

  // Returns data — but is it computed? fetched? cached?
  Map<String, dynamic> data() => _cache;

  // Status of what? Reads like a getter, but it's a method
  bool status() => _isConnected;

  // Noun suffix with no verb
  UserResult userResult(int id) => _lookup(id);
}
```

### Good (compliant)
```dart
class ApiService {
  String? _lastError;

  // Clear verb: this reports/records an error
  void reportError(String msg) {
    _lastError = msg;
  }

  // Clear verb: this fetches data
  Map<String, dynamic> fetchData() => _cache;

  // Use a getter for simple boolean state
  bool get isConnected => _isConnected;

  // Verb + noun: unambiguous
  UserResult findUserResult(int id) => _lookup(id);
}
```

## Edge Cases & False Positives
- **Override methods**: If the base class or interface defines `String error()`, all subclasses must implement `error()`. The rule must detect `@override` and suppress in that case. Check `node.declaredElement?.hasOverride ?? false` or scan the annotation list.
- **Test helper methods**: Methods named `data()` or `result()` in test files are common and acceptable as helpers returning test data. Suppress for files matching `**/*_test.dart` or `**/test/**`.
- **Tearoff usage**: Methods named `on` as in `void on(Event e)` look verb-like but `on` is actually a preposition. The verb allowlist should be applied carefully.
- **Factory and builder methods**: Methods like `empty()`, `none()`, `all()` on value types (`Optional.none()`) are idiomatic Dart. These need careful exclusion — perhaps by allowing one-word names that are not in the `_suspectNames` set.
- **DSL-style APIs**: Testing DSLs, builder patterns, and parser combinators deliberately use noun-style method chaining (`token()`, `whitespace()`, `sequence()`). Consider suppressing for classes that implement specific patterns.
- **Flutter framework**: Flutter's own API includes `build()`, which starts with a verb. Some framework methods like `createState()` are already fine. Verify the verb allowlist covers common Flutter lifecycle names: `initState`, `dispose`, `build`, `didChangeDependencies`, `didUpdateWidget`.
- **NLP limitations**: Without a full English verb dictionary, the blocklist approach will always have gaps. Accept this and document that the rule catches common cases only.

## Unit Tests

### Should Trigger (violations)
```dart
class DataStore {
  void error(String msg) { } // LINT — noun, not a verb
  Map<String, dynamic> data() => {}; // LINT — noun
  int count() => 0; // LINT — noun (count as a method should be getCount or countItems)
  UserResult userResult(int id) => UserResult(); // LINT — noun suffix, no verb
}
```

### Should NOT Trigger (compliant)
```dart
class DataStore {
  void reportError(String msg) { } // OK — starts with verb
  Map<String, dynamic> fetchData() => {}; // OK — starts with verb
  int getCount() => 0; // OK — starts with verb
  UserResult findUserResult(int id) => UserResult(); // OK — starts with verb

  // Getters are excluded from this rule
  bool get hasError => _error != null;
  int get count => _count;

  // @override excluded
  @override
  String toString() => 'DataStore';
}

// Test file methods excluded
void main() {
  test('data returns expected', () {
    // test helper method named data() in test context — not flagged
  });
}
```

## Quick Fix
This rule does not provide an automated quick fix because renaming a method is a semantic decision requiring developer judgement. Instead, provide a suggestion in the `correctionMessage`:

```
correctionMessage: 'Prefix the method name with a verb such as "get", "fetch", "compute", "build", "find", or "handle" to clarify what the method does. For example, rename "data()" to "fetchData()" or "getData()".',
```

## Notes & Issues
- The curated blocklist approach is inherently incomplete. Maintainers should expect to add entries over time as common non-verb method names are identified in real codebases.
- Consider a configuration option allowing teams to extend the `_suspectNames` set via `analysis_options.yaml` under the saropa_lints options block.
- This rule overlaps philosophically with `prefer_adjective_bool_getters` (file 4), which targets the specific case of boolean getters. Ensure the two rules do not fire on the same node — this rule should be limited to non-getter methods only.
- False positive rate is expected to be moderate. Set severity to INFO so the rule is advisory rather than disruptive.
- The strategy of checking field name collisions (Strategy 2) is the highest-confidence detection path and should be prioritised in the implementation.
