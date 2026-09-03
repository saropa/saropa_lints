# PROPOSAL: Require a Space After `//` in Line Comments

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: standard_comment_style (broader superset proposal, same relationship described from the wider rule's point of view), require_ignore_comment_spacing (narrower, `// ignore:` only)

---

## Summary

Add `start_comments_with_space` to flag a `//` line comment whose text starts immediately after the slashes with no space (`//foo`), requiring at least one space before the comment text (`// foo`). Narrower sibling of the broader `standard_comment_style` proposal — this rule checks only the space-after-`//` mechanic, nothing about capitalization or punctuation.

**Closes gap:** leancode_lint `start_comments_with_space` (github.com/leancodepl/leancode_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A comment glued directly to its `//` (`//foo`) reads worse than a spaced one (`// foo`) and is a common artifact of fast typing or paste-without-reformat. leancode_lint ships this as a standalone, minimal rule distinct from Dart's own doc-comment (`///`) conventions. This is explicitly narrower than saropa's existing `require_ignore_comment_spacing`, which is scoped ONLY to `// ignore:` / `// ignore_for_file:` suppression comments (verified via `Grep` in `lib/src/rules/stylistic/formatting_rules.dart`) — that rule does not fire on a general `//foo` comment with no `ignore:` directive, leaving ordinary comments uncovered.

---

## Detection / Behavior

Flag any `//`-prefixed line comment (`SingleLineComment` token, excluding `///` doc comments) whose first character after the two slashes is not a whitespace character and is not itself a third `/` (i.e. exclude `///` doc comments, which are a distinct token kind already covered by documentation rules) and exclude directive comments already covered by other rules (`// ignore:`, `// TODO:` if saropa has a separate TODO-format rule — scope this rule to comments with no recognized directive prefix, deferring to the more specific rule when one applies).

### Should flag (bad code)

```dart
void process() {
  //this comment has no space after the slashes
  // LINT — start_comments_with_space
  final int x = compute();
}
```

### Should pass (good code)

```dart
void process() {
  // OK — space after the slashes
  final int x = compute();
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no tier) — matches saropa's placement for other pure-formatting comment rules (e.g. `require_ignore_comment_spacing` sits in the stylistic/formatting rules file). Not a correctness or readability-blocking issue on its own, just a formatting nit.

---

## Edge Cases

1. **`///` doc comments** — should pass; this rule targets `//` line comments only, not doc comments, which have their own separate conventions and tooling (`dartdoc`, `slash_for_doc_comments`).
2. **Commented-out code (`//final x = 1;`)** — should still flag under the letter of the rule; some teams intentionally leave commented-out code unspaced to visually distinguish it from prose comments. Consider (in Implementation Notes, not required for v1) an opt-out for comments that parse as valid Dart statements, but default to flagging for simplicity and parity with leancode_lint's unconditional behavior.
3. **`// ignore:` / `// ignore_for_file:` comments** — already covered by the narrower, more specific `require_ignore_comment_spacing`; this rule's config should be checkable independently but the two are not mutually exclusive by construction (an `// ignore:foo` with no space after `//` would trip both rules). Document this as expected, not a bug — see `standard_comment_style` proposal's Edge Cases for the broader overlap discussion.
4. **Shebang lines / `// coverage:ignore-line` tool directives** — out of scope for v1; a directive-comment allowlist can be added later if false positives surface in practice.

---

## Alternatives Considered

- **Merge directly into `standard_comment_style`** — considered, since the two rules overlap almost entirely on this one check. Kept as a separate, narrower proposal because leancode_lint ships it standalone and some projects may want only the minimal space check without the broader capitalization/punctuation requirements of `standard_comment_style`. If both are implemented, see the overlap-avoidance note in `standard_comment_style`'s Edge Cases.

---

## Decision

---

## Implementation Notes

---

## Commits
