# BUG: `avoid_redundant_await` — Implements-Future types treated as non-Futures

**Status: Fixed** (supertype walk in `AvoidRedundantAwaitRule`, v2)

Created: 2026-04-28  
Fixed: 2026-04-28  
Rule: `avoid_redundant_await`  
File: `lib/src/rules/core/async_rules.dart` (`AvoidRedundantAwaitRule`, `_staticTypeIsAwaitable`)  
Severity: False positive (resolved)  
Rule version: v2 | Since: ~5.1.0 | Updated: unreleased (see `CHANGELOG.md` `[Unreleased]`)

---

## Summary

Awaiting an expression whose static type is a *subtype* of `Future<T>` (e.g. `class PostgrestBuilder<T, S, R> implements Future<T>`) was flagged as redundant, even though the await is required for the network round-trip. The rule only used `DartType.isDartAsyncFuture`, which matches the canonical `Future` type from `dart:async`, not arbitrary classes that implement `Future`.

**Fix:** `_staticTypeIsAwaitable` treats `Future`, `FutureOr`, and `Stream` as before, and for `InterfaceType` also returns true when any entry in `allSupertypes` is `Future` / `FutureOr` / `Stream` (same idea as `_isStreamOrSubclass` elsewhere in this file).

---

## Attribution Grep

```
$ grep -rn "'avoid_redundant_await'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/core/async_rules.dart:5062:    'avoid_redundant_await',
```

Single match — owns the diagnostic. Sibling repos checked (none emit this code).

---

## Reproduction (historical)

Downstream consumer: `D:\src\contacts` (saropa_lints 12.5.3).

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> example() async {
  // Was FLAGGED: [avoid_redundant_await] …
  final response = await Supabase.instance.client
      .from('user')
      .select('user_uuid')
      .eq('id', 'abc')
      .single();
}
```

Real downstream sites (before fix):

- `lib/service/supabase/auth/supabase_account_auth.dart:78-82` (`.single()`)
- `lib/service/supabase/auth/supabase_account_auth.dart:122-126` (`.maybeSingle()`)

Chain: `PostgrestBuilder<T, S, R> implements Future<T>` (`postgrest` package).

---

## Fixture (this repo)

`example/lib/async/avoid_redundant_await_fixture.dart` includes `_DelegatingFuture` (implements `Future<int>`) and `goodImplementsFuture()` with `await _DelegatingFuture(Future.value(1))` — expect **no** `avoid_redundant_await` diagnostic.

---

## Workaround in Downstream (remove after upgrade)

`saropa/contacts` 2026-04-28 — inline `// ignore: saropa_lints/avoid_redundant_await` at Postgrest `.single()` / `.maybeSingle()` call sites. **Remove those ignores** after upgrading to a `saropa_lints` release that includes this fix (watch `CHANGELOG.md` until the `[Unreleased]` **avoid_redundant_await** item appears under a numbered version).

---

## Why The Rule Misfired (historical)

`isDartAsyncFuture` is true only for the analyzer’s canonical `Future<T>` type, not for a class whose name is e.g. `PostgrestBuilder` even when it implements `Future<T>`.

---

## Suggested Fix (implemented)

Walk `InterfaceType.allSupertypes` for `Future` / `FutureOr` / `Stream`, as in:

```dart
bool _staticTypeIsAwaitable(DartType type) {
  if (type.isDartAsyncFuture) return true;
  if (type.isDartAsyncFutureOr) return true;
  if (type.isDartAsyncStream) return true;
  if (type is! InterfaceType) return false;
  return type.allSupertypes.any(
    (DartType t) =>
        t.isDartAsyncFuture ||
        t.isDartAsyncFutureOr ||
        t.isDartAsyncStream,
  );
}
```
