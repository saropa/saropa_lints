// ignore_for_file: depend_on_referenced_packages

/// Detects method calls, property access, and operator invocations
/// performed on a receiver whose static type is `dynamic`.
///
/// Complements the narrower JSON-scoped rules in `type_safety_rules.dart`
/// (`AvoidDynamicJsonAccessRule`, `AvoidDynamicJsonChainsRule`) with a
/// general receiver-type check that fires for ANY dynamically-typed
/// receiver — not only `jsonDecode()` results.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when a call, property access, or operator (including compound
/// assignment `+=`, increment/decrement `++`/`--`, cascades, and calling a
/// dynamic value as a function) is invoked on a receiver whose static type
/// is `dynamic`.
///
/// Since: v15.2.12 | Rule version: v1
///
/// A call on a `dynamic` receiver defers all member-resolution and
/// type-checking to runtime. Typos in method names, wrong argument
/// counts, and type mismatches all compile silently and only surface as
/// a `NoSuchMethodError` in production. This defeats the entire point of
/// Dart's static type system for that call site.
///
/// **Exemption**: inside a `noSuchMethod` override, only call sites that
/// actually derive from the override's `Invocation` parameter are
/// intentional dynamic dispatch and are skipped — an unrelated dynamic call
/// elsewhere in the same override body is still flagged.
///
/// **BAD:**
/// ```dart
/// void process(dynamic data) {
///   data.calculateTotal(); // no compile-time check this method exists
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(Invoice data) {
///   data.calculateTotal(); // statically verified
/// }
/// // or, if the dynamic type is unavoidable (e.g. plugin bridge):
/// void process(dynamic data) {
///   (data as Invoice).calculateTotal();
/// }
/// ```
class AvoidDynamicCallsRule extends SaropaLintRule {
  AvoidDynamicCallsRule() : super(code: _code);

  /// Calls on a dynamic receiver bypass all compile-time verification and
  /// are a frequent, hard-to-test source of production NoSuchMethodError
  /// crashes — warrants a WARNING, consistent with the sibling JSON-access
  /// rules (`avoid_dynamic_json_access`, `avoid_unsafe_cast`).
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability', 'type-safety'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Detection depends entirely on resolved static types (DynamicType
  // checks below), so this rule must run in a resolved context.
  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'avoid_dynamic_calls',
    '[avoid_dynamic_calls] Calling a method, accessing a property, or using '
        'an operator on a receiver typed dynamic bypasses the analyzer\'s '
        'static type checking entirely. Typos in member names, wrong '
        'argument counts, and type mismatches all compile silently and only '
        'surface as a NoSuchMethodError crash at runtime, in production, '
        'often in a code path unit tests never exercise. {v1}',
    correctionMessage:
        'Give the receiver a concrete type (change the parameter/variable/'
        'field type) so the compiler can verify the member exists. If a '
        'concrete type is genuinely unavailable (e.g. a plugin or '
        'reflection bridge), cast explicitly with "as SpecificType" before '
        'calling, so the unsafe boundary is a single visible line.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Binary operators that resolve to an actual operator-method call on the
  /// left operand (`+`, `<`, `&`, ...). Deliberately excludes `==`, `!=`,
  /// `&&`, and `||` — those resolve through `Object.==`/`bool` logic that
  /// is not meaningfully "unchecked" the way a dynamic arithmetic or
  /// comparison operator call is, and flagging them would just be noise on
  /// ordinary null/bool checks.
  static const Set<String> _operatorInvocationTokens = <String>{
    '+',
    '-',
    '*',
    '/',
    '~/',
    '%',
    '<',
    '<=',
    '>',
    '>=',
    '&',
    '|',
    '^',
    '<<',
    '>>',
    '>>>',
  };

  /// Compound-assignment operators (`dynamicValue += 1`) mapped to the base
  /// operator they dispatch through on the receiver (`+`). Deliberately
  /// excludes plain `=` and `??=` — neither invokes a member on the
  /// left-hand side's existing value, so there is nothing "unchecked"
  /// about them the way `dynamicValue += 1` invoking the dynamic `+`
  /// operator is. Reuses [_operatorInvocationTokens] as the source of
  /// truth for which base operators count, keeping the "meaningful
  /// operator, not `==`/`&&`/`||`" policy in one place.
  static final Map<String, String> _compoundAssignmentBaseOperators =
      <String, String>{
        for (final String operator in _operatorInvocationTokens)
          if (operator != '<' &&
              operator != '<=' &&
              operator != '>' &&
              operator != '>=')
            '$operator=': operator,
      };

  /// Prefix operators that invoke an operator method on the operand
  /// (`-dynamicValue`, `~dynamicValue`, `++dynamicValue`, `--dynamicValue`).
  /// Excludes logical `!` — like `==`/`&&`/`||` on the binary side, boolean
  /// negation is not a meaningfully "unchecked" dispatch on a dynamic
  /// receiver.
  static const Set<String> _prefixOperatorInvocationTokens = <String>{
    '-',
    '~',
    '++',
    '--',
  };

  /// Postfix operators that invoke an operator method on the operand
  /// (`dynamicValue++`, `dynamicValue--`). Dart has no other postfix
  /// operators.
  static const Set<String> _postfixOperatorInvocationTokens = <String>{
    '++',
    '--',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    context.addPropertyAccess((PropertyAccess node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (_isInsideNoSuchMethod(node)) return;
      // Import prefixes (e.g. `math.pi`) resolve the prefix identifier to
      // a PrefixElement with no static type — the DynamicType check below
      // naturally excludes them without needing an explicit element check.
      if (_hasDynamicStaticType(node.prefix)) {
        reporter.atNode(node);
      }
    });

    context.addIndexExpression((IndexExpression node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    context.addBinaryExpression((BinaryExpression node) {
      if (!_operatorInvocationTokens.contains(node.operator.lexeme)) return;
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.leftOperand)) {
        reporter.atNode(node);
      }
    });

    // `dynamicValue..foo()..bar()` — the cascade's sections have no
    // explicit target (`node.target` on the inner MethodInvocation/
    // PropertyAccess/IndexExpression is null), so they never trip the
    // hooks above. Check the cascade's own target once and report on the
    // whole CascadeExpression rather than per-section, so `x..a()..b()`
    // produces a single diagnostic instead of one per cascaded call.
    context.addCascadeExpression((CascadeExpression node) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.target)) {
        reporter.atNode(node);
      }
    });

    // `dynamicValue += 1` dispatches through the dynamic `+` operator the
    // same way `dynamicValue + 1` does, but it is an AssignmentExpression
    // rather than a BinaryExpression and was previously unchecked. Plain
    // `=` and `??=` are excluded via the map (they don't invoke a member
    // on the existing left-hand value).
    context.addAssignmentExpression((AssignmentExpression node) {
      final String? baseOperator =
          _compoundAssignmentBaseOperators[node.operator.lexeme];
      if (baseOperator == null) return;
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicReceiverType(node.leftHandSide, node)) {
        reporter.atNode(node);
      }
    });

    // `dynamicValue++`, `--dynamicValue`, `-dynamicValue`, `~dynamicValue`
    // invoke dynamic operator methods on the operand exactly like the
    // already-covered BinaryExpression case, but through
    // PrefixExpression/PostfixExpression nodes.
    context.addPrefixExpression((PrefixExpression node) {
      if (!_prefixOperatorInvocationTokens.contains(node.operator.lexeme)) {
        return;
      }
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicReceiverType(node.operand, node)) {
        reporter.atNode(node);
      }
    });

    context.addPostfixExpression((PostfixExpression node) {
      if (!_postfixOperatorInvocationTokens.contains(node.operator.lexeme)) {
        return;
      }
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicReceiverType(node.operand, node)) {
        reporter.atNode(node);
      }
    });

    // `dynamic fn = ...; fn();` calls through the dynamic value's
    // synthetic `call()` dispatch — a FunctionExpressionInvocation, not a
    // MethodInvocation (there is no member name to resolve), and was
    // previously unchecked.
    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      if (_isInsideNoSuchMethod(node)) return;
      if (_hasDynamicStaticType(node.function)) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns true when [expression]'s resolved static type is exactly
  /// `dynamic`. Uses the resolved `DartType` rather than any name/source
  /// matching, per the false-positive doctrine — a field or variable named
  /// "dynamic-something" or holding an `Object` never matches here.
  bool _hasDynamicStaticType(Expression? expression) {
    if (expression == null) return false;
    return expression.staticType is DynamicType;
  }

  /// Returns true when [receiver]'s dynamic-dispatch type is `dynamic`, for
  /// receivers used inside a [CompoundAssignmentExpression] (compound
  /// assignment `+=`, or increment/decrement `++`/`--`).
  ///
  /// A quirk of the resolved AST: when an identifier is used as the
  /// left-hand side of `+=` or as the operand of `++`/`--`, it is in a
  /// "write" position and its own `.staticType` (via [_hasDynamicStaticType])
  /// is `null` — the analyzer instead exposes the type of the value that
  /// gets READ (before the operator is applied) via `node.readType` on the
  /// [CompoundAssignmentExpression] mixin. Plain unary operators (`-`, `~`,
  /// `!`) use the same [PrefixExpression] AST node type but are NOT compound
  /// assignments, so `node.readType` is null for them and [receiver]'s own
  /// `.staticType` is populated normally — hence the fallback below.
  bool _hasDynamicReceiverType(
    Expression receiver,
    CompoundAssignmentExpression node,
  ) {
    final DartType? readType = node.readType;
    if (readType != null) return readType is DynamicType;
    return _hasDynamicStaticType(receiver);
  }

  /// `noSuchMethod` overrides intentionally dispatch dynamically, but ONLY
  /// for call sites derived from the override's `Invocation` parameter
  /// (`invocation.positionalArguments[0]...`, `invocation.memberName`,
  /// etc.) — that dispatch is the whole point of the override. A dynamic
  /// call elsewhere in the same body (e.g. a typo'd call on an unrelated
  /// dynamic local) is not part of that contract and must still be
  /// flagged, so the exemption is scoped to the parameter rather than the
  /// entire method.
  bool _isInsideNoSuchMethod(AstNode node) {
    final MethodDeclaration? method = node
        .thisOrAncestorOfType<MethodDeclaration>();
    if (method == null || method.name.lexeme != 'noSuchMethod') return false;

    // `noSuchMethod(Invocation invocation)` always has exactly one formal
    // parameter; if that shape is missing (malformed override) there is
    // nothing to scope the exemption to.
    final List<FormalParameter>? parameters = method.parameters?.parameters;
    if (parameters == null || parameters.isEmpty) return false;
    final Element? invocationParam = parameters.first.declaredFragment?.element;
    if (invocationParam == null) return false;

    // Walk this call site's own subtree for a reference back to the
    // `Invocation` parameter. Only THAT call site is exempt — sibling
    // dynamic calls elsewhere in the body are unaffected since each is
    // checked independently against its own subtree.
    final _ElementReferenceFinder finder = _ElementReferenceFinder(
      invocationParam,
    );
    node.accept(finder);
    return finder.found;
  }
}

/// Searches an AST subtree for any [SimpleIdentifier] resolving to
/// [_target], used to confirm a dynamic call site inside a `noSuchMethod`
/// override actually derives from the override's `Invocation` parameter
/// (rather than exempting the whole method body).
class _ElementReferenceFinder extends RecursiveAstVisitor<void> {
  _ElementReferenceFinder(this._target);

  final Element _target;

  /// Set true the moment a matching identifier is found; traversal is not
  /// short-circuited (RecursiveAstVisitor has no early-exit), but that's
  /// cheap given these are small call-site subtrees.
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == _target) {
      found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}
