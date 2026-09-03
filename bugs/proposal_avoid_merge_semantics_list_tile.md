# PROPOSAL: `avoid_merge_semantics_list_tile` — Flag `MergeSemantics` Wrapping a `ListTile`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_merged_semantics_hiding_info` (general MergeSemantics/interactive-widget case), `prefer_merge_semantics` (adds MergeSemantics for Icon+Text)

---

## Summary

Flag `MergeSemantics` wrapping a `ListTile` (or a `ListTile`-shaped widget with `leading`/`title`/`subtitle`/`trailing`), since `ListTile` already builds a single, well-formed semantics node internally — merging it manually is redundant at best and, when the tile contains its own interactive `trailing`/`leading` widget (an `IconButton`, `Checkbox`, `Switch`), actively harmful because it collapses that nested control's semantics into the tile's announcement, making it unreachable as its own actionable element for screen reader users.

**Closes gap:** DCM `avoid-merge-semantics-list-tile` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`ListTile` is a compound widget that Flutter already composes into a single accessible unit — `title`, `subtitle`, and `leading` icon are combined into one semantics node by design, with `onTap` making the whole row a single actionable target. Wrapping it in `MergeSemantics` is a common accessibility over-correction developers reach for when a screen reader announces a list tile in multiple fragments, but the actual fix in that situation is almost never `MergeSemantics` — it is usually a missing `semanticsLabel` or an unwanted secondary interactive widget in `trailing`. When `MergeSemantics` is applied on top of a `ListTile` that has its own interactive `trailing` control (e.g. a delete `IconButton`, a `Switch`), the merge silently swallows that control's semantics into the tile's combined announcement, and TalkBack/VoiceOver users lose the ability to activate the trailing control independently of the tile's `onTap`.

`saropa_lints` already has `avoid_merged_semantics_hiding_info` (`lib/src/rules/ui/accessibility_rules.dart:928`) which flags `MergeSemantics` wrapping *any* interactive widget in general — but it operates on the general `MergeSemantics(child: ...)` pattern and does not specifically recognize `ListTile`'s compound semantics contract, so it can miss the `ListTile`-specific framing DCM's rule targets (a `ListTile` with only non-button `trailing` content, e.g. a `Text`, will not trip the general interactive-widget check, but is still a redundant/wrong wrap DCM flags because `ListTile` already self-merges).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.title, required this.onDelete});
  final String title;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics( // LINT — ListTile already merges its own semantics
      child: ListTile(
        title: Text(title),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
```

### Should pass (good code)

```dart
class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.title, required this.onDelete});
  final String title;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile( // OK — no redundant MergeSemantics wrapper
      title: Text(title),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: onDelete,
      ),
    );
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: The redundant-wrap case is a code-quality/clarity issue (Comprehensive-level on its own), but the harder case — `MergeSemantics` swallowing a `trailing` interactive control's independent semantics — is a real a11y regression, matching the severity of the existing `avoid_merged_semantics_hiding_info` rule which sits at Recommended-equivalent (`LintImpact.warning`). Placed at Recommended for consistency with that sibling rule rather than splitting into two tiers for one narrow pattern.

---

## Edge Cases

1. **`ListTile` with no interactive `trailing`/`leading`** (only `Text`/`Icon` static content) — should still flag, but as the milder "redundant wrap" case (`ListTile` already merges); correction message should differentiate redundant-only from harmful cases.
2. **`ListTile` with an interactive `trailing`** (`IconButton`, `Checkbox`, `Switch`, `Radio`) — should flag with the stronger warning: merging hides the trailing control's independent semantics.
3. **`MergeSemantics` wrapping a `Column`/`ListView` of multiple `ListTile`s** (not a single `ListTile` directly) — should pass for this rule; that pattern is a different, more general concern already covered by `avoid_merged_semantics_hiding_info` if any tile contains interactive content, not this `ListTile`-specific rule which targets the direct single-child wrap.
4. **Custom widget named similarly but not actually `ListTile`** (e.g. a project's own `CustomListTile` wrapper) — false negative by default (name-based matching only sees the literal `ListTile` constructor); acceptable, consistent with how sibling widget-name-matching rules in `accessibility_rules.dart` scope detection.
5. **`CheckboxListTile`/`RadioListTile`/`SwitchListTile`** — these are inherently interactive `ListTile` variants and should also be flagged with the stronger (harmful-merge) message, since they always carry an embedded interactive control.

---

## Alternatives Considered

- **Extend `avoid_merged_semantics_hiding_info` to special-case `ListTile`** — considered, but rejected in favor of a separate rule: the general rule's problem message and correction guidance ("move interactive widgets outside MergeSemantics") do not fit the `ListTile` case, where the correct fix is "remove the wrapper entirely," not "restructure the widget tree." A dedicated rule keeps both messages accurate and matches DCM's own decision to ship this as a distinct rule from its general MergeSemantics checks.
- **Only flag when `trailing`/`leading` is interactive** (skip the redundant-only case) — rejected; the redundant-wrap case is still worth flagging as a code-smell/clarity issue even without a correctness bug, and DCM's rule description covers both.

---

## Decision

Not yet decided.

---

## Implementation Notes

Candidate home: `lib/src/rules/ui/accessibility_rules.dart`, placed near `AvoidMergedSemanticsHidingInfoRule` (line ~928) and `PreferMergeSemanticsRule` (line ~2972) — reuse the file's `context.addInstanceCreationExpression` + `constructorName.type.element?.name` pattern to match `MergeSemantics(child: ListTile(...))`, and inspect the `ListTile`'s `trailing`/`leading` named arguments for interactive widget types (reuse the existing `_interactiveWidgets` set at line ~956).

---

## Commits

None yet.
