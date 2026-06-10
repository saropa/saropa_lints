import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/resources/file_handling_rules.dart';

/// Tests for 15 File Handling lint rules.
///
/// Test fixtures: example/lib/file_handling/*
void main() {
  group('File Handling Rules - Rule Instantiation', () {
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
      'RequireFileExistsCheckRule',
      'require_file_exists_check',
      () => RequireFileExistsCheckRule(),
    );

    testRule(
      'RequirePdfErrorHandlingRule',
      'require_pdf_error_handling',
      () => RequirePdfErrorHandlingRule(),
    );

    testRule(
      'RequireGraphqlErrorHandlingRule',
      'require_graphql_error_handling',
      () => RequireGraphqlErrorHandlingRule(),
    );

    testRule(
      'RequireSqfliteWhereArgsRule',
      'require_sqflite_whereargs',
      () => RequireSqfliteWhereArgsRule(),
    );

    testRule(
      'RequireSqfliteTransactionRule',
      'require_sqflite_transaction',
      () => RequireSqfliteTransactionRule(),
    );

    testRule(
      'RequireSqfliteErrorHandlingRule',
      'require_sqflite_error_handling',
      () => RequireSqfliteErrorHandlingRule(),
    );

    testRule(
      'PreferSqfliteBatchRule',
      'prefer_sqflite_batch',
      () => PreferSqfliteBatchRule(),
    );

    testRule(
      'RequireSqfliteCloseRule',
      'require_sqflite_close',
      () => RequireSqfliteCloseRule(),
    );

    testRule(
      'AvoidSqfliteReservedWordsRule',
      'avoid_sqflite_reserved_words',
      () => AvoidSqfliteReservedWordsRule(),
    );

    testRule(
      'AvoidSqfliteReadAllColumnsRule',
      'avoid_sqflite_read_all_columns',
      () => AvoidSqfliteReadAllColumnsRule(),
    );

    testRule(
      'AvoidLoadingFullPdfInMemoryRule',
      'avoid_loading_full_pdf_in_memory',
      () => AvoidLoadingFullPdfInMemoryRule(),
    );

    testRule(
      'PreferSqfliteSingletonRule',
      'prefer_sqflite_singleton',
      () => PreferSqfliteSingletonRule(),
    );

    testRule(
      'PreferSqfliteColumnConstantsRule',
      'prefer_sqflite_column_constants',
      () => PreferSqfliteColumnConstantsRule(),
    );

    testRule(
      'PreferStreamingForLargeFilesRule',
      'prefer_streaming_for_large_files',
      () => PreferStreamingForLargeFilesRule(),
    );

    testRule(
      'RequireFilePathSanitizationRule',
      'require_file_path_sanitization',
      () => RequireFilePathSanitizationRule(),
    );
  });

  group('File Handling Rules - Fixture Verification', () {
    final fixtures = [
      'require_file_exists_check',
      'require_pdf_error_handling',
      'require_graphql_error_handling',
      'require_sqflite_whereargs',
      'require_sqflite_transaction',
      'require_sqflite_error_handling',
      'prefer_sqflite_batch',
      'require_sqflite_close',
      'avoid_sqflite_reserved_words',
      'avoid_sqflite_read_all_columns',
      'avoid_loading_full_pdf_in_memory',
      'prefer_sqflite_singleton',
      'prefer_sqflite_column_constants',
      'prefer_streaming_for_large_files',
      'require_file_path_sanitization',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/file_handling/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted regression assertions.
}
