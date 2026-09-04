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
