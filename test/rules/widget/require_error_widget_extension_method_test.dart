import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

/// Bug: bugs/require_error_widget_false_positive_extension_method_error_handling.md
///
/// `require_error_widget` must treat a FutureBuilder/StreamBuilder builder
/// as handling errors when it (a) inspects `.hasError`/`.error`/`.stackTrace`
/// inline, (b) invokes any method on the snapshot parameter (delegated
/// helper), or (c) invokes a method whose name itself contains `error`.
///
/// The production predicate is `RequireErrorWidgetRule._builderHandlesError`
/// in `widget/widget_patterns_require_rules.dart`. These tests mirror that
/// predicate against parsed AST snippets so the contract is independently
/// verified — keep the local helper here in sync with the production helper.
void main() {
  /// Mirrors `RequireErrorWidgetRule._snapshotParamName`.
  String? snapshotParamName(FunctionExpression builder) {
    final FormalParameterList? params = builder.parameters;
    if (params == null) return null;
    final NodeList<FormalParameter> list = params.parameters;
    if (list.length < 2) return null;
    final FormalParameter second = list[1];
    final FormalParameter inner = second is DefaultFormalParameter
        ? second.parameter
        : second;
    if (inner is SimpleFormalParameter) {
      return inner.name?.lexeme;
    }
    return null;
  }

  /// Mirrors `RequireErrorWidgetRule._builderHandlesError`.
  bool builderHandlesError(FunctionExpression builder) {
    final String? name = snapshotParamName(builder);
    final _Visitor v = _Visitor(name);
    builder.body.visitChildren(v);
    return v.handlesError;
  }

  /// Parse [source] (a function body or top-level snippet) and return the
  /// first `FunctionExpression` whose parameter list has at least two
  /// parameters — the FutureBuilder/StreamBuilder builder shape.
  FunctionExpression firstBuilder(String source) {
    final CompilationUnit unit = parseString(
      content: source,
      throwIfDiagnostics: false,
    ).unit;
    FunctionExpression? hit;
    unit.visitChildren(
      _BuilderFinder((FunctionExpression node) {
        if (hit != null) return;
        if ((node.parameters?.parameters.length ?? 0) >= 2) {
          hit = node;
        }
      }),
    );
    expect(hit, isNotNull, reason: 'no two-arg FunctionExpression in snippet');
    return hit!;
  }

  group('require_error_widget AST-based handler detection', () {
    test('BAD: builder accesses only .data — no error handling', () {
      // Canonical violation: the builder ignores error state entirely.
      // Must report.
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) {
            return Text(snapshot.data.toString());
          };
        }
      ''');
      expect(builderHandlesError(builder), isFalse);
    });

    test('GOOD: inline if (snapshot.hasError)', () {
      // Pattern 1 — canonical inline guard. PrefixedIdentifier `snapshot.hasError`.
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) {
            if (snapshot.hasError) return ErrorView();
            return Text(snapshot.data.toString());
          };
        }
      ''');
      expect(builderHandlesError(builder), isTrue);
    });

    test('GOOD: delegated handler returning Widget?', () {
      // Pattern 2 — method invocation on the snapshot identifier. Method
      // name does not itself mention "error"; previous substring check
      // would FP.
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) {
            final w = snapshot.snapLoadingProgress();
            if (w != null) return w;
            return Text(snapshot.data.toString());
          };
        }
      ''');
      expect(builderHandlesError(builder), isTrue);
    });

    test('GOOD: delegated handler whose name contains capital-E Error', () {
      // Pattern 2 AND pattern 3 both match — `snapshot.reportErrorIfAny()`
      // is a method on the snapshot AND the method name contains "error".
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) {
            snapshot.reportErrorIfAny();
            return Text(snapshot.data.toString());
          };
        }
      ''');
      expect(builderHandlesError(builder), isTrue);
    });

    test('GOOD: bare helper call whose name contains error', () {
      // Pattern 3 — method invocation whose name itself contains "error",
      // called without a target (mixin/extension scope). Suppresses lint.
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) {
            reportErrorIfAny(snapshot);
            return Text(snapshot.data.toString());
          };
        }
      ''');
      expect(builderHandlesError(builder), isTrue);
    });

    test('BAD: local variable named hasErrorState does NOT suppress', () {
      // The old substring rule treated this as handled because the literal
      // string `hasError` appeared in source. The AST predicate must NOT
      // be fooled — only `.hasError` access on a target counts.
      // This is the latent false-NEGATIVE the new check also closes.
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) {
            final hasErrorState = false;
            return Text(snapshot.data.toString());
          };
        }
      ''');
      expect(builderHandlesError(builder), isFalse);
    });

    test('GOOD: arrow-bodied builder accessing .hasError', () {
      // ExpressionFunctionBody path — the visitor must still walk it.
      final builder = firstBuilder('''
        void f() {
          var b = (ctx, snapshot) =>
              snapshot.hasError ? ErrorView() : Text(snapshot.data.toString());
        }
      ''');
      expect(builderHandlesError(builder), isTrue);
    });
  });

  // Bug: bugs/require_error_widget_false_positive_builder_method_reference.md
  //
  // When `builder:` is a method tear-off, the rule resolves the referenced
  // declaration BY NAME within the compilation unit and runs the same
  // error-handling analysis on its body. Unresolvable tear-offs are suppressed
  // (treated as handled) rather than reported. These tests mirror
  // `RequireErrorWidgetRule._findNamedExecutableBody` + `_bodyHandlesError`.

  String? snapshotFromParams(FormalParameterList? params) {
    if (params == null) return null;
    final list = params.parameters;
    if (list.length < 2) return null;
    final second = list[1];
    final inner = second is DefaultFormalParameter ? second.parameter : second;
    if (inner is SimpleFormalParameter) return inner.name?.lexeme;
    return null;
  }

  bool tearOffHandlesError(String source, String name) {
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;
    final finder = _NamedBodyFinder(name);
    unit.visitChildren(finder);
    final found = finder.result;
    // Unresolvable tear-off — production suppresses (no false positive).
    if (found == null) return true;
    final v = _Visitor(snapshotFromParams(found.params));
    found.body.visitChildren(v);
    return v.handlesError;
  }

  group('require_error_widget tear-off resolution', () {
    test('GOOD: tear-off method body handles hasError', () {
      expect(
        tearOffHandlesError('''
          class S {
            build() => FutureBuilder(builder: _buildContent);
            Widget _buildContent(ctx, snapshot) {
              if (snapshot.hasError) return ErrorView();
              return Text(snapshot.data.toString());
            }
          }
        ''', '_buildContent'),
        isTrue,
      );
    });

    test('GOOD: static tear-off method body handles hasError', () {
      expect(
        tearOffHandlesError('''
          class S {
            build() => StreamBuilder(builder: _staticBuild);
            static Widget _staticBuild(ctx, snapshot) {
              if (snapshot.hasError) return ErrorView();
              return Text(snapshot.data.toString());
            }
          }
        ''', '_staticBuild'),
        isTrue,
      );
    });

    test('BAD: tear-off method body ignores error', () {
      expect(
        tearOffHandlesError('''
          class S {
            build() => FutureBuilder(builder: _no);
            Widget _no(ctx, snapshot) => Text(snapshot.data.toString());
          }
        ''', '_no'),
        isFalse,
      );
    });

    test('GOOD: unresolvable cross-library tear-off is suppressed', () {
      expect(
        tearOffHandlesError('''
          class S {
            build() => FutureBuilder(builder: externalThing);
          }
        ''', 'externalThing'),
        isTrue,
      );
    });
  });
}

/// Mirrors `RequireErrorWidgetRule._findNamedExecutableBody`: finds the first
/// method/function named [targetName] and captures its params and body.
class _NamedBodyFinder extends RecursiveAstVisitor<void> {
  _NamedBodyFinder(this.targetName);
  final String targetName;
  ({FormalParameterList? params, FunctionBody body})? result;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (result == null && node.name.lexeme == targetName) {
      result = (params: node.parameters, body: node.body);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (result == null && node.name.lexeme == targetName) {
      result = (
        params: node.functionExpression.parameters,
        body: node.functionExpression.body,
      );
    }
    super.visitFunctionDeclaration(node);
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.snapshotParamName);
  final String? snapshotParamName;
  bool handlesError = false;

  static const Set<String> _errorProps = <String>{
    'hasError',
    'error',
    'stackTrace',
  };

  bool _isSnapshotTarget(Expression? target) {
    if (snapshotParamName == null || target == null) return false;
    return target is SimpleIdentifier && target.name == snapshotParamName;
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_errorProps.contains(node.identifier.name)) handlesError = true;
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (_errorProps.contains(node.propertyName.name)) handlesError = true;
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isSnapshotTarget(node.target)) handlesError = true;
    if (node.methodName.name.toLowerCase().contains('error')) {
      handlesError = true;
    }
    super.visitMethodInvocation(node);
  }
}

class _BuilderFinder extends RecursiveAstVisitor<void> {
  _BuilderFinder(this.onHit);
  final void Function(FunctionExpression) onHit;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    onHit(node);
    super.visitFunctionExpression(node);
  }
}
