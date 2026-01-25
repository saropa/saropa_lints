// ignore_for_file: unused_element, unused_field

import '../flutter_mocks.dart';

/// Test fixture for avoid_overlapping_animations rule.
///
/// Tests that the rule correctly detects overlapping animations while
/// allowing different-axis SizeTransition widgets.
class AvoidOverlappingAnimationsFixture extends StatefulWidget {
  const AvoidOverlappingAnimationsFixture({super.key});

  @override
  State<AvoidOverlappingAnimationsFixture> createState() =>
      _AvoidOverlappingAnimationsFixtureState();
}

class _AvoidOverlappingAnimationsFixtureState
    extends State<AvoidOverlappingAnimationsFixture>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _anotherAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _animation, curve: Curves.easeIn);
    _anotherAnimation =
        CurvedAnimation(parent: _animation, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _badNestedScaleTransitions(),
        _badNestedFadeTransitions(),
        _badNestedSizeTransitionsSameAxis(),
        _goodDifferentAxisSizeTransitions(),
        _goodDifferentTransitionTypes(),
        _goodDefaultAxisVsExplicitHorizontal(),
        _badDefaultAxisInExplicitVertical(),
      ],
    );
  }

  /// BAD: Nested ScaleTransition widgets conflict on 'scale' property
  Widget _badNestedScaleTransitions() {
    return ScaleTransition(
      scale: _animation,
      // expect_lint: avoid_overlapping_animations
      child: ScaleTransition(
        scale: _anotherAnimation,
        child: const Text('Conflict!'),
      ),
    );
  }

  /// BAD: Nested FadeTransition widgets conflict on 'opacity' property
  Widget _badNestedFadeTransitions() {
    return FadeTransition(
      opacity: _animation,
      // expect_lint: avoid_overlapping_animations
      child: FadeTransition(
        opacity: _anotherAnimation,
        child: const Text('Conflict!'),
      ),
    );
  }

  /// BAD: Nested SizeTransition widgets with SAME axis conflict
  Widget _badNestedSizeTransitionsSameAxis() {
    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.vertical,
      // expect_lint: avoid_overlapping_animations
      child: SizeTransition(
        sizeFactor: _anotherAnimation,
        axis: Axis.vertical, // Same axis = conflict
        child: const Text('Conflict!'),
      ),
    );
  }

  /// GOOD: SizeTransition on different axes do NOT conflict
  /// This is the false positive case that was fixed.
  Widget _goodDifferentAxisSizeTransitions() {
    // No lint expected - vertical and horizontal are different properties
    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.vertical, // Animates HEIGHT
      child: SizeTransition(
        sizeFactor: _animation,
        axis: Axis.horizontal, // Animates WIDTH - different property!
        child: const Text('No conflict'),
      ),
    );
  }

  /// GOOD: Different transition types animate different properties
  Widget _goodDifferentTransitionTypes() {
    // No lint expected - scale and opacity are different properties
    return ScaleTransition(
      scale: _animation,
      child: FadeTransition(
        opacity: _animation,
        child: const Text('No conflict'),
      ),
    );
  }

  /// GOOD: SizeTransition with default axis (vertical) and explicit horizontal
  Widget _goodDefaultAxisVsExplicitHorizontal() {
    // No lint expected - default (vertical) and horizontal are different
    return SizeTransition(
      sizeFactor: _animation,
      // axis defaults to Axis.vertical
      child: SizeTransition(
        sizeFactor: _animation,
        axis: Axis.horizontal,
        child: const Text('No conflict'),
      ),
    );
  }

  /// BAD: SizeTransition with default axis (vertical) nested in explicit vertical
  Widget _badDefaultAxisInExplicitVertical() {
    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.vertical,
      // expect_lint: avoid_overlapping_animations
      child: SizeTransition(
        sizeFactor: _anotherAnimation,
        // axis defaults to Axis.vertical - same as parent!
        child: const Text('Conflict!'),
      ),
    );
  }
}
