# Bug Report: `function_always_returns_null` — False Positive on `async*` Generator Methods

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/service/app_search/providers/superhero_dc_search_provider.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "function_always_returns_null",
  "severity": 4,
  "message": "[function_always_returns_null] Function returns null on every code path, making the return type effectively void. Callers that check or use the return value are performing dead logic, and the nullable return type misleads developers into thinking the function can return meaningful data. {v6}\nChange the return type to void if the function is purely side-effecting, or add meaningful return values for different code paths to make the function useful to callers.",
  "source": "dart",
  "startLineNumber": 24,
  "startColumn": 38,
  "endLineNumber": 24,
  "endColumn": 44,
  "modelVersionId": 1,
  "origin": "extHost1"
}]
```

---

## Summary

The `function_always_returns_null` rule incorrectly flags `async*` generator methods inside classes as always returning null. The method uses `yield` to emit values and `return;` to end the stream — it never returns null. The rule has an existing `body.isGenerator` guard (line 3233 of `code_quality_rules.dart`) that should skip generator functions, but it does not catch this case when the generator is a class method (registered via `addMethodDeclaration`) rather than a top-level function (registered via `addFunctionDeclaration`).

---

## The False Positive Scenario

### Real-World Example: Search Provider `async*` Method

`lib/service/app_search/providers/superhero_dc_search_provider.dart` (line 24)

```dart
class SuperheroDCSearchProvider extends AppSearchProvider {
  @override
  Stream<List<AppSearchResultModel>> search(
    String query, {
    bool isFuzzySearch = true,
  }) async* {
    // cspell:ignore SuperheroDCDBModel StaticSuperheroDCIO
    final List<SuperheroDCDBModel>? characters =
        await StaticSuperheroDCIO.dbSuperheroDCLoadList(
      textFilter: isFuzzySearch || query.contains(' ') ? null : query,
    );

    if (characters == null || characters.isEmpty) {
      yield <AppSearchResultModel>[];   // <-- yields a value
      return;                            // <-- ends stream, NOT "return null"
    }

    final List<AppSearchResultModel> results = <AppSearchResultModel>[];
    // ... builds results list ...
    yield results;                       // <-- yields a value
  }
}
```

The `search` method is an `async*` generator that:
- **Yields** `List<AppSearchResultModel>` values via `yield`
- Uses bare `return;` to end the stream early (not to return null)
- Has return type `Stream<List<AppSearchResultModel>>` (non-nullable)

The rule flags the method name `search` at line 24, columns 38-44.

### Base Class Contract

```dart
abstract class AppSearchProvider {
  Stream<List<AppSearchResultModel>> search(
    String query, {
    bool isFuzzySearch = true,
  });
}
```

The abstract method declares `Stream<List<AppSearchResultModel>>` — a non-nullable `Stream`. The implementing `async*` generator fulfills this contract correctly.

### Generalized Pattern

Any `async*` or `sync*` generator **method inside a class** will trigger this false positive if it contains a bare `return;` statement:

```dart
class MyProvider {
  // FALSE POSITIVE: flagged as "always returns null"
  Stream<int> generateValues(bool condition) async* {
    if (!condition) return;   // <-- ends stream, not null return
    yield 42;
  }
}

class MyIterable {
  // FALSE POSITIVE: flagged as "always returns null"
  Iterable<String> items(List<String>? input) sync* {
    if (input == null) return;  // <-- ends iterable, not null return
    for (final String s in input) {
      yield s;
    }
  }
}
```

The same pattern as a **top-level function** is correctly NOT flagged (covered by existing test fixture).

---

## Root Cause Analysis

The rule in `lib/src/rules/code_quality_rules.dart` (lines 3185-3335) registers two visitors:

```dart
// Line 3210 — top-level functions
context.registry.addFunctionDeclaration((FunctionDeclaration node) {
  _checkFunctionBody(
    node.functionExpression.body,   // FunctionBody from FunctionExpression
    node.returnType,
    node.name,
    reporter,
  );
});

// Line 3219 — class methods
context.registry.addMethodDeclaration((MethodDeclaration node) {
  _checkFunctionBody(node.body, node.returnType, node.name, reporter);
});
```

The `_checkFunctionBody` method has the generator guard at line 3233:

```dart
void _checkFunctionBody(
  FunctionBody body,
  TypeAnnotation? returnType,
  Token nameToken,
  SaropaDiagnosticReporter reporter,
) {
  // Skip generators — they emit values via yield, not return.
  if (body.isGenerator) return;   // <-- Guard exists
  // ...
}
```

**The guard exists but is not catching `async*` class methods.** The most likely causes:

1. **`MethodDeclaration.body.isGenerator` returns `false` unexpectedly** — The `isGenerator` property on `BlockFunctionBody` checks `star != null`. If the `star` token is not populated for method declarations in some analyzer versions, the guard fails silently.

2. **Analyzer version edge case** — The `FunctionBody.isGenerator` base class returns `false`. If `node.body` resolves to the base `FunctionBody` type instead of `BlockFunctionBody` for methods in certain AST states, the guard returns `false`.

3. **custom_lint visitor ordering** — If `addMethodDeclaration` fires before the AST is fully resolved, `body.isGenerator` may not yet reflect the `async*` modifier.

**The test fixture only covers top-level generator functions** (lines 114-144), which use `addFunctionDeclaration`. There are **no class method generator test cases**, so this code path was never verified.

---

## Suggested Fixes

### Option A: Add Defensive Keyword Check (Recommended)

In addition to `body.isGenerator`, directly check the `star` token on `BlockFunctionBody`:

```dart
void _checkFunctionBody(
  FunctionBody body,
  TypeAnnotation? returnType,
  Token nameToken,
  SaropaDiagnosticReporter reporter,
) {
  // Skip generators — they emit values via yield, not return.
  // Belt-and-suspenders: check both isGenerator and star token
  if (body.isGenerator) return;
  if (body is BlockFunctionBody && body.star != null) return;

  // ...
}
```

This catches the case even if `isGenerator` doesn't resolve correctly for method bodies.

### Option B: Check the Return Type

Generator functions return `Stream<T>` or `Iterable<T>`. Add a return type check as an additional guard:

```dart
// Skip Stream/Iterable return types — likely generators
if (_isGeneratorReturnType(returnType)) return;

bool _isGeneratorReturnType(TypeAnnotation? returnType) {
  if (returnType is! NamedType) return false;
  final String name = returnType.name.lexeme;
  return name == 'Stream' || name == 'Iterable';
}
```

This is broader than Option A and would also protect against edge cases where the body AST isn't fully resolved.

### Option C: Both Guards Combined

Apply both Option A and Option B for maximum safety:

```dart
if (body.isGenerator) return;
if (body is BlockFunctionBody && body.star != null) return;
if (_isGeneratorReturnType(returnType)) return;
```

---

## Missing Test Coverage

The test fixture (`function_always_returns_null_fixture.dart`) only has **top-level function** generators. The following class method generator cases should be added:

```dart
// =========================================================================
// GOOD: Generator METHODS inside classes — should NOT be flagged
// =========================================================================

abstract class _SearchProviderBase {
  Stream<List<String>> search(String query);
}

// Override async* method — should NOT be flagged
class _ConcreteSearchProvider extends _SearchProviderBase {
  @override
  Stream<List<String>> search(String query) async* {
    if (query.isEmpty) {
      yield <String>[];
      return; // Ends stream, not a null return
    }
    yield <String>[query];
  }
}

// Class method async* generator — should NOT be flagged
class _DataLoader {
  Stream<int> loadBatches(int count) async* {
    if (count <= 0) return;
    for (int i = 0; i < count; i++) {
      yield i;
    }
  }
}

// Class method sync* generator — should NOT be flagged
class _ItemGenerator {
  Iterable<String> generateItems(List<String>? input) sync* {
    if (input == null) return;
    if (input.isEmpty) return;
    for (final String item in input) {
      yield item;
    }
  }
}
```

---

## Patterns That Should Be Recognized

| Pattern | Currently Flagged | Should Be Flagged |
|---|---|---|
| Top-level `async*` function with `return;` | No | **No** (working correctly) |
| Top-level `sync*` function with `return;` | No | **No** (working correctly) |
| Class method `async*` with `return;` | **Yes** | **No** (false positive) |
| Class method `sync*` with `return;` | **Untested** | **No** (likely false positive) |
| `@override` `async*` method with `return;` | **Yes** | **No** (false positive) |
| `String? foo() { return null; }` | Yes | **Yes** (genuine always-null) |
| `int? bar() => null;` | Yes | **Yes** (genuine always-null) |

---

## Current Workaround

Developers must suppress the rule per-method:

```dart
// ignore: function_always_returns_null
Stream<List<AppSearchResultModel>> search(String query, {bool isFuzzySearch = true}) async* {
```

This suppresses the rule entirely, losing coverage for genuinely always-null functions in the same file.

---

## Affected Files

| File | Lines | What |
|---|---|---|
| `lib/src/rules/code_quality_rules.dart` | 3219-3221 | `addMethodDeclaration` — calls `_checkFunctionBody` with `node.body` |
| `lib/src/rules/code_quality_rules.dart` | 3233 | `body.isGenerator` guard — not catching class method generators |
| `example_core/lib/code_quality/function_always_returns_null_fixture.dart` | 110-144 | Test fixture — only top-level generator functions, no class method generators |

---

## Reproduction Steps

1. Create a class with an `async*` method that has a bare `return;`:
   ```dart
   class Foo {
     Stream<int> bar() async* {
       yield 1;
       return;
     }
   }
   ```
2. Run analysis with saropa_lints 4.14.3
3. Observe `function_always_returns_null` warning on `bar`

---

## Priority

**High** — `async*` generator methods are common in Flutter apps (search providers, data streaming, pagination, event handling). Any class that implements a stream-based interface with `async*` will trigger this false positive on every generator method that uses early `return;`, producing noise that erodes trust in the rule.
