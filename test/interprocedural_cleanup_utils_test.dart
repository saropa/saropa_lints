import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';
import 'package:saropa_lints/src/interprocedural_cleanup_utils.dart';
import 'package:test/test.dart';

/// Tests for the interprocedural (cross-method) cleanup-tracking utility that
/// lets leak/disposal rules follow teardown moved out of `dispose()` into a
/// helper, instead of guessing that any private call forwards cleanup.

ClassDeclaration _classOf(String code) => parseString(
  content: code,
  throwIfDiagnostics: false,
).unit.declarations.whereType<ClassDeclaration>().first;

MethodDeclaration _method(ClassDeclaration c, String name) => c.bodyMembers
    .whereType<MethodDeclaration>()
    .firstWhere((MethodDeclaration m) => m.name.lexeme == name);

/// Recognizes a `.close(` call anywhere in the body source.
bool _closes(FunctionBody body) => body.toSource().contains('.close(');

void main() {
  group('reachableSameClassMethods', () {
    test('includes start and only reachable methods', () {
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { _a(); }
  void _a() {}
  void _unreached() {}
}
''');
      final Set<String> names = reachableSameClassMethods(
        _method(c, 'dispose'),
        c,
      ).map((MethodDeclaration m) => m.name.lexeme).toSet();

      expect(names, containsAll(<String>['dispose', '_a']));
      expect(names, isNot(contains('_unreached')));
    });

    test('mutually recursive helpers terminate (no infinite loop)', () {
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { _a(); }
  void _a() { _b(); }
  void _b() { _a(); }
}
''');
      final Set<String> names = reachableSameClassMethods(
        _method(c, 'dispose'),
        c,
      ).map((MethodDeclaration m) => m.name.lexeme).toSet();

      expect(names, containsAll(<String>['dispose', '_a', '_b']));
    });
  });

  group('anyReachableBody', () {
    test('finds cleanup directly in the start method', () {
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { _socket.close(); }
}
''');
      expect(anyReachableBody(_method(c, 'dispose'), c, _closes), isTrue);
    });

    test('finds cleanup in a helper called from dispose', () {
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { _teardown(); }
  void _teardown() { _socket.close(); }
}
''');
      expect(anyReachableBody(_method(c, 'dispose'), c, _closes), isTrue);
    });

    test('follows a transitive helper chain', () {
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { _a(); }
  void _a() { _b(); }
  void _b() { _socket.close(); }
}
''');
      expect(anyReachableBody(_method(c, 'dispose'), c, _closes), isTrue);
    });

    test('follows a this-prefixed helper call', () {
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { this._teardown(); }
  void _teardown() { _socket.close(); }
}
''');
      expect(anyReachableBody(_method(c, 'dispose'), c, _closes), isTrue);
    });

    test('does NOT suppress when an uncalled helper holds the cleanup', () {
      // _teardown closes, but dispose never calls it — this is a real leak and
      // must still be reported, unlike the old "any private call = cleanup"
      // heuristic which would have wrongly suppressed it.
      final ClassDeclaration c = _classOf('''
class S {
  void dispose() { _other(); }
  void _other() {}
  void _teardown() { _socket.close(); }
}
''');
      expect(anyReachableBody(_method(c, 'dispose'), c, _closes), isFalse);
    });

    test('does NOT follow a call through a field receiver', () {
      // helper.teardown() targets a field, not this; a same-named method on
      // this class must not be treated as reached (that would need the element
      // model and could leave the class).
      final ClassDeclaration c = _classOf('''
class S {
  final helper = Helper();
  void dispose() { helper.teardown(); }
  void teardown() { _socket.close(); }
}
''');
      expect(anyReachableBody(_method(c, 'dispose'), c, _closes), isFalse);
    });
  });
}
