import 'package:saropa_lints/src/long_operation_method_name_match.dart';
import 'package:test/test.dart';

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
