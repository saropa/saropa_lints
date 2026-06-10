# BUG: `prefer_correct_callback_field_name` — fires on non-callback function-typed fields/params (clock source, action thunk)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

## Resolution (2026-06-10)

Implemented suggestions (1) and (2) in `naming_style_rules.dart`
(`PreferCorrectCallbackFieldNameRule`, rule version bumped v5 → v6):

- **`_isEventCallbackType(typeStr)`** replaces the inline `isCallback` predicate in
  both the field branch and the constructor-parameter branch. It drops the bare
  `Function` / `void Function` / `=> void` substring triggers and `ValueGetter`
  (a value provider), keeping only genuine event-callback shapes: any type
  containing `Callback` (VoidCallback, GestureTapCallback, AsyncCallback, …),
  `ValueChanged`, or `ValueSetter`.
- **`_hasNonCallbackNameRole(name)`** exempts names that are/ end in
  `builder`, `validator`, `getter`, `setter`, `factory`, `provider`,
  `predicate`, `comparator`, `selector` even when the type is callback-shaped.

Suggestion (3) (configurable exemption list) was **not** implemented — it adds
config plumbing not needed for the reported false positives; left for a future
change if domain providers beyond the name-role list surface.

Verified with the scan CLI against a reproducer enabling only this rule: `now`
(`DateTime Function()?`), `start` (`void Function()`), `builder`, `validator`,
and `onTap` produce **no** diagnostic; `tapHandler` (`VoidCallback`) and
`changed` (`ValueChanged<int>`) still fire. Fixture updated with all seven cases.

Created: 2026-06-10
Rule: `prefer_correct_callback_field_name`
File: `lib/src/rules/core/naming_style_rules.dart` (line ~1344, ~1390)
Severity: False positive
Rule version: v5 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule treats **every function-typed** field or constructor parameter as an event
callback and demands an `on` prefix. But the `on` prefix convention in Dart/Flutter
denotes *event-handler* callbacks (invoked *when an event happens*) — not value
providers (`T Function()` clock/getter), builders, validators, or imperative action
thunks. Renaming these to `onX` would be semantically wrong.

Should not lint: `DateTime Function()? now` (an injectable clock source) or
`void Function() start` (an action thunk the owner calls to begin work).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_correct_callback_field_name'" lib/src/rules/
# lib/src/rules/core/naming_style_rules.dart:1327:    'prefer_correct_callback_field_name',
```

**Emitter registration:** `lib/src/rules/core/naming_style_rules.dart:1327`
**Rule class:** `PreferCorrectCallbackFieldNameRule` (`naming_style_rules.dart:1304`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#3`

---

## Reproducer

```dart
// Case 1 — clock-source provider as a constructor parameter.
class TokenBucketRateLimiter {
  TokenBucketRateLimiter({
    DateTime Function()? now, // LINT — but should NOT: `now` is a value provider
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now; // (private, correctly skipped)
}

// Case 2 — imperative action thunk as a public field.
class PendingTask {
  PendingTask(this.start);

  final void Function() start; // LINT — but should NOT: `start` is an action, not an event
}
```

Both come from `saropa_dart_utils`:
- `lib/async/rate_limiter_utils.dart:27` — `DateTime Function()? now`
- `lib/async/task_scheduler_utils.dart:105` — `final void Function() start`

**Frequency:** Always, for any function-typed member whose name is not `on`-prefixed.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `now`/`start` are not event callbacks; `on` prefix would be semantically wrong |
| **Actual** | `[prefer_correct_callback_field_name] Using onXxx naming for callback fields...` reported on `now` and `start` |

Flutter's own API has many function-typed members that intentionally carry **no**
`on` prefix and would be wrongly flagged by this rule: `builder`, `itemBuilder`,
`separatorBuilder`, `transitionBuilder` (`WidgetBuilder` etc.), `validator`
(`FormFieldValidator`), `selector`. The `on` prefix is reserved for event handlers
(`onTap`, `onChanged`, `onPressed`).

---

## AST Context

```
ConstructorDeclaration (TokenBucketRateLimiter)
  └─ FormalParameterList
      └─ DefaultFormalParameter
          └─ SimpleFormalParameter  (type: DateTime Function()?, name: now)  ← reported here

ClassDeclaration (PendingTask)
  └─ FieldDeclaration  (type: void Function())
      └─ VariableDeclaration (start)  ← reported here
```

---

## Root Cause

The `isCallback` predicate is a pure substring test on the type source
(`naming_style_rules.dart:1344-1353` for fields, `1389-1397` for params):

```dart
final String typeStr = typeAnnotation.toSource();
final bool isCallback =
    typeStr.contains('Function') ||   // ← matches ANY function type
    typeStr.contains('Callback') ||
    ...
    (typeStr.startsWith('void Function') || typeStr.contains('=> void'));
```

`typeStr.contains('Function')` is true for `DateTime Function()` and
`void Function()` — so any function-typed member is classified as a callback.
The rule then requires an `on` prefix. There is no distinction between:

- **Event callbacks** — invoked *by* the owner *when an event occurs* (`onTap`,
  `onChanged`). The `on` prefix is the convention here.
- **Value providers / getters** — `ValueGetter<T>`-shaped `T Function()` returning a
  non-void value (`DateTime Function()` clock source). The owner *calls it to get a
  value*; `onNow` is wrong.
- **Builders / validators** — `WidgetBuilder`, `FormFieldValidator`. No `on` prefix
  by Flutter convention.
- **Action thunks** — a `void Function()` the owner *calls to perform an action*
  (`start`). `onStart` implies "called when start happens", inverting the meaning.

A name-only lint cannot perfectly separate these, but the current "any `Function`
substring = callback" is far too broad.

---

## Suggested Fix

Tighten `isCallback` so it only fires on genuine event-callback shapes. Combine type
narrowing with a name-role exemption (apply to both the field branch at ~1344 and the
constructor-parameter branch at ~1389):

1. **Drop the bare `Function` / `void Function` substring triggers.** Keep the
   explicit callback typedef triggers (`VoidCallback`, `ValueChanged`, `ValueSetter`,
   `GestureTapCallback`, names ending in `Callback`). A raw `T Function()` is as
   likely a provider/builder/thunk as a callback, so it should not auto-classify.
   This alone exempts both reproducer cases (`DateTime Function()`, `void Function()`).

2. **Exempt non-callback name roles** even when the type is callback-shaped: names
   ending in/matching `builder`, `validator`, `getter`, `setter`, `factory`,
   `provider`, `predicate`, `comparator`, `selector`, or that are zero-arg value
   providers (`T Function()` with non-void return).

3. **Make the exemption list configurable** so teams can add domain providers
   (`now`, `clock`, `start`, `dispose`, …) without `// ignore:` noise.

Recommendation: ship (1) as the minimal correctness fix; (2) and (3) reduce future
false positives on builder/validator-style members.

---

## Fixture Gap

The fixture for this rule should include:

1. `final void Function() start;` — expect **NO** lint (action thunk)
2. `DateTime Function()? now` constructor param — expect **NO** lint (clock provider)
3. `final WidgetBuilder builder;` — expect **NO** lint (builder convention)
4. `final FormFieldValidator<String> validator;` — expect **NO** lint
5. `final VoidCallback onTap;` — expect **NO** lint (already correct)
6. `final VoidCallback tapHandler;` — expect **LINT** (true callback, wrong name)
7. `final ValueChanged<int> changed;` — expect **LINT** (true callback, wrong name)

---

## Environment

- saropa_lints version: 13.12.3 (consuming project); local repo 13.12.4
- Dart SDK version: 3.12.1 (stable)
- Triggering project/files: `saropa_dart_utils` —
  `lib/async/rate_limiter_utils.dart:27`, `lib/async/task_scheduler_utils.dart:105`

---

## Finish Report (2026-06-10)

**Scope:** (A) Dart lint rule. One rule modified, its fixture extended, CHANGELOG
+ this bug file updated.

**Change (core logic):** `PreferCorrectCallbackFieldNameRule` in
`lib/src/rules/core/naming_style_rules.dart` (rule version v5 → v6, message tag
`{v5}` → `{v6}`).

- Replaced the two inline `isCallback` predicates (field branch + constructor-
  parameter branch) with a single static `_isEventCallbackType(String)`. It drops
  the bare `Function` / `void Function` / `=> void` substring triggers and
  `ValueGetter` (a value provider), keeping only event-callback shapes: any type
  containing `Callback`, `ValueChanged`, or `ValueSetter`.
- Added static `_hasNonCallbackNameRole(String)` + a `_nonCallbackNameRoles` set
  (`builder`, `validator`, `getter`, `setter`, `factory`, `provider`,
  `predicate`, `comparator`, `selector`); names matching/ending in these are
  skipped in both branches even when the type is callback-shaped.

Suggestion (3) (user-configurable exemption list) deliberately not implemented —
adds config plumbing unneeded for the reported cases; deferred until a domain
provider outside the name-role list actually surfaces.

**Tests:** `test/rules/core/naming_style_rules_test.dart` (instantiation +
name-list pins) re-run — `+73 All tests passed`. No test pinned this rule's
message version (the `{v5}` assertion at line 275 belongs to
`PreferWildcardForUnusedParamRule`, unaffected). Behavior verified with the scan
CLI against a 7-case reproducer enabling only this rule: exactly 2 diagnostics —
`tapHandler` (`VoidCallback`) and `changed` (`ValueChanged<int>`); `now`
(`DateTime Function()?`), `start` (`void Function()`), `builder`, `validator`,
`onTap` produced none. Fixture
`example/lib/naming_style/prefer_correct_callback_field_name_fixture.dart`
extended with all seven cases.

**Files:** `lib/src/rules/core/naming_style_rules.dart`,
`example/lib/naming_style/prefer_correct_callback_field_name_fixture.dart`,
`CHANGELOG.md`, this bug file (archived to
`plans/history/2026.06/2026.06.10/`).

**Outstanding:** none for the reported false positives.
