// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

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
  String get exampleGood =>
      'if (x == null) return; if (y == null) return; doWork();';

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

/// Warns when positive conditions first is preferred (opposite rule).
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v2
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
  PreferPositiveConditionsFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_positive_conditions_first',
    '[prefer_positive_conditions_first] Guard clauses with negated conditions push the happy path deeper into the function. Positive conditions make the primary logic path prominent and easier to understand. {v2}',
    correctionMessage:
        'Restructure to place the positive condition first so the happy path is prominent and easier to follow.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((node) {
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
            reporter.atNode(node);
          }
        } else if (condition is PrefixExpression &&
            condition.operator.type == TokenType.BANG) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when switch expression is preferred over statement (opposite).
///
/// Since: v4.13.0 | Rule version: v1
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
  PreferSwitchStatementRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_switch_statement',
    '[prefer_switch_statement] Switch expressions limit flexibility for side effects and debugging. Switch statements support imperative logic, breakpoints, and multi-line case bodies. {v1}',
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
      reporter.atNode(node);
    });
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
      if (stmt.expression == null) return;

      // Check if return expression contains await
      if (!_containsAwaitExpression(stmt.expression!)) {
        reporter.atNode(body);
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

  static const LintCode _code = LintCode(
    'prefer_positive_conditions',
    '[prefer_positive_conditions] Prefer a positive condition with '
        'the branches swapped for readability. {v3}',
    correctionMessage:
        'Invert the condition to its positive form and swap the '
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
