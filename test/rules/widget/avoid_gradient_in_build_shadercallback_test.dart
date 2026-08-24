import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

/// Regression tests for the `avoid_gradient_in_build` exemption gates.
///
/// Bug (shaderCallback): `plan/history/2026.05/2026.05.03/avoid_gradient_in_build_false_positive_shadermask_shadercallback.md`
/// Bug (AnimatedBuilder): `plans/history/2026.08/2026.08.16/avoid_gradient_in_build_fp_animated_builder_closure.md`
///
/// The rule reports non-const `LinearGradient` / `RadialGradient` /
/// `SweepGradient` constructors found inside a `build` method body. It must
/// NOT report constructors found inside:
///   1. a `FunctionExpression` passed as the `shaderCallback:` named argument
///      — those run at paint time, with `Rect bounds` only available there.
///   2. a `FunctionExpression` passed as `builder:` to `AnimatedBuilder` or
///      `TweenAnimationBuilder` — those re-run every animation frame, so the
///      gradient intentionally varies per tick.
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

  group('avoid_gradient_in_build — AnimatedBuilder boundary', () {
    test('LinearGradient inside AnimatedBuilder.builder is not reported', () {
      // Bug: avoid_gradient_in_build_fp_animated_builder_closure.md
      // The builder closure re-runs every animation frame; the gradient's
      // alignment/colors depend on the animation value, so hoisting is wrong.
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0, 0),
              colors: const [1, 2],
            ),
          ),
          child: child,
        );
      },
      child: const SizedBox(),
    );
  }
}
'''),
        isFalse,
        reason: 'AnimatedBuilder.builder re-runs per frame; gradient is exempt',
      );
    });

    test(
      'RadialGradient inside TweenAnimationBuilder.builder is not reported',
      () {
        // Same exemption applies to TweenAnimationBuilder
        expect(
          _wouldReport(r'''
class W {
  Object build(Object context) {
    return TweenAnimationBuilder(
      tween: tween,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [value, other]),
          ),
        );
      },
    );
  }
}
'''),
          isFalse,
          reason:
              'TweenAnimationBuilder.builder re-runs per frame; gradient is exempt',
        );
      },
    );

    test('SweepGradient inside ListenableBuilder.builder is not reported', () {
      // ListenableBuilder shares the same builder: contract as AnimatedBuilder
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(colors: [1, 2]),
          ),
        );
      },
    );
  }
}
'''),
        isFalse,
        reason:
            'ListenableBuilder.builder re-runs per notification; gradient is exempt',
      );
    });

    test('LinearGradient in builder: of non-animation widget IS reported', () {
      // builder: is a common parameter name — only exempt it on animation
      // widgets, not on e.g. ListView.builder or generic widgets.
      expect(
        _wouldReport(r'''
class W {
  Object build(Object context) {
    return SomeOtherWidget(
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: const [1, 2]),
          ),
        );
      },
    );
  }
}
'''),
        isTrue,
        reason:
            'builder: on a non-animation widget is build-time; gradient must fire',
      );
    });

    test(
      'gradient referencing closure-unique param on unknown widget is not reported',
      () {
        // Gate 3: widget-name-independent heuristic — if the gradient's args
        // reference a parameter unique to the builder closure (not context/child),
        // it can't be hoisted regardless of widget type.
        expect(
          _wouldReport(r'''
class W {
  Object build(Object context) {
    return CustomAnimWidget(
      builder: (context, animValue, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [animValue, other]),
          ),
        );
      },
    );
  }
}
'''),
          isFalse,
          reason:
              'gradient references animValue — a closure-unique param; cannot be hoisted',
        );
      },
    );

    test(
      'gradient NOT referencing closure-unique param on unknown widget IS reported',
      () {
        // The builder has extra params but the gradient doesn't use them
        expect(
          _wouldReport(r'''
class W {
  Object build(Object context) {
    return CustomWidget(
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: const [1, 2]),
          ),
        );
      },
    );
  }
}
'''),
          isTrue,
          reason:
              'gradient uses only const args — does not depend on closure params',
        );
      },
    );

    test(
      'LinearGradient outside AnimatedBuilder.builder closure is reported',
      () {
        // Gradient at the build() level, not inside the builder closure
        expect(
          _wouldReport(r'''
class W {
  Object build(Object context) {
    final g = LinearGradient(colors: const [1, 2]);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return child;
      },
    );
  }
}
'''),
          isTrue,
          reason:
              'gradient is in build() body, not inside the builder closure itself',
        );
      },
    );
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

  static const Set<String> _paintTimeCallbackNames = <String>{'shaderCallback'};

  // Widgets whose builder: closure re-runs every notification/tick
  static const Set<String> _animationBuilderTypes = <String>{
    'AnimatedBuilder',
    'ListenableBuilder',
    'TweenAnimationBuilder',
    'ValueListenableBuilder',
  };

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Analyzer 13 migration: NamedExpression → NamedArgument,
    // .name.label.name → .name.lexeme
    final AstNode? parent = node.parent;
    if (parent is NamedArgument) {
      final String argName = parent.name.lexeme;

      // Gate 1: paint-time callbacks (e.g. shaderCallback)
      if (_paintTimeCallbackNames.contains(argName)) {
        return;
      }

      // Gate 2: builder: closures on animation widgets
      if (argName == 'builder' && _isAnimationBuilderArg(parent)) {
        return;
      }
    }
    super.visitFunctionExpression(node);
  }

  /// Checks whether a builder: NamedArgument belongs to an animation widget.
  /// Handles both InstanceCreationExpression (resolved) and MethodInvocation
  /// (how parseString emits implicit-new calls without type resolution).
  /// Analyzer 13 migration: NamedExpression → NamedArgument
  static bool _isAnimationBuilderArg(NamedArgument namedExpr) {
    final AstNode? argList = namedExpr.parent;
    if (argList is! ArgumentList) return false;
    final AstNode? call = argList.parent;

    if (call is InstanceCreationExpression) {
      final String typeName =
          call.constructorName.type.element?.name ??
          call.constructorName.type.name.lexeme;
      return _animationBuilderTypes.contains(typeName);
    }

    // Unresolved implicit-new: parser emits MethodInvocation
    if (call is MethodInvocation) {
      return _animationBuilderTypes.contains(call.methodName.name);
    }

    return false;
  }

  // Standard builder params also available at build-method level
  static const Set<String> _standardBuilderParams = <String>{
    'context',
    'child',
    '_',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName =
        node.constructorName.type.element?.name ??
        node.constructorName.type.name.lexeme;
    if (_gradientTypes.contains(typeName) &&
        node.keyword?.lexeme != 'const' &&
        !_gradientDependsOnClosureParams(node)) {
      reported = true;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_gradientTypes.contains(node.methodName.name) &&
        !_gradientDependsOnClosureParams(node)) {
      reported = true;
    }
    super.visitMethodInvocation(node);
  }

  /// Gate 3: gradient depends on a closure-unique parameter — can't be hoisted
  static bool _gradientDependsOnClosureParams(AstNode gradientNode) {
    AstNode? current = gradientNode.parent;
    FunctionExpression? closure;
    while (current != null) {
      if (current is FunctionExpression) {
        final AstNode? parent = current.parent;
        // Analyzer 13 migration: NamedExpression → NamedArgument
        if (parent is NamedArgument && parent.name.lexeme == 'builder') {
          closure = current;
          break;
        }
      }
      current = current.parent;
    }
    if (closure == null) return false;

    // Collect closure-unique parameter names
    final params = closure.parameters?.parameters;
    if (params == null) return false;
    final Set<String> unique = <String>{};
    for (final param in params) {
      final name = param.name?.lexeme;
      if (name != null && !_standardBuilderParams.contains(name)) {
        unique.add(name);
      }
    }
    if (unique.isEmpty) return false;

    // Check if gradient arguments reference any of those parameters
    bool found = false;
    gradientNode.visitChildren(_SimpleIdVisitor(unique, (n) => found = true));
    return found;
  }
}

/// Walks an AST subtree looking for SimpleIdentifier nodes matching target names.
class _SimpleIdVisitor extends RecursiveAstVisitor<void> {
  _SimpleIdVisitor(this._names, this._onFound);
  final Set<String> _names;
  final void Function(SimpleIdentifier) _onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_names.contains(node.name)) {
      _onFound(node);
    }
  }
}
