import 'dart:io';

import 'package:saropa_lints/src/rules/core/document_enum_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';
import '../../support/resolved_rule_harness.dart';

/// Tests for the document_enum lint rule.
///
/// Test fixtures: example/lib/core/document_enum_fixture.dart
void main() {
  group('Document Enum Rule - Rule Instantiation', () {
    test('DocumentEnumRule', () {
      final rule = DocumentEnumRule();
      expect(rule.code.lowerCaseName, 'document_enum');
      expect(rule.code.problemMessage, contains('[document_enum]'));
      // Tightened from the weaker `greaterThan(50)` inherited from the
      // instantiation-test boilerplate: the project's own documented
      // requirement (CLAUDE.md "Problem Message Requirements") is that
      // problem messages exceed 200 chars, so the test should enforce the
      // real threshold rather than a value both the old and new message
      // trivially clear.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Document Enum Rule - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/core');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    test('document_enum fixture exists', () {
      final file = File('example/lib/core/document_enum_fixture.dart');
      expect(file.existsSync(), isTrue);
    });
  });

  // Resolved-rule-harness behavior tests: the two groups above only pin
  // rule metadata and check the fixture file exists — neither actually
  // *runs* the rule, so a detection regression would ship silently. These
  // tests close that gap by executing DocumentEnumRule against inline
  // source with full type/element resolution.
  group('Document Enum Rule - Behavior', () {
    test('fires on an undocumented public enum declaration', () async {
      final codes = await reportedRuleCodes(
        DocumentEnumRule(),
        '''
enum OrderStatus {
  /// Order has been placed but not yet shipped.
  pending,
}
''',
      );
      expect(codes, contains('document_enum'));
    });

    test('fires independently on each undocumented constant', () async {
      final diags = await runRuleResolved(
        DocumentEnumRule(),
        '''
/// Lifecycle states for a customer order.
enum OrderStatus {
  pending,
  shipped,
}
''',
      );
      // Enum declaration is documented (no fire); both constants are not
      // (one fire each) — three lines total, two of them constants.
      expect(diags.where((d) => d.ruleName == 'document_enum'), hasLength(2));
    });

    test(
      'does NOT fire when the enum and all constants are documented',
      () async {
        final codes = await reportedRuleCodes(
          DocumentEnumRule(),
          '''
/// Lifecycle states for a customer order.
enum OrderStatus {
  /// Order has been placed but not yet shipped.
  pending,

  /// Order has left the warehouse.
  shipped,
}
''',
        );
        expect(codes, isNot(contains('document_enum')));
      },
    );

    test('does NOT fire on a private enum, even when undocumented', () async {
      final codes = await reportedRuleCodes(
        DocumentEnumRule(),
        '''
enum _InternalRetryPhase {
  initial,
  backoff,
}
''',
      );
      expect(codes, isNot(contains('document_enum')));
    });

    // Locks in the ordering behavior called out as an untested false-positive
    // risk in the tier-1 quick-win Finish Report: an annotated enum constant
    // (e.g. `@Deprecated(...)`) is still recognized as documented regardless
    // of whether the `///` block precedes or follows the annotation.
    // Verified empirically against this package's pinned analyzer version —
    // if a future analyzer upgrade changes `documentationComment`
    // resolution, this test (not just the fixture) catches the regression.
    test(
      'annotated constant: doc comment BEFORE the annotation is recognized',
      () async {
        final codes = await reportedRuleCodes(
          DocumentEnumRule(),
          '''
/// Serialization-format identifiers.
enum ApiVersion {
  /// Original payload format.
  @Deprecated('Use v2 instead')
  v1,
}
''',
        );
        expect(codes, isNot(contains('document_enum')));
      },
    );

    test(
      'annotated constant: doc comment AFTER the annotation is also '
      'recognized (not a false positive)',
      () async {
        final codes = await reportedRuleCodes(
          DocumentEnumRule(),
          '''
/// Serialization-format identifiers.
enum ApiVersion {
  @Deprecated('Use v2 instead')
  /// Original payload format.
  v1,
}
''',
        );
        expect(codes, isNot(contains('document_enum')));
      },
    );

    test('annotated constant with no doc comment still fires', () async {
      final codes = await reportedRuleCodes(
        DocumentEnumRule(),
        '''
/// Serialization-format identifiers.
enum ApiVersion {
  @Deprecated('Never shipped')
  v0,
}
''',
      );
      expect(codes, contains('document_enum'));
    });
  });
}
