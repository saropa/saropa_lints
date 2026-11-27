# BUG: `require_error_widget` — Fires when the future catches every failure itself

**Status: Open**

Created: 2026-11-26
Rule: `require_error_widget`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~1164)
Severity: False positive
Rule version: v5 | saropa_lints 17.9.1

---

## Summary

A `FutureBuilder` is reported when its builder never reads the snapshot error, even though the future is produced by a method that catches every failure, logs it, and completes with a fallback value. `snapshot.hasError` can never be true there. Satisfying the rule means adding unreachable code, or logging inside the builder, which repeats on every rebuild.

---

## Attribution Evidence

```
$ python scripts/checks/check_report_attribution.py require_error_widget
OK    require_error_widget: defined at lib/src/rules/widget/widget_patterns_require_rules.dart:1184
```

**Emitter registration:** `lib/saropa_lints.dart:1153` (`RequireErrorWidgetRule.new`)
**Rule class:** `RequireErrorWidgetRule`

---

## Reproducer

```dart
class _RowState extends State<Row_> {
  late final Future<String?> _future = _load();

  // Never completes with an error.
  Future<String?> _load() async {
    try {
      return await fetchName();
    } on Object catch (error, stack) {
      log(error, stack);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>( // LINT, but should be OK
      future: _future,
      builder: (context, snapshot) => Text(snapshot.data ?? 'none'),
    );
  }
}
```

A second shape: the future is a getter on a controller declared in another library, and the producing method there has the same catch-all.

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the error state is unreachable and the failure is handled and logged where the future is created |
| **Actual** | `[require_error_widget] FutureBuilder/StreamBuilder must handle error state ...` |

---

## AST Context

```
MethodDeclaration (build)
  └─ ReturnStatement
      └─ InstanceCreationExpression (FutureBuilder)  ← constructorName reported
          └─ ArgumentList
              ├─ NamedArgument future: SimpleIdentifier (_future)  ← never inspected
              └─ NamedArgument builder: FunctionExpression
```

---

## Root Cause

`runWithReporter` inspects only the `builder:` argument (`_builderHandlesError` or `_bodyHandlesError`). The `future:` argument is never read, so a future that is guaranteed not to error is treated the same as a raw I/O future.

---

## Suggested Fix

When `future:` is a field or a call that resolves within the compilation unit (the way `_findNamedExecutableBody` already resolves builder tear-offs), skip the report if the producing method is `async` and its whole body is a `try` with a catch-all (`catch (e)` or `on Object catch`) whose clause neither throws nor rethrows, with no `return <future>` left un-awaited inside the `try`.

A future declared in another library cannot be resolved by name; that shape can stay reported unless element resolution is used.

---

## Fixture Gap

Add to the `require_error_widget` fixture:

- OK: field initialized from a same-file `async` method with a catch-all that returns a fallback.
- LINT: same method with `rethrow` in the catch.
- LINT: same method that does `return fetchName();` without `await` inside the `try` (the error escapes the catch).

---

## Environment

- saropa_lints: 17.9.1
- Consumer: Flutter app, three sites (one cross-library controller future, two same-file futures)
