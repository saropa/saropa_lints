# PROPOSAL: Enforce General `//` Comment Formatting Conventions

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: require_ignore_comment_spacing (narrower, `// ignore:` only), start_comments_with_space (narrower sibling proposal — covers only the space-after-`//` part of this rule)

---

## Summary

Add `standard_comment_style` to enforce a broader set of `//` line-comment formatting conventions: exactly one space before the comment text (`// text`, not `//text` or `//  text`), sentence-style capitalization for standalone comment lines, and a trailing period when the comment forms a complete sentence — mirroring Dart's own doc-comment (`///`) style guide, applied to regular `//` comments too.

**Closes gap:** essential_lints `standard_comment_style` (github.com/FMorschel/essential_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Dart's own style guide asks doc comments (`///`) to be capitalized, punctuated sentences, but says nothing normative about ordinary `//` comments, which is where most in-function reasoning actually lives. essential_lints ships `standard_comment_style` to extend that same discipline to regular comments: consistent spacing, capitalization, and terminal punctuation make comments read as prose rather than as ad hoc scribbles, and catch the common regression where a comment is edited but left lowercase/unpunctuated after the surrounding code changes. This is broader than saropa's existing `require_ignore_comment_spacing`, which only inserts a space after the colon in `// ignore:`/`// ignore_for_file:` directives (verified via `Grep` in `lib/src/rules/stylistic/formatting_rules.dart`) — that rule never touches capitalization, punctuation, or general (non-`ignore`) comments.

---

## Detection / Behavior

Flag a `//` line comment (excluding `///` doc comments and recognized directive comments such as `// ignore:`, tool pragmas, and shebangs) that violates any of:

1. **Spacing** — not exactly one space between `//` and the first non-space character.
2. **Capitalization** — a standalone comment line (i.e., not a continuation of a multi-line comment block, and not a comment fragment appended after code on the same line, e.g. `x++; // increment`) whose first letter is lowercase where the comment reads as a full sentence.
3. **Terminal punctuation** — a standalone comment line that reads as a complete sentence (heuristic: contains a verb-bearing clause / ends the comment block) with no trailing `.`, `!`, or `?`.

### Should flag (bad code)

```dart
void process() {
  //no space, lowercase, no period
  // LINT — standard_comment_style: fails spacing, capitalization, and punctuation
  final int x = compute();

  // this one only fails capitalization and punctuation
  // LINT — standard_comment_style
  final int y = compute();
}
```

### Should pass (good code)

```dart
void process() {
  // Single space, capitalized, ends with a period.
  final int x = compute();

  final int y = x + 1; // OK — trailing fragment comments are exempt from the sentence checks
}
```

---

## Proposed Tier

Tier: Stylistic (opt-in, no tier) — pure formatting/prose-style convention with no correctness impact; matches saropa's placement for other comment-formatting rules.

---

## Edge Cases

1. **Overlap with `start_comments_with_space`** — **needs discussion.** `start_comments_with_space` (see sibling proposal) covers ONLY the space-after-`//` check, which is a strict subset of this rule's spacing check. If both rules are implemented as separate `SaropaLintRule` classes, a `//foo` comment would trigger BOTH diagnostics on the same line/token, producing duplicate noise in the IDE and in `violations.json` counts. Before implementing both: either (a) have `standard_comment_style` skip its own spacing check when `start_comments_with_space` is enabled in the active tier/config (cross-rule awareness, adds coupling), or (b) scope `standard_comment_style`'s trigger set to capitalization/punctuation ONLY and let `start_comments_with_space` own spacing exclusively (cleaner — recommended), or (c) implement only one of the two and drop the other. Recommend option (b) if both proposals are accepted.
2. **Trailing/inline comments (`x++; // increment`)** — should be exempt from capitalization/punctuation checks (too noisy for short annotations) but still subject to the spacing check.
3. **Multi-line comment blocks (consecutive `//` lines forming one paragraph)** — only the first line's capitalization and the last line's terminal punctuation should be checked; internal lines should pass regardless of case.
4. **Commented-out code** — should be exempt entirely (heuristic: line parses as a plausible Dart statement/expression) since it is not prose and enforcing sentence style on it produces nonsensical corrections.
5. **URLs, code identifiers, or file paths as the entire comment content** (e.g. `// TODO(username): see https://...`) — should be exempt from capitalization/punctuation; directive-style comment prefixes (`TODO`, `FIXME`, `NOTE`) should be recognized and skip the sentence-style checks for the remainder of the line.

---

## Alternatives Considered

- **Fold this into `start_comments_with_space` as one combined rule** — rejected as the primary design; keeping them separate matches upstream (essential_lints and leancode_lint ship them as two distinct rules from two distinct packages) and lets a project opt into only the minimal spacing check without the pricier prose-style heuristics. See Edge Case 1 for the required de-duplication if both ship.
- **Skip the capitalization/punctuation heuristics entirely, ship spacing-only** — rejected; that would make this rule redundant with `start_comments_with_space` and defeat the purpose of tracking essential_lints' broader rule as a distinct gap.

---

## Decision

---

## Implementation Notes

---

## Commits
