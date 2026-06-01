import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';
import 'package:test/test.dart';

/// Bug: plans/history/2026.06/2026.06.01/pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field.md
///
/// `pass_existing_future_to_future_builder` must not fire when the future
/// argument is a private instance method on the enclosing class AND that
/// class declares at least one `Future<...>?` field. The combination is the
/// project's idiomatic cache-method pattern — calling the method on every
/// build does NOT restart the async operation when inputs are unchanged,
/// because the method returns the cached field.
///
/// The implementation predicate is private (`_isCacheMethodCall` in
/// `widget/widget_lifecycle_rules.dart`). These tests mirror the predicate
/// shape against parsed AST snippets so the contract is independently
/// verified — keep this local helper in sync with the production helper.
void main() {
  /// Mirrors `PassExistingFutureToFutureBuilderRule._isCacheMethodCall`.
  /// If you change one, change the other — the test is the contract.
  bool isCacheMethodCall(MethodInvocation node) {
    final Expression? target = node.target;
    if (target != null && target is! ThisExpression) return false;
    if (!node.methodName.name.startsWith('_')) return false;

    final ClassDeclaration? cls = node
        .thisOrAncestorOfType<ClassDeclaration>();
    if (cls == null) return false;

    for (final ClassMember member in cls.bodyMembers) {
      if (member is! FieldDeclaration) continue;
      final TypeAnnotation? type = member.fields.type;
      if (type is NamedType &&
          type.name.lexeme == 'Future' &&
          type.question != null) {
        return true;
      }
    }
    return false;
  }

  /// Walk the parsed unit and return the first `MethodInvocation` whose
  /// method name matches [methodName].
  MethodInvocation findCall(CompilationUnit unit, String methodName) {
    MethodInvocation? hit;
    unit.visitChildren(_CallFinder(methodName, (n) => hit ??= n));
    expect(hit, isNotNull, reason: 'call to `$methodName` not found in snippet');
    return hit!;
  }

  group('pass_existing_future_to_future_builder cache-method opt-out', () {
    test('private method on class with Future<T>? field IS cache pattern', () {
      // The canonical reproducer: nullable Future field + private method.
      // Calling `_getFuture(...)` returns the cached field when inputs are
      // unchanged, so the rule must not fire here.
      final unit = parseString(
        content: '''
class _State {
  Future<List<String>?>? _cache;
  Future<List<String>?> _getFuture(List<String>? k) {
    return _cache ??= Future<List<String>?>.value(k);
  }
  Future<List<String>?> build() => _getFuture(const <String>[]);
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_getFuture')), isTrue);
    });

    test('explicit `this._x()` on class with Future<T>? field IS cache', () {
      final unit = parseString(
        content: '''
class _State {
  Future<String>? _cache;
  Future<String> _load() => _cache ??= Future<String>.value('x');
  Future<String> build() => this._load();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_load')), isTrue);
    });

    test('private method on class with NO Future<T>? field is NOT cache', () {
      // No cache field, so the method allocates fresh on every call.
      // Rule must still fire.
      final unit = parseString(
        content: '''
class _State {
  Future<String> _load() async => 'hello';
  Future<String> build() => _load();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_load')), isFalse);
    });

    test('PUBLIC method even with Future<T>? field is NOT cache', () {
      // The private-marker (`_`) is load-bearing: a public method could come
      // from a superclass / mixin / external API and we cannot reason about
      // its body shape from project conventions.
      final unit = parseString(
        content: '''
class _State {
  Future<String>? _cache;
  Future<String> load() => _cache ??= Future<String>.value('x');
  Future<String> build() => load();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, 'load')), isFalse);
    });

    test('top-level / free-function call is NOT cache', () {
      // No enclosing class — clearly not the cache-method pattern.
      final unit = parseString(
        content: '''
Future<String> _fetch() async => 'x';
Future<String> build() => _fetch();
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_fetch')), isFalse);
    });

    test('NON-NULLABLE `Future<T>` field alone is NOT cache', () {
      // `late final Future<T> _x` can only be assigned once — the
      // cache-method reassignment pattern requires nullable. If the rule
      // sees only non-nullable Future fields it has no signal that the
      // method body re-uses a cached value.
      final unit = parseString(
        content: '''
class _State {
  late final Future<String> _cache = Future<String>.value('x');
  Future<String> _load() => _cache;
  Future<String> build() => _load();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_load')), isFalse);
    });

    test('private method on different receiver is NOT cache', () {
      // `other._load()` is a call on a different object — even if the
      // enclosing class has a Future field, the receiver isn't `this`.
      final unit = parseString(
        content: '''
class _Helper {
  Future<String> load() async => 'x';
}
class _State {
  Future<String>? _cache;
  final _Helper helper = _Helper();
  Future<String> build() => helper.load();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, 'load')), isFalse);
    });
  });
}

class _CallFinder extends RecursiveAstVisitor<void> {
  _CallFinder(this.target, this.onHit);
  final String target;
  final void Function(MethodInvocation node) onHit;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == target) onHit(node);
    super.visitMethodInvocation(node);
  }
}
