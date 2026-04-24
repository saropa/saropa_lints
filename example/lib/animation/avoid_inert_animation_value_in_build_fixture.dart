// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: field_initializer_outside_constructor
// ignore_for_file: final_not_initialized
// ignore_for_file: not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: missing_required_argument
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: return_of_invalid_type
// ignore_for_file: return_of_invalid_type_from_closure
// ignore_for_file: body_might_complete_normally
// ignore_for_file: invalid_assignment
// ignore_for_file: unused_element_parameter
// ignore_for_file: invalid_use_of_protected_member
// Test fixture for: avoid_inert_animation_value_in_build
// Source: lib/src/rules/ui/animation_rules.dart
//
// The rule requires resolved static types — fields are typed explicitly so the
// analyzer can identify `Animation<T>` subtypes.

import 'package:saropa_lints_example/flutter_mocks.dart';

// ─── BAD: direct .value read inside build() outside any listening builder ───

class _BadDirect extends State<MyWidget> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_inert_animation_value_in_build
    return Opacity(opacity: _opacityAnimation.value, child: const Text('x'));
  }
}

// ─── BAD: read via `this._anim.value` — PropertyAccess with explicit receiver ─

class _BadThisReceiver extends State<MyWidget> with TickerProviderStateMixin {
  late final Animation<double> _opacityAnimation;

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_inert_animation_value_in_build
    return Opacity(opacity: this._opacityAnimation.value);
  }
}

// ─── BAD: inert read in a conditional — same snapshot bug ──────────────────

class _BadConditional extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_inert_animation_value_in_build
    if (_controller.value > 0.5) {
      return const Text('on');
    }
    return const Text('off');
  }
}

// ─── BAD: subtype coverage — CurvedAnimation, AnimationController, and the ──
//          result of `Tween.animate(...)` must all trigger the rule. ──────────

class _BadSubtypes extends State<MyWidget> with TickerProviderStateMixin {
  late final CurvedAnimation _curved;
  late final AnimationController _controller;
  late final Animation<double> _tweened;

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_inert_animation_value_in_build
    final double a = _curved.value;
    // expect_lint: avoid_inert_animation_value_in_build
    final double b = _controller.value;
    // expect_lint: avoid_inert_animation_value_in_build
    final double c = _tweened.value;
    return const Text('x');
  }
}

// ─── GOOD: read inside AnimatedBuilder's builder callback — live, not inert ─

class _GoodAnimatedBuilder extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext ctx, Widget? child) =>
          Opacity(opacity: _controller.value, child: child),
    );
  }
}

// ─── GOOD: read inside ListenableBuilder's builder callback ─────────────────

class _GoodListenableBuilder extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      animation: _controller,
      builder: (BuildContext ctx, Widget? child) =>
          Opacity(opacity: _controller.value, child: child),
    );
  }
}

// ─── GOOD: read inside ValueListenableBuilder's builder callback ────────────

class _GoodValueListenableBuilder extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: _controller,
      builder: (BuildContext ctx, dynamic value, Widget? child) =>
          Opacity(opacity: _controller.value, child: child),
    );
  }
}

// ─── GOOD: listening transition widgets that do NOT read .value at all ──────
//          (passes the Animation object itself — live rebuild on tick). ─────

class _GoodFadeTransition extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacityAnimation, child: const Text('x'));
  }
}

// ─── GOOD: read outside build() is out of scope for this rule ──────────────

class _GoodOutsideBuild extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double snapshotForDebug() => _controller.value; // not in build() — OK

  @override
  void didChangeDependencies() {
    final double snapshot = _controller.value; // not in build() — OK
  }

  @override
  Widget build(BuildContext context) {
    return const Text('x');
  }
}

// ─── GOOD: non-Animation types with a `.value` getter — must NOT trigger ───

class _GoodNonAnimationValue extends State<MyWidget> {
  final TextEditingController _textController = TextEditingController();
  final ValueNotifier<int> _counter = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    final String text = _textController.value;
    final int count = _counter.value;
    return const Text('x');
  }
}

// ─── GOOD: assignment to .value is a write, not an inert read ──────────────

class _GoodAssignment extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    _controller.value = 0.3; // write — rule skips
    _controller.value += 0.1; // compound assignment — rule skips
    return const Text('x');
  }
}
