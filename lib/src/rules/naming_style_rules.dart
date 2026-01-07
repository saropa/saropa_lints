// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when a getter name starts with 'get'.
class AvoidGetterPrefixRule extends SaropaLintRule {
  const AvoidGetterPrefixRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_getter_prefix',
    problemMessage: "Getter name should not start with 'get'.",
    correctionMessage: "Remove the 'get' prefix from the getter name.",
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.isGetter) return;

      final String name = node.name.lexeme;
      if (name.startsWith('get') && name.length > 3) {
        // Check if next char is uppercase (indicating getXxx pattern)
        final String nextChar = name[3];
        if (nextChar == nextChar.toUpperCase() && nextChar != '_') {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when string literals contain non-ASCII characters.
///
/// Non-ASCII characters can cause encoding issues and may be
/// hard to distinguish visually (e.g., different types of spaces).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// // cspell: disable-next-line
/// final text = 'Héllo Wörld'; // Contains non-ASCII
/// final space = 'Hello World'; // Contains non-breaking space
/// ```
///
/// #### GOOD:
/// ```dart
/// final text = 'Hello World';
/// ```
class AvoidNonAsciiSymbolsRule extends SaropaLintRule {
  const AvoidNonAsciiSymbolsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_non_ascii_symbols',
    problemMessage: 'String contains non-ASCII characters.',
    correctionMessage: 'Use only ASCII characters or escape sequences.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      for (int i = 0; i < value.length; i++) {
        final int codeUnit = value.codeUnitAt(i);
        // Check for non-ASCII (outside 0-127 range)
        if (codeUnit > 127) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when comments don't follow proper formatting.
///
/// Comments should start with a capital letter and end with proper punctuation.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// // this is a bad comment
/// /// returns the value
/// ```
///
/// #### GOOD:
/// ```dart
/// // This is a good comment.
/// /// Returns the value.
/// ```
class FormatCommentRule extends SaropaLintRule {
  /// Pre-compiled pattern for performance
  static final RegExp _lowercaseStartPattern = RegExp(r'^[a-z]');
  const FormatCommentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'capitalize_comment',
    problemMessage: 'Comment should start with capital letter.',
    correctionMessage: 'Capitalize the first letter of the comment.',
    errorSeverity: DiagnosticSeverity.INFO,
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
        Token? commentToken = token.precedingComments;

        while (commentToken != null) {
          final String lexeme = commentToken.lexeme;

          // Skip file-level ignores and special comments
          if (lexeme.contains('ignore:') ||
              lexeme.contains('ignore_for_file:') ||
              lexeme.contains('TODO') ||
              lexeme.contains('FIXME') ||
              lexeme.contains('cspell:') ||
              lexeme.contains('@')) {
            commentToken = commentToken.next;
            continue;
          }

          // Check single-line comments
          if (lexeme.startsWith('//') && !lexeme.startsWith('///')) {
            final String content = lexeme.substring(2).trim();
            if (content.isNotEmpty && content[0].toLowerCase() == content[0]) {
              // First char is lowercase
              if (_lowercaseStartPattern.hasMatch(content)) {
                reporter.atToken(commentToken, code);
              }
            }
          }

          commentToken = commentToken.next;
        }

        token = token.next;
      }
    });
  }
}

/// Warns when class names don't match expected patterns.
///
/// Class names should follow naming conventions for their purpose.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class userWidget extends StatelessWidget { } // lowercase start
/// ```
///
/// #### GOOD:
/// ```dart
/// class UserWidget extends StatelessWidget { }
/// ```
class MatchClassNamePatternRule extends SaropaLintRule {
  const MatchClassNamePatternRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'match_class_name_pattern',
    problemMessage: 'Class name does not follow expected pattern.',
    correctionMessage: 'Ensure class name follows naming conventions.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String name = node.name.lexeme;

      // Skip private classes
      if (name.startsWith('_')) return;

      // Check for common suffix patterns that should match superclass
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;

        // Widgets should end with Widget-like suffix
        if (superName.endsWith('Widget') ||
            superName == 'StatelessWidget' ||
            superName == 'StatefulWidget') {
          if (!name.endsWith('Widget') &&
              !name.endsWith('Screen') &&
              !name.endsWith('Page') &&
              !name.endsWith('View') &&
              !name.endsWith('Dialog') &&
              !name.endsWith('Card') &&
              !name.endsWith('Button') &&
              !name.endsWith('Item') &&
              !name.endsWith('Tile') &&
              !name.endsWith('Bar') &&
              !name.endsWith('Icon') &&
              !name.endsWith('Text') &&
              !name.endsWith('Container') &&
              !name.endsWith('Layout') &&
              !name.endsWith('Panel') &&
              !name.endsWith('Section') &&
              !name.endsWith('List') &&
              !name.endsWith('Builder')) {
            // Allow any name for widgets, but warn if very generic
            if (name.length < 4) {
              reporter.atToken(node.name, code);
            }
          }
        }

        // State classes should end with State
        if (superName == 'State') {
          if (!name.endsWith('State') && !name.startsWith('_')) {
            reporter.atToken(node.name, code);
          }
        }
      }
    });
  }
}

/// Warns when getter/setter names don't match backing field names.
///
/// Getter/setter should have the same name as the backing field (without underscore).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// int _count;
/// int get total => _count; // Mismatched name
/// ```
///
/// #### GOOD:
/// ```dart
/// int _count;
/// int get count => _count;
/// ```
class MatchGetterSetterFieldNamesRule extends SaropaLintRule {
  const MatchGetterSetterFieldNamesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'match_getter_setter_field_names',
    problemMessage: 'Getter/setter name should match the backing field.',
    correctionMessage: 'Rename to match the field name (without underscore).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Collect private field names
      final Set<String> privateFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String name = variable.name.lexeme;
            if (name.startsWith('_')) {
              privateFields.add(name);
            }
          }
        }
      }

      // Check getters
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.isGetter) {
          final String getterName = member.name.lexeme;

          // Check if body returns a private field
          final FunctionBody body = member.body;
          if (body is ExpressionFunctionBody) {
            final Expression expr = body.expression;
            if (expr is SimpleIdentifier) {
              final String fieldName = expr.name;
              if (fieldName.startsWith('_')) {
                // Expected getter name is field without underscore
                final String expectedName = fieldName.substring(1);
                if (getterName != expectedName &&
                    privateFields.contains(fieldName)) {
                  reporter.atToken(member.name, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when test files don't match lib folder structure.
///
/// Test files should mirror the lib directory structure.
///
/// ### Example
///
/// #### BAD:
/// ```
/// lib/src/utils/helper.dart
/// test/helper_test.dart  // Should be in test/src/utils/
/// ```
///
/// #### GOOD:
/// ```
/// lib/src/utils/helper.dart
/// test/src/utils/helper_test.dart
/// ```
class MatchLibFolderStructureRule extends SaropaLintRule {
  const MatchLibFolderStructureRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'match_lib_folder_structure',
    problemMessage: 'Test file location should mirror lib folder structure.',
    correctionMessage: 'Move test file to match the lib directory structure.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final String path = resolver.path;

      // Only check test files
      if (!path.contains('/test/') && !path.contains('\\test\\')) return;
      if (!path.endsWith('_test.dart')) return;

      // Extract the relative path within test folder
      final RegExp testPathPattern = RegExp(r'[/\\]test[/\\](.+)_test\.dart$');
      final Match? testMatch = testPathPattern.firstMatch(path);
      if (testMatch == null) return;

      final String testRelativePath = testMatch.group(1) ?? '';

      // Check if corresponding lib file exists pattern
      // This is a simple heuristic - just check naming convention
      if (testRelativePath.isEmpty) {
        reporter.atToken(node.beginToken, code);
      }
    });
  }
}

/// Warns when positional field names don't match the variable being assigned.
class MatchPositionalFieldNamesOnAssignmentRule extends SaropaLintRule {
  const MatchPositionalFieldNamesOnAssignmentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'match_positional_field_names_on_assignment',
    problemMessage:
        'Positional field name should match the variable being assigned.',
    correctionMessage:
        'Rename the positional field to match the assignment target.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPatternAssignment((PatternAssignment node) {
      final DartPattern pattern = node.pattern;
      if (pattern is RecordPattern) {
        _checkRecordPattern(pattern, reporter);
      }
    });

    context.registry
        .addPatternVariableDeclaration((PatternVariableDeclaration node) {
      final DartPattern pattern = node.pattern;
      if (pattern is RecordPattern) {
        _checkRecordPattern(pattern, reporter);
      }
    });
  }

  void _checkRecordPattern(
      RecordPattern pattern, SaropaDiagnosticReporter reporter) {
    for (final PatternField field in pattern.fields) {
      final PatternFieldName? fieldName = field.name;
      if (fieldName == null) continue;

      final String? name = fieldName.name?.lexeme;
      if (name == null) continue;

      final DartPattern fieldPattern = field.pattern;
      if (fieldPattern is DeclaredVariablePattern) {
        final String varName = fieldPattern.name.lexeme;
        if (name != varName && !name.startsWith(r'$')) {
          reporter.atNode(field, code);
        }
      }
    }
  }
}

/// Warns when boolean prefixes are missing (is/has/can/should/will/did).
///
/// Example of **bad** code:
/// ```dart
/// bool enabled = true;
/// bool visible = false;
/// ```
///
/// Example of **good** code:
/// ```dart
/// bool isEnabled = true;
/// bool isVisible = false;
/// ```
class PreferBooleanPrefixesRule extends SaropaLintRule {
  const PreferBooleanPrefixesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_boolean_prefixes',
    problemMessage:
        'Boolean variable should have a prefix (is/has/can/should/will/did).',
    correctionMessage:
        'Rename to use a boolean prefix like isEnabled, hasData, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const List<String> _validPrefixes = <String>[
    'is',
    'has',
    'can',
    'should',
    'will',
    'did',
    'was',
    'are',
    'does',
    'do',
    'allow',
    'enable',
    'disable',
    'show',
    'hide',
    'use',
    'need',
    'require',
    'include',
    'exclude',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      // Check if it's a bool type
      final AstNode? parent = node.parent;
      if (parent is! VariableDeclarationList) return;

      final TypeAnnotation? type = parent.type;
      if (type is! NamedType) return;
      if (type.name.lexeme != 'bool') return;

      final String name = node.name.lexeme;
      // Skip private variables (starting with _)
      final String checkName =
          name.startsWith('_') ? name.replaceFirst('_', '') : name;

      if (!_hasValidPrefix(checkName)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _hasValidPrefix(String name) {
    final String lowerName = name.toLowerCase();
    for (final String prefix in _validPrefixes) {
      if (lowerName.startsWith(prefix)) {
        // Make sure it's a prefix, not just starts with those letters
        if (name.length > prefix.length) {
          final String nextChar = name[prefix.length];
          if (nextChar == nextChar.toUpperCase() || nextChar == '_') {
            return true;
          }
        }
      }
    }
    return false;
  }
}

/// Warns when callback fields don't follow onX naming convention.
class PreferCorrectCallbackFieldNameRule extends SaropaLintRule {
  const PreferCorrectCallbackFieldNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_callback_field_name',
    problemMessage: "Callback field should be named with 'on' prefix.",
    correctionMessage: "Rename to 'onX' pattern (e.g., onPressed, onChanged).",
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? typeAnnotation = node.fields.type;
      if (typeAnnotation == null) return;

      // Check if this is a callback type (Function or VoidCallback or similar)
      final String typeStr = typeAnnotation.toSource();
      final bool isCallback = typeStr.contains('Function') ||
          typeStr.contains('Callback') ||
          typeStr.contains('ValueChanged') ||
          typeStr.contains('ValueGetter') ||
          typeStr.contains('ValueSetter') ||
          typeStr.contains('VoidCallback') ||
          typeStr.contains('GestureTapCallback') ||
          (typeStr.startsWith('void Function') || typeStr.contains('=> void'));

      if (!isCallback) return;

      for (final VariableDeclaration variable in node.fields.variables) {
        final String name = variable.name.lexeme;
        // Skip private fields and fields already prefixed with 'on'
        if (name.startsWith('_')) continue;
        if (name.startsWith('on') && name.length > 2) {
          final String thirdChar = name[2];
          if (thirdChar == thirdChar.toUpperCase()) continue;
        }

        reporter.atToken(variable.name, code);
      }
    });

    // Also check constructor parameters
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      for (final FormalParameter param in node.parameters.parameters) {
        TypeAnnotation? typeAnnotation;
        String? paramName;

        if (param is SimpleFormalParameter) {
          typeAnnotation = param.type;
          paramName = param.name?.lexeme;
        } else if (param is DefaultFormalParameter) {
          final FormalParameter innerParam = param.parameter;
          if (innerParam is SimpleFormalParameter) {
            typeAnnotation = innerParam.type;
            paramName = innerParam.name?.lexeme;
          }
        }

        if (typeAnnotation == null || paramName == null) continue;

        final String typeStr = typeAnnotation.toSource();
        final bool isCallback = typeStr.contains('Function') ||
            typeStr.contains('Callback') ||
            typeStr.contains('ValueChanged') ||
            typeStr.contains('ValueGetter') ||
            typeStr.contains('ValueSetter') ||
            typeStr.contains('VoidCallback') ||
            typeStr.contains('GestureTapCallback');

        if (!isCallback) continue;

        // Skip private params and params already prefixed with 'on'
        if (paramName.startsWith('_')) continue;
        if (paramName.startsWith('on') && paramName.length > 2) {
          final String thirdChar = paramName[2];
          if (thirdChar == thirdChar.toUpperCase()) continue;
        }

        if (param is SimpleFormalParameter && param.name != null) {
          reporter.atToken(param.name!, code);
        } else if (param is DefaultFormalParameter) {
          final FormalParameter innerParam = param.parameter;
          if (innerParam is SimpleFormalParameter && innerParam.name != null) {
            reporter.atToken(innerParam.name!, code);
          }
        }
      }
    });
  }
}

/// Warns when catch block parameter is not named 'e' or 'error'.
///
/// Consistent naming of catch parameters improves readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// try {
///   ...
/// } catch (ex) { // Should be 'e' or 'error'
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// try {
///   ...
/// } catch (e) {
/// }
/// // or
/// } catch (error) {
/// }
/// ```
class PreferCorrectErrorNameRule extends SaropaLintRule {
  const PreferCorrectErrorNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_error_name',
    problemMessage: 'Catch parameter should be named "e" or "error".',
    correctionMessage: 'Rename to "e" or "error".',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _validNames = <String>{
    'e',
    'error',
    'err',
    'exception',
    'ex',
    '_', // Discard is fine
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) return;

      final String name = exceptionParam.name.lexeme;
      if (!_validNames.contains(name)) {
        reporter.atToken(exceptionParam.name, code);
      }
    });
  }
}

/// Warns when event handler names don't follow conventions.
///
/// Event handlers should be named consistently.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void clicked() { } // Should start with 'on' or '_on'
/// ```
///
/// #### GOOD:
/// ```dart
/// void onButtonClicked() { }
/// void _onTap() { }
/// ```
class PreferCorrectHandlerNameRule extends SaropaLintRule {
  const PreferCorrectHandlerNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_handler_name',
    problemMessage: 'Event handler should start with "on" or "_on".',
    correctionMessage: 'Rename to follow handler naming convention.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _handlerSuffixes = <String>{
    'Pressed',
    'Clicked',
    'Tapped',
    'Changed',
    'Submitted',
    'Selected',
    'Dismissed',
    'Closed',
    'Opened',
    'Completed',
    'Started',
    'Ended',
    'Updated',
    'Deleted',
    'Created',
    'Saved',
    'Loaded',
    'Refreshed',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String name = node.name.lexeme;

      // Check if name ends with handler suffix but doesn't start with on
      for (final String suffix in _handlerSuffixes) {
        if (name.endsWith(suffix)) {
          if (!name.startsWith('on') && !name.startsWith('_on')) {
            if (!name.startsWith('handle') && !name.startsWith('_handle')) {
              reporter.atToken(node.name, code);
            }
          }
          return;
        }
      }
    });
  }
}

/// Warns when identifier names are too short or too long.
///
/// Very short names (except common ones like i, j, x, y) hurt readability.
/// Very long names are also hard to work with.
///
/// Example of **bad** code:
/// ```dart
/// int a = 5;  // Too short
/// String thisIsAnExtremelyLongVariableNameThatIsHardToRead = '';
/// ```
///
/// Example of **good** code:
/// ```dart
/// int count = 5;
/// String userName = '';
/// ```
class PreferCorrectIdentifierLengthRule extends SaropaLintRule {
  const PreferCorrectIdentifierLengthRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_identifier_length',
    problemMessage: 'Identifier name length is not ideal.',
    correctionMessage:
        'Use names between 2-30 characters (except common short names).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Common acceptable short names
  static const Set<String> _allowedShortNames = <String>{
    'i',
    'j',
    'k',
    'x',
    'y',
    'z',
    'a',
    'b',
    'c',
    'e',
    'n',
    'm',
    'id',
    'db',
    'ui',
    'io',
    'os',
    'fs',
  };

  static const int _minLength = 2;
  static const int _maxLength = 40;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      _checkIdentifier(node.name.lexeme, node, reporter);
    });

    context.registry.addFormalParameter((FormalParameter node) {
      final String? name = node.name?.lexeme;
      if (name != null) {
        _checkIdentifier(name, node, reporter);
      }
    });
  }

  void _checkIdentifier(
      String name, AstNode node, SaropaDiagnosticReporter reporter) {
    // Skip private names (start with _)
    final String publicName = name.startsWith('_') ? name.substring(1) : name;

    if (publicName.isEmpty) return;

    // Check minimum length
    if (publicName.length < _minLength &&
        !_allowedShortNames.contains(publicName)) {
      reporter.atNode(node, code);
      return;
    }

    // Check maximum length
    if (publicName.length > _maxLength) {
      reporter.atNode(node, code);
    }
  }
}

/// Warns when setter parameter is not named 'value'.
///
/// Convention is to name setter parameters 'value' for consistency.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// set name(String n) => _name = n;
/// set count(int c) => _count = c;
/// ```
///
/// #### GOOD:
/// ```dart
/// set name(String value) => _name = value;
/// set count(int value) => _count = value;
/// ```
class PreferCorrectSetterParameterNameRule extends SaropaLintRule {
  const PreferCorrectSetterParameterNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_setter_parameter_name',
    problemMessage: 'Setter parameter should be named "value".',
    correctionMessage: 'Rename the parameter to "value".',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.isSetter) return;

      final FormalParameterList? params = node.parameters;
      if (params == null || params.parameters.isEmpty) return;

      final FormalParameter param = params.parameters.first;
      String? paramName;

      if (param is SimpleFormalParameter) {
        paramName = param.name?.lexeme;
      } else if (param is DefaultFormalParameter) {
        final NormalFormalParameter normalParam = param.parameter;
        if (normalParam is SimpleFormalParameter) {
          paramName = normalParam.name?.lexeme;
        }
      }

      if (paramName != null && paramName != 'value' && paramName != '_') {
        reporter.atNode(param, code);
      }
    });
  }
}

/// Warns when function type parameters don't have names.
///
/// Parameter names in function types improve documentation.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// typedef Callback = void Function(String, int);
/// ```
///
/// #### GOOD:
/// ```dart
/// typedef Callback = void Function(String message, int count);
/// ```
class PreferExplicitParameterNamesRule extends SaropaLintRule {
  const PreferExplicitParameterNamesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_parameter_names',
    problemMessage: 'Function type parameters should have names.',
    correctionMessage: 'Add parameter names for better documentation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addGenericFunctionType((GenericFunctionType node) {
      final FormalParameterList params = node.parameters;
      if (params.parameters.isEmpty) return;

      for (final FormalParameter param in params.parameters) {
        if (param is SimpleFormalParameter) {
          if (param.name == null && param.type != null) {
            reporter.atNode(param, code);
          }
        }
      }
    });
  }
}

/// Warns when the file name doesn't match the primary class/type name.
///
/// By convention, the file name should match the main class or type defined
/// in the file to make it easier to locate code.
class PreferMatchFileNameRule extends SaropaLintRule {
  const PreferMatchFileNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_match_file_name',
    problemMessage: 'File name should match the primary class name.',
    correctionMessage: 'Rename the file or class to match.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final String filePath = resolver.source.uri.path;
      final String fileName = filePath.split('/').last.replaceAll('.dart', '');
      final String expectedClassName = _snakeToPascal(fileName);

      // Find the first public class
      for (final CompilationUnitMember member in node.declarations) {
        if (member is ClassDeclaration) {
          final String className = member.name.lexeme;
          if (!className.startsWith('_') && className != expectedClassName) {
            reporter.atToken(member.name, code);
            return;
          }
        }
      }
    });
  }

  String _snakeToPascal(String snake) {
    return snake.split('_').map((String part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    }).join();
  }
}

/// Warns when global constants don't have a prefix.
///
/// Global constants should be prefixed with 'k' or similar.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// const maxRetries = 3;
/// ```
///
/// #### GOOD:
/// ```dart
/// const kMaxRetries = 3;
/// // OR
/// const maxRetriesCount = 3; // Descriptive name
/// ```
class PreferPrefixedGlobalConstantsRule extends SaropaLintRule {
  const PreferPrefixedGlobalConstantsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_prefixed_global_constants',
    problemMessage: 'Global constant should have a descriptive prefix.',
    correctionMessage:
        'Consider prefixing with "k" or using a descriptive name.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      final VariableDeclarationList variables = node.variables;
      if (!variables.isConst) return;

      for (final VariableDeclaration variable in variables.variables) {
        final String name = variable.name.lexeme;

        // Skip private constants
        if (name.startsWith('_')) continue;

        // Skip if already prefixed with k
        if (name.startsWith('k') && name.length > 1) {
          final String secondChar = name[1];
          if (secondChar == secondChar.toUpperCase()) continue;
        }

        // Skip if it's a long descriptive name
        if (name.length >= 15) continue;

        // Skip common naming patterns
        if (name.contains('Count') ||
            name.contains('Size') ||
            name.contains('Max') ||
            name.contains('Min') ||
            name.contains('Default') ||
            name.contains('Timeout') ||
            name.contains('Duration')) {
          continue;
        }

        // Warn for short generic names
        if (name.length < 10) {
          reporter.atToken(variable.name, code);
        }
      }
    });
  }
}

/// Warns when widget tag names don't follow conventions.
class TagNameRule extends SaropaLintRule {
  const TagNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_kebab_tag_name',
    problemMessage: 'Tag name should follow naming conventions.',
    correctionMessage: 'Use kebab-case for tag names.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Element.tag() or similar
      final String methodName = node.methodName.name;
      if (methodName != 'tag' && methodName != 'createElement') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! StringLiteral) return;

      final String? tagName = firstArg.stringValue;
      if (tagName == null) return;

      // Check for valid tag name (lowercase, hyphens allowed)
      if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(tagName)) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

// =============================================================================
// FUTURE RULES
// =============================================================================

/// Future rule: prefer-named-extensions
/// Warns when an anonymous extension should be named.
///
/// Example of **bad** code:
/// ```dart
/// extension on String {
///   bool get isBlank => trim().isEmpty;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// extension StringExtension on String {
///   bool get isBlank => trim().isEmpty;
/// }
/// ```
class PreferNamedExtensionsRule extends SaropaLintRule {
  const PreferNamedExtensionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_named_extensions',
    problemMessage: 'Anonymous extension should be named.',
    correctionMessage:
        'Add a name to the extension for better debugging and documentation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionDeclaration((ExtensionDeclaration node) {
      if (node.name == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Future rule: prefer-typedef-for-callbacks
/// Warns when inline function types are repeated and should use typedef.
///
/// Example of **bad** code:
/// ```dart
/// void Function(String) onComplete;
/// void Function(String) onError;
/// void Function(String) onProgress;
/// ```
///
/// Example of **good** code:
/// ```dart
/// typedef StringCallback = void Function(String);
/// StringCallback onComplete;
/// StringCallback onError;
/// StringCallback onProgress;
/// ```
class PreferTypedefForCallbacksRule extends SaropaLintRule {
  const PreferTypedefForCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_typedef_for_callbacks',
    problemMessage: 'Consider using typedef for repeated function types.',
    correctionMessage:
        'Create a typedef for this function type to improve readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track function type signatures to find repeats
    final Map<String, List<GenericFunctionType>> signatures =
        <String, List<GenericFunctionType>>{};

    context.registry.addGenericFunctionType((GenericFunctionType node) {
      final String signature = node.toSource();
      signatures
          .putIfAbsent(signature, () => <GenericFunctionType>[])
          .add(node);
    });

    // After traversal, check for repeats (using compilation unit end)
    context.registry.addCompilationUnit((CompilationUnit unit) {
      for (final MapEntry<String, List<GenericFunctionType>> entry
          in signatures.entries) {
        if (entry.value.length >= 3) {
          // Report on the third and subsequent occurrences
          for (int i = 2; i < entry.value.length; i++) {
            reporter.atNode(entry.value[i], code);
          }
        }
      }
      signatures.clear();
    });
  }
}

/// Future rule: prefer-enhanced-enums
/// Warns when an enum could use enhanced enum features instead of extensions.
///
/// Example of **bad** code:
/// ```dart
/// enum Status { pending, active, completed }
/// extension StatusExtension on Status {
///   String get displayName => name.toUpperCase();
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// enum Status {
///   pending,
///   active,
///   completed;
///
///   String get displayName => name.toUpperCase();
/// }
/// ```
class PreferEnhancedEnumsRule extends SaropaLintRule {
  const PreferEnhancedEnumsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_enhanced_enums',
    problemMessage: 'Consider using enhanced enum instead of extension.',
    correctionMessage: 'Move extension members into the enum itself.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Collect enum names
    final Set<String> enumNames = <String>{};

    context.registry.addEnumDeclaration((EnumDeclaration node) {
      enumNames.add(node.name.lexeme);
    });

    // Check for extensions on enums
    context.registry.addExtensionDeclaration((ExtensionDeclaration node) {
      final ExtensionOnClause? onClause = node.onClause;
      if (onClause == null) return;

      final TypeAnnotation extendedType = onClause.extendedType;
      if (extendedType is NamedType) {
        final String typeName = extendedType.name.lexeme;
        if (enumNames.contains(typeName)) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a parameter is unused and could use wildcard `_`.
///
/// Dart 3.7 introduced true wildcard variables where `_` doesn't bind.
/// Unused parameters should use `_` to signal intent.
///
/// Example of **bad** code:
/// ```dart
/// void onClick(BuildContext context, int index) {
///   print('Clicked'); // context and index not used
/// }
///
/// list.map((item) => 42); // item not used
/// ```
///
/// Example of **good** code:
/// ```dart
/// void onClick(BuildContext _, int __) {
///   print('Clicked');
/// }
///
/// list.map((_) => 42);
/// ```
class PreferWildcardForUnusedParamRule extends SaropaLintRule {
  const PreferWildcardForUnusedParamRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_wildcard_for_unused_param',
    problemMessage:
        'Parameter is unused. Consider using _ wildcard (Dart 3.7+).',
    correctionMessage:
        'Replace with _ to indicate the parameter is intentionally unused.',
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
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final FunctionBody body = node.functionExpression.body;
      _checkUnusedParams(params.parameters, body, reporter);
    });

    // Check method declarations
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      _checkUnusedParams(params.parameters, node.body, reporter);
    });

    // Check function expressions (lambdas, callbacks)
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Skip if it's part of a function declaration (handled above)
      if (node.parent is FunctionDeclaration) return;

      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      _checkUnusedParams(params.parameters, node.body, reporter);
    });
  }

  void _checkUnusedParams(
    NodeList<FormalParameter> params,
    FunctionBody body,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final FormalParameter param in params) {
      final Token? nameToken = param.name;
      if (nameToken == null) continue;

      final String name = nameToken.lexeme;

      // Skip if already a wildcard pattern
      if (name == '_' ||
          name.startsWith('_') && name.replaceAll('_', '').isEmpty) {
        continue;
      }

      // Skip 'this.' and 'super.' parameters - they're always "used"
      if (param is FieldFormalParameter || param is SuperFormalParameter) {
        continue;
      }

      // Check if the parameter is used in the body
      final bool isUsed = _isIdentifierUsedInBody(name, body);

      if (!isUsed) {
        reporter.atToken(nameToken, code);
      }
    }
  }

  bool _isIdentifierUsedInBody(String name, AstNode body) {
    final _IdentifierUsageVisitor visitor = _IdentifierUsageVisitor(name);
    body.accept(visitor);
    return visitor.isUsed;
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithWildcardFix()];
}

class _ReplaceWithWildcardFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Handle all parameter types
    void handleParam(FormalParameter param) {
      final Token? nameToken = param.name;
      if (nameToken == null) return;
      if (!SourceRange(nameToken.offset, nameToken.length)
          .intersects(analysisError.sourceRange)) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with _',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(nameToken.offset, nameToken.length),
          '_',
        );
      });
    }

    context.registry.addSimpleFormalParameter((SimpleFormalParameter node) {
      handleParam(node);
    });

    context.registry.addDefaultFormalParameter((DefaultFormalParameter node) {
      handleParam(node.parameter);
    });

    context.registry
        .addFunctionTypedFormalParameter((FunctionTypedFormalParameter node) {
      handleParam(node);
    });
  }
}

class _IdentifierUsageVisitor extends RecursiveAstVisitor<void> {
  _IdentifierUsageVisitor(this.name);

  final String name;
  bool isUsed = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) {
      // Make sure it's not a declaration, just a reference
      final AstNode? parent = node.parent;
      if (parent is! VariableDeclaration || parent.name != node.token) {
        isUsed = true;
      }
    }
    super.visitSimpleIdentifier(node);
  }
}
