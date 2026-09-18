// Behavioral test for AvoidDuplicateStringLiteralsRule and
// AvoidDuplicateStringLiteralsPairRule: verifies the rules do NOT flag a
// directive URI repeated across import/export directives (Dart requires
// directive URIs to be string literals, so there is no legal way to extract
// them to a shared constant), while still firing on ordinary duplicated
// string literals in code.
//
// Regression test for: bugs/avoid_duplicate_string_literals_pair_false_positive_import_export_directive_uri.md
//
// Uses the resolved rule harness so the relative directive URI actually
// resolves against a real file (example/lib/flutter_mocks.dart), matching
// the real analyzer pipeline.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('AvoidDuplicateStringLiteralsPairRule behavior', () {
    late AvoidDuplicateStringLiteralsPairRule rule;

    setUp(() {
      rule = AvoidDuplicateStringLiteralsPairRule();
    });

    test(
      'silent when the same relative URI is used in an import and an export directive',
      () async {
        // Mirrors the reported reproducer: a processor file imports a type
        // for its own use and re-exports it for callers, so the same
        // relative URI appears once in an `import` and once in an `export`.
        final diags = await runRuleResolved(rule, '''
import '../../flutter_mocks.dart';

export '../../flutter_mocks.dart';

dynamic data;
''');
        expect(
          diags,
          isEmpty,
          reason:
              'Directive URIs are compiler-mandated string literals and '
              'cannot be extracted to a constant',
        );
      },
    );

    test('still fires on ordinary duplicated string literals', () async {
      final diags = await runRuleResolved(rule, '''
void process() {
  print('Processing data');
  print('Processing data');
}
''');
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'avoid_duplicate_string_literals_pair');
    });
  });

  group('AvoidDuplicateStringLiteralsRule behavior', () {
    late AvoidDuplicateStringLiteralsRule rule;

    setUp(() {
      rule = AvoidDuplicateStringLiteralsRule();
    });

    test(
      'silent when the same relative URI repeats across import/export directives',
      () async {
        final diags = await runRuleResolved(rule, '''
import '../../flutter_mocks.dart';
import '../../flutter_mocks.dart' as flutter_mocks;

export '../../flutter_mocks.dart';

dynamic data;
''');
        expect(
          diags,
          isEmpty,
          reason:
              'Directive URIs are compiler-mandated string literals and '
              'cannot be extracted to a constant',
        );
      },
    );

    test('still fires on ordinary duplicated string literals', () async {
      final diags = await runRuleResolved(rule, '''
void process() {
  print('Processing data');
  print('Processing data');
  print('Processing data');
}
''');
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'avoid_duplicate_string_literals');
    });
  });
}
