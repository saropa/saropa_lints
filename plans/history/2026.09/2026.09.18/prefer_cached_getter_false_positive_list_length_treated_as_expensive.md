# BUG: `prefer_cached_getter` — Flags Repeated `List.length` Reads as an Expensive Getter to Cache

**Status: Open**

Created: 2026-09-18
Rule: `prefer_cached_getter`
File: `lib/src/rules/core/performance_rules.dart` (line ~679)
Severity: False positive
Rule version: v5 | Since: v0.1.4 | Updated: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

The rule flags `rowValues.length`/`headers.length` (`List<String>.length`) read at multiple textual sites within one method body as "repeated getter calls" that should be cached in a local. `List.length` is a synchronous `O(1)` field read guaranteed by the SDK contract, not a computed/expensive getter — caching it buys nothing and adds a variable that can silently go stale if the list is mutated between reads.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_cached_getter'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:679:    'prefer_cached_getter',

$ grep -rn "'prefer_cached_getter'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches, confirms the rule is not defined downstream)
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:679` (barrel-exported at `lib/src/rules/all_rules.dart:48`)
**Rule class:** `PreferCachedGetterRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
class Importer {
  void importRow(List<String> rowValues, List<String> headers) {
    if (rowValues.length >= headers.length) {           // OK — should NOT lint
      // ...
    } else {
      final colCount = rowValues.length;   // LINT — but should NOT lint (false positive)
      final headerCount = headers.length;  // (headers.length read a 2nd time)
      print('$colCount vs $headerCount');
    }
  }
}
```

Reduced from `lib/src/drift_debug_import.dart:434,436,446` in `saropa_drift_advisor` (`_importCsv`): `rowValues.length` is read 3 times and `headers.length` 2 times across the method body (once in the `if` condition, again inside the `else` branch and inside a `.map()` closure). None of these reads are separated by any mutation of `rowValues`/`headers` — the list is only ever read in this method.

**Frequency:** Always — fires on every method where a `List`/`String`/`Set`/`Map` `.length` (or similarly cheap SDK getter) is read from the same receiver expression 2+ times.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `List.length` is a free field read, not a getter worth caching |
| **Actual** | `[prefer_cached_getter] Repeated getter calls recompute expensive values each time, wasting CPU cycles when caching would suffice.` reported at `headers.length` (2nd occurrence) |

---

## AST Context

```
MethodDeclaration (_importCsv)
  └─ BlockFunctionBody
      └─ ForStatement
          └─ Block
              └─ IfStatement
                  ├─ condition: BinaryExpression
                  │     ├─ PropertyAccess (rowValues.length)  ← 1st occurrence, not reported
                  │     └─ PropertyAccess (headers.length)    ← 1st occurrence, not reported
                  └─ elseStatement: Block
                        └─ VariableDeclarationStatement (headerCount)
                              └─ PropertyAccess (headers.length)  ← reported here (2nd occurrence)
```

---

## Root Cause

`PreferCachedGetterRule.runWithReporter` (`performance_rules.dart:697-724`) walks every `MethodDeclaration` body with `_GetterCallCollector` (`performance_rules.dart:729-763`), which visits `PrefixedIdentifier`/`PropertyAccess` nodes and groups them by `node.toSource()` text. The **only** filter applied per access is `_isDeclaredGetter` (`performance_rules.dart:756-762`):

```dart
static bool _isDeclaredGetter(Element? element) {
  return element is GetterElement && element.isOriginDeclaration;
}
```

This distinguishes an explicitly-declared `get` accessor from a field's *synthetic* getter — but `List.length` **is** an explicitly-declared `get` accessor in `dart:core`'s `List`/`Iterable` interface (`int get length;`), not a synthetic field accessor, so it passes `_isDeclaredGetter` and is tracked exactly like a user-defined expensive computed getter. Once tracked, any getter-source text appearing 2+ times in the method body is flagged (`performance_rules.dart:715-722`), regardless of what the getter actually does:

```dart
for (final MapEntry<String, List<AstNode>> entry in getterCalls.entries) {
  if (entry.value.length > 1) {
    final String getterSource = entry.key;
    if (_isSingleSubscriptionStream(getterSource)) {   // only Isar-stream carve-out
      continue;
    }
    reporter.atNode(entry.value[1], code);
  }
}
```

The **only** existing carve-out is `_isSingleSubscriptionStream` (`performance_rules.dart:725-730`), a name-based heuristic (`getterSource.toLowerCase().contains('isar') && contains('stream')`) for Isar single-subscription streams. There is no notion anywhere in this rule of a "cheap"/`O(1)` SDK getter (`length`, `isEmpty`, `isNotEmpty`, `first`, `last`, `hashCode`, etc. on `dart:core` `List`/`String`/`Set`/`Map`) that should never be flagged. The rule's own dartdoc example (`widget.expensiveCalculation`) implies the intended target is a *computed* value, but the implementation has no check for cost — it treats every declared getter identically.

---

## Suggested Fix

In `_GetterCallCollector` (or `PreferCachedGetterRule.runWithReporter`), before tracking an access, resolve the getter's enclosing class/interface and skip when it is a known-`O(1)` `dart:core` accessor:

```dart
static const Set<String> _knownCheapGetterNames = {
  'length', 'isEmpty', 'isNotEmpty', 'first', 'last', 'hashCode',
};

static bool _isKnownCheapGetter(Element? element) {
  if (element is! GetterElement) return false;
  final enclosing = element.enclosingElement;
  final String? libraryUri = enclosing?.library?.uri.toString();
  return libraryUri == 'dart:core' &&
      _knownCheapGetterNames.contains(element.name);
}
```

and add `if (_isKnownCheapGetter(element)) return;` alongside the existing `_isDeclaredGetter` check in both `visitPrefixedIdentifier` and `visitPropertyAccess` (`performance_rules.dart:743-754`).

---

## Fixture Gap

Fixture: `example/lib/performance/prefer_cached_getter_fixture.dart` (confirmed to exist).

Missing NO-LINT cases:
1. **`list.length` read 2+ times in one method** — expect NO lint (this report's exact reproducer).
2. **`string.length`, `set.length`, `map.length` read 2+ times** — expect NO lint (same `dart:core` `O(1)` contract).
3. **`list.isEmpty`/`list.first` read 2+ times** — expect NO lint.
4. Retain existing coverage for a genuinely expensive **user-defined** getter (e.g. `widget.expensiveCalculation`) still flagging correctly, to guard against over-correcting the fix into a blanket carve-out.

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

## Finish Report (2026-09-18)

**Verdict:** Report confirmed valid. `PreferCachedGetterRule` tracked every
explicitly-declared `get` accessor read 2+ times in a method body, with no
notion of "expensive". `dart:core`'s `List`/`String`/`Set`/`Map` accessors
like `length`, `isEmpty`, `isNotEmpty`, `first`, `last`, and `hashCode` are
explicitly-declared (non-synthetic) getters in the SDK interface, so they
passed the rule's only filter (`_isDeclaredGetter`) and were flagged exactly
like a genuinely expensive user-defined getter.

**Root cause:** `_GetterCallCollector` in
`lib/src/rules/core/performance_rules.dart` (`visitPrefixedIdentifier` /
`visitPropertyAccess`) had no cost model — any declared getter, cheap or
not, was tracked once seen twice.

**Fix:** Added `_isKnownCheapGetter(Element?)`, which resolves the getter's
enclosing library and skips tracking when the getter name is one of a fixed
`dart:core` O(1) accessor set (`length`, `isEmpty`, `isNotEmpty`, `first`,
`last`, `hashCode`) *and* the element's library URI is `dart:core`. The
library-URI scoping (not a name-only heuristic) means a user-defined getter
that happens to be named e.g. `length` is still tracked — only the SDK's own
known-cheap accessors are exempted. Applied the same check in both
`visitPrefixedIdentifier` and `visitPropertyAccess`, alongside the existing
`_isDeclaredGetter` check.

**Tests added** (`test/rules/core/performance_fp_test.dart`,
`group('prefer_cached_getter')`):
- `does NOT flag List.length read twice (dart:core O(1) getter)` — the
  report's exact reproducer.
- `does NOT flag String/Set/Map .length read twice`.
- `does NOT flag List.isEmpty/first read twice`.
- Existing `STILL flags a real declared getter read twice` test (unchanged)
  continues to guard against over-correcting into a blanket carve-out.

**Fixture added** (`example/lib/performance/prefer_cached_getter_fixture.dart`):
`_goodListLength`, `_goodOtherLengths`, `_goodIsEmptyAndFirst` — NO-LINT
cases mirroring the above.

**Verification:** `dart analyze` on the three touched files reports "No
issues found!". `dart format` applied to the touched files. A full
`dart test test/rules/core/performance_fp_test.dart` run was blocked in this
session by unrelated, concurrently-edited files elsewhere in the shared
working tree (`lib/src/rules/platforms/windows_rules.dart`,
`lib/src/rules/code_quality/code_quality_avoid_rules.dart`) being mid-edit
by other agents and failing to compile — this is an environmental/tree-state
issue, not caused by this fix, since the test harness transitively compiles
the whole `saropa_lints` library. Re-run
`dart test test/rules/core/performance_fp_test.dart` once those files are
back to a clean state to confirm the new tests pass.

---

## Follow-up fix (2026-09-18, same day): false negative in the original fix

**Gap found on review:** the first fix's `_isKnownCheapGetter(Element?)`
exempted a getter purely by name + declaring library == `dart:core`. But
`length`/`isEmpty`/`isNotEmpty`/`first`/`last` are declared on `Iterable`
(and `dart:_internal`'s `EfficientLengthIterable`) in `dart:core`, not only
on `List`/`String`/`Set`/`Map`. A **lazy** `Iterable<T>` — e.g. the result of
`list.where(...)` — resolves `.length`/`.first`/etc. to that same `dart:core`
declaration, so the name+library check wrongly exempted it too, even though
reading `.length` on a lazy `Iterable` re-walks the whole chain each time
(genuinely O(n)). This was a **new false negative** introduced by the first
fix (previously these lazy-Iterable repeats were correctly flagged).

**Root cause detail:** `List`/`Set` do not always redeclare `length`/`first`/
`last`/`isEmpty` themselves — `List` declares its own `length`, but
`first`/`last`/`isEmpty`/`isNotEmpty` for both `List` and `Set` are inherited
from `Iterable`'s default (O(n)) implementation at the *static interface*
level (concrete runtime collections override them for O(1), but the
statically-resolved `Element` for the property access is `Iterable`'s
declaration either way, so it is indistinguishable from a lazy Iterable's
same read purely by declaring-element).

**Fix:** changed the check from "declaring class/library of the getter
`Element`" to **the receiver's static type**, using the analyzer's
`DartType.isDartCoreList` / `.isDartCoreString` / `.isDartCoreSet` /
`.isDartCoreMap` extension getters (the same idiom already used elsewhere in
this codebase, e.g. `lib/src/rules/core/state_management_rules.dart:1605-1607`).
`_isKnownCheapGetter` now takes the receiver `Expression?` (`node.prefix` for
`PrefixedIdentifier`, `node.realTarget` for `PropertyAccess`) and only
exempts `length`/`isEmpty`/`isNotEmpty`/`first`/`last` when the receiver's
static type is concretely `List`/`String`/`Set`/`Map` — never when it's a
plain `Iterable` (lazy or otherwise), regardless of which interface the
resolved getter element itself belongs to.

`hashCode` is handled separately and was kept: it's declared on `Object`
(identity hash — genuinely O(1) and never lazy), and the check requires the
resolved element's enclosing class to be `Object` itself in `dart:core`. If
a class **overrides** `hashCode` with an expensive computation, that read
resolves to the subclass's own `GetterElement`, not `Object`'s, so it is
untouched by this exemption and stays tracked/flagged as before — no new gap
there.

**Test added** (`test/rules/core/performance_fp_test.dart`,
`group('prefer_cached_getter')`): `STILL flags a lazy Iterable .length read
twice (genuinely O(n))` — `values.where((x) => x > 0)` assigned to `it`,
then `it.length` read twice inside a class method; asserts the rule still
fires. Also strengthened the two prior NOT-flagged tests
(`String/Set/Map .length`, `List.isEmpty/first`) by wrapping their bodies in
a class method instead of a top-level function — the rule only visits
`MethodDeclaration` (`context.addMethodDeclaration`), so a top-level
function is never inspected at all and those tests would have passed
trivially regardless of correctness; they now genuinely exercise the fix.

**Test results:** `dart analyze` on
`lib/src/rules/core/performance_rules.dart`,
`test/rules/core/performance_fp_test.dart`, and
`example/lib/performance/prefer_cached_getter_fixture.dart` — "No issues
found!". `dart test test/rules/core/performance_fp_test.dart` run in the
foreground (tree now compiles): **all 10 tests pass**, including the new
lazy-Iterable regression test and the two strengthened List/String/Set/Map
tests.

## Environment

- saropa_lints version: 16.2.1 (resolved; checkout at 16.3.0/HEAD, rule source unchanged)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings came from the `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/drift_debug_import.dart:434,436,446`, scan report `reports/20260918/20260918_081229_findings.json`
