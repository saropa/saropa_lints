# Task: `handle_throwing_invocations`

## Summary
- **Rule Name**: `handle_throwing_invocations`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.57 Error Handling Rules
- **Priority**: ⭐ Next in line for implementation

## Problem Statement

Dart has no checked exceptions. A method that can throw is indistinguishable from one that cannot, purely from its signature. When calling third-party APIs, platform channels, or internal methods annotated `@Throws`, developers may forget to wrap calls in try/catch, leading to unhandled exceptions that crash the app or produce silent failures.

This rule identifies invocations of methods that are documented (via `@Throws` annotation or known SDK methods) as potentially throwing, where the call site does not appear inside a `try` block.

## Description (from ROADMAP)

> Invocations that can throw should be handled appropriately.

## Trigger Conditions

### Phase 1 — Explicit `@Throws` Annotation
If a method or function is annotated `@Throws([SomeException])` (from `package:meta` or a custom annotation), any call to it outside a `try/catch/on` block triggers the rule.

### Phase 2 — Known Platform/SDK Patterns
Extend to well-known throwing methods:
- `File.readAsStringSync()`, `File.writeAsStringSync()` etc. (synchronous IO)
- `json.decode(...)` — throws `FormatException`
- `int.parse(...)`, `double.parse(...)` — throws `FormatException`
- `jsonDecode(...)` — throws `FormatException`
- `Uri.parse(...)` — throws `FormatException` (actually doesn't throw in Dart — **check before including**)
- Platform channel invocations (`MethodChannel.invokeMethod`) — throws `PlatformException`

## Implementation Approach

### Annotation Detection (Phase 1)

```dart
context.registry.addMethodInvocation((node) {
  final element = node.methodName.staticElement;
  if (element == null) return;
  if (!_hasThrowsAnnotation(element)) return;
  if (_isInsideTryCatch(node)) return;
  reporter.atNode(node, code);
});
```

`_hasThrowsAnnotation`: checks `element.metadata` for an annotation named `Throws` or `throws`.

`_isInsideTryCatch`: walks parent chain for `TryStatement` nodes.

### Phase 2 — Hardcoded Known Throwers

Maintain a set of `{qualifiedName → [ExceptionTypes]}`:
```dart
const _knownThrowers = {
  'dart.io.File.readAsStringSync': ['FileSystemException'],
  'dart.convert.jsonDecode': ['FormatException'],
  'dart.core.int.parse': ['FormatException'],
  // ...
};
```

Check `element.library?.name` + `element.name` against this map.

### Already-in-async Context
If the invocation is inside an `async` method and the calling code doesn't `await` a future that could throw, that's a different problem. Phase 1 focuses on synchronous throws.

## Code Examples

### Bad (Should trigger)
```dart
// Method annotated @Throws but called without try/catch
@Throws([FormatException])
String parseConfig(String raw) => json.decode(raw);

void loadConfig() {
  final result = parseConfig(rawString);  // ← trigger: no try/catch
  print(result);
}

// Phase 2: known thrower
void readFile() {
  final content = File('config.json').readAsStringSync();  // ← trigger
}
```

### Good (Should NOT trigger)
```dart
// Wrapped in try/catch ✓
void loadConfig() {
  try {
    final result = parseConfig(rawString);
    print(result);
  } on FormatException catch (e) {
    log('Config error: $e');
  }
}

// Using try/catch with catch-all ✓
void readFile() {
  try {
    final content = File('config.json').readAsStringSync();
  } catch (e) {
    handleError(e);
  }
}

// In test files — let tests throw ✓
void main() {
  test('parses valid config', () {
    expect(parseConfig('{}'), isNotNull);
  });
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Method annotated `@Throws` called inside a `try/catch` | **Suppress** | Walk parents for `TryStatement` |
| Method annotated `@Throws` called inside a method that is itself annotated `@Throws` | **Suppress** — the caller propagates the throw | Check enclosing function for `@Throws` annotation |
| Override of a method annotated `@Throws` | **Suppress on the override call** | Only check call sites, not declarations |
| Test files | **Suppress** | `ProjectContext.isTestFile` — tests are EXPECTED to test throwing behavior |
| `@Throws` in a generated file (`.g.dart`, `.freezed.dart`) | **Suppress** | Check `isGenerated` on the file path |
| Method annotated `@Throws([])`  (empty list) | **Suppress** — explicitly declares no throws | Check list length |
| Method that catches internally and rethrows | **Should trigger** — from the caller's perspective it can throw | Caller doesn't know what happens internally |
| `MethodChannel.invokeMethod` (Phase 2) | **Trigger if no try/catch** | Known to throw `PlatformException` |
| `json.decode` already wrapped in `runZonedGuarded` | **Suppress** — error is handled by zone | Hard to detect in Phase 1; add to backlog |
| Assignment inside `var x = throwingMethod();` where `x` is never used | **Trigger** — exception can still crash the app | |

## Unit Tests

### Violations
1. Call to `@Throws`-annotated method outside try/catch → 1 lint
2. `File.readAsStringSync()` outside try/catch (Phase 2) → 1 lint
3. `json.decode(str)` outside try/catch (Phase 2) → 1 lint
4. `int.parse(str)` outside try/catch (Phase 2) → 1 lint
5. Method inside another method where the outer has no `@Throws` and no try/catch → 1 lint

### Non-Violations
1. Throwing call inside `try { ... }` → no lint
2. Throwing call inside `try { ... } on FormatException catch (...) { ... }` → no lint
3. Call to `@Throws`-annotated method inside a `@Throws`-annotated method → no lint
4. Test file calling throwing method → no lint
5. `int.tryParse(str)` (non-throwing variant) → no lint
6. Generated file `.g.dart` → no lint

## Quick Fix

No automated quick fix for wrapping in try/catch — the recovery logic is application-specific.

```
correctionMessage: 'Wrap this call in a try/catch block or annotate the containing method with @Throws to propagate the exception.'
```

## Notes & Issues

1. **`@Throws` annotation does not exist in `package:meta`** as of this writing — check if the project defines its own. If not, this rule depends on a custom annotation that must be documented and the project must adopt it. Consider creating a companion `@Throws` annotation in `package:saropa_lints` or recommending `package:checked_exceptions`.
2. **Phase 2 known-throwers list** needs careful vetting — `Uri.parse()` does NOT throw in Dart (it returns `Uri?` via `tryParse` pattern... actually `Uri.parse` DOES throw `FormatException`). Verify each before adding to the list.
3. **Companion rule**: `prefer_correct_throws` (§1.57) should be implemented together — that rule documents throws, this one enforces handling.
4. **Complexity**: Cross-method analysis (knowing that the enclosing method is `@Throws`) is feasible since it only requires reading one parent annotation, not full call-graph analysis.
5. **`dart.core.int.parse` vs `int.tryParse`**: The quick fix for `int.parse` could be "use `int.tryParse` instead" — but only when null is an acceptable result. This quick fix is optional and should be Phase 2.
