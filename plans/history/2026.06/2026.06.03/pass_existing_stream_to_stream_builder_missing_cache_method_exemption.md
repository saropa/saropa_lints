# pass_existing_stream_to_stream_builder — missing the cache-method exemption that the Future sibling already has

- **Status:** Fixed
- **Created:** 2026-06-03
- **Rule:** `pass_existing_stream_to_stream_builder`
- **Rule class:** `PassExistingStreamToStreamBuilderRule` (`lib/src/rules/widget/widget_lifecycle_rules.dart:3543`)
- **Severity:** WARNING
- **Rule version:** v7
- **Reported from:** `D:\src\contacts\lib\views\utilities\cartoon_avatar_screen.dart:309`

## Summary

`PassExistingStreamToStreamBuilderRule` flags **any** `MethodInvocation` passed as `stream:` (line 3585-3587), unconditionally. Its Future counterpart, `PassExistingFutureToFutureBuilderRule`, already exempts the idiomatic cache-method pattern via `_isCacheMethodCall` (private method on a class that owns a nullable `Future<...>?` field — lines 3458-3468, 3493-3519, citing bug `pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field`). The stream rule should mirror that exemption for a nullable `Stream<...>?` field. Without it, the project's own correction message ("Store the Stream in a field … and pass the stored reference") is satisfied — via a private accessor that returns the cached field — yet the rule still fires.

## Attribution Evidence

```
$ grep -rln "pass_existing_stream_to_stream_builder" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/widget/widget_lifecycle_rules.dart
```

## Reproducer

```dart
class _S extends State<MyWidget> {
  Stream<List<int>>? _contactStream;
  Filters? _last;

  // Returns a cached stream; rebuilds it only when the input changes.
  Stream<List<int>> _getContactStream(Filters f) {
    if (_contactStream == null || f != _last) {
      _last = f;
      _contactStream = repo.watch(f);
    }
    return _contactStream!;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<int>>(
        // FALSE POSITIVE: returns the cached _contactStream, not a fresh stream.
        stream: _getContactStream(_filters), // LINT (should be OK)
        builder: (_, __) => const SizedBox(),
      );
}
```

## Expected vs Actual

| `stream:` argument | Expected | Actual |
|---|---|---|
| private cache-method on a class with a `Stream<...>?` field | OK | **LINT (FP)** |
| `repo.watch(f)` directly (no caching field) | LINT | LINT |
| stored field / local bound to the cached stream | OK | OK |

## Root Cause

`PassExistingStreamToStreamBuilderRule.runWithReporter` (3580-3594) reports on `value is MethodInvocation` with no cache-method opt-out, whereas `PassExistingFutureToFutureBuilderRule` (3454-3480) calls `_isCacheMethodCall(value)` first.

## Suggested Fix

Add an analogous `_isCacheMethodCall` to the stream rule that returns true for a private (`_`-prefixed), implicit-`this`/`this`-target method on a `ClassDeclaration` that declares at least one nullable `Stream<...>?` field; skip the report when it matches. (Same shape as the Future rule's helper, with `Future` → `Stream`.) Consider extracting one shared helper parameterized by type name.

## Fixture Gap

Add a GOOD case mirroring the Future rule's: a private accessor returning a cached `Stream<...>?` field must not lint; a direct `repo.watch(...)` in `stream:` must still lint.

## Environment

- saropa_lints: 13.11.10 (contacts consumes `^13.11.10`)
- Dart SDK `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Native `analysis_server_plugin` (IDE only)
- Triggering file: `D:\src\contacts\lib\views\utilities\cartoon_avatar_screen.dart`

## Finish Report (2026-06-03)

Mirrored the Future rule's cache-method exemption onto `PassExistingStreamToStreamBuilderRule`.

**Changed:**
- `lib/src/rules/widget/widget_lifecycle_rules.dart` — added `_isCacheMethodCall(MethodInvocation)` to the stream rule (private/implicit-this method on a class that declares a nullable `Stream<...>?` field) and guarded the `MethodInvocation` report with it, identical in shape to the Future sibling. Bumped rule version v7 → v8 (doc header + `{v8}` message token; `Updated:` → v13.11.12).
- `example/lib/widget_lifecycle/pass_existing_stream_to_stream_builder_fixture.dart` — added a GOOD cache-method case (`_getContactsStream` returning a cached `Stream<...>?` field), a BAD no-cache-field case (`_loadStream`), and a BAD public-method-with-cache-field case (`loadStream`), mirroring the Future fixture.
- `CHANGELOG.md` — `[Unreleased] > Fixed` bullet.
- `test/rules/widget/pass_existing_stream_to_stream_builder_cache_method_test.dart` — NEW; 7-case AST-predicate test mirroring `pass_existing_future_to_future_builder_cache_method_test.dart`, pinning the `_isCacheMethodCall` contract (cache pattern, explicit-`this`, no-cache-field, public method, free function, non-nullable field, different-receiver).

**Verification:**
- `dart test` on the new stream test + the existing future test → 14/14 pass.
- `dart test test/rules/widget/widget_lifecycle_rules_test.dart` → 72/72 pass (instantiation + tier-membership pins unaffected).
- `dart analyze --fatal-infos` on the new test + changed rule file → clean.
- Why no scan-CLI run: the rule keys off `addInstanceCreationExpression`, which only forms `InstanceCreationExpression` nodes under *resolved* analysis. The standalone scan CLI uses unresolved `parseString`, where `StreamBuilder(...)` stays a `MethodInvocation`, so neither this rule nor its Future sibling is exercisable via scan. The AST-predicate test is the project's established verification path for this exact case (the Future sibling uses the same approach).

**Deliberately NOT done (out of scope):** The bug suggested extracting a shared helper parameterized by type name to dedupe the now-near-identical Future/Stream `_isCacheMethodCall`. Left as-is — refactoring the already-shipped Future helper is broader than the reported fix, and the two predicate tests guard both copies. A follow-up could unify them into one `IgnoreUtils`-style helper taking the type name.
