import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

/// Behavioral tests for the wrapping-slot false-positive fix in
/// [RequireTextOverflowHandlingRule]. `new Text(...)` is used so the parse-only
/// harness yields an InstanceCreationExpression (bare calls stay
/// MethodInvocation until resolved).
void main() {
  int count(String body) => runRuleSyntactic(
    RequireTextOverflowHandlingRule(),
    // Flutter import + widget class so the rule's widget-file gate admits it.
    "import 'package:flutter/material.dart';\n"
    'class W extends StatelessWidget { void f(String v) { $body } }',
  ).length;

  group('require_text_overflow_handling wrapping slots', () {
    test('still flags dynamic Text directly in a Row (true positive)', () {
      expect(count('Row(children: [new Text(v)]);'), 1);
    });

    test('does not flag ListTile-family title/subtitle', () {
      expect(
        count('SwitchListTile(title: new Text(v), subtitle: new Text(v));'),
        0,
      );
      expect(count('new ListTile(title: new Text(v));'), 0);
    });

    test('does not flag direct child of Expanded/Flexible in a Row', () {
      expect(count('Row(children: [Expanded(child: new Text(v))]);'), 0);
      expect(count('Row(children: [Flexible(child: new Text(v))]);'), 0);
    });

    test('still flags non-title slots of a tile (e.g. trailing)', () {
      expect(count('ListTile(trailing: new Text(v));'), 1);
    });
  });
}
