# BUG: `prefer_correct_handler_name` — false positive on boolean state getter ending in a handler suffix (`bool get isClosed`)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `prefer_correct_handler_name`
File: `lib/src/rules/core/naming_style_rules.dart` (line ~1575)
Severity: False positive
Rule version: v3 | Since: — | Updated: —

---

## Summary

The rule flags any `MethodDeclaration` whose name ends with a handler suffix
(`Closed`, `Opened`, `Changed`, …) and does not start with `on`/`_on`/`handle`.
It does not exclude getters, so a boolean **state getter** such as
`bool get isClosed` is flagged and told to become `onIsClosed` / `onClosed`.
`isClosed` is a state query, not an event handler; renaming it would be wrong.
Expected: no diagnostic on getters (and on names already carrying a boolean
prefix like `is`/`has`).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_correct_handler_name'" lib/src/rules/
# lib/src/rules/core/naming_style_rules.dart:1575:    'prefer_correct_handler_name',
```

**Emitter registration:** `lib/src/rules/core/naming_style_rules.dart:1575`
**Rule class:** `PreferCorrectHandlerNameRule` — registered in `lib/saropa_lints.dart:476`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (custom_lint plugin `saropa_lints`)

---

## Reproducer

```dart
class Queue {
  bool _isClosed = false;

  // LINT (false positive): name ends with "Closed", so the rule asks to rename
  // it to onClosed/onIsClosed — but this is a boolean STATE getter, not an
  // event handler.
  bool get isClosed => _isClosed;

  // For contrast — a genuine handler that SHOULD lint:
  void itemDeleted() {} // LINT (correct): event handler should be onItemDeleted
}
```

**Frequency:** Always, for any method/getter whose name ends with one of
`_handlerSuffixes` (`Pressed`, `Clicked`, `Tapped`, `Changed`, `Submitted`,
`Selected`, `Dismissed`, `Closed`, `Opened`, `Completed`, `Started`, `Ended`,
`Updated`, `Deleted`, `Created`, `Saved`, `Loaded`, `Refreshed`) without an
`on`/`_on`/`handle` prefix — including boolean getters like `isClosed`,
`isOpened`, `hasChanged`, `isCompleted`, `isLoaded`.

Real-world hit (downstream `saropa_dart_utils`, on plugin 13.12.3):
- `lib/async/bounded_work_queue_utils.dart` — `bool get isClosed => _isClosed;`

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — a getter (especially an `is`/`has`-prefixed boolean) is a state query, not an event handler |
| **Actual** | `[prefer_correct_handler_name]` reported on `isClosed`, suggesting `onClosed` |

---

## AST Context

```
ClassDeclaration (Queue)
  └─ MethodDeclaration (isClosed)   ← isGetter == true
      └─ (no body params; expression getter)
                                    ← node.name reported here (false positive)
```

---

## Root Cause

`runWithReporter` registers `addMethodDeclaration` and matches the name's suffix
without excluding getters or boolean-prefixed names (line ~1608):

```dart
context.addMethodDeclaration((MethodDeclaration node) {
  final String name = node.name.lexeme;
  for (final String suffix in _handlerSuffixes) {
    if (name.endsWith(suffix)) {
      if (!name.startsWith('on') && !name.startsWith('_on')) {
        if (!name.startsWith('handle') && !name.startsWith('_handle')) {
          reporter.atToken(node.name, code);
        }
      }
      return;
    }
  }
});
```

`bool get isClosed` is a `MethodDeclaration` with `isGetter == true`; `isClosed`
ends with `Closed`, starts with neither `on`/`_on` nor `handle`/`_handle`, so it
is reported. The suffix set targets past-tense **events** (`dialogClosed`,
`itemDeleted`), but the same suffix appears inside adjective/state names after a
boolean prefix (`isClosed`, `isCompleted`, `isLoaded`), which are not handlers.

Sibling rules in this same file already guard getters with
`if (!node.isGetter) return;` (e.g. lines 57 and 2955). This rule omits that
guard.

### Hypothesis A: missing getter guard

A getter cannot be an event handler (it returns a value, takes no event). Adding
`if (node.isGetter) return;` resolves the reported case and matches the
file's existing convention.

### Hypothesis B: boolean-prefix names are state, not events

Even as a non-getter method, a name beginning with a boolean prefix
(`is`/`has`/`can`/`should`/`will`/`did`) reads as a state predicate; the trailing
`Closed`/`Loaded` is an adjective there, not a past-tense event.

---

## Suggested Fix

Add a getter guard at the top of the callback, and optionally skip
boolean-prefixed names:

```dart
context.addMethodDeclaration((MethodDeclaration node) {
  // A getter returns state; it is never an event handler. (Consistent with the
  // isGetter guards already used elsewhere in this file.)
  if (node.isGetter) return;

  final String name = node.name.lexeme;
  // `isClosed`, `hasChanged`, … are state predicates: the suffix is an
  // adjective after a boolean prefix, not a past-tense event.
  if (_hasBooleanPrefix(name)) return;
  // ...existing suffix matching...
});
```

where `_hasBooleanPrefix` checks `is`/`has`/`can`/`should`/`will`/`did` followed
by an uppercase letter. The getter guard alone fixes the reported `isClosed`
case; the boolean-prefix guard additionally covers boolean methods.

---

## Fixture Gap

The fixture at `example*/lib/.../prefer_correct_handler_name_fixture.dart`
should include:

1. **Boolean state getter ending in a suffix** — `bool get isClosed` — expect NO lint
2. **Boolean state getter** — `bool get hasChanged` — expect NO lint
3. **Genuine event handler method** — `void itemDeleted()` — expect LINT (regression guard)
4. **Already-prefixed handler** — `void onClosed()` — expect NO lint (already covered)

---

## Changes Made

`lib/src/rules/core/naming_style_rules.dart` — in `PreferCorrectHandlerNameRule.runWithReporter`:

1. **Getter guard** — `if (node.isGetter) return;` at the top of the
   `addMethodDeclaration` callback. A getter returns state and takes no event,
   so it can never be an event handler. Matches the `isGetter` guards already
   used elsewhere in this file.
2. **Boolean-prefix guard** — `if (_hasBooleanPrefix(name)) return;`. New static
   helper `_hasBooleanPrefix` (with `_booleanPrefixes` = `is`/`has`/`can`/
   `should`/`will`/`did`) skips names where a boolean predicate prefix is
   followed by an uppercase letter (`isClosed`, `hasChanged`, `isLoaded`). The
   trailing suffix is an adjective there, not a past-tense event.

This covers both the reported getter case and non-getter boolean predicate
methods. Genuine handlers (`itemDeleted`) still lint.

---

## Tests Added

`example/lib/naming_style/prefer_correct_handler_name_fixture.dart` — added:

- `_GoodStateClass489` — `bool get isClosed`, `bool get hasChanged`,
  `bool get isCompleted` (getter + boolean prefix) — expect NO lint
- `_GoodPredicateClass489` — `bool isLoaded()` (non-getter boolean predicate) —
  expect NO lint
- `_BadHandlerClass489` — `void itemDeleted()` — `expect_lint` regression guard

Verified with the scan CLI against a repro project: only `itemDeleted` (the
genuine handler) is flagged; `isClosed`, `hasChanged`, `isLoaded`, and the
already-prefixed `onClosed` are all clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.3 (triggering project) / reproduced in 13.12.4 source (rule unchanged, {v3})
- Dart SDK version: bundled with Flutter (project `saropa_dart_utils`)
- custom_lint version: per `saropa_dart_utils` lockfile
- Triggering project/file: `saropa_dart_utils` — `lib/async/bounded_work_queue_utils.dart`

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rule — `PreferCorrectHandlerNameRule` detection narrowing + fixture; docs.

### Root cause
The `addMethodDeclaration` callback matched any method whose name ended in a
past-tense handler suffix (`Closed`, `Changed`, `Loaded`, …) without an
`on`/`handle` prefix. It never excluded getters or boolean-predicate names, so
the state query `bool get isClosed` was flagged and told to become `onClosed`.

### Fix
`lib/src/rules/core/naming_style_rules.dart` — `runWithReporter`:
1. `if (node.isGetter) return;` — a getter returns state, never handles an event
   (matches `isGetter` guards already used elsewhere in this file).
2. `if (_hasBooleanPrefix(name)) return;` — new static helper + `_booleanPrefixes`
   (`is`/`has`/`can`/`should`/`will`/`did`). Skips names where a boolean prefix is
   followed by an uppercase letter (`isClosed`, `hasChanged`, `isLoaded`), where
   the suffix is an adjective, not a past-tense event. The uppercase check
   (`name[i] == name[i].toUpperCase() && name[i] != name[i].toLowerCase()`)
   distinguishes a real word boundary from lowercase continuations, so `island`
   (`is` + lowercase `land`) is NOT skipped.

Genuine handlers (`itemDeleted`) still lint.

### Tests
- `example/lib/naming_style/prefer_correct_handler_name_fixture.dart` — added
  `_GoodStateClass489` (getters `isClosed`/`hasChanged`/`isCompleted`, no lint),
  `_GoodPredicateClass489` (`bool isLoaded()`, no lint), `_BadHandlerClass489`
  (`void itemDeleted()`, `expect_lint` regression guard).
- `dart test test/rules/core/naming_style_rules_test.dart` → 73 passed.
- Behavioral verification via scan CLI against a repro project: only
  `itemDeleted` flagged; `isClosed`, `hasChanged`, `isLoaded`, `onClosed` clean.
- `dart analyze` on the rule file → no issues. `dart format` → no changes.

### Docs
- CHANGELOG `### Fixed` entry under `[13.12.5]`.
- ROADMAP unaffected (rule pre-exists, behavior narrowed only).
