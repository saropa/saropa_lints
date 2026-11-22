// Resolved-analyzer regression tests for the seven review findings fixed in
// one batch (iOS large text, extension-type nullability, gesture/semantics
// ancestry, reduced motion, public State members).
//
// Flutter does not resolve in the harness, so each fixture declares minimal
// local stand-ins for the widgets involved; the rules under test match on the
// resolved element NAME, which a local class satisfies.
library;

import 'package:saropa_lints/src/rules/data/type_rules.dart';
import 'package:saropa_lints/src/rules/platforms/ios_capabilities_permissions_rules.dart';
import 'package:saropa_lints/src/rules/ui/accessibility_rules.dart';
import 'package:saropa_lints/src/rules/widget/widget_lifecycle_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

import '../support/resolved_rule_harness.dart';

/// Lines (1-based) of diagnostics reported for [code] by [rule].
Future<List<int>> _lines(SaropaLintRule rule, String code) async =>
    (await runRuleResolved(rule, code)).map((d) => d.line).toList();

void main() {
  group('require_ios_accessibility_large_text - pinned scalers', () {
    const String preamble = '''
class TextStyle {
  const TextStyle({double? fontSize});
}
class TextSpan {
  const TextSpan({TextStyle? style});
}
class TextScaler {
  const TextScaler.linear(double factor);
  static const TextScaler noScaling = TextScaler.linear(1);
}
class Text {
  const Text(String s, {TextStyle? style, TextScaler? textScaler});
  const Text.rich(TextSpan s, {TextScaler? textScaler, double? textScaleFactor});
}
''';

    Future<List<int>> run(String body) => _lines(
      RequireIosAccessibilityLargeTextRule(),
      '$preamble\nvoid f() {\n$body\n}\n',
    );

    test(
      'TextScaler.linear(1) on Text.rich is pinned off -> reported',
      () async {
        expect(
          await run(
            '  Text.rich(TextSpan(style: TextStyle(fontSize: 14)), '
            'textScaler: TextScaler.linear(1));',
          ),
          hasLength(1),
        );
      },
    );

    test('TextScaler.linear(1.0) is pinned off -> reported', () async {
      expect(
        await run(
          '  Text.rich(TextSpan(style: TextStyle(fontSize: 14)), '
          'textScaler: const TextScaler.linear(1.0));',
        ),
        hasLength(1),
      );
    });

    test(
      'textScaleFactor: 1.0 on Text.rich is pinned off -> reported',
      () async {
        expect(
          await run(
            '  Text.rich(TextSpan(style: TextStyle(fontSize: 14)), '
            'textScaleFactor: 1.0);',
          ),
          hasLength(1),
        );
      },
    );

    test('linear(1.5) still scales -> silent', () async {
      expect(
        await run(
          '  Text.rich(TextSpan(style: TextStyle(fontSize: 14)), '
          'textScaler: TextScaler.linear(1.5));',
        ),
        isEmpty,
      );
    });

    test(
      'Text.rich with no opt-out resolves to consumer Text -> silent',
      () async {
        expect(
          await run('  Text.rich(TextSpan(style: TextStyle(fontSize: 14)));'),
          isEmpty,
        );
      },
    );
  });

  group('avoid_implicitly_nullable_extension_types - representation', () {
    test('dynamic, Null and T? are nullable; int is not', () async {
      final List<int> lines = await _lines(
        AvoidImplicitlyNullableExtensionTypesRule(),
        '''
extension type A(dynamic x) {}
extension type B(Null x) {}
extension type C(int? x) {}
extension type D(int x) {}
''',
      );
      expect(lines, <int>[1, 2, 3]);
    });
  });

  group('avoid_gesture_only_interactions - semantics ancestry', () {
    const String preamble = '''
typedef Cb = void Function();
class Semantics {
  const Semantics({this.onTap, this.onLongPress, this.child});
  final Cb? onTap;
  final Cb? onLongPress;
  final Object? child;
}
class GestureDetector {
  const GestureDetector({this.onTap, this.child});
  final Cb? onTap;
  final Object? child;
}
class Box {
  const Box({this.child});
  final Object? child;
}
class Scaffold {
  const Scaffold({this.body});
  final Object? body;
}
class ListView {
  const ListView.builder({required this.itemBuilder});
  final Object? Function(int, int) itemBuilder;
}
void tap() {}
''';

    Future<List<int>> run(String body) => _lines(
      AvoidGestureOnlyInteractionsRule(),
      '$preamble\nvoid f() {\n$body\n}\n',
    );

    test('Semantics(onTap: null) does not excuse the detector', () async {
      expect(
        await run(
          '  Semantics(onTap: null, child: GestureDetector(onTap: tap));',
        ),
        hasLength(1),
      );
    });

    test('Semantics(onLongPress: null) does not excuse the detector', () async {
      expect(
        await run(
          '  Semantics(onLongPress: null, child: GestureDetector(onTap: tap));',
        ),
        hasLength(1),
      );
    });

    test('direct Semantics(onTap: fn) excuses the detector', () async {
      expect(
        await run(
          '  Semantics(onTap: tap, child: GestureDetector(onTap: tap));',
        ),
        isEmpty,
      );
    });

    test('Semantics three layers up still excuses the detector', () async {
      expect(
        await run(
          '  Semantics(onTap: tap, child: Box(child: Box(child: Box('
          'child: GestureDetector(onTap: tap)))));',
        ),
        isEmpty,
      );
    });

    test('Semantics four layers up does not excuse the detector', () async {
      expect(
        await run(
          '  Semantics(onTap: tap, child: Box(child: Box(child: Box('
          'child: Box(child: GestureDetector(onTap: tap))))));',
        ),
        hasLength(1),
      );
    });

    test('Semantics wrapping a whole Scaffold does not excuse', () async {
      expect(
        await run(
          '  Semantics(onTap: tap, child: Scaffold('
          'body: GestureDetector(onTap: tap)));',
        ),
        hasLength(1),
      );
    });

    test('Semantics above a builder closure does not excuse rows', () async {
      expect(
        await run(
          '  Semantics(onTap: tap, child: ListView.builder('
          'itemBuilder: (c, i) => GestureDetector(onTap: tap)));',
        ),
        hasLength(1),
      );
    });
  });

  group('avoid_motion_without_reduce - anchoring and Duration.zero', () {
    const String preamble = '''
class AnimatedContainer {
  const AnimatedContainer({Duration? duration});
}
const Duration unreducedMotionDuration = Duration(seconds: 1);
const Duration shouldReduceMotionDuration = Duration(seconds: 1);
bool isMotionReduced = false;
''';

    Future<List<int>> run(String body) => _lines(
      AvoidMotionWithoutReduceRule(),
      '$preamble\nvoid f() {\n$body\n}\n',
    );

    test('unreducedMotionDuration is not a reduced-motion guard', () async {
      expect(
        await run('  AnimatedContainer(duration: unreducedMotionDuration);'),
        hasLength(1),
      );
    });

    test('isMotionReduced ternary is still a guard', () async {
      expect(
        await run(
          '  AnimatedContainer(duration: isMotionReduced ? '
          'Duration.zero : unreducedMotionDuration);',
        ),
        isEmpty,
      );
    });

    test('Duration.zero and parenthesized Duration.zero are silent', () async {
      expect(
        await run('  AnimatedContainer(duration: Duration.zero);'),
        isEmpty,
      );
      expect(
        await run('  AnimatedContainer(duration: (Duration.zero));'),
        isEmpty,
      );
    });
  });

  group('reducedMotionPreferencePattern - identifier boundaries', () {
    test('rejects names that merely end in a keyword', () {
      for (final String s in <String>[
        'unreducedMotionDuration',
        'preducedMotion',
        'reduceMotionless',
      ]) {
        expect(reducedMotionPreferencePattern.hasMatch(s), isFalse, reason: s);
      }
    });

    test('accepts real guards at identifier starts and camelCase humps', () {
      for (final String s in <String>[
        'isMotionReduced',
        'shouldReduceMotion',
        'MediaQuery.of(context).disableAnimations',
        'reducedMotion',
        '_reduceMotion',
        'accessibleNavigationOf(context)',
      ]) {
        expect(reducedMotionPreferencePattern.hasMatch(s), isTrue, reason: s);
      }
    });
  });

  group('avoid_public_members_in_states - override origin', () {
    const String preamble = '''
class State<T> {}
mixin PaletteAnimationMixin<T> on State<T> {
  Object get paletteController;
}
abstract class BaseState<T> extends State<T> {
  void onData() {}
}
''';

    Future<List<int>> run(String body) =>
        _lines(AvoidPublicMembersInStatesRule(), '$preamble\n$body\n');

    test('override of a user State base class member is reported', () async {
      final String code = '''
class Sub extends BaseState<int> {
  @override
  void onData() {}
}
''';
      final List<int> lines = await run(code);
      // preamble ends on line 8; blank separator; class on line 10; method 12.
      expect(lines, hasLength(2));
      // One for BaseState.onData declaration, one for the override site.
      expect(lines.last, greaterThan(lines.first));
    });

    test('override of a mixin hook is NOT reported', () async {
      final List<int> lines = await run('''
class _S extends State<int> with PaletteAnimationMixin<int> {
  @override
  Object get paletteController => 1;
}
''');
      // Only BaseState.onData (declaration site) is reported.
      expect(lines, hasLength(1));
    });

    test('override of a dart: SDK member is NOT reported', () async {
      final List<int> lines = await run('''
class _S extends State<int> {
  @override
  String toString() => 's';
}
''');
      expect(lines, hasLength(1));
    });
  });
}
