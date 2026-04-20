// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unused_import
// Test fixture for: prefer_listenable_builder
// Source: lib/src/rules/ui/animation_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

/// Typed helpers — the rule keys off the static type of the `animation:`
/// argument, so we need fields with resolvable types rather than locals
/// inferred from constructor calls.
final ValueNotifier<int> _counter = ValueNotifier<int>(0);
final ChangeNotifier _notifier = ChangeNotifier();
final AnimationController _controller = AnimationController(
  vsync: null,
  duration: Duration(milliseconds: 300),
);
final CurvedAnimation _curved = CurvedAnimation(
  parent: _controller,
  curve: Curves.easeIn,
);
dynamic _opaque;

// ============================================================================
// BAD — plain Listenable passed to AnimatedBuilder
// ============================================================================

// expect_lint: prefer_listenable_builder
void _badValueNotifier() {
  AnimatedBuilder(animation: _counter, builder: (context, child) => widget);
}

// expect_lint: prefer_listenable_builder
void _badChangeNotifier() {
  AnimatedBuilder(animation: _notifier, builder: (context, child) => widget);
}

// ============================================================================
// GOOD — Animation / AnimationController / CurvedAnimation should NOT trigger
// ============================================================================

void _goodAnimationController() {
  AnimatedBuilder(animation: _controller, builder: (context, child) => widget);
}

void _goodCurvedAnimation() {
  AnimatedBuilder(animation: _curved, builder: (context, child) => widget);
}

// ============================================================================
// GOOD — unresolved / dynamic type should NOT trigger (avoid false positives)
// ============================================================================

void _goodDynamic() {
  AnimatedBuilder(animation: _opaque, builder: (context, child) => widget);
}

// ============================================================================
// GOOD — already using ListenableBuilder; rule only targets AnimatedBuilder
// ============================================================================

void _goodAlreadyListenableBuilder() {
  ListenableBuilder(animation: _counter, builder: (context, child) => widget);
}

dynamic widget;
