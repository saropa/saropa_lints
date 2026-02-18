// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../saropa_lint_rule.dart';
import '../type_annotation_utils.dart';
import '../fixes/stylistic_null_collection/prefer_if_null_over_ternary_fix.dart';
import '../fixes/stylistic_null_collection/prefer_ternary_over_if_null_fix.dart';
import '../fixes/stylistic_null_collection/prefer_where_type_fix.dart';

// ============================================================================
// STYLISTIC NULL HANDLING & COLLECTION RULES
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences for null handling and collection patterns.
// ============================================================================

// =============================================================================
// NULL HANDLING RULES
// =============================================================================

/// Warns when `if (x == null) x = value` is used instead of `x ??= value`.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of ??= operator:**
/// - More concise
/// - Idiomatic Dart
/// - Single expression
///
/// **Cons (why some teams prefer explicit):**
/// - More familiar for developers from other languages
/// - Easier to add breakpoints/logging
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// if (name == null) name = 'default';
/// if (name == null) { name = 'default'; }
/// ```
///
/// #### GOOD:
/// ```dart
/// name ??= 'default';
/// ```
class PreferNullAwareAssignmentRule extends SaropaLintRule {
  PreferNullAwareAssignmentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_null_aware_assignment',
    '[prefer_null_aware_assignment] An if-null-then-assign pattern was detected that can be simplified. Replace the verbose null check and assignment block with the ??= operator for a concise, idiomatic single-expression assignment. {v3}',
    correctionMessage:
        'Replace the if-null-then-assign block with the ??= operator for a single-expression null-coalescing assignment.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((node) {
      // Check for: if (x == null) x = value;
      final condition = node.expression;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.EQ_EQ) return;

      // One side must be null literal
      Expression? nullCheckedExpr;
      if (condition.rightOperand is NullLiteral) {
        nullCheckedExpr = condition.leftOperand;
      } else if (condition.leftOperand is NullLiteral) {
        nullCheckedExpr = condition.rightOperand;
      }
      if (nullCheckedExpr == null) return;

      // Must have no else branch
      if (node.elseStatement != null) return;

      // Then branch must be an assignment to the same variable
      Statement thenStmt = node.thenStatement;
      if (thenStmt is Block && thenStmt.statements.length == 1) {
        thenStmt = thenStmt.statements.first;
      }

      if (thenStmt is! ExpressionStatement) return;
      final expr = thenStmt.expression;
      if (expr is! AssignmentExpression) return;
      if (expr.operator.type != TokenType.EQ) return;

      // Check if assigning to the same variable
      if (expr.leftHandSide.toString() == nullCheckedExpr.toString()) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when explicit if-null-then-assign is preferred over ??= (opposite).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of explicit null check:**
/// - More familiar for developers from other languages
/// - Easier to add breakpoints/logging
/// - More explicit control flow
///
/// **Cons (why some teams prefer ??=):**
/// - More verbose
/// - Less idiomatic Dart
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// name ??= 'default';
/// ```
///
/// #### GOOD:
/// ```dart
/// if (name == null) name = 'default';
/// ```
class PreferExplicitNullAssignmentRule extends SaropaLintRule {
  PreferExplicitNullAssignmentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_null_assignment',
    '[prefer_explicit_null_assignment] The ??= operator hides the null-check control flow, making it harder to debug and log. Use an explicit if-null-then-assign block for step-by-step clarity. {v3}',
    correctionMessage:
        'Replace ??= with an explicit if (variable == null) variable = value; block for step-by-step clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAssignmentExpression((node) {
      if (node.operator.type == TokenType.QUESTION_QUESTION_EQ) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when `x != null ? x : default` is used instead of `x ?? default`.
///
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of ?? operator:**
/// - More concise
/// - Idiomatic Dart
/// - Clearer intent
///
/// **Cons (why some teams prefer ternary):**
/// - Ternary is more explicit
/// - Familiar from other languages
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final result = value != null ? value : 'default';
/// final result = value == null ? 'default' : value;
/// ```
///
/// #### GOOD:
/// ```dart
/// final result = value ?? 'default';
/// ```
class PreferIfNullOverTernaryRule extends SaropaLintRule {
  PreferIfNullOverTernaryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferIfNullOverTernaryFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_if_null_over_ternary',
    '[prefer_if_null_over_ternary] Null-checking ternary detected where the ?? operator expresses the same intent more concisely. Replace with ?? to reduce verbosity and follow idiomatic Dart conventions. {v4}',
    correctionMessage:
        'Replace the ternary null check with the ?? operator, which expresses the same intent in fewer tokens.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConditionalExpression((node) {
      final condition = node.condition;
      if (condition is! BinaryExpression) return;

      final op = condition.operator.type;
      if (op != TokenType.EQ_EQ && op != TokenType.BANG_EQ) return;

      // Check for null comparison
      final Expression? checkedExpr;
      final bool isNullCheck;

      if (condition.rightOperand is NullLiteral) {
        checkedExpr = condition.leftOperand;
        isNullCheck = true;
      } else if (condition.leftOperand is NullLiteral) {
        checkedExpr = condition.rightOperand;
        isNullCheck = true;
      } else {
        isNullCheck = false;
        checkedExpr = null;
      }

      if (!isNullCheck || checkedExpr == null) return;

      // For x != null ? x : default OR x == null ? default : x
      // One branch should be the checked expression, the other the default
      final thenExpr = node.thenExpression.toString();
      final elseExpr = node.elseExpression.toString();
      final checkedStr = checkedExpr.toString();

      if (op == TokenType.BANG_EQ) {
        // x != null ? x : default
        if (thenExpr == checkedStr) {
          reporter.atNode(node);
        }
      } else {
        // x == null ? default : x
        if (elseExpr == checkedStr) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when ?? is used instead of explicit ternary (opposite rule).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v5
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of ternary:**
/// - More explicit about the condition
/// - Familiar from other languages
/// - Easier to add logic later
///
/// **Cons (why some teams prefer ??):**
/// - More verbose
/// - Less idiomatic Dart
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final result = value ?? 'default';
/// ```
///
/// #### GOOD:
/// ```dart
/// final result = value != null ? value : 'default';
/// ```
class PreferTernaryOverIfNullRule extends SaropaLintRule {
  PreferTernaryOverIfNullRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferTernaryOverIfNullFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_ternary_over_if_null',
    '[prefer_ternary_over_if_null] The ?? operator hides the null-check branching logic, reducing visibility into both code paths. Use an explicit ternary (value != null ? value : fallback) for full control over each branch. {v5}',
    correctionMessage:
        'Replace ?? with an explicit ternary (value != null ? value : fallback) for full control over both branches.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((node) {
      if (node.operator.type == TokenType.QUESTION_QUESTION) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when `late` could be used instead of nullable type for lazy init.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of late:**
/// - No null checks needed
/// - Clear intent - will be initialized before use
/// - Better type inference downstream
///
/// **Cons (why some teams prefer nullable):**
/// - late can cause runtime errors
/// - Nullable is safer
/// - No LateInitializationError risk
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// String? _name;
/// void init() { _name = computeName(); }
/// String get name => _name!;
/// ```
///
/// #### GOOD:
/// ```dart
/// late String _name;
/// void init() { _name = computeName(); }
/// String get name => _name;
/// ```
class PreferLateOverNullableRule extends SaropaLintRule {
  PreferLateOverNullableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_late_over_nullable',
    '[prefer_late_over_nullable] Use late instead of nullable for lazily initialized fields that are always set before first access. This is an opinionated rule - not included in any tier by default. {v2}',
    correctionMessage:
        'Declare the field as late to remove null checks — the runtime guarantees a LateInitializationError if read too early.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This rule is complex - it needs to detect patterns where a nullable
    // field is always assigned before being accessed with !
    // For now, we'll detect nullable fields that are only accessed with !
    context.addFieldDeclaration((node) {
      for (final variable in node.fields.variables) {
        final type = node.fields.type;
        if (type == null) continue;

        // Check if outer type is nullable via AST question token
        if (!isOuterTypeNullable(type)) continue;

        // Skip if already late
        if (node.fields.lateKeyword != null) continue;

        // Skip if has initializer
        if (variable.initializer != null) continue;

        // This is a heuristic - flag nullable uninitialized fields
        // A more sophisticated version would track usage patterns
        reporter.atNode(variable);
      }
    });
  }
}

/// Warns when late is used instead of nullable (opposite rule).
///
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of nullable:**
/// - Safer - no LateInitializationError
/// - Explicit about optional state
/// - Compile-time null safety
///
/// **Cons (why some teams prefer late):**
/// - Requires null checks
/// - ! operator usage
///
/// **Exemptions:**
/// - `late final` with inline initializer (lazy evaluation, zero crash risk)
/// - Fields in `State` subclasses (Flutter lifecycle guarantees `initState()`
///   runs before `build()`)
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// late String _name;
/// ```
///
/// #### GOOD:
/// ```dart
/// String? _name;
/// late final ScrollController _ctrl = ScrollController(); // OK: initializer
/// // In State subclass — OK: assigned in initState()
/// late Future<List<Item>?> _items;
/// ```
class PreferNullableOverLateRule extends SaropaLintRule {
  PreferNullableOverLateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_nullable_over_late',
    '[prefer_nullable_over_late] Field uses late initialization, which risks a LateInitializationError at runtime if read before assignment. Use a nullable type instead so the compiler enforces null checks at every access point. {v4}',
    correctionMessage:
        'Use a nullable type instead of late so the compiler enforces a null check at every access, preventing runtime errors.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.fields.lateKeyword == null) return;

      // Exempt: late final with inline initializer — lazy evaluation,
      // not deferred assignment. No LateInitializationError risk.
      if (node.fields.isFinal &&
          node.fields.variables.every(
            (VariableDeclaration v) => v.initializer != null,
          )) {
        return;
      }

      // Exempt: fields in State subclasses — Flutter lifecycle guarantees
      // initState() runs before build(), making late assignment safe.
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is ClassDeclaration) {
        final ExtendsClause? extendsClause = current.extendsClause;
        if (extendsClause != null) {
          final String superclass = extendsClause.superclass.name.lexeme;
          if (superclass == 'State') return;
        }
      }

      for (final VariableDeclaration variable in node.fields.variables) {
        reporter.atNode(variable);
      }
    });
  }
}

// =============================================================================
// COLLECTION RULES
// =============================================================================

/// Warns when .addAll() is used instead of spread operator.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of spread:**
/// - More declarative
/// - Works in const contexts
/// - Idiomatic Dart 2.3+
///
/// **Cons (why some teams prefer addAll):**
/// - Familiar imperative style
/// - Clearer for complex mutations
/// - Works with any Iterable method
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final list = [1, 2];
/// list.addAll([3, 4]);
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [1, 2, ...otherList];
/// // Or for in-place: list = [...list, ...otherList];
/// ```
class PreferSpreadOverAddAllRule extends SaropaLintRule {
  PreferSpreadOverAddAllRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  // cspell:ignore addall
  static const LintCode _code = LintCode(
    'prefer_spread_over_addall',
    '[prefer_spread_over_addall] Collection uses addAll() instead of the spread operator. The spread syntax [...list1, ...list2] is a declarative, expression-level merge that avoids mutation. {v2}',
    correctionMessage:
        'Replace addAll() with the spread operator [...list1, ...list2] for a declarative, expression-level merge.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      if (node.methodName.name == 'addAll') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when spread is used instead of addAll() (opposite rule).
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of addAll:**
/// - Familiar imperative style
/// - Clearer for mutations
/// - No new list allocation
///
/// **Cons (why some teams prefer spread):**
/// - Less declarative
/// - Doesn't work in const
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// final combined = [...list1, ...list2];
/// ```
///
/// #### GOOD:
/// ```dart
/// final combined = list1.toList()..addAll(list2);
/// ```
class PreferAddAllOverSpreadRule extends SaropaLintRule {
  PreferAddAllOverSpreadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_addall_over_spread',
    '[prefer_addall_over_spread] The spread operator creates a new list allocation on every use, which can be wasteful for in-place mutations. Use addAll() for an explicit imperative merge that avoids unnecessary copies. {v2}',
    correctionMessage:
        'Replace the spread operator with addAll() for an explicit imperative mutation that reads naturally in method chains.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSpreadElement((node) {
      reporter.atNode(node);
    });
  }
}

/// Warns when `cond ? [item] : []` is used instead of `[if (cond) item]`.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of collection-if:**
/// - More concise
/// - Idiomatic Dart 2.3+
/// - Nestable with other collection operators
///
/// **Cons (why some teams prefer ternary):**
/// - Ternary is more familiar
/// - Works in more contexts
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// [
///   widget1,
///   ...(showExtra ? [extraWidget] : []),
///   widget2,
/// ]
/// ```
///
/// #### GOOD:
/// ```dart
/// [
///   widget1,
///   if (showExtra) extraWidget,
///   widget2,
/// ]
/// ```
class PreferCollectionIfOverTernaryRule extends SaropaLintRule {
  PreferCollectionIfOverTernaryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_collection_if_over_ternary',
    '[prefer_collection_if_over_ternary] Ternary operator with spread is used to conditionally include collection elements. This pattern is harder to read; use collection-if syntax instead for clearer, more idiomatic Dart. {v2}',
    correctionMessage:
        'Replace the ternary-spread pattern with a collection-if expression: [if (condition) element] for cleaner syntax.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSpreadElement((node) {
      final expr = node.expression;
      if (expr is! ParenthesizedExpression) return;

      final inner = expr.expression;
      if (inner is! ConditionalExpression) return;

      // Check if one branch is an empty list
      final thenExpr = inner.thenExpression;
      final elseExpr = inner.elseExpression;

      final isEmptyListThen =
          thenExpr is ListLiteral && thenExpr.elements.isEmpty;
      final isEmptyListElse =
          elseExpr is ListLiteral && elseExpr.elements.isEmpty;

      if (isEmptyListThen || isEmptyListElse) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when ternary is preferred over collection-if (opposite rule).
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of ternary:**
/// - More familiar pattern
/// - Consistent with other ternary usage
/// - Works in all contexts
///
/// **Cons (why some teams prefer collection-if):**
/// - More verbose
/// - Less idiomatic
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// [
///   if (showExtra) extraWidget,
/// ]
/// ```
///
/// #### GOOD:
/// ```dart
/// [
///   ...(showExtra ? [extraWidget] : []),
/// ]
/// ```
class PreferTernaryOverCollectionIfRule extends SaropaLintRule {
  PreferTernaryOverCollectionIfRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_ternary_over_collection_if',
    '[prefer_ternary_over_collection_if] Collection-if expression could be replaced with a ternary-spread pattern for explicit control over the empty-case branch and consistent syntax. {v2}',
    correctionMessage:
        'Replace the collection-if with a ternary-spread expression: ...(condition ? [element] : []) for explicit control.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfElement((node) {
      reporter.atNode(node);
    });
  }
}

/// Warns when `.where((e) => e is T)` is used instead of `.whereType<T>()`.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of whereType:**
/// - More concise
/// - Type-safe - returns `Iterable<T>`
/// - No manual cast needed
///
/// **Cons (why some teams prefer where + is):**
/// - More explicit about the operation
/// - Familiar pattern
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// list.where((e) => e is String).cast<String>()
/// list.where((e) => e is String).map((e) => e as String)
/// ```
///
/// #### GOOD:
/// ```dart
/// list.whereType<String>()
/// ```
class PreferWhereTypeOverWhereIsRule extends SaropaLintRule {
  PreferWhereTypeOverWhereIsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  // cspell:ignore wheretype
  static const LintCode _code = LintCode(
    'prefer_wheretype_over_where_is',
    '[prefer_wheretype_over_where_is] Collection uses where((e) => e is T) for type filtering, which requires a manual cast afterward. Use whereType<T>() instead to filter and cast in one step for cleaner, type-safe code. {v2}',
    correctionMessage:
        'Replace where((e) => e is T) with whereType<T>() for concise, type-safe filtering without a manual cast.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      if (node.methodName.name != 'where') return;

      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      if (arg is! FunctionExpression) return;

      final body = arg.body;
      if (body is! ExpressionFunctionBody) return;

      final expr = body.expression;
      if (expr is! IsExpression) return;

      // Skip negated type checks — no whereType equivalent for exclusion
      if (expr.notOperator != null) return;

      // It's a where((e) => e is T) pattern
      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferWhereTypeFix(context: context),
  ];
}

/// Warns when iterating map with .keys and lookup vs .entries.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of .entries:**
/// - Single iteration - more efficient
/// - Clearer intent
/// - No repeated lookups
///
/// **Cons (why some teams prefer .keys):**
/// - Simpler when value isn't always needed
/// - Familiar pattern
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// for (final key in map.keys) {
///   final value = map[key];
///   print('$key: $value');
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// for (final entry in map.entries) {
///   print('${entry.key}: ${entry.value}');
/// }
/// ```
class PreferMapEntriesIterationRule extends SaropaLintRule {
  PreferMapEntriesIterationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_map_entries_iteration',
    '[prefer_map_entries_iteration] Iterating a map via .keys and then performing a separate map[key] lookup on each iteration duplicates work. Use map.entries to access both key and value in a single pass. {v2}',
    correctionMessage:
        'Iterate with map.entries to access key and value in a single lookup instead of re-indexing via map[key].',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((node) {
      final loopParts = node.forLoopParts;
      if (loopParts is! ForEachParts) return;

      final iterable = loopParts.iterable;
      if (iterable is! PropertyAccess) return;
      if (iterable.propertyName.name != 'keys') return;

      // Get the map name being iterated
      final mapTarget = iterable.target;
      if (mapTarget == null) return;
      final mapName = mapTarget.toString();

      // Check if the loop body accesses map[key]
      final body = node.body;
      bool hasMapLookup = false;

      void checkNode(AstNode astNode) {
        if (astNode is IndexExpression) {
          final target = astNode.target;
          if (target != null && target.toString() == mapName) {
            hasMapLookup = true;
          }
        }
        for (final child in astNode.childEntities) {
          if (child is AstNode) {
            checkNode(child);
          }
        }
      }

      checkNode(body);

      if (hasMapLookup) {
        reporter.atNode(iterable);
      }
    });
  }
}

/// Warns when .keys iteration is preferred over .entries (opposite rule).
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of .keys:**
/// - Simpler when value isn't always needed
/// - Familiar pattern
/// - Clearer when only processing keys
///
/// **Cons (why some teams prefer .entries):**
/// - Less efficient with lookups
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// for (final entry in map.entries) { ... }
/// ```
///
/// #### GOOD:
/// ```dart
/// for (final key in map.keys) { ... }
/// ```
class PreferKeysIterationRule extends SaropaLintRule {
  PreferKeysIterationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_keys_with_lookup',
    '[prefer_keys_with_lookup] Map iteration uses .entries instead of .keys with explicit lookup. Iterating with .keys and map[key] is a familiar loop pattern that matches common imperative styles. {v2}',
    correctionMessage:
        'Iterate with map.keys and look up each value explicitly for a familiar loop style that matches common patterns.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((node) {
      final loopParts = node.forLoopParts;
      if (loopParts is! ForEachParts) return;

      final iterable = loopParts.iterable;
      if (iterable is! PropertyAccess) return;
      if (iterable.propertyName.name == 'entries') {
        reporter.atNode(iterable);
      }
    });
  }
}

/// Warns when UnmodifiableListView is preferred over mutable (opposite rule).
///
/// Since: v4.8.3 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of mutable collections:**
/// - More flexible for consumers
/// - Less boilerplate
/// - Trust the caller
///
/// **Cons (why some teams prefer unmodifiable):**
/// - Risk of accidental mutation
/// - Less clear API contract
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// List<String> get items => UnmodifiableListView(_items);
/// ```
///
/// #### GOOD:
/// ```dart
/// List<String> get items => _items;
/// ```
class PreferMutableCollectionsRule extends SaropaLintRule {
  PreferMutableCollectionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_mutable_collections',
    '[prefer_mutable_collections] Function returns an unmodifiable collection. Immutable return types force callers to copy the collection before modification, adding allocation overhead and boilerplate. {v3}',
    correctionMessage:
        'Return a plain List, Set, or Map so callers can modify the collection without needing to copy or unwrap it first.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final name = node.constructorName.type.element?.name;
      if (name == 'UnmodifiableListView' ||
          name == 'UnmodifiableSetView' ||
          name == 'UnmodifiableMapView') {
        reporter.atNode(node);
      }
    });

    context.addMethodInvocation((node) {
      if (node.methodName.name == 'unmodifiable') {
        final target = node.target;
        if (target is SimpleIdentifier) {
          final name = target.name;
          if (name == 'List' || name == 'Set' || name == 'Map') {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}
