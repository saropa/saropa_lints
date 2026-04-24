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
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_class, undefined_setter
// ignore_for_file: body_might_complete_normally
// ignore_for_file: non_constant_list_element
// ignore_for_file: invalid_assignment
// Test fixture for: prefer_animation_controller_forward_from_zero
// Source: lib/src/rules/ui/animation_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// ============================================================================
// BAD: Should trigger prefer_animation_controller_forward_from_zero
// ============================================================================

// Canonical press-and-bounce: addStatusListener reverses on completed,
// onTap calls bare forward() — sticky on rapid re-press.
class _BadCanonical extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          // expect_lint: prefer_animation_controller_forward_from_zero
          _controller.forward();
        },
        child: Container(),
      );
}

// Three press callbacks on the same controller — each is its own site.
class _BadMultipleGestures extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          // expect_lint: prefer_animation_controller_forward_from_zero
          _controller.forward();
        },
        onLongPress: () {
          // expect_lint: prefer_animation_controller_forward_from_zero
          _controller.forward();
        },
        onDoubleTap: () {
          // expect_lint: prefer_animation_controller_forward_from_zero
          _controller.forward();
        },
        child: Container(),
      );
}

// Arrow-form gesture callback — same detection.
class _BadArrowCallback extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) => IconButton(
        // expect_lint: prefer_animation_controller_forward_from_zero
        onPressed: () => _controller.forward(),
        icon: Container(),
      );
}

// ============================================================================
// GOOD: Should NOT trigger
// ============================================================================

// Already fixed — forward(from: 0.0).
class _GoodFromZero extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _controller.forward(from: 0.0),
        child: Container(),
      );
}

// Equivalent reset-then-forward pair.
class _GoodResetThenForward extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          _controller.reset();
          _controller.forward();
        },
        child: Container(),
      );
}

// Deliberate resume from current value — user intent, not a bug.
class _GoodExplicitResume extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _controller.forward(from: _controller.value),
        child: Container(),
      );
}

// No status listener — plain forward() in a gesture is fine.
class _GoodNoStatusListener extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _controller.forward(),
        child: Container(),
      );
}

// Status listener calls reset() instead of reverse() — no sticky case.
class _GoodListenerCallsReset extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _controller.forward(),
        child: Container(),
      );
}

// forward() in initState is a one-shot entry animation, not a gesture.
class _GoodForwardInInitState extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// forward() in a non-gesture helper — v1 conservative, no call-chain follow.
class _GoodHelperMethod extends State<StatefulWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _controller.reverse();
    });
  }

  void _play() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// Listener on a DIFFERENT controller — pairing must match the receiver.
class _GoodOtherControllerListener extends State<StatefulWidget>
    with TickerProviderStateMixin {
  late final AnimationController _other = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final AnimationController _this = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void initState() {
    super.initState();
    _other.addStatusListener((status) {
      if (status == AnimationStatus.completed) _other.reverse();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _this.forward(),
        child: Container(),
      );
}

// Non-AnimationController custom type with a forward() method. Type gate
// filters this out — `forward()` on a non-controller is unrelated.
class _NotAController {
  void forward() {}
}

class _GoodNonControllerForward extends State<StatefulWidget> {
  final _NotAController _thing = _NotAController();

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _thing.forward(),
        child: Container(),
      );
}
