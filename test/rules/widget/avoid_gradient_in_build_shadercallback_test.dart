import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

/// Regression tests for the `avoid_gradient_in_build` ShaderCallback gate.
///
/// Bug: `plan/history/2026.05/2026.05.03/avoid_gradient_in_build_false_positive_shadermask_shadercallback.md`
///
/// The rule reports non-const `LinearGradient` / `RadialGradient` /
/// `SweepGradient` constructors found inside a `build` method body. It must
/// NOT report constructors found inside a `FunctionExpression` passed as the
/// `shaderCallback:` named argument — those run at paint time, with `Rect
/// bounds` only available there.
///
/// Mirror of `_GradientVisitor` gating in
/// `lib/src/rules/widget/build_method_rules.dart`. Keep in sync.
void main() {
  group('avoid_gradient_in_build — ShaderCallback boundary', () {
    test('LinearGradient inside ShaderMask.shaderCallback is not reported', () {
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return ShaderMask(
      shaderCallback: (Object bounds) {
        return LinearGradient(
          colors: const [1, 2, 3],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
'''),
        isFalse,
        reason: 'shaderCallback runs at paint time; gradient must be exempt',
      );
    });

    test('LinearGradient in build() outside any callback is reported', () {
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return LinearGradient(colors: const [1, 2, 3]);
  }
}
'''),
        isTrue,
        reason: 'bare gradient construction in build() is the rule target',
      );
    });

    test('LinearGradient in BoxDecoration in build() is reported', () {
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: const [1, 2, 3]),
      ),
    );
  }
}
'''),
        isTrue,
        reason: 'gradient nested in build-time BoxDecoration must still fire',
      );
    });

    test('const LinearGradient is not reported', () {
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return const LinearGradient(colors: [1, 2, 3]);
  }
}
'''),
        isFalse,
        reason: 'const gradients are canonicalized; rule skips them',
      );
    });

    test('LinearGradient outside build() is not reported', () {
      expect(
        _wouldReport(r'''
final hoisted = LinearGradient(colors: const [1, 2, 3]);
class W {
  Object build(Object context) {
    return Container(decoration: BoxDecoration(gradient: hoisted));
  }
}
'''),
        isFalse,
        reason: 'rule only walks build() bodies',
      );
    });
  });
}

bool _wouldReport(String unitSource) {
  final result = parseString(
    content: unitSource,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _CountingGradientVisitor();
  result.unit.visitChildren(_BuildBodyFinder(visitor));
  return visitor.reported;
}

/// Locates `build` method bodies and dispatches the gradient visitor against
/// them — same entry point as the real rule's
/// `context.addMethodDeclaration(...)` callback.
class _BuildBodyFinder extends RecursiveAstVisitor<void> {
  _BuildBodyFinder(this.gradientVisitor);

  final _CountingGradientVisitor gradientVisitor;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      node.body.visitChildren(gradientVisitor);
    }
    super.visitMethodDeclaration(node);
  }
}

/// Test-local mirror of `_GradientVisitor` from build_method_rules.dart.
/// If the rule's gate changes, update this and the rule together.
class _CountingGradientVisitor extends GeneralizingAstVisitor<void> {
  bool reported = false;

  static const Set<String> _gradientTypes = <String>{
    'LinearGradient',
    'RadialGradient',
    'SweepGradient',
  };

  static const Set<String> _paintTimeCallbackNames = <String>{
    'shaderCallback',
  };

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final AstNode? parent = node.parent;
    if (parent is NamedExpression &&
        _paintTimeCallbackNames.contains(parent.name.label.name)) {
      return;
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName =
        node.constructorName.type.element?.name ??
        node.constructorName.type.name.lexeme;
    if (_gradientTypes.contains(typeName) &&
        node.keyword?.lexeme != 'const') {
      reported = true;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_gradientTypes.contains(node.methodName.name)) {
      reported = true;
    }
    super.visitMethodInvocation(node);
  }
}
