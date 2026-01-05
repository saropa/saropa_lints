// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when comparing collections using == operator.
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
class AvoidCollectionEqualityChecksRule extends DartLintRule {
  const AvoidCollectionEqualityChecksRule() : super(code: _code);

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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        message: 'Add HACK comment for collection comparison',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: use listEquals/setEquals/mapEquals */ ',
        );
      });
    });
  }
}

/// Warns when duplicate keys are used in a map literal.
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
class AvoidDuplicateMapKeysRule extends DartLintRule {
  const AvoidDuplicateMapKeysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_map_keys',
    problemMessage: 'Duplicate key in map literal.',
    correctionMessage: 'Remove or rename the duplicate key.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidMapKeysContainsRule extends DartLintRule {
  const AvoidMapKeysContainsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_map_keys_contains',
    problemMessage: 'Use containsKey() instead of keys.contains().',
    correctionMessage:
        'Replace map.keys.contains(key) with map.containsKey(key).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidUnnecessaryCollectionsRule extends DartLintRule {
  const AvoidUnnecessaryCollectionsRule() : super(code: _code);

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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
/// ```
class AvoidUnsafeCollectionMethodsRule extends DartLintRule {
  const AvoidUnsafeCollectionMethodsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_collection_methods',
    problemMessage:
        'Using .first or .last on a potentially empty collection is unsafe.',
    correctionMessage: 'Use .firstOrNull/.lastOrNull or check isEmpty first.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _unsafeMethods = <String>{'first', 'last', 'single'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackCommentForUnsafeCollectionFix()];
}

class _AddHackCommentForUnsafeCollectionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Handle PropertyAccess nodes
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      _addHackComment(reporter, node, node.propertyName.name);
    });

    // Handle PrefixedIdentifier nodes
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      _addHackComment(reporter, node, node.identifier.name);
    });
  }

  void _addHackComment(ChangeReporter reporter, AstNode node, String method) {
    final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
      message: 'Add HACK comment for unsafe .$method',
      priority: 2,
    );

    changeBuilder.addDartFileEdit((builder) {
      builder.addSimpleInsertion(
        node.offset,
        '/* HACK: check empty before .$method */ ',
      );
    });
  }
}

/// Warns when reduce() is called on a potentially empty collection.
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
class AvoidUnsafeReduceRule extends DartLintRule {
  const AvoidUnsafeReduceRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_reduce',
    problemMessage: 'reduce() throws on empty collections.',
    correctionMessage:
        'Use fold() with an initial value or check isEmpty first.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        message: 'Add HACK comment for unsafe reduce',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: use fold() or check empty */ ',
        );
      });
    });
  }
}

/// Warns when map literal keys are not in alphabetical order.
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
class MapKeysOrderingRule extends DartLintRule {
  const MapKeysOrderingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'map_keys_ordering',
    problemMessage: 'Map keys should be in alphabetical order.',
    correctionMessage: 'Reorder the map entries alphabetically by key.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
/// Example of **bad** code:
/// ```dart
/// if (list.indexOf(item) != -1) { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (list.contains(item)) { ... }
/// ```
class PreferContainsRule extends DartLintRule {
  const PreferContainsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_contains',
    problemMessage: 'Use contains() instead of indexOf() for presence checks.',
    correctionMessage: 'Replace indexOf() comparison with contains().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferFirstRule extends DartLintRule {
  const PreferFirstRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_first',
    problemMessage: 'Use .first instead of [0].',
    correctionMessage: 'Replace [0] with .first or .firstOrNull.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferIterableOfRule extends DartLintRule {
  const PreferIterableOfRule() : super(code: _code);

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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
/// Example of **bad** code:
/// ```dart
/// final last = list[list.length - 1];
/// ```
///
/// Example of **good** code:
/// ```dart
/// final last = list.last;
/// ```
class PreferLastRule extends DartLintRule {
  const PreferLastRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_last',
    problemMessage: 'Use .last instead of [length - 1].',
    correctionMessage: 'Replace list[list.length - 1] with list.last.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferAddAllRule extends DartLintRule {
  const PreferAddAllRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_add_all',
    problemMessage: 'Use addAll() instead of forEach/for with add().',
    correctionMessage: 'Replace with list.addAll(items).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidDuplicateCollectionElementsRule extends DartLintRule {
  const AvoidDuplicateCollectionElementsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_collection_elements',
    problemMessage: 'Duplicate element in collection literal.',
    correctionMessage: 'Remove the duplicate element.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
    DiagnosticReporter reporter,
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
class PreferSetForLookupRule extends DartLintRule {
  const PreferSetForLookupRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_set_for_lookup',
    problemMessage:
        'Consider using Set instead of List for contains() lookups.',
    correctionMessage: 'Sets have O(1) lookup vs O(n) for Lists.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
