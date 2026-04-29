# BUG: `avoid_redundant_await` — Implements-Future types treated as non-Futures

**Status: Open**

Created: 2026-04-28
Rule: `avoid_redundant_await`
File: `lib/src/rules/core/async_rules.dart` (~line 5030)
Severity: False positive
Rule version: v1 | Since: ~12.x | Updated: HEAD

---

## Summary

Awaiting an expression whose static type is a *subtype* of `Future<T>` (e.g. `class PostgrestBuilder<T, S, R> implements Future<T>`) gets flagged as redundant, even though the await is required for the network round-trip. The rule's type check uses `DartType.isDartAsyncFuture`, which only matches the exact `Future` type and not types that `implements Future` / `extends Future`.

---

## Attribution Grep

```
$ grep -rn "'avoid_redundant_await'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/core/async_rules.dart:5046:    'avoid_redundant_await',
```

Single match — owns the diagnostic. Sibling repos checked (none emit this code).

---

## Reproduction

Downstream consumer: `D:\src\contacts` (saropa_lints 12.5.3, but the rule logic is unchanged in HEAD 12.8.0).

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> example() async {
  // FLAGGED: [avoid_redundant_await] Awaiting a non-Future expression is redundant…
  final response = await Supabase.instance.client
      .from('user')
      .select('user_uuid')
      .eq('id', 'abc')
      .single();
}
```

Real downstream sites:
- `lib/service/supabase/auth/supabase_account_auth.dart:78-82` (`.single()`)
- `lib/service/supabase/auth/supabase_account_auth.dart:122-126` (`.maybeSingle()`)

Both call into:

```
D:\tools\Pub\Cache\hosted\pub.dev\postgrest-2.7.0\lib\src\postgrest_builder.dart:40
class PostgrestBuilder<T, S, R> implements Future<T> {
```

The chain ends in a `PostgrestTransformBuilder` / `PostgrestFilterBuilder` / `PostgrestBuilder`, all of which `implement Future<T>`. The await IS required: removing it leaves a builder object instead of the resolved JSON map, and downstream code (`response['user_uuid']`) fails at compile time.

---

## Why The Rule Misfires

`async_rules.dart:5061-5077`:

```dart
context.addAwaitExpression((AwaitExpression node) {
  final DartType? type = node.expression.staticType;
  if (type == null) return;

  // Skip dynamic and Object — could be a Future at runtime
  if (type is DynamicType) return;
  if (type.isDartCoreObject) return;

  // Allow Future, FutureOr, and Stream
  if (type.isDartAsyncFuture) return;
  if (type.isDartAsyncFutureOr) return;
  if (type.isDartAsyncStream) return;

  // Skip type parameters — T could be a Future at runtime
  if (type is TypeParameterType) return;

  reporter.atNode(node);
});
```

`DartType.isDartAsyncFuture` checks whether the type is exactly `Future<T>` from `dart:async`. A class that **implements** `Future<T>` (like `PostgrestBuilder`) is a `Future<T>` at runtime — `await` works correctly on it — but `isDartAsyncFuture` returns false because the type's name is `PostgrestBuilder`, not `Future`.

The same FP fires for any user-defined `Future` implementer (custom thenable / awaitable wrappers).

---

## Suggested Fix

Walk the type's supertype chain instead of comparing only the head type. Pseudocode:

```dart
bool _isFutureLike(DartType type) {
  if (type.isDartAsyncFuture || type.isDartAsyncFutureOr || type.isDartAsyncStream) {
    return true;
  }
  // InterfaceType: walk implemented interfaces + superclass chain.
  if (type is InterfaceType) {
    for (final InterfaceType iface in type.allSupertypes) {
      if (iface.isDartAsyncFuture) return true;
    }
  }
  return false;
}
```

`allSupertypes` on `InterfaceType` is the standard analyzer way to ask "does this type's class hierarchy include `Future<T>`?". This matches both `extends Future` and `implements Future`.

---

## Fixture

Suggested addition to `example/lib/async/async_rules_fixture.dart`:

```dart
// User-defined Future implementer — await IS required (the value is a Future).
class CustomFutureLike<T> implements Future<T> {
  final T value;
  CustomFutureLike(this.value);
  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) async {
    return onValue(value) as R;
  }
  // … remaining Future members elided
}

Future<void> awaitImplementsFuture() async {
  final result = await CustomFutureLike<int>(42); // OK, NOT redundant
  print(result);
}
```

Expected: zero diagnostics.
Actual: `avoid_redundant_await` fires on the `await CustomFutureLike(42)`.

---

## Workaround in Downstream

`saropa/contacts` 2026-04-28 — added inline `// ignore: saropa_lints/avoid_redundant_await -- PostgrestBuilder.single()/maybeSingle() returns a builder that implements Future<T>; the lint's isDartAsyncFuture check only matches the exact Future type` at both call sites in [`lib/service/supabase/auth/supabase_account_auth.dart`](../../contacts/lib/service/supabase/auth/supabase_account_auth.dart). To be removed once this rule walks the supertype chain.
