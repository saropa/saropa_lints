import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/architecture_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 9 Architecture lint rules.
///
/// Test fixtures: example/lib/architecture/*
// Feature folders, DDD-style boundaries, and “wrong layer” imports in fixtures.
void main() {
  group('Architecture Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidDirectDataAccessInUiRule',
      'avoid_direct_data_access_in_ui',
      () => AvoidDirectDataAccessInUiRule(),
    );
    testRule(
      'AvoidBusinessLogicInUiRule',
      'avoid_business_logic_in_ui',
      () => AvoidBusinessLogicInUiRule(),
    );
    testRule(
      'AvoidCircularDependenciesRule',
      'avoid_circular_dependencies',
      () => AvoidCircularDependenciesRule(),
    );
    testRule('AvoidGodClassRule', 'avoid_god_class', () => AvoidGodClassRule());
    testRule(
      'AvoidUiInDomainLayerRule',
      'avoid_ui_in_domain_layer',
      () => AvoidUiInDomainLayerRule(),
    );
    testRule(
      'AvoidCrossFeatureDependenciesRule',
      'avoid_cross_feature_dependencies',
      () => AvoidCrossFeatureDependenciesRule(),
    );
    testRule(
      'AvoidSingletonPatternRule',
      'avoid_singleton_pattern',
      () => AvoidSingletonPatternRule(),
    );
    testRule(
      'AvoidTouchOnlyGesturesRule',
      'avoid_touch_only_gestures',
      () => AvoidTouchOnlyGesturesRule(),
    );
    testRule(
      'AvoidCircularImportsRule',
      'avoid_circular_imports',
      () => AvoidCircularImportsRule(),
    );
  });
  group('Architecture Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/architecture');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/architecture/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
