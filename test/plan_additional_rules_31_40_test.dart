import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration, tier, fixture, and false-positive guard tests for
/// [plan_additional_rules_31_through_40](plan/plan_additional_rules_31_through_40.md).

/// Mirrors [DocumentIgnoresRule] bare-line detection (keep in sync).
final RegExp _bareIgnoreLineTest = RegExp(
  r'^\s*//\s*ignore(?:_for_file)?:\s*((?:[^\s,]+)(?:\s*,\s*[^\s,]+)*)\s*$',
);

/// Mirrors [DeprecatedNewInCommentReferenceRule] reference pattern.
final RegExp _deprecatedNewDocRefTest = RegExp(r'\[\s*new\s+[\w.]+\s*\]');

void main() {
  const ruleNames = <String>[
    'abstract_field_initializer',
    'abi_specific_integer_invalid',
    'annotate_redeclares',
    'deprecated_new_in_comment_reference',
    'document_ignores',
    'non_constant_map_element',
    'return_in_generator',
    'subtype_of_disallowed_type',
    'undefined_enum_constructor',
    'yield_in_non_generator',
  ];

  group('Plan 31–40 rules - registration', () {
    test('all rules are registered in allSaropaRules', () {
      final names = allSaropaRules
          .map((r) => r.code.name.toLowerCase())
          .toSet();
      for (final name in ruleNames) {
        expect(
          names.contains(name),
          isTrue,
          reason: 'Rule $name should be registered',
        );
      }
    });

    test('all rules are in essential tier', () {
      final essential = getRulesForTier('essential');
      for (final name in ruleNames) {
        expect(
          essential.contains(name),
          isTrue,
          reason: '$name should be in essential tier',
        );
      }
    });

    test('each rule resolves from getRulesFromRegistry', () {
      for (final name in ruleNames) {
        final rules = getRulesFromRegistry(<String>{name});
        expect(rules, hasLength(1), reason: name);
        expect(rules.single.code.name, name);
        expect(
          rules.single.code.problemMessage,
          contains('[$name]'),
          reason: 'problemMessage should embed code tag',
        );
        expect(
          rules.single.code.problemMessage.length,
          greaterThan(50),
          reason: 'problemMessage should be descriptive',
        );
        expect(rules.single.code.correctionMessage, isNotNull);
      }
    });

    test('rules with file pre-check patterns expose requiredPatterns', () {
      void expectPatterns(String name, List<String> expected) {
        final rule = getRulesFromRegistry(<String>{name}).single;
        expect(rule.requiredPatterns, isNotNull);
        for (final p in expected) {
          expect(rule.requiredPatterns, contains(p), reason: name);
        }
      }

      expectPatterns('abi_specific_integer_invalid', <String>[
        'AbiSpecificInteger',
      ]);
      expectPatterns('return_in_generator', <String>['async*', 'sync*']);
      expectPatterns('yield_in_non_generator', <String>['yield']);
      expectPatterns('document_ignores', <String>['ignore:']);
      expectPatterns('deprecated_new_in_comment_reference', <String>['[new ']);
    });
  });

  group('Plan 31–40 heuristics (false-positive guards)', () {
    test(
      'document_ignores: bare ignore line matches; explained line does not',
      () {
        expect(_bareIgnoreLineTest.hasMatch('// ignore: dead_code'), isTrue);
        expect(
          _bareIgnoreLineTest.hasMatch('  // ignore: dead_code  '),
          isTrue,
        );
        expect(
          _bareIgnoreLineTest.hasMatch('// ignore: dead_code -- migration'),
          isFalse,
        );
        expect(
          _bareIgnoreLineTest.hasMatch(
            '// ignore: a, b -- two rules explained',
          ),
          isFalse,
        );
        expect(
          _bareIgnoreLineTest.hasMatch('// ignore_for_file: unused_element'),
          isTrue,
        );
      },
    );

    test('deprecated_new_in_comment_reference: [new Type] only', () {
      expect(_deprecatedNewDocRefTest.hasMatch('See [new Foo] x.'), isTrue);
      expect(_deprecatedNewDocRefTest.hasMatch('[new foo.bar]'), isTrue);
      expect(_deprecatedNewDocRefTest.hasMatch('See [Foo] x.'), isFalse);
    });
  });

  group('Plan 31–40 rules - fixture', () {
    test('fixture file exists', () {
      final file = File('example/lib/plan_additional_rules_31_40_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('fixture has expect_lint for each BAD case', () {
      final file = File('example/lib/plan_additional_rules_31_40_fixture.dart');
      final content = file.readAsStringSync();
      for (final name in ruleNames) {
        expect(
          content.contains('expect_lint: $name'),
          isTrue,
          reason: 'Fixture should contain // expect_lint: $name',
        );
      }
    });

    test('fixture has exactly ten expect_lint markers', () {
      final file = File('example/lib/plan_additional_rules_31_40_fixture.dart');
      final content = file.readAsStringSync();
      final matches = RegExp(
        r'// expect_lint: \w+',
      ).allMatches(content).toList();
      expect(matches.length, equals(10));
    });

    test('GOOD section has no expect_lint markers', () {
      final file = File('example/lib/plan_additional_rules_31_40_fixture.dart');
      final lines = file.readAsStringSync().split('\n');
      final start = lines.indexWhere(
        (l) => l.contains('GOOD / false-positive guards'),
      );
      expect(start, greaterThan(-1));
      for (var i = start; i < lines.length; i++) {
        expect(
          lines[i].contains('expect_lint:'),
          isFalse,
          reason:
              'Line ${i + 1} in GOOD section must not assert a lint: ${lines[i]}',
        );
      }
    });

    test('GOOD: abstract field without initializer has no expect_lint', () {
      final content = File(
        'example/lib/plan_additional_rules_31_40_fixture.dart',
      ).readAsStringSync();
      final start = content.indexOf('abstract class _AbstractFieldOk');
      expect(start, greaterThan(-1));
      final end = content.indexOf('void _goodConstMap()');
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(slice.contains('expect_lint:'), isFalse);
    });

    test('GOOD: const map with constant if has no expect_lint', () {
      final content = File(
        'example/lib/plan_additional_rules_31_40_fixture.dart',
      ).readAsStringSync();
      final start = content.indexOf('void _goodConstMap()');
      expect(start, greaterThan(-1));
      final end = content.indexOf('Stream<int> _goodGen()');
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(slice.contains('expect_lint: non_constant_map_element'), isFalse);
    });

    test(
      'GOOD: @override redeclare has no annotate_redeclares expect_lint',
      () {
        final content = File(
          'example/lib/plan_additional_rules_31_40_fixture.dart',
        ).readAsStringSync();
        final start = content.indexOf('class _GoodRedeclareChild');
        expect(start, greaterThan(-1));
        final end = content.indexOf('/// Uses [Object]');
        expect(end, greaterThan(start));
        final slice = content.substring(start, end);
        expect(slice.contains('expect_lint: annotate_redeclares'), isFalse);
      },
    );

    test('GOOD: documented ignore line is not bare (regex)', () {
      const line = '// ignore: dead_code -- unreachable debug path';
      expect(_bareIgnoreLineTest.hasMatch(line.trimRight()), isFalse);
    });

    test('GOOD: single const AbiSpecificInteger has no expect_lint', () {
      final content = File(
        'example/lib/plan_additional_rules_31_40_fixture.dart',
      ).readAsStringSync();
      final start = content.indexOf('final class _GoodAbi');
      expect(start, greaterThan(-1));
      final tail = content.substring(start);
      expect(
        tail.contains('expect_lint: abi_specific_integer_invalid'),
        isFalse,
      );
    });
  });
}
