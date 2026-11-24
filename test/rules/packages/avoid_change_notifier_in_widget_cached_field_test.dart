import 'package:saropa_lints/src/rules/packages/provider_rules.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

/// Regression: `avoid_change_notifier_in_widget` must not fire when the
/// notifier is created via `field ??= Notifier()` on a State field (created
/// once, disposed in dispose()), but must still fire for per-build creation.
///
/// Uses explicit `new` because the unresolved syntactic pass otherwise parses
/// `Foo()` as a MethodInvocation, which the rule never inspects.
void main() {
  int count(String source) => runRuleSyntactic(
    AvoidChangeNotifierInWidgetRule(),
    source,
  ).where((d) => d.ruleName == 'avoid_change_notifier_in_widget').length;

  group('avoid_change_notifier_in_widget — ??= State cache', () {
    test('field ??= creation in build() is not reported', () {
      expect(
        count(r'''
class _S extends State<W> {
  TransformationController? _transform;
  Widget build(BuildContext context) {
    final t = _transform ??= new TransformationController(Matrix4.identity());
    return t;
  }
}
'''),
        0,
      );
    });

    test('this.field ??= creation in build() is not reported', () {
      expect(
        count(r'''
class _S extends State<W> {
  TransformationController? _transform;
  Widget build(BuildContext context) {
    this._transform ??= new TransformationController();
    return child;
  }
}
'''),
        0,
      );
    });

    test('plain creation in build() is still reported', () {
      expect(
        count(r'''
class _S extends State<W> {
  Widget build(BuildContext context) {
    final t = new TransformationController();
    return t;
  }
}
'''),
        1,
      );
    });

    test('local ??= creation in build() is still reported', () {
      // A local is rebuilt every call, so ??= does not cache anything.
      expect(
        count(r'''
class _S extends State<W> {
  Widget build(BuildContext context) {
    TransformationController? t;
    t ??= new TransformationController();
    return t;
  }
}
'''),
        1,
      );
    });

    test('??= on a name that is not a field is still reported', () {
      expect(
        count(r'''
class _S extends State<W> {
  Widget build(BuildContext context) {
    other ??= new TransformationController();
    return child;
  }
}
'''),
        1,
      );
    });
  });
}
