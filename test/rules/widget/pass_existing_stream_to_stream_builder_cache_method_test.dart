import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';
import 'package:test/test.dart';

/// Bug: plans/history/2026.06/2026.06.03/pass_existing_stream_to_stream_builder_missing_cache_method_exemption.md
///
/// `pass_existing_stream_to_stream_builder` must not fire when the stream
/// argument is a private instance method on the enclosing class AND that
/// class declares at least one `Stream<...>?` field. The combination is the
/// project's idiomatic cache-method pattern — calling the method on every
/// build does NOT recreate the stream when inputs are unchanged, because the
/// method returns the cached field. Mirrors the `FutureBuilder` sibling's
/// exemption (see pass_existing_future_to_future_builder_cache_method_test).
///
/// The implementation predicate is private (`_isCacheMethodCall` in
/// `widget/widget_lifecycle_rules.dart`). These tests mirror the predicate
/// shape against parsed AST snippets so the contract is independently
/// verified — keep this local helper in sync with the production helper.
void main() {
  /// Mirrors `PassExistingStreamToStreamBuilderRule._isCacheMethodCall`.
  /// If you change one, change the other — the test is the contract.
  bool isCacheMethodCall(MethodInvocation node) {
    final Expression? target = node.target;
    if (target != null && target is! ThisExpression) return false;
    if (!node.methodName.name.startsWith('_')) return false;

    final ClassDeclaration? cls = node.thisOrAncestorOfType<ClassDeclaration>();
    if (cls == null) return false;

    for (final ClassMember member in cls.bodyMembers) {
      if (member is! FieldDeclaration) continue;
      final TypeAnnotation? type = member.fields.type;
      if (type is NamedType &&
          type.name.lexeme == 'Stream' &&
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
    expect(
      hit,
      isNotNull,
      reason: 'call to `$methodName` not found in snippet',
    );
    return hit!;
  }

  group('pass_existing_stream_to_stream_builder cache-method opt-out', () {
    test('private method on class with Stream<T>? field IS cache pattern', () {
      // The canonical reproducer: nullable Stream field + private method.
      // Calling `_getStream(...)` returns the cached field when inputs are
      // unchanged, so the rule must not fire here.
      final unit = parseString(
        content: '''
class _State {
  Stream<List<String>?>? _cache;
  Stream<List<String>?> _getStream(List<String>? k) {
    return _cache ??= Stream<List<String>?>.value(k);
  }
  Stream<List<String>?> build() => _getStream(const <String>[]);
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_getStream')), isTrue);
    });

    test('explicit `this._x()` on class with Stream<T>? field IS cache', () {
      final unit = parseString(
        content: '''
class _State {
  Stream<String>? _cache;
  Stream<String> _watch() => _cache ??= Stream<String>.value('x');
  Stream<String> build() => this._watch();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_watch')), isTrue);
    });

    test('private method on class with NO Stream<T>? field is NOT cache', () {
      // No cache field, so the method allocates fresh on every call.
      // Rule must still fire.
      final unit = parseString(
        content: '''
class _State {
  Stream<String> _watch() => Stream<String>.value('hello');
  Stream<String> build() => _watch();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_watch')), isFalse);
    });

    test('PUBLIC method even with Stream<T>? field is NOT cache', () {
      // The private-marker (`_`) is load-bearing: a public method could come
      // from a superclass / mixin / external API and we cannot reason about
      // its body shape from project conventions.
      final unit = parseString(
        content: '''
class _State {
  Stream<String>? _cache;
  Stream<String> watch() => _cache ??= Stream<String>.value('x');
  Stream<String> build() => watch();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, 'watch')), isFalse);
    });

    test('top-level / free-function call is NOT cache', () {
      // No enclosing class — clearly not the cache-method pattern.
      final unit = parseString(
        content: '''
Stream<String> _stream() => Stream<String>.value('x');
Stream<String> build() => _stream();
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_stream')), isFalse);
    });

    test('NON-NULLABLE `Stream<T>` field alone is NOT cache', () {
      // `late final Stream<T> _x` can only be assigned once — the
      // cache-method reassignment pattern requires nullable. If the rule
      // sees only non-nullable Stream fields it has no signal that the
      // method body re-uses a cached value.
      final unit = parseString(
        content: '''
class _State {
  late final Stream<String> _cache = Stream<String>.value('x');
  Stream<String> _watch() => _cache;
  Stream<String> build() => _watch();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, '_watch')), isFalse);
    });

    test('private method on different receiver is NOT cache', () {
      // `other._watch()` is a call on a different object — even if the
      // enclosing class has a Stream field, the receiver isn't `this`.
      final unit = parseString(
        content: '''
class _Helper {
  Stream<String> watch() => Stream<String>.value('x');
}
class _State {
  Stream<String>? _cache;
  final _Helper helper = _Helper();
  Stream<String> build() => helper.watch();
}
''',
      ).unit;
      expect(isCacheMethodCall(findCall(unit, 'watch')), isFalse);
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
