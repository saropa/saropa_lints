// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, todo, fixme

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC / OPINIONATED RULES
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences where there is no objectively "correct" answer. Teams can
// enable them individually based on their coding conventions.
//
// Some rules have valid opposing alternatives (e.g., prefer_relative_imports
// vs prefer_absolute_imports).
// ============================================================================

/// Warns when absolute imports are used instead of relative imports.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of relative imports:**
/// - Shorter import paths
/// - Easier refactoring when moving directories
/// - Clear indication of local dependencies
///
/// **Cons (why some teams prefer absolute):**
/// - Absolute paths are more explicit
/// - Easier to understand file location at a glance
/// - IDEs may auto-generate absolute imports
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// import 'package:my_app/src/utils/helpers.dart';
/// ```
///
/// #### GOOD:
/// ```dart
/// import '../utils/helpers.dart';
/// ```
class PreferRelativeImportsRule extends SaropaLintRule {
  const PreferRelativeImportsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_relative_imports',
    problemMessage: 'Use relative imports instead of absolute package imports.',
    correctionMessage:
        'Consider using a relative import path for files within the same package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      final StringLiteral uri = node.uri;
      if (uri is! SimpleStringLiteral) return;

      final String importPath = uri.value;

      // Only check package imports
      if (!importPath.startsWith('package:')) return;

      // Extract the package name from the import
      final int firstSlash = importPath.indexOf('/');
      if (firstSlash == -1) return;
      final String importPackage = importPath.substring(8, firstSlash);

      // Get the current file's package from the source path
      final String currentPath = resolver.source.fullName.replaceAll('\\', '/');

      // Extract package name from current path (e.g., /packages/my_app/lib/...)
      final RegExp packagePattern = RegExp(r'/([^/]+)/lib/');
      final RegExpMatch? match = packagePattern.firstMatch(currentPath);
      if (match == null) return;

      final String currentPackage = match.group(1) ?? '';

      // Only flag if importing from the SAME package
      if (importPackage == currentPackage) {
        reporter.atNode(uri, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToRelativeImportFix()];
}

class _ConvertToRelativeImportFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final StringLiteral uri = node.uri;
      if (uri is! SimpleStringLiteral) return;

      final String importPath = uri.value;
      if (!importPath.startsWith('package:')) return;

      // Extract the path after package:package_name/
      final int firstSlash = importPath.indexOf('/');
      if (firstSlash == -1) return;
      final String importedFilePath = importPath.substring(firstSlash + 1);

      // Get the current file's path relative to lib/
      final String currentPath =
          resolver.source.fullName.replaceAll('\\', '/');
      final RegExp libPattern = RegExp(r'/lib/(.*)$');
      final RegExpMatch? match = libPattern.firstMatch(currentPath);
      if (match == null) return;

      final String currentFilePath = match.group(1) ?? '';
      final String currentDir =
          currentFilePath.contains('/')
              ? currentFilePath.substring(0, currentFilePath.lastIndexOf('/'))
              : '';

      // Calculate relative path
      final String relativePath = _calculateRelativePath(
        currentDir,
        importedFilePath,
      );

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to relative import',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(uri.sourceRange, "'$relativePath'");
      });
    });
  }

  String _calculateRelativePath(String fromDir, String toPath) {
    final List<String> fromParts =
        fromDir.isEmpty ? <String>[] : fromDir.split('/');
    final List<String> toParts = toPath.split('/');

    // Find common prefix length
    int commonLength = 0;
    while (commonLength < fromParts.length &&
        commonLength < toParts.length - 1 &&
        fromParts[commonLength] == toParts[commonLength]) {
      commonLength++;
    }

    // Build relative path
    final int upCount = fromParts.length - commonLength;
    final List<String> relativeParts = <String>[];

    // Add "../" for each directory we need to go up
    for (int i = 0; i < upCount; i++) {
      relativeParts.add('..');
    }

    // Add remaining path components
    for (int i = commonLength; i < toParts.length; i++) {
      relativeParts.add(toParts[i]);
    }

    // If we're in the same directory, use ./
    if (relativeParts.isEmpty) {
      return './${toParts.last}';
    }

    return relativeParts.join('/');
  }
}

/// Warns when multiple widget classes are defined in a single file.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of one widget per file:**
/// - Easier file navigation and searchability
/// - Smaller, more focused files
/// - Clear file naming conventions
///
/// **Cons (why some teams prefer grouping):**
/// - Related widgets can be viewed together
/// - Reduces number of files in project
/// - Simpler for small, tightly coupled widgets
///
/// Note: State classes are NOT counted as separate widgets since they must
/// be in the same file as their StatefulWidget.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// // my_widgets.dart
/// class MyButton extends StatelessWidget { ... }
/// class MyCard extends StatelessWidget { ... }  // Second widget in file
/// ```
///
/// #### GOOD:
/// ```dart
/// // my_button.dart
/// class MyButton extends StatelessWidget { ... }
///
/// // my_card.dart (separate file)
/// class MyCard extends StatelessWidget { ... }
/// ```
class PreferOneWidgetPerFileRule extends SaropaLintRule {
  const PreferOneWidgetPerFileRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_one_widget_per_file',
    problemMessage: 'Multiple widget classes defined in a single file.',
    correctionMessage:
        'Consider moving each widget class to its own file for better organization.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final List<ClassDeclaration> widgetClasses = <ClassDeclaration>[];

      for (final CompilationUnitMember declaration in unit.declarations) {
        if (declaration is ClassDeclaration) {
          if (_isWidgetClass(declaration)) {
            widgetClasses.add(declaration);
          }
        }
      }

      // Report on all widgets after the first one
      if (widgetClasses.length > 1) {
        for (int i = 1; i < widgetClasses.length; i++) {
          reporter.atToken(widgetClasses[i].name, code);
        }
      }
    });
  }

  bool _isWidgetClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) return false;

    final String? superclassName = extendsClause.superclass.element?.name;
    if (superclassName == null) return false;

    // Note: State classes are NOT counted as widgets - they MUST be in the
    // same file as their StatefulWidget and are not independent widgets.
    // We only count actual widget classes that could be in separate files.
    return superclassName == 'StatelessWidget' ||
        superclassName == 'StatefulWidget';
  }
}

/// Warns when block body functions could be written as arrow functions.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of arrow functions:**
/// - More concise and readable for simple returns
/// - Signals that function is a pure expression
/// - Consistent with functional programming style
///
/// **Cons (why some teams prefer block bodies):**
/// - Block bodies are more explicit
/// - Easier to add debug statements later
/// - Consistent formatting regardless of complexity
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// int double(int x) {
///   return x * 2;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// int double(int x) => x * 2;
/// ```
class PreferArrowFunctionsRule extends SaropaLintRule {
  const PreferArrowFunctionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_arrow_functions',
    problemMessage:
        'Function body contains only a return statement; use arrow syntax.',
    correctionMessage: 'Convert to arrow function: => expression',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check function declarations
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FunctionExpression function = node.functionExpression;
      if (_shouldBeArrowFunction(function.body)) {
        reporter.atToken(node.name, code);
      }
    });

    // Check method declarations
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody? body = node.body;
      if (body != null && _shouldBeArrowFunction(body)) {
        reporter.atToken(node.name, code);
      }
    });

    // Check function expressions (lambdas)
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Skip if parent is a function declaration (already handled)
      if (node.parent is FunctionDeclaration) return;

      if (_shouldBeArrowFunction(node.body)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldBeArrowFunction(FunctionBody body) {
    // Already an arrow function
    if (body is ExpressionFunctionBody) return false;

    // Check if block body with single return statement
    if (body is BlockFunctionBody) {
      final Block block = body.block;
      if (block.statements.length == 1) {
        final Statement statement = block.statements.first;
        // Only suggest arrow for explicit return statements with values
        // Don't suggest for expression statements (void functions) as
        // `{ print('x'); }` should NOT become `=> print('x')` which changes semantics
        if (statement is ReturnStatement && statement.expression != null) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToArrowFunctionFix()];
}

class _ConvertToArrowFunctionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Handle function declarations
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final FunctionBody body = node.functionExpression.body;
      _applyFix(body, reporter);
    });

    // Handle method declarations
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final FunctionBody? body = node.body;
      if (body != null) {
        _applyFix(body, reporter);
      }
    });

    // Handle function expressions (lambdas)
    context.registry.addFunctionExpression((FunctionExpression node) {
      if (node.parent is FunctionDeclaration) return;
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      _applyFix(node.body, reporter);
    });
  }

  void _applyFix(FunctionBody body, ChangeReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final Block block = body.block;
    if (block.statements.length != 1) return;

    final Statement statement = block.statements.first;
    if (statement is! ReturnStatement) return;

    final Expression? expression = statement.expression;
    if (expression == null) return;

    final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
      message: 'Convert to arrow function',
      priority: 1,
    );

    changeBuilder.addDartFileEdit((builder) {
      // Replace the entire block body with arrow syntax
      // From: { return expression; }
      // To: => expression;
      builder.addSimpleReplacement(
        body.sourceRange,
        '=> ${expression.toSource()}',
      );
    });
  }
}

/// Warns when functions have multiple positional parameters that could be named.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of named parameters:**
/// - Self-documenting call sites
/// - Order-independent arguments
/// - Easier to add optional parameters later
///
/// **Cons (why some teams prefer positional):**
/// - More verbose call sites
/// - Overkill for simple 2-3 param functions
/// - Familiar positional style from other languages
///
/// Note: This rule excludes `main()`, operators, and `@override` methods.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// void createUser(String name, String email, int age, bool isAdmin) { ... }
///
/// // Call site is unclear:
/// createUser('John', 'john@example.com', 30, true);
/// ```
///
/// #### GOOD:
/// ```dart
/// void createUser({
///   required String name,
///   required String email,
///   required int age,
///   required bool isAdmin,
/// }) { ... }
///
/// // Call site is self-documenting:
/// createUser(name: 'John', email: 'john@example.com', age: 30, isAdmin: true);
/// ```
class PreferAllNamedParametersRule extends SaropaLintRule {
  const PreferAllNamedParametersRule() : super(code: _code);

  /// Threshold for number of positional parameters before suggesting named.
  static const int _threshold = 3;

  static const LintCode _code = LintCode(
    name: 'prefer_all_named_parameters',
    problemMessage:
        'Function has $_threshold or more positional parameters; consider using named parameters.',
    correctionMessage:
        'Convert positional parameters to named parameters for clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      // Skip main function - it has a well-defined signature
      if (node.name.lexeme == 'main') return;

      _checkParameters(node.functionExpression.parameters, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip operator overloads - they have fixed signatures
      if (node.isOperator) return;

      // Skip overridden methods - they must match parent signature
      // Check for @override annotation
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') return;
      }

      _checkParameters(node.parameters, node.name, reporter);
    });

    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      final Token nameToken = node.name ?? node.returnType.beginToken;
      _checkParameters(node.parameters, nameToken, reporter);
    });
  }

  void _checkParameters(
    FormalParameterList? parameters,
    SyntacticEntity nameNode,
    SaropaDiagnosticReporter reporter,
  ) {
    if (parameters == null) return;

    int positionalCount = 0;
    for (final FormalParameter param in parameters.parameters) {
      if (param.isPositional) {
        positionalCount++;
      }
    }

    if (positionalCount >= _threshold) {
      reporter.atOffset(
        offset: nameNode.offset,
        length: nameNode.length,
        errorCode: code,
      );
    }
  }
}

/// Warns when multi-line constructs don't have trailing commas.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of trailing commas:**
/// - Cleaner git diffs (single line changes)
/// - Easier to reorder arguments
/// - Consistent formatting with dart format
///
/// **Cons (why some teams avoid them):**
/// - Visual noise at end of lines
/// - Different from most other languages
/// - May feel redundant
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Widget build() {
///   return Container(
///     child: Column(
///       children: [
///         Text('Hello'),
///         Text('World')  // Missing trailing comma
///       ]  // Missing trailing comma
///     )  // Missing trailing comma
///   );  // Missing trailing comma
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Widget build() {
///   return Container(
///     child: Column(
///       children: [
///         Text('Hello'),
///         Text('World'),
///       ],
///     ),
///   );
/// }
/// ```
class PreferTrailingCommaAlwaysRule extends SaropaLintRule {
  const PreferTrailingCommaAlwaysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_trailing_comma_always',
    problemMessage: 'Multi-line construct should have a trailing comma.',
    correctionMessage: 'Add a trailing comma for consistent formatting.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check argument lists
    context.registry.addArgumentList((ArgumentList node) {
      if (node.arguments.isEmpty) return;
      if (!_isMultiLine(node, resolver)) return;

      final Token rightParen = node.rightParenthesis;
      final Token? lastToken = node.arguments.last.endToken;
      if (lastToken == null) return;

      // Check if there's a comma before the closing paren
      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightParen, code);
      }
    });

    // Check list literals
    context.registry.addListLiteral((ListLiteral node) {
      if (node.elements.isEmpty) return;
      if (!_isMultiLine(node, resolver)) return;

      final Token rightBracket = node.rightBracket;
      final Token? lastToken = node.elements.last.endToken;
      if (lastToken == null) return;

      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightBracket, code);
      }
    });

    // Check set/map literals
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.elements.isEmpty) return;
      if (!_isMultiLine(node, resolver)) return;

      final Token rightBracket = node.rightBracket;
      final Token? lastToken = node.elements.last.endToken;
      if (lastToken == null) return;

      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightBracket, code);
      }
    });

    // Check parameter lists
    context.registry.addFormalParameterList((FormalParameterList node) {
      if (node.parameters.isEmpty) return;
      if (!_isMultiLine(node, resolver)) return;

      final Token rightParen = node.rightParenthesis;
      final FormalParameter lastParam = node.parameters.last;
      final Token? lastToken = lastParam.endToken;
      if (lastToken == null) return;

      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightParen, code);
      }
    });
  }

  bool _isMultiLine(AstNode node, CustomLintResolver resolver) {
    final CompilationUnit unit = node.root as CompilationUnit;
    final int startLine = unit.lineInfo.getLocation(node.offset).lineNumber;
    final int endLine = unit.lineInfo.getLocation(node.end).lineNumber;
    return endLine > startLine;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTrailingCommaAlwaysFix()];
}

class _AddTrailingCommaAlwaysFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addArgumentList((ArgumentList node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.arguments.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.arguments.last.end, ',');
      });
    });

    context.registry.addListLiteral((ListLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.elements.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.elements.last.end, ',');
      });
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.elements.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.elements.last.end, ',');
      });
    });

    context.registry.addFormalParameterList((FormalParameterList node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.parameters.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.parameters.last.end, ',');
      });
    });
  }
}

/// Warns when private fields don't use underscore prefix consistently.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of underscore prefix for all instance fields:**
/// - Encapsulation by default
/// - Clear distinction between public API and internal state
/// - Forces explicit getter/setter decisions
///
/// **Cons (why some teams allow public fields):**
/// - More boilerplate for simple data classes
/// - Dart already has library privacy without underscore
/// - Record types make plain fields common
///
/// Note: Excludes widget properties, State class fields, and documented fields.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class MyClass {
///   String name;  // Public field - should be private?
///   late String _initialized;  // Good - clearly private
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyClass {
///   String _name;  // Private field
///   late String _initialized;  // Private field
///
///   String get name => _name;  // Public getter
/// }
/// ```
class PreferPrivateUnderscorePrefixRule extends SaropaLintRule {
  const PreferPrivateUnderscorePrefixRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_private_underscore_prefix',
    problemMessage:
        'Instance field should be private (prefixed with underscore).',
    correctionMessage:
        'Consider making this field private and providing a getter if needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Skip static fields
      if (node.isStatic) return;

      // Skip if explicitly marked as public API (has doc comment)
      if (node.documentationComment != null) return;

      for (final VariableDeclaration variable in node.fields.variables) {
        final String name = variable.name.lexeme;

        // Skip if already private
        if (name.startsWith('_')) continue;

        // Skip common public field patterns (like widget properties)
        if (_isLikelyIntentionallyPublic(node, name)) continue;

        reporter.atToken(variable.name, code);
      }
    });
  }

  bool _isLikelyIntentionallyPublic(FieldDeclaration node, String name) {
    // Check if this is in a State class (common pattern for public controllers)
    final AstNode? parent = node.parent;
    if (parent is ClassDeclaration) {
      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause != null) {
        final String? superclassName = extendsClause.superclass.element?.name;
        // State classes often have public fields that are intentional
        if (superclassName == 'State') return true;
      }

      // Check if class extends StatelessWidget or StatefulWidget (widget props)
      if (extendsClause != null) {
        final String? superclassName = extendsClause.superclass.element?.name;
        if (superclassName == 'StatelessWidget' ||
            superclassName == 'StatefulWidget') {
          return true; // Widget constructor parameters are intentionally public
        }
      }
    }

    // Common intentionally public field names (exact match or known prefixes)
    const Set<String> exactPublicNames = <String>{
      'key',
      'child',
      'children',
      'builder',
      'controller',
    };

    // Check exact match
    if (exactPublicNames.contains(name)) return true;

    // Check common callback prefixes
    if (name.startsWith('on') && name.length > 2) {
      // onPressed, onTap, onChange, etc.
      final String afterOn = name.substring(2);
      if (afterOn.isNotEmpty && afterOn[0] == afterOn[0].toUpperCase()) {
        return true;
      }
    }

    return false;
  }
}

/// Warns when small widgets could be extracted as methods instead of classes.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of widget methods:**
/// - Less boilerplate code
/// - Simpler for very small UI pieces
/// - Access to parent widget state without passing
///
/// **Cons (why some teams prefer widget classes):**
/// - Widget classes enable better rebuild optimization
/// - Easier to add const constructors
/// - Better separation of concerns
/// - More testable in isolation
///
/// Note: Only flags private StatelessWidgets with simple build methods.
/// Complex widgets with fields or multiple methods are not flagged.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// // Small widget that could be a method
/// class _MyIcon extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Icon(Icons.star, color: Colors.yellow);
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// // In parent widget:
/// Widget _buildIcon() {
///   return Icon(Icons.star, color: Colors.yellow);
/// }
/// ```
///
/// Note: This rule suggests methods for SIMPLE widgets. Complex widgets
/// with state or many parameters should remain as classes.
class PreferWidgetMethodsOverClassesRule extends SaropaLintRule {
  const PreferWidgetMethodsOverClassesRule() : super(code: _code);

  /// Maximum number of lines in build method to suggest conversion.
  static const int _maxBuildLines = 5;

  static const LintCode _code = LintCode(
    name: 'prefer_widget_methods_over_classes',
    problemMessage:
        'Simple widget class could be a method in the parent widget.',
    correctionMessage:
        'Consider converting to a build method for less boilerplate.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check private StatelessWidget classes
      if (!node.name.lexeme.startsWith('_')) return;

      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superclassName = extendsClause.superclass.element?.name;
      if (superclassName != 'StatelessWidget') return;

      // Check if it has only the build method (no fields, no other methods)
      final List<ClassMember> members = node.members.toList();

      bool hasFields = false;
      bool hasOtherMethods = false;
      MethodDeclaration? buildMethod;

      for (final ClassMember member in members) {
        if (member is FieldDeclaration) {
          hasFields = true;
          break;
        }
        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'build') {
            buildMethod = member;
          } else {
            // Has other methods beyond build - too complex to be a simple method
            hasOtherMethods = true;
          }
        }
        if (member is ConstructorDeclaration) {
          // Has a constructor with logic - keep as class
          if (member.body is! EmptyFunctionBody) {
            hasOtherMethods = true;
          }
        }
      }

      // Skip if has fields (needs to be a class for state)
      if (hasFields) return;

      // Skip if has other methods (too complex)
      if (hasOtherMethods) return;

      // Skip if no build method found
      if (buildMethod == null) return;

      // Check build method size
      final FunctionBody body = buildMethod.body;
      final CompilationUnit unit = node.root as CompilationUnit;
      final int startLine = unit.lineInfo.getLocation(body.offset).lineNumber;
      final int endLine = unit.lineInfo.getLocation(body.end).lineNumber;
      final int lineCount = endLine - startLine + 1;

      if (lineCount <= _maxBuildLines) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when `var`, `final` (without type), or `dynamic` is used instead of
/// explicit types.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of explicit types:**
/// - Clear intent and documentation
/// - Catches type mismatches at declaration
/// - Easier to read in code reviews
///
/// **Cons (why some teams prefer inference):**
/// - More verbose
/// - Dart's type inference is excellent
/// - Redundant when type is obvious from initializer
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// var name = 'John';
/// final count = 42;
/// dynamic items = <String>[];
/// ```
///
/// #### GOOD:
/// ```dart
/// String name = 'John';
/// final int count = 42;
/// List<String> items = <String>[];
/// ```
class PreferExplicitTypesRule extends SaropaLintRule {
  const PreferExplicitTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_types',
    problemMessage: 'Use explicit type annotation instead of var/dynamic.',
    correctionMessage: 'Replace var/dynamic with the explicit type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclarationList((VariableDeclarationList node) {
      final TypeAnnotation? type = node.type;

      // Check for 'var' keyword (type is null, keyword is 'var')
      if (type == null && node.keyword?.lexeme == 'var') {
        for (final VariableDeclaration variable in node.variables) {
          reporter.atToken(variable.name, code);
        }
        return;
      }

      // Check for 'final' without explicit type (e.g., `final name = 'John';`)
      if (type == null && node.keyword?.lexeme == 'final') {
        for (final VariableDeclaration variable in node.variables) {
          // Only flag if there's an initializer (type can be inferred)
          if (variable.initializer != null) {
            reporter.atToken(variable.name, code);
          }
        }
        return;
      }

      // Check for 'dynamic' type
      if (type is NamedType && type.element?.name == 'dynamic') {
        for (final VariableDeclaration variable in node.variables) {
          reporter.atToken(variable.name, code);
        }
      }
    });
  }
}

/// Warns when methods return records instead of dedicated classes.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of classes over records:**
/// - Named fields are self-documenting
/// - Can add methods and validation
/// - Better IDE support and refactoring
/// - Can implement interfaces
///
/// **Cons (why some teams prefer records):**
/// - Records are more concise
/// - Good for simple data transfer
/// - No boilerplate needed
/// - Pattern matching support
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// (String name, int age) getUser() {
///   return ('John', 30);
/// }
///
/// ({String name, int age}) getUserNamed() {
///   return (name: 'John', age: 30);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class User {
///   final String name;
///   final int age;
///   User(this.name, this.age);
/// }
///
/// User getUser() {
///   return User('John', 30);
/// }
/// ```
class PreferClassOverRecordReturnRule extends SaropaLintRule {
  const PreferClassOverRecordReturnRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_class_over_record_return',
    problemMessage: 'Method returns a record; consider using a dedicated class.',
    correctionMessage:
        'Create a class with named fields for better maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkReturnType(node.returnType, node.name, reporter);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkReturnType(node.returnType, node.name, reporter);
    });
  }

  void _checkReturnType(
    TypeAnnotation? returnType,
    Token nameNode,
    SaropaDiagnosticReporter reporter,
  ) {
    if (returnType == null) return;

    // Check if return type is a record type
    if (returnType is RecordTypeAnnotation) {
      reporter.atNode(returnType, code);
    }
  }
}

/// Warns when callbacks are extracted to separate methods/variables.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of inline callbacks:**
/// - Behavior is visible where it's used
/// - No need to search for method definition
/// - Simpler for one-off handlers
///
/// **Cons (why some teams prefer extracted methods):**
/// - Reusable across multiple widgets
/// - Easier to test in isolation
/// - Keeps build methods shorter
/// - Can have descriptive method names
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class MyWidget extends StatelessWidget {
///   void _onPressed() {
///     print('pressed');
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: _onPressed,  // Extracted callback
///       child: Text('Press me'),
///     );
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: () {
///         print('pressed');
///       },
///       child: Text('Press me'),
///     );
///   }
/// }
/// ```
class PreferInlineCallbacksRule extends SaropaLintRule {
  const PreferInlineCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_inline_callbacks',
    problemMessage:
        'Callback references a method; consider inlining for locality.',
    correctionMessage:
        'Inline simple callbacks to keep behavior close to its usage.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Common callback parameter names to check.
  static const Set<String> _callbackParams = <String>{
    'onPressed',
    'onTap',
    'onChanged',
    'onSubmitted',
    'onSaved',
    'onEditingComplete',
    'onLongPress',
    'onDoubleTap',
    'onHover',
    'onFocusChange',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      final String paramName = node.name.label.name;

      // Only check common callback parameters
      if (!_callbackParams.contains(paramName)) return;

      final Expression expression = node.expression;

      // Check if it's a simple identifier (method reference)
      if (expression is SimpleIdentifier) {
        // Skip null and common non-method values
        if (expression.name == 'null') return;

        // Any identifier used as a callback (except null) is likely a method reference
        // This includes both private (_onTap) and public (onTap) methods
        reporter.atNode(expression, code);
      }

      // Check if it's a prefixed identifier (this.onTap or widget.callback)
      if (expression is PrefixedIdentifier) {
        // Any prefixed identifier used as callback is a method/getter reference
        reporter.atNode(expression, code);
      }
    });
  }
}

/// Warns when double quotes are used instead of single quotes for strings.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of single quotes:**
/// - Dart style guide recommends single quotes
/// - Fewer keystrokes (no shift key needed)
/// - Consistent with many Dart codebases
///
/// **Cons (why some teams prefer double quotes):**
/// - Familiar from other languages (Java, JavaScript)
/// - Easier to include apostrophes in strings
/// - JSON uses double quotes
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// String name = "John";
/// String message = "Hello, World!";
/// ```
///
/// #### GOOD:
/// ```dart
/// String name = 'John';
/// String message = 'Hello, World!';
/// ```
class PreferSingleQuotesRule extends SaropaLintRule {
  const PreferSingleQuotesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_single_quotes',
    problemMessage: 'Use single quotes instead of double quotes for strings.',
    correctionMessage: "Replace double quotes with single quotes: 'string'",
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      // Get the raw lexeme to check the quote style
      final String lexeme = node.literal.lexeme;

      // Skip raw strings (r"..." or r'...')
      if (lexeme.startsWith('r')) return;

      // Check if it starts with double quote
      if (lexeme.startsWith('"')) {
        // Skip if the string contains unescaped single quotes
        // (would need escaping if converted to single quotes)
        if (node.value.contains("'")) {
          return;
        }
        reporter.atNode(node, code);
      }
    });

    // Also check multi-line strings with interpolation
    context.registry.addStringInterpolation((StringInterpolation node) {
      final Token beginToken = node.beginToken;
      final String lexeme = beginToken.lexeme;

      // Skip raw strings
      if (lexeme.startsWith('r')) return;

      // Check if it starts with double quote (including """)
      if (lexeme.startsWith('"')) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToSingleQuotesFix()];
}

class _ConvertToSingleQuotesFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final String lexeme = node.literal.lexeme;
      if (!lexeme.startsWith('"')) return;

      // Skip if contains single quotes (would need escaping)
      if (node.value.contains("'")) return;

      // Escape any existing backslashes and single quotes in the value
      final String escaped = node.value
          .replaceAll(r'\', r'\\')
          .replaceAll("'", r"\'");

      final String newLexeme = "'$escaped'";

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to single quotes',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.sourceRange, newLexeme);
      });
    });
  }
}

/// Warns when TODO comments don't follow the standard format.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// The standard format is: `TODO(author): description`
///
/// **Pros of formatted TODOs:**
/// - Easy to track who added the TODO
/// - Searchable by author
/// - Consistent across codebase
///
/// **Cons (why some teams skip author):**
/// - Git blame already shows author
/// - Extra typing
/// - Author may leave the team
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// // TODO: fix this later
/// // TODO fix this
/// // todo: implement feature
/// ```
///
/// #### GOOD:
/// ```dart
/// // TODO(john): fix this later
/// // TODO(jane): implement feature
/// ```
class PreferTodoFormatRule extends SaropaLintRule {
  const PreferTodoFormatRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_todo_format',
    problemMessage: 'TODO comment should follow format: TODO(author): description',
    correctionMessage: 'Add author name in parentheses: TODO(author): ...',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern for valid TODO format: TODO(author): description
  static final RegExp _validTodoPattern = RegExp(
    r'^//\s*TODO\s*\([a-zA-Z][a-zA-Z0-9_-]*\)\s*:',
    caseSensitive: false,
  );

  /// Pattern to detect any TODO comment
  static final RegExp _anyTodoPattern = RegExp(
    r'^//\s*TODO',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        // Check preceding comments
        Token? comment = token.precedingComments;
        while (comment != null) {
          final String lexeme = comment.lexeme;

          // Check if it's a TODO comment
          if (_anyTodoPattern.hasMatch(lexeme)) {
            // Check if it follows the correct format
            if (!_validTodoPattern.hasMatch(lexeme)) {
              reporter.atOffset(
                offset: comment.offset,
                length: comment.length,
                errorCode: code,
              );
            }
          }

          comment = comment.next;
        }
        token = token.next;
      }
    });
  }
}

/// Warns when FIXME comments don't follow the standard format.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// The standard format is: `FIXME(author): description`
///
/// **Pros of formatted FIXMEs:**
/// - Easy to track who added the FIXME
/// - Searchable by author
/// - Consistent with TODO format
///
/// **Cons (why some teams skip author):**
/// - Git blame already shows author
/// - Extra typing
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// // FIXME: this is broken
/// // FIXME fix the bug
/// // fixme: handle edge case
/// ```
///
/// #### GOOD:
/// ```dart
/// // FIXME(john): this is broken
/// // FIXME(jane): handle edge case
/// ```
class PreferFixmeFormatRule extends SaropaLintRule {
  const PreferFixmeFormatRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_fixme_format',
    problemMessage: 'FIXME comment should follow format: FIXME(author): description',
    correctionMessage: 'Add author name in parentheses: FIXME(author): ...',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern for valid FIXME format: FIXME(author): description
  static final RegExp _validFixmePattern = RegExp(
    r'^//\s*FIXME\s*\([a-zA-Z][a-zA-Z0-9_-]*\)\s*:',
    caseSensitive: false,
  );

  /// Pattern to detect any FIXME comment
  static final RegExp _anyFixmePattern = RegExp(
    r'^//\s*FIXME',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        // Check preceding comments
        Token? comment = token.precedingComments;
        while (comment != null) {
          final String lexeme = comment.lexeme;

          // Check if it's a FIXME comment
          if (_anyFixmePattern.hasMatch(lexeme)) {
            // Check if it follows the correct format
            if (!_validFixmePattern.hasMatch(lexeme)) {
              reporter.atOffset(
                offset: comment.offset,
                length: comment.length,
                errorCode: code,
              );
            }
          }

          comment = comment.next;
        }
        token = token.next;
      }
    });
  }
}

/// Warns when comments don't start with a capital letter.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of sentence case comments:**
/// - More professional appearance
/// - Consistent with documentation standards
/// - Easier to read
///
/// **Cons (why some teams skip this):**
/// - Extra effort for quick notes
/// - May conflict with code references (e.g., "// userId is required")
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// // calculate the total
/// // this is a helper function
/// ```
///
/// #### GOOD:
/// ```dart
/// // Calculate the total
/// // This is a helper function
/// ```
class PreferSentenceCaseCommentsRule extends SaropaLintRule {
  const PreferSentenceCaseCommentsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sentence_case_comments',
    problemMessage: 'Comment should start with a capital letter.',
    correctionMessage: 'Capitalize the first letter of the comment.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern for special comment markers that should be skipped.
  static final RegExp _specialMarkerPattern = RegExp(
    r'^(ignore|TODO|FIXME|NOTE|HACK|XXX|BUG|WARN|WARNING):?',
    caseSensitive: false,
  );

  /// Pattern for code-like references at start of comment.
  static final RegExp _codeReferencePattern = RegExp(
    r'^[a-z_][a-zA-Z0-9_]*\s',
  );

  /// Pattern to check if first character is lowercase letter.
  static final RegExp _lowercaseFirstChar = RegExp(r'^[a-z]');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        Token? comment = token.precedingComments;
        while (comment != null) {
          _checkComment(comment, reporter);
          comment = comment.next;
        }
        token = token.next;
      }
    });
  }

  void _checkComment(Token comment, SaropaDiagnosticReporter reporter) {
    final String lexeme = comment.lexeme;

    // Skip doc comments (handled separately)
    if (lexeme.startsWith('///')) return;

    // Skip block comments
    if (lexeme.startsWith('/*')) return;

    // Only check single-line comments
    if (!lexeme.startsWith('//')) return;

    // Skip special comments: ignore, TODO, FIXME, NOTE, HACK, etc.
    final String trimmed = lexeme.substring(2).trim();
    if (trimmed.isEmpty) return;

    // Skip special markers
    if (_specialMarkerPattern.hasMatch(trimmed)) {
      return;
    }

    // Skip if starts with code-like patterns (variable names, etc.)
    // e.g., "// userId is the..." or "// _privateField holds..."
    if (_codeReferencePattern.hasMatch(trimmed)) {
      return;
    }

    // Check if the first character is lowercase
    if (_lowercaseFirstChar.hasMatch(trimmed)) {
      reporter.atOffset(
        offset: comment.offset,
        length: comment.length,
        errorCode: code,
      );
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_CapitalizeCommentFix()];
}

class _CapitalizeCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Find the comment token at this location
    context.registry.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        Token? comment = token.precedingComments;
        while (comment != null) {
          final Token currentComment = comment;
          if (currentComment.offset == analysisError.offset) {
            final String lexeme = currentComment.lexeme;
            // Find the content after //
            final int prefixLength = lexeme.startsWith('// ') ? 3 : 2;
            final String content = lexeme.substring(prefixLength);

            if (content.isNotEmpty) {
              final String capitalized =
                  content[0].toUpperCase() + content.substring(1);
              final String newLexeme =
                  '${lexeme.substring(0, prefixLength)}$capitalized';

              final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
                message: 'Capitalize first letter',
                priority: 1,
              );

              changeBuilder.addDartFileEdit((builder) {
                builder.addSimpleReplacement(
                  analysisError.sourceRange,
                  newLexeme,
                );
              });
            }
          }
          comment = comment.next;
        }
        token = token.next;
      }
    });
  }
}

/// Warns when doc comments don't end with a period.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of periods in doc comments:**
/// - Complete sentences are easier to read
/// - Professional documentation style
/// - Consistent with Dart documentation guidelines
///
/// **Cons (why some teams skip this):**
/// - Extra typing for simple docs
/// - May feel redundant for short descriptions
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// /// Returns the user's name
/// String getName() => name;
///
/// /// Calculates the total price
/// double calculateTotal() { ... }
/// ```
///
/// #### GOOD:
/// ```dart
/// /// Returns the user's name.
/// String getName() => name;
///
/// /// Calculates the total price.
/// double calculateTotal() { ... }
/// ```
class PreferPeriodAfterDocRule extends SaropaLintRule {
  const PreferPeriodAfterDocRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_period_after_doc',
    problemMessage: 'Doc comment should end with a period.',
    correctionMessage: 'Add a period at the end of the doc comment.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern to strip the doc comment prefix (/// or ///).
  static final RegExp _docPrefixPattern = RegExp(r'^///\s*');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check class declarations
    context.registry.addClassDeclaration((ClassDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check method declarations
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check function declarations
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check field declarations
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check top-level variables
    context.registry.addTopLevelVariableDeclaration(
        (TopLevelVariableDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check enum declarations
    context.registry.addEnumDeclaration((EnumDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });
  }

  void _checkDocComment(Comment? comment, SaropaDiagnosticReporter reporter) {
    if (comment == null) return;

    // Get all the doc comment tokens
    final List<Token> tokens = comment.tokens;
    if (tokens.isEmpty) return;

    // Find the last non-empty line
    String? lastLine;
    Token? lastToken;
    for (int i = tokens.length - 1; i >= 0; i--) {
      final String lexeme = tokens[i].lexeme;
      // Remove the /// prefix and trim
      final String content = lexeme.replaceFirst(_docPrefixPattern, '').trim();
      if (content.isNotEmpty) {
        lastLine = content;
        lastToken = tokens[i];
        break;
      }
    }

    if (lastLine == null || lastToken == null) return;

    // Skip if it ends with code block markers or special patterns
    if (lastLine.endsWith('```') ||
        lastLine.endsWith(':') ||
        lastLine.endsWith(')') || // Likely a parameter reference like [param]
        lastLine.startsWith('@') ||
        lastLine.startsWith('*') ||
        lastLine.startsWith('-') ||
        lastLine.startsWith('{@') || // Dartdoc macros
        lastLine.contains('```')) {
      return;
    }

    // Check if it ends with proper punctuation
    if (!lastLine.endsWith('.') &&
        !lastLine.endsWith('!') &&
        !lastLine.endsWith('?') &&
        !lastLine.endsWith(':') &&
        !lastLine.endsWith(']')) {
      // Ends with ] might be a link like [ClassName]
      reporter.atToken(lastToken, code);
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddPeriodFix()];
}

class _AddPeriodFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
      message: 'Add period',
      priority: 1,
    );

    changeBuilder.addDartFileEdit((builder) {
      // Insert a period at the end of the doc comment (before any trailing whitespace)
      final int endOffset = analysisError.offset + analysisError.length;
      builder.addSimpleInsertion(endOffset, '.');
    });
  }
}

/// Warns when constants don't use SCREAMING_SNAKE_CASE.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of SCREAMING_SNAKE_CASE:**
/// - Immediately identifiable as constants
/// - Traditional style from C/Java
/// - Clear distinction from variables
///
/// **Cons (why Dart style guide uses lowerCamelCase):**
/// - Dart official style guide prefers lowerCamelCase for constants
/// - Less "shouty" in code
/// - Consistent with other Dart naming
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// const int maxRetries = 3;
/// const String apiVersion = 'v1';
/// static const double pi = 3.14159;
/// ```
///
/// #### GOOD:
/// ```dart
/// const int MAX_RETRIES = 3;
/// const String API_VERSION = 'v1';
/// static const double PI = 3.14159;
/// ```
class PreferScreamingCaseConstantsRule extends SaropaLintRule {
  const PreferScreamingCaseConstantsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_screaming_case_constants',
    problemMessage: 'Constants should use SCREAMING_SNAKE_CASE.',
    correctionMessage:
        'Rename to SCREAMING_SNAKE_CASE: MAX_VALUE instead of maxValue',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern for valid SCREAMING_SNAKE_CASE.
  static final RegExp _screamingSnakeCase = RegExp(r'^[A-Z][A-Z0-9_]*$');

  /// Converts camelCase or PascalCase to SCREAMING_SNAKE_CASE.
  static String toScreamingSnakeCase(String name) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < name.length; i++) {
      final String char = name[i];
      if (i > 0 && char == char.toUpperCase() && char != '_') {
        // Check if previous char was lowercase or if next char is lowercase
        final String prevChar = name[i - 1];
        if (prevChar == prevChar.toLowerCase() && prevChar != '_') {
          buffer.write('_');
        }
      }
      buffer.write(char.toUpperCase());
    }
    return buffer.toString();
  }

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check top-level constants
    context.registry
        .addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      if (!node.variables.isConst) return;

      for (final VariableDeclaration variable in node.variables.variables) {
        final String name = variable.name.lexeme;
        // Skip private constants (they often have different conventions)
        if (name.startsWith('_')) continue;

        if (!_screamingSnakeCase.hasMatch(name)) {
          reporter.atToken(variable.name, code);
        }
      }
    });

    // Check static const fields in classes
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (!node.isStatic) return;
      if (!node.fields.isConst) return;

      for (final VariableDeclaration variable in node.fields.variables) {
        final String name = variable.name.lexeme;
        // Skip private constants
        if (name.startsWith('_')) continue;

        if (!_screamingSnakeCase.hasMatch(name)) {
          reporter.atToken(variable.name, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToScreamingCaseFix()];
}

class _ConvertToScreamingCaseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.name.sourceRange)) return;

      final String name = node.name.lexeme;
      final String newName =
          PreferScreamingCaseConstantsRule.toScreamingSnakeCase(name);

      if (name == newName) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Rename to $newName',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.name.sourceRange, newName);
      });
    });
  }
}

/// Warns when boolean variables/parameters don't use descriptive prefixes.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// Boolean names should use prefixes like `is`, `has`, `can`, `should`, `will`,
/// `was`, `did`, or `does` to make their purpose clear.
///
/// **Pros of prefixed boolean names:**
/// - Self-documenting code
/// - Clear intent at usage site
/// - Reads naturally in conditions
///
/// **Cons (why some teams skip this):**
/// - Can be verbose for obvious cases
/// - Some booleans don't fit these patterns naturally
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// bool loading = true;
/// bool visible = false;
/// void setEnabled(bool enabled) { ... }
/// ```
///
/// #### GOOD:
/// ```dart
/// bool isLoading = true;
/// bool isVisible = false;
/// void setEnabled(bool isEnabled) { ... }
/// ```
class PreferDescriptiveBoolNamesRule extends SaropaLintRule {
  const PreferDescriptiveBoolNamesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_descriptive_bool_names',
    problemMessage: 'Boolean should use a descriptive prefix (is, has, can, should, etc.).',
    correctionMessage: 'Rename with a prefix: isEnabled, hasData, canEdit, shouldUpdate',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Valid boolean prefixes
  static final RegExp _validBoolPrefix = RegExp(
    r'^(is|has|have|can|should|will|was|did|does|allow|enable|disable|show|hide|include|exclude)[A-Z]',
  );

  /// Also allow common boolean suffixes
  static final RegExp _validBoolSuffix = RegExp(
    r'(Enabled|Disabled|Visible|Hidden|Active|Valid|Invalid|Empty|Loading|Loaded|Complete|Done|Open|Closed|Required|Optional|Selected|Checked|Available|Initialized)$',
  );

  /// Set of allowed boolean type representations.
  static const Set<String> _boolTypes = <String>{'bool', 'bool?'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check variable declarations
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final element = node.declaredElement;
      if (element == null) return;

      // Check for bool or bool?
      final String typeStr = element.type.toString();
      if (!_boolTypes.contains(typeStr)) return;

      _checkName(node.name, reporter);
    });

    // Check parameters
    context.registry.addSimpleFormalParameter((SimpleFormalParameter node) {
      // Check the type annotation
      final TypeAnnotation? typeAnnotation = node.type;
      if (typeAnnotation == null) return;

      // Check if it's a bool or bool? type
      final String typeName = typeAnnotation.toString();
      if (!_boolTypes.contains(typeName)) return;

      final Token? name = node.name;
      if (name != null) {
        _checkName(name, reporter);
      }
    });

    // Check field declarations (class members)
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final element = variable.declaredElement;
        if (element == null) continue;

        final String typeStr = element.type.toString();
        if (!_boolTypes.contains(typeStr)) continue;

        _checkName(variable.name, reporter);
      }
    });
  }

  void _checkName(Token nameToken, SaropaDiagnosticReporter reporter) {
    final String name = nameToken.lexeme;

    // Skip private names (they may have different conventions)
    if (name.startsWith('_')) return;

    // Skip single letter names (usually in tests or lambdas)
    if (name.length <= 2) return;

    // Check for valid prefix or suffix
    if (_validBoolPrefix.hasMatch(name)) return;
    if (_validBoolSuffix.hasMatch(name)) return;

    // Special case: common boolean names that are clear without prefix
    const Set<String> allowedNames = <String>{
      'enabled',
      'disabled',
      'visible',
      'hidden',
      'active',
      'valid',
      'invalid',
      'empty',
      'loading',
      'loaded',
      'complete',
      'done',
      'open',
      'closed',
      'required',
      'optional',
      'selected',
      'checked',
      'available',
      'nullable',
      'mounted',
      'disposed',
      'async',
      'sync',
      'success',
      'failed',
      'ready',
      'pending',
      'expanded',
      'collapsed',
      'focused',
      'hovering',
      'pressed',
      'dragging',
    };
    if (allowedNames.contains(name.toLowerCase())) return;

    reporter.atToken(nameToken, code);
  }
}

/// Warns when Dart file names don't use snake_case.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of snake_case file names:**
/// - Dart style guide recommends snake_case
/// - Consistent across the Dart ecosystem
/// - Case-insensitive file systems handle better
///
/// **Cons (why some teams use other styles):**
/// - Some prefer PascalCase to match class names
/// - Habit from other languages
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```
/// UserService.dart
/// user-service.dart
/// userService.dart
/// ```
///
/// #### GOOD:
/// ```
/// user_service.dart
/// ```
class PreferSnakeCaseFilesRule extends SaropaLintRule {
  const PreferSnakeCaseFilesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_snake_case_files',
    problemMessage: 'File name should use snake_case.',
    correctionMessage:
        'Rename file to snake_case: user_service.dart instead of UserService.dart',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern for valid snake_case file names.
  static final RegExp _snakeCasePattern = RegExp(r'^[a-z][a-z0-9_]*\.dart$');

  /// Generated file suffixes that should be skipped.
  static const List<String> _generatedSuffixes = <String>[
    '.g.dart',
    '.freezed.dart',
    '.gen.dart',
    '.gr.dart',
    '.mocks.dart',
    '.config.dart',
    '.chopper.dart',
    '.drift.dart',
    '.mapper.dart',
    '.reflectable.dart',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final String fullPath = resolver.source.fullName.replaceAll('\\', '/');
      final String fileName = fullPath.split('/').last;

      // Skip generated files
      for (final String suffix in _generatedSuffixes) {
        if (fileName.endsWith(suffix)) {
          return;
        }
      }

      // Skip files in generated directories
      if (fullPath.contains('/generated/') ||
          fullPath.contains('/.dart_tool/')) {
        return;
      }

      if (!_snakeCasePattern.hasMatch(fileName)) {
        // Report at the library directive if present, otherwise at the first token
        final LibraryDirective? library =
            unit.directives.whereType<LibraryDirective>().firstOrNull;
        if (library != null) {
          reporter.atNode(library, code);
        } else {
          // Report at the beginning of the file
          reporter.atOffset(
            offset: 0,
            length: 1,
            errorCode: code,
          );
        }
      }
    });
  }
}

/// Warns when text size is smaller than the recommended minimum.
///
/// This is an **opinionated rule** - not included in any tier by default.
/// Default minimum is 12 logical pixels.
///
/// **Pros of minimum text size:**
/// - Better accessibility for all users
/// - WCAG compliance
/// - Easier reading on all devices
///
/// **Cons (why some teams allow smaller text):**
/// - Design requirements may need smaller text
/// - Captions and legal text often need smaller sizes
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Text('Small', style: TextStyle(fontSize: 10));
/// ```
///
/// #### GOOD:
/// ```dart
/// Text('Readable', style: TextStyle(fontSize: 14));
/// ```
class AvoidSmallTextRule extends SaropaLintRule {
  const AvoidSmallTextRule() : super(code: _code);

  /// Minimum font size in logical pixels.
  static const double _minFontSize = 12.0;

  static const LintCode _code = LintCode(
    name: 'avoid_small_text',
    problemMessage:
        'Font size is smaller than $_minFontSize. Consider increasing for accessibility.',
    correctionMessage:
        'Use a font size of at least $_minFontSize for better readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;

      // Check TextStyle constructor
      if (constructorName != 'TextStyle') return;

      _checkFontSize(node.argumentList.arguments, reporter);
    });
  }

  void _checkFontSize(
    NodeList<Expression> arguments,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final Expression arg in arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'fontSize') {
        final Expression expression = arg.expression;

        double? fontSize;
        if (expression is IntegerLiteral) {
          fontSize = expression.value?.toDouble();
        } else if (expression is DoubleLiteral) {
          fontSize = expression.value;
        } else if (expression is PrefixExpression &&
            expression.operator.lexeme == '-') {
          // Handle negative numbers (which would definitely be invalid)
          final Expression operand = expression.operand;
          if (operand is IntegerLiteral || operand is DoubleLiteral) {
            fontSize = -1; // Any negative is invalid
          }
        }

        if (fontSize != null && fontSize < _minFontSize) {
          reporter.atNode(arg, code);
        }
      }
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_IncreaseFontSizeFix()];
}

class _IncreaseFontSizeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.name.label.name != 'fontSize') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Change to fontSize: ${AvoidSmallTextRule._minFontSize}',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.expression.sourceRange,
          AvoidSmallTextRule._minFontSize.toString(),
        );
      });
    });
  }
}

/// Warns when regular comments (`//`) are used instead of doc comments (`///`)
/// for public members.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of doc comments:**
/// - Show up in IDE hover documentation
/// - Can be extracted by dartdoc
/// - Clearly mark API documentation
///
/// **Cons (why some teams use regular comments):**
/// - Less formal for internal notes
/// - Doc comments may feel heavy for simple members
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// // Returns the user's full name.
/// String getFullName() => '$firstName $lastName';
///
/// // The user's age in years.
/// int age;
/// ```
///
/// #### GOOD:
/// ```dart
/// /// Returns the user's full name.
/// String getFullName() => '$firstName $lastName';
///
/// /// The user's age in years.
/// int age;
/// ```
class PreferDocCommentsOverRegularRule extends SaropaLintRule {
  const PreferDocCommentsOverRegularRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_doc_comments_over_regular',
    problemMessage:
        'Use doc comments (///) instead of regular comments (//) for public API documentation.',
    correctionMessage: 'Replace // with /// for documentation comments.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern to detect if comment starts with a capital letter.
  static final RegExp _startsWithCapital = RegExp(r'^[A-Z]');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check methods
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      // Skip if has doc comment
      if (node.documentationComment != null) return;

      // Check for regular comment above
      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });

    // Check functions
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme.startsWith('_')) return;
      if (node.documentationComment != null) return;

      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });

    // Check classes
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (node.name.lexeme.startsWith('_')) return;
      if (node.documentationComment != null) return;

      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });

    // Check fields
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (node.documentationComment != null) return;

      // Check if any variable is public
      bool hasPublicField = false;
      for (final VariableDeclaration variable in node.fields.variables) {
        if (!variable.name.lexeme.startsWith('_')) {
          hasPublicField = true;
          break;
        }
      }
      if (!hasPublicField) return;

      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });
  }

  void _checkPrecedingComment(Token token, SaropaDiagnosticReporter reporter) {
    Token? comment = token.precedingComments;

    // Look for the last regular comment before the declaration
    Token? lastRegularComment;
    while (comment != null) {
      final String lexeme = comment.lexeme;
      // Check if it's a regular comment that looks like documentation
      // (not a doc comment, not an ignore directive)
      if (lexeme.startsWith('//') &&
          !lexeme.startsWith('///') &&
          !lexeme.contains('ignore:') &&
          !lexeme.contains('ignore_for_file:')) {
        // Check if it looks like a documentation comment (describes the member)
        final String content = lexeme.substring(2).trim();
        if (content.isNotEmpty &&
            !content.startsWith('TODO') &&
            !content.startsWith('FIXME') &&
            !content.startsWith('NOTE') &&
            !content.startsWith('HACK') &&
            // Only flag if it looks like a description (starts with capital letter
            // or common doc patterns)
            (_startsWithCapital.hasMatch(content) ||
                content.startsWith('Returns') ||
                content.startsWith('Gets') ||
                content.startsWith('Sets') ||
                content.startsWith('The '))) {
          lastRegularComment = comment;
        }
      }
      comment = comment.next;
    }

    if (lastRegularComment != null) {
      reporter.atOffset(
        offset: lastRegularComment.offset,
        length: lastRegularComment.length,
        errorCode: code,
      );
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToDocCommentFix()];
}

class _ConvertToDocCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
      message: 'Convert to doc comment (///)',
      priority: 1,
    );

    changeBuilder.addDartFileEdit((builder) {
      // Replace // with ///
      // The error is at the comment, so we just need to insert an extra /
      builder.addSimpleInsertion(analysisError.offset + 2, '/');
    });
  }
}
