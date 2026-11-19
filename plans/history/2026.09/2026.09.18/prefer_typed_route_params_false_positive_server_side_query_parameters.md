# BUG: `prefer_typed_route_params` — fires on `dart:io` `HttpRequest.uri.queryParameters` piped through an already-typed same-file helper, and its `parse` exclusion is too strict to recognize named wrapper methods

**Status: Open**

Created: 2026-09-18

Rule: `prefer_typed_route_params`
File: `lib/src/rules/ui/navigation_rules.dart` (line ~1413, exclusion at ~1421-1425)
Severity: False positive
Rule version: v3 | Since: v2.0.0 | Updated: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

`prefer_typed_route_params` reports on `request.uri.queryParameters[ServerConstants.queryParamLimit]` / `...queryParamOffset]` inside a raw `dart:io` `HttpServer` router (`lib/src/server/router.dart:665,668` in `saropa_drift_advisor`), even though each is passed straight into `ServerUtils.parseLimit`/`parseOffset` — same-file helpers that already `int.tryParse` the string and clamp it to a bounded range (`lib/src/server/server_utils.dart:135-153`). Two independent gaps compound here:

1. The rule matches route-parameter access purely by **property name** (`pathParameters`/`queryParameters`), with no check that the receiver is a Flutter/`go_router` `GoRouterState`/`Uri` in a navigation context — it fires identically on `dart:io`'s `HttpRequest.uri.queryParameters`, a plain `Map<String, String>` getter that has nothing to do with route navigation.
2. Even setting that aside, the rule's own "already parsed" exclusion only recognizes a call whose method name is the **literal word** `parse` (`RegExp(r'\bparse\b')`), so `parseLimit(...)`/`parseOffset(...)` — same-file helpers that internally call `int.tryParse` — are not recognized as parsing wrappers at all.

---

## Attribution Evidence

```bash
cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'prefer_typed_route_params'" lib/src/rules/
# lib/src/rules/ui/navigation_rules.dart:1388:    'prefer_typed_route_params',

grep -rn "'prefer_typed_route_params'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

**Emitter registration:** `lib/src/rules/all_rules.dart:113` (`export 'ui/navigation_rules.dart';`)
**Rule class:** `PreferTypedRouteParamsRule` — defined in `lib/src/rules/ui/navigation_rules.dart:1369`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Reduced from `lib/src/server/router.dart:663-669` and `lib/src/server/server_utils.dart:135-153` in `saropa_drift_advisor` (a `dart:io` `HttpServer` request router — no `go_router`/Flutter navigation involved at all):

```dart
import 'dart:io';

abstract final class ServerUtils {
  static int parseLimit(String? value) {
    if (value == null) return 100;
    final int? n = int.tryParse(value);
    if (n == null || n < 1) return 100;
    return n > 1000 ? 1000 : n;
  }
}

void handle(HttpRequest request) {
  final int limit = ServerUtils.parseLimit(
    // LINT (false positive) — this is dart:io's HttpRequest.uri.queryParameters,
    // not a Flutter/go_router route param, and it IS already piped through a
    // typed, clamping parse helper one line up.
    request.uri.queryParameters['limit'],
  );
}
```

**Frequency:** Always, for `.pathParameters[...]`/`.queryParameters[...]` on any receiver (regardless of static type) passed as a bare argument to any method whose name is not the literal word `parse`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — (a) this is server-side `dart:io` code, not Flutter route-parameter handling, and (b) the value is already parsed/clamped by `ServerUtils.parseLimit`. |
| **Actual** | `[prefer_typed_route_params] Route parameter from pathParameters or queryParameters is passed directly without type conversion... {v3}` reported at the `queryParameters[...]` index expression. |

---

## AST Context

```
MethodDeclaration (handle route dispatch)
  └─ Block
      └─ VariableDeclarationStatement (final int limit = ...)
          └─ VariableDeclaration (limit)
              └─ MethodInvocation (ServerUtils.parseLimit(...))
                  └─ ArgumentList
                      └─ IndexExpression (request.uri.queryParameters[...])  ← node reported here (reporter.atNode(node))
                          └─ PropertyAccess (request.uri.queryParameters)
                              propertyName.name == "queryParameters"  ← only this string is checked
```

---

## Root Cause

Two separate conditions in `PreferTypedRouteParamsRule.runWithReporter` (`navigation_rules.dart:1404-1436`):

**(1) No receiver-type check — `navigation_rules.dart:1264-1268` + `1413`:**

```dart
String _indexTargetPropertyOrName(Expression target) {
  if (target is PropertyAccess) return target.propertyName.name;
  if (target is SimpleIdentifier) return target.name;
  if (target is PrefixedIdentifier) return target.identifier.name;
  return '';
}
...
final String prop = _indexTargetPropertyOrName(target);
if (!_routeParamProps.contains(prop)) return;
```

`_routeParamProps` (`navigation_rules.dart:1395-1398`) is `{'pathParameters', 'queryParameters'}`. The rule declares `usesTypeResolution => true` but never calls `target.staticType` for this check — matching is purely on the syntactic property name, so `dart:io`'s `Uri.queryParameters` (a plain `Map<String, String>` getter, nothing to do with routing) is indistinguishable from `go_router`'s `GoRouterState.pathParameters`/`.uri.queryParameters`.

**(2) `parse` exclusion is a whole-word match, not a prefix match — `navigation_rules.dart:1399-1402` + `1421-1425`:**

```dart
static final RegExp _parseMethodPattern = RegExp(r'\bparse\b', caseSensitive: false);
...
if (grandparent is MethodInvocation) {
  final String methodName = grandparent.methodName.name;
  if (_parseMethodPattern.hasMatch(methodName)) {
    return;
  }
}
```

`\bparse\b` requires `parse` to be a standalone word — bounded by non-word characters on both sides. `parseLimit`/`parseOffset` are single unbroken identifiers (`p-a-r-s-e-L-i-m-i-t`), so there is no word boundary between `e` and `L`; the regex does not match, and the exclusion never fires for these (or any other) `parseXxx`-named wrapper methods, even though the rule's own doc comment's "GOOD" example (`navigation_rules.dart:1361-1367`) uses `int.tryParse(...)` — a different method entirely (`tryParse`, which also fails the same `\bparse\b` check for the same reason, though that specific case is presumably covered by a different code path not reached here since `tryParse` is what the *fix* suggests inserting, not what the exclusion is tested against).

**Is this really UI-navigation logic misapplied to server code?** Yes — `navigation_rules.dart`'s file-level intent (per its doc comments, e.g. the `GoRoute`/`state.pathParameters` example at `navigation_rules.dart:1350-1366`) is Flutter/`go_router` route parameters. The rule's detection condition (property-name-only match, `tags => {'flutter', 'ui'}` at `navigation_rules.dart:1379`) never verifies the surrounding code is a `go_router`/Flutter navigation context — it will fire in any file, including a pure-`dart:io` HTTP server with no Flutter/`go_router` dependency at all (confirmed: `saropa_drift_advisor`'s `pubspec.yaml` declares no Flutter or `go_router` dependency; see `dependencies:` block, line 32 — the debug server is deliberately dependency-free).

---

## Suggested Fix

1. Restrict `_routeParamProps` matching to targets whose static type (or the static type of the object the property is accessed on) resolves to a `go_router`/Flutter navigation type (`GoRouterState`, `RouteSettings`, or similar) rather than matching any receiver with a property literally named `pathParameters`/`queryParameters`. The rule already declares `usesTypeResolution => true`; use it here.
2. Loosen `_parseMethodPattern` from `RegExp(r'\bparse\b', caseSensitive: false)` to something that also matches parse-shaped wrapper method names, e.g. `RegExp(r'pars(e|ing)', caseSensitive: false)` (catches `parseLimit`, `parseOffset`, `tryParse`, `parseInt`, etc.), or recognize any grandparent `MethodInvocation` whose resolved body contains an `int.tryParse`/`double.tryParse`/`num.tryParse`/`bool.tryParse` call (heavier but precise).

---

## Fixture Gap

`example/lib/navigation/prefer_typed_route_params_fixture.dart` only exercises `state.pathParameters['id']` (a `GoRouterState`-shaped case) for both the BAD case (line ~117, `// expect_lint: prefer_typed_route_params`) and the GOOD case (`int.tryParse(state.pathParameters['id'] ?? '') ?? 0`, line ~128). Missing:

1. **Case:** `dart:io` `HttpRequest.uri.queryParameters[...]`/a plain `Uri.queryParameters[...]` access with no Flutter/`go_router` type in scope — expect **NO lint** (or, if the fix is receiver-type-gated, this becomes the primary regression case proving the gate works).
2. **Case:** a route/query param piped through a same-file helper method whose name is `parseXxx`/`xxxParse` (not the bare word `parse`) that internally does `int.tryParse` + clamp — expect **NO lint**.

---

## Changes Made

_Revision history: an initial fix loosened `_parseMethodPattern` to the
unanchored `RegExp(r'pars(e|ing)')`. A follow-up review (run, not just read)
confirmed that loosened pattern over-matched: `sparseView(...)` and
`openParserScreen(...)` contain "parse"/"Parse" as a run of letters
despite doing no parsing at all, so the rule went silent on those real
positives. The regex-only approach was replaced with the resolved-type
check described below; the final diff is what's summarized here._

_Second revision: a follow-up re-review (also run, not just read) caught that
including `bool` in the return-type check was itself an over-match — see the
"Finish Report" for the full explanation. `bool` was removed from the
generic return-type check; the dead `correspondingParameter` branch (numeric/
bool parameter types can never appear there — passing a `String`/`String?`
argument to a non-String/non-dynamic parameter doesn't compile) was removed
entirely; and `bool.parse`/`bool.tryParse` are now matched specifically by
their resolved dart:core `bool` receiver instead. The description below is
the final state._

`lib/src/rules/ui/navigation_rules.dart` (~1399-1500):

1. Replaced the name-only "already parsed" exclusion with
   `_isAlreadyConverted(IndexExpression argument, MethodInvocation call)`,
   which prefers resolved element/type checks:
   - OK (already converted) if the wrapping call's resolved **return type**
     (`call.staticType`) is one of the numeric "parsed" types (`int`/
     `double`/`num`, via `isDartCoreInt`/`isDartCoreDouble`/`isDartCoreNum`,
     checked in `_isParsedNumericType`) — covers `int.tryParse(...)`,
     `ServerUtils.parseLimit(...)`, `double.parse(...)`, regardless of the
     method's name.
   - OK if `_isBoolParseCall(call)` — the call is specifically
     `bool.parse(...)`/`bool.tryParse(...)` resolved against dart:core's
     `bool` class (checked via the target identifier's resolved `Element`
     being an `InterfaceElement` named `bool` in a `dart:core`-flagged
     library), not merely "returns bool". `bool` is deliberately excluded
     from the generic return-type check because bool-returning methods are
     commonly *sinks* that convert nothing (`Set.add`, `Set.contains`, a
     user-defined `bool save(String? id)`) — including it there silently
     swallowed those.
   - The `correspondingParameter` type check from the previous revision was
     removed: it can never fire, because passing a `String`/`String?`
     argument to a parameter whose resolved type is numeric/bool/non-dynamic
     and non-String would fail to compile, so real code never reaches it.
2. Only when the wrapping call's return type doesn't resolve to anything
   useful (`null`, `InvalidType`, or `DynamicType`) does the rule fall back
   to a **name** check — anchored (`_parseMethodPattern`) to match
   `parse`/`tryParse` only at the start of the identifier, or at the start
   of an UpperCase camelCase word, and never immediately followed by a
   lowercase letter. This still recognizes `parseLimit`/`tryParse` but no
   longer matches `sparseView` (lowercase `p`, not a new word) or
   `openParserScreen` (the `Parse` run is immediately followed by `r`, so
   it's rejected as mid-word). `DynamicType` is treated the same as
   unresolved: a `dynamic`-typed call site (e.g. a same-file helper invoked
   through an untyped variable) gives the return-type check nothing to go
   on either.

---

## Tests Added

`test/rules/ui/prefer_typed_route_params_fp_test.dart` (new): resolved-analyzer
regression tests via the oracle harness (`reportedRuleCodes`), 7 total.
- `does NOT flag a queryParameters value piped through a parseXxx wrapper` —
  reproduces the report's `dart:io` `HttpRequest.uri.queryParameters['limit']`
  piped through `ServerUtils.parseLimit(...)`; asserts no
  `prefer_typed_route_params` (via the resolved return-type check, not name).
- `still flags a route parameter passed directly with no parse wrapper` —
  a `void greet(Object? name)` sink with no conversion; guards against a
  false negative.
- `still flags a name that merely CONTAINS "parse" (sparseView)` — a
  `void sparseView(String? id)` sink; guards specifically against the
  over-match the unanchored regex introduced.
- `still flags a name that merely CONTAINS "Parser" (openParserScreen)` —
  same, for the `Parser`-substring case.
- `still flags a bool-returning Set.add sink` — `Set<String?>.add(...)`
  returns `bool`; guards against the bool-return-type over-match from the
  second review pass.
- `still flags a bool-returning Set.contains sink` — same, for `.contains`.
- `still flags a user-defined bool-returning wrapper (bool save(String?))` —
  same, for an arbitrary same-file bool-returning function.

`example/lib/navigation/prefer_typed_route_params_fixture.dart`: added
`_good512` (a `parseLimit`-named wrapper around a `queryParameters` index
expression — GOOD, no lint), `_bad513`/`_sparseView` (a name that merely
contains "parse" but does no conversion — BAD, still lints), and
`_bad514`/`_save514` (a `bool`-returning same-file wrapper that does no
conversion — BAD, still lints), alongside the existing GoRouter BAD/GOOD
cases.

Note: `bool.parse`/`bool.tryParse` is deliberately NOT special-cased in
`_isAlreadyConverted`. Both require a non-nullable `String` parameter, while
`Map<String, String>['key']` (which is what `queryParameters['id']` is) is
always `String?` under sound null safety, so calling
`bool.tryParse(request.uri.queryParameters['id'])` directly can never
type-check; it's only reachable via `!` or `?? ''`, both of which insert a
`PostfixExpression`/`BinaryExpression` between the `IndexExpression` and the
`ArgumentList` — a case the rule's `runWithReporter` already treats as "not
used directly" for unrelated, pre-existing structural reasons (its final
`parent is NamedExpression || parent is ArgumentList` gate), independent of
this fix. An earlier revision added a dedicated `_isBoolParseCall` resolved-
receiver check for this case, but since the rule's AST gate never actually
reaches it, it was untestable dead code and was removed (see "Fourth pass"
below).

Verified: `dart analyze` clean on all touched files (`navigation_rules.dart`,
the fixture, the new test file, and `navigation_rules_test.dart`);
`dart test test/rules/ui/prefer_typed_route_params_fp_test.dart` (7/7 passed)
and `dart test test/rules/ui/navigation_rules_test.dart` (80/80 passed).

---

## Commits

_Not committed by this agent — working-tree changes only, per task constraints._

---

## Environment

- saropa_lints version: 16.2.1 (findings produced), 16.3.0 / HEAD (source reviewed; unchanged for this file between the two)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (scan via `saropa_lints scan` / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/router.dart:665,668`. Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`.

---

## Finish Report (2026-09-18)

**Verdict: Partially valid.** The reported false positive (root cause #2, the
`\bparse\b` whole-word regex) is confirmed and fixed. Root cause #1
(no receiver-type gating on `pathParameters`/`queryParameters`) is real as
described but its suggested fix was **not** implemented — see rationale below.

**Root cause:** `PreferTypedRouteParamsRule`'s "already parsed" exclusion
(`navigation_rules.dart:1399-1402`, applied at `:1421-1425`) matched a
grandparent `MethodInvocation`'s method name against
`RegExp(r'\bparse\b', caseSensitive: false)`. `\bparse\b` requires `parse` to
be a standalone word bounded by non-word characters on both sides.
`parseLimit`/`parseOffset` are single unbroken identifiers with no such
boundary, so the regex never matched and the rule flagged an already-parsed,
already-clamped value passed through a same-file helper.

**Fix (revised after review):** The first pass at a fix loosened the pattern
to the unanchored `RegExp(r'pars(e|ing)', caseSensitive: false)`. A follow-up
review that actually ran the rule against adversarial names caught that this
over-matched: `sparseView(...)` and `openParserScreen(...)` both contain
"parse"/"Parse" as a run of letters (`sPARSEView`, `openPARSERScreen`)
despite performing no conversion at all — the loosened regex silently went
false-negative on those real positives.

The fix was redone to prefer a **resolved element/type check** over any
name-based heuristic, per the reviewer's guidance and this project's stated
preference for semantic checks:

- A wrapping call is now treated as "already converted" if its **resolved
  return type** (`MethodInvocation.staticType`) is one of `int`/`double`/
  `num`/`bool` (checked via `isDartCoreInt`/`isDartCoreDouble`/
  `isDartCoreNum`/`isDartCoreBool`) — this is true regardless of what the
  method is named, so `ServerUtils.parseLimit(...)`, `int.tryParse(...)`,
  and any other numeric/bool-returning wrapper are recognized correctly.
- Or if the **resolved parameter type** the argument binds to
  (`Expression.correspondingParameter?.type`) is already one of those types.
- The check is deliberately scoped to `int`/`double`/`num`/`bool` rather than
  "anything not String": a broader check would treat a `void`-returning sink
  whose parameter happens to be `Object`/`Object?` as "already converted",
  which is false — passing a raw `String` into an `Object?` parameter is not
  a type conversion, and such a sink should still be flagged.
- The regex is retained only as a **last-resort fallback** for when the
  call's return type doesn't resolve at all (`null`/`InvalidType`), and is
  now correctly anchored: it matches `parse`/`tryParse` only at the start of
  the identifier or the start of an UpperCase camelCase word, and requires a
  non-lowercase character (or end of string) immediately after the match —
  so it accepts `parseLimit`/`tryParse` but rejects `sparseView` (the `p` is
  lowercase and not at a word start) and `openParserScreen` (the `Parse` run
  is immediately followed by a lowercase `r`, i.e. it's part of a longer
  word, "Parser").

**Why root cause #1 (receiver-type gating) was not implemented:** The
report's suggested fix — restrict `_routeParamProps` matching to a resolved
`GoRouterState`/Flutter navigation receiver type — does not hold up under
scrutiny for the `queryParameters` half of the pair. go_router's own idiom
for query parameters is `state.uri.queryParameters`, which resolves through
`Uri.queryParameters` — the exact same dart:core API dart:io's
`HttpRequest.uri.queryParameters` resolves through. There is no sound
static-type distinction between "go_router's query parameters" and "any
other Uri's query parameters" at the `IndexExpression` site; both are
literally `Map<String, String> Function()` on `Uri`. Implementing an
allowlist keyed on the *outer* receiver (e.g. requiring `state` to be
`GoRouterState`) would (a) not generalize to `auto_route` or other routers
that don't use `GoRouterState` by name, reintroducing a name heuristic one
level up, and (b) still fire on legitimate dart:io/server code accessed via
a variable coincidentally named `state`. `pathParameters` (unique to
`GoRouterState`) could be type-gated safely, but doing that alone for half
of `_routeParamProps` while leaving `queryParameters` on the existing
name-only heuristic seemed like partial, inconsistent coverage not worth the
added surface for this fix; it was left out to keep the change minimal and
focused on the confirmed, reproducible false positive. This tradeoff is
called out explicitly here for a future pass if server-side `queryParameters`
false positives recur for cases that don't route through a parse-shaped
wrapper.

---

## Third pass (2026-09-18, same day): bool-return-type over-match

A second review (also run, not just read) found that `_isAlreadyConverted`'s
return-type check included `isDartCoreBool`, which was itself an over-match:
bool-returning methods are very commonly *sinks*, not converters —
`Set<String?>.add(...)`, `Set<String?>.contains(...)`, or any user-defined
`bool save(String? id)` all return `bool` without converting the string to
anything, so all three went silent under the second-pass logic even though
they were flagged before any of this work started.

**Fix:**
- Removed `isDartCoreBool` from the generic return-type check
  (`_isParsedNumericType` now checks only `int`/`double`/`num`).
- Added `_isBoolParseCall(MethodInvocation call)`, which recognizes
  `bool.parse(...)`/`bool.tryParse(...)` specifically — by checking that the
  call's target is an `Identifier` whose resolved `Element` is an
  `InterfaceElement` named `bool` belonging to a library where
  `library.isDartCore` is true — rather than by return type or name alone.
  This is a genuine string-to-bool conversion, unlike an arbitrary
  bool-returning sink.
- Removed the `correspondingParameter` parameter-type branch from the
  previous revision entirely: it was dead code. A `String`/`String?`
  argument can only type-check against a parameter whose resolved type is
  `String`, `String?`, `dynamic`, `Object`, or `Object?` — never `int`/
  `double`/`num`/`bool` — so the branch could never fire for real,
  compiling code.
- Also treats a `DynamicType` return type the same as unresolved
  (`InvalidType`/`null`) for the name-fallback: a call resolved to `dynamic`
  (e.g. invoked on an untyped/`dynamic` receiver) gives the return-type
  check nothing to reason about either, so it should degrade to the name
  heuristic rather than silently fall through to `false`
  ("not converted") only by accident of the `if` chain's shape.

**Tests added:** three true-positive regression tests
(`still flags a bool-returning Set.add sink`, `... Set.contains sink`,
`... user-defined bool-returning wrapper (bool save(String?))`) — see
"Tests Added" above. `ServerUtils.parseLimit(...)` (the original report's
case) was re-verified to stay silent, since it returns `int`, unaffected by
the `bool` removal.

**Files changed (this pass):**
- `lib/src/rules/ui/navigation_rules.dart` — removed `isDartCoreBool` from
  `_isParsedNumericType` (renamed from `_isParsedType`); added
  `_isBoolParseCall`; removed the dead `correspondingParameter` branch;
  treat `DynamicType` as unresolved in the name-fallback condition.
- `example/lib/navigation/prefer_typed_route_params_fixture.dart` — added
  `_bad514`/`_save514` (BAD: bool-returning same-file wrapper, still lints).
- `test/rules/ui/prefer_typed_route_params_fp_test.dart` — added the three
  bool-sink true-positive tests; updated the file-header comment to narrate
  both revisions.

**Tests (this pass):** `dart analyze` clean on
`lib/src/rules/ui/navigation_rules.dart`,
`example/lib/navigation/prefer_typed_route_params_fixture.dart`,
`test/rules/ui/prefer_typed_route_params_fp_test.dart`, and
`test/rules/ui/navigation_rules_test.dart`.
`dart test test/rules/ui/prefer_typed_route_params_fp_test.dart
test/rules/ui/navigation_rules_test.dart` — 87/87 passed (7 in the new
regression file + 80 fixture-verification tests). Run on branch
`fix/ci-toggle-if-and-template-parity`; no git operations performed.

---

## Fourth pass (2026-09-18, same day): removed untestable `_isBoolParseCall`

The third pass added `_isBoolParseCall` to recognize `bool.parse(...)`/
`bool.tryParse(...)` specifically via a resolved dart:core `bool` receiver
check. While reviewing test coverage for it, it became clear this method is
never actually reachable through `PreferTypedRouteParamsRule`'s AST gate:
`_isAlreadyConverted` (and therefore `_isBoolParseCall`) is only invoked when
an `IndexExpression`'s immediate parent is an `ArgumentList`
(`runWithReporter`'s `if (parent is ArgumentList) { ... }` branch). But
`bool.parse`/`bool.tryParse` require a non-nullable `String` argument, and
`queryParameters[...]`/`pathParameters[...]` is always `String?` — so
passing one directly to either can never type-check. The only way to reach
`bool.tryParse` from one of these index expressions is through a `!` or
`?? ''`, and both of those put a `PostfixExpression`/`BinaryExpression`
between the index expression and the `ArgumentList`, which fails the
`parent is ArgumentList` check before `_isAlreadyConverted` is ever called.
`_isBoolParseCall` was therefore dead code with no way to write a real
passing/failing test for it — code that can't run shouldn't ship without
one.

**Fix:** Deleted `_isBoolParseCall` and its call site in
`_isAlreadyConverted`. `bool.parse`/`bool.tryParse` remain deliberately
un-special-cased; the doc comment on `_isAlreadyConverted` now explains why
(the rule's AST gate never reaches that case) instead of pointing at a
method that no longer exists.

**Files changed (this pass):**
- `lib/src/rules/ui/navigation_rules.dart` — removed `_isBoolParseCall` and
  its call site; expanded the doc comment explaining why `bool.parse`/
  `bool.tryParse` aren't special-cased.
- No test or fixture changes this pass (nothing depended on
  `_isBoolParseCall`, since it was never reachable/tested to begin with).

**Tests (this pass):** `dart analyze` clean on
`lib/src/rules/ui/navigation_rules.dart`. `dart test
test/rules/ui/prefer_typed_route_params_fp_test.dart
test/rules/ui/navigation_rules_test.dart` — all passed (unchanged test
count: 7 + 80 = 87). Run on branch `fix/ci-toggle-if-and-template-parity`;
no git operations performed.

**Files changed (cumulative, all passes):**
- `lib/src/rules/ui/navigation_rules.dart` — replaced the name-only "already
  parsed" exclusion with `_isAlreadyConverted`/`_isParsedNumericType`
  (resolved return-type checks for int/double/num only); retained
  `_parseMethodPattern` as an anchored, unresolved/dynamic-type-only
  fallback. `bool.parse`/`bool.tryParse` are deliberately not special-cased
  (documented, not implemented — see "Fourth pass").
- `example/lib/navigation/prefer_typed_route_params_fixture.dart` — added
  `_good512` (GOOD: `parseLimit`-wrapped `queryParameters` access, no lint),
  `_bad513`/`_sparseView` (BAD: name-lookalike, still lints), and
  `_bad514`/`_save514` (BAD: bool-returning sink, still lints).
- `test/rules/ui/prefer_typed_route_params_fp_test.dart` (new) — 7 resolved-analyzer
  regression tests covering the original report, a plain no-wrapper true
  positive, two name-lookalike true positives, and three bool-sink true
  positives.

**Proposed CHANGELOG bullet:**
`fix: prefer_typed_route_params no longer flags route/query parameters already converted by a wrapper call (detected via resolved return types, e.g. ServerUtils.parseLimit), while still flagging pass-through sinks like Set.add/Set.contains/bool-returning wrappers`
