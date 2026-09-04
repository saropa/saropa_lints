// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC / OPINIONATED RULES
// ============================================================================
//
// This rule is NOT included in any default tier. It represents a team
// preference for cascade notation immediately after object construction —
// there is no objectively "correct" answer, so it lives in the opt-in
// Pedantic tier alongside other cascade/chaining style rules
// (`prefer_cascade_assignments`, `prefer_cascade_over_chained`).
// ============================================================================

/// Returns `true` when [stmt] is a single statement that operates on the
/// freshly-constructed local variable named [varName] — either a method
/// call (`varName.method(...)`) or a simple property assignment
/// (`varName.field = value`).
///
/// Deliberately narrow (AST-shape match, never string/name substring
/// matching — see the false-positive doctrine): a bare reassignment of
/// [varName] itself (`varName = ...`) does NOT match here because its
/// left-hand side is a [SimpleIdentifier], not a [PropertyAccess] /
/// [PrefixedIdentifier] rooted at [varName]. That is intentional — once the
/// variable is reassigned, or once a statement reads/consumes its value
/// instead of only writing to one of its members, the chain is no longer a
/// pure "construct, then configure" cascade opportunity and detection must
/// stop (see proposal edge cases 1 and 3).
bool _isFreshInstanceConfigStatement(Statement stmt, String varName) {
  if (stmt is! ExpressionStatement) return false;
  final Expression expr = stmt.expression;

  // `varName.method(args);`
  if (expr is MethodInvocation) {
    final Expression? target = expr.target;
    if (target is! SimpleIdentifier || target.name != varName) return false;
    // Guard: if any argument reads `varName` back (e.g.
    // `controller.jumpTo(controller.offset);`), folding this into
    // `Ctrl()..jumpTo(controller.offset)` would reference `controller`
    // inside its own initializer — a compile error. Bail on self-reference.
    return !_argumentsReferenceVariable(expr.argumentList, varName);
  }

  // `varName.field = value;` — only plain `=`, never compound assignments
  // (`+=`, `??=`, ...), which usually imply the property is being read as
  // well as written and are a weaker cascade candidate.
  if (expr is AssignmentExpression && expr.operator.type == TokenType.EQ) {
    final Expression lhs = expr.leftHandSide;
    final bool targetsVarName;
    if (lhs is PropertyAccess) {
      final Expression? target = lhs.target;
      targetsVarName = target is SimpleIdentifier && target.name == varName;
    } else if (lhs is PrefixedIdentifier) {
      targetsVarName = lhs.prefix.name == varName;
    } else {
      targetsVarName = false;
    }
    if (!targetsVarName) return false;
    // Guard: the RHS may itself read `varName`, e.g.
    // `controller.selection = TextSelection.collapsed(offset:
    // controller.text.length);`. Cascading that into the constructor's
    // initializer would self-reference the not-yet-bound variable —
    // a compile error — so exclude it from matching.
    return !_expressionReferencesVariable(expr.rightHandSide, varName);
  }

  return false;
}

/// Returns `true` if any argument in [args] contains a reference to the
/// identifier [varName] — used to reject method-call statements that would
/// self-reference the receiver if folded into its own cascade initializer.
bool _argumentsReferenceVariable(ArgumentList args, String varName) {
  for (final Expression arg in args.arguments) {
    if (_expressionReferencesVariable(arg, varName)) return true;
  }
  return false;
}

/// Returns `true` if [expr] (or any of its descendants) reads the bare
/// identifier [varName]. Used to detect the "self-reference before binding"
/// hazard: a configuring statement whose RHS/args mention the variable being
/// constructed can never be safely folded into that variable's own cascade
/// initializer.
bool _expressionReferencesVariable(Expression expr, String varName) {
  final _VariableReferenceVisitor visitor = _VariableReferenceVisitor(
    varName,
  );
  expr.accept(visitor);
  return visitor.found;
}

/// AST visitor that records whether a [SimpleIdentifier] reading [varName]
/// appears anywhere in the visited subtree.
class _VariableReferenceVisitor extends RecursiveAstVisitor<void> {
  _VariableReferenceVisitor(this.varName);

  final String varName;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == varName) found = true;
    super.visitSimpleIdentifier(node);
  }
}

/// Suggests cascade (`..`) notation when two or more consecutive statements
/// each call a method or set a property on the same freshly-constructed
/// local variable.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v1
///
/// This is an **opinionated rule** — not included in any tier by default.
///
/// Repeating a receiver variable name across several consecutive statements
/// right after construction is pure noise: the reader already knows what
/// the variable is from the declaration on the line above, so re-reading
/// its name on every following line adds nothing. Dart's cascade operator
/// collapses this into one expression that reads as "build this object,
/// then configure it".
///
/// Only fires when the two (or more) configuring statements are
/// **immediately** consecutive, directly after the declaration, in the same
/// block — a statement in between that reads the variable, reassigns a
/// different variable, or crosses an `if`/`for` boundary breaks the chain
/// and the rule stays silent (see the class-level detection notes below).
///
/// **BAD:**
/// ```dart
/// final controller = TextEditingController();
/// controller.text = 'hello'; // repeats `controller` for no new information
/// controller.selection = const TextSelection.collapsed(offset: 5);
/// ```
///
/// **GOOD:**
/// ```dart
/// final controller = TextEditingController()
///   ..text = 'hello'
///   ..selection = const TextSelection.collapsed(offset: 5);
/// ```
///
/// **GOOD (not flagged — only one configuring statement):**
/// ```dart
/// final controller = TextEditingController();
/// controller.text = 'hello';
/// ```
///
/// **GOOD (not flagged — an unrelated statement breaks the chain):**
/// ```dart
/// final controller = TextEditingController();
/// controller.text = 'hello';
/// logEvent('controller created');
/// controller.selection = const TextSelection.collapsed(offset: 5);
/// ```
class NewInstanceCascadeRule extends SaropaLintRule {
  NewInstanceCascadeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention', 'cascade'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad =>
      "final c = Ctrl(); c.text = 'a'; c.selection = sel; // repeats `c`";

  @override
  String get exampleGood => "final c = Ctrl()..text = 'a'..selection = sel;";

  static const LintCode _code = LintCode(
    'new_instance_cascade',
    '[new_instance_cascade] Two or more consecutive statements each call a '
        "method or set a property on the same freshly-constructed local "
        'variable. Repeating the receiver name on every line adds no new '
        "information once the reader has seen the declaration; Dart's "
        'cascade (..) notation expresses the same "construct, then '
        'configure" intent as a single chained expression and makes the '
        'shared receiver visually obvious. {v1}',
    correctionMessage:
        'Combine the consecutive calls into a single cascade (..) '
        'expression starting from the constructor call.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final List<Statement> statements = node.statements;

      // Need a declaration plus at least two follow-up statements to have
      // any chance of a 2+ consecutive-statement cascade candidate.
      for (int i = 0; i < statements.length - 2; i++) {
        final Statement stmt = statements[i];
        if (stmt is! VariableDeclarationStatement) continue;

        // Only single-variable declarations are considered — a
        // multi-variable `final a = A(), b = B();` declaration has no
        // single unambiguous "freshly constructed" receiver.
        final NodeList<VariableDeclaration> variables =
            stmt.variables.variables;
        if (variables.length != 1) continue;

        final VariableDeclaration decl = variables.first;
        final Expression? initializer = decl.initializer;
        // Accept a direct `Type(...)` construction, OR a cascade expression
        // rooted at one (`Type()..x = 1`). The latter is only *partially*
        // configured — later, un-cascaded sibling statements are still a
        // legitimate cascade opportunity, so a partial cascade must not
        // stop detection entirely (previously it did, a false negative).
        final bool isFreshInstance =
            initializer is InstanceCreationExpression ||
            (initializer is CascadeExpression &&
                initializer.target is InstanceCreationExpression);
        if (!isFreshInstance) continue;

        final String varName = decl.name.lexeme;

        // Walk forward counting the immediately-consecutive statements that
        // configure `varName`; report at the first statement of a run of 2+.
        // Stop at the first non-matching statement — that enforces
        // "consecutive" and naturally excludes reassignment, reads, and any
        // statement crossing a control-flow boundary (those simply are not
        // siblings in this block's statement list).
        final Statement? candidate = _findConsecutiveConfigRun(
          statements,
          i + 1,
          varName,
        );
        if (candidate != null) reporter.atNode(candidate);
      }
    });
  }
}

/// Returns the first statement of a run of 2 or more immediately-consecutive
/// statements (starting at [startIndex] in [statements]) that each configure
/// [varName], or `null` if no such run exists. Extracted from
/// `runWithReporter` to keep that function under the project's line-count
/// guideline and to make the two nested loops reviewable independently.
Statement? _findConsecutiveConfigRun(
  List<Statement> statements,
  int startIndex,
  String varName,
) {
  int count = 0;
  Statement? first;
  for (int j = startIndex; j < statements.length; j++) {
    if (!_isFreshInstanceConfigStatement(statements[j], varName)) break;
    count++;
    first ??= statements[j];
    if (count >= 2) return first;
  }
  return null;
}
