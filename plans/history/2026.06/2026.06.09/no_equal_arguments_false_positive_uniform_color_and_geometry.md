# BUG: `no_equal_arguments` — False Positive on Intentional Equal Args in Color and Geometry Constructors

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `no_equal_arguments`
File: `lib/src/rules/data/equality_rules.dart` (line ~409)
Severity: False positive
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

`no_equal_arguments` fires when the same `SimpleIdentifier` appears as more
than one positional argument in a function call. The rule correctly exempts
numeric literals (`IntegerLiteral`, `DoubleLiteral`) but has no exemption for
identifier arguments whose equal values are semantically required by the
constructor contract — for example a neutral gray `Color.fromRGBO(g, g, g, 1.0)`
where R = G = B is the definition of "gray", or a `RelativeRect.fromLTRB` used
to pin a popup to a point. Every such call site must be suppressed with an
`// ignore: no_equal_arguments` workaround today.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'no_equal_arguments'" lib/src/rules/
# lib/src/rules/data/equality_rules.dart:409:     'no_equal_arguments',
```

The rule is registered in `lib/src/rules/data/equality_rules.dart` (line ~409)
as `NoEqualArgumentsRule`. Attribution is confirmed; the diagnostic owner in
the IDE Problems panel is `_generated_diagnostic_collection_name_#N` (the
analysis-server plugin host), not a sibling repo, so negative attribution
is not required.

**Emitter registration:** `lib/src/rules/data/equality_rules.dart:409`
**Rule class:** `NoEqualArgumentsRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

```dart
// Neutral gray via equal R, G, B components — semantically correct.
Color grayFromBrightness(int gray) {
  return Color.fromRGBO(gray, gray, gray, 1.0); // LINT — but equal args are REQUIRED here
}

// Centering a popup at a single tap point (left == right, top == bottom
// collapses the rect to a point, which is the documented centering idiom).
RelativeRect popupAnchor(double x, double y) {
  return RelativeRect.fromLTRB(x, y, x, y); // LINT — but x==right and y==bottom is the point-anchor pattern
}

// Square Size — no way to express "square" without passing the same value twice.
const Size square = Size(kTileSize, kTileSize); // LINT — kTileSize is a SimpleIdentifier, not a literal
```

**Frequency:** Always — fires on every call site where a non-literal identifier
appears in two or more positional slots, regardless of the constructor's
semantic contract.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — equal arguments are semantically required by `Color.fromRGBO`, `RelativeRect.fromLTRB` (point centering), and `Size` (square) |
| **Actual** | `[no_equal_arguments] The same identifier is passed as multiple positional arguments…` reported on each call |

---

## AST Context

```
ExpressionStatement
  └─ MethodInvocation (Color.fromRGBO)
      └─ ArgumentList
          ├─ SimpleIdentifier (gray)   ← pos 0
          ├─ SimpleIdentifier (gray)   ← pos 1  — flagged here
          ├─ SimpleIdentifier (gray)   ← pos 2  — and here
          └─ DoubleLiteral (1.0)
```

The rule's `context.addArgumentList` callback at
`equality_rules.dart` ~line 421 iterates positional arguments and records
each `SimpleIdentifier.name` in a `Set<String>`. On the second occurrence of
`"gray"`, `seen.contains("gray")` is `true` and `reporter.atNode(arg)` fires
(~line 444–446). No check for constructor name, callee type, or whether the
repetition is idiomatic for that callee is performed.

---

## Root Cause

### Hypothesis A: No allowlist for constructors where equal arguments are idiomatic

The detection loop (lines ~427–449) exempts only numeric literals
(`IntegerLiteral`, `DoubleLiteral`). It does not consider the callee. For
constructors whose semantics make equal arguments correct — `Color.fromRGBO`
(grayscale), `Color.fromARGB` (grayscale), `RelativeRect.fromLTRB` (point
anchor), `Size` (square), `Offset` (diagonal) — the rule has no escape path.

The literal exemption at lines ~433–434 was clearly added to handle the
`Size(100, 100)` and `Alignment(0.7, 0.7)` patterns explicitly called out in
the source comment:

```dart
// Skip numeric literals - it's common to have Alignment(0.7, 0.7),
// Offset(10, 10), Size(100, 100), etc.
if (arg is IntegerLiteral || arg is DoubleLiteral) continue;
```

But this exemption only covers the case where the programmer writes the
literal directly. When the repeated value is held in a `const` or a
variable — `Color.fromRGBO(gray, gray, gray, 1.0)`, `Size(kTileSize, kTileSize)` — the identifier path falls through to the `SimpleIdentifier` branch and fires.

### Hypothesis B: Callee resolution would allow a targeted allowlist

`node.parent` of the `ArgumentList` is a `MethodInvocation` or
`InstanceCreationExpression`. Resolving its `staticElement` (or reading
`methodName.name` for a named constructor) would let the rule skip known
idiomatic constructors without any flow analysis.

---

## Suggested Fix

At `equality_rules.dart` ~line 421, before the positional-argument loop, check
whether the callee is in an explicit allowlist of constructors/functions where
equal arguments are idiomatic:

```dart
// Constructors where equal positional arguments are semantically required
// (e.g. grayscale Color, point-anchor RelativeRect, square Size/Offset).
// These are NOT copy-paste bugs; flagging them forces meaningless ignores.
const Set<String> _equalArgAllowlist = <String>{
  'fromRGBO',   // Color.fromRGBO(r, g, b, opacity) — grayscale: r==g==b
  'fromARGB',   // Color.fromARGB(a, r, g, b) — same
  'fromLTRB',   // RelativeRect.fromLTRB(l, t, r, b) — point: l==r, t==b
  'Size',       // Size(w, h) — square: w==h
};

final parent = node.parent;
final String? calleeName = switch (parent) {
  MethodInvocation mi => mi.methodName.name,
  InstanceCreationExpression ice => ice.constructorName.name?.name ??
      ice.constructorName.type.name2.lexeme,
  _ => null,
};
if (calleeName != null && _equalArgAllowlist.contains(calleeName)) return;
```

Alternatively, downgrade the diagnostic to `DiagnosticSeverity.INFO` and add a
comment-suppression whitelist so teams can opt in per-project rather than per-site.

---

## Fixture Gap

The fixture at `example*/lib/data/no_equal_arguments_fixture.dart` should include:

1. **`Color.fromRGBO(g, g, g, 1.0)`** — expect NO lint (grayscale, equal R=G=B required)
2. **`Color.fromARGB(255, g, g, g)`** — expect NO lint (grayscale, same)
3. **`RelativeRect.fromLTRB(x, y, x, y)`** — expect NO lint (point-anchor centering idiom)
4. **`Size(d, d)` where `d` is a `SimpleIdentifier`** — expect NO lint (square)
5. **`setPosition(x, x)` where x is a SimpleIdentifier and callee is not allowlisted** — expect LINT (copy-paste error pattern)
6. **`Size(100, 100)`** — expect NO lint (numeric literal — already exempt; regression guard)
7. **`compare(value, value)` where callee is not allowlisted** — expect LINT (self-comparison error pattern)

---

## Changes Made

Implemented the callee-allowlist fix (Hypothesis A/B) in `equality_rules.dart`:

- Added `_equalArgIdiomaticCallees` = `{fromRGBO, fromARGB, fromLTRB, Size,
  Offset}` and the `_calleeName(AstNode?)` helper. Before the duplicate-arg
  loop, `runWithReporter` resolves the parent call's callee name and returns
  early when it is in the allowlist.
- `_calleeName` covers both AST shapes: the parse-only form where
  `Color.fromRGBO(...)`/`Size(...)` parse as `MethodInvocation` (uses
  `methodName.name`) and the resolved/`const` form as
  `InstanceCreationExpression` (uses `constructorName.name?.name ??
  constructorName.type.name.lexeme`).

---

## Tests Added

- `example/lib/equality/no_equal_arguments_fixture.dart`: added `_goodIdiomatic`
  (Color.fromRGBO/fromARGB, RelativeRect.fromLTRB, Size, Offset with repeated
  identifiers — NO lint) and `_badIdentifier` (`setPosition(value, value)` —
  LINT). Existing `compare(value, value)` BAD case retained.
- Scan CLI verified: `no_equal_arguments` fires only on the two
  non-allowlisted self-arg calls; every idiomatic constructor is clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** The allowlist is a single set membership check, O(1), no
traversal. It is purely additive (suppression only) and scoped to five
well-known geometry/color constructors where equal positional args are the
documented idiom. The dual-shape `_calleeName` ensures the exemption works in
both the parse-only scan and the resolved analysis server. Rule file, tier,
severity (WARNING), `LintImpact` unchanged.

**Tests:** `dart test test/rules/data/equality_rules_test.dart` → all pass.
Scan-CLI behavior verified as above.

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/no_equal_arguments_false_positive_uniform_color_and_geometry.md
→ plans/history/2026.06/2026.06.09/no_equal_arguments_false_positive_uniform_color_and_geometry.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (as in Saropa Contacts toolchain, 2026-06-09)
- custom_lint version: N/A — saropa_lints uses analysis_server_plugin, not custom_lint
- Triggering project/file: Saropa Contacts 2026-06-09 — worked around with `// ignore: no_equal_arguments -- neutral gray requires equal R=G=B` on affected call sites
