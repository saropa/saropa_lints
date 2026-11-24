import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

/// Regression: avoid_undisposed_instances must credit fields disposed via a
/// for-in loop over a list literal inside dispose().
void main() {
  Set<String> run(String body) =>
      reportedRuleCodesSyntactic(AvoidUndisposedInstancesRule(), '''
import 'package:flutter/material.dart';
class W extends StatefulWidget {}
class _S extends State<W> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _city = TextEditingController();
  void _cb() {}
  @override
  void dispose() {
$body
    super.dispose();
  }
}
''', pathHint: 'lib/widgets/w.dart');

  test('fields disposed via for-in over list literal are not reported', () {
    expect(
      run(
        'for (final c in [_name, _city]) { c.removeListener(_cb); c.dispose(); }',
      ),
      isEmpty,
    );
  });

  test('loop that does not dispose the loop variable still reports', () {
    expect(
      run('for (final c in [_name, _city]) { c.removeListener(_cb); }'),
      contains('avoid_undisposed_instances'),
    );
  });

  test('field missing from the list literal still reports', () {
    expect(
      run('for (final c in [_name]) { c.dispose(); }'),
      contains('avoid_undisposed_instances'),
    );
  });
}
