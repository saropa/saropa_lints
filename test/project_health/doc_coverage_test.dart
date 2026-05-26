/// Tests public-API documentation coverage (private API ignored, null when no
/// public surface).
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:saropa_lints/src/cli/project_health/doc_coverage.dart';
import 'package:test/test.dart';

double? _cov(String code) =>
    docCoverageOf(parseString(content: code, throwIfDiagnostics: false).unit);

void main() {
  group('docCoverageOf', () {
    test('half-documented public functions yield 0.5', () {
      const code = '''
/// Documented.
void a() {}
void b() {}
''';
      expect(_cov(code), closeTo(0.5, 0.001));
    });

    test('private declarations are ignored', () {
      const code = '''
void _hidden() {}
/// Doc.
void shown() {}
''';
      expect(
        _cov(code),
        1.0,
      ); // only the public one counts, and it is documented
    });

    test('counts public methods and fields of a class', () {
      const code = '''
/// Class doc.
class C {
  int x = 0;
  /// Field doc.
  int y = 0;
  void m() {}
}
''';
      // public: C(doc), x(no), y(doc), m(no) -> 2/4
      expect(_cov(code), closeTo(0.5, 0.001));
    });

    test('null when there is no public API', () {
      expect(_cov('void _a() {} void _b() {}'), isNull);
    });
  });
}
