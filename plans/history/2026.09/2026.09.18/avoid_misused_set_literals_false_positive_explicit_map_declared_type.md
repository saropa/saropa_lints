# BUG: `avoid_misused_set_literals` fires on `final Map<K, V> x = {};` even though the declared type makes `{}` unambiguously a Map

**Status: Open**

Created: 2026-09-18

Rule: `avoid_misused_set_literals`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~475, class `AvoidMisusedSetLiteralsRule` at line 455)
Severity: False positive — High. Every site has the same unambiguous shape (explicit `Map<K, V>` on the left of an empty `{}`), so this fires on the single most common way to write "empty map field," not on an edge case.
Rule version: v2 | Since: v1.7.2 | Updated: v4.13.0

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD (checkout at `9456b83e`, `v16.2.1-13-g9456b83e`).

---

## Summary

`avoid_misused_set_literals` reports *"Empty `{}` without type annotation creates a Map, not a Set."* on 4 sites in `saropa_drift_advisor`, all of the identical shape: `final Map<K, V> x = {};` — an **explicit `Map<K, V>` type already stated on the declaration**. Dart's context-typing rules resolve a bare `{}` against the declaration's static type; when that type is `Map<K, V>`, `{}` is unambiguously a `Map` literal by the language spec, with zero possibility of the `Set`-vs-`Map` misinterpretation the rule exists to catch. That ambiguity only exists when there is *no* context type at all (e.g. `var x = {};`, or `{}` passed to an untyped parameter).

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_misused_set_literals'" lib/src/rules/
lib/src/rules/code_quality/code_quality_avoid_rules.dart:475:    'avoid_misused_set_literals',

$ grep -rn "'avoid_misused_set_literals'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/saropa_lints.dart:361` — `AvoidMisusedSetLiteralsRule.new,`
**Rule class:** `AvoidMisusedSetLiteralsRule` — defined `lib/src/rules/code_quality/code_quality_avoid_rules.dart:455`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
class Example {
  // LINT (false positive): the declared type Map<String, int> already
  // resolves `{}` unambiguously as an empty Map — Dart's context-typing
  // rule (Effective Dart / language spec) applies the LHS type to the
  // literal, so this can never be misread as a Set.
  final Map<String, int> cache = {};
}
```

Minimal reduction of all 4 real sites:
- `saropa_drift_advisor/lib/src/server/generation_handler.dart:70` — `static final Map<String, String?> _webCatalogCache = {};`
- `saropa_drift_advisor/lib/src/server/rate_limiter.dart:51` — `final Map<String, _WindowEntry> _windows = {};`
- `saropa_drift_advisor/lib/src/drift_debug_session.dart:45` — `final Map<String, Map<String, dynamic>> _sessions = {};`
- `saropa_drift_advisor/lib/src/server/snapshot_handler.dart:38` — `final Map<String, List<Map<String, dynamic>>> data = {};`

**Frequency:** Always, for any `<Declared Map/Set type> <name> = {};` shape.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the declared type already disambiguates `{}`; nothing here can be "misused" |
| **Actual** | `[avoid_misused_set_literals] Set literal may be misused. Empty {} without type annotation creates a Map, not a Set.` reported at all 4 sites |

---

## AST Context

```
FieldDeclaration
  └─ VariableDeclarationList (type: Map<String, int>)
      └─ VariableDeclaration (cache)
          └─ SetOrMapLiteral ({})   ← node reported here
```

---

## Root Cause

`runWithReporter` (`code_quality_avoid_rules.dart:484-505`) registers on `SetOrMapLiteral` and, after filtering to empty literals with no explicit type arguments on the literal itself (`code_quality_avoid_rules.dart:491-492`), does:

```dart
// code_quality_avoid_rules.dart:494-503
final DartType? contextType = node.staticType;
if (contextType == null) return;

final String typeStr = contextType.getDisplayString();
if (typeStr.startsWith('Map<') || typeStr.startsWith('Set<')) {
  reporter.atNode(node);
}
```

`node.staticType` here is the analyzer's **already-resolved, post-inference** type — i.e. exactly the type Dart's own context-typing already assigned to the literal, which for `final Map<String, int> cache = {};` is unambiguously `Map<String, int>` *because* the declared LHS type drove the inference. The check as written fires whenever inference succeeded and landed on `Map<...>`/`Set<...>` — which is **every single well-typed empty-map-or-set declaration**, not just the ambiguous ones. There is no branch anywhere in this method that distinguishes "the literal's own position had no declared/contextual type and Dart's *default* rule silently chose `Set`" (the actual bug class) from "the enclosing declaration explicitly states `Map<K, V>`/`Set<T>` and inference simply confirmed it" (this repo's 4 sites).

This also matches the rule's own doc comment (`code_quality_avoid_rules.dart:444-448`), which gives `Map<String, int> map = {};  // This is actually a Set literal!` as the "bad" example — but that inline claim is incorrect Dart semantics: with an explicit `Map<String, int>` declared type present, `{}` is never inferred as `Set` (that only happens with *no* context type, e.g. `var map = {};`). The rule's example fixture (`example/lib/code_quality/avoid_misused_set_literals_fixture.dart:112-117`) encodes the same premise — `Map<String, int> map = {};` is marked `expect_lint`, alongside `var items = {1, 2, 3};` in the *same* function, even though the two have completely different ambiguity: `var items = {1, 2, 3};` has non-empty elements and is unaffected by this empty-literal branch at all (`code_quality_avoid_rules.dart:491`), while `Map<String, int> map = {};` is the unambiguous case this report is about. So the root cause is conceptual, not just a missing guard: the check conflates "Dart's context-typing resolved this literal" with "this literal is ambiguous," when in fact an explicit declared `Map<K, V>`/`Set<T>` type on the LHS is precisely the case where no ambiguity exists.

---

## Suggested Fix

Skip `{}` literals whose enclosing declaration/parameter/return position already carries an **explicit, spelled-out** `Map<K, V>` or `Set<T>` type annotation — i.e. check the syntactic type annotation on the `VariableDeclarationList`/parameter/field (`TypeAnnotation`, not just the resolved `DartType`) rather than `node.staticType`. Only flag when the empty `{}` sits in a position with **no** declared/contextual type at all (`var x = {};`, an untyped parameter, or a dynamic-typed field) — that is the only shape where Dart's own default-to-`Set` rule can silently pick the wrong container. Also correct the rule's doc comment (`code_quality_avoid_rules.dart:444-448`) and fixture (`example/lib/code_quality/avoid_misused_set_literals_fixture.dart:112-117`), which currently assert the opposite of Dart's actual context-typing behavior for `Map<String, int> map = {};`.

---

## Fixture Gap

The fixture at `example/lib/code_quality/avoid_misused_set_literals_fixture.dart` currently has exactly one `Map<...> = {}` case, and it is marked `expect_lint` (line 113) — i.e. the fixture itself asserts the false-positive behavior as correct. It should instead:

1. **`final Map<K, V> x = {};` (explicit declared Map type)** — change to expect **NO LINT**: this is the pattern behind all 4 real findings.
2. **`var x = {};` with no declared type, later inferred/used as a Set** — expect LINT (the actual bug class this rule should catch: an empty literal with zero context type defaulting to `Set` when a `Map` was likely intended).
3. **`Map<K, V> field;` then `field = {};` in a constructor body** (context type from the field's declared type, not the assignment site) — expect NO LINT, to make sure the fix's declared-type lookup also covers assignment targets, not only declarations.

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

- saropa_lints version: 16.2.1 resolved (checkout under investigation: `9456b83e`, `v16.2.1-13-g9456b83e`; rule source unchanged since v16.2.1)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings from `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/generation_handler.dart:70`, `lib/src/server/rate_limiter.dart:51`, `lib/src/drift_debug_session.dart:45`, `lib/src/server/snapshot_handler.dart:38`. Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18, revised after Opus review)

**Verdict: Valid.** The report's diagnosis and repro were confirmed by reading
the rule and reproducing both the false positive and the fix with the
resolved-analyzer test harness. A first-pass fix (declaration/assignment
AST-walking) was reviewed by Opus and found to leave the same false-positive
class open for every other syntactic position (arguments, default values,
return statements, nested map values, index assignment, `??`). This report
now documents the revised, general fix.

### Root cause

`AvoidMisusedSetLiteralsRule.runWithReporter`
(`lib/src/rules/code_quality/code_quality_avoid_rules.dart`) flagged every
empty `{}` whose *resolved* `node.staticType` (post-inference) displayed with
a `Map<` or `Set<` prefix — which matched not only Dart's true default
(`Map<dynamic, dynamic>`, assigned when there is no context type anywhere)
but also every concretely-typed result, e.g. `Map<String, int>` from an
explicit declared type. So the check fired on every well-typed
`final Map<K, V> x = {};`, not just the genuinely ambiguous `var x = {};`
shape it was meant to catch. The rule's doc comment and fixture encoded the
same incorrect premise.

### Fix (revised)

The first-pass fix walked specific AST parent shapes (`VariableDeclaration`,
`AssignmentExpression`) via resolved elements' `hasImplicitType` to detect an
"explicit declared type." Opus's review (confirmed by running the harness
against each shape) showed this missed every other position that legitimately
supplies Dart context: positional/named arguments, parameter default values,
`return`, a value slot inside an explicitly-typed outer map literal, index
assignment (`mm['k'] = {}`), and `??` operands — none of which are a
`VariableDeclaration` initializer or a plain `AssignmentExpression`, so the
guard never applied there and they kept false-positiving.

Replaced the AST-walking guard entirely with a general, position-agnostic
check on Dart's own inference result:

```dart
final DartType? contextType = node.staticType;
if (contextType == null) return;
if (contextType.getDisplayString() == 'Map<dynamic, dynamic>') {
  reporter.atNode(node);
}
```

`node.staticType` already reflects whatever context-typing Dart performed
for `{}` regardless of *where* it sits — declaration, argument, return,
nested value, index target, `??` operand, etc. Dart's inference algorithm
resolves `{}` against a real context type (`Map<K, V>` context → `Map<K,
V>`; `Iterable<E>`-but-not-`Map` context, e.g. an `Iterable<int>`-typed
target → `Set<E>`) whenever one exists, and falls back to its hardcoded
default `Map<dynamic, dynamic>` only when there is no context type at all.
So checking for exactly that default, rather than any `Map<`/`Set<` prefix,
is both necessary and sufficient — and needs no AST walking, so it covers
every syntactic position uniformly.

**Verified-not-a-bug case:** the review also asked to check
`LinkedHashMap<String, int> b = {};`. Confirmed via `dart analyze` that this
is *already an `invalid_assignment` compile error* independent of this rule
— Dart's downward inference for a bare `{}` only propagates through a
context type schema of the literal forms `Map<K, V>` / `Set<E>` /
`Iterable<E>`, not through an arbitrary concrete `Map`-implementing class
like `LinkedHashMap`. So the literal's resolved type genuinely is
`Map<dynamic, dynamic>` there. `Iterable<int> d = {};`, by contrast, **is**
valid Dart (resolves as an explicit `Set<int>`) and is correctly silent.

### Round 3 (2026-09-18, second Opus re-review): written raw/typedef/nullable `Map` annotations

The round-2 fix intentionally kept flagging `Map<dynamic, dynamic> m = {};`
(reasoning: the annotation gives no more information than none at all). A
second Opus re-review identified this as the same false-positive class as
the original report: a **written** `Map` annotation — including a raw
`Map` (no type arguments, itself `Map<dynamic, dynamic>`), a typedef alias
for one, or a nullable `Map<dynamic, dynamic>?` — already answers "did you
mean Set?" for the reader, and the diagnostic's own text ("Empty `{}`
**without type annotation**...") is factually wrong to fire when an
annotation is right there. This reverses the round-2 decision.

**Fix:** added a targeted, syntactic-position check ahead of the general
structural check — but element-based (semantic), not source-text-based, so
it follows typedefs correctly:

```dart
final AstNode? parent = node.parent;
if (parent is VariableDeclaration && parent.initializer == node) {
  final Element? element = parent.declaredFragment?.element;
  if (element is VariableElement && !element.hasImplicitType) {
    final DartType declaredType = element.type;
    if (declaredType is InterfaceType && declaredType.isDartCoreMap) {
      return; // written Map annotation - unambiguous, don't flag
    }
  }
}
```

`element.type` is the analyzer's fully-resolved type, so a `typedef Raw =
Map<dynamic, dynamic>; final Raw r = {};` is followed structurally (no
string/name re-parsing of the annotation). `dynamic`/`Object` variables are
not `InterfaceType` with `isDartCoreMap`, so they still fall through to the
general check and remain flagged, matching `var x = {};`.

Also replaced the general check's display-string comparison
(`getDisplayString() == 'Map<dynamic, dynamic>'`) with a structural check
per review request, so it can't be fooled by an unrelated user type that
happens to print the same string or by formatting differences:

```dart
if (contextType is InterfaceType &&
    contextType.isDartCoreMap &&
    contextType.typeArguments.every((arg) => arg is DynamicType)) {
  reporter.atNode(node);
}
```

Rewrote the rule's doc comment again to state the two independent
"don't flag" conditions (written `Map` annotation vs. real context type)
and to give `dynamic map = {};` as an additional bad example.

Deleted the round-2 "still fires on `LinkedHashMap<String, int> b = {};`"
test (it asserted behavior on code that doesn't compile, so it guarded
nothing useful) and the "fires on `Map<dynamic, dynamic> m = {};`" test
(decision reversed — now asserts silent instead). Added true-negative tests
for `final Map raw = {};`, the typedef-alias case, and
`Map<dynamic, dynamic>? m = {};`; added explicit true-positive tests for
`dynamic d = {};` and `Object o = {};` to pin down the boundary.

### Files changed (cumulative)

- `lib/src/rules/code_quality/code_quality_avoid_rules.dart` — `runWithReporter`
  now has two checks: (1) a written-Map-annotation exemption via the
  `VariableDeclaration`'s resolved element type, and (2) the general
  structural `Map<dynamic, dynamic>`-default check for every other
  position (arguments, return, nested values, index assignment, `??`,
  ...). Doc comment rewritten to match.
- `example/lib/code_quality/avoid_misused_set_literals_fixture.dart` —
  unchanged since round 1: `var noDeclaredType = {};` (`expect_lint`) plus
  NO-LINT cases for explicit declared `Map<K, V>`/`Set<T>` fields and an
  assignment to an explicitly-typed field — all still correctly covered.
- `test/rules/code_quality/avoid_misused_set_literals_behavior_test.dart` —
  now 21 resolved-harness behavioral tests (up from 8 in round 1, 18 in
  round 2): true positives (`var x = {}`, `dynamic field; field = {}`,
  `dynamic d = {}`, `Object o = {}`); true negatives for every position
  from round 2 (declaration, assignment target, positional/named argument,
  default value, return, nested map value, index assignment, `??`,
  `Iterable<int>`) plus the round-3 written-annotation cases (raw `Map`,
  typedef alias, nullable `Map<dynamic, dynamic>?`).

### Tests (final, round 3)

- `dart analyze` on the rule file and both test files — No issues found.
- `dart test test/rules/code_quality/avoid_misused_set_literals_behavior_test.dart test/rules/code_quality/code_quality_rules_test.dart` — All 242 tests passed (21 + 221, no regression).
- `dart format` applied to all touched files.

### Commits

Not committed by this agent (per task constraints — no git operations performed). Across all three rounds, unrelated concurrent agents transiently broke compilation of `lib/src/rules/core/async_rules.dart`, `lib/src/rules/platforms/windows_rules.dart`, and (briefly) `AvoidSubstringRule`/`ClassDeclaration.members` in the same file (in-progress edits to other rules); each time this agent waited for those to land rather than touching them, per the "touch only your rule's region" constraint. This agent's own region (`AvoidMisusedSetLiteralsRule`) was not touched by any other agent throughout.
