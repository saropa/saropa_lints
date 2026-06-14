# BUG: scanner — standalone `// ignore:` above a ternary operand is not honored

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-14
Component: headless scanner ignore-comment resolution (`IgnoreUtils.hasIgnoreComment`)
File: `lib/src/ignore_utils.dart` (`hasIgnoreComment` ~line 226)
Severity: Infrastructure — suppression silently not applied
Affects: `dart run saropa_lints scan` (and any rule path that relies solely on `IgnoreUtils` for line-level ignores)

---

## Summary

A standalone `// ignore: <rule>` comment placed on its own line **between** the
operands of a `ConditionalExpression` — i.e. directly above the `? <expr>` or
`: <expr>` operand that gets flagged — is not honored by the scanner: the
diagnostic still fires. A **trailing** `// ignore:` on the same line as the
flagged operand IS honored. Both the bare (`prefer_layout_builder_for_constraints`)
and prefixed (`saropa_lints/prefer_layout_builder_for_constraints`) forms were
affected. First observed while triaging
`prefer_layout_builder_for_constraints_false_positive_mediaquery_fallback_and_viewport_fraction.md`.

---

## Reproducer

```dart
Widget buildA(BuildContext context) {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double maxWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          // ignore: prefer_layout_builder_for_constraints
          : MediaQuery.sizeOf(context).width; // NOT honored — still flagged
      return SizedBox(width: maxWidth);
    },
  );
}

// Trailing form on the same line — IS honored:
//   : MediaQuery.sizeOf(context).width, // ignore: prefer_layout_builder_for_constraints
```

**Frequency:** Always, for a standalone ignore line placed above a ternary
`then`/`else` operand.

Note: with the `prefer_layout_builder_for_constraints` fallback fix now landed,
that specific rule no longer flags this shape, so the original reproducer is
green for a different reason. The ignore-resolution defect is independent — it
reproduces with **any** rule that reports on a node sitting directly under a
`?`/`:` ternary operator (place a standalone `// ignore:` above that operand and
the suppression is dropped).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | A standalone `// ignore: <rule>` on the line directly above a ternary operand suppresses the diagnostic on that operand (matching how a leading ignore works above a statement). |
| **Actual** | The diagnostic still fires; only a trailing same-line `// ignore:` suppresses it. |

---

## Root Cause

In Dart's token stream a comment attaches to the `precedingComments` of the
**next** token. For

```
? constraints.maxWidth
// ignore: ...
: MediaQuery.sizeOf(context).width
```

the `// ignore:` comment hangs off the `:` token — which is the
`ConditionalExpression.colon`, NOT any token of the flagged
`MediaQuery.sizeOf(context).width` `PropertyAccess`.

`IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart:226`) probes a fixed
set of tokens for a leading `// ignore:`:

- the node's `beginToken` and (for `AnnotatedNode`) the post-doc token
  (`_nodeHasLeadingIgnore`, ~line 366),
- `MethodInvocation` → `operator` + `methodName` tokens (~line 248),
- `PropertyAccess` → `operator` + `propertyName` tokens (~line 276),
- `CatchClause` → the token before `catch` (~line 302),
- then a parent walk that checks each ancestor's `beginToken` only (~line 316),
  stopping at the containing `Statement`,
- finally trailing-comment checks on the node and the containing statement
  (~lines 333, 339).

None of these inspect the `?` or `:` token of an enclosing
`ConditionalExpression`. The parent walk reaches the `ConditionalExpression`,
but `_nodeHasLeadingIgnore` checks its `beginToken` (the condition's first token,
`constraints`) — far above the comment — so the `commentLine == nodeStartLine - 1`
guard in `_hasValidLeadingIgnoreComment` (~line 427) never matches. The comment
on the `:` token is therefore never examined, and the suppression is dropped.

The trailing same-line form works because the comment then hangs off the token
after the value (the `,`/`;`), which the trailing-comment checks at lines
333/339 do catch.

This is why the defect is scanner-visible: the headless scanner relies solely on
`IgnoreUtils.hasIgnoreComment` for line-level ignores, whereas the analysis
server in the IDE also has its own native `// ignore:` handling that can mask it.

---

## Suggested Fix

In `hasIgnoreComment`, add a special case mirroring the existing
`MethodInvocation` / `PropertyAccess` probes: when the flagged node is (after
unwrapping parentheses) the `thenExpression` or `elseExpression` of an enclosing
`ConditionalExpression`, also probe the `?` / `:` operator token that
immediately precedes that operand for a valid leading ignore comment, using the
operand's own start line as `nodeStartLine`.

Concretely: walk from the node up to the nearest `ConditionalExpression` whose
`thenExpression`/`elseExpression` contains the node; if the node sits at the
start of that branch, call `_hasValidLeadingIgnoreComment` on
`ConditionalExpression.question` (for the then-branch) or
`ConditionalExpression.colon` (for the else-branch) with the branch operand's
start line. Reuse the unchanged `commentLine == nodeStartLine - 1` +
`_isCommentAtLineStart` guard so placement stays strict.

---

## Fixture / Test Gap

`IgnoreUtils` has unit coverage; add cases for:

1. Standalone `// ignore: <rule>` directly above a ternary `else` operand →
   suppression honored (currently fails).
2. Standalone `// ignore: <rule>` directly above a ternary `then` operand →
   suppression honored.
3. Trailing `// ignore: <rule>` on the same line as the operand → still honored
   (regression guard).
4. Standalone ignore above the ternary's `condition` (not a value branch) →
   suppresses a diagnostic reported on the condition, but NOT one reported on a
   value branch (placement must stay precise).

---

## Environment

- saropa_lints version: native analyzer plugin (v5 ignore-comment format)
- Dart SDK version: bundled with current Flutter toolchain
- Observed via: `dart run saropa_lints scan` (headless scanner path)
- Triggering shape: any rule reporting on a node under a `?`/`:` ternary operand

---

## Finish Report (2026-06-14)

### What the fix does

`IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart`) now honors a
standalone `// ignore: <rule>` placed on its own line directly above a ternary
`?`/`:` branch. A new helper, `_conditionalBranchHasLeadingIgnore`, ascends from
the flagged node to the nearest enclosing `ConditionalExpression` (stopping at a
`Statement` boundary so a ternary further up the tree cannot govern a node nested
inside a branch), identifies which branch the node begins, and probes the
operator token that carries the comment — `question` (`?`) for the then-branch,
`colon` (`:`) for the else-branch. It keys the existing
`commentLine == operandLine - 1` placement guard to the branch operand's own
start line and unwraps surrounding parentheses so `: (flagged)` still resolves.

### Why the previous behavior was wrong

A comment attaches to the `precedingComments` of the next token in the stream,
so a standalone ignore between ternary operands hangs off the `?`/`:` operator
token, never off a token of the flagged operand. The general node/parent walk in
`hasIgnoreComment` only inspected ancestor `beginToken`s, and a
`ConditionalExpression`'s `beginToken` is the condition's first token — far above
the comment — so a correctly-placed leading ignore on a ternary branch was
silently dropped. Only a trailing same-line ignore worked, because that comment
hangs off the token after the value, which the trailing-comment checks catch.

### Placement precision

The helper fires only when the flagged node begins the branch, so an ignore
above the condition or above the *other* branch does not leak onto an unrelated
operand. An ignore above the condition continues to be handled by the existing
node/ancestor walk, since that comment hangs off the condition's own begin token.

### Verification

`dart test test/utils/ignore_utils_test.dart` — all 65 tests pass, including a
new `ConditionalExpression operands (ternary branches)` group of 8 cases:
standalone ignore above the else operand, above the then operand, the hyphenated
form, a trailing same-line ignore (regression guard), a parenthesized else
operand, no-leak from the else operand onto the then operand, a non-matching rule
name (negative), and a no-comment control (negative).

### Changelog

Entry recorded under `[Unreleased]` → `### Fixed`.

### Files

- `lib/src/ignore_utils.dart` — `_conditionalBranchHasLeadingIgnore` helper plus
  its call site in `hasIgnoreComment`.
- `test/utils/ignore_utils_test.dart` — the ternary-branch test group.
- This report archived to `plans/history/2026.06/2026.06.14/`.
