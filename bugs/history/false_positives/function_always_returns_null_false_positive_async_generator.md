# Bug: `function_always_returns_null` false positive on `async*` / `sync*` generators

## Summary

The `function_always_returns_null` rule incorrectly flags `async*` and `sync*`
generator functions. Generators emit values via `yield`, not `return`. A bare
`return;` in a generator simply ends the stream/iterable — it does not "return
null". The rule's `_ReturnCollector` finds these bare `return;` statements,
treats them as null-returning, and fires on the method name.

## Severity

**False positive** — `async*` generators are a core Dart language feature used
for lazy sequences and reactive streams. Any codebase with `Stream<T>`-returning
generators will see false warnings, training developers to suppress or ignore
the rule entirely.

## Reproduction

### Minimal example

```dart
// async* generator — emits values via yield, not return
Stream<List<String>> search(String query) async* {
  final List<String>? items = await loadItems(query);

  if (items == null || items.isEmpty) {
    yield <String>[];
    return; // ← ends the stream, does NOT "return null"
  }

  yield items;
}
```

### Lint output

```
line:col • [function_always_returns_null] Function returns null on every code
path, making the return type effectively void. Callers that check or use the
return value are performing dead logic, and the nullable return type misleads
developers into thinking the function can return meaningful data. {v6}
• function_always_returns_null • WARNING
```

### `sync*` generator (also affected)

```dart
Iterable<int> fibonacci(int count) sync* {
  if (count <= 0) return; // ← FALSELY FLAGGED

  int a = 0, b = 1;
  for (int i = 0; i < count; i++) {
    yield a;
    final int next = a + b;
    a = b;
    b = next;
  }
}
```

### Additional triggering patterns

All of the following standard generator patterns are falsely flagged:

```dart
// Async generator with early exit guard
Stream<Data> watchData(String id) async* {
  final Data? initial = await fetch(id);
  if (initial == null) return;           // FLAGGED
  yield initial;
  yield* streamUpdates(id);
}

// Sync generator with guard
Iterable<int> range(int start, int end) sync* {
  if (start >= end) return;              // FLAGGED
  for (int i = start; i < end; i++) {
    yield i;
  }
}

// Async generator with no return statement at all but yield only
// (NOT flagged — returns list is empty so rule exits early)
Stream<int> countUp(int n) async* {
  for (int i = 0; i < n; i++) {
    yield i;
  }
}
```

## Real-world occurrence

Found in `saropa/lib/service/app_search/providers/mental_model_search_provider.dart`:

```dart
class MentalModelSearchProvider extends AppSearchProvider {
  @override
  Stream<List<AppSearchResultModel>> search(
    String query, {
    bool isFuzzySearch = true,
  }) async* {
    final List<MentalModelDBModel>? allModels =
        await DatabaseMentalModelIO.dbMentalModelLoadList(
      textFilter: isFuzzySearch || query.contains(' ') ? null : query,
    );

    if (allModels == null || allModels.isEmpty) {
      yield <AppSearchResultModel>[];
      return; // ← bare return ends the stream — FALSELY FLAGGED
    }

    // ... score and filter models ...

    yield results;
  }
}
```

Diagnostic produced:

```
lib\service\app_search\providers\mental_model_search_provider.dart:22:38
• [function_always_returns_null] Function returns null on every code path...
• function_always_returns_null • WARNING
```

The method is an `@override` of `AppSearchProvider.search()` which returns
`Stream<List<AppSearchResultModel>>`. It yields meaningful lists of search
results. The bare `return;` on the early-exit path ends the stream, which is
standard generator control flow.

Multiple sibling providers follow the identical pattern:

- `medical_conditions_search_provider.dart`
- `emergency_tips_search_provider.dart`
- `born_on_this_day_search_provider.dart`

All will be affected.

## Root cause

**File:** `lib/src/rules/code_quality_rules.dart`, lines 3201–3239
(`_checkFunctionBody`)

### The buggy code path

```dart
void _checkFunctionBody(
  FunctionBody body,
  TypeAnnotation? returnType,
  Token nameToken,
  SaropaDiagnosticReporter reporter,
) {
  // Skip void functions - bare return statements are valid
  if (_isVoidType(returnType)) return;

  // ... expression body check ...

  if (body is BlockFunctionBody) {
    final List<ReturnStatement> returns = <ReturnStatement>[];
    body.block.visitChildren(_ReturnCollector(returns));

    if (returns.isEmpty) return;

    final bool allBareReturns = returns.every(
      (ReturnStatement ret) => ret.expression == null,
    );
    final bool allNull = returns.every((ReturnStatement ret) {
      final Expression? expr = ret.expression;
      return expr == null || expr is NullLiteral;
    });

    // If no explicit return type and all returns are bare `return;`,
    // this is likely a void function with inferred type - don't flag
    if (returnType == null && allBareReturns) return;

    if (allNull && returns.isNotEmpty) {
      reporter.atToken(nameToken, code);  // ← FALSE POSITIVE HERE
    }
  }
}
```

### Why it fails

The method never checks whether `body` is a **generator** (`body.isGenerator`).
In an `async*` or `sync*` function:

1. The return type is `Stream<T>` or `Iterable<T>`, not `void` — so
   `_isVoidType()` returns false.
2. Values are emitted via `yield` / `yield*` — the `_ReturnCollector` ignores
   these entirely (it only visits `ReturnStatement` nodes).
3. Any bare `return;` in the generator ends the sequence — it does **not**
   return null. A generator's `return;` is semantically equivalent to "stop
   yielding".
4. `_ReturnCollector` finds the bare `return;`, records it. `allBareReturns`
   is true, `allNull` is true.
5. `returnType` is `Stream<List<...>>` (not null), so the
   `returnType == null && allBareReturns` escape hatch on line 3234 doesn't
   apply.
6. `allNull && returns.isNotEmpty` evaluates to true → the rule fires.

### Relevant AST structure

For `Stream<int> count() async* { yield 1; return; }`:

```
MethodDeclaration
  returnType: NamedType "Stream<int>"
  name: "count"
  body: BlockFunctionBody
    keyword: "async"
    star: "*"              ← body.isGenerator == true
    block: Block
      YieldStatement: yield 1;    ← NOT a ReturnStatement, invisible to rule
      ReturnStatement: return;    ← collected, treated as "returns null"
```

The `body.star` token (or `body.isGenerator` property) distinguishes generators
from regular functions. The rule does not check either.

## Suggested fix

Add a generator check at the top of `_checkFunctionBody`, before any return
analysis:

```dart
void _checkFunctionBody(
  FunctionBody body,
  TypeAnnotation? returnType,
  Token nameToken,
  SaropaDiagnosticReporter reporter,
) {
  // Skip generators — they emit values via yield, not return.
  // A bare `return;` in async*/sync* ends the stream/iterable, not a null return.
  if (body.isGenerator) return;

  // Skip void functions - bare return statements are valid
  if (_isVoidType(returnType)) return;

  // ... rest unchanged ...
}
```

`FunctionBody.isGenerator` is `true` when the body has a `*` token (`async*` or
`sync*`). This is the same pattern used by other saropa_lints rules — for
example, `avoid_redundant_async` in `async_rules.dart` (line ~395) uses
`body.isAsynchronous && !body.isGenerator` to explicitly skip generators.

### Why this is the correct fix

| Function kind | `isGenerator` | `isAsynchronous` | Return type | Returns via |
|---------------|---------------|------------------|-------------|-------------|
| Regular       | false         | false            | `T`         | `return`    |
| `async`       | false         | true             | `Future<T>` | `return`    |
| `sync*`       | true          | false            | `Iterable<T>` | `yield`  |
| `async*`      | true          | true             | `Stream<T>` | `yield`     |

For generators (`isGenerator == true`), `return` statements have fundamentally
different semantics — they terminate the sequence, they don't produce a value.
The concept of "always returns null" is meaningless for generators.

### Alternative: check for Stream / Iterable return types

A more targeted but fragile alternative would be to extend `_isVoidType` to also
skip `Stream<T>` and `Iterable<T>` return types. This is **not recommended**
because:

1. It conflates return type skipping with generator semantics.
2. A non-generator function returning `Stream<T>` that always returns null IS a
   valid lint target (e.g., `Stream<int>? getStream() => null;`).
3. `body.isGenerator` is the direct semantic check — it's what makes `return;`
   mean "stop yielding" rather than "return null".

## Test cases to add

Add to `example_core/lib/code_quality/function_always_returns_null_fixture.dart`:

```dart
// =========================================================================
// GOOD: Generator functions — yield values, return; ends the sequence
// =========================================================================

// Async generator with early exit — should NOT be flagged
Stream<List<String>> asyncGeneratorWithEarlyExit(String query) async* {
  final List<String>? items = await _loadItems(query);
  if (items == null || items.isEmpty) {
    yield <String>[];
    return; // Ends stream, not a null return
  }
  yield items;
}

// Sync generator with early exit — should NOT be flagged
Iterable<int> syncGeneratorWithEarlyExit(int count) sync* {
  if (count <= 0) return; // Ends iterable, not a null return
  for (int i = 0; i < count; i++) {
    yield i;
  }
}

// Async generator with no return statement — should NOT be flagged
Stream<int> asyncGeneratorNoReturn() async* {
  yield 1;
  yield 2;
}

// Sync generator with multiple early exits — should NOT be flagged
Iterable<String> syncGeneratorMultipleExits(List<String>? input) sync* {
  if (input == null) return;
  if (input.isEmpty) return;
  for (final String item in input) {
    yield item;
  }
}

// Mock helper
Future<List<String>?> _loadItems(String query) async => <String>['a'];
```

**Verify these existing BAD cases still fire** (no change expected):

```dart
// Non-generator returning Stream? that is always null — SHOULD still flag
// expect_lint: function_always_returns_null
Stream<int>? getNullStream() => null;

// Non-generator returning Iterable? that is always null — SHOULD still flag
// expect_lint: function_always_returns_null
Iterable<int>? getNullIterable() {
  return null;
}
```

## Impact

Any Dart codebase using `async*` or `sync*` generators with early-exit `return;`
statements will see false positives. This is a standard pattern for:

- **Search providers** — stream results as they're computed, exit early on empty
  input
- **Database watchers** — `async*` generators wrapping Isar/Firestore streams
- **Pagination** — `async*` generators yielding pages with early exit on end
- **Iterators** — `sync*` generators for lazy sequences with guard clauses
- **State machines** — `async*` generators emitting state transitions

The only generators that escape are those with no `return;` statements at all
(the `returns.isEmpty` check on line 3221 exits early). Any generator using the
idiomatic early-exit pattern `if (bad) return;` will be falsely flagged.

## Environment

- **saropa_lints**: path dependency from `D:\src\saropa_lints`
- **Rule file**: `lib/src/rules/code_quality_rules.dart` lines 3162–3307
- **Test fixture**: `example_core/lib/code_quality/function_always_returns_null_fixture.dart`
- **Test project**: `D:\src\contacts`
- **Triggered in**: `lib/service/app_search/providers/mental_model_search_provider.dart:22`
- **Dart SDK**: 3.10.8
- **custom_lint**: 0.8.1
