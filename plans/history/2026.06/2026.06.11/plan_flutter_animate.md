# Plan: new `flutter_animate` lint rules

**Package:** flutter_animate ^4.5.2 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (v4.5.2, verified against GitHub source):**
- `Animate extends StatefulWidget with AnimateManager<Animate>` — constructor:
  `Animate({ child, effects, autoPlay, delay, controller, adapter, target, value, onInit, onPlay, onComplete })`
- `autoPlay` defaults to `true`; when `true`, calls `_controller.forward()` on mount.
- `onPlay` fires after any `Animate.delay`; receives the internal `AnimationController`. The documented
  idiom for looping is `onPlay: (controller) => controller.repeat(reverse: true)`.
- `target` (0–1): when changed via `setState`, automatically animates to the new position (`didUpdateWidget` calls `_play()`).
- `value` (0–1): jumps immediately to position without animation.
- `controller` (external): when provided, `_isInternalController = false` and Animate does NOT call
  `_controller.dispose()`. The caller owns disposal.
- `adapter`: synchronizes the internal controller to an external source (e.g., `ScrollAdapter`);
  the `Adapter.detach()` lifecycle is managed by `Animate` itself.
- `AnimateList`: wraps each child in its own `Animate`; staggers via `interval`; extension shorthand
  `[widgets].animate(interval: 400.ms)`.
- `Animate.restartOnHotReload` global static: restarts all animations on hot reload.
  Must be `false` in release builds; leaving it `true` is a ship-ready defect.
- Library URI: `package:flutter_animate/flutter_animate.dart` (single barrel export).

**Confirmed AST-detectable concerns:**
1. `onPlay: (c) => c.repeat()` — unconditional repeat in `onPlay` callback (infinite loop; runs off-screen).
2. External `AnimationController` passed as `controller:` but caller class has no `dispose()` that calls
   `controller.dispose()` — ticker leak.
3. `Animate.restartOnHotReload = true` set anywhere outside a debug guard — shipping a dev-only flag.
4. `target:` parameter passed as a literal constant (0.0 or 1.0) that never changes — `target` is only
   useful when it varies with state; a fixed literal replaces what `autoPlay` already provides,
   the animation still fires but the developer intent is incorrect.
5. `.animate()` called on a widget without a stable `Key` inside a list or `Column`/`Row` that rebuilds
   — every rebuild creates a new `Animate` state, restarting the animation.
6. `AnimateList` constructed with an empty `children` list (literal `[]`) — no-op, dead code.
7. `autoPlay: false` with no `controller:` and no `adapter:` and no `target:` — animation can never
   start; the widget is permanently invisible or frozen.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `flutter_animate_unconditional_repeat_in_on_play` | correctness | `onPlay:` argument is a function literal whose body calls `controller.repeat()` unconditionally (no `if`, no visibility check) | report-only | WARNING | narrow to `onPlay` named arg on `Animate` / `.animate()`; skip when body contains an `if` guard |
| `flutter_animate_external_controller_not_disposed` | correctness | `controller:` arg is a local variable or field whose static type is `AnimationController` and the enclosing class has no `dispose()` that calls `.dispose()` on that variable | report-only | WARNING | skip when controller is created by an `AnimationController(...)` expression that is NOT stored in a field (i.e., inline — then Animate's internal disposal handles it); class-level fields only |
| `flutter_animate_restart_on_hot_reload_in_release` | correctness | `Animate.restartOnHotReload = true` set without being guarded by `kDebugMode` or `assert(...)` | report-only | ERROR | library URI `package:flutter_animate/flutter_animate.dart`; only the static setter assignment |
| `flutter_animate_fixed_target_literal` | best-practice | `target:` named arg whose value is a numeric literal (not a variable or expression) | report-only | INFO | literal only; do NOT flag `target: _isActive ? 1.0 : 0.0` (conditional expression) or `target: someConst` |
| `flutter_animate_no_key_in_list` | best-practice | `.animate()` or `Animate(child: ...)` used directly as a `children:` element in `Column`, `Row`, `ListView`, `Stack`, `Wrap`, or `AnimateList` where that element carries no `key:` | report-only | WARNING | skip when the call-site expression already has a `key:` named arg on the `.animate()` call or its immediate `Animate()` wrapper; skip test files |
| `flutter_animate_empty_animate_list` | correctness | `AnimateList(children: [])` or `[].animate(...)` where the children expression is a literal empty list | report-only | WARNING | literal empty list only; do NOT flag variables |
| `flutter_animate_auto_play_false_no_driver` | best-practice | `autoPlay: false` passed to `Animate` / `.animate()` with no `controller:`, no `adapter:`, and no `target:` also present | report-only | INFO | only fire when all three of `controller`, `adapter`, `target` are absent from the same constructor call |

---

## Rule detail

### `flutter_animate_unconditional_repeat_in_on_play`

- **What/why:** The documented `onPlay` loop idiom `onPlay: (controller) => controller.repeat(reverse: true)` creates an animation that runs forever. Flutter's `AnimationController` does not pause when the widget is scrolled off-screen, hidden behind another route, or placed in an `Offstage`. An infinite animation fires a new frame every vsync tick, consuming CPU and preventing battery-saving sleep on the rasterizer thread. GitHub flutter/flutter issue #5469 ("If you put an infinitely-animating widget offstage, it still burns the battery down") and issue #128197 ("Performance issues with looping animations") confirm this is a real production footgun. The correct approach is to gate the repeat on a `VisibilityDetector` callback, use `WidgetsBindingObserver.didChangeAppLifecycleState`, or pause via `onComplete` when the widget may go off-screen.
- **Detection (AST, type-safe):**
  1. Match a `NamedExpression` where `name.label.name == 'onPlay'` inside an `ArgumentList` of either
     an `InstanceCreationExpression` whose static type is `Animate` from
     `package:flutter_animate/flutter_animate.dart`, OR a `MethodInvocation` named `animate` whose
     static return type is `Animate`.
  2. The `expression` of the `NamedExpression` must be a `FunctionExpression` (arrow or block body).
  3. Walk the function body for any `MethodInvocation` named `repeat` whose receiver's static type is
     `AnimationController` from `package:flutter/animation.dart`.
  4. If found AND the `MethodInvocation` is NOT nested inside an `IfStatement` or `ConditionalExpression`,
     report at the `onPlay:` named expression.
- **Fix:** report-only. Adding a visibility guard requires knowing which `VisibilityDetector` or lifecycle strategy the caller wants — no safe mechanical replacement.
- **False positives:**
  - Animations intentionally meant to loop forever (loading spinners, pulsing status indicators) are a genuine FP. Severity is WARNING not ERROR to allow developer judgment.
  - `controller.repeat()` inside `if (_shouldLoop) { controller.repeat(); }` is correctly skipped.

---

### `flutter_animate_external_controller_not_disposed`

> **VALIDATION (2026-06-11) — DROP (overlap):** duplicates `require_change_notifier_dispose` (disposal_rules.dart:1331), `require_dispose_implementation` (disposal_rules.dart:2110), and `require_animation_controller_dispose` (disposal_rules.dart:2099) — all flag undisposed AnimationController fields. The "externally provided" framing does not survive once stored as a field. Drop unless re-scoped to a case those provably miss.

- **What/why:** When a caller provides `controller: myController` to `Animate`, the package source
  (`_disposeController()`) explicitly checks `_isInternalController` before disposing — external
  controllers are intentionally NOT disposed by `Animate`. The caller takes ownership. If the
  `AnimationController` is stored as a class field and `dispose()` is never called on it, the `Ticker`
  (which backs every `AnimationController`) leaks and fires indefinitely — a real memory and battery
  leak. This is the most common `AnimationController` leak class in Flutter (confirmed by
  flutter/flutter issue #57797 and the analyzer's own `discard_listeners` pattern).
- **Detection (AST, type-safe):**
  1. Match `NamedExpression` where `name.label.name == 'controller'` inside an `Animate` / `.animate()`
     call as above.
  2. The value expression resolves to an identifier whose declaration is a `VariableDeclaration` at
     class field scope (i.e., `node.parent is FieldDeclaration`).
  3. The field's static type resolves to `AnimationController` from `package:flutter/animation.dart`.
  4. Check the enclosing `ClassDeclaration` for a method named `dispose` that contains a
     `MethodInvocation` named `dispose` on a receiver matching the same field name.
  5. If no such invocation exists, report the `controller:` named expression.
- **Fix:** report-only. The disposal call belongs inside the class's `dispose()` method but the
  correct placement depends on whether `super.dispose()` is called before or after.
- **False positives:**
  - Controllers disposed via a helper method (not directly in `dispose()`) are missed — acceptable
    conservative heuristic.
  - `SingleTickerProviderStateMixin` / `TickerProviderStateMixin` disposes controllers via
    `super.dispose()`; the rule may FP here. Guard: check whether the class mixes in
    `SingleTickerProviderStateMixin` and the field was created via `createAnimationController()` —
    mark as speculative, refine at implementation time.
  - Test files: skip via `ProjectContext.isTestFile(path)`.

---

### `flutter_animate_restart_on_hot_reload_in_release`

- **What/why:** `Animate.restartOnHotReload` is a development convenience that restarts all running
  animations every time Flutter hot-reloads. If left `true` in production code (not guarded by
  `kDebugMode`), it causes every `Animate` in the tree to restart whenever Flutter internally
  reassembles the widget tree (e.g., after any `setState` that causes `didUpdateWidget` to propagate).
  The package README notes this flag is "for animation testing during development." Shipping it
  `true` is a defect: users see animations replay unexpectedly, and the mechanism adds overhead on
  every reassembly.
- **Detection (AST, type-safe):**
  1. Match `AssignmentExpression` where the left side is a `PrefixedIdentifier` with
     `prefix.name == 'Animate'` and `identifier.name == 'restartOnHotReload'`, AND the right side
     is a `BooleanLiteral` with value `true`. Resolve `Animate` to the class from
     `package:flutter_animate/flutter_animate.dart`.
  2. Walk the ancestors to find whether the assignment is inside an `IfStatement` whose condition
     contains a reference to `kDebugMode` (from `package:flutter/foundation.dart`) or is wrapped
     in an `assert(...)` call.
  3. If not guarded, report the assignment expression.
- **Fix:** report-only. The fix is to wrap in `if (kDebugMode) { ... }` or to delete the line — the
  caller decides.
- **False positives:** Very few — this is a direct static setter assignment on a named class. The only
  legitimate `true` value is inside a `kDebugMode` guard.

---

### `flutter_animate_fixed_target_literal`

- **What/why:** The `target` parameter is designed for state-driven animation: "when the value of
  `target` changes, it will automatically animate to the new target position." Passing a numeric
  literal (e.g., `target: 1.0`) hard-codes the value to never change, so the animation will
  play once to that fixed position on mount — exactly what `autoPlay: true` (the default) already
  does. The developer almost certainly meant to pass a variable (`target: _isActive ? 1.0 : 0.0`)
  but wrote a literal instead. The runtime behavior is subtly different from `autoPlay` in edge cases
  (`target` defers the "play" until after any `delay`), but the intent mismatch is a likely bug.
- **Detection (AST, type-safe):**
  1. Match `NamedExpression` where `name.label.name == 'target'` inside an `Animate` / `.animate()`
     call.
  2. The value expression is a `DoubleLiteral`, `IntegerLiteral`, or a `PrefixExpression` with
     operator `-` on a numeric literal.
  3. Do NOT flag `ConditionalExpression`, `BinaryExpression`, `SimpleIdentifier`, `PropertyAccess`,
     or any non-literal form.
  4. Report at the `target:` named expression.
- **Fix:** report-only. The intended variable reference is unknown from the call site alone.
- **False positives:** Numeric literals `0.0` and `1.0` are the only meaningful values for `target`
  (the range is 0–1). A literal `target: 0.0` effectively says "animate to beginning on mount,"
  which might be intentional for a reveal-from-beginning effect. Severity is INFO to reflect that
  this is an intent-mismatch heuristic, not a proven bug.

---

### `flutter_animate_no_key_in_list`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** static (never-reorder) lists FP; noisy at WARNING.

- **What/why:** `Animate` is a `StatefulWidget`. When Flutter's widget reconciler replaces the widget
  in a slot (because the parent rebuilt and the widget type/identity changed), it creates a new `State`
  object, which resets and replays the animation from the beginning. Inside a `Column`, `Row`, or any
  other multi-child widget that rebuilds, every rebuild that reorders or replaces children will cause
  animations to restart unexpectedly. The fix is to assign a stable `Key` to each animated widget:
  `myWidget.animate(key: ValueKey(id)).fade()`. The flutter_animate README documents
  `key: UniqueKey()` as the mechanism to FORCE a restart on rebuild — which is the opposite of what
  most developers want and confirms that the key is load-bearing for identity.
- **Detection (AST, type-safe):**
  1. Find a `ListLiteral` (i.e., `[...]`) that is passed as the `children:` named argument to
     `Column`, `Row`, `ListView`, `Stack`, `Wrap`, or as the `children:` of `AnimateList`.
  2. Among the list elements, find any that are either:
     - An `InstanceCreationExpression` whose static type is `Animate`, without a `key:` named arg.
     - A `MethodInvocation` named `animate` (return type `Animate`) on any `Widget`, without a
       `key:` named arg on the `.animate()` call itself or on the `.animate()` chain's outermost
       widget wrapper.
  3. Report at each such element's `.animate()` call or `Animate(...)` construction.
  4. Skip when the immediate child expression already passes `key:` — e.g.,
     `MyWidget(key: k).animate().fade()` is fine because `MyWidget` carries the key.
- **Fix:** report-only. The correct key type (ValueKey, ObjectKey, etc.) depends on the item's
  identity source.
- **False positives:**
  - Lists that never reorder and are driven by a fully stable widget tree (static column with fixed
    items) are a mild FP. Severity is WARNING to allow team discretion.
  - When the parent is itself keyed (e.g., `KeyedSubtree`), Flutter can still reconcile correctly —
    but this is an uncommon pattern; the rule err on the side of flagging.
  - Skip test files via `ProjectContext.isTestFile(path)`.

---

### `flutter_animate_empty_animate_list`

- **What/why:** `AnimateList(children: [])` or `[].animate(...)` creates the wrapper machinery
  (an `AnimateList` with an internal list of `Animate` instances) over zero children. No animation
  can play, no child is rendered, and the object allocation is pure overhead. This is dead code in
  the same sense as an empty `Column(children: [])` — a sign of incomplete migration or a copy-paste
  error where items were removed but the enclosing animated list was not.
- **Detection (AST, type-safe):**
  1. Match `InstanceCreationExpression` whose static type is `AnimateList` from
     `package:flutter_animate/flutter_animate.dart`, where the `children:` named arg value is a
     `ListLiteral` with zero elements.
  2. Also match a `MethodInvocation` named `animate` on a receiver whose static type is
     `List<Widget>` (or `List<Never>`) and whose receiver is itself a `ListLiteral` with zero
     elements.
  3. Report at the `AnimateList(...)` or the `[].animate(...)` expression.
- **Fix:** report-only. Whether to populate with real children or delete the construct is the
  developer's decision.
- **False positives:** Near-zero. A literal empty-list `children` is always dead code in this context.

---

### `flutter_animate_auto_play_false_no_driver`

- **What/why:** Setting `autoPlay: false` without providing a `controller:`, `adapter:`, or `target:`
  disables the automatic `_controller.forward()` call on mount with no other mechanism to start
  playback. The animation will never run. The effect list is evaluated (effects are defined), but
  the widget is permanently at the `value` position (default `0`), which renders as the animation's
  "start" state — typically invisible if `FadeEffect` is the first effect. This is most often a
  copy-paste error where the developer set `autoPlay: false` intending to wire up a controller but
  never did.
- **Detection (AST, type-safe):**
  1. Match a named arg `autoPlay:` with a `BooleanLiteral` value `false` inside an `Animate` /
     `.animate()` call.
  2. In the same `ArgumentList`, check that NONE of `controller:`, `adapter:`, or `target:` are
     also present as named arguments.
  3. Report at the `autoPlay: false` named expression.
- **Fix:** report-only. The missing driver is caller-specific — could be a controller, a scroll
  adapter, or a `target` bound to state.
- **False positives:**
  - Sometimes `autoPlay: false` is intentional for a widget that is animated on a gesture (the
    caller calls `controller.forward()` from a GestureDetector callback) but the controller is passed
    in from a parent, not from the same constructor call — the rule correctly does NOT fire in that
    case because `controller:` is present.
  - If the controller is stored as a sibling field and start is triggered in `initState`, the rule
    may FP since it only inspects the single constructor call's argument list. Severity is INFO.

---

## Implementation note

New file: `lib/src/rules/packages/flutter_animate_rules.dart`

Register in `lib/src/rules/all_rules.dart` (packages section):
```
export 'packages/flutter_animate_rules.dart';
```

Register each rule class in `lib/saropa_lints.dart` `_allRuleFactories` list:
```dart
FlutterAnimateUnconditionalRepeatInOnPlayRule.new,
FlutterAnimateExternalControllerNotDisposedRule.new,
FlutterAnimateRestartOnHotReloadInReleaseRule.new,
FlutterAnimateFixedTargetLiteralRule.new,
FlutterAnimateNoKeyInListRule.new,
FlutterAnimateEmptyAnimateListRule.new,
FlutterAnimateAutoPlayFalseNoDriverRule.new,
```

Add to tier in `lib/src/tiers.dart`:
- **`recommendedOnlyRules`:** `flutter_animate_unconditional_repeat_in_on_play`,
  `flutter_animate_external_controller_not_disposed`,
  `flutter_animate_restart_on_hot_reload_in_release`,
  `flutter_animate_no_key_in_list`,
  `flutter_animate_empty_animate_list`
- **`professionalOnlyRules`:** `flutter_animate_fixed_target_literal`,
  `flutter_animate_auto_play_false_no_driver`

Add to `PackageImports` in `lib/src/import_utils.dart`:
```dart
static const Set<String> flutterAnimate = {'package:flutter_animate/'};
```

Every rule's `runWithReporter` must call:
```dart
if (!fileImportsPackage(node /* or any AST node */, PackageImports.flutterAnimate)) return;
```

Use `SaropaLintRule` (not `DartLintRule`) as the base class. Problem messages must start with
`[rule_name]` prefix and exceed 200 characters total. Include `correctionMessage` on every `LintCode`.
Set `impact`, `cost`, and `ruleType` fields. Tags: `const {'packages'}`.

**No `UniqueKey()` quick fix** — per project rules, no TODO-insert or no-op fixes.

---

## Sources

- [flutter_animate on pub.dev](https://pub.dev/packages/flutter_animate)
- [flutter_animate GitHub — gskinner/flutter_animate](https://github.com/gskinner/flutter_animate)
- [flutter_animate source: animate.dart (constructor, controller lifecycle, onPlay)](https://raw.githubusercontent.com/gskinner/flutter_animate/main/lib/src/animate.dart)
- [flutter_animate source: animate_list.dart](https://raw.githubusercontent.com/gskinner/flutter_animate/main/lib/src/animate_list.dart)
- [flutter_animate source: adapter.dart](https://raw.githubusercontent.com/gskinner/flutter_animate/main/lib/src/adapters/adapter.dart)
- [flutter/flutter issue #5469 — Offstage infinite animation burns battery](https://github.com/flutter/flutter/issues/5469)
- [flutter/flutter issue #128197 — Performance issues with looping animations](https://github.com/flutter/flutter/issues/128197)
- [flutter/flutter issue #57797 — AnimationController dispose leaks Ticker](https://github.com/flutter/flutter/issues/57797)
- [Flutter animations performance best practices](https://docs.flutter.dev/perf/best-practices)

---

## Finish Report (2026-06-11)

 Scope (LINTER variant): (A) Dart lint rules / analyzer plugin + (C) docs.

**Shipped.** 6 rules (unconditional_repeat_in_on_play, restart_on_hot_reload_in_release, no_key_in_list, empty_animate_list, fixed_target_literal, auto_play_false_no_driver). Dropped flutter_animate_external_controller_not_disposed (overlap with disposal rules).

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns) — that triage is honored, not skipped. Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
