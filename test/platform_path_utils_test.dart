import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
// Compat extension gives us ClassBody.members under analyzer 11.
import 'package:saropa_lints/src/analyzer_compat.dart';
import 'package:saropa_lints/src/platform_path_utils.dart';
import 'package:test/test.dart';

/// Unit tests for [platformPathApis], [bodyContainsPlatformPathApi],
/// [isFromPlatformPathApi], and [isParamPassedOnlyLiteralsAtCallSites].
///
/// Coverage for:
/// - the widened Dart-SDK allowlist (Hypothesis A)
/// - the literal-only call-site check (Hypothesis B)
/// Both fixes close bugs/*_false_positive_internal_resolver_parameter.md.
void main() {
  group('platformPathApis allowlist', () {
    test('includes Flutter path_provider APIs (pre-existing)', () {
      expect(platformPathApis, contains('getApplicationDocumentsDirectory'));
      expect(platformPathApis, contains('getTemporaryDirectory'));
      expect(platformPathApis, contains('getDatabasesPath'));
    });

    test('includes Dart-SDK resolvers (v12.3.4 additions)', () {
      expect(platformPathApis, contains('resolvePackageUri'));
      expect(platformPathApis, contains('resolvedExecutable'));
      expect(platformPathApis, contains('systemTemp'));
      expect(platformPathApis, contains('Platform.script'));
      expect(platformPathApis, contains('Directory.current'));
      expect(platformPathApis, contains('File.fromUri'));
      expect(platformPathApis, contains('Directory.fromUri'));
    });
  });

  group('bodyContainsPlatformPathApi', () {
    test('substring-matches qualified receivers', () {
      // Isolate.resolvePackageUri matches via the `resolvePackageUri` token.
      expect(
        bodyContainsPlatformPathApi(
          'final uri = await Isolate.resolvePackageUri(u);',
        ),
        isTrue,
      );
      // Directory.systemTemp matches via `systemTemp`.
      expect(
        bodyContainsPlatformPathApi('final t = Directory.systemTemp.path;'),
        isTrue,
      );
      // Platform.resolvedExecutable matches via `resolvedExecutable`.
      expect(
        bodyContainsPlatformPathApi('final exe = Platform.resolvedExecutable;'),
        isTrue,
      );
    });

    test('returns false for bodies with no API reference', () {
      expect(bodyContainsPlatformPathApi('final x = foo(bar);'), isFalse);
      // Similar-looking but unlisted names do not match.
      expect(bodyContainsPlatformPathApi('final x = _resolveRoot();'), isFalse);
    });
  });

  group('isFromPlatformPathApi — intra-procedural', () {
    test('trusts when body contains a widened API name', () {
      // Top-level function body references Isolate.resolvePackageUri —
      // `resolvePackageUri` is in the allowlist, so any node inside that
      // body is trusted.
      final CompilationUnit unit = parseString(
        content: '''
Future<void> f() async {
  final uri = await Isolate.resolvePackageUri(u);
  final file = File('\${uri.path}/a');
}
''',
      ).unit;
      final FunctionDeclaration func =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          func.functionExpression.body as BlockFunctionBody;

      // Any interior node works — pick the last statement.
      final AstNode interior = body.block.statements.last;
      expect(isFromPlatformPathApi(interior), isTrue);
    });

    test('returns false when body has no API and no callers', () {
      // Top-level public function with no allowlist match anywhere.
      final CompilationUnit unit = parseString(
        content: '''
Future<void> g(String userPath) async {
  final file = File('/data/\$userPath');
}
''',
      ).unit;
      final FunctionDeclaration func =
          unit.declarations.first as FunctionDeclaration;
      final BlockFunctionBody body =
          func.functionExpression.body as BlockFunctionBody;

      expect(isFromPlatformPathApi(body.block.statements.last), isFalse);
    });
  });

  group('isParamPassedOnlyLiteralsAtCallSites — Hypothesis B', () {
    test('trusts private helper whose every call site passes a literal', () {
      final CompilationUnit unit = parseString(
        content: '''
class AssetServer {
  Future<void> sendStyle() => _send('assets/style.css');
  Future<void> sendScript() => _send('assets/bundle.js');
  Future<void> _send(String relativePath) async {
    final root = '/opt';
    final file = File('\$root/\$relativePath');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration send = cls.body.members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == '_send');
      final BlockFunctionBody body = send.body as BlockFunctionBody;

      // Any interior node inside _send serves as the query anchor.
      expect(
        isParamPassedOnlyLiteralsAtCallSites(
          body.block.statements.last,
          'relativePath',
        ),
        isTrue,
      );
    });

    test('rejects when at least one call site passes a non-literal', () {
      final CompilationUnit unit = parseString(
        content: '''
class Mixed {
  Future<void> safe() => _open('safe.css');
  Future<void> unsafe(String userInput) => _open(userInput);
  Future<void> _open(String p) async {
    final file = File('/data/\$p');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration open = cls.body.members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == '_open');
      final BlockFunctionBody body = open.body as BlockFunctionBody;

      expect(
        isParamPassedOnlyLiteralsAtCallSites(body.block.statements.last, 'p'),
        isFalse,
      );
    });

    test('rejects when zero call sites observed (conservative)', () {
      // Private but never called in this unit — cannot prove all callers
      // pass literals, so return false.
      final CompilationUnit unit = parseString(
        content: '''
class Lonely {
  Future<void> _unused(String p) async {
    final file = File('/data/\$p');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration helper =
          cls.body.members.first as MethodDeclaration;
      final BlockFunctionBody body = helper.body as BlockFunctionBody;

      expect(
        isParamPassedOnlyLiteralsAtCallSites(body.block.statements.last, 'p'),
        isFalse,
      );
    });

    test('returns false for public methods (non-underscore name)', () {
      // Only private helpers qualify — public ones could be called from
      // outside the unit with arbitrary arguments.
      final CompilationUnit unit = parseString(
        content: '''
class Pub {
  Future<void> caller() => open('lit.css');
  Future<void> open(String p) async {
    final file = File('/data/\$p');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration open = cls.body.members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == 'open');
      final BlockFunctionBody body = open.body as BlockFunctionBody;

      expect(
        isParamPassedOnlyLiteralsAtCallSites(body.block.statements.last, 'p'),
        isFalse,
      );
    });

    test('accepts AdjacentStrings of SimpleStringLiterals as literal', () {
      final CompilationUnit unit = parseString(
        content: '''
class Adj {
  Future<void> go() => _helper('a' 'b' 'c');
  Future<void> _helper(String p) async {
    final file = File('/data/\$p');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration helper = cls.body.members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == '_helper');
      final BlockFunctionBody body = helper.body as BlockFunctionBody;

      expect(
        isParamPassedOnlyLiteralsAtCallSites(body.block.statements.last, 'p'),
        isTrue,
      );
    });

    test('resolves named parameter by label, not positional index', () {
      final CompilationUnit unit = parseString(
        content: '''
class Named {
  Future<void> caller() => _helper(path: 'lit.css', count: 1);
  Future<void> _helper({required String path, required int count}) async {
    final file = File('/data/\$path');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration helper = cls.body.members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == '_helper');
      final BlockFunctionBody body = helper.body as BlockFunctionBody;

      expect(
        isParamPassedOnlyLiteralsAtCallSites(
          body.block.statements.last,
          'path',
        ),
        isTrue,
      );
    });

    test('rejects interpolated StringInterpolation with expressions', () {
      // Interpolation whose parts include runtime expressions cannot be
      // treated as a compile-time literal.
      final CompilationUnit unit = parseString(
        content: r'''
class Interp {
  Future<void> caller(String u) => _helper('pre-$u');
  Future<void> _helper(String p) async {
    final file = File('/data/$p');
  }
}
''',
      ).unit;
      final ClassDeclaration cls = unit.declarations.first as ClassDeclaration;
      final MethodDeclaration helper = cls.body.members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == '_helper');
      final BlockFunctionBody body = helper.body as BlockFunctionBody;

      expect(
        isParamPassedOnlyLiteralsAtCallSites(body.block.statements.last, 'p'),
        isFalse,
      );
    });
  });
}
