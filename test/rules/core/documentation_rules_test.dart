import 'dart:io';

import 'package:saropa_lints/src/rules/core/documentation_rules.dart';
import 'package:test/test.dart';

/// Tests for 12 Documentation lint rules.
///
/// Test fixtures: example/lib/documentation/*
void main() {
  group('Documentation Rules - Rule Instantiation', () {
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
      'RequirePublicApiDocumentationRule',
      'require_public_api_documentation',
      () => RequirePublicApiDocumentationRule(),
    );
    testRule(
      'PreferCorrectThrowsRule',
      'prefer_correct_throws',
      () => PreferCorrectThrowsRule(),
    );
    testRule(
      'AvoidMisleadingDocumentationRule',
      'avoid_misleading_documentation',
      () => AvoidMisleadingDocumentationRule(),
    );
    testRule(
      'RequireDeprecationMessageRule',
      'require_deprecation_message',
      () => RequireDeprecationMessageRule(),
    );
    testRule(
      'RequireComplexLogicCommentsRule',
      'require_complex_logic_comments',
      () => RequireComplexLogicCommentsRule(),
    );
    testRule(
      'RequireParameterDocumentationRule',
      'require_parameter_documentation',
      () => RequireParameterDocumentationRule(),
    );
    testRule(
      'RequireReturnDocumentationRule',
      'require_return_documentation',
      () => RequireReturnDocumentationRule(),
    );
    testRule(
      'RequireExceptionDocumentationRule',
      'require_exception_documentation',
      () => RequireExceptionDocumentationRule(),
    );
    testRule(
      'RequireExampleInDocumentationRule',
      'require_example_in_documentation',
      () => RequireExampleInDocumentationRule(),
    );
    testRule(
      'VerifyDocumentedParametersExistRule',
      'verify_documented_parameters_exist',
      () => VerifyDocumentedParametersExistRule(),
    );
    testRule(
      'MissingCodeBlockLanguageInDocCommentRule',
      'missing_code_block_language_in_doc_comment',
      () => MissingCodeBlockLanguageInDocCommentRule(),
    );
    testRule(
      'UnintendedHtmlInDocCommentRule',
      'unintended_html_in_doc_comment',
      () => UnintendedHtmlInDocCommentRule(),
    );
    testRule(
      'UriDoesNotExistInDocImportRule',
      'uri_does_not_exist_in_doc_import',
      () => UriDoesNotExistInDocImportRule(),
    );
  });
  group('Documentation Rules - Fixture Verification', () {
    final fixtures = [
      'require_public_api_documentation',
      'prefer_correct_throws',
      'avoid_misleading_documentation',
      'require_deprecation_message',
      'require_complex_logic_comments',
      'require_parameter_documentation',
      'require_return_documentation',
      'require_exception_documentation',
      'require_example_in_documentation',
      'verify_documented_parameters_exist',
      'missing_code_block_language_in_doc_comment',
      'unintended_html_in_doc_comment',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/documentation/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted regression assertions.
}
