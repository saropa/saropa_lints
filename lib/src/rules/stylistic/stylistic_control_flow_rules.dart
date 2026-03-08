// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC CONTROL FLOW & ASYNC RULES
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences for control flow patterns and async handling.
// ============================================================================

// =============================================================================
// SHARED HELPERS
// =============================================================================

/// Checks if an expression contains an await expression.
bool _containsAwaitExpression(Expression expr) {
  if (expr is AwaitExpression) return true;
  // Recursively check nested expressions
  for (final child in expr.childEntities) {
    if (child is Expression && _containsAwaitExpression(child)) return true;
  }

  return false;
}

/// Returns true if [stmt] (or any descendant) contains an AwaitExpression.
bool _statementContainsAwait(Statement stmt) {
  bool found = false;
  stmt.visitChildren(_AwaitFinder(() => found = true));
  return found;
}

class _AwaitFinder extends RecursiveAstVisitor<void> {
  _AwaitFinder(this._onFound);
  final void Function() _onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _onFound();
    super.visitAwaitExpression(node);
  }
}

// =============================================================================
// CONTROL FLOW RULES
// =============================================================================

/// Warns when deeply nested if-else can be refactored to early returns.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v7
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of early return:**
/// - Reduces nesting and indentation
/// - Easier to follow linear logic
/// - Guards are at the top
///
/// **Cons (why some teams prefer single exit):**
/// - Single exit point is more structured
/// - Easier to add cleanup/logging at end
/// - Some style guides mandate it
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process(String? input) {
///   if (input != null) {
///     if (input.isNotEmpty) {
///       if (input.length > 3) {
///         // do work
///       }
///     }
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process(String? input) {
///   if (input == null) return;
///   if (input.isEmpty) return;
///   if (input.length <= 3) return;
///   // do work
/// }
/// ```
class PreferEarlyReturnRule extends SaropaLintRule {
  PreferEarlyReturnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'if (x != null) { if (y != null) { doWork(); } }';

  @override
  String get exampleGood => 'if (x == null) return;\n'
      'if (y == null) return;\n'
      'doWork();';

  static const LintCode _code = LintCode(
    'prefer_early_return',
    '[prefer_early_return] Deeply nested if blocks increase cognitive load and make code harder to follow. Early returns flatten the structure and clarify preconditions. {v7}',
    correctionMessage:
        'Invert conditions and return early at the top of the function to reduce nesting and improve readability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((node) {
      // Check for nested if without else
      if (node.elseStatement != null) return;

      final thenStmt = node.thenStatement;
      Statement? innerStmt = thenStmt;

      // Unwrap block if needed
      if (innerStmt is Block && innerStmt.statements.length == 1) {
        innerStmt = innerStmt.statements.first;
      }

      // Check if the only statement is another if without else
      if (innerStmt is IfStatement && innerStmt.elseStatement == null) {
        // Found nested if pattern - count depth
        int depth = 2;
        Statement? current = innerStmt.thenStatement;
        while (current != null) {
          if (current is Block && current.statements.length == 1) {
            current = current.statements.first;
          }
          if (current is IfStatement && current.elseStatement == null) {
            depth++;
            current = current.thenStatement;
          } else {
            break;
          }
        }

        if (depth >= 3) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when early return is used instead of single exit point (opposite).
///
/// Since: v4.13.0 | Rule version: v1
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of single exit:**
/// - More structured flow
/// - Easier to add cleanup/logging at end
/// - Some style guides mandate it
///
/// **Cons (why some teams prefer early return):**
/// - More nesting
/// - Harder to follow for complex conditions
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process(String? input) {
///   if (input == null) return;
///   if (input.isEmpty) return;
///   // do work
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process(String? input) {
///   if (input != null && input.isNotEmpty) {
///     // do work
///   }
/// }
/// ```
class PreferSingleExitPointRule extends SaropaLintRule {
  PreferSingleExitPointRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'if (x == null) return;\n'
      'if (y == null) return;\n'
      'doWork();';

  @override
  String get exampleGood => 'if (x != null && y != null) {\n'
      '  doWork();\n'
      '}';

  /// Alias: prefer_single_exit
  static const LintCode _code = LintCode(
    'prefer_single_exit_point',
    '[prefer_single_exit_point] Multiple return statements (early exits) make it harder to ensure cleanup, logging, and consistent resource management at the end of a function. This can lead to missed cleanup, inconsistent state, and bugs that are difficult to trace. Refactor to a single exit point so all cleanup and logging happens reliably before returning. {v1}',
    correctionMessage:
        'Refactor to a single exit point: move cleanup and logging to the end, and return once.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionBody((node) {
      if (node is! BlockFunctionBody) return;

      int returnCount = 0;
      for (final stmt in node.block.statements) {
        _countReturns(stmt, (count) => returnCount += count);
      }

      // Flag if more than one return (multiple exit points)
      if (returnCount > 1) {
        // Find the first early return (return not at the end)
        final statements = node.block.statements;
        for (int i = 0; i < statements.length - 1; i++) {
          final stmt = statements[i];
          if (stmt is IfStatement) {
            final thenStmt = stmt.thenStatement;
            if (_containsReturn(thenStmt)) {
              reporter.atNode(stmt);
              return;
            }
          }
        }
      }
    });
  }

  void _countReturns(Statement stmt, void Function(int) addCount) {
    if (stmt is ReturnStatement) {
      addCount(1);
    } else if (stmt is Block) {
      for (final s in stmt.statements) {
        _countReturns(s, addCount);
      }
    } else if (stmt is IfStatement) {
      _countReturns(stmt.thenStatement, addCount);
      if (stmt.elseStatement != null) {
        _countReturns(stmt.elseStatement!, addCount);
      }
    }
  }

  bool _containsReturn(Statement stmt) {
    if (stmt is ReturnStatement) return true;
    if (stmt is Block) {
      for (final s in stmt.statements) {
        if (_containsReturn(s)) return true;
      }
    }
    return false;
  }
}

/// Warns when guard clauses could be used at function start.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of guard clauses:**
/// - Validation at the top
/// - Clear preconditions
/// - Flat code structure
///
/// **Cons (why some teams prefer positive conditions):**
/// - Happy path first is clearer
/// - Less negation in conditions
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process(User? user) {
///   if (user != null) {
///     if (user.isActive) {
///       // do work
///     }
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process(User? user) {
///   if (user == null) return;
///   if (!user.isActive) return;
///   // do work
/// }
/// ```
class PreferGuardClausesRule extends SaropaLintRule {
  PreferGuardClausesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'void f(x) { if (x != null) { /* body */ } }';

  @override
  String get exampleGood => 'void f(x) { if (x == null) return; /* body */ }';

  static const LintCode _code = LintCode(
    'prefer_guard_clauses',
    '[prefer_guard_clauses] Wrapping the entire function body in an if block obscures preconditions and increases nesting. Guard clauses make preconditions explicit and help prevent bugs. {v3}',
    correctionMessage:
        'Extract the condition as a guard clause with early return at the top to make preconditions explicit and reduce nesting.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionBody((node) {
      if (node is! BlockFunctionBody) return;

      final statements = node.block.statements;
      if (statements.isEmpty) return;

      // Check if function starts with an if that wraps most of the body
      final first = statements.first;
      if (first is! IfStatement) return;
      if (first.elseStatement != null) return;

      // If the if statement is the only statement or wraps most code
      if (statements.length == 1) {
        reporter.atNode(first);
      }
    });
  }
}

/// Warns when a negated condition is used in a guard clause instead of
/// the positive form.
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// Null-guard clauses (`if (x == null) return;`) are excluded because
/// `== null` is an equality check, not a negation, and the early-return
/// pattern keeps the happy path un-nested.
///
/// **Pros of positive conditions first:**
/// - Less negation in conditions
/// - More optimistic code style
///
/// **Cons (why some teams prefer negated guards):**
/// - Preconditions not as visible
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process(String input) {
///   if (!input.isNotEmpty) return;
///   // do work
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process(String input) {
///   if (input.isNotEmpty) {
///     // do work
///   }
/// }
/// ```
class PreferPositiveConditionsFirstRule extends SaropaLintRule {
  PreferPositiveConditionsFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'if (!isReady) return;  // negated guard';

  @override
  String get exampleGood => 'if (isReady) {\n'
      '  doWork();\n'
      '}';

  static const LintCode _code = LintCode(
    'prefer_positive_conditions_first',
    '[prefer_positive_conditions_first] Negated guard clauses '
        '(if (!condition) return) obscure the intent. '
        'Rewriting with the positive condition makes the logic clearer. '
        'Null-guard clauses (== null) are excluded because they are '
        'equality checks, not negations. {v3}',
    correctionMessage:
        'Remove the negation and restructure so the positive condition '
        'is tested first.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((node) {
      // Only flag guard clauses (no else branch)
      if (node.elseStatement != null) return;

      final thenStmt = node.thenStatement;
      Statement? inner = thenStmt;
      if (inner is Block && inner.statements.length == 1) {
        inner = inner.statements.first;
      }

      // Only flag single-return guard clauses
      if (inner is! ReturnStatement) return;

      // Only flag negated conditions (! operator).
      // Null-equality checks (== null) are NOT negations and are
      // excluded — they are valid guard clause patterns.
      final condition = node.expression;
      if (condition is PrefixExpression &&
          condition.operator.type == TokenType.BANG) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a switch expression is used outside a value-producing position.
///
/// Since: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** — not included in any tier by default.
///
/// Switch expressions in Dart 3 are idiomatic for pure value mappings
/// (arrow bodies, return statements, variable initializers, assignments,
/// and yield statements). This rule only fires when a switch expression
/// appears in a non-value position (e.g. nested in a collection literal
/// or passed as a function argument), where a switch statement would allow
/// side effects, breakpoints, and multi-line case bodies.
///
/// **v2 change:** No longer flags switch expressions in value-producing
/// positions (`=> switch (...)`, `return switch (...)`, variable init,
/// assignment, yield). This eliminates false positives on the canonical
/// Dart 3 enum-to-value mapping pattern.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final widgets = [
///   switch (status) {            // nested in list — not a value position
///     Status.active => Text('Active'),
///     Status.inactive => Text('Inactive'),
///   },
/// ];
/// ```
///
/// #### GOOD:
/// ```dart
/// // Arrow body — idiomatic Dart 3 value mapping (not flagged)
/// String get label => switch (status) {
///   Status.active => 'Active',
///   Status.inactive => 'Inactive',
/// };
/// ```
class PreferSwitchStatementRule extends SaropaLintRule {
  PreferSwitchStatementRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad => 'final widgets = [\n'
      '  switch (s) { 0 => a, _ => b },\n'
      '];';

  @override
  String get exampleGood => 'String get label => switch (s) {\n'
      '  0 => "a", _ => "b",\n'
      '};';

  static const LintCode _code = LintCode(
    'prefer_switch_statement',
    '[prefer_switch_statement] Switch expressions limit flexibility for side effects and debugging. Switch statements support imperative logic, breakpoints, and multi-line case bodies. {v2}',
    correctionMessage:
        'Replace the switch expression with a switch statement to enable side effects, multi-line cases, and debuggability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchExpression((node) {
      if (_isValuePositionSwitch(node)) return;
      reporter.atNode(node);
    });
  }

  /// Returns true when the switch expression is in a value-producing position
  /// where it is idiomatic Dart 3 (arrow body, return, variable init,
  /// assignment, yield, named argument).
  static bool _isValuePositionSwitch(SwitchExpression node) {
    final parent = node.parent;

    // => switch (...) { ... }  (getter / method arrow body)
    if (parent is ExpressionFunctionBody) return true;

    // return switch (...) { ... };
    if (parent is ReturnStatement) return true;

    // final x = switch (...) { ... };
    if (parent is VariableDeclaration) return true;

    // x = switch (...) { ... };
    if (parent is AssignmentExpression && parent.rightHandSide == node) {
      return true;
    }

    // yield switch (...) { ... };
    if (parent is YieldStatement) return true;

    // label: switch (...) { ... }  (named argument — value position)
    if (parent is NamedExpression) return true;

    return false;
  }
}

/// Warns when cascade could be used instead of chained calls for mutations.
///
/// Since: v4.13.0 | Rule version: v1
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of cascade:**
/// - Clear that mutations are on same object
/// - Works with void methods
/// - No intermediate variables
///
/// **Cons (why some teams prefer chained):**
/// - Chaining is more familiar
/// - Works with builder patterns
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final list = [];
/// list.add(1);
/// list.add(2);
/// list.add(3);
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = []
///   ..add(1)
///   ..add(2)
///   ..add(3);
/// ```
class PreferCascadeOverChainedRule extends SaropaLintRule {
  PreferCascadeOverChainedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'list.add(1); list.add(2); list.add(3);';

  @override
  String get exampleGood => 'list..add(1)..add(2)..add(3);';

  static const LintCode _code = LintCode(
    'prefer_cascade_over_chained',
    '[prefer_cascade_over_chained] Consecutive method calls on the same variable repeat the target name unnecessarily. Cascade notation (..) signals that all operations mutate the same object. {v1}',
    correctionMessage:
        'Rewrite consecutive calls using cascade (..) to eliminate the repeated variable name and clarify mutation intent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((node) {
      // Look for consecutive method calls on the same variable
      final statements = node.statements;
      String? lastTarget;
      int consecutiveCount = 0;
      Statement? firstConsecutive;

      for (final stmt in statements) {
        if (stmt is ExpressionStatement) {
          final expr = stmt.expression;
          if (expr is MethodInvocation) {
            final target = expr.target;
            if (target is SimpleIdentifier) {
              final targetName = target.name;
              if (targetName == lastTarget) {
                consecutiveCount++;
                if (consecutiveCount == 2) {
                  final node = firstConsecutive;
                  if (node != null) reporter.atNode(node, code);
                }
              } else {
                lastTarget = targetName;
                consecutiveCount = 1;
                firstConsecutive = stmt;
              }
              continue;
            }
          }
        }
        // Reset on non-matching statement
        lastTarget = null;
        consecutiveCount = 0;
        firstConsecutive = null;
      }
    });
  }
}

/// Warns when chained calls are preferred over cascade (opposite).
///
/// Since: v4.13.0 | Rule version: v1
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of chained calls:**
/// - More familiar pattern
/// - Works with builder APIs
/// - Consistent with other languages
///
/// **Cons (why some teams prefer cascade):**
/// - Doesn't work with void methods
/// - Less clear about target object
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final list = []
///   ..add(1)
///   ..add(2);
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [];
/// list.add(1);
/// list.add(2);
/// ```
class PreferChainedOverCascadeRule extends SaropaLintRule {
  PreferChainedOverCascadeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'paint..color = red..strokeWidth = 2;';

  @override
  String get exampleGood => 'paint.color = red; paint.strokeWidth = 2;';

  static const LintCode _code = LintCode(
    'prefer_chained_over_cascade',
    '[prefer_chained_over_cascade] Cascade notation is unfamiliar to developers from other languages and breaks builder patterns. Separate statements are explicit about each operation. {v1}',
    correctionMessage:
        'Replace cascade (..) with separate statements to improve readability and maintain compatibility with builder patterns.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCascadeExpression((node) {
      if (node.cascadeSections.length >= 2) {
        reporter.atNode(node);
      }
    });
  }
}

/// Discourages use of cascade notation (..) for clarity and maintainability.
///
/// Reports every [CascadeExpression]. Teams that prefer explicit statements
/// over fluent-style cascades can enable this (Stylistic tier). No recursion
/// or cross-file logic; single-node callback only.
///
/// **Bad:**
/// ```dart
/// controller..forward()..repeat();
/// list..add(1)..add(2);
/// ```
///
/// **Good:**
/// ```dart
/// controller.forward();
/// controller.repeat();
/// list.add(1);
/// list.add(2);
/// ```
class AvoidCascadesRule extends SaropaLintRule {
  AvoidCascadesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad => 'list..add(1)..add(2);  // cascade';

  @override
  String get exampleGood => 'list.add(1); list.add(2);  // separate';

  static const LintCode _code = LintCode(
    'avoid_cascade_notation',
    '[avoid_cascade_notation] Cascade notation (..) can reduce clarity and maintainability. Use separate statements for each operation. {v1}',
    correctionMessage:
        'Replace cascade (..) with separate method calls or property assignments.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<String> get configAliases => const ['avoid_cascades'];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCascadeExpression((node) {
      reporter.atNode(node);
    });
  }
}

/// Warns when default case is used in enum switch instead of exhaustive cases.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of exhaustive cases:**
/// - Compiler catches missing cases
/// - No hidden behavior in default
/// - Future-proof when enum grows
///
/// **Cons (why some teams prefer default):**
/// - Simpler for large enums
/// - Handles unknown values gracefully
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// switch (status) {
///   case Status.active: return 'Active';
///   default: return 'Other';
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// switch (status) {
///   case Status.active: return 'Active';
///   case Status.inactive: return 'Inactive';
///   case Status.pending: return 'Pending';
/// }
/// ```
class PreferExhaustiveEnumsRule extends SaropaLintRule {
  PreferExhaustiveEnumsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'switch (s) {\n'
      '  case S.a: break;\n'
      '  default: break;  // hides missing cases\n'
      '}';

  @override
  String get exampleGood => 'switch (s) {\n'
      '  case S.a: break;\n'
      '  case S.b: break;  // exhaustive\n'
      '}';

  static const LintCode _code = LintCode(
    'prefer_exhaustive_enums',
    '[prefer_exhaustive_enums] Prefer exhaustive enum cases instead of default. Exhaustive cases catch missing logic at compile time and prevent silent failures. {v2}',
    correctionMessage:
        'Remove the default branch and list every enum value explicitly so the compiler flags missing cases after additions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((node) {
      // Check if switching on an enum (heuristic: has case with enum prefix)
      bool looksLikeEnum = false;
      bool hasDefault = false;

      for (final member in node.members) {
        if (member is SwitchCase) {
          final expr = member.expression;
          if (expr is PrefixedIdentifier) {
            looksLikeEnum = true;
          }
        } else if (member is SwitchDefault) {
          hasDefault = true;
        }
      }

      if (looksLikeEnum && hasDefault) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when exhaustive cases is preferred over default (opposite).
///
/// Since: v4.13.0 | Rule version: v1
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of default case:**
/// - Handles unknown/future values
/// - Simpler for large enums
/// - Defensive programming
///
/// **Cons (why some teams prefer exhaustive):**
/// - Hides missing case handling
/// - Silent failures possible
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// switch (status) {
///   case Status.active: return 'Active';
///   case Status.inactive: return 'Inactive';
///   case Status.pending: return 'Pending';
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// switch (status) {
///   case Status.active: return 'Active';
///   default: return 'Other';
/// }
/// ```
class PreferDefaultEnumCaseRule extends SaropaLintRule {
  PreferDefaultEnumCaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'switch (s) {\n'
      '  case S.a: break;\n'
      '  case S.b: break;  // no default\n'
      '}';

  @override
  String get exampleGood => 'switch (s) {\n'
      '  case S.a: break;\n'
      '  default: break;  // handles future values\n'
      '}';

  static const LintCode _code = LintCode(
    'prefer_default_enum_case',
    '[prefer_default_enum_case] Exhaustive enum switches break at compile time when new values are added, requiring immediate updates across the codebase. A default case handles unknown values gracefully. {v1}',
    correctionMessage:
        'Add a default case to handle unknown or future enum values gracefully and prevent compile-time breakage on enum changes.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((node) {
      // Check if switching on enum without default
      bool looksLikeEnum = false;
      bool hasDefault = false;

      for (final member in node.members) {
        if (member is SwitchCase) {
          final expr = member.expression;
          if (expr is PrefixedIdentifier) {
            looksLikeEnum = true;
          }
        } else if (member is SwitchDefault) {
          hasDefault = true;
        }
      }

      if (looksLikeEnum && !hasDefault) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// ASYNC RULES
// =============================================================================

/// Warns when a function is marked async but doesn't use await.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of only async when awaiting:**
/// - Clear that async is intentional
/// - No unnecessary Future wrapping
/// - More precise function signatures
///
/// **Cons (why some teams allow async without await):**
/// - Consistency with other async methods
/// - Easier to add await later
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Future<int> getValue() async {
///   return 42;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Future<int> getValue() {
///   return Future.value(42);
/// }
/// // Or if you actually await:
/// Future<int> getValue() async {
///   return await computeValue();
/// }
/// ```
/// Warns when await is preferred over .then() chains.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of await:**
/// - More readable, sequential style
/// - Better error handling with try/catch
/// - Idiomatic Dart
///
/// **Cons (why some teams prefer then):**
/// - Functional style
/// - Chain transformations easily
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// fetchData().then((data) => processData(data)).then((result) => save(result));
/// ```
///
/// #### GOOD:
/// ```dart
/// final data = await fetchData();
/// final result = await processData(data);
/// await save(result);
/// ```
class PreferAwaitOverThenRule extends SaropaLintRule {
  PreferAwaitOverThenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad => 'fetchData().then((d) => process(d));';

  @override
  String get exampleGood => 'final d = await fetchData(); process(d);';

  static const LintCode _code = LintCode(
    'prefer_await_over_then',
    '[prefer_await_over_then] The .then() chain obscures sequential async logic and complicates error handling. Rewrite with await for clearer control flow. {v3}',
    correctionMessage:
        'Replace .then() with await to enable sequential reading, try/catch error handling, and easier debugging of async code.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      if (node.methodName.name == 'then') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when .then() is preferred over await (opposite rule).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of then:**
/// - Functional style
/// - Chain transformations easily
/// - Explicit about asynchrony
///
/// **Cons (why some teams prefer await):**
/// - Harder to read chains
/// - Error handling with catchError
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final data = await fetchData();
/// final result = await processData(data);
/// ```
///
/// #### GOOD:
/// ```dart
/// fetchData().then((data) => processData(data)).then((result) => save(result));
/// ```
class PreferThenOverAwaitRule extends SaropaLintRule {
  PreferThenOverAwaitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'final d = await fetchData(); process(d);';

  @override
  String get exampleGood => 'fetchData().then(process).then(save);';

  static const LintCode _code = LintCode(
    'prefer_then_over_await',
    '[prefer_then_over_await] The await keyword introduces implicit suspension points that break functional composition. Use .then() for explicit Future chaining. {v2}',
    correctionMessage:
        'Replace await with .then() to maintain functional composition and make asynchronous data flow explicit in the call chain.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAwaitExpression((node) {
      reporter.atNode(node);
    });
  }
}

/// Warns when Future.value() could be used instead of async for simple returns.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of sync return:**
/// - No unnecessary async overhead
/// - Clearer about synchronous nature
/// - Explicit Future wrapping
///
/// **Cons (why some teams prefer async):**
/// - Consistent with other async methods
/// - Easier to add await later
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Future<int> getValue() async {
///   return 42;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Future<int> getValue() {
///   return Future.value(42);
/// }
/// ```
class PreferSyncOverAsyncWhereSimpleRule extends SaropaLintRule {
  PreferSyncOverAsyncWhereSimpleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'Future<int> f() async { return 42; }';

  @override
  String get exampleGood => 'Future<int> f() => Future.value(42);';

  static const LintCode _code = LintCode(
    'prefer_sync_over_async_where_possible',
    '[prefer_sync_over_async_where_possible] Marking a function async when it only returns a synchronous value adds unnecessary Future wrapping overhead and obscures intent. {v3}',
    correctionMessage:
        'Remove the async keyword and return Future.value() directly to eliminate unnecessary Future wrapping and clarify synchronous intent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((node) {
      final body = node.body;
      if (body is! BlockFunctionBody) return;
      if (!body.isAsynchronous) return;

      // Check if body is just a single return statement
      final statements = body.block.statements;
      if (statements.length != 1) return;

      final stmt = statements.first;
      if (stmt is! ReturnStatement) return;
      final returnExpr = stmt.expression;
      if (returnExpr == null) return;

      // Check if return expression contains await
      if (!_containsAwaitExpression(returnExpr)) {
        reporter.atNode(body);
      }
    });
  }
}

/// Warns when try/catch is used for async error handling instead of .then().catchError().
///
/// Stylistic: some teams prefer chained .then().catchError() for single-Future error
/// handling so that errors are handled at the call site without try/catch.
///
/// **Bad:**
/// ```dart
/// try {
///   final x = await fetchData();
///   use(x);
/// } catch (e, st) {
///   log(e, st);
/// }
/// ```
///
/// **Good:**
/// ```dart
/// fetchData().then(use).catchError(log);
/// ```
class PreferThenCatchErrorRule extends SaropaLintRule {
  PreferThenCatchErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'try {\n'
      '  await fetch();\n'
      '} catch (e) { log(e); }';

  @override
  String get exampleGood => 'fetch().then(use).catchError(log);';

  static const LintCode _code = LintCode(
    'prefer_then_catcherror',
    '[prefer_then_catcherror] Prefer .then().catchError() over try/catch for async error handling when handling a single Future.',
    correctionMessage:
        'Consider refactoring to use .then().catchError() on the Future.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      if (!_statementContainsAwait(node.body)) return;
      reporter.atNode(node);
    });
  }
}

/// Suggests fire-and-forget (unawaited) when the Future result is not used.
///
/// Stylistic: awaiting a Future and ignoring the result is clearer as
/// unawaited(future) or just calling without await so the intent is explicit.
///
/// **Bad:**
/// ```dart
/// void onTap() async {
///   await logEvent();  // result unused
/// }
/// ```
///
/// **Good:**
/// ```dart
/// void onTap() {
///   unawaited(logEvent());
/// }
/// ```
class PreferFireAndForgetRule extends SaropaLintRule {
  PreferFireAndForgetRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad => 'await logEvent();  // result unused';

  @override
  String get exampleGood => 'unawaited(logEvent());';

  static const LintCode _code = LintCode(
    'prefer_fire_and_forget',
    '[prefer_fire_and_forget] Await is used but the Future result is not used; consider fire-and-forget (unawaited) to make intent explicit.',
    correctionMessage:
        'Use unawaited() or remove await if the result is not needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAwaitExpression((AwaitExpression node) {
      final AstNode? parent = node.parent;
      if (parent is! ExpressionStatement) return;
      reporter.atNode(node);
    });
  }
}

/// Suggests separate assignments over cascade for assignments.
///
/// Stylistic: some teams prefer separate statements over obj..a=1..b=2.
///
/// **Bad:**
/// ```dart
/// context..size = 1..debug = true;
/// ```
///
/// **Good:**
/// ```dart
/// context.size = 1;
/// context.debug = true;
/// ```
class PreferSeparateAssignmentsRule extends SaropaLintRule {
  PreferSeparateAssignmentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad => 'ctx..size = 1..debug = true;  // cascade';

  @override
  String get exampleGood => 'ctx.size = 1; ctx.debug = true;  // separate';

  static const LintCode _code = LintCode(
    'prefer_separate_assignments',
    '[prefer_separate_assignments] Prefer separate assignment statements over cascade assignment.',
    correctionMessage: 'Replace with separate assignment statements.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCascadeExpression((CascadeExpression node) {
      reporter.atNode(node);
    });
  }
}

/// Prefer if-else over guard clauses for certain logic (opinionated).
///
/// Flags blocks that contain two or more consecutive guard-style if statements
/// (if (cond) return;). Some teams prefer if-else for symmetry.
///
/// **Bad:**
/// ```dart
/// void f(int x) {
///   if (x < 0) return;
///   if (x > 10) return;
///   print(x);
/// }
/// ```
///
/// **Good:**
/// ```dart
/// void f(int x) {
///   if (x < 0) {
///     return;
///   } else if (x > 10) {
///     return;
///   } else {
///     print(x);
///   }
/// }
/// ```
class PreferIfElseOverGuardsRule extends SaropaLintRule {
  PreferIfElseOverGuardsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'if (x < 0) return;\n'
      'if (x > 10) return;  // consecutive guards';

  @override
  String get exampleGood => 'if (x < 0) {\n'
      '  return;\n'
      '} else if (x > 10) {\n'
      '  return;\n'
      '}';

  static const LintCode _code = LintCode(
    'prefer_if_else_over_guards',
    '[prefer_if_else_over_guards] Consecutive guard clauses (if-return) could be expressed as if-else for symmetry.',
    correctionMessage:
        'Consider refactoring guard clauses into an if-else structure.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final statements = node.statements;
      if (statements.length < 2) return;
      for (int i = 0; i < statements.length - 1; i++) {
        final a = statements[i];
        final b = statements[i + 1];
        if (a is IfStatement &&
            b is IfStatement &&
            _isGuardStyle(a) &&
            _isGuardStyle(b)) {
          reporter.atNode(a);
          return;
        }
      }
    });
  }

  static bool _isGuardStyle(IfStatement stmt) {
    if (stmt.elseStatement != null) return false;
    final then = stmt.thenStatement;
    if (then is ReturnStatement) return true;
    if (then is Block && then.statements.length == 1) {
      return then.statements.single is ReturnStatement;
    }
    return false;
  }
}

/// Prefer cascade (..) for consecutive assignments/calls to the same target.
///
/// Same intent as prefer_cascade_over_chained; alternative rule name for tier config.
///
/// **Bad:**
/// ```dart
/// list.add(1);
/// list.add(2);
/// ```
///
/// **Good:**
/// ```dart
/// list..add(1)..add(2);
/// ```
class PreferCascadeAssignmentsRule extends SaropaLintRule {
  PreferCascadeAssignmentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'list.add(1); list.add(2);  // repeated target';

  @override
  String get exampleGood => 'list..add(1)..add(2);  // cascade';

  static const LintCode _code = LintCode(
    'prefer_cascade_assignments',
    '[prefer_cascade_assignments] Consecutive method calls on the same target; consider cascade notation (..).',
    correctionMessage:
        'Consider using cascade (..) for consecutive calls on the same object.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final statements = node.statements;
      String? lastTarget;
      int consecutiveCount = 0;
      Statement? firstConsecutive;

      for (final stmt in statements) {
        if (stmt is ExpressionStatement) {
          final expr = stmt.expression;
          if (expr is MethodInvocation) {
            final target = expr.target;
            if (target is SimpleIdentifier) {
              final targetName = target.name;
              if (targetName == lastTarget) {
                consecutiveCount++;
                if (consecutiveCount == 2) {
                  final node = firstConsecutive;
                  if (node != null) {
                    reporter.atNode(node);
                    return;
                  }
                }
              } else {
                lastTarget = targetName;
                consecutiveCount = 1;
                firstConsecutive = stmt;
              }
              continue;
            }
          }
        }
        lastTarget = null;
        consecutiveCount = 0;
        firstConsecutive = null;
      }
    });
  }
}

// =============================================================================
// QUICK FIXES
// =============================================================================

// =============================================================================
// POSITIVE CONDITIONS RULE
// =============================================================================

/// Returns true if [expr] is a simple operand safe to flip with `!`.
///
/// Accepts identifiers, property access, method calls, and index access.
/// Rejects binary expressions, prefix expressions, parenthesized expressions,
/// and other compound forms that would require De Morgan's or deeper rewrites.
bool _isSimpleOperand(Expression expr) {
  return expr is SimpleIdentifier ||
      expr is PrefixedIdentifier ||
      expr is PropertyAccess ||
      expr is MethodInvocation ||
      expr is IndexExpression ||
      expr is FunctionExpressionInvocation;
}

/// Warns when an if/else or ternary uses a negative condition.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// Positive conditions are easier to read. When both branches exist, prefer
/// the positive test so the "happy path" appears first.
///
/// Only flags straightforward negations (`!expr` where expr is simple, or
/// `a != b`). Compound conditions with `&&`, `||`, or nested negations are
/// intentionally skipped.
///
/// **Pros of positive conditions:**
/// - Easier to read and reason about
/// - "Happy path" appears first in the code
/// - Reduces cognitive load from double-negatives
///
/// **Cons (why some teams allow negative first):**
/// - Sometimes the negative case IS the important one
/// - Refactoring may break git blame
/// - Team familiarity with existing patterns
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// if (!isValid) {
///   showError();
/// } else {
///   proceed();
/// }
///
/// final label = status != null ? status.name : 'unknown';
/// ```
///
/// #### GOOD:
/// ```dart
/// if (isValid) {
///   proceed();
/// } else {
///   showError();
/// }
///
/// final label = status == null ? 'unknown' : status.name;
/// ```
class PreferPositiveConditionsRule extends SaropaLintRule {
  PreferPositiveConditionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad => 'if (!isValid) {\n'
      '  showError();\n'
      '} else {\n'
      '  proceed();\n'
      '}';

  @override
  String get exampleGood => 'if (isValid) {\n'
      '  proceed();\n'
      '} else {\n'
      '  showError();\n'
      '}';

  static const LintCode _code = LintCode(
    'prefer_positive_conditions',
    '[prefer_positive_conditions] Prefer a positive condition with '
        'the branches swapped for readability. {v3}',
    correctionMessage: 'Invert the condition to its positive form and swap the '
        'then/else branches.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    _checkIfStatements(context, reporter);
    _checkTernaryExpressions(context, reporter);
  }

  void _checkIfStatements(
    SaropaContext context,
    SaropaDiagnosticReporter reporter,
  ) {
    context.addIfStatement((IfStatement node) {
      // Must have an else branch to swap with
      final elseStmt = node.elseStatement;
      if (elseStmt == null) return;

      // Skip else-if chains — too complex
      if (elseStmt is IfStatement) return;

      if (_isNegativeCondition(node.expression)) {
        reporter.atNode(node.expression, code);
      }
    });
  }

  void _checkTernaryExpressions(
    SaropaContext context,
    SaropaDiagnosticReporter reporter,
  ) {
    context.addConditionalExpression((ConditionalExpression node) {
      if (_isNegativeCondition(node.condition)) {
        reporter.atNode(node.condition, code);
      }
    });
  }

  static bool _isNegativeCondition(Expression condition) {
    // Case 1: !simpleExpr
    if (condition is PrefixExpression &&
        condition.operator.type == TokenType.BANG) {
      return _isSimpleOperand(condition.operand);
    }

    // Case 2: a != b  (top-level only — no compound)
    if (condition is BinaryExpression &&
        condition.operator.type == TokenType.BANG_EQ) {
      return true;
    }

    return false;
  }
}

// -----------------------------------------------------------------------------
// Quick fix: swap if/else branches and invert condition
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Quick fix: swap ternary branches and invert condition
// -----------------------------------------------------------------------------
