// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, todo, fixme

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../comment_utils.dart';
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v6
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
  PreferRelativeImportsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_relative_imports',
    '[prefer_relative_imports] An absolute package import was used for a file within the same package. Relative imports simplify refactoring and clearly signal local dependencies. Replace the absolute import with a relative path. {v6}',
    correctionMessage:
        'Relative imports make refactoring easier and clearly signal local dependencies within the package.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addImportDirective((ImportDirective node) {
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
      final String currentPath = context.filePath.replaceAll('\\', '/');

      // Extract package name from current path (e.g., /packages/my_app/lib/...)
      final RegExp packagePattern = RegExp(r'/([^/]+)/lib/');
      final RegExpMatch? match = packagePattern.firstMatch(currentPath);
      if (match == null) return;

      final String currentPackage = match.group(1) ?? '';

      // Only flag if importing from the SAME package
      if (importPackage == currentPackage) {
        reporter.atNode(uri);
      }
    });
  }
}

/// Warns when multiple widget classes are defined in a single file.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferOneWidgetPerFileRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_one_widget_per_file',
    '[prefer_one_widget_per_file] Multiple widget classes are defined in a single file, which makes it harder to locate widgets by filename. Move each widget class into its own file so names map directly to files for faster navigation. {v3}',
    correctionMessage:
        'Move each widget class to its own file so file names map directly to widget names for faster navigation.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferArrowFunctionsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_arrow_functions',
    '[prefer_arrow_functions] Function body contains only a single return statement. Block syntax adds unnecessary braces and visual noise for simple expressions; convert to arrow syntax (=>) to signal a pure, single-expression return. {v3}',
    correctionMessage:
        'Convert to arrow syntax (=> expression) to signal a pure, single-expression return and reduce visual noise.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check function declarations
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final FunctionExpression function = node.functionExpression;
      if (_shouldBeArrowFunction(function.body)) {
        reporter.atToken(node.name, code);
      }
    });

    // Check method declarations
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody? body = node.body;
      if (body != null && _shouldBeArrowFunction(body)) {
        reporter.atToken(node.name, code);
      }
    });

    // Check function expressions (lambdas)
    context.addFunctionExpression((FunctionExpression node) {
      // Skip if parent is a function declaration (already handled)
      if (node.parent is FunctionDeclaration) return;

      if (_shouldBeArrowFunction(node.body)) {
        reporter.atNode(node);
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
}

/// Warns when functions have multiple positional parameters that could be named.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferAllNamedParametersRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Threshold for number of positional parameters before suggesting named.
  static const int _threshold = 3;

  static const LintCode _code = LintCode(
    'prefer_all_named_parameters',
    '[prefer_all_named_parameters] Function has $_threshold or more positional parameters that lack self-documenting call sites. This is an opinionated rule - not included in any tier by default. {v2}',
    correctionMessage:
        'Convert positional parameters to named parameters so call sites are self-documenting and order-independent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      // Skip main function - it has a well-defined signature
      if (node.name.lexeme == 'main') return;

      _checkParameters(node.functionExpression.parameters, node.name, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip operator overloads - they have fixed signatures
      if (node.isOperator) return;

      // Skip overridden methods - they must match parent signature
      // Check for @override annotation
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') return;
      }

      _checkParameters(node.parameters, node.name, reporter);
    });

    context.addConstructorDeclaration((ConstructorDeclaration node) {
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  PreferTrailingCommaAlwaysRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_trailing_comma_always',
    '[prefer_trailing_comma_always] A multi-line argument list or collection is missing a trailing comma. Add one so dart format keeps each element on its own line, producing cleaner diffs and easier reordering. {v4}',
    correctionMessage:
        'Add a trailing comma so dart format keeps each argument on its own line, producing cleaner git diffs.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check argument lists
    context.addArgumentList((ArgumentList node) {
      if (node.arguments.isEmpty) return;
      if (!_isMultiLine(node)) return;

      final Token rightParen = node.rightParenthesis;
      final Token? lastToken = node.arguments.last.endToken;
      if (lastToken == null) return;

      // Check if there's a comma before the closing paren
      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightParen);
      }
    });

    // Check list literals
    context.addListLiteral((ListLiteral node) {
      if (node.elements.isEmpty) return;
      if (!_isMultiLine(node)) return;

      final Token rightBracket = node.rightBracket;
      final Token? lastToken = node.elements.last.endToken;
      if (lastToken == null) return;

      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightBracket);
      }
    });

    // Check set/map literals
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.elements.isEmpty) return;
      if (!_isMultiLine(node)) return;

      final Token rightBracket = node.rightBracket;
      final Token? lastToken = node.elements.last.endToken;
      if (lastToken == null) return;

      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightBracket);
      }
    });

    // Check parameter lists
    context.addFormalParameterList((FormalParameterList node) {
      if (node.parameters.isEmpty) return;
      if (!_isMultiLine(node)) return;

      final Token rightParen = node.rightParenthesis;
      final FormalParameter lastParam = node.parameters.last;
      final Token? lastToken = lastParam.endToken;
      if (lastToken == null) return;

      final Token? tokenAfterLast = lastToken.next;
      if (tokenAfterLast?.type != TokenType.COMMA) {
        reporter.atToken(rightParen);
      }
    });
  }

  bool _isMultiLine(AstNode node) {
    final CompilationUnit unit = node.root as CompilationUnit;
    final int startLine = unit.lineInfo.getLocation(node.offset).lineNumber;
    final int endLine = unit.lineInfo.getLocation(node.end).lineNumber;
    return endLine > startLine;
  }
}

/// Warns when private fields don't use underscore prefix consistently.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferPrivateUnderscorePrefixRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_private_underscore_prefix',
    '[prefer_private_underscore_prefix] Instance field is public without documentation, exposing internal state. This is an opinionated rule - not included in any tier by default. {v3}',
    correctionMessage:
        'Prefix with underscore to enforce encapsulation, then expose via a getter if external access is needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferWidgetMethodsOverClassesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Maximum number of lines in build method to suggest conversion.
  static const int _maxBuildLines = 5;

  static const LintCode _code = LintCode(
    'prefer_widget_methods_over_classes',
    '[prefer_widget_methods_over_classes] Simple widget class with a short build method detected. A separate class adds unnecessary boilerplate when the widget could be a method in the parent, giving direct access to parent state. {v2}',
    correctionMessage:
        'Convert to a build method in the parent widget to eliminate class boilerplate and access parent state directly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
///
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
/// // dynamic is acceptable when intentional (e.g., JSON)
/// ```
///
/// #### GOOD:
/// ```dart
/// String name = 'John';
/// final int count = 42;
/// List<String> items = <String>[];
/// ```
class PreferExplicitTypesRule extends SaropaLintRule {
  PreferExplicitTypesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_types',
    '[prefer_explicit_types] Variable uses var instead of an explicit type annotation. Without a visible type, readers must inspect the right-hand side or hover in the IDE to determine the declared type. {v4}',
    correctionMessage:
        'Replace var with the explicit type annotation so the declared type is visible without hovering or reading the initializer.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclarationList((VariableDeclarationList node) {
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

      // Note: 'dynamic' is an explicit type choice, not implicit like var/final.
      // Don't flag it - developers use it intentionally for JSON, etc.
    });
  }
}

/// Warns when methods return records instead of dedicated classes.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  PreferClassOverRecordReturnRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_class_over_record_return',
    '[prefer_class_over_record_return] Method returns a record type, which lacks named fields and dedicated methods. This is an opinionated rule - not included in any tier by default. {v4}',
    correctionMessage:
        'Create a class with named fields to improve IDE support, type documentation, and long-term maintainability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      _checkReturnType(node.returnType, node.name, reporter);
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
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
      reporter.atNode(returnType);
    }
  }
}

/// Warns when callbacks are extracted to separate methods/variables.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferInlineCallbacksRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_inline_callbacks',
    '[prefer_inline_callbacks] Callback references a separate method, forcing readers to jump away to understand behavior. This is an opinionated rule - not included in any tier by default. {v3}',
    correctionMessage:
        'Inline the callback body at the call site so the behavior is visible where the widget is constructed.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
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
        reporter.atNode(expression);
      }

      // Check if it's a prefixed identifier (this.onTap or widget.callback)
      if (expression is PrefixedIdentifier) {
        // Any prefixed identifier used as callback is a method/getter reference
        reporter.atNode(expression);
      }
    });
  }
}

/// Warns when double quotes are used instead of single quotes for strings.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v6
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
  PreferSingleQuotesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_single_quotes',
    '[prefer_single_quotes] Double quotes detected where single quotes would suffice. Prefer single quotes for consistency with Dart style conventions and to reduce visual noise in string literals. {v6}',
    correctionMessage:
        "Replace double quotes with single quotes to follow Dart style conventions and maintain codebase consistency.",
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
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
        reporter.atNode(node);
      }
    });

    // Also check multi-line strings with interpolation
    context.addStringInterpolation((StringInterpolation node) {
      final Token beginToken = node.beginToken;
      final String lexeme = beginToken.lexeme;

      // Skip raw strings
      if (lexeme.startsWith('r')) return;

      // Check if it starts with double quote (including """)
      if (lexeme.startsWith('"')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when TODO comments don't follow the standard format.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferTodoFormatRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_todo_format',
    '[prefer_todo_format] TODO comment is missing the required author and description format. Use TODO(author): description so the comment is trackable, searchable, and attributable to an owner. {v3}',
    correctionMessage:
        'Add author name in parentheses: TODO(author): ... so the TODO is trackable and searchable by owner.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferFixmeFormatRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_fixme_format',
    '[prefer_fixme_format] FIXME comment is missing the required author tag. Without an owner, FIXMEs become orphaned and unactionable; use the format FIXME(author): description so the issue is trackable. {v3}',
    correctionMessage:
        'Add author name in parentheses: FIXME(author): ... so the issue is trackable and searchable by owner.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
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
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  PreferSentenceCaseCommentsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_sentence_case_comments',
    '[prefer_sentence_case_comments] Comment starts with a lowercase letter. Inconsistent capitalization in comments reduces readability and gives the codebase an unfinished appearance. {v4}',
    correctionMessage:
        'Capitalize the first letter of the comment to maintain sentence-case consistency across the codebase.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Pattern for special comment markers that should be skipped.
  static final RegExp _specialMarkerPattern = RegExp(
    r'^(ignore|TODO|FIXME|NOTE|HACK|XXX|BUG|WARN|WARNING):?',
    caseSensitive: false,
  );

  /// Pattern for code-like references at start of comment.
  /// Matches: identifier followed by space, or identifier in prose context.
  static final RegExp _codeReferencePattern = RegExp(r'^[a-z_][a-zA-Z0-9_]*\s');

  /// Pattern for Dart keywords that typically start code statements.
  /// These indicate commented-out code rather than prose comments.
  static final RegExp _dartKeywordPattern = RegExp(
    r'^(return|if|else|for|while|do|switch|case|break|continue|'
    r'try|catch|finally|throw|rethrow|assert|'
    r'var|final|const|late|'
    r'void|int|double|bool|String|List|Map|Set|Future|Stream|'
    r'class|extends|implements|with|mixin|abstract|'
    r'import|export|part|library|'
    r'await|async|yield|'
    r'new|super|this|null|true|false|'
    r'get|set|operator|typedef|enum|extension|'
    r'static|external|factory|covariant|required|'
    r'show|hide|as|is|in|on|when)\b',
  );

  /// Pattern for commented-out code constructs.
  /// Matches: function calls, assignments, method chains, operators, etc.
  static final RegExp _commentedOutCodePattern = RegExp(
    // identifier followed by ( or . or = or ; or < or [ or {
    r'^[a-z_][a-zA-Z0-9_]*\s*[(.=;<\[{]|'
    // starts with underscore (private identifier)
    r'^_[a-zA-Z0-9_]+|'
    // contains semicolon (likely code)
    r';$|;\s|'
    // contains common code operators
    r'[+\-*/]=|'
    // arrow functions
    r'=>|'
    // generics
    r'<[A-Z][a-zA-Z0-9_,\s]*>',
  );

  /// Pattern for standalone code symbols (brackets, braces, etc.).
  /// These are typically part of commented-out code blocks.
  static final RegExp _codeSymbolOnlyPattern = RegExp(
    // Just brackets/braces/parens (with optional trailing content)
    r'^[\{\}\[\]\(\)]+\s*$|'
    // Closing bracket with comma or semicolon
    r'^[\}\]\)][,;]?\s*$|'
    // Opening bracket possibly with content
    r'^[\{\[\(]\s*\S|'
    // Increment/decrement
    r'\+\+|--|'
    // Ternary operator parts
    r'^\s*[?:]|'
    // Spread operator
    r'^\.\.\.|'
    // Null-aware operators
    r'\?\?|'
    // Cascade
    r'^\.\.',
  );

  /// Pattern to check if first character is lowercase letter.
  static final RegExp _lowercaseFirstChar = RegExp(r'^[a-z]');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
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

    // Skip commented-out code: lines starting with Dart keywords
    // e.g., "// return value;" or "// if (condition) {"
    if (_dartKeywordPattern.hasMatch(trimmed)) {
      return;
    }

    // Skip commented-out code: lines with code constructs
    // e.g., "// doSomething();" or "// value = 42;"
    if (_commentedOutCodePattern.hasMatch(trimmed)) {
      return;
    }

    // Skip commented-out code: standalone symbols like { } [ ] ( )
    // These are typically part of multi-line commented-out code blocks
    if (_codeSymbolOnlyPattern.hasMatch(trimmed)) {
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
}

/// Warns when doc comments don't end with a period.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferPeriodAfterDocRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_period_after_doc',
    '[prefer_period_after_doc] Doc comment missing period at end. Incomplete sentences reduce clarity and professionalism in API docs. {v3}',
    correctionMessage:
        'Add a period at the end of every doc comment sentence. Example: /// Returns the user name.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Pattern to strip the doc comment prefix (/// or ///).
  static final RegExp _docPrefixPattern = RegExp(r'^///\s*');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check class declarations
    context.addClassDeclaration((ClassDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check method declarations
    context.addMethodDeclaration((MethodDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check function declarations
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check field declarations
    context.addFieldDeclaration((FieldDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check top-level variables
    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    // Check enum declarations
    context.addEnumDeclaration((EnumDeclaration node) {
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
      reporter.atToken(lastToken);
    }
  }
}

/// Warns when constants don't use SCREAMING_SNAKE_CASE.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v5
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
  PreferScreamingCaseConstantsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_screaming_case_constants',
    '[prefer_screaming_case_constants] Constant name does not use SCREAMING_SNAKE_CASE convention. Without visual distinction, constants blend with regular variables and their immutable intent is lost. {v5}',
    correctionMessage:
        'Rename the constant to SCREAMING_SNAKE_CASE (e.g., MAX_VALUE instead of maxValue) for visual distinction.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check top-level constants
    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
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
    context.addFieldDeclaration((FieldDeclaration node) {
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
}

/// Warns when boolean variables/parameters don't use descriptive prefixes.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v5
///
/// This rule is suitable for the **professional** tier.
///
/// This is the lenient version that allows action verb prefixes (like
/// `processData`, `sortItems`, `removeEntry`) in addition to standard boolean
/// prefixes. For stricter enforcement, use `prefer_descriptive_bool_names_strict`.
///
/// Boolean names should use prefixes like `is`, `has`, `can`, `should`, `will`,
/// `was`, `did`, `does`, or action verbs to make their purpose clear.
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
/// bool processData = true;  // Action verb - allowed in lenient mode
/// bool sortAlphabetically = true;  // Action verb - allowed
/// void setEnabled(bool isEnabled) { ... }
/// ```
///
/// See also: [PreferDescriptiveBoolNamesStrictRule] for stricter enforcement.
class PreferDescriptiveBoolNamesRule extends SaropaLintRule {
  PreferDescriptiveBoolNamesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_descriptive_bool_names',
    '[prefer_descriptive_bool_names] Boolean should use a descriptive prefix (is, has, can, should, etc.) or action verb. This rule is suitable for the professional tier. {v5}',
    correctionMessage:
        'Rename with a descriptive prefix: isEnabled, hasData, canEdit, shouldUpdate, or an action verb like processData.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Valid boolean prefixes (state-based)
  static final RegExp _validBoolPrefix = RegExp(
    r'^(is|has|have|can|should|will|was|did|does|allow|enable|disable|show|hide|include|exclude)[A-Z]',
  );

  /// Valid action verb prefixes (allowed in lenient mode)
  static final RegExp _actionVerbPrefix = RegExp(
    r'^(process|sort|remove|update|create|validate|fetch|build|compute|get|set|load|save|refresh|clear|reset|toggle|submit|apply|execute|run|start|stop|pause|resume|send|receive|handle|perform|calculate|generate|parse|format|transform|convert|filter|search|find|check|verify|confirm|accept|reject|approve|deny|skip|ignore|use|need|want|require|prefer|force|auto|try|await|defer|delay|cache|store|retrieve|delete|add|insert|append|prepend|merge|split|join|concat|trim|truncate|normalize|sanitize|encode|decode|encrypt|decrypt|compress|decompress|serialize|deserialize|render|display|print|log|trace|debug|notify|alert|warn|error|throw|catch|retry|fallback|override|replace|swap|move|copy|clone|duplicate|mirror|sync|async|batch|queue|schedule|dispatch|emit|broadcast|publish|subscribe|unsubscribe|listen|watch|observe|monitor|track|measure|record|capture|snapshot|restore|backup|export|import|upload|download|stream|buffer|flush|drain|pipe|pump|push|pop|shift|unshift|enqueue|dequeue)[A-Z]',
  );

  /// Also allow common boolean suffixes
  static final RegExp _validBoolSuffix = RegExp(
    r'(Enabled|Disabled|Visible|Hidden|Active|Valid|Invalid|Empty|Loading|Loaded|Complete|Done|Open|Closed|Required|Optional|Selected|Checked|Available|Initialized|Value)$',
  );

  /// Set of allowed boolean type representations.
  static const Set<String> _boolTypes = <String>{'bool', 'bool?'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check variable declarations
    context.addVariableDeclaration((VariableDeclaration node) {
      final element = node.declaredFragment?.element;
      if (element == null) return;

      // Check for bool or bool?
      final String typeStr = element.type.toString();
      if (!_boolTypes.contains(typeStr)) return;

      _checkName(node.name, reporter);
    });

    // Check parameters
    context.addSimpleFormalParameter((SimpleFormalParameter node) {
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
    context.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final element = variable.declaredFragment?.element;
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
    if (_actionVerbPrefix.hasMatch(name)) return;
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
      'value', // Common in generic contexts
    };
    if (allowedNames.contains(name.toLowerCase())) return;

    reporter.atToken(nameToken);
  }
}

/// Quick fix that adds "is" prefix to boolean names.
///
/// Transforms names like `loading` → `isLoading`, `visible` → `isVisible`.
/// For unknown names, simply prefixes with "is" and capitalizes.

/// Warns when boolean variables/parameters don't use descriptive prefixes.
///
/// Since: v3.1.1 | Updated: v4.13.0 | Rule version: v3
///
/// This rule is suitable for the **pedantic** tier.
///
/// This is the strict version that only allows traditional boolean prefixes
/// like `is`, `has`, `can`, `should`. Action verbs like `processData` are NOT
/// allowed. For a more lenient version, use `prefer_descriptive_bool_names`.
///
/// **When to use this rule:**
/// - Greenfield projects with strict naming conventions
/// - Teams that want all booleans to read as questions/states
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// bool loading = true;
/// bool processData = true;  // Not allowed - use shouldProcessData
/// bool sortAlphabetically = true;  // Not allowed - use shouldSortAlphabetically
/// ```
///
/// #### GOOD:
/// ```dart
/// bool isLoading = true;
/// bool shouldProcessData = true;
/// bool shouldSortAlphabetically = true;
/// ```
///
/// See also: [PreferDescriptiveBoolNamesRule] for lenient enforcement.
class PreferDescriptiveBoolNamesStrictRule extends SaropaLintRule {
  PreferDescriptiveBoolNamesStrictRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_descriptive_bool_names_strict',
    '[prefer_descriptive_bool_names_strict] Boolean should use a descriptive prefix (is, has, can, should, etc.). This rule is suitable for the pedantic tier. {v3}',
    correctionMessage:
        'Rename with a descriptive boolean prefix: isEnabled, hasData, canEdit, shouldUpdate, doesExist, or willChange.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check variable declarations
    context.addVariableDeclaration((VariableDeclaration node) {
      final element = node.declaredFragment?.element;
      if (element == null) return;

      // Check for bool or bool?
      final String typeStr = element.type.toString();
      if (!_boolTypes.contains(typeStr)) return;

      _checkName(node.name, reporter);
    });

    // Check parameters
    context.addSimpleFormalParameter((SimpleFormalParameter node) {
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
    context.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final element = variable.declaredFragment?.element;
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

    reporter.atToken(nameToken);
  }
}

/// Warns when Dart file names don't use snake_case.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  PreferSnakeCaseFilesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_snake_case_files',
    '[prefer_snake_case_files] File name does not follow snake_case convention. Non-standard file names break import autocompletion and make the project structure harder to navigate on case-sensitive file systems. {v4}',
    correctionMessage:
        'Rename the file to snake_case (e.g., user_service.dart instead of UserService.dart) to follow Dart conventions.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Pattern for valid snake_case base names (without extension).
  static final RegExp _snakeCasePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Generated file suffixes that should be skipped entirely.
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

  /// Multi-part extensions that are allowed and should be stripped
  /// before validating the base name.
  ///
  /// Format: base_name.suffix.dart (e.g., contact_star_wars.io.dart)
  static const List<String> _allowedMultiPartExtensions = <String>[
    '.io.dart', // Input/output or data transfer files
    '.dto.dart', // Data transfer objects
    '.model.dart', // Model files
    '.entity.dart', // Entity files
    '.service.dart', // Service files
    '.repository.dart', // Repository files
    '.controller.dart', // Controller files
    '.provider.dart', // Provider files
    '.bloc.dart', // BLoC files
    '.cubit.dart', // Cubit files
    '.state.dart', // State files
    '.event.dart', // Event files
    '.notifier.dart', // Notifier files
    '.view.dart', // View files
    '.widget.dart', // Widget files
    '.screen.dart', // Screen files
    '.page.dart', // Page files
    '.dialog.dart', // Dialog files
    '.violation_parser.dart', // Utils files
    '.helper.dart', // Helper files
    '.extension.dart', // Extension files
    '.mixin.dart', // Mixin files
    '.test.dart', // Test files
    '.mock.dart', // Mock files
    '.stub.dart', // Stub files
    '.fake.dart', // Fake files
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      final String fullPath = context.filePath.replaceAll('\\', '/');
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

      // Extract the base name by stripping known extensions
      final String baseName = _extractBaseName(fileName);

      if (!_snakeCasePattern.hasMatch(baseName)) {
        // Report at the library directive if present, otherwise at the first token
        final LibraryDirective? library = unit.directives
            .whereType<LibraryDirective>()
            .firstOrNull;
        if (library != null) {
          reporter.atNode(library);
        } else {
          // Report at the beginning of the file
          reporter.atOffset(offset: 0, length: 1, errorCode: code);
        }
      }
    });
  }

  /// Extracts the base name from a file, stripping known extensions.
  ///
  /// For `user_service.dart` returns `user_service`.
  /// For `contact.io.dart` returns `contact`.
  /// For `my_bloc.bloc.dart` returns `my_bloc`.
  static String _extractBaseName(String fileName) {
    // Check multi-part extensions first (longer suffixes)
    for (final String ext in _allowedMultiPartExtensions) {
      if (fileName.endsWith(ext)) {
        return fileName.substring(0, fileName.length - ext.length);
      }
    }

    // Fall back to stripping just .dart
    if (fileName.endsWith('.dart')) {
      return fileName.substring(0, fileName.length - 5);
    }

    return fileName;
  }
}

/// Warns when text size is smaller than the recommended minimum.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  AvoidSmallTextRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  /// Minimum font size in logical pixels.
  static const double _minFontSize = 12.0;

  static const LintCode _code = LintCode(
    'avoid_small_text',
    '[avoid_small_text] Font size is smaller than $_minFontSize, which reduces readability for users with low vision. This is an opinionated rule - not included in any tier by default. Default minimum is 12 logical pixels. {v4}',
    correctionMessage:
        'Use a font size of at least $_minFontSize to meet accessibility readability guidelines for body text.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          reporter.atNode(arg);
        }
      }
    }
  }
}

/// Warns when regular comments (`//`) are used instead of doc comments (`///`)
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v5
///
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
  PreferDocCommentsOverRegularRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_doc_comments_over_regular',
    '[prefer_doc_comments_over_regular] Use doc comments (///) instead of regular comments (//) for public API documentation. This is an opinionated rule - not included in any tier by default. {v5}',
    correctionMessage:
        'Replace // with /// so the comment appears in IDE hover docs and can be extracted by dartdoc for API reference.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Pattern to detect if comment starts with a capital letter.
  static final RegExp _startsWithCapital = RegExp(r'^[A-Z]');

  /// Pattern to detect annotation markers like TODO:, FIX:, NOTE:, HACK:, etc.
  /// Matches uppercase words followed by optional colon at the start.
  static final RegExp _annotationMarker = RegExp(
    r'^(TODO|FIXME|FIX|NOTE|HACK|XXX|BUG|OPTIMIZE|WARNING|CHANGED|REVIEW|DEPRECATED|IMPORTANT|MARK)\b',
    caseSensitive: false,
  );

  /// Pattern to detect commented-out code.
  /// Matches lines that look like Dart code rather than documentation.
  static final RegExp _commentedOutCode = RegExp(
    r'^('
    // Type declarations with variable names (e.g., "String? get", "int foo")
    r'(String|int|double|bool|num|void|dynamic|var|final|const|late|List|Map|Set|Future|Stream)\b'
    r'|'
    // Return statements
    r'return\s'
    r'|'
    // Control flow
    r'(if|else|for|while|switch|case|break|continue|try|catch|finally|throw)\s*[\(\{]?'
    r'|'
    // Assignment or arrow functions
    r'\w+\s*(=|=>)\s*'
    r'|'
    // Method calls or property access starting a line
    r'(this|super)\.'
    r'|'
    // Closing braces/brackets or semicolons typical of code
    r'[\}\];]\s*$'
    r'|'
    // Import/export statements
    r"(import|export|part)\s+['"
    r'"]'
    r'|'
    // Class/method modifiers
    r'(abstract|static|override|async|await)\s'
    r')',
    caseSensitive: true,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check methods
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      // Skip if has doc comment
      if (node.documentationComment != null) return;

      // Check for regular comment above
      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });

    // Check functions
    context.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme.startsWith('_')) return;
      if (node.documentationComment != null) return;

      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });

    // Check classes
    context.addClassDeclaration((ClassDeclaration node) {
      if (node.name.lexeme.startsWith('_')) return;
      if (node.documentationComment != null) return;

      _checkPrecedingComment(node.firstTokenAfterCommentAndMetadata, reporter);
    });

    // Check fields
    context.addFieldDeclaration((FieldDeclaration node) {
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
        // Skip annotation markers like TODO:, FIX:, NOTE:, HACK:, etc.
        if (_annotationMarker.hasMatch(content)) {
          comment = comment.next;
          continue;
        }

        // Skip commented-out code
        if (_commentedOutCode.hasMatch(content)) {
          comment = comment.next;
          continue;
        }

        // Only flag if it looks like a description (starts with capital letter
        // or common doc patterns)
        if (content.isNotEmpty &&
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
}

// cspell:ignore Brien
/// Warns when stylized (curly) apostrophes are used instead of straight apostrophes.
///
/// Since: v4.2.3 | Updated: v4.13.0 | Rule version: v5
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// Code should use straight/ASCII apostrophes (') (U+0027) rather than
/// Right Single Quotation Mark (\u2019) (U+2019) or Left Single Quotation Mark (\u2018) (U+2018).
/// Curly apostrophes are for typography in prose, not code.
///
/// **Pros of straight apostrophes:**
/// - Standard in code and programming
/// - Consistent with source code conventions
/// - Easier to type and search for
/// - No Unicode confusion
///
/// **Cons (why some teams use curly apostrophes):**
/// - More typographic/professional appearance
/// - Used in formal documentation strings
/// - Habit from writing tools (Word, etc.)
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// String message = 'It\u2019s a beautiful day';  // Right Single Quotation Mark (U+2019)
/// String name = 'O\u2019Brien';                  // Right Single Quotation Mark (U+2019)
/// ```
///
/// #### GOOD:
/// ```dart
/// String message = 'It\'s a beautiful day';  // ASCII apostrophe with escape
/// String name = "O'Brien";                   // ASCII apostrophe in double quotes
/// ```
class PreferStraightApostropheRule extends SaropaLintRule {
  PreferStraightApostropheRule() : super(code: _code);

  /// Stylistic rule - style/consistency issues are acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_straight_apostrophe',
    "[prefer_straight_apostrophe] A Right Single Quotation Mark (U+2019) was found where a straight apostrophe (U+0027) is expected. Curly quotes cause inconsistent string delimiters and can break tooling. Replace with a straight apostrophe. {v5}",
    correctionMessage:
        "Replace the Right Single Quotation Mark (U+2019) with a straight apostrophe (U+0027) for code consistency.",
    severity: DiagnosticSeverity.INFO,
  );

  /// Unicode Right Single Quotation Mark (U+2019)
  static const String rightSingleQuote = '\u2019';

  /// Unicode Left Single Quotation Mark (U+2018)
  static const String leftSingleQuote = '\u2018';

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Check for curly apostrophes
      if (value.contains(rightSingleQuote) || value.contains(leftSingleQuote)) {
        reporter.atNode(node);
      }
    });

    // Also check string interpolations
    context.addStringInterpolation((StringInterpolation node) {
      final String value = node.toString();
      if (value.contains(rightSingleQuote) || value.contains(leftSingleQuote)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when straight apostrophes are used instead of stylized (curly) apostrophes.
///
/// Since: v4.2.3 | Updated: v4.13.0 | Rule version: v5
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// For documentation and user-facing strings, Right Single Quotation Mark (\u2019) (U+2019)
/// provides better typography than straight ASCII apostrophes (') (U+0027).
/// This is the inverse of [PreferStraightApostropheRule].
///
/// **Pros of Right Single Quotation Mark:**
/// - Better typography in user-facing text
/// - Professional appearance in documentation
/// - Common in publishing and design
/// - More readable for prose
///
/// **Cons (why some teams avoid them):**
/// - Code convention is straight apostrophes
/// - Can be confusing when mixed with code
/// - Harder to type on some keyboards (use copy/paste or compose key)
/// - May not display correctly in some contexts
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// /// It's a beautiful day.  // Straight ASCII apostrophe (U+0027)
/// String avoid_generic_greeting_text = 'Hello';
/// ```
///
/// #### GOOD:
/// ```dart
/// /// It's a beautiful day.  // Right Single Quotation Mark (U+2019)
/// String avoid_generic_greeting_text = 'Hello';
/// ```
class PreferDocCurlyApostropheRule extends SaropaLintRule {
  PreferDocCurlyApostropheRule() : super(code: _code);

  /// Stylistic rule - style/consistency issues are acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_doc_curly_apostrophe',
    "[prefer_doc_curly_apostrophe] Use Right Single Quotation Mark (') instead of straight apostrophe (') in documentation. This is an opinionated rule - not included in any tier by default. {v5}",
    correctionMessage:
        "Replace the straight apostrophe with a Right Single Quotation Mark (U+2019) for typographic correctness.",
    severity: DiagnosticSeverity.INFO,
  );

  /// ASCII straight apostrophe (U+0027)
  static const String straightApostrophe = "'";

  /// Unicode Right Single Quotation Mark (U+2019)
  static const String curlyApostrophe = '\u2019';

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check doc comments (where typography matters most)
    context.addClassDeclaration((ClassDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addFieldDeclaration((FieldDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });
  }

  void _checkDocComment(Comment? comment, SaropaDiagnosticReporter reporter) {
    if (comment == null) return;

    final List<Token> tokens = comment.tokens;
    for (final Token token in tokens) {
      final String lexeme = token.lexeme;

      // Only check doc comments
      if (!lexeme.startsWith('///')) continue;

      // Check if it contains straight apostrophes that could be curly
      // Look for contractions: don't, won't, can't, it's, etc.
      if (lexeme.contains("'")) {
        // Simple heuristic: if it looks like a contraction, suggest curly
        final RegExp contractionCheck = RegExp(
          r"(don't|won't|can't|shouldn't|wouldn't|isn't|aren't|"
          r"hasn't|haven't|wasn't|weren't|let's|it's|there's|"
          r"here's|we'll|I've|I'm|you're|they're|that's)",
        );

        if (contractionCheck.hasMatch(lexeme)) {
          reporter.atToken(token);
        }
      }
    }
  }
}

/// Warns when stylized (curly) apostrophes are used instead of straight apostrophes
///
/// Since: v4.2.3 | Updated: v4.13.0 | Rule version: v4
///
/// in documentation comments.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// For documentation comments, some teams prefer straight/ASCII apostrophes (')
/// (U+0027) rather than Right Single Quotation Mark (\u2019) (U+2019).
/// This is the inverse of [PreferDocCurlyApostropheRule].
///
/// **Pros of straight apostrophes in docs:**
/// - Consistent with code conventions
/// - Easier to type and search for
/// - No Unicode confusion
/// - Works in all editors and terminals
///
/// **Cons (why some teams use curly apostrophes):**
/// - Better typography in rendered documentation
/// - More professional appearance
/// - Common in publishing
///
/// **Quick fix available:** Replaces curly apostrophes with straight ones.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// /// It's a beautiful day.  // Right Single Quotation Mark (U+2019)
/// void greet() {}
/// ```
///
/// #### GOOD:
/// ```dart
/// /// It's a beautiful day.  // ASCII apostrophe (U+0027)
/// void greet() {}
/// ```
class PreferDocStraightApostropheRule extends SaropaLintRule {
  PreferDocStraightApostropheRule() : super(code: _code);

  /// Stylistic rule - style/consistency issues are acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_doc_straight_apostrophe',
    "[prefer_doc_straight_apostrophe] Use straight apostrophe (') instead of Right Single Quotation Mark (') in documentation. This is an opinionated rule - not included in any tier by default. {v4}",
    correctionMessage:
        "Replace the Right Single Quotation Mark (U+2019) with a straight apostrophe (U+0027) for plain text docs.",
    severity: DiagnosticSeverity.INFO,
  );

  /// Unicode Right Single Quotation Mark (U+2019)
  static const String rightSingleQuote = '\u2019';

  /// Unicode Left Single Quotation Mark (U+2018)
  static const String leftSingleQuote = '\u2018';

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check doc comments
    context.addClassDeclaration((ClassDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addFieldDeclaration((FieldDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });

    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      _checkDocComment(node.documentationComment, reporter);
    });
  }

  void _checkDocComment(Comment? comment, SaropaDiagnosticReporter reporter) {
    if (comment == null) return;

    final List<Token> tokens = comment.tokens;
    for (final Token token in tokens) {
      final String lexeme = token.lexeme;

      // Only check doc comments
      if (!lexeme.startsWith('///')) continue;

      // Check if it contains curly apostrophes
      if (lexeme.contains(rightSingleQuote) ||
          lexeme.contains(leftSingleQuote)) {
        reporter.atToken(token);
      }
    }
  }
}

/// Warns when straight apostrophes are used instead of stylized (curly) apostrophes
///
/// Since: v4.2.3 | Updated: v4.13.0 | Rule version: v4
///
/// in string literals.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// For user-facing strings, Right Single Quotation Mark (\u2019) (U+2019)
/// provides better typography than straight ASCII apostrophes (') (U+0027).
/// This is the inverse of [PreferStraightApostropheRule].
///
/// **Pros of curly apostrophes in strings:**
/// - Better typography in user-facing text
/// - Professional appearance
/// - Common in publishing and design
/// - More readable for prose
///
/// **Cons (why some teams avoid them):**
/// - Code convention is straight apostrophes
/// - Harder to type on some keyboards
/// - May not display correctly in some contexts
/// - Can be confusing when mixed with code
///
/// **Quick fix available:** Replaces straight apostrophes with curly ones in
/// common contractions and proper names.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// String message = "It's a beautiful day";  // Straight ASCII apostrophe (U+0027)
/// String name = "O'Brien";                   // Straight ASCII apostrophe (U+0027)
/// ```
///
/// #### GOOD:
/// ```dart
/// String message = "It's a beautiful day";  // Right Single Quotation Mark (U+2019)
/// String name = "O'Brien";                   // Right Single Quotation Mark (U+2019)
/// ```
class PreferCurlyApostropheRule extends SaropaLintRule {
  PreferCurlyApostropheRule() : super(code: _code);

  /// Stylistic rule - style/consistency issues are acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_curly_apostrophe',
    "[prefer_curly_apostrophe] Use Right Single Quotation Mark (') instead of straight apostrophe (') in strings. This is an opinionated rule - not included in any tier by default. {v4}",
    correctionMessage:
        "Replace the straight apostrophe with a Right Single Quotation Mark (U+2019) for typographic polish in strings.",
    severity: DiagnosticSeverity.INFO,
  );

  /// ASCII straight apostrophe (U+0027)
  static const String straightApostrophe = "'";

  /// Unicode Right Single Quotation Mark (U+2019)
  static const String curlyApostrophe = '\u2019';

  /// Regex to detect common contractions with straight apostrophes.
  /// Static to avoid recreation on every node visit.
  // cspell:ignore shouldn wouldn aren hasn wasn weren
  static final RegExp _contractionCheck = RegExp(
    r"(don't|won't|can't|shouldn't|wouldn't|isn't|aren't|"
    r"hasn't|haven't|wasn't|weren't|let's|it's|there's|"
    r"here's|we'll|I've|I'm|you're|they're|that's|"
    r"o'clock|O'Brien|O'Connor|O'Hara|O'Malley|O'Neill|"
    r"'s\b|'t\b|'ll\b|'ve\b|'re\b|'m\b|'d\b)",
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (_contractionCheck.hasMatch(value)) {
        reporter.atNode(node);
      }
    });

    // Also check string interpolations
    context.addStringInterpolation((StringInterpolation node) {
      final String value = node.toString();

      if (_contractionCheck.hasMatch(value)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when named arguments in function calls are not in alphabetical order.
///
/// Since: v4.8.2 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// Consistent argument ordering at call sites improves readability and makes
/// it easier to scan for specific arguments, especially in constructors with
/// many parameters (common in Flutter widgets).
///
/// **Pros of alphabetical argument ordering:**
/// - Easy to find specific arguments in long argument lists
/// - Consistent ordering across the codebase
/// - Cleaner diffs when adding/removing arguments
///
/// **Cons (why some teams prefer other orderings):**
/// - Logical grouping may be more intuitive than alphabetical
/// - Required parameters first may be preferred
/// - May conflict with auto-generated code
///
/// Note: This rule only checks named arguments. Positional arguments are
/// not checked since their order is determined by the function signature.
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(
///   width: 100,
///   height: 50,      // 'height' should come before 'width'
///   color: Colors.blue,  // 'color' should come before 'height'
///   child: Text('Hello'),  // 'child' should come before 'color'
/// );
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(
///   child: Text('Hello'),
///   color: Colors.blue,
///   height: 50,
///   width: 100,
/// );
/// ```
///
/// Formerly: `enforce_arguments_ordering`
class ArgumentsOrderingRule extends SaropaLintRule {
  ArgumentsOrderingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases => const <String>[
    'enforce_arguments_ordering',
    'arguments_ordering',
  ];

  static const LintCode _code = LintCode(
    'prefer_arguments_ordering',
    '[prefer_arguments_ordering] Named arguments are not in alphabetical order. Unsorted arguments force reviewers to scan the entire call site to spot missing or duplicated parameters. {v3}',
    correctionMessage:
        'Reorder named arguments alphabetically so reviewers can quickly spot missing or duplicate arguments.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addArgumentList((ArgumentList node) {
      // Extract only named arguments
      final List<NamedExpression> namedArgs = <NamedExpression>[];
      for (final Expression arg in node.arguments) {
        if (arg is NamedExpression) {
          namedArgs.add(arg);
        }
      }

      // Need at least 2 named arguments to check ordering
      if (namedArgs.length < 2) return;

      // Check if named arguments are in alphabetical order
      for (int i = 1; i < namedArgs.length; i++) {
        final String currentName = namedArgs[i].name.label.name;
        final String previousName = namedArgs[i - 1].name.label.name;

        if (currentName.compareTo(previousName) < 0) {
          // Found an argument that should come before the previous one
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

// ============================================================================
// COMMENTED-OUT CODE DETECTION
// ============================================================================

/// Warns when commented-out code is detected.
///
/// Since: v4.3.0 | Updated: v4.13.0 | Rule version: v4
///
/// Commented-out code clutters the codebase and creates confusion about intent.
/// It's better to delete unused code - version control preserves history if you
/// need to restore it later.
///
/// This is an **opinionated rule** - not included in any tier by default.
/// Enable it for greenfield projects or teams that want clean codebases.
///
/// **Detection heuristics for commented-out code:**
/// - Dart keywords at start: `// return`, `// if (`, `// final x`
/// - Type declarations: `// int value`, `// String name`
/// - Function/method calls: `// doSomething()`, `// list.add(item)`
/// - Property access: `// foo.bar`, `// widget.build()`
/// - Assignments: `// x = 5`, `// name = "test"`
/// - Annotations: `// @override`, `// @deprecated`
/// - Import/export statements: `// import 'package:...'`
/// - Class/enum declarations: `// class Foo {`, `// enum Status {`
/// - Block delimiters: `// }`, `// {`
///
/// **Skipped patterns (not flagged):**
/// - TODO/FIXME/NOTE markers: `// TODO: implement this`
/// - Lint ignores: `// ignore: unused_variable`
/// - Documentation references: `// See: https://...`
///
/// **BAD:**
/// ```dart
/// void example() {
///   // final oldValue = compute();
///   // if (condition) {
///   //   doSomething();
///   // }
///   final newValue = computeNew();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void example() {
///   // Compute the new value using the updated algorithm
///   final newValue = computeNew();
/// }
/// ```
///
/// **Quick fix available:** Deletes the commented-out code line.
///
/// See also: [CommentPatterns] for shared detection heuristics.
///
/// Formerly: `avoid_commented_out_code`
class AvoidCommentedOutCodeRule extends SaropaLintRule {
  AvoidCommentedOutCodeRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases => const <String>['avoid_commented_out_code'];

  static const LintCode _code = LintCode(
    'prefer_no_commented_out_code',
    '[prefer_no_commented_out_code] Commented-out code clutters the codebase. '
        'Delete it - git preserves history. Prose comments and special markers '
        'like TODO, FIXME, and test directives are automatically skipped. {v5}',
    correctionMessage:
        'Delete the commented-out code. Use version control to retrieve it if needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        Token? commentToken = token.precedingComments;

        while (commentToken != null) {
          final String lexeme = commentToken.lexeme;

          // Only check single-line comments (not doc comments)
          if (lexeme.startsWith('//') && !lexeme.startsWith('///')) {
            final String content = lexeme.substring(2).trim();

            // Skip empty comments
            if (content.isEmpty) {
              commentToken = commentToken.next;
              continue;
            }

            // Skip special markers (TODO, FIXME, ignore, etc)
            if (CommentPatterns.isSpecialMarker(content)) {
              commentToken = commentToken.next;
              continue;
            }

            // Flag if this looks like commented-out code
            if (CommentPatterns.isLikelyCode(content)) {
              reporter.atToken(commentToken);
            }
          }

          commentToken = commentToken.next;
        }

        token = token.next;
      }
    });
  }
}

/// Quick fix that deletes the commented-out code line.
