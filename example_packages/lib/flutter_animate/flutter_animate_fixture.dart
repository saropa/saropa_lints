// ignore_for_file: unused_local_variable, unused_element, dead_code

/// Fixture for the 6 flutter_animate lint rules.
///
/// Each section has BAD examples (marked `// expect_lint: <rule>`) and GOOD
/// examples that must NOT trigger the rule.
///
/// Mock stubs replace the real flutter_animate types so the file can be parsed
/// without the package on the classpath.  The import below is what the import
/// gate (`fileImportsPackage`) inspects syntactically.
library;

// The import gate is syntactic — just having this import is enough.
import 'package:flutter_animate/flutter_animate.dart';

// ---------------------------------------------------------------------------
// Minimal stubs (stand-ins for flutter_animate + Flutter types)
// ---------------------------------------------------------------------------

class AnimationController {
  void repeat({bool reverse = false}) {}
  void forward() {}
  void dispose() {}
}

class Widget {}

class Key {
  const Key(String value);
}

class ValueKey<T> extends Key {
  const ValueKey(T value) : super('');
}

/// Stub for `Animate` widget.
class Animate extends Widget {
  // ignore: avoid_unused_constructor_parameters
  const Animate({
    Widget? child,
    bool autoPlay = true,
    dynamic controller,
    dynamic adapter,
    double? target,
    double? value,
    void Function(AnimationController)? onPlay,
    void Function(AnimationController)? onComplete,
    Key? key,
  });

  // Stub for the `.animate()` extension (returns Animate for chaining).
  Animate fade() => this;
  Animate slide() => this;

  /// Development-only flag.  Must NOT be `true` in production without a
  /// `kDebugMode` guard.
  static bool restartOnHotReload = false;
}

/// Stub for `AnimateList` widget.
class AnimateList extends Widget {
  // ignore: avoid_unused_constructor_parameters
  const AnimateList({
    List<Widget> children = const [],
    Key? key,
  });
}

extension AnimateExtension on Widget {
  // ignore: avoid_unused_constructor_parameters
  Animate animate({
    bool autoPlay = true,
    dynamic controller,
    dynamic adapter,
    double? target,
    double? value,
    void Function(AnimationController)? onPlay,
    Key? key,
  }) =>
      Animate();
}

extension AnimateListExtension on List<Widget> {
  // ignore: avoid_unused_constructor_parameters
  AnimateList animate({Duration? interval}) => AnimateList();
}

const bool kDebugMode = bool.fromEnvironment('dart.vm.product') == false;

class Column extends Widget {
  // ignore: avoid_unused_constructor_parameters
  const Column({List<Widget> children = const []});
}

class Row extends Widget {
  // ignore: avoid_unused_constructor_parameters
  const Row({List<Widget> children = const []});
}

// ---------------------------------------------------------------------------
// 1. flutter_animate_unconditional_repeat_in_on_play
// ---------------------------------------------------------------------------

Widget get _myWidget => Widget();

// BAD: unconditional repeat.
// expect_lint: flutter_animate_unconditional_repeat_in_on_play
final badRepeat = Animate(
  onPlay: (controller) => controller.repeat(reverse: true),
  child: _myWidget,
);

// BAD: block body with unconditional repeat.
// expect_lint: flutter_animate_unconditional_repeat_in_on_play
final badRepeatBlock = Animate(
  onPlay: (controller) {
    controller.repeat();
  },
  child: _myWidget,
);

// GOOD: repeat is guarded by an if.
final goodRepeatGuarded = Animate(
  onPlay: (controller) {
    if (true) controller.repeat(reverse: true); // simplified guard
  },
  child: _myWidget,
);

// GOOD: onPlay that does NOT call repeat.
final goodRepeatNoRepeat = Animate(
  onPlay: (controller) => controller.forward(),
  child: _myWidget,
);

// ---------------------------------------------------------------------------
// 2. flutter_animate_restart_on_hot_reload_in_release
// ---------------------------------------------------------------------------

// BAD: unguarded assignment.
void badRestartOnHotReload() {
  // expect_lint: flutter_animate_restart_on_hot_reload_in_release
  Animate.restartOnHotReload = true;
}

// GOOD: guarded by kDebugMode.
void goodRestartOnHotReload() {
  if (kDebugMode) {
    Animate.restartOnHotReload = true;
  }
}

// GOOD: set to false — not flagged (rule only fires on `= true`).
void goodRestartFalse() {
  Animate.restartOnHotReload = false;
}

// ---------------------------------------------------------------------------
// 3. flutter_animate_no_key_in_list
// ---------------------------------------------------------------------------

// BAD: Animate in Column children — no key.
// expect_lint: flutter_animate_no_key_in_list
final badNoKeyInList = Column(children: [
  _myWidget.animate().fade(),
]);

// BAD: Animate constructor in Row children — no key.
// expect_lint: flutter_animate_no_key_in_list
final badAnimateCtorNoKey = Row(children: [
  Animate(child: _myWidget),
]);

// GOOD: key present on the .animate() call.
final goodKeyOnAnimate = Column(children: [
  _myWidget.animate(key: const ValueKey('a')).fade(),
]);

// ---------------------------------------------------------------------------
// 4. flutter_animate_empty_animate_list
// ---------------------------------------------------------------------------

// BAD: AnimateList with literal empty children.
// expect_lint: flutter_animate_empty_animate_list
final badEmptyAnimateList = AnimateList(children: []);

// BAD: empty list literal receiver on .animate().
// expect_lint: flutter_animate_empty_animate_list
final badEmptyListAnimate = <Widget>[].animate();

// GOOD: non-empty children.
final goodNonEmpty = AnimateList(children: [_myWidget]);

// GOOD: variable children (not a literal empty).
List<Widget> _items = [];

// ---------------------------------------------------------------------------
// 5. flutter_animate_fixed_target_literal
// ---------------------------------------------------------------------------

// BAD: target is a double literal.
// expect_lint: flutter_animate_fixed_target_literal
final badTargetDouble = _myWidget.animate(target: 1.0).fade();

// BAD: target is an integer literal.
// expect_lint: flutter_animate_fixed_target_literal
final badTargetInt = _myWidget.animate(target: 1).fade();

// BAD: target is a unary-minus numeric literal.
// expect_lint: flutter_animate_fixed_target_literal
final badTargetNegative = _myWidget.animate(target: -1.0).fade();

// GOOD: target is a conditional expression.
bool _isActive = false;
final goodTargetConditional =
    _myWidget.animate(target: _isActive ? 1.0 : 0.0).fade();

// GOOD: target is a variable.
double _targetValue = 0.5;
final goodTargetVar = _myWidget.animate(target: _targetValue).fade();

// ---------------------------------------------------------------------------
// 6. flutter_animate_auto_play_false_no_driver
// ---------------------------------------------------------------------------

// BAD: autoPlay: false with no controller/adapter/target.
// expect_lint: flutter_animate_auto_play_false_no_driver
final badAutoPlayFalseNoDriver = _myWidget.animate(autoPlay: false).fade();

// GOOD: autoPlay: false with a controller.
final _ctrl = AnimationController();
final goodAutoPlayFalseWithController =
    _myWidget.animate(autoPlay: false, controller: _ctrl).fade();

// GOOD: autoPlay: false with a target.
final goodAutoPlayFalseWithTarget =
    _myWidget.animate(autoPlay: false, target: _isActive ? 1.0 : 0.0).fade();

// GOOD: autoPlay: true (default) — not flagged.
final goodAutoPlayTrue = _myWidget.animate().fade();
