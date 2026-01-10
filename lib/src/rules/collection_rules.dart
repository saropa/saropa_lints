// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when comparing collections using == operator.
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
  const AvoidCollectionEqualityChecksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_collection_equality_checks',
    problemMessage: 'Comparing collections with == uses reference equality.',
    correctionMessage:
        'Use listEquals, setEquals, mapEquals, or DeepCollectionEquality.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
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
        reporter.atNode(node, code);
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackCommentForCollectionEqualityFix()];
}

class _AddHackCommentForCollectionEqualityFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for collection comparison',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: use listEquals/setEquals/mapEquals */ ',
        );
      });
    });
  }
}

/// Warns when duplicate keys are used in a map literal.
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
  const AvoidDuplicateMapKeysRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_map_keys',
    problemMessage: 'Duplicate key in map literal.',
    correctionMessage: 'Remove or rename the duplicate key.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
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
  const AvoidMapKeysContainsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_map_keys_contains',
    problemMessage: 'Use containsKey() instead of keys.contains().',
    correctionMessage:
        'Replace map.keys.contains(key) with map.containsKey(key).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'contains') return;

      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      if (target.propertyName.name == 'keys') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseContainsKeyFix()];
}

class _UseContainsKeyFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'contains') return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression? target = node.target;
      if (target is! PropertyAccess) return;
      if (target.propertyName.name != 'keys') return;

      final Expression? mapExpr = target.target;
      if (mapExpr == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use containsKey()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Replace "map.keys.contains(key)" with "map.containsKey(key)"
        final String mapSource = mapExpr.toSource();
        final String argsSource = node.argumentList.toSource();
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '$mapSource.containsKey$argsSource',
        );
      });
    });
  }
}

/// Warns when unnecessary collection wrappers are used.
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
  const AvoidUnnecessaryCollectionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_collections',
    problemMessage: 'Unnecessary collection wrapper.',
    correctionMessage: 'Use the collection literal directly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _unnecessaryMethods = <String>{
    'of',
    'from',
  };

  static const Set<String> _collectionTypes = <String>{
    'List',
    'Set',
    'Map',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when using .first or .last on potentially empty collections.
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
  const AvoidUnsafeCollectionMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_collection_methods',
    problemMessage:
        'Using .first or .last on a potentially empty collection is unsafe.',
    correctionMessage: 'Use .firstOrNull/.lastOrNull or check isEmpty first.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _unsafeMethods = <String>{'first', 'last', 'single'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
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

        reporter.atNode(node, code);
      }
    });

    // Also check for prefixed identifier access like list.first
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
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

        reporter.atNode(node, code);
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

  @override
  List<Fix> getFixes() => <Fix>[_UseNullSafeCollectionMethodFix()];
}

class _UseNullSafeCollectionMethodFix extends DartFix {
  static const Map<String, String> _replacements = <String, String>{
    'first': 'firstOrNull',
    'last': 'lastOrNull',
    'single': 'singleOrNull',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Handle PropertyAccess nodes (e.g., someList.first)
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      final String propertyName = node.propertyName.name;
      final String? replacement = _replacements[propertyName];
      if (replacement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .$replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.propertyName.offset, node.propertyName.length),
          replacement,
        );
      });
    });

    // Handle PrefixedIdentifier nodes (e.g., list.first in simple cases)
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      final String propertyName = node.identifier.name;
      final String? replacement = _replacements[propertyName];
      if (replacement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .$replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.identifier.offset, node.identifier.length),
          replacement,
        );
      });
    });
  }
}

/// Warns when reduce() is called on a potentially empty collection.
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
  const AvoidUnsafeReduceRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_reduce',
    problemMessage: 'reduce() throws on empty collections.',
    correctionMessage:
        'Use fold() with an initial value or check isEmpty first.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackCommentForReduceFix()];
}

class _AddHackCommentForReduceFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'reduce') return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for unsafe reduce',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: use fold() or check empty */ ',
        );
      });
    });
  }
}

/// Warns when firstWhere/lastWhere/singleWhere is used without orElse.
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
  const AvoidUnsafeWhereMethodsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_where_methods',
    problemMessage:
        'firstWhere/lastWhere/singleWhere throws if no element matches.',
    correctionMessage:
        'Use firstWhereOrNull/lastWhereOrNull/singleWhereOrNull from '
        'package:collection, or provide an orElse callback.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _unsafeMethods = <String>{
    'firstWhere',
    'lastWhere',
    'singleWhere',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseWhereOrNullFix()];
}

class _UseWhereOrNullFix extends DartFix {
  static const Map<String, String> _replacements = <String, String>{
    'firstWhere': 'firstWhereOrNull',
    'lastWhere': 'lastWhereOrNull',
    'singleWhere': 'singleWhereOrNull',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_replacements.containsKey(methodName)) return;
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final String? replacement = _replacements[methodName];
      if (replacement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .$replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.methodName.offset, node.methodName.length),
          replacement,
        );
      });
    });
  }
}

/// Suggests using *OrNull methods instead of *Where with orElse callback.
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
  const PreferWhereOrNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_where_or_null',
    problemMessage:
        'Consider using firstWhereOrNull/lastWhereOrNull/singleWhereOrNull '
        'with ?? instead of orElse callback.',
    correctionMessage: 'Replace .firstWhere(..., orElse: () => x) with '
        '.firstWhereOrNull(...) ?? x for cleaner code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _whereMethods = <String>{
    'firstWhere',
    'lastWhere',
    'singleWhere',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithWhereOrNullFix()];
}

class _ReplaceWithWhereOrNullFix extends DartFix {
  static const Map<String, String> _replacements = <String, String>{
    'firstWhere': 'firstWhereOrNull',
    'lastWhere': 'lastWhereOrNull',
    'singleWhere': 'singleWhereOrNull',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_replacements.containsKey(methodName)) return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find orElse argument and extract its return expression
      final NodeList<Expression> args = node.argumentList.arguments;
      NamedExpression? orElseArg;
      Expression? predicateArg;

      for (final Expression arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'orElse') {
          orElseArg = arg;
        } else if (predicateArg == null) {
          predicateArg = arg;
        }
      }

      if (orElseArg == null || predicateArg == null) return;

      // Try to extract the return value from orElse callback
      String? defaultValue;
      final Expression orElseExpr = orElseArg.expression;
      if (orElseExpr is FunctionExpression) {
        final FunctionBody body = orElseExpr.body;
        if (body is ExpressionFunctionBody) {
          defaultValue = body.expression.toSource();
        }
      }

      final String? replacement = _replacements[methodName];
      if (replacement == null) return;

      final Expression? target = node.realTarget;
      if (target == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .$replacement ?? $defaultValue',
        priority: 1,
      );

      if (defaultValue != null) {
        changeBuilder.addDartFileEdit((builder) {
          // Replace entire method call with: target.firstWhereOrNull(predicate) ?? defaultValue
          final String newCode =
              '${target.toSource()}.$replacement(${predicateArg!.toSource()}) ?? $defaultValue';
          builder.addSimpleReplacement(
            SourceRange(node.offset, node.length),
            newCode,
          );
        });
      }
    });
  }
}

/// Warns when map literal keys are not in alphabetical order.
///
/// Alias: sort_map_keys, alphabetical_map_keys
///
/// Consistent key ordering improves readability.
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
  const MapKeysOrderingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'map_keys_ordering',
    problemMessage: 'Map keys should be in alphabetical order.',
    correctionMessage: 'Reorder the map entries alphabetically by key.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
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
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when indexOf is used to check for element presence.
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
  const PreferContainsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_contains',
    problemMessage: 'Use contains() instead of indexOf() for presence checks.',
    correctionMessage: 'Replace indexOf() comparison with contains().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final Expression left = node.leftOperand;
      if (left is! MethodInvocation) return;
      if (left.methodName.name != 'indexOf') return;

      final Expression right = node.rightOperand;
      if (right is IntegerLiteral && (right.value == -1 || right.value == 0)) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseContainsFix()];
}

class _UseContainsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression left = node.leftOperand;
      if (left is! MethodInvocation) return;
      if (left.methodName.name != 'indexOf') return;

      final Expression? target = left.target;
      if (target == null) return;

      final Expression right = node.rightOperand;
      if (right is! IntegerLiteral) return;

      final String op = node.operator.lexeme;
      final int? value = right.value;
      final String args = left.argumentList.arguments.first.toSource();
      String replacement;

      // indexOf(x) != -1 or indexOf(x) >= 0 means "contains"
      // indexOf(x) == -1 or indexOf(x) < 0 means "!contains"
      if ((value == -1 && op == '!=') || (value == 0 && op == '>=')) {
        replacement = '${target.toSource()}.contains($args)';
      } else if ((value == -1 && op == '==') || (value == 0 && op == '<')) {
        replacement = '!${target.toSource()}.contains($args)';
      } else if (value == -1 && op == '>') {
        replacement = '${target.toSource()}.contains($args)';
      } else {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .contains()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
      });
    });
  }
}

/// Warns when `list[0]` is used instead of `list.first`.
///
/// Alias: use_first_not_index, no_list_zero
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
  const PreferFirstRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_first',
    problemMessage: 'Use .first instead of [0].',
    correctionMessage: 'Replace [0] with .first or .firstOrNull.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      final Expression index = node.index;
      if (index is IntegerLiteral && index.value == 0) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseFirstFix()];
}

class _UseFirstFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression index = node.index;
      if (index is! IntegerLiteral || index.value != 0) return;

      final Expression? target = node.target;
      if (target == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .first',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '${target.toSource()}.first',
        );
      });
    });
  }
}

/// Warns when List.from/Set.from/Map.from is used instead of .of constructors.
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
  const PreferIterableOfRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_iterable_of',
    problemMessage: 'Prefer using .of() instead of .from() for collections.',
    correctionMessage: 'Replace .from() with .of() for better type safety.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _collectionTypes = <String>{
    'List',
    'Set',
    'Queue',
    'LinkedList',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String? name = constructorName.name?.name;

      if (name != 'from') return;

      final String typeName = constructorName.type.name.lexeme;
      if (_collectionTypes.contains(typeName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `list[length-1]` is used instead of `list.last`.
///
/// Alias: use_last_not_index, no_length_minus_one
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
  const PreferLastRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_last',
    problemMessage: 'Use .last instead of [length - 1].',
    correctionMessage: 'Replace list[list.length - 1] with list.last.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
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
              reporter.atNode(node, code);
            }
          }
          // Also check for simple identifier.length pattern
          if (left is PrefixedIdentifier && left.identifier.name == 'length') {
            final Expression? indexTarget = node.target;
            if (indexTarget is SimpleIdentifier &&
                indexTarget.name == left.prefix.name) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseLastFix()];
}

class _UseLastFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression? target = node.target;
      if (target == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use .last',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '${target.toSource()}.last',
        );
      });
    });
  }
}

/// Warns when forEach with add is used instead of addAll.
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
  const PreferAddAllRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_add_all',
    problemMessage: 'Use addAll() instead of forEach/for with add().',
    correctionMessage: 'Replace with list.addAll(items).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check forEach pattern: items.forEach((item) => list.add(item))
    context.registry.addMethodInvocation((MethodInvocation node) {
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
                reporter.atNode(node, code);
              }
            }
          }
        }
      }
    });

    // Check for-in pattern: for (final item in items) { list.add(item); }
    context.registry.addForStatement((ForStatement node) {
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
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when duplicate elements appear in collection literals.
///
/// Alias: no_duplicate_elements, unique_collection_elements
///
/// Example of **bad** code:
/// ```dart
/// final list = [1, 2, 1, 3];  // 1 is duplicated
/// final set = {'a', 'b', 'a'};  // 'a' is duplicated
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = [1, 2, 3];
/// final set = {'a', 'b', 'c'};
/// ```
class AvoidDuplicateCollectionElementsRule extends SaropaLintRule {
  const AvoidDuplicateCollectionElementsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_collection_elements',
    problemMessage: 'Duplicate element in collection literal.',
    correctionMessage: 'Remove the duplicate element.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      _checkForDuplicates(node.elements, reporter);
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.isSet) {
        _checkForDuplicates(node.elements, reporter);
      }
    });
  }

  void _checkForDuplicates(
    NodeList<CollectionElement> elements,
    SaropaDiagnosticReporter reporter,
  ) {
    final Set<String> seen = <String>{};
    for (final CollectionElement element in elements) {
      if (element is! Expression) continue;

      // Only check literals (not expressions that might have different values)
      if (element is! Literal && element is! SimpleIdentifier) continue;

      final String source = element.toSource();
      if (seen.contains(source)) {
        reporter.atNode(element, code);
      } else {
        seen.add(source);
      }
    }
  }
}

/// Warns when a List is used for frequent contains() checks.
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
  const PreferSetForLookupRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_set_for_lookup',
    problemMessage:
        'Consider using Set instead of List for contains() lookups.',
    correctionMessage: 'Sets have O(1) lookup vs O(n) for Lists.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'contains') return;

      final Expression? target = node.realTarget;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      // Only warn for List types (not Set or other collections)
      if (typeName.startsWith('List<')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when for loop uses non-standard increment patterns.
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
  const PreferCorrectForLoopIncrementRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_correct_for_loop_increment',
    problemMessage: 'For loop uses non-standard increment pattern.',
    correctionMessage: 'Consider using i++ for standard iteration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
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
              reporter.atNode(updater, code);
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
                reporter.atNode(updater, code);
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
  const AvoidUnreachableForLoopRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_unreachable_for_loop',
    problemMessage: 'For loop has impossible bounds and will never execute.',
    correctionMessage: 'Check the loop condition and increment direction.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
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
          reporter.atNode(condition, code);
          return;
        }
        // i = 5; i > 10 (start < end with >)
        if ((op == TokenType.GT || op == TokenType.GT_EQ) &&
            initValue < boundValue) {
          reporter.atNode(condition, code);
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
        reporter.atNode(condition, code);
      }
      // i > bound with increment = infinite loop (if start < bound)
      if ((op == TokenType.GT || op == TokenType.GT_EQ) && isIncrementing) {
        reporter.atNode(condition, code);
      }
    });
  }
}
