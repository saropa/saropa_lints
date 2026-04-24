// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor
// ignore_for_file: final_not_initialized
// ignore_for_file: super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument
// ignore_for_file: undefined_named_parameter
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: not_initialized_non_nullable_instance_field
// Test fixture for: prefer_single_ticker_provider_state_mixin
// Source: lib\src\rules\ui\animation_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// ============================================================================
// BAD: Should trigger prefer_single_ticker_provider_state_mixin
// ============================================================================

// expect_lint: prefer_single_ticker_provider_state_mixin
class _BadOneController extends State<StatefulWidget>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) => Container();
}

// expect_lint: prefer_single_ticker_provider_state_mixin
// One controller alongside derived Animations — Animations are not counted.
class _BadOneControllerWithDerivedAnimations extends State<StatefulWidget>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  Widget build(BuildContext context) => Container();
}

// expect_lint: prefer_single_ticker_provider_state_mixin
// Nullable controller still counts as one controller.
class _BadNullableController extends State<StatefulWidget>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  @override
  Widget build(BuildContext context) => Container();
}

// expect_lint: prefer_single_ticker_provider_state_mixin
// Inferred-type field via `late final _c = AnimationController(...)`.
class _BadInferredController extends State<StatefulWidget>
    with TickerProviderStateMixin {
  late final _controller = AnimationController();

  @override
  Widget build(BuildContext context) => Container();
}

// ============================================================================
// GOOD: Should NOT trigger prefer_single_ticker_provider_state_mixin
// ============================================================================

// OK: Already using the Single variant.
class _GoodSingleMixin extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) => Container();
}

// OK: Two controllers — plural mixin is correct.
class _GoodTwoControllers extends State<StatefulWidget>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  @override
  Widget build(BuildContext context) => Container();
}

// OK: Three controllers — plural mixin is correct (separate rule flags 3+).
class _GoodThreeControllers extends State<StatefulWidget>
    with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final AnimationController _c3;

  @override
  Widget build(BuildContext context) => Container();
}

// OK: Zero controllers — out of scope (dead-mixin case handled elsewhere).
class _GoodZeroControllers extends State<StatefulWidget>
    with TickerProviderStateMixin {
  String _title = '';

  @override
  Widget build(BuildContext context) => Container();
}

// OK: Collection of controllers implies dynamic ticker count.
class _GoodControllerList extends State<StatefulWidget>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];

  @override
  Widget build(BuildContext context) => Container();
}

// ============================================================================
// FALSE POSITIVES: Should NOT trigger
// ============================================================================

// OK: Non-State class that happens to mix in TickerProviderStateMixin.
// The extends-State gate filters this out.
class _NotAState {
  late final AnimationController _controller;
}
