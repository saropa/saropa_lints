// Reproduction + regression tests for false-positive / false-negative fixes in
// lib/src/rules/ui/animation_rules.dart.
//
// All fixtures define LOCAL STUB classes (AnimationController, State, Animation,
// Tween, CurvedAnimation, Widget) so the resolved-analyzer oracle can resolve
// the types WITHOUT a Flutter dependency (the example fixture package has none).
// Element identity and staticType checks therefore work against these stubs.
library;

import 'package:saropa_lints/src/rules/ui/animation_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Stub declarations shared across fixtures. The rules under test match on
/// names (`State`, `AnimationController`, `Animation`, `Tween`,
/// `CurvedAnimation`) and/or static types resolved from these declarations.
const String _stubs = '''
class Widget {
  const Widget({this.child});
  final Widget? child;
}

class AnimationController {
  void dispose() {}
  void forward() {}
  void repeat() {}
  void addStatusListener(void Function(int) listener) {}
  Animation<double> get view => Animation<double>();
  double get value => 0;
}

class Animation<T> {
  T get value => throw '';
  void addStatusListener(void Function(int) listener) {}
}

class Tween<T> {
  Tween({this.begin, this.end});
  final T? begin;
  final T? end;
  Animation<T> animate(Object parent) => Animation<T>();
}

class CurvedAnimation {
  CurvedAnimation({this.parent, this.curve});
  final Object? parent;
  final Object? curve;
}

class Curves {
  static const Object easeIn = Object();
}

class State<T> {
  void initState() {}
  void dispose() {}
  void deactivate() {}
}

class AnimatedBuilder extends Widget {
  const AnimatedBuilder({this.animation, this.builder, super.child});
  final Object? animation;
  final Widget Function(Object, Widget?)? builder;
}

class Container extends Widget {
  const Container({super.child});
}
class Column extends Widget {
  const Column({this.children});
  final List<Widget>? children;
}
class Center extends Widget {
  const Center({super.child});
}
class Padding extends Widget {
  const Padding({super.child});
}
class Text extends Widget {
  const Text(this.data);
  final String data;
}
class SizedBox extends Widget {
  const SizedBox({super.child});
}
class Card extends Widget {
  const Card({super.child});
}
class ClipRRect extends Widget {
  const ClipRRect({super.child});
}
''';

void main() {
  group('require_animation_controller_dispose', () {
    test('FN: disposal via deactivate() is missed (BAD-but-silent)', () async {
      // Controller IS disposed, just in deactivate() rather than dispose().
      // Current code only scans a method literally named `dispose`.
      final codes = await reportedRuleCodes(
        RequireAnimationControllerDisposeRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  @override
  void deactivate() {
    _c.dispose();
  }
}
''',
      );
      expect(
        codes,
        isNot(contains('require_animation_controller_dispose')),
        reason: 'Disposal in deactivate() should satisfy the rule.',
      );
    });

    test('FN: disposal via helper called from dispose() is missed', () async {
      // Controller IS disposed via a helper invoked from dispose().
      final codes = await reportedRuleCodes(
        RequireAnimationControllerDisposeRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  void _disposeControllers() {
    _c.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
  }
}
''',
      );
      expect(
        codes,
        isNot(contains('require_animation_controller_dispose')),
        reason: 'Disposal via a helper called from dispose() should count.',
      );
    });

    test('BAD: controller never disposed anywhere still fires', () async {
      final codes = await reportedRuleCodes(
        RequireAnimationControllerDisposeRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  @override
  void dispose() {}
}
''',
      );
      expect(codes, contains('require_animation_controller_dispose'));
    });

    test('GOOD: direct dispose() in dispose method stays silent', () async {
      final codes = await reportedRuleCodes(
        RequireAnimationControllerDisposeRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  @override
  void dispose() {
    _c.dispose();
  }
}
''',
      );
      expect(codes, isEmpty);
    });
  });

  group('require_animation_status_listener', () {
    test('FP: this._c.forward() with this._c.addStatusListener stays silent',
        () async {
      // Same controller element, different source spellings (`_c` vs
      // `this._c`). Source-string keying treats them as two controllers and
      // wrongly fires.
      final codes = await reportedRuleCodes(
        RequireAnimationStatusListenerRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  void go() {
    this._c.addStatusListener((s) {});
    _c.forward();
  }
}
''',
      );
      expect(
        codes,
        isNot(contains('require_animation_status_listener')),
        reason: 'Listener and forward target the SAME controller element.',
      );
    });

    test('BAD: forward() with no status listener fires', () async {
      final codes = await reportedRuleCodes(
        RequireAnimationStatusListenerRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  void go() {
    _c.forward();
  }
}
''',
      );
      expect(codes, contains('require_animation_status_listener'));
    });

    test('GOOD: forward() with matching listener stays silent', () async {
      final codes = await reportedRuleCodes(
        RequireAnimationStatusListenerRule(),
        '''
$_stubs
class _S extends State<Widget> {
  AnimationController _c = AnimationController();

  void go() {
    _c.addStatusListener((s) {});
    _c.forward();
  }
}
''',
      );
      expect(codes, isEmpty);
    });
  });

  group('require_animation_curve', () {
    test('FP: animate(parent: CurvedAnimation(...)) stays silent', () async {
      // CurvedAnimation is passed as a NAMED `parent:` arg, so its arg source
      // does not start/end with "CurvedAnimation" — old check fires wrongly.
      final codes = await reportedRuleCodes(
        RequireAnimationCurveRule(),
        '''
$_stubs
Animation<double> build(AnimationController c) {
  return Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(parent: c, curve: Curves.easeIn),
  );
}
''',
      );
      expect(
        codes,
        isNot(contains('require_animation_curve')),
        reason: 'CurvedAnimation argument means a curve IS specified.',
      );
    });

    test('BAD: Tween.animate(controller) without curve fires', () async {
      final codes = await reportedRuleCodes(
        RequireAnimationCurveRule(),
        '''
$_stubs
Animation<double> build(AnimationController c) {
  return Tween<double>(begin: 0, end: 1).animate(c);
}
''',
      );
      expect(codes, contains('require_animation_curve'));
    });
  });

  group('avoid_excessive_rebuilds_animation', () {
    test('FP: non-Animation .value read does not suppress the warning',
        () async {
      // The builder has >5 static widgets. A `data.value` read where `data`
      // is NOT an Animation must not be treated as an animation-value read
      // (which would mark the wrapping widget hoistable and drop the count).
      final codes = await reportedRuleCodes(
        AvoidExcessiveRebuildsAnimationRule(),
        '''
$_stubs
class Holder {
  int get value => 0;
}
Widget build(Animation<double> anim, Holder data) {
  return AnimatedBuilder(
    animation: anim,
    builder: (ctx, ch) {
      return Container(
        child: Column(children: [
          Center(child: Padding(child: SizedBox(
            child: Card(child: Text('\${data.value}')),
          ))),
        ]),
      );
    },
  );
}
''',
      );
      expect(
        codes,
        contains('avoid_excessive_rebuilds_animation'),
        reason: 'A non-Animation .value must not suppress the count.',
      );
    });

    test('GOOD: genuine animation .value read keeps suppressing', () async {
      // The animated leaf reads anim.value; the wrapping widgets are required
      // scaffolding and must NOT be counted -> below threshold -> silent.
      final codes = await reportedRuleCodes(
        AvoidExcessiveRebuildsAnimationRule(),
        '''
$_stubs
Widget build(Animation<double> anim) {
  return AnimatedBuilder(
    animation: anim,
    builder: (ctx, ch) {
      return Container(
        child: Column(children: [
          Center(child: Padding(child: SizedBox(
            child: Card(child: Text('\${anim.value}')),
          ))),
        ]),
      );
    },
  );
}
''',
      );
      expect(codes, isEmpty);
    });
  });

  group('avoid_clip_during_animation', () {
    // The `package:flutter/` literal satisfies the rule's requiresFlutterImport
    // content gate. The URI does not resolve (no Flutter dep), so it imports no
    // symbols and does not conflict with the local stubs.
    const String flutterImport = "import 'package:flutter/widgets.dart';";

    test('FP: user class literally named AnimatedContainer stays silent',
        () async {
      // A user class named `AnimatedContainer` resolves to THIS library, not
      // package:flutter — so it must not count as the real animated widget.
      // (BAD-fires for the genuine Flutter type is out of scope for this
      // Flutter-less oracle; the resolved library guard handles it.)
      final codes = await reportedRuleCodes(
        AvoidClipDuringAnimationRule(),
        '''
$flutterImport
$_stubs
class AnimatedContainer extends Widget {
  const AnimatedContainer({super.child});
}
Widget build() {
  return AnimatedContainer(
    child: ClipRRect(child: Text('x')),
  );
}
''',
      );
      expect(
        codes,
        isNot(contains('avoid_clip_during_animation')),
        reason: 'A non-flutter user type must not count as animated ancestor.',
      );
    });

    test('FP: clip in a non-child argument stays silent', () async {
      // The clip sits in a `leading:` argument, not the animated widget's
      // rendered `child:`/`children:` subtree. Both new guards (resolved
      // library + child-subtree) independently keep this silent; verified here
      // as a regression pin against the token-only walk firing on any nesting.
      final codes = await reportedRuleCodes(
        AvoidClipDuringAnimationRule(),
        '''
$flutterImport
$_stubs
class AnimatedSize extends Widget {
  const AnimatedSize({this.leading, super.child});
  final Widget? leading;
}
Widget build() {
  return AnimatedSize(
    leading: ClipRRect(child: Text('x')),
    child: Text('body'),
  );
}
''',
      );
      expect(
        codes,
        isNot(contains('avoid_clip_during_animation')),
        reason: 'Clip outside child/children subtree must not fire.',
      );
    });

    // NOTE on BAD-fires: positively asserting a fire requires the ancestor to
    // resolve to a real `package:flutter/` animated widget. This Flutter-less
    // oracle cannot provide that — an undefined `AnimatedContainer(...)`
    // resolves to a MethodInvocation (not an InstanceCreationExpression, which
    // is the only node this rule registers), so it can never reach the report
    // site here. The real-Flutter BAD case is covered by the example fixture
    // example/lib/animation/avoid_clip_during_animation_fixture.dart. The two
    // FP tests above pin the new guards (resolved-library + child-subtree).
  });
}
