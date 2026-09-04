import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:meta/meta.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// never_discard_build_context
// =============================================================================

/// Flags a `BuildContext` parameter that is declared but never read in the
/// `builder:` callback of a **context-supplying** widget — specifically
/// `Builder`, `LayoutBuilder`, and `StatefulBuilder`.
///
/// Those three widgets exist for one reason: to insert a new element into the
/// tree and hand the callback a context scoped *below* that element — one that
/// sees the `InheritedWidget`s (theme, localization, `Provider`/`Riverpod`
/// values) established at that point. Ignoring the parameter and reaching for
/// an outer/ambient `context` captured from the enclosing `build` method
/// instead means the lookup resolves against the WRONG scope — a stale theme,
/// the default locale, or a `Provider` value from above the intended subtree —
/// a bug that is invisible at compile time and only surfaces as wrong-looking
/// UI at runtime. For `Builder` the widget then serves no purpose at all.
///
/// Deliberately NOT flagged: every other `builder:` callback. `FutureBuilder`,
/// `StreamBuilder`, `AnimatedBuilder`, `ValueListenableBuilder`,
/// `DraggableScrollableSheet`, and Provider's `Consumer`/`Selector` all take a
/// `builder:` whose purpose is to deliver OTHER data (an `AsyncSnapshot`, an
/// animation value, a provider value, a `ScrollController`). Their context
/// parameter is incidental — it is the same scope the enclosing `build`
/// already has for lookup purposes — so ignoring it is idiomatic and
/// extremely common. v1 of this rule gated only on the argument being named
/// `builder:`, which produced dozens of false positives per real Flutter
/// codebase; v2 resolves the enclosing widget type and restricts detection to
/// the three widgets where the "this callback exists to hand you a scoped
/// context" premise actually holds.
///
/// Since: v14.3.4 | Updated: v14.3.5 | Rule version: v2
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
///
/// // Also GOOD — FutureBuilder's callback exists to deliver `snapshot`, not
/// // a scoped context, so discarding `context` here is idiomatic.
/// FutureBuilder<int>(
///   future: f,
///   builder: (context, snapshot) => Text('${snapshot.data}'),
/// );
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
  // parameter literally as `builder:` (Builder, LayoutBuilder and
  // StatefulBuilder all use this exact parameter name), so a file without
  // the substring can never contain a violation. Kept as the pre-filter
  // rather than the three widget names because a single substring test is
  // cheaper than three, and the widget-type gate runs on the AST anyway.
  @override
  Set<String>? get requiredPatterns => const {'builder:'};

  // Only Flutter files can hold a Builder-style widget callback; skips the
  // whole rule on pure-Dart files before any AST work happens.
  @override
  bool get requiresFlutterImport => true;

  static const LintCode _code = LintCode(
    'never_discard_build_context',
    '[never_discard_build_context] This Builder/LayoutBuilder/StatefulBuilder '
        'callback declares a BuildContext parameter that is never read in its '
        'body. These three widgets exist solely to insert an element into the '
        'tree and hand the callback a context scoped below it, so discarding '
        'that context and reaching for an outer one resolves InheritedWidget '
        'lookups (Theme.of, Localizations.of, Provider.of) against the wrong '
        'scope, producing UI that silently reads a stale theme, the wrong '
        'locale, or an ancestor Provider value — and for a plain Builder the '
        'widget then does nothing at all. Callbacks on FutureBuilder, '
        'StreamBuilder, AnimatedBuilder, ValueListenableBuilder and '
        'Consumer/Selector are NOT checked, because their context parameter is '
        'incidental to the data they deliver. If the parameter is genuinely '
        'unneeded, rename it to `_` to make that explicit. {v2}',
    correctionMessage:
        'Use the Builder/LayoutBuilder/StatefulBuilder-supplied '
        'context for InheritedWidget lookups, or rename the unused parameter '
        'to `_`.',
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
    // Gate 1 (cheap, token-level): the function expression must be the value
    // of a `builder:` named argument.
    final parent = node.parent;
    if (parent is! NamedExpression || parent.name.label.name != 'builder') {
      return null;
    }

    // Gate 2 (the v2 false-positive fix): the argument must belong to one of
    // the three widgets whose builder exists to SUPPLY a scoped context.
    // Without this, the rule fired on FutureBuilder/StreamBuilder/
    // AnimatedBuilder/ValueListenableBuilder/Consumer/Selector, where
    // discarding the incidental context parameter is idiomatic — dozens of
    // false positives per real Flutter codebase, on by default in the
    // Recommended tier.
    if (!_isContextSupplyingBuilderWidget(parent)) return null;

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

  /// The ONLY widgets whose `builder:` callback exists to hand the caller a
  /// newly-scoped [BuildContext]. Every other Flutter builder callback takes
  /// a context only because the signature happens to include one; its real
  /// payload is the second parameter (an `AsyncSnapshot`, an animation value,
  /// a provider value, a `ScrollController`, `BoxConstraints`...), and
  /// discarding the context there is both idiomatic and pervasive.
  ///
  /// Exact-match set, never substring matching — a `.contains('Builder')`
  /// test would re-admit `FutureBuilder`, `AnimatedBuilder` and every
  /// third-party `*Builder`, which is precisely the false positive this
  /// gate exists to kill.
  static const Set<String> _contextSupplyingBuilders = {
    'Builder',
    'LayoutBuilder',
    'StatefulBuilder',
  };

  /// Whether the `builder:` argument [namedArgument] belongs to a
  /// construction of one of [_contextSupplyingBuilders].
  ///
  /// Walks the named argument up to its enclosing invocation and reads the
  /// constructed type's NAME from the AST. Two node shapes must be handled
  /// because this rule runs in both analysis modes: in resolved code
  /// `Builder(...)` is an [InstanceCreationExpression], but in the syntactic
  /// scan path (and in `parseString`-based unit tests) an unprefixed
  /// constructor call with no `new` parses as a [MethodInvocation]. Reading
  /// the syntactic type name rather than `staticType` keeps detection
  /// identical in both modes; a resolved-only check would silently disable
  /// the rule for every unresolved scan.
  static bool _isContextSupplyingBuilderWidget(NamedExpression namedArgument) {
    final argumentList = namedArgument.parent;
    if (argumentList is! ArgumentList) return false;

    final invocation = argumentList.parent;

    if (invocation is InstanceCreationExpression) {
      // `Builder(...)`, `const Builder(...)`, `new Builder(...)`, and
      // prefixed `widgets.Builder(...)` — `NamedType.name` is the bare type
      // token in every case, so the import prefix never interferes.
      return _contextSupplyingBuilders.contains(
        invocation.constructorName.type.name.lexeme,
      );
    }

    if (invocation is MethodInvocation) {
      // Unresolved parse of the same source: the constructor call is
      // indistinguishable from a function call, so match on the callee name.
      return _contextSupplyingBuilders.contains(invocation.methodName.name);
    }

    return false;
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
/// nested closures/functions UNLESS the nested scope REDECLARES [targetName],
/// in which case every identifier inside it refers to that inner declaration,
/// not to the outer builder context, and must not count as a use.
///
/// Four shadowing forms are recognized:
///
/// 1. A nested [FunctionExpression] with a same-named parameter.
/// 2. A nested [FunctionDeclarationStatement] with a same-named parameter.
/// 3. A nested [Block] containing a same-named local variable declaration.
/// 4. A `for` loop or `catch` clause introducing a same-named variable.
///
/// Forms 3 and 4 were missing in v1: only parameter lists were inspected, so
/// an unrelated `final ctx = computeSomethingElse();` in a nested block
/// counted every subsequent `ctx` read as a use of the builder context and
/// silently suppressed a genuine violation (false negative). Skipping the
/// WHOLE declaring block/loop/clause is correct rather than merely
/// conservative: in Dart a local's scope is its entire enclosing block, so a
/// read of that name earlier in the same block is a compile error, never a
/// read of the outer parameter.
///
/// Everything else is searched normally, so ordinary nested callbacks
/// (`onPressed`, `then`, `addPostFrameCallback`, a locally-declared helper
/// function) that read the outer context still register as genuine uses.
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

  @override
  void visitBlock(Block node) {
    if (found) return;
    // A block that declares its own local named [targetName] shadows the
    // outer builder context for the WHOLE block (Dart local scope is the
    // enclosing block, not "from the declaration onward"), so no identifier
    // inside it can be a read of the outer parameter.
    if (_declaresLocalVariable(node, targetName)) return;
    super.visitBlock(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    if (found) return;
    // `for (final ctx in items)` / `for (var ctx = 0; ...)` shadows the outer
    // name for the loop's header AND body.
    if (_forLoopDeclares(node.forLoopParts, targetName)) return;
    super.visitForStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (found) return;
    // `catch (ctx)` / `on E catch (e, ctx)` shadows the outer name inside the
    // catch body.
    if (node.exceptionParameter?.name.lexeme == targetName ||
        node.stackTraceParameter?.name.lexeme == targetName) {
      return;
    }
    super.visitCatchClause(node);
  }

  /// Whether [block] declares a local variable named [name] at its own
  /// statement level (nested blocks get their own [visitBlock] check).
  static bool _declaresLocalVariable(Block block, String name) {
    for (final statement in block.statements) {
      if (statement is! VariableDeclarationStatement) continue;
      for (final variable in statement.variables.variables) {
        if (variable.name.lexeme == name) return true;
      }
    }
    return false;
  }

  /// Whether a `for` loop's header declares a variable named [name], covering
  /// both `for-in` (`ForEachPartsWithDeclaration`) and C-style
  /// (`ForPartsWithDeclarations`) headers. Pattern-based headers
  /// (`for (final (a, b) in ...)`) are not inspected — they would only ever
  /// cause the rule to treat a shadowed read as a use, i.e. err toward NOT
  /// reporting, which is the safe direction.
  static bool _forLoopDeclares(ForLoopParts parts, String name) {
    if (parts is ForEachPartsWithDeclaration) {
      return parts.loopVariable.name.lexeme == name;
    }
    if (parts is ForPartsWithDeclarations) {
      for (final variable in parts.variables.variables) {
        if (variable.name.lexeme == name) return true;
      }
    }
    return false;
  }

  /// Whether [parameters] declares a formal parameter named [name],
  /// unwrapping [DefaultFormalParameter] down to the underlying
  /// [SimpleFormalParameter]/other formal to reach the declared name.
  static bool _declaresParameter(FormalParameterList? parameters, String name) {
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
