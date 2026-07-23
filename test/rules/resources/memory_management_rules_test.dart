import 'dart:io';

import 'package:saropa_lints/src/rules/resources/memory_management_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 13 Memory Management lint rules.
///
/// Test fixtures: example/lib/memory_management/*
// Image cache, big blobs in state, and disposal of native/controller handles.
void main() {
  group('Memory Management Rules - Rule Instantiation', () {
    test('AvoidLargeObjectsInStateRule', () {
      final rule = AvoidLargeObjectsInStateRule();
      expect(rule.code.lowerCaseName, 'avoid_large_objects_in_state');
      expect(
        rule.code.problemMessage,
        contains('[avoid_large_objects_in_state]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireImageDisposalRule', () {
      final rule = RequireImageDisposalRule();
      expect(rule.code.lowerCaseName, 'require_image_disposal');
      expect(rule.code.problemMessage, contains('[require_image_disposal]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCapturingThisInCallbacksRule', () {
      final rule = AvoidCapturingThisInCallbacksRule();
      expect(rule.code.lowerCaseName, 'avoid_capturing_this_in_callbacks');
      expect(
        rule.code.problemMessage,
        contains('[avoid_capturing_this_in_callbacks]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireCacheEvictionPolicyRule', () {
      final rule = RequireCacheEvictionPolicyRule();
      expect(rule.code.lowerCaseName, 'require_cache_eviction_policy');
      expect(
        rule.code.problemMessage,
        contains('[require_cache_eviction_policy]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferWeakReferencesForCacheRule', () {
      final rule = PreferWeakReferencesForCacheRule();
      expect(rule.code.lowerCaseName, 'prefer_weak_references_for_cache');
      expect(
        rule.code.problemMessage,
        contains('[prefer_weak_references_for_cache]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidExpandoCircularReferencesRule', () {
      final rule = AvoidExpandoCircularReferencesRule();
      expect(rule.code.lowerCaseName, 'avoid_expando_circular_references');
      expect(
        rule.code.problemMessage,
        contains('[avoid_expando_circular_references]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidLargeIsolateCommunicationRule', () {
      final rule = AvoidLargeIsolateCommunicationRule();
      expect(rule.code.lowerCaseName, 'avoid_large_isolate_communication');
      expect(
        rule.code.problemMessage,
        contains('[avoid_large_isolate_communication]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireCacheExpirationRule', () {
      final rule = RequireCacheExpirationRule();
      expect(rule.code.lowerCaseName, 'require_cache_expiration');
      expect(rule.code.problemMessage, contains('[require_cache_expiration]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUnboundedCacheGrowthRule', () {
      final rule = AvoidUnboundedCacheGrowthRule();
      expect(rule.code.lowerCaseName, 'avoid_unbounded_cache_growth');
      expect(
        rule.code.problemMessage,
        contains('[avoid_unbounded_cache_growth]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireCacheKeyUniquenessRule', () {
      final rule = RequireCacheKeyUniquenessRule();
      expect(rule.code.lowerCaseName, 'require_cache_key_uniqueness');
      expect(
        rule.code.problemMessage,
        contains('[require_cache_key_uniqueness]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidRetainingDisposedWidgetsRule', () {
      final rule = AvoidRetainingDisposedWidgetsRule();
      expect(rule.code.lowerCaseName, 'avoid_retaining_disposed_widgets');
      expect(
        rule.code.problemMessage,
        contains('[avoid_retaining_disposed_widgets]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidClosureCaptureLeaksRule', () {
      final rule = AvoidClosureCaptureLeaksRule();
      expect(rule.code.lowerCaseName, 'avoid_closure_capture_leaks');
      expect(
        rule.code.problemMessage,
        contains('[avoid_closure_capture_leaks]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireExpandoCleanupRule', () {
      final rule = RequireExpandoCleanupRule();
      expect(rule.code.lowerCaseName, 'require_expando_cleanup');
      expect(rule.code.problemMessage, contains('[require_expando_cleanup]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Memory Management Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/memory_management');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/memory_management/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests removed; keep rule metadata and fixture checks.
}
