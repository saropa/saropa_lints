# BUG: `prefer_utc_for_storage` — flags `.toIso8601String()` in `toJson()` even when the receiver field is provably UTC-only at its single construction site

**Status: Open**

Created: 2026-09-18

Rule: `prefer_utc_for_storage`
File: `lib/src/rules/core/async_rules.dart` (line ~2107)
Severity: False positive
Rule version: v4 | Since: v2.0.0 | Updated: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

`prefer_utc_for_storage` reports on `at.toIso8601String()` / `createdAt.toIso8601String()` calls inside `toJson()` methods, even though every field of this shape is populated exclusively from `DateTime.now().toUtc()` at its one and only construction site elsewhere in the file. The rule's "already UTC" guard (`async_rules.dart:2107-2110`) only inspects the immediate receiver expression's own source text for a literal `.toUtc()`/`.utc` — it cannot see that the value was normalized to UTC upstream, at construction, rather than at the point of serialization.

**Correction to the originating downstream report:** the downstream `saropa_drift_advisor` draft (`bugs/BUG_PREFER_UTC_FOR_STORAGE_FALSE_POSITIVE_FLAGS_FIELD_DECLARATION_NOT_ASSIGNMENT.md`) claimed the rule reports on the **field declaration** (`final DateTime at;`) and is therefore unfixable at the reported location. That claim is incorrect. `PreferUtcForStorageRule.runWithReporter` (`async_rules.dart:2089-2135`) registers only `addMethodInvocation` and calls `reporter.atNode(node)` where `node` is the `toIso8601String()`/`millisecondsSinceEpoch`/`microsecondsSinceEpoch` **method invocation** — never a field/variable declaration. Cross-checking the scan report's line numbers against the actual downstream source (`cat -n`) confirms all four reported lines are the `.toIso8601String()` call inside the class's `toJson()`, not the field declaration a few lines above it:

- `host_statement_capture.dart:38` → `ServerConstants.jsonKeyAt: at.toIso8601String(),` (field decl `final DateTime at;` is actually line 33)
- `server_types.dart:35` → `ServerConstants.jsonKeyCreatedAt: createdAt.toIso8601String(),`
- `server_types.dart:298` → `'at': at.toIso8601String(),`
- `table_activity_tracker.dart:44` → `ServerConstants.jsonKeyAt: at.toIso8601String(),` (field decl is line 34)

So the reported node *does* carry a fixable expression (the quick fix, `AddToUtcFix`, can insert `.toUtc()` right there) — the "unfixable at the reported location" claim does not hold. The real defect is different: the rule cannot tell that inserting `.toUtc()` there would be redundant, because every one of these fields is already UTC by construction.

---

## Attribution Evidence

```bash
cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'prefer_utc_for_storage'" lib/src/rules/
# lib/src/rules/core/async_rules.dart:2043:    'prefer_utc_for_storage',

grep -rn "'prefer_utc_for_storage'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

**Emitter registration:** `lib/src/rules/all_rules.dart:42` (`export 'core/async_rules.dart';`)
**Rule class:** `PreferUtcForStorageRule` — defined in `lib/src/rules/core/async_rules.dart:2015`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Reduced from `lib/src/server/host_statement_capture.dart` in `saropa_drift_advisor` (a field that is *always* constructed via `.toUtc()`, then serialized elsewhere):

```dart
class HostStatement {
  const HostStatement({required this.at});

  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
    // LINT (false positive) — `at` is provably UTC; see the only ctor call site below.
    'at': at.toIso8601String(),
  };
}

HostStatement makeEntry() => HostStatement(at: DateTime.now().toUtc());
```

**Frequency:** Always, for any `DateTime`-typed field whose UTC normalization happens at a constructor-argument call site rather than textually inside the flagged expression.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `at` is provably UTC at every construction site, so serializing it with `.toIso8601String()` is safe. |
| **Actual** | `[prefer_utc_for_storage] Local time stored without UTC conversion causes incorrect values when restored in different timezones. {v4}` reported at the `.toIso8601String()` call inside `toJson()`. |

---

## AST Context

```
ClassDeclaration (HostStatement)
  └─ MethodDeclaration (toJson)
      └─ ExpressionFunctionBody
          └─ SetOrMapLiteral ({...})
              └─ MapLiteralEntry ('at': at.toIso8601String())
                  └─ MethodInvocation (at.toIso8601String())  ← node reported here (reporter.atNode(node))
                      └─ SimpleIdentifier (at)  ← node.target; target.toSource() == "at", no '.toUtc()'/'.utc' text
```

---

## Root Cause

`async_rules.dart:2106-2110`:

```dart
// Check if already UTC (regex to avoid FP on substrings)
final String targetSource = target.toSource();
if (RegExp(r'\.toUtc\s*\(\s*\)').hasMatch(targetSource) ||
    RegExp(r'\.utc\b').hasMatch(targetSource)) {
  return;
}
```

This check only looks at the **local syntax of the receiver expression at the call site** (`target.toSource()`), which for a bare field access like `at` or `createdAt` is just the identifier name — never containing `.toUtc()` or `.utc`, regardless of whether the value was normalized to UTC at construction time. The rule has no cross-declaration dataflow: it does not resolve the field to its constructor parameter, walk to the field's construction call sites, and check the argument expressions there.

The rule's own fixture already documents the intended "no lint" shape for this exact pattern — a variable assigned `DateTime.now().toUtc()` once, then serialized later without re-calling `.toUtc()` at the call site — at `example/lib/async/prefer_utc_for_storage_fixture.dart:85-87`:

```dart
// Already UTC DateTime
final utcNow = DateTime.now().toUtc();
await db.insert({'timestamp': utcNow.toIso8601String()});
```

This case is marked as "GOOD" (no `// expect_lint` comment), but by the same code path traced above, `target.toSource()` for `utcNow.toIso8601String()` is the bare identifier `"utcNow"` — `RegExp(r'\.utc\b')` requires a literal `.` immediately before `utc`, which `"utcNow"` does not contain (no dot at all), and `RegExp(r'\.toUtc\s*\(\s*\)')` obviously doesn't match a bare identifier either. So, per the current implementation, this fixture's own "GOOD" case would actually be flagged too — I could not find an automated test (`test/rules/core/async_rules_test.dart`, `test/rules/core/async_remaining_fp_test.dart`) that exercises this specific case to confirm whether it currently passes or is a latent, uncaught regression; `async_remaining_fp_test.dart:86-124` covers a different, already-fixed false positive (enclosing-scope storage-pattern scan) for this same rule, not this one. This is a hypothesis anchored to real lines, not a confirmed second bug — but it is strong corroborating evidence that the rule authors already intended "receiver was UTC-ified upstream" to suppress the lint, and the current local-syntax-only check does not achieve that intent even for the in-repo fixture's own named variable, let alone an unrelated field name like `at`/`createdAt` with no "utc" in its name at all.

---

## Suggested Fix

Before reporting, in addition to the local `target.toSource()` check, resolve the target when it is a `SimpleIdentifier`/`PropertyAccess` referring to a field: look up the enclosing class's constructor parameter of the same name (if the field is constructor-promoted, as in `const HostStatement({required this.at})`), find its construction call sites within the same compilation unit, and check whether **every** call site's corresponding argument expression already contains `.toUtc()`/`.utc`. Only report when at least one construction site's argument lacks it. This mirrors the fixture's already-documented intent at `example/lib/async/prefer_utc_for_storage_fixture.dart:85-87` and would also need to correctly suppress that fixture case itself, which the current implementation does not.

As a smaller, lower-risk interim fix: extend the "already UTC" check to also resolve the target's `staticElement` (when it's a `PropertyAccessorElement`/field) and check that field's declaration's `initializer` or (for constructor-promoted fields) whether the field is `final` with no local reassignment and is only ever set via constructor arguments containing `.toUtc()` — a narrower, single-hop version of the full fix above.

---

## Fixture Gap

`example/lib/async/prefer_utc_for_storage_fixture.dart` already has a "GOOD: Already UTC DateTime" case at lines 85-87 (`utcNow.toIso8601String()`), but:

1. **Missing:** a case where the UTC conversion happens at a **constructor-argument call site**, not on a local variable in the same function — i.e. a class with a `final DateTime` field set via `SomeClass(at: DateTime.now().toUtc())`, later serialized via `at.toIso8601String()` inside `toJson()`. This is the exact downstream shape and is structurally different from the existing `utcNow` case (no local dataflow to trace, only a cross-declaration one).
2. Should also verify (via `dart test test/rules/core/async_rules_test.dart test/rules/core/async_remaining_fp_test.dart`, not run here per the re-homing constraints) whether the existing `utcNow` "GOOD" case at lines 85-87 actually passes today, since the traced logic above suggests it may not.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Environment

- saropa_lints version: 16.2.1 (findings produced), 16.3.0 / HEAD (source reviewed; unchanged for this file between the two)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (scan via `saropa_lints scan` / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/host_statement_capture.dart:38`, `lib/src/server/server_types.dart:35,298`, `lib/src/server/table_activity_tracker.dart:44`. Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`.

---

## Finish Report (2026-09-18)

**Verdict: Partially fixed.** The report described two distinct false-positive shapes under one root cause; only one of them is actually fixable without whole-program analysis, and it's the one that's fixed. The report's own reproducer (a `final` field promoted via a constructor's `this.field` parameter, e.g. `HostStatement`) is **not** fixed and still lints — see "What's still open" below.

### History of this investigation (kept for context)

Three rounds happened before landing here:

1. **Round 1** added a resolved-element "upstream UTC" hop covering both a `final` local variable's initializer AND a `final` instance field promoted via `this.field`, verified by walking the same-file constructor call sites.
2. **Round 2** (post-review) tightened the field path after review found it silently suppressed real bugs reachable via a redirecting constructor (`: this(...)`), a subclass constructor (`super(...)`), a tear-off (`ClassName.new` used as a value), and any same-file UTC call site for a **public** class (which can be constructed from other files). The fix restricted suppression to library-private classes and added bail-outs for the other three paths.
3. **Round 3** (this round, post-second-review) found the round-2 tightening was *still* unsound: "private" means private to the *library*, not the *file*, and this rule only ever scans one file — a `part` file of the same library can still construct the class unseen; a `factory` redirecting constructor (`factory _H.local(...) = _H;`) was skipped entirely rather than traced or bailed on; and a mixin-application class alias (`class _S = _H with _M;`) inherits `_H`'s constructors without being visited by the subclass check. Each round's fix narrowed the hole but never closed it, and the report's own reproducer (`HostStatement`) is a **public** class, so even a fully sound private-class-only field path would never have fixed the reported case. Continuing to patch this path was assessed as a whack-a-mole exercise with no sound stopping point short of cross-file/cross-library construction analysis (tracking every constructor call, redirect, super-call, mixin alias and tear-off across the entire package, not just one file) — well beyond what a single-file AST-visitor lint rule should attempt. **The field-tracing path was removed entirely** rather than patched a third time.

### Root cause (unchanged across all rounds)

`PreferUtcForStorageRule.runWithReporter` (`lib/src/rules/core/async_rules.dart`) only performed a local-syntax check on the receiver's `toSource()`/AST shape at the call site. It has no dataflow to the receiver's declaration, so it can't see UTC normalization done further upstream — whether at a local variable's initializer (fixable, single-file, sound) or at a class field's construction site(s) (not soundly fixable without whole-program analysis).

### What's fixed

A `final` **local variable** (not a field) whose initializer is UTC is now correctly not flagged, even though the receiver at the call site is a bare identifier with no `.toUtc()`/`.utc` text of its own:
```dart
final utcNow = DateTime.now().toUtc();
await db.insert({'timestamp': utcNow.toIso8601String()}); // no longer flagged
```
This is sound because a `final` local's only possible value-setting point is its own declaration — no redirect, subclass, tear-off or cross-file path exists for a local variable the way it does for a class. It also now correctly resolves when the variable is read inside a nested closure (searches the whole compilation unit via `identifier.root`, not just the nearest enclosing `FunctionBody`).

Separately, the "already UTC" check (both the direct receiver-syntax check and the new upstream-resolution hop) is now structural instead of text/substring-based: it requires the **outermost** form of the candidate expression to be a bare `.toUtc()` call or a `DateTime.utc(...)` constructor. Previously a substring search for `.toUtc(`/`.utc` would have wrongly treated `DateTime.now().toUtc().toLocal()` as UTC; it's now correctly still flagged, at both the receiver site and the local-variable-initializer site.

### What's still open (report's own case, NOT fixed)

A `final` **field** promoted via a constructor parameter (`this.field`) is always flagged now, regardless of how "obviously UTC" its construction site looks in the same file — including the report's exact `HostStatement` reproducer. This is a deliberate regression from round 1/2's behavior, not an oversight: no same-file, single-pass analysis can soundly verify that every possible construction path is UTC, because a field can be set via a redirecting (possibly `factory`) constructor, a subclass constructor forwarding through `super(...)`, a mixin-application class alias, a tear-off invoked elsewhere, or (for any non-private class, which includes the report's own class) a construction site in another file or another `part` of the same library. Soundly fixing this would require cross-file/cross-library construction analysis that this single-file AST rule does not have the infrastructure for.

### Files changed (final state)

- `lib/src/rules/core/async_rules.dart`:
  - Kept: `_expressionIsUtc(Expression)` (structural outermost-form UTC check), `_localInitializerIsUtc` (local-variable-only upstream hop, whole-compilation-unit search via `identifier.root`), `_isUpstreamUtc` (now only dispatches to the local-variable case), `_FindMatchingDeclaration` (visitor used by the local-variable search), and running `_isUpstreamUtc` only after the storage-context match (not on every `toIso8601String()` call).
  - Removed entirely: `_fieldIsUpstreamUtc`, `_findConstructionCallSites`, `_UnverifiableConstructionVisitor`, `_FindConstructionCallSites`, the `_NullableElementAt` extension, and all field/redirect/subclass/tear-off/privacy logic that depended on them.
  - The direct receiver-syntax check (previously a `RegExp` substring match) now also calls `_expressionIsUtc(target)`.
- `example/lib/async/prefer_utc_for_storage_fixture.dart` — removed the field-specific suppression ("GOOD") cases and the elaborate redirect/subclass/tear-off/public/private cases from rounds 1–2 (they tested bail-out logic that no longer exists). Replaced with a single `HostStatement` class matching the report's exact reproducer shape, now carrying `// expect_lint: prefer_utc_for_storage` to document that it is intentionally still flagged.
- `test/rules/core/async_remaining_fp_test.dart` — replaced the field-suppression test and the round-2 defense-in-depth tests (public/redirect/subclass/tear-off) with: one test confirming the report's reproducer still fires (labeled "NOT fixed"), the `final` local-variable suppression test, a new closure-captured local-variable suppression test, the local-variable `.toUtc().toLocal()` true-positive test, and a new true-positive test for a chained `.toUtc().toLocal().toIso8601String()` receiver (exercising the structural fix applied to the direct receiver check itself).
- `CHANGELOG.md` — the `prefer_utc_for_storage` bullet under `## [16.4.0]` → `### Fixed` (newly added section) now describes only the `final`-local-variable fix, not the field case.

### Tests (final round, run in foreground)

- `dart analyze lib/src/rules/core/async_rules.dart test/rules/core/async_remaining_fp_test.dart test/rules/core/async_rules_test.dart` → No issues found.
- `dart analyze` on the fixture (`example/lib/async/prefer_utc_for_storage_fixture.dart`, run from `example/`) → No issues found.
- `dart test test/rules/core/async_remaining_fp_test.dart test/rules/core/async_rules_test.dart` → All tests passed (118 total; 7 in the `prefer_utc_for_storage` group: reproducer-still-fires, local-variable-suppressed, closure-captured-suppressed, local-variable-`.toUtc().toLocal()`-still-fires, receiver-`.toUtc().toLocal()`-still-fires, plus the two pre-existing storage-context tests).
- `dart format` run on the changed Dart files.
- One transient unrelated failure was observed and is noted for completeness, not as part of this rule's own verification: `dart test` initially failed to *load* (a compile error, not a test failure) because a different, concurrently-edited file (`lib/src/rules/security/security_network_input_rules.dart`, owned by another agent working in the same tree) was briefly in a non-compiling intermediate state. It was not touched by this work and resolved itself ~20 seconds later when that agent's edit completed; the test run above is the one taken after it resolved.

### CHANGELOG bullet

Committed by another session in commit `8c2e2818` (not on this branch's ancestry as of this writing, but not this task's to edit either way):
> `prefer_utc_for_storage` no longer flags `.toIso8601String()`/epoch calls on a `final` local variable whose initializer already converts to UTC (including when the variable is read inside a nested closure), even though the receiver's own source at the call site has no `.toUtc()`/`.utc` text. No action required.

No git operations performed at any point in this investigation. The working branch changed externally more than once mid-task by other concurrent processes/merges (observed values included `fix/ci-toggle-if-and-template-parity` and `main`, the latter after PR #343 merged); this task's own uncommitted edits were confirmed intact via `git status` before each resumption and were never affected.

---

## Finish Report Update (2026-09-18, round 4 — UTC-preserving arithmetic)

A fourth Opus review, run against the round-3 state above, found one new false positive introduced by round 3's structural `_expressionIsUtc` fix (item 2 in that round): requiring the OUTERMOST form to be a bare `.toUtc()` call or `DateTime.utc(...)` constructor is correct for ruling OUT `.toUtc().toLocal()`, but it also wrongly ruled out `.toUtc().add(Duration)` and `DateTime.utc(...).subtract(Duration)` — `.add`/`.subtract` on a `DateTime` preserve its UTC-ness (they don't change the offset), so the outermost-call requirement was too strict for these two specific methods. Confirmed by running both of the review's examples against the round-3 code and seeing them wrongly flagged.

**Fix (`lib/src/rules/core/async_rules.dart`, `_expressionIsUtc`):** added a third case — when the outermost node is a `MethodInvocation` named `add` or `subtract` with a `DateTime`-typed target, recurse into that target instead of returning `false`. Deliberately limited to exactly these two method names: `copyWith` was explicitly NOT added to the recursion list, since `DateTime.copyWith` accepts an `isUtc:` argument that can flip a value from UTC to local (or vice versa), so it is not unconditionally UTC-preserving the way `add`/`subtract` are. No other `DateTime` method was added either, per the review's explicit scope.

**Nit fix:** `_FindMatchingDeclaration`'s dartdoc claimed "Stops descending once found," which was never true — `_found` only guards against reporting a second match (which can't happen in practice, since elements are unique per declaration); the visitor still walks the rest of the compilation unit after a match. Fixed the doc to describe the actual behavior rather than changing the (harmless, if slightly wasteful) traversal.

**Files changed (this round):**
- `lib/src/rules/core/async_rules.dart` — `_expressionIsUtc` gained the `add`/`subtract` recursion case; `_FindMatchingDeclaration`'s dartdoc corrected.
- `test/rules/core/async_remaining_fp_test.dart` — added 4 tests to the `prefer_utc_for_storage` group: `.toUtc().add(Duration)` silent, `DateTime.utc(...).subtract(Duration)` silent, `.toUtc().add(...).toLocal()` still fires (recursion must stop at the first non-add/subtract call), and `.toUtc().copyWith(...)` still fires (copyWith is deliberately not in the recursion allowlist).
- This report — appended this section; heading of the previous section de-labeled from "final" since it wasn't.

**CHANGELOG.md:** not touched — the bullet for this rule was already committed by another session (commit `8c2e2818`) and the coordinator explicitly said not to edit it further.

**Tests (round 4, run in foreground):**
- `dart analyze lib/src/rules/core/async_rules.dart test/rules/core/async_remaining_fp_test.dart test/rules/core/async_rules_test.dart` → No issues found.
- `dart analyze` on the fixture (`example/lib/async/prefer_utc_for_storage_fixture.dart`, run from `example/`) → No issues found.
- `dart test test/rules/core/async_remaining_fp_test.dart test/rules/core/async_rules_test.dart` → All tests passed (122 total; 11 in the `prefer_utc_for_storage` group — the prior 7 plus the 4 new arithmetic-recursion tests).
- `dart format` run on the changed Dart files.

No git operations performed.

---

## Finish Report Update (2026-09-18, round 5 — display-string type check nit)

A final Opus check passed the rule ship-with-nits, flagging one remaining issue: `_expressionIsUtc`'s two `DateTime`-ness checks (the `DateTime.utc(...)` constructor check and the `add`/`subtract` recursion's target-type check) both used `type.getDisplayString().startsWith('DateTime')`, a prefix match that also matches an unrelated user type merely named e.g. `DateTimeBag`.

**Fix (`lib/src/rules/core/async_rules.dart`):** added a private helper `_isDartCoreDateTime(DartType? type)` that does a real semantic check — `type is InterfaceType && type.element.name == 'DateTime' && type.element.library.isDartCore` — and replaced both `getDisplayString().startsWith('DateTime')` call sites with it. `InterfaceType.element` resolves correctly through a `DateTime?` nullable type too (the nullability suffix doesn't affect `.element`), so nullable receivers still match. The unrelated receiver-type gate earlier in `runWithReporter` (`typeName.startsWith('DateTime')`, decides whether the rule processes the call invocation at all) was explicitly left alone, per the coordinator's scope.

**Test added:** `test/rules/core/async_remaining_fp_test.dart` — a `DateTimeBag` class with a same-named `.utc(...)` constructor and `.add(...)` method, used as `DateTimeBag.utc(2020).add('x').toIso8601String()` inside a storage call. Before this fix, both the `.utc()` check and the `add`-recursion's target check would have accepted `DateTimeBag` as if it were `DateTime` (its display string starts with "DateTime"), so the expression would have been wrongly treated as UTC and the lint wrongly suppressed. It now correctly still fires.

**CHANGELOG.md:** not touched, per explicit instruction.

**Tests (round 5, run in foreground):**
- `dart analyze lib/src/rules/core/async_rules.dart test/rules/core/async_remaining_fp_test.dart test/rules/core/async_rules_test.dart` → No issues found.
- `dart analyze` on the fixture (from `example/`) → No issues found.
- `dart test test/rules/core/async_remaining_fp_test.dart test/rules/core/async_rules_test.dart` → All tests passed (123 total; 12 in the `prefer_utc_for_storage` group — the prior 11 plus the new `DateTimeBag` look-alike test).
- `dart format` run on the two changed Dart files (no changes needed).

No git operations performed.
