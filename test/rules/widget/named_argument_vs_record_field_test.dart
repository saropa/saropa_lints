// Analyzer 14 split `NamedExpression` into `NamedArgument` (call arguments)
// and `RecordLiteralNamedField` (record fields). Rules that match a named
// argument by name (shrinkWrap, itemBuilder, onPanEnd, ...) must keep firing
// on a call argument and must NOT fire on a record field with the same name.
//
// Syntactic rules only: Flutter types are unresolved in the harness, which is
// fine because these rules match on type names, not resolved types.
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

class _Case {
  _Case(this.name, this.rule, this.call, this.record);
  final String name;
  final SaropaLintRule Function() rule;

  /// Fixture where the named argument is a real call argument (must report).
  final String call;

  /// Same name used as a record field (must stay silent).
  final String record;
}

void main() {
  final cases = <_Case>[
    _Case(
      'AvoidShrinkWrapExpensiveRule (shrinkWrap)',
      () => AvoidShrinkWrapExpensiveRule(),
      'void f() { ListView(shrinkWrap: true); }',
      'void f() { ListView(children: [(shrinkWrap: true)]); }',
    ),
    _Case(
      'AvoidSemanticsExclusionRule (excludeFromSemantics)',
      () => AvoidSemanticsExclusionRule(),
      'void f() { Image(excludeFromSemantics: true); }',
      'void f() { Image(child: (excludeFromSemantics: true)); }',
    ),
    _Case(
      'AvoidAutoplayAudioRule (autoPlay)',
      () => AvoidAutoplayAudioRule(),
      'void f() { Player(autoPlay: true); }',
      'void f() { Player(child: (autoPlay: true)); }',
    ),
    _Case(
      'AvoidExcessiveBottomNavItemsRule (items)',
      () => AvoidExcessiveBottomNavItemsRule(),
      'void f() { BottomNavigationBar(items: [1, 2, 3, 4, 5, 6, 7, 8]); }',
      'void f() { BottomNavigationBar(child: (items: [1, 2, 3, 4, 5, 6, 7, 8])); }',
    ),
    _Case(
      'PreferPhysicsSimulationRule (onPanEnd)',
      () => PreferPhysicsSimulationRule(),
      'void f(c) { GestureDetector(onPanEnd: (d) { c.animateTo(0); }); }',
      'void f(c) { GestureDetector(child: (onPanEnd: (d) { c.animateTo(0); })); }',
    ),
    _Case(
      'AvoidBuilderIndexOutOfBoundsRule (itemBuilder)',
      () => AvoidBuilderIndexOutOfBoundsRule(),
      "class W extends StatelessWidget {}\nvoid f(List<int> items) { ListView.builder(itemBuilder: (c, index) => items[index]); }",
      "class W extends StatelessWidget {}\nvoid f(List<int> items) { ListView.builder(child: (itemBuilder: (c, index) => items[index])); }",
    ),
  ];

  for (final c in cases) {
    group(c.name, () {
      test('fires on a call argument', () async {
        final diags = await runRuleResolved(c.rule(), c.call);
        expect(diags, isNotEmpty);
      });

      test(
        'does not fire on a record-literal field of the same name',
        () async {
          final diags = await runRuleResolved(c.rule(), c.record);
          expect(diags, isEmpty);
        },
      );
    });
  }
}
