# PROPOSAL: Flag Labeled Statements as Rarely-Needed and Hard to Read

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_labeled_statements` to flag labeled statements (`myLabel: for (...) { ... }`, `myLabel: while (...) { ... }`, `myLabel: switch (...) { ... }`) — Dart's `break myLabel;` / `continue myLabel;` mechanism for escaping nested loops/switches. Labels are legal but rarely necessary and hurt readability when a reader has to scan outward to find what a bare `break`/`continue` actually targets.

**Closes gap:** DCM `avoid-labels` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Labeled statements are one of Dart's least-used control-flow features, and most codebases can express the same intent with an extracted function (`return`/early-exit instead of `break outer;`) or a boolean flag. DCM ships `avoid-labels` as prior art specifically because label-driven control flow forces readers to track a name across nested blocks instead of reasoning locally about the innermost loop. Extracting the labeled block into a helper method almost always reads better and is independently testable.

---

## Detection / Behavior

Flag any `LabeledStatement` node in the AST — i.e. a statement with a label prefix (`identifier:`) attached to a `for`, `while`, `do`, or `switch` statement.

### Should flag (bad code)

```dart
void findFirst(List<List<int>> grid, int target) {
  outer:
  for (final row in grid) {
    for (final value in row) {
      if (value == target) {
        break outer; // LINT — labeled statement; prefer extracting a helper function
      }
    }
  }
}
```

### Should pass (good code)

```dart
// Extracted helper uses a normal early return instead of a label.
bool _containsTarget(List<List<int>> grid, int target) {
  for (final row in grid) {
    for (final value in row) {
      if (value == target) {
        return true; // OK — no label needed
      }
    }
  }
  return false;
}

void findFirst(List<List<int>> grid, int target) {
  final found = _containsTarget(grid, target); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Labeled statements are legal, rarely used, and not a correctness risk — this is a style/readability rule, not a bug-catcher. Comprehensive matches saropa's placement for other "rarely-needed construct" style rules; it is too niche for Essential/Recommended where most projects would never trip it either way, but valuable for teams doing a deep readability pass.

---

## Edge Cases

1. **Unlabeled `break`/`continue` inside nested loops** — should pass; the rule only targets the label declaration itself, not ordinary control flow.
2. **A label with no actual `break label;`/`continue label;` reference** — should still flag; an unused label is strictly worse (dead annotation + unused label lint from the analyzer already covers this separately, but the labeled statement itself remains a readability smell).
3. **Switch statement labels used for `continue label;` inside a `switch` nested in a `for`** — should flag same as loop labels; the AST node is still `LabeledStatement`.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Only flag labels on `switch` statements** (where `continue label;` inside a `for`-over-`switch` is the classic footgun) — rejected in favor of matching DCM's broader `avoid-labels` scope, which covers all labeled statements, to keep parity with the cited prior art.
- **Quick fix that extracts the labeled block into a method automatically** — deferred; safely inferring a method name and signature (parameters, captured locals) is non-trivial and out of scope for the initial rule. Flag now, consider a fix in a follow-up.

---

## Decision

---

## Implementation Notes

- Rule class: `AvoidLabeledStatementsRule` in `lib/src/rules/flow/control_flow_rules.dart`
- Tier: Comprehensive (INFO severity)
- Detection: uses `RecursiveAstVisitor` via `context.addCompilationUnit()` because `LabeledStatement` has no dedicated visitor callback in the analyzer's `RuleVisitorRegistry`
- Reports each `Label` node (not the whole statement) for precise diagnostic underlining
- Alias: `avoid_labels` (matches DCM prior art)
- No quick fix — extracting labeled blocks into methods requires inferring signatures

---

## Commits
