# Task: `avoid_private_typedef_functions`

## Summary

- **Rule Name**: `avoid_private_typedef_functions`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Style

## Problem Statement

Dart supports typedef declarations for naming function types:

```dart
typedef _ClickHandler = void Function(BuildContext context);
```

Private typedefs (those starting with `_`) that define function types are almost always unnecessary. A private function type alias is used only within the file where it is declared. In nearly every case, the inline function type (`void Function(BuildContext context)`) is clearer at the usage site — it shows the exact signature without requiring the reader to navigate to the typedef declaration.

The key issues with private function typedefs:

1. **Hidden complexity**: The reader sees `_ClickHandler handler` and must look up the typedef to know the actual signature. Inline types are self-documenting.
2. **Used once or twice**: Private typedefs are rarely reused enough within a single file to justify the naming overhead. If the type appears more than 3-4 times with complex generics, the typedef becomes worthwhile — but that is the exception.
3. **Naming overhead**: Naming a private type adds cognitive overhead. The name `_ClickHandler` doesn't add meaning beyond `void Function(BuildContext)`.
4. **Not part of the public API**: Unlike public typedefs (which improve discoverability and documentation), private typedefs serve no external audience.

The exception is generic or complex function typedefs that significantly reduce the verbosity of repeated usage, or typedefs that serve as documentation markers. These should be suppressable with `// ignore:`.

## Description (from ROADMAP)

Flag `typedef` declarations that are private (name starts with `_`) and define a function type (as opposed to a class type alias or record type alias), suggesting replacement with inline function types at each usage site.

## Trigger Conditions

The rule triggers when:

1. A `FunctionTypeAlias` or `GenericTypeAlias` is found.
2. The typedef name starts with `_` (private).
3. The right-hand side of the typedef defines a function type (i.e., `... = void Function(...)` or `... = T Function(...)`).

It does NOT trigger for:

- Public typedefs (no `_` prefix) — these may be part of the public API.
- Typedefs that define non-function types (class aliases, record type aliases): `typedef _MyRecord = (String, int)`.
- Generic typedefs where the type parameter changes the signature meaningfully and inlining would be verbose.
- Typedefs that are used more than a configurable threshold of times in the same file (default: 3 usages).

## Implementation Approach

### AST Visitor

Handle both legacy `FunctionTypeAlias` (pre-Dart 2.13 syntax) and modern `GenericTypeAlias` (post-2.13 `typedef Foo = ...` syntax):

```dart
context.registry.addFunctionTypeAlias((node) {
  _checkTypedefName(node.name, reporter);
});

context.registry.addGenericTypeAlias((node) {
  if (_isFunctionType(node.type)) {
    _checkTypedefName(node.name, reporter);
  }
});
```

### Detection Logic

**Step 1 — Check private name:**

```dart
void _checkTypedefName(Token nameToken, ErrorReporter reporter) {
  if (!nameToken.lexeme.startsWith('_')) return;
  reporter.atToken(nameToken, code);
}
```

**Step 2 — Verify it is a function type alias (for `GenericTypeAlias`):**

```dart
bool _isFunctionType(TypeAnnotation type) {
  return type is GenericFunctionType;
}
```

For `FunctionTypeAlias`, the AST node itself is always a function type — no additional check needed.

**Step 3 — Count usages to suppress low-noise cases (optional optimisation):**

If the typedef is used more than `_maxUsages` (e.g., 3) times in the same file, suppress the report to avoid flagging cases where the typedef genuinely reduces verbosity:

```dart
// This requires a two-pass analysis or a collected set of all TypeName references.
// Consider making this a secondary check or configurable option.
```

This is complex to implement efficiently and may be deferred to a follow-up enhancement.

**Step 4 — Distinguish function types from other generic aliases:**

A `GenericTypeAlias` like `typedef _Result<T> = (String, T)` is a record type, not a function type. Ensure `_isFunctionType` checks specifically for `GenericFunctionType`:

```dart
bool _isFunctionType(TypeAnnotation type) {
  if (type is GenericFunctionType) return true;
  // Also handle type parameters that wrap a function type:
  // typedef _Handler<T> = void Function(T);
  if (type is NamedType) {
    // This would be a class type alias — not a function type
    return false;
  }

  return false;
}
```

## Code Examples

### Bad (triggers rule)

```dart
// Private function typedef — unnecessary, use inline type
typedef _ClickHandler = void Function(BuildContext context);
typedef _ErrorCallback = void Function(Object error, StackTrace trace);
typedef _Predicate<T> = bool Function(T item);

class ButtonWidget {
  final _ClickHandler onTap; // could be: final void Function(BuildContext) onTap
  ButtonWidget({required this.onTap});
}

void processErrors(List<String> items, _ErrorCallback onError) {
  // _ErrorCallback could be: void Function(Object, StackTrace)
}
```

### Good (compliant)

```dart
// Inline function types — clear at usage site
class ButtonWidget {
  final void Function(BuildContext context) onTap;
  ButtonWidget({required this.onTap});
}

void processErrors(
  List<String> items,
  void Function(Object error, StackTrace trace) onError,
) {
  // implementation
}

// Public typedef — acceptable (part of public API)
typedef ClickHandler = void Function(BuildContext context);

// Non-function type alias — not flagged
typedef _UserRecord = (String id, String name);

// Private typedef for a genuinely complex generic — suppressed by developer
// ignore: avoid_private_typedef_functions
typedef _Transformer<A, B, C> = C Function(A input, B config, String key);
```

## Edge Cases & False Positives

- **Typedef used many times in one file**: If `_ErrorCallback` is used in 15 different method signatures across a 300-line file, the typedef saves significant repetition and the inline form would be tedious. A usage-count threshold (default: suppress if used 4+ times) would prevent flagging these. This is a configuration option.
- **Complex generic function signatures**: `typedef _Mapper<T, R> = Future<R> Function(T input, {String? key, bool force})` — inlining this every time it is used adds real verbosity. The usage-count check or minimum-complexity threshold would handle this.
- **Interop with external packages**: Some external packages define callbacks that match specific signatures. Using a typedef to name those signatures locally can improve clarity even in private scope.
- **`FunctionTypeAlias` vs `GenericTypeAlias`**: Dart has two AST nodes for typedefs depending on the syntax used. The legacy `typedef _Handler(String arg)` form uses `FunctionTypeAlias`. The modern `typedef _Handler = void Function(String)` uses `GenericTypeAlias`. Ensure both are handled.
- **Type aliases for record types**: `typedef _Pair = (String, int)` is a record type alias. `_isFunctionType` must return `false` for these. Record type aliases are a relatively new Dart feature; ensure the implementation handles them correctly.
- **Class type aliases**: `typedef _UserList = List<User>` — this is a `GenericTypeAlias` where the right side is a `NamedType`. `_isFunctionType` returns `false`. Not flagged.
- **Callbacks in generated code**: Generated code often uses private typedefs. Exclude generated files.

## Unit Tests

### Should Trigger (violations)

```dart
// Private function typedefs
typedef _Handler = void Function(String event);    // LINT
typedef _Callback<T> = void Function(T value);     // LINT
typedef _Predicate = bool Function(dynamic item);  // LINT

// Legacy function typedef syntax
typedef void _LegacyHandler(String event);         // LINT
```

### Should NOT Trigger (compliant)

```dart
// Public function typedef — excluded
typedef Handler = void Function(String event);     // OK

// Non-function private type alias — excluded
typedef _UserRecord = (String, int);               // OK
typedef _StringList = List<String>;                // OK

// Suppressed with ignore comment
// ignore: avoid_private_typedef_functions
typedef _Complex<A, B, C> = C Function(A, B, {String? key}); // OK — suppressed

// Function typedef in generated file — excluded
// (file path matches *.g.dart)
```

## Quick Fix

There is no automated quick fix for this rule because:

1. Replacing a typedef requires substituting the typedef name with the full inline type everywhere it is used.
2. The replacement must happen across multiple usage sites in the same file.
3. The quick fix would need to collect all `TypeName` references to the typedef and replace each one.

While technically feasible, this is a complex multi-site edit. Provide a descriptive `correctionMessage` instead:

```
correctionMessage: 'Remove this private typedef and replace usages with the inline function type. For "_ClickHandler = void Function(BuildContext)", replace fields and parameters typed as "_ClickHandler" with "void Function(BuildContext)" directly.',
```

If time permits, implement a simple fix that replaces `_TypedefName` → inline type at the declaration, and adds a note that usages must be updated manually.

## Notes & Issues

- The usage-count threshold (suppress if used 4+ times) would require scanning the entire compilation unit for type references, which is potentially expensive. Consider making this optional and disabled by default, or implementing it as a lazy count during block analysis.
- This rule is Comprehensive tier (one level below Pedantic) because it is a stylistic preference rather than a clear best practice. Many experienced Dart developers legitimately disagree on whether private function typedefs are harmful.
- Consider adding a `minUsageCount` option to `analysis_options.yaml` allowing teams to set their own threshold for when a private typedef is "justified." Default: `1` (always flag), configurable to `3` or `4` for teams that want some tolerance.
- Public typedefs are explicitly excluded because they serve API discoverability and documentation purposes. This rule is specifically about private, internal-use-only function typedefs.
- The `FunctionTypeAlias` AST node handles the older `typedef void _Handler(String)` syntax. Both forms must be detected.
