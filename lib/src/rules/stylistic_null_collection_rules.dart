// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
  const PreferNullAwareAssignmentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_null_aware_assignment',
    problemMessage: '[prefer_null_aware_assignment] Use ??= instead of if-null-then-assign pattern.',
    correctionMessage: 'Replace with: variable ??= value',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when explicit if-null-then-assign is preferred over ??= (opposite).
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
  const PreferExplicitNullAssignmentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_null_assignment',
    problemMessage: '[prefer_explicit_null_assignment] Use explicit if-null-then-assign instead of ??=.',
    correctionMessage: 'Replace with: if (variable == null) variable = value;',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((node) {
      if (node.operator.type == TokenType.QUESTION_QUESTION_EQ) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `x != null ? x : default` is used instead of `x ?? default`.
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
  const PreferIfNullOverTernaryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_if_null_over_ternary',
    problemMessage: '[prefer_if_null_over_ternary] Use ?? instead of null-checking ternary expression.',
    correctionMessage: 'Replace with: value ?? default',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConditionalExpression((node) {
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
          reporter.atNode(node, code);
        }
      } else {
        // x == null ? default : x
        if (elseExpr == checkedStr) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when ?? is used instead of explicit ternary (opposite rule).
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
  const PreferTernaryOverIfNullRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_ternary_over_if_null',
    problemMessage:
        '[prefer_ternary_over_if_null] Use ternary expression instead of ?? for explicit control.',
    correctionMessage: 'Replace with: value != null ? value : default',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((node) {
      if (node.operator.type == TokenType.QUESTION_QUESTION) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `late` could be used instead of nullable type for lazy init.
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
  const PreferLateOverNullableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_late_over_nullable',
    problemMessage:
        '[prefer_late_over_nullable] Consider using late instead of nullable for lazily initialized fields.',
    correctionMessage:
        'late avoids null checks if you guarantee initialization before use.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This rule is complex - it needs to detect patterns where a nullable
    // field is always assigned before being accessed with !
    // For now, we'll detect nullable fields that are only accessed with !
    context.registry.addFieldDeclaration((node) {
      for (final variable in node.fields.variables) {
        final type = node.fields.type;
        if (type == null) continue;

        // Check if type is nullable (ends with ?)
        final typeStr = type.toString();
        if (!typeStr.endsWith('?')) continue;

        // Skip if already late
        if (node.fields.lateKeyword != null) continue;

        // Skip if has initializer
        if (variable.initializer != null) continue;

        // This is a heuristic - flag nullable uninitialized fields
        // A more sophisticated version would track usage patterns
        reporter.atNode(variable, code);
      }
    });
  }
}

/// Warns when late is used instead of nullable (opposite rule).
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
/// ```
class PreferNullableOverLateRule extends SaropaLintRule {
  const PreferNullableOverLateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_nullable_over_late',
    problemMessage: '[prefer_nullable_over_late] Use nullable type instead of late for safer code.',
    correctionMessage: 'Nullable types prevent LateInitializationError.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((node) {
      if (node.fields.lateKeyword != null) {
        for (final variable in node.fields.variables) {
          reporter.atNode(variable, code);
        }
      }
    });
  }
}

// =============================================================================
// COLLECTION RULES
// =============================================================================

/// Warns when .addAll() is used instead of spread operator.
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
  const PreferSpreadOverAddAllRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  // cspell:ignore addall
  static const LintCode _code = LintCode(
    name: 'prefer_spread_over_addall',
    problemMessage: '[prefer_spread_over_addall] Use spread operator [...] instead of addAll().',
    correctionMessage: 'Spread is more declarative: [...list1, ...list2]',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name == 'addAll') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when spread is used instead of addAll() (opposite rule).
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
  const PreferAddAllOverSpreadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_addall_over_spread',
    problemMessage: '[prefer_addall_over_spread] Use addAll() instead of spread for consistency.',
    correctionMessage: 'addAll() is more explicit for mutations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSpreadElement((node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when `cond ? [item] : []` is used instead of `[if (cond) item]`.
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
  const PreferCollectionIfOverTernaryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_collection_if_over_ternary',
    problemMessage: '[prefer_collection_if_over_ternary] Use collection-if instead of ternary with spread.',
    correctionMessage: 'Replace with: [if (condition) element]',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSpreadElement((node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when ternary is preferred over collection-if (opposite rule).
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
  const PreferTernaryOverCollectionIfRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_ternary_over_collection_if',
    problemMessage: '[prefer_ternary_over_collection_if] Use ternary spread instead of collection-if.',
    correctionMessage: 'Replace with: ...(condition ? [element] : [])',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfElement((node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when `.where((e) => e is T)` is used instead of `.whereType<T>()`.
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
  const PreferWhereTypeOverWhereIsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  // cspell:ignore wheretype
  static const LintCode _code = LintCode(
    name: 'prefer_wheretype_over_where_is',
    problemMessage: '[prefer_wheretype_over_where_is] Use whereType<T>() instead of where((e) => e is T).',
    correctionMessage: 'whereType<T>() is more concise and type-safe.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'where') return;

      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      if (arg is! FunctionExpression) return;

      final body = arg.body;
      if (body is! ExpressionFunctionBody) return;

      final expr = body.expression;
      if (expr is! IsExpression) return;

      // It's a where((e) => e is T) pattern
      reporter.atNode(node, code);
    });
  }
}

/// Warns when iterating map with .keys and lookup vs .entries.
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
  const PreferMapEntriesIterationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_map_entries_iteration',
    problemMessage: '[prefer_map_entries_iteration] Use map.entries instead of iterating .keys with lookup.',
    correctionMessage: 'for (final entry in map.entries) is more efficient.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((node) {
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
        reporter.atNode(iterable, code);
      }
    });
  }
}

/// Warns when .keys iteration is preferred over .entries (opposite rule).
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
  const PreferKeysIterationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_keys_with_lookup',
    problemMessage: '[prefer_keys_with_lookup] Use map.keys with lookup for consistency.',
    correctionMessage: 'for (final key in map.keys) is more familiar.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((node) {
      final loopParts = node.forLoopParts;
      if (loopParts is! ForEachParts) return;

      final iterable = loopParts.iterable;
      if (iterable is! PropertyAccess) return;
      if (iterable.propertyName.name == 'entries') {
        reporter.atNode(iterable, code);
      }
    });
  }
}

/// Warns when mutable collections are returned from getters.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of UnmodifiableListView:**
/// - Prevents accidental mutation
/// - Clear API contract
/// - Defensive programming
///
/// **Cons (why some teams prefer mutable):**
/// - More flexible for consumers
/// - Less boilerplate
/// - Trust the caller
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// List<String> get items => _items;
/// ```
///
/// #### GOOD:
/// ```dart
/// List<String> get items => UnmodifiableListView(_items);
/// // Or: List<String> get items => List.unmodifiable(_items);
/// ```
class PreferUnmodifiableCollectionsRule extends SaropaLintRule {
  const PreferUnmodifiableCollectionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_unmodifiable_collections',
    problemMessage:
        '[prefer_unmodifiable_collections] Return UnmodifiableListView from getters to prevent mutation.',
    correctionMessage:
        'Wrap with UnmodifiableListView() or List.unmodifiable().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      // Only check getters
      if (!node.isGetter) return;

      final returnType = node.returnType?.toString();
      if (returnType == null) return;

      // Check if return type is a mutable collection
      if (!returnType.startsWith('List<') &&
          !returnType.startsWith('Set<') &&
          !returnType.startsWith('Map<')) {
        return;
      }

      // Check the body
      final body = node.body;
      if (body is! ExpressionFunctionBody) return;

      final expr = body.expression;

      // Allow if already returning unmodifiable
      final exprStr = expr.toString();
      if (exprStr.contains('UnmodifiableListView') ||
          exprStr.contains('UnmodifiableSetView') ||
          exprStr.contains('UnmodifiableMapView') ||
          exprStr.contains('.unmodifiable')) {
        return;
      }

      // Flag if returning a field directly
      if (expr is SimpleIdentifier || expr is PrefixedIdentifier) {
        reporter.atNode(expr, code);
      }
    });
  }
}

/// Warns when UnmodifiableListView is preferred over mutable (opposite rule).
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
  const PreferMutableCollectionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_mutable_collections',
    problemMessage: '[prefer_mutable_collections] Return mutable collections for flexibility.',
    correctionMessage: 'Avoid UnmodifiableListView wrapper.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final name = node.constructorName.type.element?.name;
      if (name == 'UnmodifiableListView' ||
          name == 'UnmodifiableSetView' ||
          name == 'UnmodifiableMapView') {
        reporter.atNode(node, code);
      }
    });

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name == 'unmodifiable') {
        final target = node.target;
        if (target is SimpleIdentifier) {
          final name = target.name;
          if (name == 'List' || name == 'Set' || name == 'Map') {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}
