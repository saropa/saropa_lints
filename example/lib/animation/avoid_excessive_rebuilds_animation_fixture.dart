// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// Test fixture for: avoid_excessive_rebuilds_animation
// Source: lib/src/rules/ui/animation_rules.dart

import 'dart:async';

import 'package:saropa_lints_example/flutter_mocks.dart';

/// Typed fields so the rule can resolve `Animation` vs plain `Listenable`.
final AnimationController _controller = AnimationController(
  vsync: null,
  duration: const Duration(milliseconds: 300),
);
final ValueNotifier<int> _counter = ValueNotifier<int>(0);

Widget _manyKnownWidgets() {
  return Column(
    children: <Widget>[
      Row(
        children: <Widget>[
          const Text('a'),
          const Icon(null),
          const Container(),
          const SizedBox(),
        ],
      ),
      Padding(
        padding: const EdgeInsets.all(1),
        child: Stack(
          children: <Widget>[
            const Center(),
            Opacity(opacity: 1, child: Transform.rotate(angle: 0)),
          ],
        ),
      ),
    ],
  );
}

// =============================================================================
// BAD — expect_lint: avoid_excessive_rebuilds_animation
// =============================================================================

// expect_lint: avoid_excessive_rebuilds_animation
void badAnimatedBuilderHeavy() {
  AnimatedBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) => _manyKnownWidgets(),
  );
}

// expect_lint: avoid_excessive_rebuilds_animation
void badListenableBuilderHeavyWithAnimationSource() {
  ListenableBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) => _manyKnownWidgets(),
  );
}

// =============================================================================
// GOOD — should NOT trigger (non-frame-driven or small builder)
// =============================================================================

void goodListenableBuilderValueNotifierHeavy() {
  ListenableBuilder(
    animation: _counter,
    builder: (BuildContext context, Widget? child) => _manyKnownWidgets(),
  );
}

void goodFutureBuilderHeavy() {
  FutureBuilder<int>(
    future: Future<int>.value(1),
    builder: (BuildContext context, AsyncSnapshot<int> snapshot) =>
        _manyKnownWidgets(),
  );
}

void goodStreamBuilderHeavy() {
  StreamBuilder<int>(
    stream: Stream<int>.empty(),
    builder: (BuildContext context, AsyncSnapshot<int> snapshot) =>
        _manyKnownWidgets(),
  );
}

void goodValueListenableBuilderHeavy() {
  ValueListenableBuilder<int>(
    valueListenable: _counter,
    builder: (BuildContext context, int value, Widget? child) =>
        _manyKnownWidgets(),
  );
}

void goodAnimatedBuilderFewWidgets() {
  AnimatedBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) =>
        Opacity(opacity: _controller.value, child: child),
    child: const Text('x'),
  );
}

void goodAnimatedBuilderUsesChildForStaticSubtree() {
  AnimatedBuilder(
    animation: _controller,
    child: Column(
      children: <Widget>[
        const Text('a'),
        const Icon(null),
        const Container(),
        const SizedBox(),
      ],
    ),
    builder: (BuildContext context, Widget? child) =>
        Opacity(opacity: _controller.value, child: child),
  );
}

void main() {}
