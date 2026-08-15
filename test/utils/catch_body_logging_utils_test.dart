import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/catch_body_logging_utils.dart';
import 'package:test/test.dart';

/// Unit tests for [catchBodyHasLoggingCall], the shared detection logic
/// used by:
/// - `require_error_logging` (flags a catch body that never logs)
/// - `avoid_catching_generic_exception` (exempts a broad `on Object`/
///   `on Exception`/`dynamic` catch whose body logs before falling back)
/// - `require_error_boundary` (exempts a `MaterialApp`/`CupertinoApp` built
///   as the fallback UI inside an already-logged catch clause)
///
/// Test fixtures for integration testing:
/// - example/lib/widget_patterns/avoid_catching_generic_exception_fixture.dart
/// - example/lib/error_handling/require_error_logging_fixture.dart
void main() {
  group('catchBodyHasLoggingCall', () {
    bool hasLoggingCall(String catchClauseSource) {
      final parsed = parseString(
        content: 'void f() { try {} $catchClauseSource }',
      );
      Block? body;
      parsed.unit.accept(
        _CatchBodyFinder((CatchClause node) => body = node.body),
      );
      return catchBodyHasLoggingCall(body!);
    }

    test('detects a bare log/print call', () {
      expect(hasLoggingCall('catch (e) { print(e); }'), isTrue);
    });

    test('detects a named crash-reporting method call', () {
      expect(
        hasLoggingCall('on Object catch (e, s) { debugException(e, s); }'),
        isTrue,
      );
    });

    test('detects a logger-receiver call not in the method name list', () {
      expect(
        hasLoggingCall(
          'on Object catch (e, s) { Crashlytics.instance.recordError(e, s); }',
        ),
        isTrue,
      );
    });

    test('detects rethrow', () {
      expect(hasLoggingCall('catch (e) { rethrow; }'), isTrue);
    });

    test('detects a bare throw', () {
      expect(hasLoggingCall('catch (e) { throw e; }'), isTrue);
    });

    test('returns false for a silently swallowed catch', () {
      expect(
        hasLoggingCall('on Object catch (e) { /* nothing */ }'),
        isFalse,
      );
    });

    test('returns false when only unrelated calls are made', () {
      expect(hasLoggingCall('catch (e) { showFallbackUi(); }'), isFalse);
    });
  });
}

class _CatchBodyFinder extends RecursiveAstVisitor<void> {
  _CatchBodyFinder(this.onCatchClause);

  final void Function(CatchClause node) onCatchClause;

  @override
  void visitCatchClause(CatchClause node) {
    onCatchClause(node);
    super.visitCatchClause(node);
  }
}
