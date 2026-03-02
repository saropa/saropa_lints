// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import '../saropa_lint_rule.dart';
import '../fixes/code_quality/prefer_returning_conditional_expressions_fix.dart';
import '../fixes/code_quality/simplify_boolean_comparison_fix.dart';

class PreferBothInliningAnnotationsRule extends SaropaLintRule {
  PreferBothInliningAnnotationsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_both_inlining_annotations',
    '[prefer_both_inlining_annotations] Only one inlining pragma is present, but the Dart VM and dart2js compilers use different annotations. Without both vm:prefer-inline and dart2js:tryInline, the function is only inlined on one platform, leaving the other without the intended optimization. {v3}',
    correctionMessage:
        'Add the missing counterpart annotation: use @pragma(dart2js:tryInline) alongside @pragma(vm:prefer-inline), or vice versa.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void checkAnnotations(NodeList<Annotation> metadata, Token reportAt) {
      bool hasVmInline = false;
      bool hasDart2jsInline = false;

      for (final Annotation annotation in metadata) {
        if (annotation.name.name != 'pragma') continue;

        final ArgumentList? args = annotation.arguments;
        if (args == null || args.arguments.isEmpty) continue;

        final Expression firstArg = args.arguments.first;
        if (firstArg is! SimpleStringLiteral) continue;

        final String value = firstArg.value;
        if (value == 'vm:prefer-inline' || value == 'vm:never-inline') {
          hasVmInline = true;
        }
        if (value == 'dart2js:tryInline' || value == 'dart2js:noInline') {
          hasDart2jsInline = true;
        }
      }

      if (hasVmInline != hasDart2jsInline) {
        reporter.atToken(reportAt);
      }
    }

    context.addMethodDeclaration((MethodDeclaration node) {
      checkAnnotations(node.metadata, node.name);
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
      checkAnnotations(node.metadata, node.name);
    });
  }
}

/// Warns when using `MediaQuery.of(context).size` instead of dedicated methods.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: prefer_dedicated_media_query_methods
///
/// Flutter provides dedicated methods like `MediaQuery.sizeOf(context)` which
/// are more efficient and clearer.
///
/// Example of **bad** code:
/// ```dart
/// final size = MediaQuery.of(context).size;
/// final padding = MediaQuery.of(context).padding;
/// ```
///
/// Example of **good** code:
/// ```dart
/// final size = MediaQuery.sizeOf(context);
/// final padding = MediaQuery.paddingOf(context);
/// ```
class PreferDedicatedMediaQueryMethodRule extends SaropaLintRule {
  PreferDedicatedMediaQueryMethodRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_dedicated_media_query_method',
    '[prefer_dedicated_media_query_method] MediaQuery.of(context) accessed for a single property. This registers a dependency on the entire MediaQueryData object, causing the widget to rebuild whenever any media query value changes (orientation, padding, text scale), even if only one property is needed. {v6}',
    correctionMessage:
        'Use the dedicated method such as MediaQuery.sizeOf(context), MediaQuery.paddingOf(context), or MediaQuery.textScaleFactorOf(context) to depend only on the specific property.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _dedicatedProperties = <String>{
    'size',
    'padding',
    'viewInsets',
    'viewPadding',
    'orientation',
    'devicePixelRatio',
    'textScaleFactor',
    'platformBrightness',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      // Check for pattern: MediaQuery.of(context).size
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      // Check if it's MediaQuery.of(...)
      final Expression? targetTarget = target.target;
      if (targetTarget is! SimpleIdentifier) return;
      if (targetTarget.name != 'MediaQuery') return;
      if (target.methodName.name != 'of') return;

      // Check if the property is one that has a dedicated method
      final String propertyName = node.propertyName.name;
      if (_dedicatedProperties.contains(propertyName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when enum values are found using firstWhere instead of byName.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// MyEnum.values.firstWhere((e) => e.name == 'value');
/// ```
///
/// Example of **good** code:
/// ```dart
/// MyEnum.values.byName('value');
/// ```
class PreferEnumsByNameRule extends SaropaLintRule {
  PreferEnumsByNameRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_enums_by_name',
    '[prefer_enums_by_name] Enum lookup uses firstWhere with name comparison instead of the built-in byName() method. The manual approach is more verbose, less readable, and throws a generic StateError on mismatch instead of the descriptive ArgumentError that byName() provides. {v5}',
    correctionMessage:
        'Replace .firstWhere((e) => e.name == x) with .byName(x) for cleaner code and a more descriptive error message on lookup failure.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'firstWhere') return;

      // Check if target is .values
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;
      if (target.propertyName.name != 'values') return;

      // Check if the argument is a function that compares .name
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is FunctionExpression) {
        final FunctionBody body = firstArg.body;
        if (body is ExpressionFunctionBody) {
          final Expression expr = body.expression;
          // Check for pattern: e.name == 'something' or 'something' == e.name
          if (expr is BinaryExpression &&
              expr.operator.type == TokenType.EQ_EQ) {
            final bool isNameComparison =
                _isNameAccess(expr.leftOperand) ||
                _isNameAccess(expr.rightOperand);
            if (isNameComparison) {
              reporter.atNode(node);
            }
          }
        }
      }
    });
  }

  bool _isNameAccess(Expression expr) {
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'name';
    }
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'name';
    }
    return false;
  }
}

/// Warns when inline function callbacks should be extracted.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class PreferExtractingFunctionCallbacksRule extends SaropaLintRule {
  PreferExtractingFunctionCallbacksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_extracting_function_callbacks',
    '[prefer_extracting_function_callbacks] Large inline callback detected spanning 10+ lines. Inline callbacks make code harder to read, test in isolation, and reuse across multiple call sites, reducing code maintainability and increasing complexity. {v4}',
    correctionMessage:
        'Extract this callback to a separate named method or private function. This enables unit testing the logic independently, improves readability by giving the behavior a descriptive name, and allows reuse.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _maxCallbackLines = 10;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
      // Skip if not used as an argument
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression && parent is! ArgumentList) return;

      // Check function body size
      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      final CompilationUnit unit = node.root as CompilationUnit;
      final int startLine = unit.lineInfo.getLocation(body.offset).lineNumber;
      final int endLine = unit.lineInfo.getLocation(body.end).lineNumber;
      final int lineCount = endLine - startLine + 1;

      if (lineCount > _maxCallbackLines) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when spreading a nullable collection without null-aware spread.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final list = [...?nullableList ?? []];
/// final combined = items != null ? [...items] : [];
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [...?nullableList];
/// final combined = [...?items];
/// ```
class PreferNullAwareSpreadRule extends SaropaLintRule {
  PreferNullAwareSpreadRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_null_aware_spread',
    '[prefer_null_aware_spread] Nullable collection spread without null-aware operator. Spreading a nullable list or set without ...? throws a runtime TypeError when the value is null, crashing the collection literal construction instead of gracefully contributing zero elements. {v4}',
    correctionMessage:
        'Replace ...nullableCollection with ...?nullableCollection so that null values are treated as empty and contribute no elements to the result.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSpreadElement((SpreadElement node) {
      // Check for ...?(x ?? []) pattern
      final Expression expr = node.expression;
      if (node.isNullAware && expr is BinaryExpression) {
        if (expr.operator.lexeme == '??') {
          final Expression right = expr.rightOperand;
          if (right is ListLiteral && right.elements.isEmpty) {
            reporter.atNode(node);
          }
        }
      }
    });

    // Check for ternary patterns like: items != null ? [...items] : []
    context.addConditionalExpression((ConditionalExpression node) {
      final Expression condition = node.condition;
      final Expression thenExpr = node.thenExpression;
      final Expression elseExpr = node.elseExpression;

      // Check for x != null ? [...x] : [] pattern
      if (condition is BinaryExpression &&
          condition.operator.lexeme == '!=' &&
          condition.rightOperand is NullLiteral) {
        if (thenExpr is ListLiteral &&
            thenExpr.elements.length == 1 &&
            elseExpr is ListLiteral &&
            elseExpr.elements.isEmpty) {
          final CollectionElement firstElement = thenExpr.elements.first;
          if (firstElement is SpreadElement && !firstElement.isNullAware) {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when @visibleForTesting should be used on members.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Test-only members should be annotated.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Foo {
///   // Used only in tests but not annotated
///   void testHelper() { }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Foo {
///   @visibleForTesting
///   void testHelper() { }
/// }
/// ```
class PreferVisibleForTestingOnMembersRule extends SaropaLintRule {
  PreferVisibleForTestingOnMembersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_visible_for_testing_on_members',
    '[prefer_visible_for_testing_on_members] Member exposed solely for testing lacks the @visibleForTesting annotation. Without the annotation, the analyzer cannot warn when production code accidentally calls the test-only member, breaking the intended encapsulation boundary. {v4}',
    correctionMessage:
        'Add the @visibleForTesting annotation from package:meta so the analyzer flags any non-test usage of this member as a warning.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _testIndicators = <String>{
    'test',
    'Test',
    'mock',
    'Mock',
    'fake',
    'Fake',
    'stub',
    'Stub',
    'spy',
    'Spy',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip test files
    if (context.filePath.contains('_test.dart') ||
        context.filePath.contains('/test/') ||
        context.filePath.contains('\\test\\')) {
      return;
    }

    void checkMember(Token nameToken, NodeList<Annotation> metadata) {
      final String name = nameToken.lexeme;

      // Check if name suggests it's for testing
      bool suggestsTest = false;
      for (final String indicator in _testIndicators) {
        if (name.contains(indicator)) {
          suggestsTest = true;
          break;
        }
      }

      if (!suggestsTest) return;

      // Check if already has @visibleForTesting
      for (final Annotation annotation in metadata) {
        if (annotation.name.name == 'visibleForTesting') return;
      }

      reporter.atToken(nameToken);
    }

    context.addMethodDeclaration((MethodDeclaration node) {
      checkMember(node.name, node.metadata);
    });

    context.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        checkMember(variable.name, node.metadata);
      }
    });
  }
}

/// Warns when a named parameter is passed as null explicitly.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// void foo({String? name}) { }
/// foo(name: null);  // Explicitly passing null
/// ```
///
/// Example of **good** code:
/// ```dart
/// void foo({String? name}) { }
/// foo();  // Omit the parameter instead of passing null
/// ```
class PreferAnyOrEveryRule extends SaropaLintRule {
  PreferAnyOrEveryRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_any_or_every',
    '[prefer_any_or_every] Collection filtered with where() only to check isEmpty/isNotEmpty. The where() call creates an intermediate lazy iterable and allocates a closure, while any() and every() short-circuit on the first matching element without creating intermediate objects. {v5}',
    correctionMessage:
        'Replace where(predicate).isEmpty with !any(predicate), and where(predicate).isNotEmpty with any(predicate) for clearer intent and better performance.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;
      if (propertyName != 'isEmpty' && propertyName != 'isNotEmpty') return;

      final Expression? target = node.target;
      if (target is MethodInvocation && target.methodName.name == 'where') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when index-based for loop can be replaced with for-in.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Example of **bad** code:
/// ```dart
/// for (var i = 0; i < list.length; i++) {
///   print(list[i]);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// for (final item in list) {
///   print(item);
/// }
/// ```
class PreferForInRule extends SaropaLintRule {
  PreferForInRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_for_in',
    '[prefer_for_in] Using for-in loops instead of index-based for loops is a stylistic preference. Both have equivalent performance for most Dart collections. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Replace the index-based loop with a for-in loop (for (final item in list)) to iterate directly over elements without managing an index variable.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is! ForPartsWithDeclarations) return;

      final NodeList<VariableDeclaration> variables = parts.variables.variables;
      if (variables.length != 1) return;

      final VariableDeclaration indexVar = variables.first;
      final Expression? initializer = indexVar.initializer;
      if (initializer is! IntegerLiteral || initializer.value != 0) return;

      final String indexName = indexVar.name.lexeme;

      final Expression? condition = parts.condition;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.LT) return;

      final NodeList<Expression> updaters = parts.updaters;
      if (updaters.length != 1) return;

      final Expression updater = updaters.first;
      bool isSimpleIncrement = false;
      if (updater is PostfixExpression &&
          updater.operand is SimpleIdentifier &&
          (updater.operand as SimpleIdentifier).name == indexName) {
        isSimpleIncrement = true;
      }
      if (updater is PrefixExpression &&
          updater.operand is SimpleIdentifier &&
          (updater.operand as SimpleIdentifier).name == indexName) {
        isSimpleIncrement = true;
      }

      if (isSimpleIncrement) {
        reporter.atToken(node.forKeyword, code);
      }
    });
  }
}

/// Warns when duplicate patterns appear in pattern matching.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case (int x, int y) when x > 0:
///   case (int x, int y) when x > 0:  // Duplicate pattern
/// }
/// ```
class PreferBytesBuilderRule extends SaropaLintRule {
  PreferBytesBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'prefer_bytes_builder',
    '[prefer_bytes_builder] List<int> with repeated addAll operations detected. Each addAll call may trigger memory reallocation and copying, causing O(n²) performance when building large byte arrays, resulting in slow processing and excessive memory churn. {v5}',
    correctionMessage:
        'Replace with BytesBuilder which preallocates memory efficiently and avoids repeated copying. Use BytesBuilder.add() or addByte() to accumulate bytes, then call toBytes() once at the end for O(n) performance.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'addAll') return;

      final Expression? target = node.target;
      if (target == null) return;

      final DartType? targetType = target.staticType;
      if (targetType == null) return;

      final String typeName = targetType.getDisplayString();
      if (typeName == 'List<int>' || typeName == 'Uint8List') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a ternary expression can be pushed into arguments.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Example of **bad** code:
/// ```dart
/// condition ? foo(1, 2) : foo(1, 3);
/// ```
///
/// Example of **good** code:
/// ```dart
/// foo(1, condition ? 2 : 3);
/// ```
class PreferPushingConditionalExpressionsRule extends SaropaLintRule {
  PreferPushingConditionalExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_pushing_conditional_expressions',
    '[prefer_pushing_conditional_expressions] Moving conditional logic into return expressions is a code shape preference. No performance or correctness difference between forms. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Move the conditional expression inside the single differing argument so the constructor or function call appears once with all shared arguments visible.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConditionalExpression((ConditionalExpression node) {
      final Expression thenExpr = node.thenExpression;
      final Expression elseExpr = node.elseExpression;

      // Check if both branches are method calls to the same method
      if (thenExpr is MethodInvocation && elseExpr is MethodInvocation) {
        if (thenExpr.methodName.name == elseExpr.methodName.name) {
          final String? thenTarget = thenExpr.target?.toSource();
          final String? elseTarget = elseExpr.target?.toSource();

          if (thenTarget == elseTarget) {
            // Check if only one argument differs
            final List<Expression> thenArgs = thenExpr.argumentList.arguments
                .toList();
            final List<Expression> elseArgs = elseExpr.argumentList.arguments
                .toList();

            if (thenArgs.length == elseArgs.length && thenArgs.length >= 2) {
              int diffCount = 0;
              for (int i = 0; i < thenArgs.length; i++) {
                if (thenArgs[i].toSource() != elseArgs[i].toSource()) {
                  diffCount++;
                }
              }
              if (diffCount == 1) {
                reporter.atNode(node);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when `.new` constructor shorthand can be used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final items = list.map((e) => Item(e));
/// ```
///
/// Example of **good** code:
/// ```dart
/// final items = list.map(Item.new);
/// ```
class PreferShorthandsWithConstructorsRule extends SaropaLintRule {
  PreferShorthandsWithConstructorsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_shorthands_with_constructors',
    '[prefer_shorthands_with_constructors] Lambda wraps a constructor call without adding any logic (e.g. (x) => MyClass(x)). The closure allocates an extra function object on each evaluation and obscures the simple delegation, making the code harder to read at a glance. {v4}',
    correctionMessage:
        'Replace the lambda with a constructor tear-off (ClassName.new) to eliminate the wrapper function and communicate the delegation intent directly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
      final FunctionBody body = node.body;

      Expression? bodyExpr;
      if (body is ExpressionFunctionBody) {
        bodyExpr = body.expression;
      } else if (body is BlockFunctionBody) {
        final NodeList<Statement> statements = body.block.statements;
        if (statements.length == 1 && statements.first is ReturnStatement) {
          bodyExpr = (statements.first as ReturnStatement).expression;
        }
      }

      if (bodyExpr is! InstanceCreationExpression) return;

      final FormalParameterList? paramList = node.parameters;
      if (paramList == null) return;

      final List<FormalParameter> params = paramList.parameters.toList();
      if (params.length != 1) return;

      final String paramName = params.first.name?.lexeme ?? '';

      final ArgumentList args = bodyExpr.argumentList;
      if (args.arguments.length != 1) return;

      final Expression arg = args.arguments.first;
      if (arg is SimpleIdentifier && arg.name == paramName) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when enum shorthand can be used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final status = Status.values.where((e) => e == Status.active);
/// ```
class PreferShorthandsWithEnumsRule extends SaropaLintRule {
  PreferShorthandsWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_shorthands_with_enums',
    '[prefer_shorthands_with_enums] Enum accessed using verbose qualification (EnumType.enumValue) where shorthand (.enumValue) is available. This adds unnecessary repetition, makes code harder to read, and increases the chance of errors when refactoring enum names. {v4}',
    correctionMessage:
        'Use the shorthand enum syntax by omitting the enum type prefix. Within contexts that accept the enum type, write .enumValue instead of EnumType.enumValue for cleaner, more maintainable code.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for patterns like EnumType.values.where/firstWhere
      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      if (target.propertyName.name != 'values') return;

      final Expression? enumType = target.target;
      if (enumType == null) return;

      final DartType? type = enumType.staticType;
      if (type == null) return;

      // Check if it's an enum type access
      final Element? element = type.element;
      if (element is EnumElement) {
        final String methodName = node.methodName.name;
        if (methodName == 'where' ||
            methodName == 'firstWhere' ||
            methodName == 'singleWhere') {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when static field shorthand can be used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final color = Colors.values.firstWhere((c) => c == Colors.red);
/// ```
class PreferShorthandsWithStaticFieldsRule extends SaropaLintRule {
  PreferShorthandsWithStaticFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_shorthands_with_static_fields',
    '[prefer_shorthands_with_static_fields] Static field accessed through unnecessary collection search (firstWhere, where) when direct access is available. This wastes CPU cycles iterating through values and makes code less efficient and harder to understand. {v4}',
    correctionMessage:
        'Replace the collection search with direct static field access (e.g., Colors.red instead of Colors.values.firstWhere((c) => c == Colors.red)). Direct access is instant, clearer, and cannot fail.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'firstWhere' &&
          node.methodName.name != 'singleWhere') {
        return;
      }

      final Expression? target = node.target;
      if (target is! PropertyAccess) return;

      // Check for Class.staticList.firstWhere pattern
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! FunctionExpression) return;

      final FunctionBody body = firstArg.body;
      if (body is! ExpressionFunctionBody) return;

      final Expression bodyExpr = body.expression;
      if (bodyExpr is BinaryExpression &&
          bodyExpr.operator.type == TokenType.EQ_EQ) {
        // Check if comparing against a static field
        final Expression right = bodyExpr.rightOperand;
        if (right is PrefixedIdentifier || right is PropertyAccess) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when a parameter type doesn't match the accepted type annotation.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// void process(@Accept(String) int value) {} // Type mismatch
/// ```
class PassCorrectAcceptedTypeRule extends SaropaLintRule {
  PassCorrectAcceptedTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'pass_correct_accepted_type',
    '[pass_correct_accepted_type] Argument type does not match the parameter type declared by the @Accept annotation. Passing an incompatible type circumvents the annotation contract, which may cause runtime cast failures or incorrect behavior in the called function. {v4}',
    correctionMessage:
        'Change the argument to match the type declared in the @Accept annotation, or update the annotation if the accepted type has intentionally changed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFormalParameter((FormalParameter node) {
      // Check for Accept-style annotations
      for (final Annotation annotation in node.metadata) {
        final String annotationName = annotation.name.name;
        if (annotationName == 'Accept' || annotationName == 'AcceptType') {
          final ArgumentList? args = annotation.arguments;
          if (args != null && args.arguments.isNotEmpty) {
            final Expression firstArg = args.arguments.first;
            if (firstArg is TypeLiteral) {
              // Get expected type from annotation
              final String expectedTypeName = firstArg.type.toSource();

              // Get actual parameter type
              final TypeAnnotation? paramType = node is SimpleFormalParameter
                  ? node.type
                  : null;

              if (paramType != null) {
                final String actualTypeName = paramType.toSource();
                if (actualTypeName != expectedTypeName &&
                    !actualTypeName.contains(expectedTypeName)) {
                  reporter.atNode(node);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when an optional argument is not passed but could improve clarity.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Detects method calls that are missing commonly-used optional boolean
/// arguments like `verbose`, `recursive`, `force`, etc.
///
/// Example of **bad** code:
/// ```dart
/// void process(String name, {bool verbose}) {}
/// process('test'); // Missing optional verbose arg
/// ```
class PassOptionalArgumentRule extends SaropaLintRule {
  PassOptionalArgumentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'pass_optional_argument',
    '[pass_optional_argument] Function call omits important optional parameter, relying on default value. Future readers must hunt for the function definition to understand the omitted behavior, making code harder to comprehend and maintain at the call site. {v4}',
    correctionMessage:
        'Explicitly pass the optional parameter with its intended value, even if it matches the default. This documents your intent at the call site and prevents confusion if the default changes, improving code clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  // Common boolean parameter names that should be passed explicitly
  static const Set<String> _importantBoolParams = <String>{
    'verbose',
    'recursive',
    'force',
    'isRequired',
    'shouldValidate',
    'hasHeader',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      // Find functions that have important optional boolean parameters
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final Set<String> optionalBoolParams = <String>{};
      for (final FormalParameter param in params.parameters) {
        if (param.isNamed || param.isOptional) {
          final String? name = param.name?.lexeme;
          if (name != null && _importantBoolParams.contains(name)) {
            optionalBoolParams.add(name);
          }
        }
      }

      if (optionalBoolParams.isEmpty) return;

      // Store for later checking of call sites
      // This rule checks at declaration site for documentation purposes
      // A more complete implementation would track call sites
    });
  }
}

/// Warns when a file contains multiple top-level declarations.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// // my_file.dart
/// class Foo {}
/// class Bar {} // Should be in separate file
/// ```
class PreferSingleDeclarationPerFileRule extends SaropaLintRule {
  PreferSingleDeclarationPerFileRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_single_declaration_per_file',
    '[prefer_single_declaration_per_file] File contains multiple top-level class, enum, or extension declarations. Combining unrelated declarations in one file makes it harder to locate definitions, increases merge conflicts when multiple developers edit the same file, and breaks the convention of one-declaration-per-file. {v3}',
    correctionMessage:
        'Split each top-level declaration into its own file, named after the declaration (e.g. my_class.dart for MyClass), to improve discoverability and reduce merge conflicts.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      // Count significant top-level declarations
      int classCount = 0;
      int enumCount = 0;
      int mixinCount = 0;
      ClassDeclaration? secondClass;

      for (final CompilationUnitMember member in node.declarations) {
        if (member is ClassDeclaration) {
          classCount++;
          if (classCount == 2) {
            secondClass = member;
          }
        } else if (member is EnumDeclaration) {
          enumCount++;
        } else if (member is MixinDeclaration) {
          mixinCount++;
        }
      }

      // Report if there are multiple major declarations
      final int majorDeclarations = classCount + enumCount + mixinCount;
      if (majorDeclarations > 1 && secondClass != null) {
        // Skip if it looks like a private helper class
        if (secondClass.name.lexeme.startsWith('_')) return;

        // Skip if all classes are abstract final with only static members
        // (pure constant / utility namespaces co-located for discoverability)
        if (enumCount == 0 &&
            mixinCount == 0 &&
            _allClassesAreStaticNamespaces(node)) {
          return;
        }

        reporter.atNode(secondClass);
      }
    });
  }

  /// Returns true when every [ClassDeclaration] in [unit] is `abstract final`
  /// with only `static` members (pure constant / utility namespaces).
  ///
  /// See also: `_isUtilityNamespaceFile` in `structure_rules.dart` which
  /// performs the same check (kept separate to avoid cross-file imports).
  static bool _allClassesAreStaticNamespaces(CompilationUnit unit) {
    final Iterable<ClassDeclaration> classes = unit.declarations
        .whereType<ClassDeclaration>();
    if (classes.isEmpty) return false;

    for (final ClassDeclaration cls in classes) {
      if (cls.abstractKeyword == null || cls.finalKeyword == null) {
        return false;
      }
      for (final ClassMember member in cls.members) {
        if (member is FieldDeclaration && !member.isStatic) return false;
        if (member is MethodDeclaration && !member.isStatic) return false;
      }
    }
    return true;
  }
}

/// Warns when a switch statement could be converted to a switch expression.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// String result;
/// switch (value) {
///   case 1: result = 'one'; break;
///   case 2: result = 'two'; break;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final result = switch (value) {
///   1 => 'one',
///   2 => 'two',
/// };
/// ```
class PreferTestMatchersRule extends SaropaLintRule {
  PreferTestMatchersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_test_matchers',
    '[prefer_test_matchers] Generic expect(value, equals(x)) or expect(value, isTrue) used where a more specific matcher exists. Specific matchers produce clearer failure messages that show the actual vs expected difference, reducing debugging time when tests fail. {v4}',
    correctionMessage:
        'Replace with the appropriate specific matcher (e.g. expect(list, contains(x)), expect(map, containsPair(k, v)), expect(fn, throwsA(isA<MyError>()))) for better diagnostics.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only check test files
    final String path = context.filePath;
    if (!path.contains('test') && !path.endsWith('_test.dart')) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'expect') return;

      final List<Expression> args = node.argumentList.arguments.toList();
      if (args.length < 2) return;

      final Expression actual = args[0];
      final Expression matcher = args[1];

      // Check for list.length == 0 pattern
      if (actual is PropertyAccess && actual.propertyName.name == 'length') {
        if (matcher is MethodInvocation &&
            matcher.methodName.name == 'equals') {
          final List<Expression> matcherArgs = matcher.argumentList.arguments
              .toList();
          if (matcherArgs.isNotEmpty) {
            final Expression matcherArg = matcherArgs[0];
            if (matcherArg is IntegerLiteral && matcherArg.value == 0) {
              reporter.atNode(node);
              return;
            }
          }
        }
      }

      // Check for .contains() with isTrue/isFalse
      if (actual is MethodInvocation && actual.methodName.name == 'contains') {
        if (matcher is SimpleIdentifier) {
          if (matcher.name == 'isTrue' || matcher.name == 'isFalse') {
            reporter.atNode(node);
            return;
          }
        }
      }

      // Check for .isEmpty with isTrue/isFalse
      if (actual is PropertyAccess &&
          (actual.propertyName.name == 'isEmpty' ||
              actual.propertyName.name == 'isNotEmpty')) {
        if (matcher is SimpleIdentifier &&
            (matcher.name == 'isTrue' || matcher.name == 'isFalse')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when `FutureOr<T>` could be unwrapped for cleaner handling.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// FutureOr<int> getValue() => 42;
/// void process() {
///   final value = getValue();
///   if (value is Future<int>) {
///     value.then((v) => print(v));
///   } else {
///     print(value);
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> getValue() async => 42;
/// void process() async {
///   final value = await getValue();
///   print(value);
/// }
/// ```
class PreferUnwrappingFutureOrRule extends SaropaLintRule {
  PreferUnwrappingFutureOrRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_unwrapping_future_or',
    '[prefer_unwrapping_future_or] FutureOr type detected requiring manual type checking and unwrapping. This forces runtime type inspection (is Future checks) and adds branching complexity, making the code harder to understand and more error-prone. {v4}',
    correctionMessage:
        'Convert the function to async and use await to unwrap values uniformly. Async/await eliminates the need for runtime type checking, produces cleaner control flow, and ensures consistent handling of both synchronous and asynchronous values.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      // Check for pattern: if (value is Future<T>)
      final Expression condition = node.expression;
      if (condition is! IsExpression) return;

      final TypeAnnotation type = condition.type;
      if (type is! NamedType) return;

      if (type.name.lexeme == 'Future') {
        // This is checking if something is a Future, likely FutureOr handling
        final Expression target = condition.expression;
        if (target is SimpleIdentifier) {
          reporter.atNode(node);
        }
      }
    });

    // Also check for FutureOr return types that could be simplified
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'FutureOr') {
        // Check if body is simple enough to just be async
        final FunctionBody body = node.functionExpression.body;
        if (body is BlockFunctionBody) {
          // Has block body - might benefit from being async
          bool hasAwait = false;
          body.accept(_AwaitFinderVisitor((bool found) => hasAwait = found));
          if (!hasAwait) {
            reporter.atNode(returnType);
          }
        }
      }
    });
  }
}

class _AwaitFinderVisitor extends RecursiveAstVisitor<void> {
  _AwaitFinderVisitor(this.onFound);
  final void Function(bool) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(true);
  }
}

// =============================================================================
// HARD COMPLEXITY RULES
// =============================================================================

/// Warns when type arguments can be inferred and are redundant.
///
/// Since: v4.5.2 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// final list = <String>['a', 'b'];  // Type can be inferred
/// final map = Map<String, int>();   // Type can be inferred from usage
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = ['a', 'b'];  // Type inferred as List<String>
/// final map = <String, int>{};  // Explicit when needed
/// ```
///
/// Formerly: `avoid_inferrable_type_arguments`
class PreferOverridingParentEqualityRule extends SaropaLintRule {
  PreferOverridingParentEqualityRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_overriding_parent_equality',
    '[prefer_overriding_parent_equality] Subclass overrides == without incorporating the parent class equality check. If the parent class compares fields that the subclass ignores, two objects may be considered equal even though their parent fields differ, breaking the transitivity contract of ==. {v4}',
    correctionMessage:
        'Call super == other as part of the equality check, or explicitly compare all parent fields alongside the subclass fields to ensure consistent equality behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class has an == operator
      MethodDeclaration? equalityOperator;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == '==' &&
            member.isOperator) {
          equalityOperator = member;
          break;
        }
      }

      if (equalityOperator == null) return;

      // Check if parent class has == operator
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superType = extendsClause.superclass;
      final DartType? superDartType = superType.type;
      if (superDartType == null) return;

      final Element? superElement = superDartType.element;
      if (superElement is! InterfaceElement) return;

      // Check if parent has custom == (not just Object.==)
      bool parentHasCustomEquals = false;
      for (final MethodElement method in superElement.methods) {
        if (method.name == '==' && !method.isAbstract) {
          // Check if it's from Object or a custom implementation
          final enclosing = (method as Element).enclosingElement;
          final String? enclosingName = enclosing is InterfaceElement
              ? enclosing.name
              : null;
          if (enclosingName != null && enclosingName != 'Object') {
            parentHasCustomEquals = true;
            break;
          }
        }
      }

      if (!parentHasCustomEquals) return;

      // Check if the child's == calls super.==
      bool callsSuper = false;
      equalityOperator.body.visitChildren(
        _SuperEqualityChecker(() => callsSuper = true),
      );

      if (!callsSuper) {
        reporter.atToken(equalityOperator.name, code);
      }
    });
  }
}

class _SuperEqualityChecker extends RecursiveAstVisitor<void> {
  _SuperEqualityChecker(this.onSuperFound);

  final void Function() onSuperFound;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '==') {
      if (node.leftOperand is SuperExpression ||
          node.rightOperand is SuperExpression) {
        onSuperFound();
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression) {
      onSuperFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when more specific switch cases should come before general ones.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case int _: print('int');
///   case int x when x > 0: print('positive');  // Unreachable
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (value) {
///   case int x when x > 0: print('positive');
///   case int _: print('other int');
/// }
/// ```
class PreferTypedefsForCallbacksRule extends SaropaLintRule {
  PreferTypedefsForCallbacksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_typedefs_for_callbacks',
    '[prefer_typedefs_for_callbacks] Inline function type could be a typedef. Inline function types are harder to read and reuse. Suggests using typedefs for callback function types. {v2}',
    correctionMessage:
        'Create a named typedef for this callback signature and reference it by name, improving readability and allowing reuse across multiple parameters.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFormalParameterList((FormalParameterList node) {
      for (final FormalParameter param in node.parameters) {
        if (param is SimpleFormalParameter) {
          final TypeAnnotation? type = param.type;
          if (type is GenericFunctionType) {
            reporter.atNode(type);
          }
        }
      }
    });
  }
}

/// Suggests using redirecting constructors for super calls.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Redirecting constructors are cleaner than calling super directly.
///
/// **BAD:**
/// ```dart
/// class Child extends Parent {
///   Child(String name) : super(name);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Child extends Parent {
///   Child(super.name);
/// }
/// ```
class PreferRedirectingSuperclassConstructorRule extends SaropaLintRule {
  PreferRedirectingSuperclassConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_redirecting_superclass_constructor',
    '[prefer_redirecting_superclass_constructor] Constructor forwards parameters to super() without modification, which can be simplified with Dart 3 super parameters. {v2}',
    correctionMessage:
        'Replace the explicit super(paramName) call with super.paramName in the parameter list to reduce boilerplate and keep the forwarding relationship visible in the signature.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      final NodeList<ConstructorInitializer> initializers = node.initializers;
      if (initializers.isEmpty) return;

      for (final ConstructorInitializer init in initializers) {
        if (init is SuperConstructorInvocation) {
          // Check if super call has simple parameter forwarding
          final ArgumentList args = init.argumentList;
          for (final Expression arg in args.arguments) {
            if (arg is SimpleIdentifier) {
              // Check if the identifier matches a constructor parameter
              final FormalParameterList? params = node.parameters;
              if (params != null) {
                for (final FormalParameter param in params.parameters) {
                  if (param.name?.lexeme == arg.name) {
                    reporter.atNode(init);
                    return;
                  }
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when buildWhen callback is empty or always returns true.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Empty buildWhen defeats the purpose of BlocBuilder optimization.
///
/// **BAD:**
/// ```dart
/// BlocBuilder<MyBloc, MyState>(
///   buildWhen: (previous, current) => true, // Always rebuilds
///   builder: (context, state) => Text('$state'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocBuilder<MyBloc, MyState>(
///   buildWhen: (previous, current) => previous.value != current.value,
///   builder: (context, state) => Text('${state.value}'),
/// )
/// ```
class PreferUsePrefixRule extends SaropaLintRule {
  PreferUsePrefixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_use_prefix',
    '[prefer_use_prefix] Prefixing Flutter Hooks function names with use is a naming convention. The prefix does not affect hook behavior or performance. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Rename the function to start with "use" (e.g. useMyHook) following the hooks convention, so it is recognizable as a hook and subject to hook linting rules.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _hookMethods = <String>{
    'useState',
    'useEffect',
    'useMemoized',
    'useCallback',
    'useRef',
    'useContext',
    'useValueListenable',
    'useAnimation',
    'useAnimationController',
    'useFuture',
    'useStream',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final String name = node.name.lexeme;

      // Skip if already has hook prefix (use + PascalCase)
      if (_isHookFunction(name)) return;

      // Check if body calls hook methods
      bool usesHooks = false;
      node.functionExpression.body.visitChildren(
        _HookCallVisitor(
          hookMethods: _hookMethods,
          onHookFound: () => usesHooks = true,
        ),
      );

      if (usesHooks) {
        reporter.atNode(node);
      }
    });
  }
}

class _HookCallVisitor extends RecursiveAstVisitor<void> {
  _HookCallVisitor({required this.hookMethods, required this.onHookFound});

  final Set<String> hookMethods;
  final void Function() onHookFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    // Check known hooks or any use + PascalCase pattern
    if (hookMethods.contains(methodName) || _isHookFunction(methodName)) {
      onHookFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Checks if a method name follows the Flutter hooks naming convention.
///
/// Flutter hooks use the pattern `use` + PascalCase identifier:
/// - `useState`, `useEffect`, `useCallback` ✓
/// - `userDOB`, `usefulHelper`, `username` ✗
bool _isHookFunction(String name) {
  // Must start with 'use' and have at least one more character
  if (!name.startsWith('use')) return false;
  if (name.length < 4) return false;

  // The character after 'use' must be uppercase (PascalCase convention)
  // This distinguishes useState from userDOB
  final charAfterUse = name[3];
  return charAfterUse == charAfterUse.toUpperCase() &&
      charAfterUse != charAfterUse.toLowerCase();
}

/// Warns when enum value could use Dart 3 dot shorthand.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Dart 3 allows `.value` syntax when enum type can be inferred.
/// This makes code more concise without losing clarity.
///
/// **BAD:**
/// ```dart
/// TextAlign align = TextAlign.center;
/// ```
///
/// **GOOD:**
/// ```dart
/// TextAlign align = .center;
/// ```
///
/// **Note:** This is a stylistic preference. Some teams prefer explicit
/// enum names for clarity.
class PreferDotShorthandRule extends SaropaLintRule {
  PreferDotShorthandRule() : super(code: _code);

  /// Code style preference.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_dot_shorthand',
    '[prefer_dot_shorthand] Fully qualified enum reference detected where the type is already known from context. Use dot shorthand (.value) available in Dart 3 to reduce verbosity while preserving type safety. {v2}',
    correctionMessage:
        'Replace the fully qualified EnumType.value with .value where the type is already known from context, reducing verbosity while keeping the code type-safe.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((node) {
      // Check if prefix is an enum type accessing a value
      final prefix = node.prefix;

      // Get the static type of the prefix
      final prefixType = prefix.staticType;
      if (prefixType == null) {
        return;
      }

      // Check if it's an enum
      final element = prefixType.element;
      if (element is! EnumElement) {
        return;
      }

      // Check if this is in an assignment or argument where type is known
      final parent = node.parent;
      if (parent is VariableDeclaration) {
        final declaredType = parent.parent;
        if (declaredType is VariableDeclarationList &&
            declaredType.type != null) {
          // Type is explicit, shorthand could be used
          reporter.atNode(node);
        }
      } else if (parent is NamedExpression) {
        // In named parameter, type is known from function signature
        reporter.atNode(node);
      } else if (parent is AssignmentExpression &&
          parent.rightHandSide == node) {
        // Assignment to typed variable
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - Core Code Quality Rules
// =============================================================================

/// Warns when comparing boolean expressions to boolean literals.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v3
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: boolean_literal_compare, unnecessary_bool_compare, redundant_bool_literal
///
/// Comparing a boolean expression to `true` or `false` is redundant and
/// makes code harder to read. Use the expression directly or negate it.
///
/// **BAD:**
/// ```dart
/// if (isEnabled == true) { }
/// if (isEnabled == false) { }
/// if (true == isEnabled) { }
/// if (isEnabled != false) { }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (isEnabled) { }
/// if (!isEnabled) { }
/// ```
///
/// **Quick fix available:** Simplifies to direct boolean expression.
class NoBooleanLiteralCompareRule extends SaropaLintRule {
  NoBooleanLiteralCompareRule() : super(code: _code);

  /// Code style improvement.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_boolean_literal_compare',
    '[no_boolean_literal_compare] Comparing a boolean to true/false literally (x == true) instead of using the value directly (x) is a stylistic choice with no correctness or performance impact. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Use the boolean expression directly: write x instead of x == true, and !x instead of x == false.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Only check == and != operators
      final operatorType = node.operator.type;
      if (operatorType != TokenType.EQ_EQ &&
          operatorType != TokenType.BANG_EQ) {
        return;
      }

      final left = node.leftOperand;
      final right = node.rightOperand;

      // Check if either operand is a boolean literal
      final leftIsBoolLiteral = left is BooleanLiteral;
      final rightIsBoolLiteral = right is BooleanLiteral;

      if (!leftIsBoolLiteral && !rightIsBoolLiteral) {
        return;
      }

      // Check if the other operand is a boolean type (to avoid false positives
      // on nullable booleans where == true is intentional)
      final Expression otherOperand = leftIsBoolLiteral ? right : left;
      final otherType = otherOperand.staticType;

      // Only flag if the other operand is non-nullable bool
      if (otherType != null && otherType.isDartCoreBool) {
        // Check nullability - allow == true/false for nullable bools
        if (otherType.nullabilitySuffix == NullabilitySuffix.none) {
          reporter.atNode(node);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        SimplifyBooleanComparisonFix(context: context),
  ];
}

/// Quick fix: Simplifies boolean literal comparisons.

// =============================================================================
// prefer_returning_conditional_expressions
// =============================================================================

/// Return conditional expressions directly instead of if/else blocks.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// When an if/else block simply returns different values, use a ternary
/// expression or direct return for cleaner, more readable code.
///
/// **BAD:**
/// ```dart
/// if (condition) {
///   return true;
/// } else {
///   return false;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// return condition;
/// // or
/// return condition ? valueA : valueB;
/// ```
///
/// **Quick fix available:** Transforms if/else to ternary expression.
class PreferReturningConditionalExpressionsRule extends SaropaLintRule {
  PreferReturningConditionalExpressionsRule() : super(code: _code);

  /// Code quality improvement. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferReturningConditionalExpressionsFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_returning_conditional_expressions',
    '[prefer_returning_conditional_expressions] Returning a ternary expression instead of if-else is a stylistic preference. Both compile to the same code with no performance difference. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Collapse to return condition ? valueA : valueB; for value returns, or return condition; when directly returning a boolean expression.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      // Must have else branch
      final Statement? elseStatement = node.elseStatement;
      if (elseStatement == null) return;

      // Check if then branch is single return
      final Statement thenStatement = node.thenStatement;
      final ReturnStatement? thenReturn = _getSingleReturn(thenStatement);
      if (thenReturn == null) return;

      // Check if else branch is single return (not else-if)
      if (elseStatement is IfStatement) return;
      final ReturnStatement? elseReturn = _getSingleReturn(elseStatement);
      if (elseReturn == null) return;

      // Both branches are single returns - report
      reporter.atNode(node);
    });
  }

  /// Extract single return statement from a block or bare statement.
  ReturnStatement? _getSingleReturn(Statement statement) {
    if (statement is ReturnStatement) return statement;
    if (statement is Block) {
      final statements = statement.statements;
      if (statements.length == 1 && statements.first is ReturnStatement) {
        return statements.first as ReturnStatement;
      }
    }
    return null;
  }
}

// =============================================================================
// Missing Interpolation Rules
// =============================================================================

/// Warns when string concatenation with + is used where string interpolation
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// would be clearer.
///
/// String interpolation is more readable, less error-prone, and performs
/// better than concatenation with the + operator. Concatenation also makes
/// it easy to forget spaces between segments.
///
/// **BAD:**
/// ```dart
/// final greeting = 'Hello, ' + name + '!';
/// final path = baseUrl + '/api/' + endpoint;
/// ```
///
/// **GOOD:**
/// ```dart
/// final greeting = 'Hello, $name!';
/// final path = '$baseUrl/api/$endpoint';
/// ```
class PreferNamedBoolParamsRule extends SaropaLintRule {
  PreferNamedBoolParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_named_bool_params',
    '[prefer_named_bool_params] Prefer named parameter for boolean parameters.',
    correctionMessage:
        'Convert to a named parameter (e.g. {required bool visible}).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFormalParameterList((FormalParameterList node) {
      if (node.parameters.length > 3) return;
      final parent = node.parent;
      if (parent is MethodDeclaration) {
        if (parent.isOperator || parent.isSetter) return;
        if (parent.metadata.any((a) => a.name.name == 'override')) return;
      } else if (parent is FunctionExpression) {
        return;
      }
      for (final FormalParameter p in node.parameters) {
        if (p is DefaultFormalParameter) {
          if (p.parameter is! SimpleFormalParameter) continue;
          if ((p.parameter as SimpleFormalParameter).isNamed) continue;
          final sp = p.parameter as SimpleFormalParameter;
          if (_isBoolType(sp)) reporter.atNode(p);
        } else if (p is SimpleFormalParameter) {
          if (p.isNamed) continue;
          if (_isBoolType(p)) reporter.atNode(p);
        }
      }
    });
  }

  bool _isBoolType(SimpleFormalParameter p) {
    final TypeAnnotation? type = p.type;
    if (type is! NamedType) return false;
    return type.name.lexeme == 'bool' || type.name.lexeme == 'bool?';
  }
}

// =============================================================================
// banned_usage
// =============================================================================

/// Warns when a configured identifier is used.
///
/// Configurable rule to ban specific APIs, classes, or patterns. With no
/// configuration the rule is a no-op. Configure in `analysis_options_custom.yaml`:
/// ```yaml
/// banned_usage:
///   entries:
///     - identifier: 'print'
///       reason: 'Use Logger.debug() instead'
/// ```
///
/// **BAD (when print is banned):**
/// ```dart
/// void logUserAction(String action) {
///   print('User did: $action');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void logUserAction(String action) {
///   Logger.d('User did: $action');
/// }
/// ```
