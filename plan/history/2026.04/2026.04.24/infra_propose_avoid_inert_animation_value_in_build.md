# BUG: `avoid_inert_animation_value_in_build` — Propose New Rule — Detect `Animation.value` Read in `build()` Outside a Listening Widget

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Implemented: 2026-04-24 (v12.3.5) — rule class [animation_rules.dart](../lib/src/rules/ui/animation_rules.dart) `AvoidInertAnimationValueInBuildRule`; registered in [saropa_lints.dart](../lib/saropa_lints.dart) and added to `recommendedOnlyRules` in [tiers.dart](../lib/src/tiers.dart); fixture [avoid_inert_animation_value_in_build_fixture.dart](../example/lib/animation/avoid_inert_animation_value_in_build_fixture.dart); test entry in [animation_rules_test.dart](../test/animation_rules_test.dart). Quick fixes deferred (rule emits diagnostic + correction message only in v1 — the structural wrap / transition-swap fixes sketched in the Suggested Fix Generator section are future work).
Rule: `avoid_inert_animation_value_in_build` (proposed — does not yet exist)
File: `lib/src/rules/ui/animation_rules.dart` (new rule class; add to `all_rules.dart` + `tiers.dart`)
Severity: False negative — no rule exists for a silent correctness bug
Rule version: proposed v1

---

## Summary

Reading `someAnimation.value` directly inside a `State.build()` method — outside of an `AnimatedBuilder` / `ListenableBuilder` / `ValueListenableBuilder` builder callback — produces **dead animation code**: the expression snapshots the current value at the moment `build()` runs and never updates as the controller ticks, because nothing in the widget tree is listening. The animation appears wired (controller is started, tween exists, status listener fires) but is visually inert.

The proposed rule flags `Animation.value` reads inside `build()` unless the read is inside a listening builder callback.

---

## Attribution Evidence

```bash
# Positive — confirms the rule does NOT already exist under any of these names
grep -rn "'avoid_inert_animation_value_in_build'" lib/src/rules/
grep -rn "'animation_value_in_build'" lib/src/rules/
grep -rn "'inert_animation'" lib/src/rules/
grep -rn "'dead_animation'" lib/src/rules/
# Expected: 0 matches (verified 2026-04-24)
```

**Nearest existing rules (do not cover this pattern):**
- `avoid_animation_in_build` — flags `AnimationController` **construction** in build(), not `.value` reads. Complementary, not overlapping.
- `avoid_animation_rebuild_waste` — targets oversized `AnimatedBuilder.builder` subtrees, not the absence of a builder.
- `avoid_excessive_rebuilds_animation` — counts widget constructors inside builder callbacks; does not detect the inverse (reads outside any builder).
- `prefer_listenable_builder` — suggests `ListenableBuilder` over `AnimatedBuilder` for plain `Listenable`; orthogonal.

**Emitter registration (when implemented):** `lib/src/rules/ui/animation_rules.dart:NN`
**Rule class:** `AvoidInertAnimationValueInBuildRule` — to be registered in `lib/src/rules/all_rules.dart`

---

## Reproducer

Real-world trigger from `saropa-contacts` — [lib/components/primitive/animation/common_inkwell.dart](lib/components/primitive/animation/common_inkwell.dart) (pre-fix state, commit prior to 2026-04-24):

```dart
class _CommonInkWellState extends State<CommonInkWell>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation   = Tween<double>(begin: 1, end: 0.9).animate(_animationController);
    _opacityAnimation = Tween<double>(begin: 1, end: 0.7).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation, // OK — ScaleTransition listens to the animation
      child: widget.child.withOpacity(_opacityAnimation.value), // LINT — inert read
      //                              ^^^^^^^^^^^^^^^^^^^^^^^^
      // `_opacityAnimation.value` is read once when build() runs. As the
      // controller ticks, nothing re-invokes build(), so the opacity never
      // animates. ScaleTransition only rebuilds its own RenderObject.
    );
  }
}
```

### Correct patterns (must NOT lint)

```dart
// OK — FadeTransition listens to the animation and drives its own RenderObject
return FadeTransition(opacity: _opacityAnimation, child: widget.child);

// OK — AnimatedBuilder rebuilds its builder callback on every tick
return AnimatedBuilder(
  animation: _controller,
  builder: (BuildContext ctx, Widget? child) {
    // `.value` is fine here — the builder runs on every tick.
    return Opacity(opacity: _opacityAnimation.value, child: child);
  },
  child: widget.child,
);

// OK — ListenableBuilder (Flutter 3.13+) same shape
return ListenableBuilder(
  listenable: _controller,
  builder: (BuildContext ctx, Widget? child) => Opacity(
    opacity: _opacityAnimation.value, // OK — inside builder
    child: child,
  ),
);

// OK — read outside build() is not this rule's concern
double snapshotOpacityForDebug() => _opacityAnimation.value;
```

**Frequency:** Always, for the exact shape `build() { ... someAnimation.value ... }` where `someAnimation` is an `Animation<T>` and the read is not inside a listening builder callback.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Diagnostic `[avoid_inert_animation_value_in_build] Reading _opacityAnimation.value here produces a snapshot that never updates. Use FadeTransition (for opacity), ScaleTransition (for scale), AnimatedBuilder, or ListenableBuilder to listen to the animation.` |
| **Actual** | No diagnostic — silent bug ships to production. |

---

## AST Context

```
MethodDeclaration (build) — name == 'build', parameter type BuildContext
  └─ Block
      └─ ReturnStatement
          └─ InstanceCreationExpression (ScaleTransition)   ← not a listening builder (no `builder:` param)
              └─ ArgumentList
                  └─ NamedExpression (child:)
                      └─ MethodInvocation (.withOpacity(...))
                          └─ ArgumentList
                              └─ PropertyAccess (._opacityAnimation.value)   ← node reported here
                                  ├─ SimpleIdentifier (_opacityAnimation)    ← staticType is Animation<double>
                                  └─ SimpleIdentifier (value)
```

Key: the parent-walk from the flagged `PropertyAccess` must reach the enclosing `MethodDeclaration (build)` **without** passing through a `FunctionExpression` that is the `builder:` argument of a listening builder widget.

---

## Detection Plan

### Registry

`context.addPropertyAccess` **and** `context.addPrefixedIdentifier` — the access can be parsed either way depending on prior tokens (`this._opacityAnimation.value` vs `_opacityAnimation.value`).

### Trigger conditions (all must hold)

1. **Property name is `value`** — `propertyAccess.propertyName.name == 'value'` (or `prefixedIdentifier.identifier.name == 'value'`).
2. **Receiver static type is `Animation<T>` or a subtype** — resolve via `staticType` → `InterfaceType`. Walk `element` + `allSupertypes` looking for `Animation` (SDK class). This catches `AnimationController`, `CurvedAnimation`, `ReverseAnimation`, `Tween<T>.animate(...)` results, and any custom `Animation` subclass. Reuse the existing `_isAnimationType(InterfaceType)` helper at [animation_rules.dart:2397](lib/src/rules/ui/animation_rules.dart#L2397).
3. **Enclosing `build()` exists** — walk `node.parent` until a `MethodDeclaration` is hit; require `node.name.lexeme == 'build'` AND its parameter list's first positional type is `BuildContext`. Stop the walk at any `ClassDeclaration` (prevents matching nested classes) or `CompilationUnit`.
4. **Not inside a listening builder callback** — during the upward walk, if we pass through a `FunctionExpression` whose parent is a `NamedExpression(name: 'builder', ...)` AND that `NamedExpression` belongs to an `InstanceCreationExpression` whose type is one of `{AnimatedBuilder, ListenableBuilder, ValueListenableBuilder}`, the read is safe — abort detection.

### Why not a pure substring check on `.value`

`Animation.value` is a well-known pitfall but `value` is too common a property name to flag without type resolution. Strings like `_controller.value` where the controller is actually a `TextEditingController` or custom non-animation class must not trigger — hence the `Animation` supertype walk.

### Early-exit gate

```dart
@override
Set<String>? get requiredPatterns => {'.value'};
```

Files without any `.value` token cannot match — saves full AST registration cost on most files.

---

## Known False-Positive Avoidance

| Pattern | Behavior | Rationale |
|---|---|---|
| `_anim.value` inside `AnimatedBuilder(builder: ...)` | NO lint | Builder re-invokes on every tick. |
| `_anim.value` inside `ListenableBuilder(builder: ...)` | NO lint | Same as above (Flutter 3.13+). |
| `_anim.value` inside `ValueListenableBuilder(builder: ...)` | NO lint | Same. |
| `_anim.value` in `setState(() { x = _anim.value; })` inside an `addListener` callback | NO lint | Not inside `build()` — outside the rule's scope. |
| `_anim.value` in `didChangeDependencies` / `initState` / lifecycle methods | NO lint | Outside `build()`. |
| `_anim.value` in a helper method called from `build()` | **OPEN QUESTION** — recommend: flag it. The helper inherits `build()`'s (lack of) listening context. Rule v1 may conservatively skip non-`build()` methods and add helper-tracking in v2. |
| `controller.value = 0.5` (assignment) | NO lint | Not a read — rule targets reads only. Detect via `node.parent is! AssignmentExpression || AssignmentExpression.leftHandSide != node`. |
| `if (controller.value > 0.5) { ... }` in build() | LINT | Same inert-read issue — conditional layout based on a snapshot. |
| Non-`Animation` types with a `value` property (`TextEditingController`, `ValueNotifier`, custom classes) | NO lint | Type check excludes them. |

---

## Suggested Fix Generator

Offer two quick fixes when the read is a direct receiver pattern (`Foo(arg: _anim.value)` or `widget.withOpacity(_anim.value)`):

1. **Replace `Opacity(opacity: _anim.value, child: X)` → `FadeTransition(opacity: _anim, child: X)`** — structural, detectable, high-confidence.
2. **Replace `Transform.scale(scale: _anim.value, child: X)` → `ScaleTransition(scale: _anim, child: X)`** — same shape.
3. **General-purpose wrap suggestion** (no auto-apply): wrap the enclosing widget in `AnimatedBuilder(animation: <anim>, builder: (ctx, child) => <original>)`. Leave as correction message text — too easy to mis-apply structurally.

No auto-fix for the `widget.withOpacity(_anim.value)` extension case — that's a project-specific extension; fix generator cannot predict its signature.

---

## Fixture Gap

New fixture: `example*/lib/ui/avoid_inert_animation_value_in_build_fixture.dart`

Must include:

1. **Basic inert read** — `Opacity(opacity: _anim.value, child: child)` inside `build()` → expect LINT
2. **Inert read through extension** — `child.withOpacity(_anim.value)` → expect LINT
3. **Inert read in conditional** — `if (_anim.value > 0.5) ...` in build() → expect LINT
4. **Safe inside AnimatedBuilder** — `AnimatedBuilder(builder: (ctx, c) => Opacity(opacity: _anim.value, child: c))` → expect NO lint
5. **Safe inside ListenableBuilder** — same shape → expect NO lint
6. **Safe inside ValueListenableBuilder** — same shape → expect NO lint
7. **Safe: value read outside build()** — getter method, lifecycle method → expect NO lint
8. **Safe: non-Animation type with `.value`** — `_textController.value`, `_valueNotifier.value` → expect NO lint
9. **Safe: assignment, not read** — `_controller.value = 0.3` → expect NO lint
10. **Subtype coverage** — `_curvedAnim.value`, `_reverseAnim.value`, `Tween<double>(...).animate(_c).value` → expect LINT on each
11. **Nested builder** — builder inside builder, inner reads value → expect NO lint (ancestor listener present)
12. **False-flag guard** — custom class with `Animation` in name but NOT a subtype (e.g. `AnimationData`) → expect NO lint
13. **Through `this.`** — `this._anim.value` → expect LINT (same as bare)

---

## Metadata

```dart
class AvoidInertAnimationValueInBuildRule extends SaropaLintRule {
  AvoidInertAnimationValueInBuildRule() : super(code: _code);

  /// Silent correctness bug — animation appears wired but never runs.
  /// Misleads the reader, wastes controller cycles, fails to deliver
  /// the visual feedback the code claims to provide.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation'};

  @override
  RuleCost get cost => RuleCost.medium; // requires type resolution + parent walk

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => {'.value'};

  static const LintCode _code = LintCode(
    'avoid_inert_animation_value_in_build',
    '[avoid_inert_animation_value_in_build] Reading an Animation.value '
        'inside build() outside of a listening builder produces a static '
        'snapshot — the value is captured when build() runs and never '
        'updates as the controller ticks, so the animation is visually '
        'inert. Use FadeTransition (for opacity), ScaleTransition (for '
        'scale), Align / SlideTransition (for offset), or wrap the '
        'subtree in AnimatedBuilder / ListenableBuilder so the read is '
        're-evaluated on every tick. {v1}',
    correctionMessage:
        'Replace the direct .value read with a listening widget: '
        'FadeTransition(opacity: animation, child: ...), '
        'ScaleTransition(scale: animation, child: ...), or '
        'AnimatedBuilder(animation: animation, builder: (ctx, child) => '
        '<widget that uses animation.value>, child: child). The listening '
        'widget rebuilds only its own RenderObject per tick.',
    severity: DiagnosticSeverity.ERROR, // silent-bug class deserves ERROR
  );
}
```

### Severity Guide mapping

| Severity | Meaning | This rule |
|---|---|---|
| **Critical** | Rule crashes analyzer | N/A |
| **High** | False positive on common pattern | N/A — new rule |
| **Medium** | False negative on important violation | **Yes — this rule** (rule's whole purpose is to close this false-negative gap) |
| **Low** | Cosmetic | N/A |

Severity in `LintCode`: `ERROR` — the bug is silent and production-visible, no user can see the pattern fails without stepping through with a debugger.

---

## Priority

**Critical.** The exact bug described here existed in [common_inkwell.dart](lib/components/primitive/animation/common_inkwell.dart) — a wrapper used across the entire `saropa-contacts` app — and shipped undetected. One of three core animation primitives had its opacity tween silently ignored for the life of the widget. A single rule catches all future instances, including the far-more-subtle cases where `.value` is read in a `child:` slot, inside a conditional, or passed to a non-framework helper.

---

## Open Design Questions

1. **Helper methods called from build()** — should `build() { return _buildInner(context); } Widget _buildInner(ctx) { return Opacity(opacity: _anim.value, ...); }` be flagged? The helper inherits the non-listening context. Rule v1: conservative, flag only direct `build()` reads. Rule v2: propagate "called from build" taint through the call graph.
2. **Record the receiver name in the diagnostic** — quote `_opacityAnimation.value` in the message for faster user orientation vs a generic "an Animation.value".
3. **Inline exception via comment** — `_anim.value /* ignore: inert-ok, used for initial snapshot */`? Probably not — `// ignore: avoid_inert_animation_value_in_build` on the line suffices. Don't invent a second suppression mechanism.

---

## Environment

- saropa_lints version: target for next release
- Dart SDK version: any
- custom_lint version: n/a — this plugin is a native analyzer plugin (per MEMORY: `saropa_lints is native analyzer plugin, not custom_lint`)
- Triggering project/file (real-world motivating case): `d:\src\contacts\lib\components\primitive\animation\common_inkwell.dart` — the `widget.child.withOpacity(_opacityAnimation.value)` read on line 381 (pre-fix).
