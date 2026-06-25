# BUG: `avoid_animated_size_in_wrap` — New rule: flag `AnimatedSize` as a direct child of `Wrap`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->


Created: 2026-06-25
Rule: `avoid_animated_size_in_wrap` (proposed — does not exist yet)
File: proposed home `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`
Severity: Feature (new rule) — prevents a runtime crash, so High value
Rule version: n/a (new)

---

## Summary

`AnimatedSize` must not be a direct child of `Wrap` (nor `Flow`). `RenderWrap`
lays out every child during `_computeRuns` (a real, parent-uses-size layout). When
a child's size changes, `RenderAnimatedSize` restarts its animation from inside its
own `performLayout` (`AnimationController.forward()` → `notifyListeners()` →
`markNeedsLayout()` on itself). The framework then asserts:

```
A RenderAnimatedSize was mutated in its own performLayout implementation.
A RenderObject must not re-dirty itself while still being laid out.
```

This throws **every frame** once a wrapped card collapses/expands, spamming the log
and Crashlytics. A `Column`/`ListView` lays each child out exactly once, so the
restart is correctly deferred to the next frame — those parents are safe.

Propose a new rule that flags `AnimatedSize` appearing directly in a `Wrap`'s
`children:` list (or `Flow`), since the combination is never correct.

---

## Attribution Evidence

This is a **new-rule feature request**, not a false positive against an existing
rule. Positive grep confirms no such rule exists yet:

```bash
grep -rn "avoid_animated_size_in_wrap" lib/src/rules/   # 0 matches
grep -rn "AnimatedSize" lib/src/rules/                  # no rule targets AnimatedSize-in-Wrap
```

`AnimatedSize` appears in `lib/src/rules/ui/animation_rules.dart`,
`lib/src/rules/ui/accessibility_rules.dart`,
`lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`, and
`lib/src/rules/testing/test_rules.dart` only as incidental string mentions — none
detect the Wrap-child crash pattern.

---

## Reproducer

Minimal Dart that triggers the runtime crash (found in Saropa Contacts,
`lib/components/primitive/expandable_card/expandable_listener_card_list.dart`, fixed
2026-06-25):

```dart
// CRASH: AnimatedSize is a direct child of Wrap. When any card animates its
// height (expand/collapse), the framework throws "RenderAnimatedSize was mutated
// in its own performLayout" every frame.
Wrap(
  children: <Widget>[
    for (final Widget card in cards)
      AnimatedSize(            // LINT — AnimatedSize directly under Wrap
        duration: const Duration(milliseconds: 200),
        child: card,
      ),
  ],
)

// OK: Column lays each child out once; AnimatedSize restart defers to next frame.
Column(
  children: <Widget>[
    for (final Widget card in cards)
      AnimatedSize(            // OK — Column/ListView/SliverList are safe parents
        duration: const Duration(milliseconds: 200),
        child: card,
      ),
  ],
)
```

**Frequency:** Always, once a wrapped `AnimatedSize` child's size changes (i.e. as
soon as the animation it exists for actually runs).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Lint flags `AnimatedSize` placed directly in `Wrap.children` (or `Flow`), with a fix/message pointing to `Column` / `ListView` |
| **Actual** | No lint today; ships, then throws `RenderAnimatedSize was mutated in its own performLayout` at runtime every frame |

---

## AST Context

The reportable node is the `AnimatedSize` `InstanceCreationExpression` when its
nearest enclosing collection-literal element is the `children:` argument of a `Wrap`
(or `Flow`) `InstanceCreationExpression`:

```
InstanceCreationExpression (Wrap)
  └─ ArgumentList
      └─ NamedExpression (children:)
          └─ ListLiteral
              └─ (element, incl. ForElement / IfElement) 
                  └─ InstanceCreationExpression (AnimatedSize)  ← report here
```

Detection notes for the implementer:
- Register `addInstanceCreationExpression`; match constructor type name
  `AnimatedSize`.
- Walk parents: the element may be wrapped in `ForElement` / `IfElement` /
  `SpreadElement` inside the `ListLiteral` — handle those, don't break on them.
- The owning `NamedExpression` must be named `children`, and its grandparent
  `InstanceCreationExpression` type name must be `Wrap` or `Flow`.
- Only flag a **direct** child: if any intervening widget (`SizedBox`,
  `ConstrainedBox`, `LayoutBuilder`, etc.) sits between the `Wrap` and the
  `AnimatedSize`, do NOT flag — a bounded/stable parent fixes the crash, so that is
  a valid escape hatch. Match the precedent in `AvoidExpandedAsSpacerRule` /
  `AvoidFlexibleOutsideFlexRule` in the same file, which already inspect the
  `children:` / `child:` named args.

---

## Root Cause (of the runtime crash the rule prevents)

`RenderWrap.performLayout` → `_computeRuns` (`wrap.dart:752`) calls
`ChildLayoutHelper.layoutChild(child, ...)` with `parentUsesSize: true`.
`RenderAnimatedSize.performLayout` → `_layoutStable` → `_restartAnimation`
(`animated_size.dart`) calls `_controller.forward()`, whose listener (registered in
the `RenderAnimatedSize` constructor) calls `markNeedsLayout()` on the same render
object while it is mid-layout — the assertion at
`RenderObject._debugCanPerformMutations` then throws.

`Column`/`Flex` lay the child out once and do not re-enter, so the same
`AnimatedSize` is fine there. The incompatibility is specific to parents that lay a
child out within their own measurement pass — `Wrap` and `Flow`.

---

## Suggested Fix (rule implementation)

Add `AvoidAnimatedSizeInWrapRule` to
`lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` (alongside the existing
flex/scroll layout rules), code `'avoid_animated_size_in_wrap'`, tags
`{'flutter', 'ui'}`. Message: "AnimatedSize cannot be a direct child of Wrap/Flow —
it re-dirties itself during the parent's layout pass and throws at runtime. Use
Column / ListView, or place a bounded box (SizedBox/ConstrainedBox) between them."
No quick fix required (the correct container depends on intent), but a message
nudge to `Column` is enough.

---

## Fixture Gap

`example*/lib/widget/avoid_animated_size_in_wrap_fixture.dart` should include:

1. `AnimatedSize` directly in `Wrap(children: [...])` — expect **LINT**
2. `AnimatedSize` directly in `Wrap(children: [ for (...) AnimatedSize(...) ])` (ForElement) — expect **LINT**
3. `AnimatedSize` directly in `Flow(children: [...])` — expect **LINT**
4. `AnimatedSize` in `Column(children: [...])` — expect **NO lint**
5. `AnimatedSize` in `ListView(children: [...])` — expect **NO lint**
6. `Wrap(children: [ SizedBox(width: 100, child: AnimatedSize(...)) ])` — expect **NO lint** (bounded intervening parent is the escape hatch)

---

## Environment

- Triggering project/file: Saropa Contacts —
  `lib/components/primitive/expandable_card/expandable_listener_card_list.dart`
- Runtime log: `bugs/issues_runtime.log` (motorola edge 2022, Android 35, Impeller/Vulkan)
- Flutter rendering: `wrap.dart` `_computeRuns`, `animated_size.dart` `_restartAnimation`

---

## Finish Report (2026-06-25)

### What was added

A new Essential lint rule `avoid_animated_size_in_wrap` (`AvoidAnimatedSizeInWrapRule`,
`LintImpact.error`, `DiagnosticSeverity.ERROR`) that flags an `AnimatedSize`
placed as a *direct* child of `Wrap` or `Flow`. The combination throws
"RenderAnimatedSize was mutated in its own performLayout" every frame once the
wrapped child's size animates, because `RenderWrap`/`RenderFlow` lay each child
out within their own measurement pass (`parentUsesSize: true`) while
`RenderAnimatedSize` re-dirties itself during that pass. Flex parents
(`Column`/`Row`/`Flex`) and `ListView` lay each child out once, deferring the
restart to the next frame, so they remain valid.

### Detection

Registered on `addInstanceCreationExpression`; matches constructor type name
`AnimatedSize`, then walks ancestors with `_isDirectChildOfUnsafeParent`:

- The first `InstanceCreationExpression` ancestor encountered means an intervening
  widget sits between the `AnimatedSize` and any children list — a bounded box
  (`SizedBox`/`ConstrainedBox`) is the documented escape hatch, so no report.
- The first enclosing `NamedExpression` must be `children`; any other name
  (e.g. `child:` of a `SizedBox`) means it is not a direct child.
- The owning argument's parent `InstanceCreationExpression` type must be `Wrap`
  or `Flow`.
- The walk transparently passes through `ListLiteral`, `ForElement`,
  `IfElement`, and `SpreadElement`, and stops at `FunctionBody`/`Declaration`
  boundaries (call site controls the parent — indeterminate).

No quick fix: the correct replacement container depends on intent, per the
suggested fix in this report. The message nudges toward `Column`/`ListView` or a
bounded intervening box.

### Files changed

- `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` — rule class.
- `lib/saropa_lints.dart` — `_allRuleFactories` registration.
- `lib/src/tiers.dart` — added to `essentialRules` beside the sibling
  runtime-crash rules (`avoid_spacer_in_wrap`, `avoid_scrollable_in_intrinsic`).
- `test/rules/widget/widget_layout_rules_test.dart` — instantiation pin.
- `example/lib/widget_layout/avoid_animated_size_in_wrap_fixture.dart` — fixture.
- `CHANGELOG.md` — `[Unreleased] → Added` entry.

### Verification

The ancestor-walk logic was validated against ten parsed cases (the six fixture
scenarios plus `IfElement`, `SpreadElement`, a non-`Wrap` widget with a
`children:` list, and a nested-`Wrap` case): all six BAD cases flag, all GOOD and
escape-hatch cases stay clean (10/10). The scan CLI's default pass is syntactic
(`parseString`), where unprefixed constructor calls parse as `MethodInvocation`
rather than `InstanceCreationExpression`, so it cannot exercise this rule; the
identical parent-chain walk was validated directly instead. The rule fires on
resolved units under real `custom_lint` use. Widget-layout instantiation suite
and the tier/plugin consistency integrity suite both pass.
