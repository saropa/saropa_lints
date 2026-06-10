# BUG: `avoid_returning_null_for_future` — Fires on `return null` when the declared return type is a NULLABLE Future (`Future<T>?`)

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_returning_null_for_future`
File: `lib/src/rules/flow/return_rules.dart` (line ~660-675)
Severity: False positive
Rule version: v1 | Since: v5.1.0 | Updated: v13.12.2

---

## Summary

The rule flags `return null` from a synchronous function whose return type
`isDartAsyncFuture`, on the premise that awaiting that null causes a runtime
null error. But it does not inspect the **nullability** of the return type.
When the function is declared `Future<T>?` (nullable Future), returning `null`
is correct and idiomatic — the caller holds a `Future<T>?` and never awaits a
null future (e.g. `FutureBuilder.future` accepts `Future<T>?` and shows its
empty/initial state when the future is null). The rule fires anyway because
`isDartAsyncFuture` is true for both `Future<T>` and `Future<T>?`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_returning_null_for_future'" lib/src/rules/
# lib/src/rules/flow/return_rules.dart:644:    'avoid_returning_null_for_future',

# Negative — rule is NOT in the sibling drift-advisor repo
grep -rn "avoid_returning_null_for_future" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/flow/return_rules.dart:644`
**Rule class:** `AvoidReturningNullForFutureRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
import 'dart:io' as io;

class FileLister {
  // Return type is NULLABLE Future: `Future<List<String>?>?`.
  // Returning null is valid — the caller (e.g. FutureBuilder.future, which
  // accepts Future<T>?) renders its initial/empty state when the future is null.
  // Nothing ever awaits a null future, so there is no runtime null error.
  Future<List<String>?>? buildFileFuture(io.Directory? folder) {
    if (folder == null) return null; // LINT — but should NOT lint (false positive)
    return _listFiles(folder);
  }

  Future<List<String>?> _listFiles(io.Directory folder) async => <String>[];
}

// Contrast — this SHOULD still lint (non-nullable Future return, awaited null = NPE):
Future<String> fetchName() {
  return null; // LINT — correct true positive (Future<String> is non-nullable)
}
```

**Frequency:** Always, whenever a synchronous function declared to return a
nullable Future (`Future<T>?`) contains a `return null`.

Real site in `d:\src\contacts`:
- `lib/components/user/backup_restore/file_restore_list.dart:78` —
  `Future<List<String>?>? _buildFileFuture(io.Directory? folder) { if (folder == null) return null; ... }`.
  The result is fed to `FutureBuilder<List<String>?>(future: _fileListFuture, ...)`, which accepts a
  nullable future.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the return type is `Future<T>?` (nullable), so `return null` is type-correct and never produces a runtime null error when consumed. |
| **Actual** | `[avoid_returning_null_for_future] Returning null from a synchronous function declared to return Future<T> ... causes a runtime null error` reported at the `return null` statement. |

---

## AST Context

```
MethodDeclaration (_buildFileFuture)
  returnType: NamedType  Future<List<String>?>?   ← nullabilitySuffix == question (NULLABLE)
  └─ BlockFunctionBody (synchronous)
      └─ Block
          └─ IfStatement (folder == null)
              └─ ReturnStatement
                  └─ NullLiteral (null)            ← node reported here
```

---

## Root Cause

`lib/src/rules/flow/return_rules.dart:660-675`, `runWithReporter`:

```dart
final DartType? returnType = getReturnTypeFromBody(body);
if (returnType == null) return;
if (!returnType.isDartAsyncFuture) return;   // <-- true for Future<T> AND Future<T>?
reporter.atNode(node);
```

`DartType.isDartAsyncFuture` checks only the type's element (is it `dart:async`'s
`Future`), independent of nullability. `Future<T>` and `Future<T>?` both return
`true`. The rule never reads `returnType.nullabilitySuffix`. For a nullable
return type the function is *declared* to allow `null`, the analyzer's own type
system accepts `return null`, and downstream consumers expect a `Future<T>?`.
The rule's premise ("causes a runtime null error when the future is awaited")
does not hold for `Future<T>?` because the caller must null-check before
awaiting — that is the whole point of the `?`.

---

## Suggested Fix

In `lib/src/rules/flow/return_rules.dart`, add a nullability guard immediately
after the `isDartAsyncFuture` check (around line 672):

```dart
if (!returnType.isDartAsyncFuture) return;

// A nullable Future return type (`Future<T>?`) explicitly permits `null`;
// the caller must null-check before awaiting, so `return null` is correct
// and cannot produce a runtime null error. Only non-nullable `Future<T>`
// returns are at risk.
if (returnType.nullabilitySuffix == NullabilitySuffix.question) return;

reporter.atNode(node);
```

(Import `package:analyzer/dart/element/nullability_suffix.dart` if not already
in scope.)

---

## Fixture Gap

The fixture at `example*/lib/flow/avoid_returning_null_for_future_fixture.dart`
should include:

1. `Future<String> f() { return null; }` — expect LINT (non-nullable, true positive)
2. `Future<String>? f() { return null; }` — expect NO lint (nullable Future, false-positive guard)
3. `Future<List<int>?>? f(bool b) { if (b) return null; return Future.value(<int>[]); }` — expect NO lint
4. `Future<String> f() async { return null; }` — expect NO lint (async body already exempt; regression guard)

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0 (per pubspec environment constraint)
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/components/user/backup_restore/file_restore_list.dart:78`
