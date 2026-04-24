# BUG: `prefer_animation_controller_forward_from_zero` — Propose New Rule — Flag `controller.forward()` on Auto-Reverse Press Animations

**Status: Implemented (v12.3.5 / Unreleased)**

Implementation: rule in [animation_rules.dart](../lib/src/rules/ui/animation_rules.dart); quick fix in [prefer_animation_controller_forward_from_zero_fix.dart](../lib/src/fixes/animation/prefer_animation_controller_forward_from_zero_fix.dart); fixture in [prefer_animation_controller_forward_from_zero_fixture.dart](../example/lib/animation/prefer_animation_controller_forward_from_zero_fixture.dart); registered in [saropa_lints.dart](../lib/saropa_lints.dart) `_allRuleFactories` and `recommendedOnlyRules` in [tiers.dart](../lib/src/tiers.dart).

Created: 2026-04-24
Rule: `prefer_animation_controller_forward_from_zero` (proposed — does not yet exist)
File: `lib/src/rules/ui/animation_rules.dart` (new rule class; add to `all_rules.dart` + `tiers.dart`)
Severity: False negative — UX correctness gap, narrow trigger
Rule version: proposed v1

---

## Summary

When an `AnimationController` is wired to auto-reverse on completion (via `addStatusListener` → `reverse()` on `AnimationStatus.completed` — the canonical "press-and-bounce" pattern), calling `controller.forward()` from inside a gesture handler while the controller is still mid-reverse resumes from the in-flight value, producing a sticky, uneven re-press animation. The fix is `controller.forward(from: 0.0)` — restart cleanly so every press feels identical regardless of timing.

Propose flagging `AnimationController.forward()` no-arg calls inside gesture callbacks (`onTap`, `onLongPress`, `onDoubleTap`, `onTapDown`, `onPressed`, etc.) when the controller in scope has an `addStatusListener` that calls `reverse()` on completion.

---

## Attribution Evidence

```bash
# Positive — confirms no existing rule covers this
grep -rn "'prefer_animation_controller_forward_from_zero'" lib/src/rules/
grep -rn "'forward_without_reset'" lib/src/rules/
grep -rn "'animation_restart_jitter'" lib/src/rules/
# Expected: 0 matches (verified 2026-04-24)
```

**Nearest existing rules (orthogonal):**
- `require_animation_status_listener` ([animation_rules.dart:1054](lib/src/rules/ui/animation_rules.dart#L1054)) — flags missing `addStatusListener` where one is expected. This proposal is downstream — given that a status listener exists and triggers reverse-on-complete, pick the right `forward()` invocation.
- `avoid_animation_rebuild_waste`, `avoid_excessive_rebuilds_animation` — perf rules around builder scope; unrelated.
- `prefer_physics_simulation` — gesture-release animations should use springs; also unrelated but gesture-adjacent.

**Emitter registration (when implemented):** `lib/src/rules/ui/animation_rules.dart:NN`
**Rule class:** `PreferAnimationControllerForwardFromZeroRule` — to be registered in `lib/src/rules/all_rules.dart`

---

## Reproducer

Real-world trigger from `saropa-contacts` — [lib/components/primitive/animation/common_inkwell.dart](lib/components/primitive/animation/common_inkwell.dart) (pre-fix state):

```dart
class _CommonInkWellState extends State<CommonInkWell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    // This status listener makes the controller auto-reverse on completion —
    // the canonical "press-and-bounce" pattern.
    _animationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        _animationController.forward(); // LINT — no `from:`, sticky on re-press
        widget.onTap?.call();
      },
      onLongPress: () {
        _animationController.forward(); // LINT
        widget.onLongPress?.call();
      },
      onDoubleTap: () {
        _animationController.forward(); // LINT
        widget.onDoubleTap?.call();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
```

**Why this is a bug, not a style preference**

- First press: `forward()` from 0.0 → animation plays 150ms to 1.0 → status-completed → `reverse()` plays 150ms back to 0.0.
- Second press arrives at t=75ms into the reverse (controller value ≈ 0.5).
- Plain `forward()` resumes forward from 0.5, reaches 1.0 in ~75ms — half the intended duration, visibly faster than the first press.
- Plain `forward(from: 0.0)` restarts at 0.0, plays the full 150ms — every press looks identical.

The mismatch is the bug. Users feel the UI respond "slippery" on rapid taps but can't name why.

### Correct patterns (must NOT lint)

```dart
// OK — explicit `from:` restart
onTap: () => _controller.forward(from: 0.0);

// OK — reset-then-forward (equivalent; slightly more explicit)
onTap: () {
  _controller.reset();
  _controller.forward();
};

// OK — one-shot animation with no auto-reverse listener (no sticky problem)
class _OneShotState extends State<_OneShotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, ...);
  // no addStatusListener → reverse() pairing anywhere

  void _onPressed() => _c.forward(); // NO lint — not an auto-reverse controller
}

// OK — controller is driven by a gesture's own drag/fling, not a tap
onPanUpdate: (d) => _controller.value = d.delta.dx / width; // NO lint — direct value drive
onPanEnd:    (d) => _controller.forward(); // NO lint — called from a release, not a re-press
```

**Frequency:** Only when the specific pairing exists — `addStatusListener` with reverse-on-complete + `forward()` no-arg in a gesture callback.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Diagnostic `[prefer_animation_controller_forward_from_zero] This AnimationController auto-reverses on completion. Calling forward() without 'from: 0.0' while the controller is mid-reverse resumes from the in-flight value, making rapid re-presses feel sticky. Use forward(from: 0.0) so every press starts from the same state.` |
| **Actual** | No diagnostic — silent UX regression. |

---

## AST Context

```
ClassDeclaration (_CommonInkWellState)
  ├─ [...initState with addStatusListener + reverse on completed...]
  └─ MethodDeclaration (build)
      └─ ReturnStatement
          └─ InstanceCreationExpression (InkResponse)
              └─ ArgumentList
                  └─ NamedExpression (onTap:)
                      └─ FunctionExpression
                          └─ BlockFunctionBody
                              └─ ExpressionStatement
                                  └─ MethodInvocation (_animationController.forward())   ← node reported here
                                      ├─ target: SimpleIdentifier (_animationController)
                                      ├─ methodName: forward
                                      └─ argumentList: empty (no `from:`)
```

Report site: the `MethodInvocation` itself (the `.forward()` call) so the squiggle lands on the call.

---

## Detection Plan

### Registry

`context.addMethodInvocation` — every `.forward()` call passes through here.

### Trigger conditions (all must hold)

1. **Method name is `forward`** — `node.methodName.name == 'forward'`.
2. **No `from:` argument** — none of `node.argumentList.arguments` is a `NamedExpression` with `name.label.name == 'from'`. (Positional first arg is also acceptable — Flutter's signature is `forward({double? from})`, so the argument is always named.)
3. **Target static type is `AnimationController`** — resolve `node.realTarget?.staticType` and check `element.name == 'AnimationController'` or supertype chain. Skip if static type is unknown (unresolved code) to avoid false flags.
4. **Enclosing context is a gesture callback** — walk ancestors; require passing through a `FunctionExpression` that is a `NamedExpression` value where `name.label.name` is in the gesture-callback set `{onTap, onLongPress, onDoubleTap, onTapDown, onTapUp, onPressed, onSecondaryTap, onSecondaryLongPress, onSecondaryTapDown, onHover, onTertiaryTapDown}`. This filters out one-shot / programmatic `forward()` calls (e.g. `initState`, explicit `animate()` wrappers).
5. **Enclosing class's initState (or any method) attaches a status listener that reverses on completion** — scan `ClassDeclaration` for any `MethodInvocation` matching the pattern `<sameControllerReceiver>.addStatusListener(<arg>)` where the `<arg>` body references `<sameControllerReceiver>.reverse(...)` inside an `if (status == AnimationStatus.completed)` (or `== AnimationStatus.dismissed` paired with `forward()`). String-based matching on a `toSource()` region is sufficient for v1 — resolve the receiver name (`_animationController`) and grep the class body.
6. **Report site** — `reporter.atNode(methodInvocation, code)`.

### Early-exit gate

```dart
@override
Set<String>? get requiredPatterns => {'.forward(', 'addStatusListener'};
```

Both tokens must appear for the rule to fire — skips almost every file.

---

## Known False-Positive Avoidance

| Pattern | Behavior | Rationale |
|---|---|---|
| `.forward()` in `initState` / outside a gesture callback | NO lint | One-shot entry animation; no re-press timing issue. |
| `.forward()` with `from: 0.0` | NO lint | Already correct. |
| `.forward(from: someExpression)` | NO lint | User is deliberately driving from a non-zero start. |
| `.forward()` in a gesture callback, but controller has no reverse-on-completion listener | NO lint | Not an auto-reverse animation; no sticky re-press case. |
| `.forward()` in a gesture callback, controller has status listener that calls `reset()` instead of `reverse()` | NO lint | `reset()` doesn't produce the mid-animation sticky state. |
| `.reset()` immediately before `.forward()` | NO lint | Equivalent to `forward(from: 0.0)`. Detect via a preceding `ExpressionStatement` in the same `Block` that is `receiver.reset()`. |
| Controller is part of a `TweenSequence` / `AnimationController.repeat()` / `animateTo()` call | NO lint | Different usage pattern. |
| `.forward()` on a non-`AnimationController` with a `forward()` method (e.g. `PageController`, custom class) | NO lint | Type check filters. |

---

## Suggested Fix Generator

Quick fix — insert `from: 0.0` into the empty `()`:

```
- _controller.forward()
+ _controller.forward(from: 0.0)
```

Implementation notes:
- Target `SourceRange` is the `(` and `)` of `node.argumentList` — insert between them.
- Skip if the call already has any argument (including positional).
- Don't try to convert pre-existing `reset(); forward()` pairs — leave those alone; they're already correct.

---

## Fixture Gap

New fixture: `example*/lib/ui/prefer_animation_controller_forward_from_zero_fixture.dart`

Must include:

1. **Full canonical pattern** — addStatusListener + reverse on completed + `forward()` in `onTap` → expect LINT
2. **Already fixed** — same pattern but `forward(from: 0.0)` → expect NO lint
3. **Reset-then-forward** — `reset(); forward();` → expect NO lint
4. **No status listener** — plain `forward()` in `onTap`, no auto-reverse → expect NO lint
5. **Status listener calls `reset` not `reverse`** — `forward()` in onTap → expect NO lint
6. **Multiple gesture callbacks** — `onTap`, `onLongPress`, `onDoubleTap` each with bare `forward()` → expect LINT × 3
7. **`forward()` in initState** (entry animation, not a gesture) → expect NO lint
8. **`forward()` in a non-gesture helper** (`void _play() { _c.forward(); }`) → expect NO lint (v1 conservative — don't follow call chains)
9. **PageController.`forward()`** — custom type with forward method → expect NO lint
10. **Already using `reverse()` in the gesture** — `_c.status == completed ? _c.reverse() : _c.forward()` → expect NO lint (user is driving manually)
11. **Listener on a DIFFERENT controller** (`_other.addStatusListener(...)` + `_this.forward()`) → expect NO lint (pairing must match the receiver)
12. **Named `from: _c.value`** → expect NO lint (deliberate resume)

---

## Metadata

```dart
class PreferAnimationControllerForwardFromZeroRule extends SaropaLintRule {
  PreferAnimationControllerForwardFromZeroRule() : super(code: _code);

  /// UX correctness — repeat press timing. Not a crash or leak, but a
  /// visible/felt regression on every rapid tap. Narrow trigger keeps
  /// false positives low.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation', 'ux'};

  @override
  RuleCost get cost => RuleCost.medium; // requires class-body scan + ancestor walk

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => {'.forward(', 'addStatusListener'};

  static const LintCode _code = LintCode(
    'prefer_animation_controller_forward_from_zero',
    '[prefer_animation_controller_forward_from_zero] This '
        'AnimationController is wired to auto-reverse on completion, '
        'so calling forward() with no arguments from a gesture callback '
        'resumes from the in-flight value when the controller is still '
        'mid-reverse. Rapid re-presses play only part of the animation, '
        'which feels sticky and inconsistent. {v1}',
    correctionMessage:
        'Use forward(from: 0.0) so every press restarts the animation '
        'from the beginning, or call reset() immediately before forward().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferAnimationControllerForwardFromZeroFix(context: context),
  ];
}
```

### Severity Guide mapping

Medium — False negative on a UX bug that has no visible error, no compile failure, no analyzer warning. Found only by users noticing that rapid taps feel "off." `DiagnosticSeverity.WARNING` in `LintCode`.

---

## Priority

**Medium — narrow but high-signal.** The trigger is precise (auto-reverse controller + gesture-callback bare `forward()`), so false-positive rate should be low. When it fires, it catches a real UX regression that QA rarely flags because the degradation is time-correlated — one press looks fine, three rapid presses look wrong, and QA test scripts usually do one press. Real-world hit in `saropa-contacts/lib/components/primitive/animation/common_inkwell.dart:329/347/364` (three sites in one file, fixed 2026-04-24).

---

## Open Design Questions

1. **Call-chain propagation** — a gesture handler `onTap: _onPressed` where `_onPressed()` is a method that calls `_controller.forward()` would not be flagged by v1 (ancestor walk stops at the method boundary). v2 could follow the call graph one hop. Deferred; start narrow.
2. **`AnimationStatus.dismissed` + `forward()` pairing** — the mirror of `completed` + `reverse()` (animation auto-forwards on dismiss). Same sticky-restart problem when `reverse()` is called from a gesture. Cover in v2 or treat as a separate rule? Recommend v2 since it's the same mechanism rotated 180°.
3. **`repeat()` / `repeat(reverse: true)`** — controllers that auto-ping-pong via `repeat()` aren't "pressed" — the animation is continuous, and gesture-driven `forward()` on top is a different pattern entirely. Out of scope.
4. **Diagnostic wording for the `reverse()` direction** — the rule message currently assumes the user called `forward()`. If we expand to `reverse()` + `dismissed` pairings (question 2), the message needs to generalize. Defer wording until that decision.

---

## Environment

- saropa_lints version: target for next release
- Dart SDK version: any
- custom_lint version: n/a — native analyzer plugin
- Triggering project/file: `d:\src\contacts\lib\components\primitive\animation\common_inkwell.dart` — three call sites (`onTap`, `onLongPress`, `onDoubleTap`), all fixed 2026-04-24 by switching to `forward(from: 0.0)`.
