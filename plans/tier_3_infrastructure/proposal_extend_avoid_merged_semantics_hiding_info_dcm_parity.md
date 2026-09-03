# PROPOSAL: Extend `avoid_merged_semantics_hiding_info` to Flag Any Nested Interactive Semantics/GestureDetector

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_merged_semantics_hiding_info`

---

## Summary

Extend `avoid_merged_semantics_hiding_info` beyond the `MergeSemantics`-specific case to flag any interactive `Semantics`/`GestureDetector` widget nested inside another interactive `Semantics`/`GestureDetector` — which confuses assistive-technology focus order even without `MergeSemantics` involved — matching DCM's `avoid-nested-interactive-semantics`.

**Closes gap:** DCM `avoid-nested-interactive-semantics` (dcm.dev) — currently PARTIAL via saropa's `avoid_merged_semantics_hiding_info`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`AvoidMergedSemanticsHidingInfoRule` (`lib/src/rules/ui/accessibility_rules.dart:928`, code `avoid_merged_semantics_hiding_info`) only fires on `MergeSemantics`:

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  final String? constructorName = node.constructorName.type.element?.name;
  if (constructorName != 'MergeSemantics') return;

  int interactiveCount = 0;
  node.visitChildren(
    _InteractiveCountVisitor((String name) {
      if (_interactiveWidgets.contains(name)) interactiveCount++;
    }),
  );
  if (interactiveCount > 0) {
    reporter.atNode(node.constructorName, code);
  }
});
```

It requires a `MergeSemantics` ancestor to even begin counting `_interactiveWidgets` descendants. A `GestureDetector` (or explicit `Semantics(button: true, ...)`) nested directly inside another `GestureDetector`/`Semantics` with no `MergeSemantics` anywhere in the tree produces the same assistive-technology harm DCM's `avoid-nested-interactive-semantics` targets — a screen reader cannot determine which of the two overlapping interactive regions the user intends to activate, and focus/traversal order becomes ambiguous — but the current rule's early `return` on any non-`MergeSemantics` constructor means it is entirely blind to this pattern.

---

## Detection / Behavior

### Should flag (bad code)

```dart
GestureDetector(
  onTap: () => openDetails(),
  child: Column(
    children: [
      Text('Item'),
      GestureDetector( // LINT — interactive GestureDetector nested inside another interactive one, no MergeSemantics
        onTap: () => favorite(),
        child: Icon(Icons.star),
      ),
    ],
  ),
)

Semantics(
  button: true,
  onTap: openDetails,
  child: ElevatedButton( // LINT — interactive widget nested inside an interactive Semantics node
    onPressed: () {},
    child: Text('Buy'),
  ),
)
```

### Should pass (good code)

```dart
Column(
  children: [
    GestureDetector(onTap: () => openDetails(), child: Text('Item')), // OK — siblings, not nested
    GestureDetector(onTap: () => favorite(), child: Icon(Icons.star)),
  ],
)
```

---

## Proposed Tier

Tier: Professional (unchanged — same tier as `avoid_merged_semantics_hiding_info`, see `lib/src/tiers.dart:1893`)
Justification: Same accessibility category, severity (INFO/WARNING), and cost class as the existing `MergeSemantics`-scoped check; this is a detection-recall extension within the identical rule domain, not a new severity tier.

---

## Edge Cases

1. **`ExcludeSemantics` wrapping the inner interactive widget** — should pass; the inner widget is explicitly removed from the semantics tree, so there is no nesting-ambiguity harm for assistive tech.
2. **`Semantics(container: true, ...)` used purely for grouping, not marked interactive** (no `onTap`/`button: true`) — should pass; only interactive-marked `Semantics` (matching the existing `_interactiveProperties` detection already used by the sibling rule at `lib/src/rules/ui/accessibility_rules.dart:880`) should count as the "outer" node.
3. **Two `GestureDetector`s where the inner one only registers a *different* gesture type** (outer `onTap`, inner `onLongPress` only, no `onTap`) — should still flag; DCM's rule targets structural nesting of interactive semantics nodes regardless of which specific gesture callbacks are wired, since a screen reader cannot distinguish "tap the outer" from "tap the inner" either way.
4. **`MergeSemantics`-wrapped case already covered by the existing check** — must continue to fire via the existing, unmodified code path; this proposal adds a parallel non-`MergeSemantics` detection path, it does not replace the existing one.
5. **Interactive widget nested inside a `Semantics`/`GestureDetector` that is itself inside a `Builder`/other indirection widget** — best-effort only; the visitor should walk through common transparent wrapper widgets (`Builder`, `Container` with no interactive properties) but is not required to resolve through arbitrary custom widget indirection, matching the existing rule's direct-children AST-walk scope.

---

## Alternatives Considered

- **Separate new rule** (`avoid_nested_interactive_semantics`): considered, since the trigger condition changes from "root is `MergeSemantics`" to "root is any interactive `Semantics`/`GestureDetector`." However, the core interactive-widget detection machinery (`_interactiveWidgets` set, `_InteractiveCountVisitor`) is already implemented and directly reusable, and both checks report the identical underlying accessibility harm with the same correction guidance ("move interactive widgets outside / avoid wrapping one interactive region in another"). Extending keeps one rule id covering "interactive semantics nesting hazards" end-to-end and avoids asking users to separately discover and enable a second, near-identical accessibility rule.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

In `AvoidMergedSemanticsHidingInfoRule.runWithReporter` (`lib/src/rules/ui/accessibility_rules.dart:971`), add a second `context.addInstanceCreationExpression` branch (or generalize the existing one) that treats any `GestureDetector` or interactive `Semantics(...)` constructor (reusing the `_interactiveProperties` check from the sibling `AvoidNested...`/interactive-widgets rule near line 880) as a valid "outer" node — not only `MergeSemantics` — before running the existing `_InteractiveCountVisitor` descendant scan, with the `ExcludeSemantics` and non-interactive-`Semantics` exclusions from the Edge Cases section applied. Reference: `lib/src/rules/ui/accessibility_rules.dart:928`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
