import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';
import 'package:saropa_lints/src/fixes/config/prefer_primary_constructor_fix.dart';
import 'package:test/test.dart';

/// Tests for the `prefer_primary_constructor` quick fix's parameter-list
/// builder.
///
/// `buildPrimaryConstructorParamsSource` is pure text generation from a
/// parsed [FormalParameterList] — verified here against parsed ASTs and by
/// round-tripping the generated primary-constructor source back through
/// `parseString` (the codebase has no `ChangeBuilder`/fix-application test
/// harness, so the full [PreferPrimaryConstructorFix.compute] IDE-apply path
/// is not exercised end-to-end).
void main() {
  group('buildPrimaryConstructorParamsSource', () {
    test('positional params', () {
      final ctor = _firstConstructor('''
class SimplePoint {
  SimplePoint(this.x, this.y);
  final double x;
  final double y;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {
        'x': 'double',
        'y': 'double',
      });
      expect(result, 'final double x, final double y');
      _expectValidRewrite('class SimplePoint($result);');
    });

    test('required named params', () {
      final ctor = _firstConstructor('''
class UserProfile {
  const UserProfile({required this.id, required this.displayName});
  final String id;
  final String displayName;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {
        'id': 'String',
        'displayName': 'String',
      });
      expect(
        result,
        '{required final String id, required final String displayName}',
      );
      _expectValidRewrite('class const UserProfile($result);');
    });

    test('optional named params with defaults', () {
      final ctor = _firstConstructor('''
class Settings {
  Settings({this.timeout = 30, this.retries = 3});
  final int timeout;
  final int retries;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {
        'timeout': 'int',
        'retries': 'int',
      });
      expect(result, '{final int timeout = 30, final int retries = 3}');
      _expectValidRewrite('class Settings($result);');
    });

    test('mixed required-positional and named group', () {
      final ctor = _firstConstructor('''
class Mixed {
  Mixed(this.a, {required this.b});
  final int a;
  final int b;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {
        'a': 'int',
        'b': 'int',
      });
      expect(result, 'final int a, {required final int b}');
      _expectValidRewrite('class Mixed($result);');
    });

    test('optional positional params with defaults', () {
      final ctor = _firstConstructor('''
class Range {
  Range(this.start, [this.end = 10]);
  final int start;
  final int end;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {
        'start': 'int',
        'end': 'int',
      });
      expect(result, 'final int start, [final int end = 10]');
      _expectValidRewrite('class Range($result);');
    });

    test('nullable and generic field types are preserved verbatim', () {
      final ctor = _firstConstructor('''
class Wrapper {
  Wrapper(this.value, this.tags);
  final String? value;
  final List<int> tags;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {
        'value': 'String?',
        'tags': 'List<int>',
      });
      expect(result, 'final String? value, final List<int> tags');
      _expectValidRewrite('class Wrapper($result);');
    });

    test('returns null when a field type is missing from the map', () {
      final ctor = _firstConstructor('''
class Incomplete {
  Incomplete(this.a);
  final int a;
}
''');
      final result = buildPrimaryConstructorParamsSource(ctor.parameters, {});
      expect(result, isNull);
    });
  });
}

/// Parses [source] and returns the first constructor declaration found.
ConstructorDeclaration _firstConstructor(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final classDecl = result.unit.declarations
      .whereType<ClassDeclaration>()
      .first;
  // bodyMembers replaced .members in analyzer 13
  return classDecl.bodyMembers.whereType<ConstructorDeclaration>().first;
}

/// Asserts [rewrittenClass] parses with zero syntax errors — the ground
/// truth that the generated primary-constructor text is not just
/// string-plausible but actually valid Dart 3.13+ syntax.
void _expectValidRewrite(String rewrittenClass) {
  final result = parseString(
    content: rewrittenClass,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  expect(
    result.errors,
    isEmpty,
    reason:
        'Generated primary-constructor source failed to parse: '
        '$rewrittenClass\nErrors: ${result.errors}',
  );
}
