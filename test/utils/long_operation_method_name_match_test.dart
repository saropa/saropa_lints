/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `long_operation_method_name_match_test` (long operation method name match).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'package:saropa_lints/src/long_operation_method_name_match.dart';
import 'package:test/test.dart';

// long_operation_method_name_match: substring false positives on allowed method names.

void main() {
  group('longOperationMethodNameMatchesPattern', () {
    test('rejects importAll inside ImportAllowed-style names (regression)', () {
      expect(
        longOperationMethodNameMatchesPattern(
          '_isFacebookFriendsImportAllowedNow',
          'importAll',
        ),
        isFalse,
      );
      expect(
        longOperationMethodNameMatchesPattern(
          '_isAstronomicalCalendarImportAllowedNow',
          'importAll',
        ),
        isFalse,
      );
    });

    test('accepts real importAll token', () {
      expect(
        longOperationMethodNameMatchesPattern('importAllFromCsv', 'importAll'),
        isTrue,
      );
      expect(
        longOperationMethodNameMatchesPattern('importAll', 'importAll'),
        isTrue,
      );
    });

    test('rejects processAll on dbProcessAll helpers', () {
      expect(
        longOperationMethodNameMatchesPattern(
          'dbProcessAllContactListGroupMemberships',
          'processAll',
        ),
        isFalse,
      );
    });

    test('accepts processAll at identifier start or after camel boundary', () {
      expect(
        longOperationMethodNameMatchesPattern('processAllUsers', 'processAll'),
        isTrue,
      );
      expect(
        longOperationMethodNameMatchesPattern('myUploadFile', 'uploadFile'),
        isTrue,
      );
    });

    test('rejects exportAll inside ExportAllowed-style names', () {
      expect(
        longOperationMethodNameMatchesPattern(
          'isExportAllowedNow',
          'exportAll',
        ),
        isFalse,
      );
    });
  });
}
