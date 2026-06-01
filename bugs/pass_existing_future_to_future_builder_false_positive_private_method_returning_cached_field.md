# BUG: `pass_existing_future_to_future_builder` — Fires on Private Method Calls That Return a Cached Field

**Status: Open**

Created: 2026-05-31
Rule: `pass_existing_future_to_future_builder`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~3418)
Severity: False positive
Rule version: v8 | Since: v0.1.4 | Updated: v?.?.?

---

## Summary

The rule fires on `FutureBuilder(future: _methodCall(...), ...)` whenever the future-argument is any `MethodInvocation` — including method calls that internally return a cached `Future<T>?` field. The recommended fix in the lint message ("Cache the Future in initState() or a final field") is already implemented in these sites — just through a getter-method indirection that the rule cannot see through.

The cache-method pattern is the project's idiomatic approach when the cached future depends on dynamic input that may change (e.g., contact UUIDs received from a parent stream), and a plain `late final` would be wrong. The rule's current detection criminalizes it.

---

## Attribution Evidence

```bash
$ grep -rn "'pass_existing_future_to_future_builder'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/widget/widget_lifecycle_rules.dart:3437:    'pass_existing_future_to_future_builder',
```

Single match — rule is unambiguously emitted by `saropa_lints`. No cross-repo grep needed; the rule name is not shared with `saropa_drift_advisor` or other sibling plugins.

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:3437`
**Rule class:** `PassExistingFutureToFutureBuilderRule`
**Diagnostic `source` / `owner` as seen in VS Code Problems panel:** `dart` (via `custom_lint`)

---

## Reproducer

Minimal Dart code reproducing the FP. The widget already caches the Future per the rule's recommendation — just through a helper method that internally returns the cached field when inputs are unchanged.

```dart
import 'package:flutter/material.dart';

class CachedContactsWidget extends StatefulWidget {
  const CachedContactsWidget({super.key});

  @override
  State<CachedContactsWidget> createState() => _CachedContactsWidgetState();
}

class _CachedContactsWidgetState extends State<CachedContactsWidget> {
  // Cached future — exactly the pattern the rule's correction message asks for.
  Future<List<String>?>? _contactsFuture;
  List<String>? _lastKeys;

  Future<List<String>?> _getContactsFuture(List<String>? keys) {
    // Return cached future when input hasn't changed.
    final bool unchanged = _contactsFuture != null && _listEq(keys, _lastKeys);
    if (unchanged) return _contactsFuture!;
    _lastKeys = keys;
    _contactsFuture = _fetch(keys);
    return _contactsFuture!;
  }

  Future<List<String>?> _fetch(List<String>? keys) async => keys;

  bool _listEq(List<String>? a, List<String>? b) =>
      a?.length == b?.length;

  @override
  Widget build(BuildContext context) {
    final List<String>? keys = const <String>['a', 'b'];
    return FutureBuilder<List<String>?>(
      future: _getContactsFuture(keys), // FALSE POSITIVE — rule fires here
      builder: (BuildContext context, AsyncSnapshot<List<String>?> snapshot) {
        return const SizedBox.shrink();
      },
    );
  }
}
```

**Frequency:** Always, whenever the `future:` argument is any `MethodInvocation` — the rule does not inspect what the invoked method does.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_getContactsFuture(...)` returns a cached field; calling it on every rebuild does NOT restart the async operation when inputs are unchanged. |
| **Actual** | `[pass_existing_future_to_future_builder] Creating new Future in FutureBuilder restarts the async operation on every widget rebuild.` reported on the `_getContactsFuture(keys)` `MethodInvocation`. |

---

## AST Context

```
MethodDeclaration (build)
  └─ Block
      └─ ReturnStatement
          └─ InstanceCreationExpression (FutureBuilder)
              └─ ArgumentList
                  └─ NamedExpression (future:)
                      └─ MethodInvocation (_getContactsFuture)   ← reported here
```

The rule's `runWithReporter` (line ~3449) accepts ANY `MethodInvocation` in the `future:` slot as a violation:

```dart
if (value is MethodInvocation) {
  reporter.atNode(value);
}
```

It does not check whether the method:
1. Is a private instance method on the enclosing State class.
2. Returns a cached field that is set conditionally inside the method body.
3. Is referenced from a `late final Future<T> _foo` initializer — itself indirected through a method.

---

## Root Cause

**Mechanism:** The rule treats `MethodInvocation` as a proxy for "expression that constructs a new Future on each evaluation." This is true for the common case (`fetchData()` at a free function or static method) but is false for cache-returning instance methods.

The rule has no awareness of the method's body. Two patterns the rule currently cannot distinguish:

| Pattern | Should the rule fire? |
|---|---|
| `future: DatabaseFooIO.dbLoad(uuid)` — top-level/static call, allocates a new Future every rebuild | Yes — real violation |
| `future: _getContactsFuture(uuids)` — private instance method that returns a cached `Future<T>?` field | No — already cached |

The rule fires on both because both are `MethodInvocation` nodes.

### Hypothesis A: heuristic-based opt-out

Suppress the warning when ALL of the following hold:
1. The `MethodInvocation` target is `null` (implicit `this`) — i.e., a method call on the enclosing class.
2. The method name starts with `_` (private) — i.e., the method lives in the same library.
3. The enclosing class has at least one field whose type is `Future<…>?` — i.e., a cache field exists.

The combination is a strong signal of the cache-method pattern. Risk: it could mask real violations where someone has a private method that just calls a network API directly. Acceptable trade-off — those callers should be inlining the call into `_init…()` anyway.

### Hypothesis B: walk the method body

Inspect the resolved declaration of the invoked method and check whether its body reads from a class field of type `Future<T>?`. More accurate but more expensive (requires `node.staticElement?.declaration` traversal across files).

---

## Suggested Fix

Implement Hypothesis A in `runWithReporter` at `lib/src/rules/widget/widget_lifecycle_rules.dart:3459`:

```dart
if (value is MethodInvocation) {
  // Skip if it's a private instance method on the enclosing class AND the
  // class has at least one Future<T>? field — strong signal of the
  // cache-method pattern (see bug:
  // pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field).
  if (_isCacheMethodCall(value)) continue;
  reporter.atNode(value);
}
```

Where `_isCacheMethodCall(MethodInvocation node)` returns true when:
- `node.target == null` (or `node.target is ThisExpression`)
- `node.methodName.name.startsWith('_')`
- The nearest enclosing class declaration has at least one `FieldDeclaration` whose `type` resolves to `Future<...>?` (nullable Future).

---

## Fixture Gap

The current fixture at `example/lib/widget_lifecycle/pass_existing_future_to_future_builder_fixture.dart` exercises only two cases:

1. BAD — inline top-level method call (`fetchData()`)
2. GOOD — `late final Future<Data> _dataFuture` cached field

Missing cases that should be added:

1. **GOOD — private state method returning a cached `Future<T>?` field, conditional on changing input.** Exact reproducer above. Expect: no lint.
2. **GOOD — getter on State that lazily initializes a `Future<T>?` and returns it.** Same pattern, different surface. Expect: no lint.
3. **BAD — private state method that always constructs a new Future (no cache field).** Expect: lint should still fire.
4. **EDGE — public method on State (no leading `_`) returning a cached field.** Decision: also no lint? Probably yes — the cache field is the load-bearing signal, not the underscore. Worth a fixture case to anchor the decision.

---

## Suggested Fix

See "Root Cause" → Hypothesis A above. Net change: a small `_isCacheMethodCall` helper in the rule and four new fixture cases.

---

## Changes Made

<!-- Empty until a fix lands upstream. -->

---

## Tests Added

<!-- Empty until a fix lands upstream. -->

---

## Commits

<!-- Empty until a fix lands upstream. -->

---

## Environment

- saropa_lints version: 13.11.1 (per `analysis_options.yaml` `plugins.saropa_lints.version`)
- Dart SDK version: (project pinned, see `pubspec.yaml`)
- custom_lint version: native analyzer plugin (saropa_lints uses `analysis_server_plugin`, not `custom_lint`)
- Triggering project: `d:/src/contacts` (Saropa Contacts)
- Triggering files (both share the cache-method pattern):
  - `lib/components/contact/contact_points_list_widget.dart:112` — `_getContactsFuture(contactSaropaUUIDs)`
  - `lib/components/contact/contact_suggestion_list.dart:141` — `_getSuggestedContactsFuture(contacts)`

---

## Downstream Workaround

Until the fix lands, both downstream sites carry a one-line `// ignore: pass_existing_future_to_future_builder` directive with a comment that references this bug file by name. The ignore is targeted (single line), explained at the call site, and removable once the rule learns to recognize the cache-method pattern.
