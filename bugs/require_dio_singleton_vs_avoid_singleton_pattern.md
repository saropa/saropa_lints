# Bug: `require_dio_singleton` contradicts `avoid_singleton_pattern`

**Ref:** https://github.com/saropa/saropa_lints/issues/274
**Status:** Open
**Severity:** High -- enforces an anti-pattern while another rule penalizes it

## Problem

`require_dio_singleton` flags inline `Dio()` calls and accepts `static final Dio instance = Dio()` as the correct pattern (see its GOOD example in `dio_rules.dart:616-618`). `avoid_singleton_pattern` flags classes that use the full GoF singleton (static instance field + factory constructor + private constructor) — it does NOT fire on a bare `static final` field alone.

The contradiction is architectural, not a direct rule collision: `require_dio_singleton` steers users toward `static final` singletons, and when users follow that advice to its logical conclusion (wrapping in a proper singleton class), they trigger `avoid_singleton_pattern`. Both rules agree singletons are bad in their correction messages — but `require_dio_singleton` recommends one.

More fundamentally, `require_dio_singleton` recommends the wrong architecture for resource-holding types. Static `Dio` singletons cause:
- Untestable code (no DI, no mocking without hacks)
- Resource leaks (no `dispose` path for `dio.close()`)
- State contamination when multiple clients are needed (auth vs public)
- Platform bugs (`sendTimeout` unsupported on web)

## Correct Patterns (from the issue)

### DI Container (e.g. GetIt)

```dart
getIt.registerLazySingleton<Dio>(
  () => Dio(BaseOptions(connectTimeout: const Duration(seconds: 35)))
    ..transformer = BackgroundTransformer()
    ..interceptors.add(RetryInterceptor(dio: dio, retries: 3)),
  dispose: (d) => d.close(),
);
```

### Factory Pattern

```dart
class DioFactory {
  DioFactory(this._tokenStore, this._logger);

  final TokenStore _tokenStore;
  final Logger _logger;

  Dio create() {
    final dio = Dio(_baseOptions())..transformer = BackgroundTransformer();
    dio.interceptors.addAll(_buildInterceptors(dio));
    return dio;
  }
}
```

Both approaches solve lifecycle management and testability.

## Proposed Fix

Refactor `require_dio_singleton` to `require_dio_factory` or `require_dio_injected`:

1. **Flag** `Dio()` constructed in `TopLevelVariableDeclaration` or `static` `FieldDeclaration`
2. **Allow** `Dio()` inside methods, constructors, closures, and DI registration blocks
3. **Be framework-agnostic** -- detect the pattern (factory/DI), not specific package names like `getIt`

### AST Edge Cases

- **Static getters:** `static Dio get client => _dio;` -- check `MethodDeclaration` with `isGetter && isStatic`
- **Late initialization:** `static late final Dio client = Dio();` -- handle `late` modifier
- **Global caching functions:** `Dio? _cached; Dio getGlobalDio() => _cached ??= Dio();` -- top-level variable + null-coalescing assignment

## Implementation Notes

- Current rule is in [dio_rules.dart](lib/src/rules/packages/dio_rules.dart)
- `avoid_singleton_pattern` is in [architecture_rules.dart](lib/src/rules/architecture/architecture_rules.dart)
- Must use the `SaropaLintRule` base class (not the retired `custom_lint_builder` API)
- Must use `SaropaDiagnosticReporter` via `runWithReporter()`
