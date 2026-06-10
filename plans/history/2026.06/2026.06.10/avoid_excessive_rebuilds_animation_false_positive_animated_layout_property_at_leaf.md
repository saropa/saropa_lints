# BUG: `avoid_excessive_rebuilds_animation` — Fires when the builder reads an animated *layout* property (font size) at a leaf, where rebuilding the surrounding subtree is mandatory

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_excessive_rebuilds_animation`
File: `lib/src/rules/ui/animation_rules.dart` (line ~1810–1845, `runWithReporter` + `_WidgetCountVisitor`)
Severity: False positive
Rule version: v2 | Since: (rule `{v2}`) | Updated: v13.12.2

---

## Summary

The rule counts widget constructors inside an `AnimatedBuilder` / `ListenableBuilder` `builder:`
callback and fires when the count exceeds 5, on the theory that the static widgets should be hoisted
into the `child:` parameter. That hoist is only valid when the animated value drives a **compositing-layer**
effect (opacity, transform) wrapping an *opaque, static* subtree. It is **invalid** when the animated
value is a **layout property** read at a *leaf* deep inside the subtree — e.g. `fontSize:
ThemeCommonFontSize.Medium.size * _textSizeAnimation.value` on a `Text`/`RichText`. Font size cannot be
animated at the compositing layer; the text widget MUST be rebuilt each frame, and its structural
ancestors (`Container` → `Stack` → `Column` → `Positioned` …) are interleaved with the animated leaf, so
they cannot be passed as an opaque `child:`. The widget-count heuristic has no awareness of *where* the
animation value is consumed, so it flags a builder whose rebuild is genuinely required.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_excessive_rebuilds_animation'" lib/src/rules/
# lib/src/rules/ui/animation_rules.dart:1792:    'avoid_excessive_rebuilds_animation',

# Negative — rule is NOT in the sibling drift-advisor repo
grep -rn "'avoid_excessive_rebuilds_animation'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/ui/animation_rules.dart:1792`, class `AvoidExcessiveRebuildsAnimationRule` at line 1776.
**Rule registered in:** `lib/saropa_lints.dart:2820`.
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`.

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class FontSizeAnimation extends StatefulWidget {
  const FontSizeAnimation({super.key});
  @override
  State<FontSizeAnimation> createState() => _FontSizeAnimationState();
}

class _FontSizeAnimationState extends State<FontSizeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(seconds: 1))..forward();
  late final Animation<double> _textSize =
      Tween<double>(begin: 0.5, end: 1).animate(_controller);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      // LINT (count > 5) — but the rebuild is REQUIRED: _textSize.value
      // drives a font SIZE (a layout property) at the leaf Text below.
      // The Container/Stack/Column wrappers cannot move to child: because
      // the animated Text is nested INSIDE them, not beside them.
      builder: (BuildContext context, Widget? child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all()),
          child: Stack(
            children: <Widget>[
              const Positioned(top: 0, left: 0, child: Icon(Icons.format_quote)),
              Column(
                children: <Widget>[
                  Text('Title', style: TextStyle(fontSize: 14 * _textSize.value)),
                  const Text('static subtitle'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

**Frequency:** Always, when an `AnimatedBuilder` builder reads an animated value at a nested leaf and the
surrounding (structurally required) widget count exceeds 5.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the builder reads an animated layout property at a leaf, so rebuilding the subtree each frame is necessary; there is no static opaque subtree to hoist to `child:`. |
| **Actual** | `[avoid_excessive_rebuilds_animation] The builder callback … contains too many widget constructors …` reported on the `AnimatedBuilder` constructor name. |

---

## AST Context

```
InstanceCreationExpression (AnimatedBuilder)              ← node walked, reported on constructorName
  └─ ArgumentList
      ├─ NamedExpression (animation: _controller)         → _staticTypeIsAnimation == true
      └─ NamedExpression (builder: (context, child) { … })
            └─ FunctionExpression.body
                  └─ ... Container/Stack/Column/Positioned/Text ...   ← _WidgetCountVisitor counts ALL
                        └─ Text(style: TextStyle(fontSize: 14 * _textSize.value))
                                                            ↑ the ONLY animation-dependent node;
                                                              never identified by the visitor
```

`_WidgetCountVisitor` (lines 1902–1948) increments on every `_knownWidgets` constructor and never checks
whether the subtree reads the animation value, nor whether any subtree is hoistable.

---

## Root Cause

`runWithReporter` (lines 1815–1845) confirms the listenable is an `Animation`, then:

```dart
final int count = _countWidgetsInBody(builderExpr.body);   // line 1838
if (count > _widgetCountThreshold) {                       // _widgetCountThreshold = 5, line 1808
  reporter.atNode(node.constructorName, code);             // line 1840
}
```

### Hypothesis A (confirmed): count-only heuristic ignores *where* the animation value is consumed

The rule equates "many widgets in the builder" with "static content that should be in `child:`." That
equivalence holds only when the builder's animated effect wraps an opaque static subtree (the rule's own
GOOD example: `Opacity(opacity: ctrl.value, child: child)`). It fails when the animated value is consumed
at a *leaf* (`fontSize: … * anim.value`) that is structurally nested inside the counted widgets. Those
widgets are not "static content sitting next to the animation"; they are the required scaffolding around
the animated leaf, and cannot be expressed as a single `child:`.

### Hypothesis B (confirmed): font size is a layout property, not a compositing effect

`Opacity` / `Transform` (and `FadeTransition` / `ScaleTransition`) animate at the compositing layer and do
NOT rebuild their child. `fontSize` changes text layout, so the `Text`/`RichText` must rebuild every frame
by definition — there is no compositing shortcut. A rule that recommends "move it to `child:`" is therefore
wrong for layout-driving animations.

---

## Suggested Fix

Before reporting, check whether the builder body actually reads an animation value (the controller passed
to `animation:`/`listenable:`, or a derived `Animation` field). Two refinements, either of which removes
the FP:

1. **Suppress when the body references an animation value at a node nested below the counted widgets.**
   If a `PropertyAccess`/`PrefixedIdentifier` ending in `.value` (or a reference to the `animation:`
   argument's element) appears inside the builder body, the rebuild is intentional — do not fire. (This
   risks under-reporting genuine waste, so combine with #2.)

2. **Only count widgets that are NOT ancestors of an animation-value read.** Walk the builder body; if a
   counted widget transitively contains a node reading the animation value, exclude it from the "hoistable
   static" tally. Fire only when ≥ threshold counted widgets sit on a branch with *no* animation-value
   read (those are the truly-hoistable ones). This preserves the true positive (large static subtree built
   inside the builder for no reason) while clearing the leaf-driven case.

A minimal first step (option 1) already clears the reported real-world FPs.

---

## Fixture Gap

`example*/lib/ui/avoid_excessive_rebuilds_animation_fixture.dart` should add:

1. `AnimatedBuilder` whose builder reads `anim.value` only as `fontSize:` on a nested `Text`, with > 5
   surrounding widgets — expect **NO lint** (leaf layout-property read; rebuild required).
2. `AnimatedBuilder` whose builder builds > 5 fully-static widgets and ignores the animation value (all
   effect via an outer `FadeTransition`/`Opacity`) — expect **LINT** (true positive: the static subtree
   IS hoistable to `child:`).
3. `AnimatedBuilder` whose builder reads `anim.value` for `Opacity(opacity:)` wrapping a large static
   subtree — expect **LINT** (compositing effect; subtree should move to `child:`).

---

## Real-World Occurrences (Saropa Contacts, v13.12.2)

| File:line | Verdict | Detail |
|---|---|---|
| `lib/views/static_data/inspirational_quote_view_screen.dart:225` | **FALSE POSITIVE** | builder reads `_textSizeAnimation.value` as `fontSize` on `RichText`/`CommonText` (lines 300, 317, 337, 349) — layout-property leaf reads inside a required `Container > Stack > Column` scaffold |
| `lib/views/static_data/interesting_vocabulary_view_screen.dart:214` | **FALSE POSITIVE** | builder reads `_textSizeAnimation.value` as `fontSize` (lines 220, 315) — same shape |
| `lib/views/static_data/mental_model_view_screen.dart:187` | **TRUE POSITIVE (not in this report)** | builder reads NO animation value; both effects are `FadeTransition`/`ScaleTransition` (compositing) around a fully static subtree → the subtree is genuinely hoistable to `child:`. Correctly flagged. |

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- Flutter: >=3.44.0
- custom_lint version: n/a — native analyzer plugin (`analysis_server_plugin`)
- Triggering project/file: `d:/src/contacts` — 2 of 3 flagged sites are FPs (the third is a true positive)

## Finish Report (2026-06-10)

Fixed in WS-6 via the report's option 2: `_WidgetCountVisitor` now counts only HOISTABLE widgets — those whose subtree reads no animation `.value`. A leaf layout read (fontSize: a.value) makes its required wrapper scaffold non-hoistable (FP cleared), while a large static subtree under `Opacity(opacity: a.value, child: ...)` stays counted (TP preserved). The visitor also handles the unresolved MethodInvocation constructor shape. Verified by `test/rules/ui/avoid_excessive_rebuilds_animation_ws6_test.dart`.
