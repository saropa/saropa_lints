# BUG: `avoid_duplicate_object_elements` — False positive on symmetric gradient / animation color list

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_duplicate_object_elements`
File: `lib/src/rules/data/collection_rules.dart` (line ~2265)
Severity: False positive
Rule version: v2 | Since: v4.4.0 | Updated: v4.13.0

---

## Summary

`avoid_duplicate_object_elements` fires on a `LinearGradient(colors: [baseColor, highlightColor, baseColor])`
shimmer list where `baseColor` appears at both ends to form a symmetric fade ramp. The duplicate is
required by the visual shape — omitting either bookend changes the gradient from symmetric to asymmetric —
but the rule treats every repeated identifier as a copy-paste error without considering whether the
enclosing parameter (`colors:` on a gradient class) is a position-sensitive sequence where deliberate
repetition is the norm. A `// ignore:` was added at the Saropa Contacts call site on 2026-06-09.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'avoid_duplicate_object_elements'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:2265:     'avoid_duplicate_object_elements',
```

The rule is registered in `lib/src/rules/data/collection_rules.dart` (line ~2265) as
`AvoidDuplicateObjectElementsRule`. Attribution is confirmed; the diagnostic owner in the IDE
Problems panel is `_generated_diagnostic_collection_name_#N` (the analysis-server plugin host),
not a sibling repo, so negative attribution is not required.

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:2265`
**Rule class:** `AvoidDuplicateObjectElementsRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

```dart
// Shimmer gradient: base → highlight → base forms a symmetric fade.
// The repeated baseColor is required by the visual shape — it is not
// a copy-paste error. Removing either endpoint produces an asymmetric
// gradient that does not animate as a shimmer.
const Color baseColor = Color(0xFFE0E0E0);
const Color highlightColor = Color(0xFFF5F5F5);

final LinearGradient shimmerGradient = LinearGradient(
  colors: [baseColor, highlightColor, baseColor], // LINT — baseColor at both ends intentional
  stops: const [0.0, 0.5, 1.0],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// Also fires on non-adjacent symmetric color sequences used in animation
// TweenSequence or multi-stop RadialGradient/SweepGradient:
final RadialGradient pulseGradient = RadialGradient(
  colors: [accentColor, fadeColor, accentColor], // LINT — accentColor bookends intentional
);
```

**Frequency:** Always — fires on any list literal where the same `SimpleIdentifier` appears at two
or more positions, regardless of whether the enclosing parameter requires a symmetric sequence.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `baseColor` at both ends is semantically required by the symmetric gradient/animation shape; this is not a copy-paste error |
| **Actual** | `[avoid_duplicate_object_elements] Duplicate object reference or literal (bool, null, identifier) in collection typically indicates a copy-paste error…` reported at the second `baseColor` occurrence |

---

## AST Context

```
InstanceCreationExpression  (LinearGradient(...))
  └─ ArgumentList
      └─ NamedExpression  colors: [baseColor, highlightColor, baseColor]
            └─ ListLiteral  ← rule registers addListLiteral; node checked here
                  ├─ SimpleIdentifier  baseColor   (index 0)
                  ├─ SimpleIdentifier  highlightColor  (index 1)
                  └─ SimpleIdentifier  baseColor   (index 2)  ← reported here
```

---

## Root Cause

The detection logic is in `_checkForDuplicateObjects` (collection_rules.dart line ~2491–2517),
called from `AvoidDuplicateObjectElementsRule.runWithReporter` (lines ~2283–2292) via both the
`addListLiteral` and `addSetOrMapLiteral` (set branch) visitors.

`_checkForDuplicateObjects` iterates the `NodeList<CollectionElement>` with a single `Set<String>
seen`. For each element it calls `element.toSource()` and reports the node if that source string
was already seen:

```dart
// collection_rules.dart ~2496–2516
final Set<String> seen = <String>{};
for (final CollectionElement element in elements) {
  if (element is! Expression) continue;
  if (element is IntegerLiteral || element is DoubleLiteral || element is StringLiteral) continue;
  if (element is! Literal && element is! SimpleIdentifier) continue;

  final String source = element.toSource();
  if (seen.contains(source)) {
    reporter.atNode(element);   // ← fires unconditionally on the second occurrence
  } else {
    seen.add(source);
  }
}
```

The function has no knowledge of:

1. **The enclosing named parameter** — it receives a raw `NodeList` stripped of its `NamedExpression`
   parent. It cannot check whether the list is bound to `colors:` on a gradient class, which is a
   well-known position-sensitive sequence.
2. **The element index** — it does not distinguish adjacent duplicates (a true copy-paste signal)
   from non-adjacent bookend duplicates (the symmetric-ramp pattern). Both are treated identically.
3. **The list's type parameter or expected element semantics** — even if the enclosing context were
   available, `_checkForDuplicateObjects` operates solely on source-text equality.

Because the detection is purely textual and index-unaware, any identifier that appears at both ends
of a symmetric color sequence is reported, even though no equivalent logic applies to
`IntegerLiteral` or `DoubleLiteral` elements (those are already excluded).

---

## Suggested Fix

**Option A (preferred — adjacency guard):** In `_checkForDuplicateObjects`, report a duplicate only
when the repeated element is **adjacent** to an earlier occurrence (i.e. the immediately preceding
element in the list has the same source). Non-adjacent duplicates are far more likely to be
intentional bookends than copy-paste errors. This is a conservative, low-false-negative change that
requires no context from the enclosing parameter.

**Option B (targeted — parameter exemption):** Before calling `_checkForDuplicateObjects`, check
whether the `ListLiteral` is the value of a `NamedExpression` whose parameter name is in an
exemption set (`colors`, `stops`, `values`, `items` on known gradient/animation types). Suppress
the check in those cases. Requires encoding the exemption list in the rule, but is precise.

**Option C (general — non-adjacent exemption):** Track the last-seen index per source string. Flag
only when a duplicate appears within N positions of the previous occurrence (configurable, default 1
for adjacency). This handles both the shimmer case (bookend, non-adjacent) and future cases without
a hard-coded parameter list.

In all options, add an explicit test fixture case so the non-adjacent symmetric pattern is
permanently guarded against regression.

---

## Fixture Gap

The fixture at `example*/lib/data/avoid_duplicate_object_elements_fixture.dart` should include:

1. **Symmetric `LinearGradient(colors: [baseColor, highlightColor, baseColor])`** — expect NO lint
   (currently emits a FP; bookend repetition is intentional).
2. **Non-symmetric list with adjacent duplicates `[a, a, b]`** — expect LINT (true positive;
   adjacent copy-paste error).
3. **Two genuinely distinct objects listed twice `[myObj, other, myObj]`** — expect LINT (true
   positive; copy-paste of a non-bookend identifier).
4. **Boolean list `[true, false, true]`** — expect LINT (true positive; bool duplicate is an error).
5. **`RadialGradient(colors: [accent, fade, accent])`** — expect NO lint (same non-adjacent
   bookend pattern via a different gradient class).

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (saropa_lints repo default)
- custom_lint version: N/A (native analyzer plugin)
- Triggering project/file: Saropa Contacts — 2026-06-09 (suppressed with `// ignore: avoid_duplicate_object_elements -- baseColor intentionally at both ends; symmetric shimmer gradient requires bookend repetition`)
