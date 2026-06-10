import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/widget/widget_lifecycle_rules.dart';
import 'package:test/test.dart';

/// WS-3 false-positive fixes for two widget-lifecycle rules. Both detections are
/// pure syntactic analysis, so they are exercised on unresolved `parseString`
/// ASTs via `@visibleForTesting` accessors (the scan CLI and most harnesses do
/// not populate resolved types).
void main() {
  group('always_remove_listener — receiver/callback normalization', () {
    String norm(String raw) =>
        AlwaysRemoveListenerRule.normalizeListenerTokenForTesting(raw);

    test('strips trailing null-assertion (!)', () {
      expect(norm('widget.notifier!'), equals('widget.notifier'));
    });

    test('strips trailing null-aware (?)', () {
      expect(norm('widget.notifier?'), equals('widget.notifier'));
    });

    test('add (!) and remove (?) of the same field normalize equal', () {
      expect(norm('widget.notifier!'), equals(norm('widget.notifier?')));
    });

    test('plain receiver is unchanged', () {
      expect(norm('controller'), equals('controller'));
    });

    test('different fields stay distinct after normalization', () {
      expect(norm('widget.a!'), isNot(equals(norm('widget.b?'))));
    });
  });

  group('avoid_context_in_initstate_dispose — only inherited lookups', () {
    // Returns the count of unsafe `context` usages the rule would report for the
    // initState body wrapping [bodyStatements].
    int unsafeCount(String bodyStatements) {
      final unit = parseString(
        content:
            '''
class _S {
  void initState() {
    $bodyStatements
  }
}
''',
        throwIfDiagnostics: false,
      ).unit;
      final finder = _MethodFinder('initState');
      unit.accept(finder);
      return AvoidContextInInitStateDisposeRule.unsafeContextUsagesForTesting(
        finder.found!,
      ).length;
    }

    test('context forwarded to an ordinary helper is safe', () {
      expect(unsafeCount('final c = resolveColor(context);'), equals(0));
    });

    test('bare capture of context is safe', () {
      expect(unsafeCount('final c = context;'), equals(0));
    });

    test('Theme.of(context) is unsafe', () {
      expect(unsafeCount('Theme.of(context);'), equals(1));
    });

    test('MediaQuery.maybeOf(context) is unsafe', () {
      expect(unsafeCount('MediaQuery.maybeOf(context);'), equals(1));
    });

    test('context.read<T>() is unsafe', () {
      expect(unsafeCount('context.read<int>();'), equals(1));
    });

    test('context.size is unsafe', () {
      expect(unsafeCount('final s = context.size;'), equals(1));
    });

    test('context inside addPostFrameCallback is safe', () {
      expect(
        unsafeCount(
          'WidgetsBinding.instance.addPostFrameCallback((_) {'
          ' Theme.of(context); });',
        ),
        equals(0),
      );
    });
  });
}

/// Finds the first method declaration named [name].
class _MethodFinder extends RecursiveAstVisitor<void> {
  _MethodFinder(this.name);
  final String name;
  MethodDeclaration? found;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (found == null && node.name.lexeme == name) {
      found = node;
    }
    super.visitMethodDeclaration(node);
  }
}
