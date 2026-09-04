// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: unused_field, unused_element
// Test fixture for: avoid_disposing_late_fields
// Source: lib/src/rules/architecture/avoid_disposing_late_fields_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: `_controller` is only assigned inside the `if (widget.autoPlay)`
// branch of initState(), with no else — dispose() unconditionally calls
// dispose() on it, which throws LateInitializationError when autoPlay is
// false and the branch is skipped.
class _bad1_VideoPlayerWidgetState extends State<StatefulWidget> {
  late final AnimationController _controller;

  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  // expect_lint: avoid_disposing_late_fields
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// BAD: same conditional-assignment shape, but reached via `?.dispose()` —
// the null-aware call syntax does not change the underlying
// LateInitializationError risk, since a `late` field throws on ANY access
// (including the implicit null-check performed by `?.`) before assignment.
class _bad2_StreamPlayerState extends State<StatefulWidget> {
  late final AnimationController _player;

  bool hasStream = false;

  @override
  void initState() {
    super.initState();
    if (hasStream) {
      _player = AnimationController(vsync: this);
    }
  }

  @override
  // expect_lint: avoid_disposing_late_fields
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD: `_controller` is assigned unconditionally at the top level of
// initState(), so dispose() can always safely call dispose() on it.
class _good1_VideoPlayerWidgetState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD: conditional assignment, but every branch of the if/else chain
// assigns the field — full branch coverage proves it is always set before
// dispose() runs.
class _good2_ThemedControllerState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin<StatefulWidget> {
  late final AnimationController _controller;

  bool useFastAnimation = false;

  @override
  void initState() {
    super.initState();
    if (useFastAnimation) {
      _controller = AnimationController(vsync: this, duration: null);
    } else {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD: dispose() call is itself guarded by the same condition used to
// initialize the field — the guard at the call site proves safety even
// though initialization is conditional.
class _good3_GuardedDisposeState extends State<StatefulWidget> {
  late final AnimationController _controller;

  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  void dispose() {
    if (autoPlay) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD: `late final` with an inline lazy initializer — this always
// initializes exactly once on first read and is out of this rule's scope
// (candidateFields excludes fields with a non-null initializer).
class _good4_LazyControllerState extends State<StatefulWidget> {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD: no `late` field at all — a regular nullable field with a
// null-check dispose call is a different (already-covered) pattern.
class _good5_NullableControllerState extends State<StatefulWidget> {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD (documented false negative): the field is assigned unconditionally
// by a helper method, not by a top-level assignment statement in
// initState() itself. The rule cannot see inside `_setupController()`, so
// it accepts this as "cannot prove unsafe" rather than flagging — this is
// the accepted false-negative trade-off from the class doc comment (v1
// scope accepts false negatives on helper-method delegation rather than
// risk flagging this always-safe pattern, which is exactly what happened
// before the Finish Report 2026-09-04 Priority 1 fix).
class _good6_HelperDelegationState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD (documented false negative): the field is assigned unconditionally
// inside a try/catch block, another statement shape `_branchAssigns` does
// not analyze. Same accepted trade-off as the helper-delegation case above.
class _good7_TryCatchAssignmentState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    try {
      _controller = AnimationController(vsync: this);
    } catch (_) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// BAD: arrow-bodied dispose() (`=> expr;` instead of `{ ... }`) on a
// conditionally-initialized field. Previously this whole class was
// silently skipped because the rule only accepted `BlockFunctionBody`
// dispose() implementations (Finish Report 2026-09-04, Issue: "Silent
// whole-class skip for arrow-bodied dispose()").
class _bad3_ArrowDisposeState extends State<StatefulWidget> {
  late final AnimationController _controller;

  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  // expect_lint: avoid_disposing_late_fields
  void dispose() => _controller.dispose();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD: arrow-bodied initState() with an unconditional assignment — proves
// the field is always set before dispose() runs. Previously this shape was
// only correctly handled "by luck" (every non-block initState() body was
// treated as safe regardless of what it actually did); now it is verified
// explicitly (Finish Report 2026-09-04, Issue: "Silent per-class miss for
// arrow-bodied initState()").
class _good8_ArrowInitStateState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() => _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD (documented false negative, real crash risk): the dispose() call is
// guarded by `mounted`, an unrelated condition to the field's init guard
// (`autoPlay`). `_isGuarded` accepts ANY enclosing `IfStatement` as proof
// of safety, not just one matching the initialization condition, so this
// still throws `LateInitializationError` when `autoPlay` was false — this
// is an accepted, documented false negative (Finish Report 2026-09-04,
// Concern: "Guard detection at the dispose() call site does not check that
// the guard condition matches the initialization condition"), not a fix
// target for this pass.
class _good9_MountedGuardedDisposeState extends State<StatefulWidget> {
  late final AnimationController _controller;

  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  void dispose() {
    if (mounted) {
      _controller.dispose(); // NOT actually safe — `mounted` != `autoPlay`
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// BAD: widened call-site matching now also catches `.cancel()` on a
// conditionally-initialized late `StreamSubscription`, not just
// `.dispose()` (Finish Report 2026-09-04, Priority 4: widen call-site
// matching to `.close()`/`.cancel()`).
class _bad4_ConditionalSubscriptionState extends State<StatefulWidget> {
  late final StreamSubscription<void> _subscription;

  bool listenEnabled = false;

  @override
  void initState() {
    super.initState();
    if (listenEnabled) {
      _subscription = Stream.periodic(
        const Duration(seconds: 1),
      ).listen((_) {});
    }
  }

  @override
  // expect_lint: avoid_disposing_late_fields
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD (regression case for the v2 branch-recursion fix): BOTH arms of the
// if/else initialize the field, but each does so through a private helper
// this heuristic cannot see inside. Before v2 the unanalyzable-shape
// bail-out only applied to TOP-LEVEL initState() statements — a helper call
// nested inside a branch fell through to "this branch does not assign", so
// this always-safe, fully-covered pattern was flagged. It must stay silent.
class _good10_BranchDelegationState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin<StatefulWidget> {
  late final AnimationController _controller;

  bool useAdvanced = false;

  @override
  void initState() {
    super.initState();
    if (useAdvanced) {
      _setupAdvancedController();
    } else {
      _setupBasicController();
    }
  }

  void _setupAdvancedController() {
    _controller = AnimationController(vsync: this, duration: null);
  }

  void _setupBasicController() {
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// GOOD (v2 guard widening): the dispose() call is gated by a `switch`, not
// an `if`. The author has clearly conditioned teardown on the same state
// that drove initialization; before v2 only an `IfStatement` ancestor
// counted as a guard, so switch-based teardown false-positived.
class _good11_SwitchGuardedDisposeState extends State<StatefulWidget> {
  late final AnimationController _controller;

  int mode = 0;

  @override
  void initState() {
    super.initState();
    if (mode == 1) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  void dispose() {
    switch (mode) {
      case 1:
        _controller.dispose();
        break;
      default:
        break;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// BAD (v2 cascade matching): `_controller..dispose();` is the same
// unconditional teardown of a conditionally-initialized late field as
// `_controller.dispose();`, but the cascade section carries no target of
// its own (the target lives on the enclosing CascadeExpression), so the
// target-based call matcher never saw it — a silent false negative before
// v2.
class _bad6_CascadeDisposeState extends State<StatefulWidget> {
  late final AnimationController _controller;

  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  // expect_lint: avoid_disposing_late_fields
  void dispose() {
    _controller..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// BAD: the only "assignment" to `_controller` is `??=`, which is NOT proof
// of safe unconditional initialization — `??=` reads the field before
// deciding whether to assign it, so on a genuinely uninitialized `late`
// field the read itself throws `LateInitializationError` before the
// assignment can run. Regression case for the fix in `_isPlainAssignment`
// (Finish Report 2026-09-04, Concern: "`??=` counted as a full/safe
// assignment") — this must still be flagged, not treated as initialized.
class _bad5_NullAwareAssignmentState extends State<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller ??= AnimationController(vsync: this);
  }

  @override
  // expect_lint: avoid_disposing_late_fields
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
