import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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
      // Only builder-style callbacks matter: the function expression must
      // be the value of a `builder:` named argument.
      final parent = node.parent;
      if (parent is! NamedExpression || parent.name.label.name != 'builder') {
        return;
      }

      final parameters = node.parameters?.parameters;
      if (parameters == null || parameters.isEmpty) return;

      // The context parameter is always first: Builder(context), Layout
      // Builder(context, constraints), StatefulBuilder(context, setState),
      // FutureBuilder/StreamBuilder(context, snapshot).
      final firstParam = parameters.first;
      final paramName = _parameterName(firstParam);
      if (paramName == null) return;

      // `_`-prefixed params are the explicit "intentionally unused" escape
      // hatch called out in the proposal's edge cases — never flag these.
      if (paramName.startsWith('_')) return;

      if (!_looksLikeBuildContext(firstParam, paramName)) return;

      final body = node.body;
      if (_isNameUsed(body, paramName)) return;

      reporter.atNode(firstParam);
    });
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

  /// Whether [name] is read anywhere in [body], excluding nested function
  /// bodies (a nested builder using its OWN context of the same name does
  /// not excuse the outer parameter — see proposal edge case 2).
  static bool _isNameUsed(FunctionBody body, String name) {
    final visitor = _IdentifierUsageVisitor(name);
    body.accept(visitor);
    return visitor.found;
  }
}

/// Walks a function body looking for any read of [targetName], stopping at
/// the boundary of any nested closure/function so a nested builder's own
/// (possibly same-named) context parameter is never mistaken for a use of
/// the outer one.
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
    // Do not descend into nested closures — a nested builder's own context
    // parameter must not count as a use of the outer one.
    if (found) return;
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    if (found) return;
  }
}
