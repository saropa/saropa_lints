# PROPOSAL: `avoid_focusable_offstage` — Flag Focusable Content Inside `Offstage`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Flag an `Offstage` widget whose child subtree contains a focusable/interactive widget (`TextField`, `TextFormField`, `ElevatedButton`, `TextButton`, `IconButton`, `Checkbox`, `Radio`, `Switch`, `Focus`, etc.), since `Offstage` only hides content visually — it does not remove the subtree from the focus traversal order or from screen-reader/keyboard navigation.

**Closes gap:** DCM `avoid-focusable-offstage` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`Offstage` is commonly reached for as a lightweight "hide this without unmounting it" widget — it keeps state alive while removing the child from paint. The critical, non-obvious behavior: `Offstage.offstage = true` does **not** remove descendants from the semantics tree or the keyboard/focus traversal order. A screen reader user (TalkBack/VoiceOver) can still navigate to and activate a button that is invisible on screen, and `Tab`/`Shift+Tab` on a physical keyboard can still land focus on a hidden `TextField`. This produces a confusing, effectively broken experience: the user hears or focuses a control they cannot see, and activating it can trigger UI changes with no visible feedback.

Flutter's own documentation for `Offstage` explicitly warns about this ("this class is relatively expensive... Offstage children are still active: they can receive focus... consider using Visibility instead"), so this is a documented framework footgun, not a hypothetical. DCM ships `avoid-focusable-offstage` for exactly this case. `saropa_lints` has strong accessibility coverage in `lib/src/rules/ui/accessibility_rules.dart` (e.g. `avoid_merged_semantics_hiding_info`, `PreferMergeSemanticsRule`) but no existing rule inspects `Offstage` subtrees for focusable content — a grep for `Offstage` across `lib/src/rules/` returns only an unrelated performance mention in `lib/src/rules/packages/flutter_animate_rules.dart` about animation ticking, not focus/a11y.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class SearchPanel extends StatelessWidget {
  const SearchPanel({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !expanded,
      child: TextField( // LINT — reachable by keyboard/screen reader even when offstage
        decoration: const InputDecoration(hintText: 'Search'),
      ),
    );
  }
}
```

### Should pass (good code)

```dart
class SearchPanel extends StatelessWidget {
  const SearchPanel({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    // Visibility (with maintainState if needed) removes the subtree from
    // focus/semantics traversal when hidden, unlike Offstage.
    return Visibility(
      visible: expanded,
      maintainState: true,
      child: TextField( // OK
        decoration: const InputDecoration(hintText: 'Search'),
      ),
    );
  }
}
```

---

## Proposed Tier

Tier: Essential
Justification: This is an accessibility correctness bug with a documented, framework-confirmed failure mode (hidden-but-reachable interactive controls) — not a style preference. It sits alongside other a11y checks already at Essential/Recommended in `lib/src/rules/ui/accessibility_rules.dart`.

---

## Edge Cases

1. **`Offstage(offstage: false, ...)`** (i.e. never actually offstage, a constant-false configuration) — could argue for "no lint" since content is always shown, but the rule should still flag it: `offstage` is commonly driven by a variable/expression, and static literal `false` is the rare case; flagging keeps the rule simple and a `false` literal is itself a smell (why use `Offstage` at all).
2. **Nested `Offstage` where the outer one is not itself offstage but the inner one is** — flag based on the innermost `Offstage` ancestor's focusable descendants, same logic recursively.
3. **Focusable widget wrapped in `ExcludeFocus` or `Focus(canRequestFocus: false)` inside the `Offstage` subtree** — should pass; an explicit focus-exclusion widget already fixes the underlying problem, so flagging would be a false positive.
4. **`Offstage` with no interactive children** (e.g. only `Text`/`Icon`/`Image`) — should pass; static content has no focus/keyboard-reachability concern (screen readers can still find purely informational text, which is a lesser but distinct problem DCM does not flag either).
5. **Custom widgets that internally contain a `TextField`/button but are opaque at the AST level** (e.g. `MyCustomSearchBar()`) — false negative, acceptable; AST-only detection cannot see inside a widget's own `build()` method without whole-program analysis, consistent with how sibling a11y rules in `accessibility_rules.dart` scope their widget-name matching.

---

## Alternatives Considered

- **Flag all `Offstage` usage unconditionally** (regardless of child content) — rejected as too broad; `Offstage` around purely static/non-interactive content (measurement widgets, layout probes) is a legitimate, harmless use and would generate noisy false positives.
- **Suggest `AnimatedOpacity`/`Opacity` as the fix instead of `Visibility`** — rejected; `Opacity` still keeps the subtree focusable (same underlying problem as `Offstage`) and additionally still paints/hit-tests, so it is not a correct substitute. `Visibility(maintainState: true)` is the framework-recommended replacement.

---

## Decision

Not yet decided.

---

## Implementation Notes

Candidate home: `lib/src/rules/ui/accessibility_rules.dart`, alongside `AvoidMergedSemanticsHidingInfoRule` and `PreferMergeSemanticsRule` — reuse the file's existing `_interactiveWidgets`-style constant set (see line ~956) for the focusable-widget-name check, and the file's established pattern of `context.addInstanceCreationExpression` + child-subtree walk for detecting nested interactive widgets.

---

## Commits

None yet.
