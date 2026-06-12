# BUG: `pass_existing_future_to_future_builder` — Fires on Private Method Calls That Return a Cached Field

**Status: Fixed**

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

Implemented Hypothesis A in [lib/src/rules/widget/widget_lifecycle_rules.dart](../lib/src/rules/widget/widget_lifecycle_rules.dart) — added `_isCacheMethodCall(MethodInvocation)` helper to `PassExistingFutureToFutureBuilderRule`. The `MethodInvocation` branch in `runWithReporter` now skips reporting when all three conditions hold:

1. `node.target == null` or `node.target is ThisExpression` — implicit-`this` or explicit-`this` call on the enclosing class.
2. `node.methodName.name.startsWith('_')` — private to the library, so the project convention is locally inspectable.
3. The nearest enclosing `ClassDeclaration` has at least one `FieldDeclaration` whose `fields.type` is a `NamedType` named `Future` with `question != null` (nullable). The nullable signal is load-bearing — a `late final Future<T>` non-nullable field can only be assigned once and so cannot back the cache-method reassignment pattern.

Real violations (top-level call, public method with cache field, private method without cache field) continue to fire.

Updated [example/lib/widget_lifecycle/pass_existing_future_to_future_builder_fixture.dart](../example/lib/widget_lifecycle/pass_existing_future_to_future_builder_fixture.dart) with three new cases:

- GOOD — private method on `State` with `Future<List<String>?>?` field (canonical reproducer).
- BAD — private method on `State` with NO `Future<T>?` field (no cache; still fires).
- BAD — public method on `State` even with `Future<T>?` field (private marker is required).

Added a CHANGELOG entry under `[Unreleased] > Fixed` explaining the rule change and removing the need for the downstream `// ignore:` comments.

---

## Tests Added

[test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart](../test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart) — seven AST-level tests mirror the predicate against `parseString` snippets (same project pattern as `require_https_only_string_inspection_pattern_test.dart`):

1. Private method on class with `Future<T>?` field IS cache.
2. Explicit `this._x()` on class with `Future<T>?` field IS cache.
3. Private method on class with NO `Future<T>?` field is NOT cache (still fires).
4. PUBLIC method even with `Future<T>?` field is NOT cache (private marker required).
5. Top-level / free-function call is NOT cache (no enclosing class).
6. Non-nullable `Future<T>` field alone is NOT cache (nullable signal required).
7. Call on a different receiver (`helper.load()`) is NOT cache (target check enforced).

The existing instantiation test in `widget_lifecycle_rules_test.dart` continues to pass.

---

## Commits

Pending — single commit covering the rule change, fixture additions, behavior test, and CHANGELOG entry.

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

The fix has landed in this repo. The downstream `// ignore:` markers can be removed on the next `saropa_lints` upgrade — the rule now suppresses on the cache-method pattern automatically.

---

## Finish Report (2026-06-01)

### Scope

LINTER variant. (A) Dart lint rule + fixture + behavior test + CHANGELOG + bug archival. No (C) docs-only or script changes.

### Files changed

- `lib/src/rules/widget/widget_lifecycle_rules.dart` — added `_isCacheMethodCall` helper to `PassExistingFutureToFutureBuilderRule`; gated the `MethodInvocation` reporter on it.
- `example/lib/widget_lifecycle/pass_existing_future_to_future_builder_fixture.dart` — added three new cases: GOOD (`_CachedContactsWidgetState`), BAD (`_UncachedState`), BAD (`_PublicMethodCachedState`).
- `test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart` — new file. 7 AST-level tests mirror `_isCacheMethodCall` against `parseString` snippets (same pattern as `require_https_only_string_inspection_pattern_test.dart`).
- `CHANGELOG.md` — entry under `[Unreleased] > Fixed` (third bullet).
- `bugs/...md` → `plans/history/2026.06/2026.06.01/...md` (this file). Status flipped to `Fixed`; Changes Made, Tests Added, downstream-workaround note filled in.

### Core logic diff

The fix is a 3-condition AST predicate gating the existing `reporter.atNode(value)` call when `value is MethodInvocation`:

1. `node.target == null || node.target is ThisExpression` — implicit-/explicit-this call on the enclosing class. Excludes `helper.load()` style calls on other receivers.
2. `node.methodName.name.startsWith('_')` — private to library. The underscore is the load-bearing signal that the project's local convention applies; public methods could come from a superclass / mixin / external API and are not locally inspectable.
3. The nearest enclosing `ClassDeclaration` has at least one `FieldDeclaration` whose `fields.type is NamedType` named `Future` with `question != null` (nullable). Non-nullable `late final Future<T>` cannot back the reassignment pattern (single-assignment); the nullable signal is what tells us the cached value can be re-seated.

All three conditions short-circuit cheaply, so the linear field scan only runs on plausibly cached calls. No surface change to the rule (`code`, `problemMessage`, `correctionMessage`, severity, tier, impact, cost, applicableFileTypes all unchanged) — the fix is detection-only.

### Tests

**A. Existing tests audited:**

- `test/rules/widget/widget_lifecycle_rules_test.dart` references `PassExistingFutureToFutureBuilderRule` (instantiation pin: `code.lowerCaseName`, `problemMessage`, `correctionMessage`). No surface field was modified — verified by run. **72/72 pass.**
- No other test file references the rule, message, fixture path, or tier assignment.

**B. New tests:**

- `test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart` — 7 cases (private-with-cache, explicit-this, no-cache-field, public-method, top-level, non-nullable-field, different-receiver). **7/7 pass.**

**Combined run:** `dart test test/rules/widget/widget_lifecycle_rules_test.dart test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart` → 79/79 pass.

**Analyzer sweep:** `dart analyze lib/src/rules/widget/widget_lifecycle_rules.dart test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart` → No issues found.

### Project maintenance

- CHANGELOG updated (`[Unreleased] > Fixed`).
- README verified — no updates needed (rule count, doc count, headline pitch unchanged).
- pubspec / pubspec.lock — SKIPPED [C-NOT-IN-SCOPE]. No release or dependency change.
- doc/guides — guides reviewed (no user-facing surface change).
- ROADMAP — no entry for this rule (verified via grep); nothing to remove.
- **Bug archived:** `bugs/pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field.md` → `plans/history/2026.06/2026.06.01/pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field.md` (this file). Status flipped to `Fixed`. Inline bug references in `test/rules/widget/pass_existing_future_to_future_builder_cache_method_test.dart:7` repointed to the new archived path; the rule-file inline comment uses the slug only (no `bugs/` prefix) so it stays greppable across relocations.

### Persist Finish Report

**Finish report appended:** `plans/history/2026.06/2026.06.01/pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field.md` (this file).

### Outstanding

None for this task. The downstream `// ignore:` markers in `contacts` repo can be removed once the consuming project upgrades to a saropa_lints version including this commit.

### Scope notes

The working tree at commit time also contains unrelated in-progress work from other workstreams (`require_late_initialization_in_init_state` rule fix, `require_error_widget` rule fix, the corresponding bug archives). Those are NOT included in this commit — only the files for this fix are staged. The CHANGELOG file is committed as-is (it carries three Unreleased bullets — this fix plus the two from the other workstreams, which are documentation entries already added by those sessions); the implementation code behind the other two bullets stays uncommitted in the working tree for those sessions to land.
