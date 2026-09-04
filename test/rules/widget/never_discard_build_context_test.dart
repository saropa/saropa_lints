import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/widget/never_discard_build_context_rules.dart';
import 'package:test/test.dart';

/// Tests for [NeverDiscardBuildContextRule].
///
/// The rule's detection is purely syntactic (first-parameter name/type of a
/// `builder:` closure, plus a body-scoped identifier-usage scan) — no
/// resolved-type information is required, so these tests parse source
/// directly via `parseString` and re-run the rule's own detection helpers
/// against the resulting AST, mirroring the pattern used by
/// `avoid_builder_index_out_of_bounds_behavior_test.dart`.
///
/// End-to-end firing (via the scan CLI, confirming the rule actually
/// reports on its fixture) is verified separately — see
/// `example/lib/widget_lifecycle/never_discard_build_context_fixture.dart`.
void main() {
  group('NeverDiscardBuildContextRule — instantiation', () {
    test('rule metadata satisfies the LintCode message contract', () {
      final rule = NeverDiscardBuildContextRule();
      expect(rule.code.lowerCaseName, 'never_discard_build_context');
      expect(
        rule.code.problemMessage,
        contains('[never_discard_build_context]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('NeverDiscardBuildContextRule — Builder', () {
    test('unused typed BuildContext param is reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext innerContext) {
      return Text(Theme.of(context).toString());
    },
  );
}
'''),
        isTrue,
      );
    });

    test('used typed BuildContext param is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext innerContext) {
      return Text(Theme.of(innerContext).toString());
    },
  );
}
'''),
        isFalse,
      );
    });

    test('param renamed to `_` is never flagged (escape hatch)', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext _) {
      return const SizedBox();
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — LayoutBuilder', () {
    test(
      'unused context with a USED second param (constraints) still reports',
      () {
        // Edge case 3 in the proposal: using another builder-supplied param
        // does not excuse ignoring context.
        expect(
          _wouldReport(r'''
Object w() {
  return LayoutBuilder(
    builder: (BuildContext ctx, BoxConstraints constraints) {
      return SizedBox(width: constraints.maxWidth);
    },
  );
}
'''),
          isTrue,
        );
      },
    );

    test('used context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return LayoutBuilder(
    builder: (BuildContext ctx, BoxConstraints constraints) {
      return Text(Theme.of(ctx).toString());
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — untyped params', () {
    test('untyped conventional name (ctx) unused is reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (ctx) {
      return Text(Theme.of(context).toString());
    },
  );
}
'''),
        isTrue,
      );
    });

    test('untyped conventional name (ctx) used is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (ctx) {
      return Text(Theme.of(ctx).toString());
    },
  );
}
'''),
        isFalse,
      );
    });

    test('untyped non-conventional name is not treated as BuildContext', () {
      // e.g. an unrelated builder-style API whose first param isn't context.
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (value) {
      return const SizedBox();
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — nested closures', () {
    test(
      'nested builder using its OWN context does not excuse the outer one',
      () {
        // Edge case 2 in the proposal.
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext outerContext) {
      return Builder(
        builder: (BuildContext innerContext) {
          return Text(Theme.of(innerContext).toString());
        },
      );
    },
  );
}
'''),
          isTrue,
        );
      },
    );

    test('context captured into a variable and used later is not reported', () {
      // Edge case 4 in the proposal.
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext innerContext) {
      final captured = innerContext;
      return Text(Theme.of(captured).toString());
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — non-builder callbacks', () {
    test('unused first param on a non-`builder:` named argument is ignored', () {
      expect(
        _wouldReport(r'''
Object w() {
  return GestureDetector(
    onTap: (BuildContext unused) {},
  );
}
'''),
        isFalse,
      );
    });
  });
}

/// Locates the `builder:` [FunctionExpression] in [unitSource] and applies
/// the same first-parameter type/usage checks as
/// [NeverDiscardBuildContextRule.runWithReporter].
bool _wouldReport(String unitSource) {
  final result = parseString(
    content: unitSource,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  var reported = false;
  result.unit.accept(_BuilderCallbackVisitor((node) => reported = true));
  return reported;
}

/// Mirror of the rule's `addFunctionExpression` callback body. Kept in sync
/// manually with `lib/src/rules/widget/never_discard_build_context_rules.dart`.
class _BuilderCallbackVisitor extends RecursiveAstVisitor<void> {
  _BuilderCallbackVisitor(this._onReport);

  final void Function(FunctionExpression node) _onReport;

  static const Set<String> _untypedContextNames = {
    'context',
    'ctx',
    'innerContext',
    'outerContext',
    'buildContext',
    'buildCtx',
  };

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final parent = node.parent;
    if (parent is NamedExpression && parent.name.label.name == 'builder') {
      final parameters = node.parameters?.parameters;
      if (parameters != null && parameters.isNotEmpty) {
        final firstParam = parameters.first;
        final paramName = _parameterName(firstParam);
        if (paramName != null && !paramName.startsWith('_')) {
          if (_looksLikeBuildContext(firstParam, paramName)) {
            if (!_isNameUsed(node.body, paramName)) {
              _onReport(node);
            }
          }
        }
      }
    }
    super.visitFunctionExpression(node);
  }

  static String? _parameterName(FormalParameter param) {
    final normalized = param is DefaultFormalParameter
        ? param.parameter
        : param;
    return normalized.name?.lexeme;
  }

  static bool _looksLikeBuildContext(FormalParameter param, String name) {
    final normalized = param is DefaultFormalParameter
        ? param.parameter
        : param;
    if (normalized is SimpleFormalParameter) {
      final type = normalized.type;
      if (type is NamedType) {
        return type.name.lexeme == 'BuildContext';
      }
      if (type == null) {
        return _untypedContextNames.contains(name);
      }
    }
    return false;
  }

  static bool _isNameUsed(FunctionBody body, String name) {
    final visitor = _IdentifierUsageVisitor(name);
    body.accept(visitor);
    return visitor.found;
  }
}

class _IdentifierUsageVisitor extends RecursiveAstVisitor<void> {
  _IdentifierUsageVisitor(this.targetName);

  final String targetName;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (found) return;
    if (node.name == targetName) {
      found = true;
      return;
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (found) return;
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    if (found) return;
  }
}
