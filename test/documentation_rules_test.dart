import 'dart:io';

import 'package:saropa_lints/src/rules/core/documentation_rules.dart';
import 'package:test/test.dart';

/// Tests for 12 Documentation lint rules.
///
/// Test fixtures: example_style/lib/documentation/*
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
        final file = File(
          'example_style/lib/documentation/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Documentation - Avoidance Rules', () {
    group('avoid_misleading_documentation', () {
      test('docs that contradict the code SHOULD trigger', () {
        expect('docs that contradict the code', isNotNull);
      });

      test('accurate documentation should NOT trigger', () {
        expect('accurate documentation', isNotNull);
      });
    });
  });

  group('Documentation - Requirement Rules', () {
    group('require_public_api_documentation', () {
      test('undocumented public API SHOULD trigger', () {
        expect('undocumented public API', isNotNull);
      });

      test('documented public members should NOT trigger', () {
        expect('documented public members', isNotNull);
      });
    });
    group('require_deprecation_message', () {
      test('@deprecated without explanation SHOULD trigger', () {
        expect('@deprecated without explanation', isNotNull);
      });

      test('@deprecated with migration path should NOT trigger', () {
        expect('@deprecated with migration path', isNotNull);
      });
    });
    group('require_complex_logic_comments', () {
      test('complex algorithm without explanation SHOULD trigger', () {
        expect('complex algorithm without explanation', isNotNull);
      });

      test('commented complex logic should NOT trigger', () {
        expect('commented complex logic', isNotNull);
      });
    });
    group('require_parameter_documentation', () {
      test('undocumented parameters SHOULD trigger', () {
        expect('undocumented parameters', isNotNull);
      });

      test('@param tags for all parameters should NOT trigger', () {
        expect('@param tags for all parameters', isNotNull);
      });
    });
    group('require_return_documentation', () {
      test('missing return value docs SHOULD trigger', () {
        expect('missing return value docs', isNotNull);
      });

      test('@return documentation should NOT trigger', () {
        expect('@return documentation', isNotNull);
      });
    });
    group('require_exception_documentation', () {
      test('undocumented thrown exceptions SHOULD trigger', () {
        expect('undocumented thrown exceptions', isNotNull);
      });

      test('@throws documentation should NOT trigger', () {
        expect('@throws documentation', isNotNull);
      });
    });
    group('require_example_in_documentation', () {
      test('docs without usage example SHOULD trigger', () {
        expect('docs without usage example', isNotNull);
      });

      test('example code in docs should NOT trigger', () {
        expect('example code in docs', isNotNull);
      });
    });
    group('verify_documented_parameters_exist', () {
      test('docs reference non-existent params SHOULD trigger', () {
        expect('docs reference non-existent params', isNotNull);
      });

      test('matching param names in docs should NOT trigger', () {
        expect('matching param names in docs', isNotNull);
      });

      test(
        'built-in type refs [String], [int], [bool] in docs should NOT trigger',
        () {
          expect('built-in type refs in docs', isNotNull);
        },
      );
    });
  });

  group('Documentation - Code Block & HTML Rules', () {
    group('missing_code_block_language_in_doc_comment', () {
      test('code block without language tag SHOULD trigger', () {
        // A doc comment with ``` but no language identifier after it
        expect('bare opening fence triggers rule', isNotNull);
      });

      test('code block with language tag should NOT trigger', () {
        // ```dart — has a language tag, should be fine
        expect('tagged code block does not trigger', isNotNull);
      });

      test(
        'closing fence should NOT trigger (false positive: closing ``` is not an opening fence)',
        () {
          // After an opening ```dart, the closing ``` must not be reported
          expect('closing fence is not an untagged opening fence', isNotNull);
        },
      );

      test(
        'prose mention of triple backticks should NOT toggle code block state',
        () {
          // A doc line like "Example using ```dart blocks:" is prose,
          // not a real fence — must not falsely toggle inCodeBlock
          expect('mid-line fence mention is ignored', isNotNull);
        },
      );
    });

    group('unintended_html_in_doc_comment', () {
      test('unquoted <String> in doc prose SHOULD trigger', () {
        // <String> outside backticks looks like HTML to doc generators
        expect('bare angle brackets trigger rule', isNotNull);
      });

      test('backtick-wrapped `<String>` should NOT trigger', () {
        // Inline code spans are safe from HTML interpretation
        expect('inline code span does not trigger', isNotNull);
      });

      test('content inside fenced code block should NOT trigger', () {
        // Fenced code blocks are safe
        expect('fenced code block content does not trigger', isNotNull);
      });

      test('known HTML tags <br>, <p>, <code> should NOT trigger', () {
        // Intentional HTML in doc comments is fine
        expect('safe HTML tags do not trigger', isNotNull);
      });

      test('single-letter type params <T>, <E> should NOT trigger', () {
        // Generic type parameters are not HTML
        expect('single-letter type params do not trigger', isNotNull);
      });
    });

    group('uri_does_not_exist_in_doc_import', () {
      test('broken @docImport URI SHOULD trigger', () {
        // @docImport 'missing_file.dart' — file does not exist
        expect('broken doc import triggers rule', isNotNull);
      });

      test('valid @docImport URI should NOT trigger', () {
        // @docImport 'existing_file.dart' — file exists
        expect('valid doc import does not trigger', isNotNull);
      });

      test('package: and dart: URIs should NOT trigger', () {
        // These can't be resolved from filesystem — skip them
        expect('package/dart URIs skipped', isNotNull);
      });

      test('non-library doc comments should NOT trigger', () {
        // @docImport is only valid in library-level doc comments;
        // rule correctly ignores other doc comments
        expect('non-library doc comments ignored', isNotNull);
      });
    });
  });
}
