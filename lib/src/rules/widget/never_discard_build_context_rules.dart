import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:meta/meta.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// never_discard_build_context
// =============================================================================

/// Flags a `BuildContext` parameter supplied by a builder callback
/// (`Builder`, `StatefulBuilder`, `LayoutBuilder`, `AnimatedBuilder`,
/// `FutureBuilder`, `StreamBuilder`, and any other widget that exposes a
/// `builder:` callback) that is declared but never read inside the callback
/// body.
///
/// A builder callback exists specifically to hand the caller a *scoped*
/// context — one that sees the `InheritedWidget`s (theme, localization,
/// `Provider`/`Riverpod` values) established by the widget the builder is
/// attached to. Ignoring the parameter and reaching for an outer/ambient
/// `context` captured from the enclosing `build` method instead usually
/// means the resulting lookup resolves against the WRONG scope — a stale
/// theme, the default locale, or a `Provider` value from above the intended
/// subtree — a bug that is invisible at compile time and only surfaces as
/// wrong-looking UI at runtime.
///
/// Since: v14.3.4 | Updated: v14.3.4 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Builder(
///     builder: (innerContext) { // never reads innerContext
///       return Text(Theme.of(context).primaryColor.toString());
///     },
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Builder(
///     builder: (innerContext) {
///       return Text(Theme.of(innerContext).primaryColor.toString());
///     },
///   );
/// }
/// ```
class NeverDiscardBuildContextRule extends SaropaLintRule {
  NeverDiscardBuildContextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'flutter', 'widget'};

  @override
  RuleCost get cost => RuleCost.low;

  // Cheap pre-parse skip: every affected call site spells the named
  // parameter literally as `builder:` (Builder, StatefulBuilder,
  // LayoutBuilder, AnimatedBuilder, FutureBuilder, StreamBuilder all use
  // this exact parameter name), so a file without the substring can never
  // contain a violation.
  @override
  Set<String>? get requiredPatterns => const {'builder:'};

  // Only Flutter files can hold a Builder-style widget callback; skips the
  // whole rule on pure-Dart files before any AST work happens.
  @override
  bool get requiresFlutterImport => true;

  static const LintCode _code = LintCode(
    'never_discard_build_context',
    '[never_discard_build_context] This builder callback declares a '
        'BuildContext parameter that is never read in its body. Builder '
        'callbacks exist to hand you a context scoped to the widget being '
        'built, so ignoring it and reaching for an outer context instead '
        'usually resolves InheritedWidget lookups (Theme.of, Localizations.of, '
        'Provider.of) against the wrong scope, producing UI that silently '
        'reads a stale theme, the wrong locale, or an ancestor Provider value. '
        'If the parameter is genuinely unneeded, rename it to `_` to make '
        'that explicit. {v1}',
    correctionMessage: 'Use the builder-supplied context, or rename the '
        'unused parameter to `_`.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
      final offendingParam = _offendingParameter(node);
      if (offendingParam != null) reporter.atNode(offendingParam);
    });
  }

  /// Runs the rule's full detection logic against a single
  /// [FunctionExpression] and returns the parameter to flag, or `null` when
  /// the node is not an offending builder callback. Extracted from
  /// [runWithReporter] so both the live rule and [wouldReportForTesting]
  /// share one implementation — no more hand-copied test mirror to drift
  /// out of sync with the real logic. (Library-private: tests reach it only
  /// through the public [wouldReportForTesting] entry point below.)
  static FormalParameter? _offendingParameter(FunctionExpression node) {
    // Only builder-style callbacks matter: the function expression must
    // be the value of a `builder:` named argument.
    final parent = node.parent;
    if (parent is! NamedExpression || parent.name.label.name != 'builder') {
      return null;
    }

    final parameters = node.parameters?.parameters;
    if (parameters == null || parameters.isEmpty) return null;

    // The context parameter is always first: Builder(context), Layout
    // Builder(context, constraints), StatefulBuilder(context, setState),
    // FutureBuilder/StreamBuilder(context, snapshot).
    final firstParam = parameters.first;
    final paramName = _parameterName(firstParam);
    if (paramName == null) return null;

    // `_`-prefixed params are the explicit "intentionally unused" escape
    // hatch called out in the proposal's edge cases — never flag these.
    if (paramName.startsWith('_')) return null;

    if (!_looksLikeBuildContext(firstParam, paramName)) return null;

    final body = node.body;
    if (_isNameUsed(body, paramName)) return null;

    return firstParam;
  }

  /// Test-only entry point: walks [unit] looking for the first `builder:`
  /// [FunctionExpression] and reports whether the rule's real detection
  /// logic ([_offendingParameter]) would flag it. Keeps
  /// `never_discard_build_context_test.dart` exercising the actual rule
  /// implementation rather than a manually-duplicated visitor that can
  /// silently drift from it (see Finish Report 2026-09-04, Recommendation 4).
  @visibleForTesting
  static bool wouldReportForTesting(CompilationUnit unit) {
    var reported = false;
    unit.accept(
      _OffendingParameterVisitor((node) {
        if (_offendingParameter(node) != null) reported = true;
      }),
    );
    return reported;
  }

  /// Extracts the declared name of a formal parameter, unwrapping
  /// [DefaultFormalParameter] (named/optional params) down to the
  /// underlying [SimpleFormalParameter].
  static String? _parameterName(FormalParameter param) {
    final normalized = param is DefaultFormalParameter
        ? param.parameter
        : param;
    return normalized.name?.lexeme;
  }

  /// Common names Flutter/community code uses for a builder-supplied
  /// context when the parameter is left untyped (inference from the
  /// builder's function-type signature). Kept as an explicit allow-list —
  /// per the false-positive doctrine, guessing based on `.contains()` on
  /// arbitrary names is exactly the mistake that has burned this package
  /// before.
  static const Set<String> _untypedContextNames = {
    'context',
    'ctx',
    'innerContext',
    'outerContext',
    'buildContext',
    'buildCtx',
  };

  /// True when the first parameter of a `builder:` callback is plausibly a
  /// `BuildContext`: either explicitly typed as `BuildContext`, or left
  /// untyped with one of the conventional context parameter names.
  static bool _looksLikeBuildContext(FormalParameter param, String name) {
    final normalized = param is DefaultFormalParameter
        ? param.parameter
        : param;
    if (normalized is SimpleFormalParameter) {
      final type = normalized.type;
      if (type is NamedType) {
        return type.name.lexeme == 'BuildContext';
      }
      // Untyped parameter (relying on inference from the builder's
      // function-type signature) — fall back to conventional naming.
      if (type == null) {
        return _untypedContextNames.contains(name);
      }
    }
    return false;
  }

  /// Whether [name] is read anywhere in [body], including inside nested
  /// closures/functions (onPressed, then(), addPostFrameCallback, a locally
  /// declared helper) — EXCEPT a nested function that redeclares a
  /// parameter named [name] itself, since that nested body refers to its
  /// own (shadowing) parameter, not the outer one (proposal edge case 2).
  static bool _isNameUsed(FunctionBody body, String name) {
    final visitor = _IdentifierUsageVisitor(name);
    body.accept(visitor);
    return visitor.found;
  }
}

/// Test-support visitor: walks a whole compilation unit and invokes
/// [_onFunctionExpression] for every [FunctionExpression] found, letting
/// [NeverDiscardBuildContextRule.wouldReportForTesting] reuse the exact same
/// `builder:`-detection entry point the live rule registers via
/// `context.addFunctionExpression`.
class _OffendingParameterVisitor extends RecursiveAstVisitor<void> {
  _OffendingParameterVisitor(this._onFunctionExpression);

  final void Function(FunctionExpression node) _onFunctionExpression;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _onFunctionExpression(node);
    super.visitFunctionExpression(node);
  }
}

/// Walks a function body looking for any read of [targetName]. Descends into
/// nested closures/functions UNLESS the nested function redeclares a
/// parameter with the same name as [targetName] (true shadowing) — in that
/// case its body refers to its OWN parameter, not the outer one, so it is
/// skipped. This lets ordinary nested callbacks (`onPressed`, `then`,
/// `addPostFrameCallback`, a locally-declared helper function, etc.) that
/// read the outer context register as a genuine use, while still honoring
/// proposal edge case 2: a nested builder that declares its own
/// same-named context parameter must not excuse the outer one.
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
    // Only stop descending when this nested function itself redeclares a
    // parameter named exactly like the outer target — that is genuine
    // shadowing, not a use of the outer context. Any other nested closure
    // (onPressed, then(), addPostFrameCallback, etc.) is searched normally.
    if (_declaresParameter(node.parameters, targetName)) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    if (found) return;
    final parameters = node.functionDeclaration.functionExpression.parameters;
    if (_declaresParameter(parameters, targetName)) return;
    super.visitFunctionDeclarationStatement(node);
  }

  /// Whether [parameters] declares a formal parameter named [name],
  /// unwrapping [DefaultFormalParameter] down to the underlying
  /// [SimpleFormalParameter]/other formal to reach the declared name.
  static bool _declaresParameter(
    FormalParameterList? parameters,
    String name,
  ) {
    if (parameters == null) return false;
    for (final param in parameters.parameters) {
      final normalized = param is DefaultFormalParameter
          ? param.parameter
          : param;
      if (normalized.name?.lexeme == name) return true;
    }
    return false;
  }
}
