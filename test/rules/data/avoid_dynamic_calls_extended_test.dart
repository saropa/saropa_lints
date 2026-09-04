import 'dart:io';

import 'package:saropa_lints/src/rules/data/avoid_dynamic_calls_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for the `avoid_dynamic_calls` lint rule.
///
/// Test fixture: example/lib/type_safety/avoid_dynamic_calls_fixture.dart
/// The fixture's `expect_lint` markers cover all seven detection paths this
/// rule wires up in `runWithReporter` — MethodInvocation, PropertyAccess,
/// PrefixedIdentifier, IndexExpression (including null-aware `?.`/`?[]`),
/// BinaryExpression, CascadeExpression, compound AssignmentExpression,
/// PrefixExpression/PostfixExpression, and FunctionExpressionInvocation —
/// plus the narrowed `noSuchMethod` exemption (only calls that actually
/// derive from the `Invocation` parameter are skipped). Verified against
/// the fixture with `dart run saropa_lints scan` (see CLAUDE.md /
/// `Skill(lint-rules)`); this file only pins rule metadata, per project
/// convention — `dart test` does not execute rules against fixtures.
void main() {
  group('AvoidDynamicCallsRule - Rule Instantiation', () {
    test('AvoidDynamicCallsRule', () {
      final rule = AvoidDynamicCallsRule();
      expect(rule.code.lowerCaseName, 'avoid_dynamic_calls');
      expect(rule.code.problemMessage, contains('[avoid_dynamic_calls]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('AvoidDynamicCallsRule - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/type_safety');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    test('avoid_dynamic_calls fixture exists', () {
      final file = File(
        'example/lib/type_safety/avoid_dynamic_calls_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });
}
