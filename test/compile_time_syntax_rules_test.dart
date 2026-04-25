import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:saropa_lints/saropa_lints.dart'
    show
        essentialRules,
        getRulesFromRegistry,
        rulesWithFixes,
        LintImpact,
        RuleType,
        SaropaLintRule;
import 'package:saropa_lints/src/rules/architecture/compile_time_syntax_rules.dart';
import 'package:test/test.dart';

/// Unit tests for compile-time syntax shape rules
/// (`lib/src/rules/architecture/compile_time_syntax_rules.dart`).
void main() {
  const ruleNames = <String>{
    'duplicate_constructor',
    'conflicting_constructor_and_static_member',
    'field_initializer_redirecting_constructor',
    'invalid_super_formal_parameter_location',
    'illegal_concrete_enum_member',
    'invalid_literal_annotation',
    'invalid_non_virtual_annotation',
    'abstract_field_initializer',
    'undefined_enum_constructor',
  };

  group('tier and registry', () {
    test('all rules are in essentialRules (not optional add-ons)', () {
      for (final n in ruleNames) {
        expect(essentialRules.contains(n), isTrue, reason: n);
      }
    });

    test('getRulesFromRegistry returns one rule per name', () {
      final rules = getRulesFromRegistry(ruleNames);
      expect(rules, hasLength(ruleNames.length));
      expect(rules.map((r) => r.code.lowerCaseName).toSet(), ruleNames);
    });
  });

  group('shared metadata', () {
    void expectErrorSeverity(SaropaLintRule r) {
      expect(
        r.code.severity,
        equals(DiagnosticSeverity.ERROR),
        reason: r.code.lowerCaseName,
      );
    }

    test('each rule: bug, medium impact, no patterns, no auto-fix', () {
      final rules = <SaropaLintRule>[
        DuplicateConstructorRule(),
        ConflictingConstructorAndStaticMemberRule(),
        FieldInitializerRedirectingConstructorRule(),
        InvalidSuperFormalParameterLocationRule(),
        IllegalConcreteEnumMemberRule(),
        InvalidLiteralAnnotationRule(),
        InvalidNonVirtualAnnotationRule(),
        AbstractFieldInitializerRule(),
        UndefinedEnumConstructorRule(),
      ];
      for (final r in rules) {
        expect(r.impact, LintImpact.medium, reason: r.code.lowerCaseName);
        expect(r.ruleType, RuleType.bug, reason: r.code.lowerCaseName);
        expect(r.requiredPatterns, isNull, reason: r.code.lowerCaseName);
        expect(r.fixGenerators, isEmpty, reason: r.code.lowerCaseName);
      }
    });

    test(
      'native-shape violations: analyzer ERROR severity (matches SDK compile errors)',
      () {
        for (final r in <SaropaLintRule>[
          DuplicateConstructorRule(),
          ConflictingConstructorAndStaticMemberRule(),
          FieldInitializerRedirectingConstructorRule(),
          InvalidSuperFormalParameterLocationRule(),
          IllegalConcreteEnumMemberRule(),
        ]) {
          expectErrorSeverity(r);
        }
      },
    );

    test(
      'annotation / enum issues: WARNING severity (invalid use, not always compile error)',
      () {
        for (final r in <SaropaLintRule>[
          InvalidLiteralAnnotationRule(),
          InvalidNonVirtualAnnotationRule(),
          AbstractFieldInitializerRule(),
          UndefinedEnumConstructorRule(),
        ]) {
          expect(
            r.code.severity,
            equals(DiagnosticSeverity.WARNING),
            reason: r.code.lowerCaseName,
          );
        }
      },
    );
  });

  group('rulesWithFixes and registration', () {
    test(
      'compile_time_syntax rules have no auto-fixes registered (shape-only)',
      () {
        for (final n in ruleNames) {
          expect(rulesWithFixes.contains(n), isFalse, reason: n);
        }
      },
    );
  });

  group('Compile-time syntax rules - Rule Instantiation', () {
    test('DuplicateConstructorRule', () {
      final rule = DuplicateConstructorRule();
      expect(rule.code.lowerCaseName, 'duplicate_constructor');
      expect(rule.code.problemMessage, contains('[duplicate_constructor]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('ConflictingConstructorAndStaticMemberRule', () {
      final rule = ConflictingConstructorAndStaticMemberRule();
      expect(
        rule.code.lowerCaseName,
        'conflicting_constructor_and_static_member',
      );
      expect(
        rule.code.problemMessage,
        contains('[conflicting_constructor_and_static_member]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('FieldInitializerRedirectingConstructorRule', () {
      final rule = FieldInitializerRedirectingConstructorRule();
      expect(
        rule.code.lowerCaseName,
        'field_initializer_redirecting_constructor',
      );
      expect(
        rule.code.problemMessage,
        contains('[field_initializer_redirecting_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('InvalidSuperFormalParameterLocationRule', () {
      final rule = InvalidSuperFormalParameterLocationRule();
      expect(
        rule.code.lowerCaseName,
        'invalid_super_formal_parameter_location',
      );
      expect(
        rule.code.problemMessage,
        contains('[invalid_super_formal_parameter_location]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('IllegalConcreteEnumMemberRule', () {
      final rule = IllegalConcreteEnumMemberRule();
      expect(rule.code.lowerCaseName, 'illegal_concrete_enum_member');
      expect(
        rule.code.problemMessage,
        contains('[illegal_concrete_enum_member]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('InvalidLiteralAnnotationRule', () {
      final rule = InvalidLiteralAnnotationRule();
      expect(rule.code.lowerCaseName, 'invalid_literal_annotation');
      expect(
        rule.code.problemMessage,
        contains('[invalid_literal_annotation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('InvalidNonVirtualAnnotationRule', () {
      final rule = InvalidNonVirtualAnnotationRule();
      expect(rule.code.lowerCaseName, 'invalid_non_virtual_annotation');
      expect(
        rule.code.problemMessage,
        contains('[invalid_non_virtual_annotation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('AbstractFieldInitializerRule', () {
      final rule = AbstractFieldInitializerRule();
      expect(rule.code.lowerCaseName, 'abstract_field_initializer');
      expect(
        rule.code.problemMessage,
        contains('[abstract_field_initializer]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('UndefinedEnumConstructorRule', () {
      final rule = UndefinedEnumConstructorRule();
      expect(rule.code.lowerCaseName, 'undefined_enum_constructor');
      expect(
        rule.code.problemMessage,
        contains('[undefined_enum_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
