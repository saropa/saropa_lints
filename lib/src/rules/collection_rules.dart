// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../fixes/collection/replace_with_where_or_null_fix.dart';
import '../fixes/collection/use_contains_key_fix.dart';
import '../fixes/collection/use_last_fix.dart';
import '../fixes/collection/use_where_or_null_fix.dart';
import '../saropa_lint_rule.dart';
import '../fixes/collection/use_contains_fix.dart';
import '../fixes/collection/use_first_fix.dart';

/// Warns when comparing collections using == operator.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: no_collection_equality, use_deep_equals
///
/// Collections (List, Set, Map) use reference equality by default,
/// not value equality. Use listEquals, setEquals, or mapEquals instead.
///
/// Example of **bad** code:
/// ```dart
/// if (list1 == list2) {}  // Reference equality, not content
/// ```
///
/// Example of **good** code:
/// ```dart
/// import 'package:collection/collection.dart';
/// if (listEquals(list1, list2)) {}
/// // or
/// if (const DeepCollectionEquality().equals(list1, list2)) {}
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidCollectionEqualityChecksRule extends SaropaLintRule {
  AvoidCollectionEqualityChecksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_collection_equality_checks',
    '[avoid_collection_equality_checks] Comparing collections with == uses reference equality. This can cause false positives/negatives, leading to logic errors and unexpected app behavior. Collections (List, Set, Map) use reference equality by default, not value equality. Use listEquals, setEquals, or mapEquals instead. {v5}',
    correctionMessage:
        'Use listEquals, setEquals, mapEquals, or DeepCollectionEquality. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _collectionTypes = <String>{
    'List',
    'Set',
    'Map',
    'Iterable',
    'Queue',
    'LinkedList',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      if (node.operator.type != TokenType.EQ_EQ &&
          node.operator.type != TokenType.BANG_EQ) {
        return;
      }

      final DartType? leftType = node.leftOperand.staticType;
      final DartType? rightType = node.rightOperand.staticType;

      // Allow null checks - comparing collection to null is valid
      if (leftType == null || rightType == null) {
        return;
      }

      // Only report if both sides are collections (actual collection comparison)
      if (_isCollectionType(leftType) && _isCollectionType(rightType)) {
        reporter.atNode(node);
      }
    });
  }

  bool _isCollectionType(DartType? type) {
    if (type == null) return false;
    final String typeName = type.getDisplayString();
    return _collectionTypes.any(
      (String collection) => typeName.startsWith(collection),
    );
  }
}

/// Warns when duplicate keys are used in a map literal.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: no_duplicate_keys, map_duplicate_key
///
/// Example of **bad** code:
/// ```dart
/// final map = {'a': 1, 'b': 2, 'a': 3};
/// ```
///
/// Example of **good** code:
/// ```dart
/// final map = {'a': 1, 'b': 2, 'c': 3};
/// ```
class AvoidDuplicateMapKeysRule extends SaropaLintRule {
  AvoidDuplicateMapKeysRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_duplicate_map_keys',
    '[avoid_duplicate_map_keys] Duplicate key in map literal silently overwrites the earlier value, causing data loss and unpredictable behavior. Only the last value assigned to the key will persist in the resulting map. {v4}',
    correctionMessage:
        'Remove the duplicate key entry or rename it to a unique key to preserve all intended values.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!node.isMap) return;

      final Set<String> seenKeys = <String>{};
      for (final CollectionElement element in node.elements) {
        if (element is MapLiteralEntry) {
          final String keySource = element.key.toSource();
          if (seenKeys.contains(keySource)) {
            reporter.atNode(element.key, code);
          } else {
            seenKeys.add(keySource);
          }
        }
      }
    });
  }
}

/// Warns when .keys.contains() is used instead of .containsKey().
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: use_contains_key, no_keys_contains
///
/// Example of **bad** code:
/// ```dart
/// if (map.keys.contains(key)) { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (map.containsKey(key)) { ... }
/// ```
///
/// **Quick fix available:** Replaces with `map.containsKey(key)`.
class AvoidMapKeysContainsRule extends SaropaLintRule {
  AvoidMapKeysContainsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_map_keys_contains',
    '[avoid_map_keys_contains] Calling .keys.contains() allocates an iterable of all keys and performs a linear search, while .containsKey() uses the map hash table for O(1) lookup. This wastes memory and CPU cycles on every call. {v5}',
    correctionMessage:
        'Replace map.keys.contains(key) with map.containsKey(key) to use the efficient hash-based lookup.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'contains') return;

      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      if (target.propertyName.name == 'keys') {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseContainsKeyFix(context: context),
  ];
}

/// Warns when unnecessary collection wrappers are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: prefer_collection_literals, no_list_of_literal
///
/// Using collection literals is preferred over constructors.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final list = List.of([1, 2, 3]);
/// final set = Set.of({1, 2, 3});
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [1, 2, 3];
/// final set = {1, 2, 3};
/// ```
class AvoidUnnecessaryCollectionsRule extends SaropaLintRule {
  AvoidUnnecessaryCollectionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_collections',
    '[avoid_unnecessary_collections] Wrapping an existing collection literal with List.of() or Set.of() creates a redundant copy, wasting memory and adding unnecessary overhead. The literal itself already produces the correct collection type. {v4}',
    correctionMessage:
        'Remove the List.of() or Set.of() wrapper and use the collection literal directly to eliminate the extra allocation.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _unnecessaryMethods = <String>{'of', 'from'};

  static const Set<String> _collectionTypes = <String>{'List', 'Set', 'Map'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      final String typeName = target.name;
      final String methodName = node.methodName.name;

      if (_collectionTypes.contains(typeName) &&
          _unnecessaryMethods.contains(methodName)) {
        final ArgumentList args = node.argumentList;
        if (args.arguments.length == 1) {
          final Expression arg = args.arguments.first;
          // Check if argument is already a literal
          if (arg is ListLiteral || arg is SetOrMapLiteral) {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when using .first or .last on potentially empty collections.
///
/// Since: v0.1.8 | Updated: v4.13.0 | Rule version: v9
///
/// Alias: no_unsafe_first_last, prefer_first_or_null
///
/// Calling .first or .last on an empty collection throws a StateError.
/// Use .firstOrNull/.lastOrNull or check isEmpty first.
///
/// Example of **bad** code:
/// ```dart
/// final item = items.first;  // Throws if empty
/// ```
///
/// Example of **good** code:
/// ```dart
/// final item = items.firstOrNull;
/// // or
/// if (items.isNotEmpty) {
///   final item = items.first;
/// }
/// // or
/// final item = items.length > 1 ? items.last : fallback;
/// ```
class AvoidUnsafeCollectionMethodsRule extends SaropaLintRule {
  AvoidUnsafeCollectionMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unsafe_collection_methods',
    '[avoid_unsafe_collection_methods] Calling .first, .last, or .single on an empty collection throws a StateError at runtime, crashing the app. This is especially dangerous when the collection comes from an API response, database query, or user input where emptiness cannot be guaranteed at compile time. {v9}',
    correctionMessage:
        'Use .firstOrNull, .lastOrNull, or .singleOrNull from package:collection, or guard with an isEmpty check before accessing.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _unsafeMethods = <String>{'first', 'last', 'single'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;
      if (!_unsafeMethods.contains(propertyName)) return;

      // Check if target is an Iterable type
      final DartType? targetType = node.realTarget.staticType;
      if (targetType == null) return;

      // Check if it's an Iterable (List, Set, etc.)
      final String typeName = targetType.getDisplayString();
      if (typeName.startsWith('List') ||
          typeName.startsWith('Set') ||
          typeName.startsWith('Iterable') ||
          typeName.startsWith('Queue')) {
        // Check if this is a guaranteed non-empty collection
        if (_isGuaranteedNonEmpty(node.realTarget)) {
          return;
        }

        // Get the collection name for guard checking
        final String? collectionName = _getCollectionName(node.realTarget);

        // Check if guarded by isNotEmpty/length check
        if (collectionName != null && _isGuardedAccess(node, collectionName)) {
          return;
        }

        reporter.atNode(node);
      }
    });

    // Also check for prefixed identifier access like list.first
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      final String propertyName = node.identifier.name;
      if (!_unsafeMethods.contains(propertyName)) return;

      final DartType? targetType = node.prefix.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      if (typeName.startsWith('List') ||
          typeName.startsWith('Set') ||
          typeName.startsWith('Iterable') ||
          typeName.startsWith('Queue')) {
        // Check if this is a guaranteed non-empty collection (e.g., EnumType.values)
        if (_isGuaranteedNonEmptyPrefixed(node)) {
          return;
        }

        final String collectionName = node.prefix.name;

        // Check if guarded by isNotEmpty/length check
        if (_isGuardedAccess(node, collectionName)) {
          return;
        }

        reporter.atNode(node);
      }
    });
  }

  /// Checks if an expression is guaranteed to be non-empty.
  /// This includes:
  /// - String.split() results (always returns at least one element)
  /// - EnumType.values (enums must have at least one value)
  bool _isGuaranteedNonEmpty(Expression expr) {
    // Check for .split() result - String.split() always returns at least one element
    if (expr is MethodInvocation && expr.methodName.name == 'split') {
      return true;
    }

    // Check for enum .values property access (e.g., MyEnum.values)
    if (expr is PrefixedIdentifier && expr.identifier.name == 'values') {
      // Check the static type of the entire expression (e.g., List<TestEnum>)
      // If it's a List of an enum type, it's guaranteed non-empty
      final DartType? exprType = expr.staticType;
      if (exprType is InterfaceType && exprType.typeArguments.isNotEmpty) {
        final String typeName = exprType.getDisplayString();
        if (typeName.startsWith('List<')) {
          final DartType elementType = exprType.typeArguments.first;
          final Element? element = elementType.element;
          if (element is EnumElement) {
            return true;
          }
        }
      }

      final DartType? prefixType = expr.prefix.staticType;
      if (prefixType != null) {
        // Check if accessing .values on an enum type
        final Element? element = prefixType.element;
        if (element is EnumElement) {
          return true;
        }
        // Type<EnumName> indicates it's accessing static members of an enum
        final String typeStr = prefixType.getDisplayString();
        if (typeStr.startsWith('Type<')) {
          return true;
        }
      }
    }

    // Check for PropertyAccess to .values on enum
    if (expr is PropertyAccess && expr.propertyName.name == 'values') {
      final Expression? target = expr.target;
      if (target != null) {
        final DartType? targetType = target.staticType;
        if (targetType != null) {
          final Element? element = targetType.element;
          if (element is EnumElement) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Checks if a PrefixedIdentifier represents a guaranteed non-empty collection.
  /// e.g., EnumType.values.first where the prefix is the "values" property
  bool _isGuaranteedNonEmptyPrefixed(PrefixedIdentifier node) {
    // Check the static type of the prefix to see if it's an enum values list
    final DartType? prefixType = node.prefix.staticType;
    if (prefixType != null) {
      final String typeStr = prefixType.getDisplayString();
      // List<MyEnum> where MyEnum is an enum - this is what .values returns
      if (typeStr.startsWith('List<')) {
        // Check the element type to see if it's an enum
        if (prefixType is InterfaceType &&
            prefixType.typeArguments.isNotEmpty) {
          final DartType elementType = prefixType.typeArguments.first;
          final Element? element = elementType.element;
          if (element is EnumElement) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Extracts the collection variable name from an expression.
  String? _getCollectionName(Expression expr) {
    if (expr is SimpleIdentifier) {
      return expr.name;
    }
    if (expr is PrefixedIdentifier) {
      return expr.toSource();
    }
    if (expr is PropertyAccess) {
      return expr.toSource();
    }
    return null;
  }

  /// Checks if the access is guarded by an isNotEmpty or length check.
  bool _isGuardedAccess(AstNode node, String collectionName) {
    // Check for ternary expression guard: list.length > 0 ? list.first : ...
    if (_isGuardedByTernary(node, collectionName)) {
      return true;
    }

    // Check for if statement guard: if (list.isNotEmpty) { ... list.first ... }
    if (_isGuardedByIfStatement(node, collectionName)) {
      return true;
    }

    // Check for collection-if guard: [if (list.isNotEmpty) list.first]
    if (_isGuardedByCollectionIf(node, collectionName)) {
      return true;
    }

    return false;
  }

  /// Checks if inside a ternary with a length/isEmpty guard.
  bool _isGuardedByTernary(AstNode node, String collectionName) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ConditionalExpression) {
        // Check if this node is in the "then" expression (not the "else")
        if (_isDescendantOf(node, current.thenExpression)) {
          if (_isValidGuardCondition(current.condition, collectionName)) {
            return true;
          }
        }
        // For .last in else branch with inverted condition
        if (_isDescendantOf(node, current.elseExpression)) {
          if (_isInvertedGuardCondition(current.condition, collectionName)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if inside an if block with isNotEmpty/length guard.
  bool _isGuardedByIfStatement(AstNode node, String collectionName) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        // Check if we're in the "then" branch
        if (_isDescendantOf(node, current.thenStatement)) {
          if (_isValidGuardCondition(current.expression, collectionName)) {
            return true;
          }
        }
        // Check if we're in the "else" branch with inverted condition
        final Statement? elseStatement = current.elseStatement;
        if (elseStatement != null && _isDescendantOf(node, elseStatement)) {
          if (_isInvertedGuardCondition(current.expression, collectionName)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if inside a collection-if element with isNotEmpty/length guard.
  /// e.g., [if (list.isNotEmpty) list.first] or {if (set.length > 0) set.first}
  bool _isGuardedByCollectionIf(AstNode node, String collectionName) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfElement) {
        // Check if we're in the "then" element
        if (_isDescendantOf(node, current.thenElement)) {
          if (_isValidGuardCondition(current.expression, collectionName)) {
            return true;
          }
        }
        // Check if we're in the "else" element with inverted condition
        final CollectionElement? elseElement = current.elseElement;
        if (elseElement != null && _isDescendantOf(node, elseElement)) {
          if (_isInvertedGuardCondition(current.expression, collectionName)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a condition is a valid guard for the collection.
  /// Valid guards: list.isNotEmpty, !list.isEmpty, list.length > 0, etc.
  bool _isValidGuardCondition(Expression condition, String collectionName) {
    // Handle: list.isNotEmpty
    if (condition is PrefixedIdentifier) {
      if (condition.prefix.name == collectionName &&
          condition.identifier.name == 'isNotEmpty') {
        return true;
      }
    }

    // Handle: list.isNotEmpty (as PropertyAccess)
    if (condition is PropertyAccess) {
      final String targetSource = condition.target?.toSource() ?? '';
      if (targetSource == collectionName &&
          condition.propertyName.name == 'isNotEmpty') {
        return true;
      }
    }

    // Handle: !list.isEmpty
    if (condition is PrefixExpression &&
        condition.operator.type == TokenType.BANG) {
      final Expression operand = condition.operand;
      if (operand is PrefixedIdentifier) {
        if (operand.prefix.name == collectionName &&
            operand.identifier.name == 'isEmpty') {
          return true;
        }
      }
      if (operand is PropertyAccess) {
        final String targetSource = operand.target?.toSource() ?? '';
        if (targetSource == collectionName &&
            operand.propertyName.name == 'isEmpty') {
          return true;
        }
      }
    }

    // Handle: list.length > 0, list.length >= 1, list.length != 0
    if (condition is BinaryExpression) {
      if (_isLengthComparisonGuard(condition, collectionName)) {
        return true;
      }
      // Handle: list.isNotEmpty && otherCondition
      if (condition.operator.type == TokenType.AMPERSAND_AMPERSAND) {
        if (_isValidGuardCondition(condition.leftOperand, collectionName) ||
            _isValidGuardCondition(condition.rightOperand, collectionName)) {
          return true;
        }
      }
    }

    // Handle extension methods like .isNotListNullOrEmpty
    if (condition is PrefixedIdentifier) {
      final String propName = condition.identifier.name;
      if (condition.prefix.name == collectionName &&
          (propName.contains('NotEmpty') || propName.contains('NotNull'))) {
        return true;
      }
    }

    return false;
  }

  /// Checks for inverted guard (isEmpty check in condition, access in else).
  bool _isInvertedGuardCondition(Expression condition, String collectionName) {
    // Handle: list.isEmpty -> access in else is safe
    if (condition is PrefixedIdentifier) {
      if (condition.prefix.name == collectionName &&
          condition.identifier.name == 'isEmpty') {
        return true;
      }
    }

    if (condition is PropertyAccess) {
      final String targetSource = condition.target?.toSource() ?? '';
      if (targetSource == collectionName &&
          condition.propertyName.name == 'isEmpty') {
        return true;
      }
    }

    // Handle: list.length == 0 -> access in else is safe
    if (condition is BinaryExpression) {
      if (_isLengthZeroCheck(condition, collectionName)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if condition is a length comparison that ensures non-empty.
  /// e.g., list.length > 0, list.length >= 1, list.length != 0, list.length == 1
  bool _isLengthComparisonGuard(BinaryExpression expr, String collectionName) {
    final Expression left = expr.leftOperand;
    final Expression right = expr.rightOperand;
    final TokenType op = expr.operator.type;

    // Check for: list.length > N or list.length >= N
    String? lengthTarget;
    if (left is PrefixedIdentifier && left.identifier.name == 'length') {
      lengthTarget = left.prefix.name;
    } else if (left is PropertyAccess && left.propertyName.name == 'length') {
      lengthTarget = left.target?.toSource();
    }

    if (lengthTarget == collectionName && right is IntegerLiteral) {
      final int? value = right.value;
      if (value != null) {
        // list.length > 0, list.length > 1, etc.
        if (op == TokenType.GT && value >= 0) return true;
        // list.length >= 1, list.length >= 2, etc.
        if (op == TokenType.GT_EQ && value >= 1) return true;
        // list.length != 0
        if (op == TokenType.BANG_EQ && value == 0) return true;
        // list.length == 1, list.length == 2, etc. (exact positive length)
        if (op == TokenType.EQ_EQ && value >= 1) return true;
      }
    }

    return false;
  }

  /// Checks if condition is list.length == 0 (for inverted guard).
  bool _isLengthZeroCheck(BinaryExpression expr, String collectionName) {
    final Expression left = expr.leftOperand;
    final Expression right = expr.rightOperand;

    String? lengthTarget;
    if (left is PrefixedIdentifier && left.identifier.name == 'length') {
      lengthTarget = left.prefix.name;
    } else if (left is PropertyAccess && left.propertyName.name == 'length') {
      lengthTarget = left.target?.toSource();
    }

    if (lengthTarget == collectionName &&
        expr.operator.type == TokenType.EQ_EQ &&
        right is IntegerLiteral &&
        right.value == 0) {
      return true;
    }

    return false;
  }

  /// Checks if [node] is a descendant of [potentialAncestor].
  bool _isDescendantOf(AstNode node, AstNode potentialAncestor) {
    AstNode? current = node;
    while (current != null) {
      if (current == potentialAncestor) return true;
      current = current.parent;
    }
    return false;
  }
}

/// Warns when reduce() is called on a potentially empty collection.
///
/// Since: v0.1.8 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: no_unsafe_reduce, prefer_fold
///
/// Calling reduce() on an empty collection throws a StateError.
/// Use fold() with an initial value instead.
///
/// Example of **bad** code:
/// ```dart
/// final sum = numbers.reduce((a, b) => a + b);  // Throws if empty
/// ```
///
/// Example of **good** code:
/// ```dart
/// final sum = numbers.fold(0, (a, b) => a + b);
/// // or
/// final sum = numbers.isEmpty ? 0 : numbers.reduce((a, b) => a + b);
/// ```
class AvoidUnsafeReduceRule extends SaropaLintRule {
  AvoidUnsafeReduceRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unsafe_reduce',
    '[avoid_unsafe_reduce] Calling reduce() on an empty collection throws a StateError at runtime, crashing the app. Unlike fold(), reduce() has no initial value and requires at least one element to operate. {v6}',
    correctionMessage:
        'Replace reduce() with fold() and provide an initial value, or guard the call with an isEmpty check first.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'reduce') return;

      // Check if target is an Iterable type
      final Expression? target = node.realTarget;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      if (typeName.startsWith('List') ||
          typeName.startsWith('Set') ||
          typeName.startsWith('Iterable') ||
          typeName.startsWith('Queue')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when firstWhere/lastWhere/singleWhere is used without orElse.
///
/// Since: v1.4.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: no_unsafe_where, require_or_else
///
/// These methods throw StateError if no element matches the predicate.
/// Use firstWhereOrNull/lastWhereOrNull/singleWhereOrNull from
/// package:collection instead.
///
/// Example of **bad** code:
/// ```dart
/// final item = items.firstWhere((e) => e.isActive);  // Throws if none match
/// final last = items.lastWhere((e) => e.id == 5);    // Throws if none match
/// ```
///
/// Example of **good** code:
/// ```dart
/// import 'package:collection/collection.dart';
/// final item = items.firstWhereOrNull((e) => e.isActive);
/// final last = items.lastWhereOrNull((e) => e.id == 5);
/// // or with orElse:
/// final item = items.firstWhere((e) => e.isActive, orElse: () => defaultItem);
/// ```
class AvoidUnsafeWhereMethodsRule extends SaropaLintRule {
  AvoidUnsafeWhereMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unsafe_where_methods',
    '[avoid_unsafe_where_methods] Calling firstWhere, lastWhere, or singleWhere without an orElse callback throws a StateError when no element matches the predicate. This crashes the app at runtime, especially when filtering data from external sources where matches are not guaranteed. {v4}',
    correctionMessage:
        'Use firstWhereOrNull, lastWhereOrNull, or singleWhereOrNull from package:collection, or provide an orElse callback to handle the no-match case.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _unsafeMethods = <String>{
    'firstWhere',
    'lastWhere',
    'singleWhere',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_unsafeMethods.contains(methodName)) return;

      // Check if target is an Iterable type
      final Expression? target = node.realTarget;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      if (!typeName.startsWith('List') &&
          !typeName.startsWith('Set') &&
          !typeName.startsWith('Iterable') &&
          !typeName.startsWith('Queue')) {
        return;
      }

      // Check if orElse is provided - if so, it's safe
      final NodeList<Expression> args = node.argumentList.arguments;
      for (final Expression arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'orElse') {
          return; // Has orElse callback, safe to use
        }
      }

      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseWhereOrNullFix(context: context),
  ];
}

/// Suggests using *OrNull methods instead of *Where with orElse callback.
///
/// Since: v4.1.1 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: use_where_or_null, prefer_or_null_methods
///
/// While using orElse is safe, the *OrNull pattern from package:collection
/// is more concise and idiomatic.
///
/// Example of **acceptable** code (but can be improved):
/// ```dart
/// final item = items.firstWhere((e) => e.isActive, orElse: () => defaultItem);
/// ```
///
/// Example of **preferred** code:
/// ```dart
/// import 'package:collection/collection.dart';
/// final item = items.firstWhereOrNull((e) => e.isActive) ?? defaultItem;
/// ```
class PreferWhereOrNullRule extends SaropaLintRule {
  PreferWhereOrNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'prefer_where_or_null',
    '[prefer_where_or_null] Using firstWhere/lastWhere/singleWhere with an orElse callback is verbose and harder to read. The *OrNull variant from package:collection combined with ?? produces cleaner, more idiomatic Dart code. {v4}',
    correctionMessage:
        'Replace .firstWhere(..., orElse: () => x) with .firstWhereOrNull(...) ?? x to reduce boilerplate and improve readability.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _whereMethods = <String>{
    'firstWhere',
    'lastWhere',
    'singleWhere',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_whereMethods.contains(methodName)) return;

      // Check if target exists (has something before the dot)
      final Expression? target = node.realTarget;
      if (target == null) return;

      // Check if target is an Iterable type (if type is resolved)
      final DartType? targetType = target.staticType;
      if (targetType != null) {
        final String typeName = targetType.getDisplayString();
        // Skip if definitely not an iterable type
        if (!typeName.contains('List') &&
            !typeName.contains('Set') &&
            !typeName.contains('Iterable') &&
            !typeName.contains('Queue') &&
            !typeName.contains('Iterable')) {
          return;
        }
      }

      // Only flag if orElse IS provided (otherwise AvoidUnsafeWhereMethodsRule handles it)
      final NodeList<Expression> args = node.argumentList.arguments;
      NamedExpression? orElseArg;
      for (final Expression arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'orElse') {
          orElseArg = arg;
          break;
        }
      }

      if (orElseArg == null) return; // No orElse, handled by other rule

      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceWithWhereOrNullFix(context: context),
  ];
}

/// Warns when map literal keys are not in alphabetical order.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: sort_map_keys, alphabetical_map_keys
///
/// **Stylistic rule (opt-in only).** Key ordering does not affect runtime
/// behavior or performance. This is purely a readability preference.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final map = {'zebra': 1, 'apple': 2, 'banana': 3};
/// ```
///
/// #### GOOD:
/// ```dart
/// final map = {'apple': 2, 'banana': 3, 'zebra': 1};
/// ```
class MapKeysOrderingRule extends SaropaLintRule {
  MapKeysOrderingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'map_keys_ordering',
    '[map_keys_ordering] Ordering map keys alphabetically is a stylistic preference for readability. Key order does not affect map behavior or performance at runtime. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Reorder the map entries alphabetically by key to improve readability and make diffs easier to review.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!node.isMap) return;

      final List<String> stringKeys = <String>[];

      for (final CollectionElement element in node.elements) {
        if (element is MapLiteralEntry) {
          final Expression key = element.key;
          if (key is SimpleStringLiteral) {
            stringKeys.add(key.value);
          } else {
            // Non-string key, skip ordering check
            return;
          }
        }
      }

      // Check if keys are sorted
      for (int i = 1; i < stringKeys.length; i++) {
        if (stringKeys[i].compareTo(stringKeys[i - 1]) < 0) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when indexOf is used to check for element presence.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_index_of_for_contains, use_contains
///
/// Example of **bad** code:
/// ```dart
/// if (list.indexOf(item) != -1) { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (list.contains(item)) { ... }
/// ```
class PreferContainsRule extends SaropaLintRule {
  PreferContainsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseContainsFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_list_contains',
    '[prefer_list_contains] Using indexOf() with a comparison to -1 or 0 to check element presence is verbose and error-prone. The contains() method expresses intent directly, improving readability and reducing off-by-one mistakes. {v2}',
    correctionMessage:
        'Replace the indexOf() comparison with contains() to express the presence check directly and clearly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final Expression left = node.leftOperand;
      if (left is! MethodInvocation) return;
      if (left.methodName.name != 'indexOf') return;

      final Expression right = node.rightOperand;
      if (right is IntegerLiteral && (right.value == -1 || right.value == 0)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when `list[0]` is used instead of `list.first`.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: use_first_not_index, no_list_zero
///
/// **Stylistic rule (opt-in only).** The `.first` getter calls `operator[]`
/// with index 0 internally — there is no performance benefit. This is purely
/// a readability preference.
///
/// Example of **bad** code:
/// ```dart
/// final first = list[0];
/// ```
///
/// Example of **good** code:
/// ```dart
/// final first = list.first;
/// ```
///
/// **Quick fix available:** Replaces `list[0]` with `list.first`.
class PreferFirstRule extends SaropaLintRule {
  PreferFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseFirstFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_list_first',
    '[prefer_list_first] Using [0] instead of .first is a stylistic choice. The .first getter calls [0] internally — there is no performance benefit. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Replace [0] with .first or .firstOrNull to clearly communicate the intent of accessing the first element.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
      final Expression index = node.index;
      if (index is IntegerLiteral && index.value == 0) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when List.from/Set.from/Map.from is used instead of .of constructors.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: prefer_of_over_from, no_collection_from
///
/// The `.of` constructors are more efficient for creating collections from iterables
/// when you don't need the type casting behavior of `.from`.
///
/// Example of **bad** code:
/// ```dart
/// final list = List<int>.from(items);
/// final set = Set<String>.from(names);
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = List<int>.of(items);
/// final set = Set<String>.of(names);
/// ```
class PreferIterableOfRule extends SaropaLintRule {
  PreferIterableOfRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_iterable_of',
    '[prefer_iterable_of] Using .from() performs a runtime cast on each element, which can silently succeed with wrong types and throw later. The .of() constructor enforces type safety at the call site, catching type mismatches immediately. {v4}',
    correctionMessage:
        'Replace .from() with .of() to enforce compile-time type checking and prevent silent runtime cast failures.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _collectionTypes = <String>{
    'List',
    'Set',
    'Queue',
    'LinkedList',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String? name = constructorName.name?.name;

      if (name != 'from') return;

      final String typeName = constructorName.type.name.lexeme;
      if (_collectionTypes.contains(typeName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when `list[length-1]` is used instead of `list.last`.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: use_last_not_index, no_length_minus_one
///
/// **Stylistic rule (opt-in only).** The `.last` getter performs the same
/// index computation internally — there is no performance benefit. This is
/// purely a readability preference.
///
/// Example of **bad** code:
/// ```dart
/// final last = list[list.length - 1];
/// ```
///
/// Example of **good** code:
/// ```dart
/// final last = list.last;
/// ```
class PreferLastRule extends SaropaLintRule {
  PreferLastRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_list_last',
    '[prefer_list_last] Using [length-1] instead of .last is a stylistic choice. The .last getter does the same indexing internally — no performance benefit. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Replace list[list.length - 1] with list.last to improve readability and reduce off-by-one error risk.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
      final Expression index = node.index;

      // Check for pattern: length - 1
      if (index is BinaryExpression && index.operator.type == TokenType.MINUS) {
        final Expression right = index.rightOperand;
        if (right is IntegerLiteral && right.value == 1) {
          // Check if left operand is .length on the same target
          final Expression left = index.leftOperand;
          if (left is PropertyAccess && left.propertyName.name == 'length') {
            // Check if the target matches
            final Expression? indexTarget = node.target;
            final Expression lengthTarget = left.target!;
            if (indexTarget != null &&
                indexTarget.toSource() == lengthTarget.toSource()) {
              reporter.atNode(node);
            }
          }
          // Also check for simple identifier.length pattern
          if (left is PrefixedIdentifier && left.identifier.name == 'length') {
            final Expression? indexTarget = node.target;
            if (indexTarget is SimpleIdentifier &&
                indexTarget.name == left.prefix.name) {
              reporter.atNode(node);
            }
          }
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        UseLastFix(context: context),
  ];
}

/// Warns when forEach with add is used instead of addAll.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: use_add_all, no_foreach_add
///
/// Example of **bad** code:
/// ```dart
/// items.forEach((item) => list.add(item));
/// for (final item in items) { list.add(item); }
/// ```
///
/// Example of **good** code:
/// ```dart
/// list.addAll(items);
/// ```
class PreferAddAllRule extends SaropaLintRule {
  PreferAddAllRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_add_all',
    '[prefer_add_all] Looping with forEach or for-in to call add() one element at a time is verbose and slower than addAll(), which can pre-allocate capacity and copy elements in bulk. This pattern also obscures the intent of batch insertion. {v4}',
    correctionMessage:
        'Replace the forEach/for loop with list.addAll(items) to reduce boilerplate and enable bulk insertion optimization.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check forEach pattern: items.forEach((item) => list.add(item))
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'forEach') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is! FunctionExpression) return;

      final FunctionBody body = firstArg.body;
      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        if (expr is MethodInvocation && expr.methodName.name == 'add') {
          // Check if the argument to add is the forEach parameter
          final FormalParameterList? params = firstArg.parameters;
          if (params != null && params.parameters.isNotEmpty) {
            final String? paramName = params.parameters.first.name?.lexeme;
            final NodeList<Expression> addArgs = expr.argumentList.arguments;
            if (addArgs.isNotEmpty && addArgs.first is SimpleIdentifier) {
              final SimpleIdentifier addArg = addArgs.first as SimpleIdentifier;
              if (addArg.name == paramName) {
                reporter.atNode(node);
              }
            }
          }
        }
      }
    });

    // Check for-in pattern: for (final item in items) { list.add(item); }
    context.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is! ForEachPartsWithDeclaration) return;

      final Statement body = node.body;
      if (body is! Block) return;
      if (body.statements.length != 1) return;

      final Statement stmt = body.statements.first;
      if (stmt is! ExpressionStatement) return;

      final Expression expr = stmt.expression;
      if (expr is! MethodInvocation) return;
      if (expr.methodName.name != 'add') return;

      // Check if add argument matches loop variable
      final String loopVar = parts.loopVariable.name.lexeme;
      final NodeList<Expression> addArgs = expr.argumentList.arguments;
      if (addArgs.isNotEmpty && addArgs.first is SimpleIdentifier) {
        final SimpleIdentifier addArg = addArgs.first as SimpleIdentifier;
        if (addArg.name == loopVar) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when duplicate numeric elements appear in collection literals.
///
/// Since: v4.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_duplicate_numbers, unique_number_elements
///
/// Duplicate numeric values in lists or sets are usually unintentional and
/// indicate copy-paste errors or logic mistakes. However, some legitimate
/// use cases exist (e.g., days-in-month arrays), which is why this rule
/// can be suppressed independently from string and object duplicate rules.
///
/// **Why this matters:**
/// - Duplicate numbers waste memory and may cause logic errors
/// - Sets silently ignore duplicates, leading to unexpected behavior
/// - Often indicates copy-paste mistakes
///
/// Example of **bad** code:
/// ```dart
/// final list = [1, 2, 1, 3];  // 1 is duplicated
/// final doubles = [1.5, 2.0, 1.5];  // 1.5 is duplicated
/// final prices = {9.99, 19.99, 9.99};  // Set silently ignores duplicate
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = [1, 2, 3, 4];
/// // ignore: avoid_duplicate_number_elements
/// const daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
/// ```
///
/// **Quick fix available:** Removes the duplicate element.
///
/// See also:
/// - `avoid_duplicate_string_elements` for string duplicates
/// - `avoid_duplicate_object_elements` for other duplicates
class AvoidDuplicateNumberElementsRule extends SaropaLintRule {
  AvoidDuplicateNumberElementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_duplicate_number_elements',
    '[avoid_duplicate_number_elements] Duplicate numeric element in collection literal typically indicates a copy-paste error or logic mistake. In Sets, the duplicate is silently ignored, producing a smaller collection than expected. {v2}',
    correctionMessage:
        'Remove the duplicate numeric element. If intentional (e.g., days-in-month arrays), suppress with // ignore.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only flag Set literals — duplicates in Sets are silently dropped
    // (producing a smaller collection than expected), which is almost
    // always a bug.  In Lists, duplicate numeric values at different
    // indices are semantically distinct and commonly intentional
    // (e.g. days-in-month arrays, quarter mappings).
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.isSet) {
        _checkForDuplicateNumbers(node.elements, reporter, code);
      }
    });
  }
}

/// Warns when duplicate string elements appear in collection literals.
///
/// Since: v4.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_duplicate_strings, unique_string_elements
///
/// Duplicate string values in lists or sets indicate copy-paste errors or
/// unintentional repetition. This rule can be suppressed independently from
/// number and object duplicate rules.
///
/// **Why this matters:**
/// - Duplicate strings waste memory
/// - Sets silently ignore duplicates, leading to unexpected behavior
/// - Often indicates copy-paste mistakes or incomplete refactoring
///
/// Example of **bad** code:
/// ```dart
/// final list = ['a', 'b', 'a'];  // 'a' is duplicated
/// final set = {'hello', 'world', 'hello'};  // Set silently ignores duplicate
/// final urls = ['https://api.com', 'https://backup.com', 'https://api.com'];
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = ['a', 'b', 'c'];
/// final set = {'hello', 'world', 'foo'};
/// ```
///
/// **Quick fix available:** Removes the duplicate element.
///
/// See also:
/// - `avoid_duplicate_number_elements` for numeric duplicates
/// - `avoid_duplicate_object_elements` for other duplicates
class AvoidDuplicateStringElementsRule extends SaropaLintRule {
  AvoidDuplicateStringElementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_duplicate_string_elements',
    '[avoid_duplicate_string_elements] Duplicate string element in collection literal typically indicates a copy-paste error or incomplete refactoring. In Sets, the duplicate is silently ignored, producing a smaller collection than expected. {v2}',
    correctionMessage:
        'Remove the duplicate string element or verify the values are intentionally repeated. In Sets, duplicates are silently discarded.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      _checkForDuplicateStrings(node.elements, reporter, code);
    });

    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.isSet) {
        _checkForDuplicateStrings(node.elements, reporter, code);
      }
    });
  }
}

/// Warns when duplicate object elements appear in collection literals.
///
/// Since: v4.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_duplicate_objects, unique_object_elements
///
/// This rule detects duplicate boolean literals, null literals, and
/// identifier references in collections. It complements the number and
/// string duplicate rules.
///
/// **Why this matters:**
/// - Duplicate references in lists are usually unintentional
/// - Boolean lists like `[true, false, true]` are typically errors
/// - Sets silently ignore duplicates, leading to unexpected size
///
/// Example of **bad** code:
/// ```dart
/// final list = [myObj, otherObj, myObj];  // myObj is duplicated
/// final bools = [true, false, true];  // true is duplicated
/// final nulls = [null, value, null];  // null is duplicated
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = [myObj, otherObj, thirdObj];
/// final bools = [true, false];
/// ```
///
/// **Quick fix available:** Removes the duplicate element.
///
/// See also:
/// - `avoid_duplicate_number_elements` for numeric duplicates
/// - `avoid_duplicate_string_elements` for string duplicates
class AvoidDuplicateObjectElementsRule extends SaropaLintRule {
  AvoidDuplicateObjectElementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_duplicate_object_elements',
    '[avoid_duplicate_object_elements] Duplicate object reference or literal (bool, null, identifier) in collection typically indicates a copy-paste error. In Sets, the duplicate is silently ignored, producing a smaller collection than expected. {v2}',
    correctionMessage:
        'Remove the duplicate object element or verify the references are intentionally repeated. In Sets, duplicates are silently discarded.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      _checkForDuplicateObjects(node.elements, reporter, code);
    });

    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.isSet) {
        _checkForDuplicateObjects(node.elements, reporter, code);
      }
    });
  }
}

// =============================================================================
// Shared helpers for duplicate element detection
// =============================================================================

/// Checks for duplicate numeric literals in a collection.
void _checkForDuplicateNumbers(
  NodeList<CollectionElement> elements,
  SaropaDiagnosticReporter reporter,
  LintCode code,
) {
  final Set<String> seen = <String>{};
  for (final CollectionElement element in elements) {
    if (element is! Expression) continue;
    if (element is! IntegerLiteral && element is! DoubleLiteral) continue;

    final String source = element.toSource();
    if (seen.contains(source)) {
      reporter.atNode(element);
    } else {
      seen.add(source);
    }
  }
}

/// Checks for duplicate string literals in a collection.
void _checkForDuplicateStrings(
  NodeList<CollectionElement> elements,
  SaropaDiagnosticReporter reporter,
  LintCode code,
) {
  final Set<String> seen = <String>{};
  for (final CollectionElement element in elements) {
    if (element is! Expression) continue;
    if (element is! StringLiteral) continue;

    final String source = element.toSource();
    if (seen.contains(source)) {
      reporter.atNode(element);
    } else {
      seen.add(source);
    }
  }
}

/// Checks for duplicate object literals/identifiers in a collection.
void _checkForDuplicateObjects(
  NodeList<CollectionElement> elements,
  SaropaDiagnosticReporter reporter,
  LintCode code,
) {
  final Set<String> seen = <String>{};
  for (final CollectionElement element in elements) {
    if (element is! Expression) continue;

    // Skip numeric and string literals (handled by other rules)
    if (element is IntegerLiteral ||
        element is DoubleLiteral ||
        element is StringLiteral) {
      continue;
    }

    // Check other literals (bool, null) and identifiers
    if (element is! Literal && element is! SimpleIdentifier) continue;

    final String source = element.toSource();
    if (seen.contains(source)) {
      reporter.atNode(element);
    } else {
      seen.add(source);
    }
  }
}

/// Quick fix that removes a duplicate element from a collection.

/// Warns when a List is used for frequent contains() checks.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: use_set_for_contains, set_over_list_lookup
///
/// Using Set for lookups is O(1) vs O(n) for List.
///
/// Example of **bad** code:
/// ```dart
/// final allowedItems = ['a', 'b', 'c'];
/// if (allowedItems.contains(value)) { ... }  // O(n) lookup
/// ```
///
/// Example of **good** code:
/// ```dart
/// final allowedItems = {'a', 'b', 'c'};
/// if (allowedItems.contains(value)) { ... }  // O(1) lookup
/// ```
class PreferSetForLookupRule extends SaropaLintRule {
  PreferSetForLookupRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'prefer_set_for_lookup',
    '[prefer_set_for_lookup] Calling contains() on a List performs a linear O(n) scan through every element, while a Set uses hash-based O(1) lookup. For collections used primarily for membership testing, this causes unnecessary performance degradation. {v5}',
    correctionMessage:
        'Change the collection type from List to Set to use hash-based O(1) lookup instead of linear O(n) scanning.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'contains') return;

      final Expression? target = node.realTarget;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      // Only warn for List types (not Set or other collections)
      if (typeName.startsWith('List<')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when for loop uses non-standard increment patterns.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: standard_for_increment, no_non_standard_increment
///
/// Standard for loop increments make code more readable and predictable.
///
/// **BAD:**
/// ```dart
/// for (int i = 0; i < 10; i += 2) { } // Non-standard increment
/// for (int i = 0; i < 10; i = i + 3) { } // Verbose increment
/// ```
///
/// **GOOD:**
/// ```dart
/// for (int i = 0; i < 10; i++) { } // Standard increment
/// for (int i = 0; i < 10; i += 1) { } // Also acceptable
/// ```
class PreferCorrectForLoopIncrementRule extends SaropaLintRule {
  PreferCorrectForLoopIncrementRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_for_loop_increment',
    '[prefer_correct_for_loop_increment] Non-standard for loop increment (e.g., i += 2, i = i + 3) reduces readability and can hide off-by-one errors. Standard i++ makes the iteration pattern immediately recognizable to all developers. {v2}',
    correctionMessage:
        'Use i++ for standard iteration, or add a comment explaining why a non-standard increment step is necessary.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is! ForParts) return;

      // Check for updaters (the part after the second semicolon)
      final NodeList<Expression> updaters = parts.updaters;
      if (updaters.isEmpty) return;

      for (final Expression updater in updaters) {
        // Check for compound assignment like i += 2
        if (updater is AssignmentExpression) {
          final String op = updater.operator.lexeme;
          if (op == '+=' || op == '-=') {
            final Expression right = updater.rightHandSide;
            if (right is IntegerLiteral && right.value != 1) {
              // Non-standard increment (not by 1)
              reporter.atNode(updater);
            }
          }
        }
        // Check for verbose i = i + n pattern
        if (updater is AssignmentExpression && updater.operator.lexeme == '=') {
          final Expression right = updater.rightHandSide;
          if (right is BinaryExpression) {
            // i = i + n or i = i - n
            if (right.operator.type == TokenType.PLUS ||
                right.operator.type == TokenType.MINUS) {
              final Expression rightOperand = right.rightOperand;
              if (rightOperand is IntegerLiteral && rightOperand.value != 1) {
                reporter.atNode(updater);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when a for loop has impossible or unreachable bounds.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: no_impossible_for_loop, unreachable_loop_body
///
/// For loops with impossible conditions never execute or run infinitely.
///
/// **BAD:**
/// ```dart
/// for (int i = 10; i < 5; i++) { } // Never executes
/// for (int i = 0; i > 10; i++) { } // Never executes
/// for (int i = 0; i < 10; i--) { } // Infinite loop
/// ```
///
/// **GOOD:**
/// ```dart
/// for (int i = 0; i < 10; i++) { } // Standard ascending
/// for (int i = 10; i > 0; i--) { } // Standard descending
/// ```
class AvoidUnreachableForLoopRule extends SaropaLintRule {
  AvoidUnreachableForLoopRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unreachable_for_loop',
    '[avoid_unreachable_for_loop] For loop with impossible bounds will never execute, resulting in dead code. This often indicates a logic error, typo, or incorrect increment direction. Unreachable loops can hide bugs, confuse maintainers, and lead to missed updates or calculations. {v3}',
    correctionMessage:
        'Review the loop condition and increment direction. Ensure the bounds allow the loop to execute at least once, and correct any off-by-one errors or typos. Add tests to verify loop behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is! ForParts) return;

      // Get initialization value if it's a simple integer
      int? initValue;
      if (parts is ForPartsWithDeclarations) {
        final NodeList<VariableDeclaration> vars = parts.variables.variables;
        if (vars.length == 1) {
          final Expression? init = vars.first.initializer;
          if (init is IntegerLiteral) {
            initValue = init.value;
          }
        }
      }

      // Get condition
      final Expression? condition = parts.condition;
      if (condition is! BinaryExpression) return;

      final TokenType op = condition.operator.type;
      final Expression left = condition.leftOperand;
      final Expression right = condition.rightOperand;

      // Get bound value if it's a simple integer
      int? boundValue;
      if (right is IntegerLiteral) {
        boundValue = right.value;
      }

      // Check for impossible initial conditions
      if (initValue != null && boundValue != null) {
        // i = 10; i < 5 (start > end with <)
        if ((op == TokenType.LT || op == TokenType.LT_EQ) &&
            initValue > boundValue) {
          reporter.atNode(condition);
          return;
        }
        // i = 5; i > 10 (start < end with >)
        if ((op == TokenType.GT || op == TokenType.GT_EQ) &&
            initValue < boundValue) {
          reporter.atNode(condition);
          return;
        }
      }

      // Check for mismatched increment direction
      final NodeList<Expression> updaters = parts.updaters;
      if (updaters.isEmpty) return;

      final Expression updater = updaters.first;
      bool? isIncrementing;

      if (updater is PostfixExpression) {
        isIncrementing = updater.operator.type == TokenType.PLUS_PLUS;
      } else if (updater is PrefixExpression) {
        isIncrementing = updater.operator.type == TokenType.PLUS_PLUS;
      } else if (updater is AssignmentExpression) {
        final String opLex = updater.operator.lexeme;
        if (opLex == '+=') {
          final Expression r = updater.rightHandSide;
          if (r is IntegerLiteral && r.value != null) {
            isIncrementing = r.value! > 0;
          }
        } else if (opLex == '-=') {
          final Expression r = updater.rightHandSide;
          if (r is IntegerLiteral && r.value != null) {
            isIncrementing = r.value! < 0;
          }
        }
      }

      if (isIncrementing == null) return;

      // Check for mismatched direction: i < n with i-- or i > n with i++
      final String varName = left is SimpleIdentifier ? left.name : '';
      if (varName.isEmpty) return;

      // i < bound with decrement = infinite loop
      if ((op == TokenType.LT || op == TokenType.LT_EQ) && !isIncrementing) {
        reporter.atNode(condition);
      }
      // i > bound with increment = infinite loop (if start < bound)
      if ((op == TokenType.GT || op == TokenType.GT_EQ) && isIncrementing) {
        reporter.atNode(condition);
      }
    });
  }
}

/// Warns when collections handle nullable items without null-aware spread.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Dart 3 supports null-aware elements (?element) in collections.
/// This avoids explicit null checks when adding nullable items.
///
/// **BAD:**
/// ```dart
/// final items = [
///   item1,
///   if (item2 != null) item2,
/// ];
/// ```
///
/// **GOOD:**
/// ```dart
/// final items = [
///   item1,
///   ?item2,
/// ];
/// ```
class PreferNullAwareElementsRule extends SaropaLintRule {
  PreferNullAwareElementsRule() : super(code: _code);

  /// Code style improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_null_aware_elements',
    '[prefer_null_aware_elements] Explicit null check with if (x != null) x in collection literals is verbose. Dart 3 supports the ?element syntax, which eliminates the boilerplate and expresses nullable inclusion more concisely. {v5}',
    correctionMessage:
        'Replace `if (x != null) x` with `?x` to use the Dart 3 null-aware element syntax and reduce collection boilerplate.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfElement((node) {
      // Check for pattern: if (x != null) x
      final condition = node.expression;
      if (condition is! BinaryExpression) {
        return;
      }

      if (condition.operator.lexeme != '!=') {
        return;
      }

      // Check if comparing to null
      final right = condition.rightOperand;
      if (right is! NullLiteral) {
        return;
      }

      // Get the variable being checked
      final left = condition.leftOperand;
      if (left is! SimpleIdentifier) {
        return;
      }

      final varName = left.name;

      // Check if then element is just that variable
      final thenElement = node.thenElement;
      if (thenElement is! Expression) {
        return;
      }

      if (thenElement is SimpleIdentifier && thenElement.name == varName) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when iterable operations chain to List when lazy iteration suffices.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Chaining .map().where().toList() creates intermediate lists.
/// If only iterating once, keep it lazy for better memory usage.
///
/// **BAD:**
/// ```dart
/// for (final item in items.map((x) => x.name).where((n) => n.isNotEmpty).toList()) {
///   print(item);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// for (final item in items.map((x) => x.name).where((n) => n.isNotEmpty)) {
///   print(item);
/// }
/// ```
///
/// **ALSO OK:**
/// ```dart
/// // toList() is fine when you need the list itself
/// final names = items.map((x) => x.name).toList();
/// names.add('extra');
/// ```
class PreferIterableOperationsRule extends SaropaLintRule {
  PreferIterableOperationsRule() : super(code: _code);

  /// Performance improvement for large collections.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_iterable_operations',
    '[prefer_iterable_operations] Calling .toList() at the end of an iterable chain inside a for-in loop forces eager evaluation and allocates an intermediate list that is iterated once and then discarded. This wastes memory and CPU cycles. {v2}',
    correctionMessage:
        'Remove .toList() to keep the iteration lazy and eliminate the unnecessary intermediate list allocation.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((node) {
      final forParts = node.forLoopParts;
      if (forParts is! ForEachPartsWithDeclaration) {
        return;
      }

      // Check if iterable ends with toList()
      final iterable = forParts.iterable;
      if (iterable is! MethodInvocation) {
        return;
      }

      if (iterable.methodName.name != 'toList' &&
          iterable.methodName.name != 'toSet') {
        return;
      }

      // Check if there's a chain before toList
      final target = iterable.target;
      if (target is! MethodInvocation) {
        return;
      }

      // Common chained methods that return iterables
      final chainMethods = ['map', 'where', 'expand', 'take', 'skip'];
      if (chainMethods.contains(target.methodName.name)) {
        reporter.atNode(iterable.methodName, code);
      }
    });
  }
}

/// Warns when widgets in lists lack a Key for efficient updates.
///
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: list_item_key, require_widget_key, no_keyless_list_items
///
/// Flutter uses keys to identify widgets in lists. Without keys, Flutter
/// may inefficiently rebuild widgets or lose widget state during reordering.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(title: Text(items[index])),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(
///     key: ValueKey(items[index].id),
///     title: Text(items[index].name),
///   ),
/// )
/// ```
class RequireKeyForCollectionRule extends SaropaLintRule {
  RequireKeyForCollectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_key_for_collection',
    '[require_key_for_collection] List items in dynamic collections (ListView, GridView, etc.) must have a Key to preserve child widget state (e.g., TextField input, animations) when the list reorders or updates. Missing keys can cause UI bugs, loss of user input, broken animations, and confusing user experiences. This is a common source of hard-to-debug Flutter widget tree issues. {v4}',
    correctionMessage:
        'Add a Key (such as ValueKey, ObjectKey, or UniqueKey) to each list item. Ensure the key is unique and stable for each item, especially when items are reordered or updated. Document key usage in your builder methods to prevent state loss.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// List builder widgets that need keyed children.
  static const Set<String> _listBuilderWidgets = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SliverList',
    'SliverGrid',
    'ReorderableListView',
    'AnimatedList',
  };

  /// Builder methods that indicate dynamic list building.
  static const Set<String> _builderMethods = <String>{
    'builder',
    'separated',
    'custom',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      final String widgetName = target.name;
      final String methodName = node.methodName.name;

      // Check for ListView.builder, GridView.builder, etc.
      if (!_listBuilderWidgets.contains(widgetName)) return;
      if (!_builderMethods.contains(methodName)) return;

      // Find the itemBuilder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            _checkBuilderForKey(builderExpr, reporter);
          }
        }
      }
    });

    // Also check for ReorderableListView and AnimatedList constructors
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName == null) return;

      if (typeName == 'ReorderableListView' ||
          typeName == 'AnimatedList' ||
          typeName == 'SliverAnimatedList') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
            final Expression builderExpr = arg.expression;
            if (builderExpr is FunctionExpression) {
              _checkBuilderForKey(builderExpr, reporter);
            }
          }
        }
      }
    });
  }

  void _checkBuilderForKey(
    FunctionExpression builder,
    SaropaDiagnosticReporter reporter,
  ) {
    final FunctionBody body = builder.body;

    // Get the returned widget expression
    Expression? returnedWidget;

    if (body is ExpressionFunctionBody) {
      returnedWidget = body.expression;
    } else if (body is BlockFunctionBody) {
      // Find return statement
      for (final Statement stmt in body.block.statements) {
        if (stmt is ReturnStatement && stmt.expression != null) {
          returnedWidget = stmt.expression;
          break;
        }
      }
    }

    if (returnedWidget == null) return;

    // Check if the returned widget has a key
    if (returnedWidget is InstanceCreationExpression) {
      if (!_hasKeyArgument(returnedWidget)) {
        reporter.atNode(returnedWidget.constructorName, code);
      }
    }
  }

  bool _hasKeyArgument(InstanceCreationExpression widget) {
    for (final Expression arg in widget.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'key') {
        return true;
      }
    }
    return false;
  }
}
