import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/avoid_disposing_late_fields_rules.dart';
import 'package:test/test.dart';

/// Tests for the `avoid_disposing_late_fields` lint rule.
///
/// Test fixture: example/lib/architecture/avoid_disposing_late_fields_fixture.dart
void main() {
  group('AvoidDisposingLateFieldsRule - Rule Instantiation', () {
    test('AvoidDisposingLateFieldsRule', () {
      final rule = AvoidDisposingLateFieldsRule();
      expect(rule.code.lowerCaseName, 'avoid_disposing_late_fields');
      expect(
        rule.code.problemMessage,
        contains('[avoid_disposing_late_fields]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('avoid_disposing_late_fields - Fixture Verification', () {
    const path =
        'example/lib/architecture/avoid_disposing_late_fields_fixture.dart';

    test('fixture exists', () {
      expect(File(path).existsSync(), isTrue, reason: 'Fixture must exist');
    });

    test('fixture has exactly five BAD (expect_lint) cases', () {
      final content = File(path).readAsStringSync();
      final count = RegExp(
        r'// expect_lint: avoid_disposing_late_fields',
      ).allMatches(content).length;
      expect(
        count,
        5,
        reason:
            'Five BAD cases should declare expect_lint: plain dispose(), '
            'null-aware dispose(), arrow-bodied dispose(), widened '
            '.cancel() matching, and a `??=` assignment that is not proof '
            'of safe initialization',
      );
    });

    test(
      'fixture GOOD cases cover unconditional init, full branch coverage, '
      'guarded dispose, lazy init, nullable field near-misses, arrow-bodied '
      'initState(), and the accepted false-negative trade-offs (helper-'
      'method delegation, try/catch assignment, mismatched dispose guard)',
      () {
        final content = File(path).readAsStringSync();
        expect(content.contains('_good1_VideoPlayerWidgetState'), isTrue);
        expect(content.contains('_good2_ThemedControllerState'), isTrue);
        expect(content.contains('_good3_GuardedDisposeState'), isTrue);
        expect(content.contains('_good4_LazyControllerState'), isTrue);
        expect(content.contains('_good5_NullableControllerState'), isTrue);
        expect(content.contains('_good6_HelperDelegationState'), isTrue);
        expect(content.contains('_good7_TryCatchAssignmentState'), isTrue);
        expect(content.contains('_good8_ArrowInitStateState'), isTrue);
        expect(content.contains('_good9_MountedGuardedDisposeState'), isTrue);
      },
    );

    test(
      'fixture BAD cases cover arrow-bodied dispose(), widened .cancel() '
      'matching, and rejection of `??=` as safe initialization',
      () {
        final content = File(path).readAsStringSync();
        expect(content.contains('_bad3_ArrowDisposeState'), isTrue);
        expect(
          content.contains('_bad4_ConditionalSubscriptionState'),
          isTrue,
        );
        expect(content.contains('_bad5_NullAwareAssignmentState'), isTrue);
      },
    );
  });
}
