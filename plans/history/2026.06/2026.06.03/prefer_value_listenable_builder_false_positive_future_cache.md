# prefer_value_listenable_builder — False Positive when the single field is a Future/Stream cache for a FutureBuilder/StreamBuilder

- **Status:** Fixed
- **Created:** 2026-06-03
- **Rule:** `prefer_value_listenable_builder`
- **Rule class:** `PreferValueListenableBuilderRule` (`lib/src/rules/core/performance_rules.dart:1430`)
- **Registration:** `lib/saropa_lints.dart:1269` (`PreferValueListenableBuilderRule.new`)
- **Severity:** INFO
- **Rule version:** v4
- **Reported from:** `D:\src\contacts\lib\views\contact\contact_companion_screen.dart` (line 86, class `_ContactCompanionScreenState`)

## Summary

The rule suggests replacing `setState` with `ValueNotifier` + `ValueListenableBuilder` for any `State` with exactly one non-final field and 1–3 `setState` calls. It fires when that single field is a cached `Future<T>?` (or `Stream<T>?`) that backs a `FutureBuilder`/`StreamBuilder`, where the `setState` exists to **invalidate and re-fetch** the future, not to publish a display value. `ValueListenableBuilder` does not model "re-run an async fetch"; the suggestion is inapplicable for this idiom.

What should happen: a `State` whose only non-final field is a `Future`/`Stream` should not be suggested for `ValueListenableBuilder`.

## Attribution Evidence

```
$ grep -rn "'prefer_value_listenable_builder'" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/core/performance_rules.dart:1447:    'prefer_value_listenable_builder',
```

Not present as a rule definition in saropa_drift_advisor (only referenced in its `analysis_options.yaml`).

## Reproducer

```dart
import 'package:flutter/material.dart';

// OK — single field is a cached Future backing a FutureBuilder; setState
// invalidates it to re-fetch. ValueListenableBuilder cannot express this.
// Currently FIRES (false positive).
class _CountState extends State<StatefulWidget> {        // LINT (should be OK)
  Future<int>? _countFuture;

  void _refresh() => setState(() => _countFuture = null); // re-fetch on rebuild

  @override
  Widget build(BuildContext context) {
    _countFuture ??= _load();
    return FutureBuilder<int>(future: _countFuture, builder: (_, __) => const SizedBox());
  }

  Future<int> _load() async => 0;
}

// BAD — single primitive display value driven by setState. Should fire.
class _CounterState extends State<StatefulWidget> {       // LINT (correct)
  int _counter = 0;
  void _inc() => setState(() => _counter++);
  @override
  Widget build(BuildContext context) => Text('$_counter');
}
```

## Expected vs Actual

| Single non-final field | Expected | Actual |
|---|---|---|
| `Future<int>? _countFuture` (FutureBuilder cache) | OK | **LINT (FP)** |
| `Stream<T>? _stream` (StreamBuilder cache) | OK | **LINT (FP)** |
| `int _counter` (display value) | LINT | LINT |

## AST Context

```
ClassDeclaration (_ContactCompanionScreenState)
  extendsClause: State<ContactCompanionScreen>
  members:
    FieldDeclaration  final ScrollController _scrollController  // final → not counted
    FieldDeclaration  Future<int>? _headerCountFuture           // non-final → stateFieldCount == 1
    MethodDeclaration ... setState(...) once                    // setStateCallCount == 1
```

## Root Cause

`runWithReporter` (lines 1459–1492) counts non-final, non-static fields and `setState` invocations, then reports when `stateFieldCount == 1 && setStateCallCount in [1,3]`. The field's **type** is never inspected. A `Future`/`Stream` cache (the standard FutureBuilder/StreamBuilder invalidation idiom) is counted as if it were a simple synchronous display value, for which the `ValueListenableBuilder` rewrite is valid.

## Suggested Fix

When counting state fields (lines 1472–1477), skip fields whose declared type is `Future<...>` or `Stream<...>` (these back `FutureBuilder`/`StreamBuilder`, not `ValueListenableBuilder`). If skipping them drops `stateFieldCount` to 0, the rule correctly stays silent.

```dart
if (!member.isStatic && !member.fields.isFinal) {
  final String? t = member.fields.type?.toSource();
  if (t != null && (t.startsWith('Future<') || t.startsWith('Stream<') ||
                    t == 'Future' || t == 'Stream')) {
    continue; // async-builder cache, not ValueListenable-able state
  }
  stateFieldCount++;
}
```

## Fixture Gap

`example/lib/performance/prefer_value_listenable_builder_fixture.dart` has only the `int _counter` BAD case (and that BAD `_bad790__MyState` actually has no `setState` call, so its `expect_lint` is itself suspect against the `setStateCallCount >= 1` gate — worth a separate look). Add a GOOD case:

```dart
// GOOD: single Future field backing a FutureBuilder — no lint
class _GoodFutureState extends State<MyWidget> {
  Future<int>? _future;
  void _refresh() => setState(() => _future = null);
  Widget build(BuildContext context) =>
      FutureBuilder<int>(future: _future ??= load(), builder: (_, __) => const SizedBox());
}
```

## Environment

- saropa_lints: 13.11.9 (consumed in contacts as `^13.11.9`)
- Dart SDK: `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Plugin mode: native `analysis_server_plugin` (IDE analysis server only)
- Triggering file: `D:\src\contacts\lib\views\contact\contact_companion_screen.dart`

## Finish Report (2026-06-03)

**Fix:** In `PreferValueListenableBuilderRule.runWithReporter`, the state-field
counter now skips fields whose declared type is `Future` or `Stream` (raw or
parameterized) via the new `_isAsyncBuilderCacheType(TypeAnnotation?)` helper.
A `State` whose only non-final field is such a cache drops to
`stateFieldCount == 0` and the rule stays silent. The detection uses the
syntactic type name (`NamedType.name.lexeme`), so it works without resolution.
Rule version bumped v3 → v4 (doc header + `{v3}`→`{v4}` message marker).

**Fixture:** `example/lib/performance/prefer_value_listenable_builder_fixture.dart`
— added `_inc()` with a real `setState` to the BAD `_bad790__MyState` (it
previously had no `setState`, so its `expect_lint` could not have fired against
the `setStateCallCount >= 1` gate), and added GOOD `_good790FutureCacheState`
and `_good790StreamCacheState` cases.

**Verification:** `dart run saropa_lints scan d:/tmp --tier comprehensive
--files <repro> --format json` against a 3-class reproducer (Future cache,
Stream cache, int counter) — exactly one `prefer_value_listenable_builder` hit,
on the `int _counter` class (line 25); the Future and Stream caches are silent.
`dart analyze` clean.

**Changelog:** `### Fixed` bullet under `[Unreleased]`.
