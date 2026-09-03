# PROPOSAL: `prefer_state_class_below_widget` — Flag `State<X>` Declared Above Its `StatefulWidget X`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Flag a `State<X>` class declaration that appears earlier in the file (above) its corresponding `StatefulWidget X` declaration, instead of the conventional ordering where the `StatefulWidget` comes first and its `State` class follows immediately below.

**Closes gap:** DCM `keep-state-below-its-widget` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Flutter's own style guide and the vast majority of generated boilerplate (`flutter create`, IDE "New StatefulWidget" snippets, `StatefulWidget` code templates) place the public `StatefulWidget` class first and its private `State` class immediately below it. This ordering matters for readability: a reader opening the file expects to see the widget's public API (constructor, fields) before the implementation details of its state — reading top-to-bottom mirrors the actual composition relationship (`createState()` returns the class below it). When the `State` class is declared first, a reader has to scroll past internal state/lifecycle logic before reaching the widget's public constructor and fields, inverting the natural "interface before implementation" reading order and making it harder to scan a large file for a widget's public surface.

This is purely a convention/readability concern (not a correctness bug), which is why DCM ships it as its own dedicated rule (`keep-state-below-its-widget`) rather than folding it into a general class-ordering rule — the specific `StatefulWidget`/`State` pairing relationship (via `createState()`'s return type) is a Flutter-specific structural convention that a generic "sort members" rule cannot express.

---

## Detection / Behavior

### Should flag (bad code)

```dart
// State class declared ABOVE its widget — inverted reading order.
class _CounterState extends State<Counter> { // LINT
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$_count');
  }
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}
```

### Should pass (good code)

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> { // OK — declared after its widget
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$_count');
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Pure readability/convention with no runtime or correctness impact — matches the tier criteria for cosmetic-but-worthwhile checks (consistent with other file-ordering/convention rules already placed at Comprehensive rather than Essential/Recommended, which are reserved for bug-risk and a11y-impact rules per this proposal batch's items 2-5).

---

## Edge Cases

1. **`State` and its `StatefulWidget` in different files** — should pass (or be out of scope); cross-file ordering has no meaningful "above/below" relationship, so the rule should only compare declarations within the same compilation unit.
2. **Multiple `StatefulWidget`/`State` pairs in one file, correctly ordered but interleaved** (e.g. `WidgetA`, `StateA`, `WidgetB`, `StateB` — each state directly below its own widget) — should pass; the rule checks each pair's relative order, not that all widgets come before all states.
3. **`State` class with no matching `StatefulWidget` in the file** (state class widget type resolves to an import from another file) — should pass, no ordering constraint applies without a same-file pair to compare against.
4. **Abstract/mixin-based `State` base classes not directly extending `State<X>`** (e.g. an intermediate `abstract class _BaseState<T extends StatefulWidget> extends State<T>`) — should pass; the rule should only match a `State` class whose direct generic type argument is a concrete `StatefulWidget` class resolvable in the same file, not intermediate/generic base classes.
5. **`createState()` returning a different `State` subtype than the immediately-following class** (unusual but legal) — match on `createState()`'s declared return type, not textual adjacency, so the check remains correct even if unrelated classes sit between them.

---

## Alternatives Considered

- **Fold into a generic "declaration order" rule** — rejected; a generic member-ordering rule cannot express the specific `StatefulWidget` → `State<Widget>` structural relationship (via `createState()`'s return type) without Flutter-specific knowledge, so a dedicated rule is clearer to implement and to explain in its diagnostic message.
- **Auto-fix by reordering the classes** — plausible future quick fix (move the `State` class declaration to immediately after its `StatefulWidget`), but out of scope for this initial proposal; flag first, evaluate a `DartFix` once the detection is validated on fixtures.

---

## Decision

Not yet decided.

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (existing `prefer_*`/`avoid_*` widget-structure rule cluster) — detection needs a whole-file pass matching each `ClassDeclaration extends State<X>` against the file-level offset of the `ClassDeclaration extends StatefulWidget` named `X`, which is a `CompilationUnit`-level check rather than a single-node visitor; see `SaropaContext` in `lib/src/saropa_lint_rule.dart` for the whole-unit visitor pattern used by similar file-structure rules.

---

## Commits

None yet.
