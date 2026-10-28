// ignore_for_file: depend_on_referenced_packages
//
// Smoke test: run every registered rule over the Dart 3.13 primary-constructor
// fixture (syntactic pass, as the scan CLI does) and fail on any rule that
// throws. Detection results are not asserted.
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../support/syntactic_rule_harness.dart';

void main() {
  test('no registered rule throws on primary-constructor syntax', () {
    final source = File(
      'example/lib/primary_constructor_fixture.dart',
    ).readAsStringSync();
    final thrown = <String>[];
    for (final rule in allSaropaRules) {
      try {
        runRuleSyntactic(rule, source);
      } on Object catch (e) {
        thrown.add(
          '${rule.code.lowerCaseName}: ${e.toString().split('\n').first}',
        );
      }
    }
    expect(thrown, isEmpty, reason: thrown.join('\n'));
  });
}
