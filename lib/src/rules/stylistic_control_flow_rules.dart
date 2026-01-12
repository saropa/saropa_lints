// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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

// =============================================================================
// CONTROL FLOW RULES
// =============================================================================

/// Warns when deeply nested if-else can be refactored to early returns.
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
  const PreferEarlyReturnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_early_return',
    problemMessage: 'Consider using early return instead of nested if blocks.',
    correctionMessage: 'Guard clauses at the top reduce nesting.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((node) {
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
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when early return is used instead of single exit point (opposite).
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
  const PreferSingleExitPointRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_single_exit_point',
    problemMessage:
        'Consider using single exit point instead of early returns.',
    correctionMessage: 'Single exit makes cleanup and logging easier.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionBody((node) {
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
              reporter.atNode(stmt, code);
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
  const PreferGuardClausesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_guard_clauses',
    problemMessage:
        'Consider using guard clauses at the start of the function.',
    correctionMessage: 'Guard clauses make preconditions explicit.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionBody((node) {
      if (node is! BlockFunctionBody) return;

      final statements = node.block.statements;
      if (statements.isEmpty) return;

      // Check if function starts with an if that wraps most of the body
      final first = statements.first;
      if (first is! IfStatement) return;
      if (first.elseStatement != null) return;

      // If the if statement is the only statement or wraps most code
      if (statements.length == 1) {
        reporter.atNode(first, code);
      }
    });
  }
}

/// Warns when positive conditions first is preferred (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of positive conditions first:**
/// - Happy path is prominent
/// - Less negation in conditions
/// - More optimistic code style
///
/// **Cons (why some teams prefer guard clauses):**
/// - More nesting
/// - Preconditions not as visible
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void process(User? user) {
///   if (user == null) return;
///   // do work
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void process(User? user) {
///   if (user != null) {
///     // do work
///   }
/// }
/// ```
class PreferPositiveConditionsFirstRule extends SaropaLintRule {
  const PreferPositiveConditionsFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_positive_conditions_first',
    problemMessage: 'Consider using positive conditions with happy path first.',
    correctionMessage: 'Positive conditions are easier to understand.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((node) {
      // Check for guard clause pattern: if (negative) return;
      if (node.elseStatement != null) return;

      final thenStmt = node.thenStatement;
      Statement? inner = thenStmt;
      if (inner is Block && inner.statements.length == 1) {
        inner = inner.statements.first;
      }

      // If the then branch is just a return, it's a guard clause
      if (inner is ReturnStatement) {
        // Check if condition is negative
        final condition = node.expression;
        if (condition is BinaryExpression &&
            condition.operator.type == TokenType.EQ_EQ) {
          if (condition.rightOperand is NullLiteral ||
              condition.leftOperand is NullLiteral) {
            reporter.atNode(node, code);
          }
        } else if (condition is PrefixExpression &&
            condition.operator.type == TokenType.BANG) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when switch statement could be a switch expression.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of switch expression:**
/// - More concise for value production
/// - Exhaustiveness checking
/// - Dart 3.0+ idiomatic
///
/// **Cons (why some teams prefer switch statement):**
/// - More familiar
/// - Easier to add side effects
/// - Works in all Dart versions
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// String getLabel(Status status) {
///   switch (status) {
///     case Status.active: return 'Active';
///     case Status.inactive: return 'Inactive';
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// String getLabel(Status status) => switch (status) {
///   Status.active => 'Active',
///   Status.inactive => 'Inactive',
/// };
/// ```
class PreferSwitchExpressionRule extends SaropaLintRule {
  const PreferSwitchExpressionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_expression',
    problemMessage: 'Consider using switch expression instead of statement.',
    correctionMessage:
        'Switch expressions are more concise for value production.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((node) {
      // Check if all cases just return a value
      bool allReturn = true;

      for (final member in node.members) {
        if (member is SwitchCase) {
          final statements = member.statements;
          if (statements.length != 1) {
            allReturn = false;
            break;
          }
          if (statements.first is! ReturnStatement) {
            allReturn = false;
            break;
          }
        } else if (member is SwitchDefault) {
          final statements = member.statements;
          if (statements.length != 1 || statements.first is! ReturnStatement) {
            allReturn = false;
            break;
          }
        }
      }

      if (allReturn && node.members.isNotEmpty) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when switch expression is preferred over statement (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of switch statement:**
/// - More familiar pattern
/// - Easier to add side effects
/// - Works in all Dart versions
///
/// **Cons (why some teams prefer expression):**
/// - More verbose
/// - Less idiomatic Dart 3.0+
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final label = switch (status) {
///   Status.active => 'Active',
///   Status.inactive => 'Inactive',
/// };
/// ```
///
/// #### GOOD:
/// ```dart
/// String label;
/// switch (status) {
///   case Status.active: label = 'Active'; break;
///   case Status.inactive: label = 'Inactive'; break;
/// }
/// ```
class PreferSwitchStatementRule extends SaropaLintRule {
  const PreferSwitchStatementRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_switch_statement',
    problemMessage: 'Consider using switch statement instead of expression.',
    correctionMessage: 'Switch statements are more familiar and flexible.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when cascade could be used instead of chained calls for mutations.
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
  const PreferCascadeOverChainedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_cascade_over_chained',
    problemMessage: 'Consider using cascade (..) for consecutive mutations.',
    correctionMessage: 'Cascades make it clear operations are on same object.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((node) {
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
                  reporter.atNode(firstConsecutive!, code);
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
  const PreferChainedOverCascadeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_chained_over_cascade',
    problemMessage: 'Consider using separate statements instead of cascade.',
    correctionMessage: 'Separate statements are more familiar and explicit.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCascadeExpression((node) {
      if (node.cascadeSections.length >= 2) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when default case is used in enum switch instead of exhaustive cases.
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
  const PreferExhaustiveEnumsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_exhaustive_enums',
    problemMessage: 'Prefer exhaustive enum cases instead of default.',
    correctionMessage:
        'Exhaustive switches catch missing cases at compile time.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when exhaustive cases is preferred over default (opposite).
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
  const PreferDefaultEnumCaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_default_enum_case',
    problemMessage: 'Consider using default case for future-proofing.',
    correctionMessage: 'Default case handles unknown enum values gracefully.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// ASYNC RULES
// =============================================================================

/// Warns when a function is marked async but doesn't use await.
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
class PreferAsyncOnlyWhenAwaitingRule extends SaropaLintRule {
  const PreferAsyncOnlyWhenAwaitingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_async_only_when_awaiting',
    problemMessage: 'Function is async but does not use await.',
    correctionMessage: 'Remove async or add await expressions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionBody((node) {
      if (node is! BlockFunctionBody) return;
      if (!node.isAsynchronous) return;

      // Check for await expressions
      bool hasAwait = false;

      void checkStatement(Statement stmt) {
        if (hasAwait) return;

        if (stmt is ExpressionStatement) {
          if (_containsAwaitExpression(stmt.expression)) hasAwait = true;
        } else if (stmt is ReturnStatement && stmt.expression != null) {
          if (_containsAwaitExpression(stmt.expression!)) hasAwait = true;
        } else if (stmt is VariableDeclarationStatement) {
          for (final v in stmt.variables.variables) {
            if (v.initializer != null &&
                _containsAwaitExpression(v.initializer!)) {
              hasAwait = true;
            }
          }
        } else if (stmt is IfStatement) {
          checkStatement(stmt.thenStatement);
          if (stmt.elseStatement != null) {
            checkStatement(stmt.elseStatement!);
          }
        } else if (stmt is Block) {
          for (final s in stmt.statements) {
            checkStatement(s);
          }
        } else if (stmt is ForStatement) {
          checkStatement(stmt.body);
        } else if (stmt is WhileStatement) {
          checkStatement(stmt.body);
        } else if (stmt is TryStatement) {
          checkStatement(stmt.body);
          for (final clause in stmt.catchClauses) {
            checkStatement(clause.body);
          }
          if (stmt.finallyBlock != null) {
            checkStatement(stmt.finallyBlock!);
          }
        }
      }

      for (final stmt in node.block.statements) {
        checkStatement(stmt);
        if (hasAwait) break;
      }

      if (!hasAwait) {
        reporter.atNode(node, code);
      }
    });
  }
}

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
  const PreferAwaitOverThenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_await_over_then',
    problemMessage: 'Consider using await instead of .then() chains.',
    correctionMessage: 'await provides better readability and error handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name == 'then') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when .then() is preferred over await (opposite rule).
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
  const PreferThenOverAwaitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_then_over_await',
    problemMessage: 'Consider using .then() for functional style.',
    correctionMessage: '.then() provides explicit Future chaining.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when Future.value() could be used instead of async for simple returns.
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
  const PreferSyncOverAsyncWhereSimpleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_sync_over_async_where_possible',
    problemMessage: 'Consider returning Future.value() for simple sync values.',
    correctionMessage: 'Avoid async overhead when not awaiting.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      final body = node.body;
      if (body is! BlockFunctionBody) return;
      if (!body.isAsynchronous) return;

      // Check if body is just a single return statement
      final statements = body.block.statements;
      if (statements.length != 1) return;

      final stmt = statements.first;
      if (stmt is! ReturnStatement) return;
      if (stmt.expression == null) return;

      // Check if return expression contains await
      if (!_containsAwaitExpression(stmt.expression!)) {
        reporter.atNode(body, code);
      }
    });
  }
}
