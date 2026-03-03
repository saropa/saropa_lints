import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/conditional_import_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isNativeOnlyConditionalImportTarget', () {
    test('returns false for null or empty path', () {
      expect(isNativeOnlyConditionalImportTarget(null), isFalse);
      expect(isNativeOnlyConditionalImportTarget(''), isFalse);
    });

    test('returns false for file outside a project (no pubspec)', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        final libDir = Directory(p.join(dir.path, 'lib'));
        libDir.createSync(recursive: true);
        final filePath = p.join(libDir.path, 'some.dart');
        File(filePath).writeAsStringSync('void main() {}');
        expect(isNativeOnlyConditionalImportTarget(filePath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns true when file is dart.library.io conditional import target', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(dir.path, importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''');
        final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
        expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns true when file is dart.library.ffi conditional import target', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(dir.path, importerContent: '''
import 'executor_web.dart' if (dart.library.ffi) 'executor_native.dart';
''');
        final nativePath = p.join(dir.path, 'lib', 'executor_native.dart');
        File(nativePath).writeAsStringSync('void f() {}');
        expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns false for stub file (default branch)', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(dir.path, importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''');
        final stubPath = p.join(dir.path, 'lib', 'stub.dart');
        expect(isNativeOnlyConditionalImportTarget(stubPath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns false for file in lib that is not a conditional target', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(dir.path, importerContent: '''
import 'stub.dart' if (dart.library.io) 'native_impl.dart';
''');
        final otherPath = p.join(dir.path, 'lib', 'other.dart');
        File(otherPath).writeAsStringSync('void other() {}');
        expect(isNativeOnlyConditionalImportTarget(otherPath), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('returns true when target is referenced via package URI (same package)', () {
      final dir = Directory.systemTemp.createTempSync('saropa_cond_import_');
      try {
        _createTempProject(dir.path, importerContent: '''
import 'package:test_package/stub.dart' if (dart.library.io) 'package:test_package/native_impl.dart';
''');
        final nativePath = p.join(dir.path, 'lib', 'native_impl.dart');
        expect(isNativeOnlyConditionalImportTarget(nativePath), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}

void _createTempProject(String projectRoot, {required String importerContent}) {
  final libDir = Directory(p.join(projectRoot, 'lib'));
  libDir.createSync(recursive: true);
  File(p.join(projectRoot, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
  File(p.join(libDir.path, 'stub.dart')).writeAsStringSync('void stub() {}');
  File(p.join(libDir.path, 'native_impl.dart')).writeAsStringSync('void nativeImpl() {}');
  File(p.join(libDir.path, 'importer.dart')).writeAsStringSync(importerContent);
}
