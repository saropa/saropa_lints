// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../comment_utils.dart';
import '../saropa_lint_rule.dart';

/// Warns when a getter name starts with 'get'.
///
/// Since: v4.8.2 | Updated: v4.13.0 | Rule version: v2
///
/// Formerly: `avoid_getter_prefix`
class AvoidGetterPrefixRule extends SaropaLintRule {
  AvoidGetterPrefixRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases => const <String>['avoid_getter_prefix'];

  static const LintCode _code = LintCode(
    'prefer_no_getter_prefix',
    "[prefer_no_getter_prefix] Getter with 'get' prefix is redundant. Dart convention omits it. Formerly: avoid_getter_prefix. A getter name starts with \'get\'. {v2}",
    correctionMessage:
        "Remove the 'get' prefix from the getter name. For example, rename getName to name, or getValue to value.",
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidNonAsciiSymbolsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_non_ascii_symbols',
    '[avoid_non_ascii_symbols] String contains non-ASCII characters. Non-ASCII characters can cause encoding issues and may be hard to distinguish visually (e.g., different types of spaces). {v4}',
    correctionMessage:
        'Replace non-ASCII characters with ASCII equivalents or Unicode escape sequences (e.g., \\u00E9 for e-acute).',
    severity: DiagnosticSeverity.INFO,
  );

  /// Code points that are invisible or visually confusable.
  ///
  /// These are the genuinely dangerous non-ASCII characters:
  /// zero-width joiners/spaces, invisible formatters, non-standard
  /// whitespace, and byte-order marks.  Visible characters like
  /// emoji, accented letters, and math symbols are NOT included.
  static const Set<int> _dangerousCodePoints = <int>{
    // Zero-width characters
    0x200B, // zero-width space
    0x200C, // zero-width non-joiner
    0x200D, // zero-width joiner
    0xFEFF, // byte order mark / zero-width no-break space
    // Invisible formatters
    0x00AD, // soft hyphen
    0x2060, // word joiner
    0x2061, // function application
    0x2062, // invisible times
    0x2063, // invisible separator
    0x2064, // invisible plus
    // Non-standard whitespace
    0x00A0, // non-breaking space
    0x2000, // en quad
    0x2001, // em quad
    0x2002, // en space
    0x2003, // em space
    0x2004, // three-per-em space
    0x2005, // four-per-em space
    0x2006, // six-per-em space
    0x2007, // figure space
    0x2008, // punctuation space
    0x2009, // thin space
    0x200A, // hair space
    0x202F, // narrow no-break space
    0x205F, // medium mathematical space
    0x3000, // ideographic space
    // Directional formatting
    0x200E, // left-to-right mark
    0x200F, // right-to-left mark
    0x202A, // left-to-right embedding
    0x202B, // right-to-left embedding
    0x202C, // pop directional formatting
    0x202D, // left-to-right override
    0x202E, // right-to-left override
    0x2066, // left-to-right isolate
    0x2067, // right-to-left isolate
    0x2068, // first strong isolate
    0x2069, // pop directional isolate
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      for (int i = 0; i < value.length; i++) {
        final int codeUnit = value.codeUnitAt(i);
        // Only flag invisible or confusable characters, not all non-ASCII.
        // Visible emoji, accented letters, math symbols, currency symbols,
        // and typographic punctuation are intentional and readable.
        if (_dangerousCodePoints.contains(codeUnit)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when single-line comments don't start with a capital letter.
///
/// Since: v4.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Prose comments should start with a capital letter for readability.
/// Commented-out code is automatically detected and skipped to avoid false
/// positives on patterns like `// foo.bar()` or `// return x;`.
///
/// **Detection heuristics for commented-out code:**
/// - Identifier followed by code punctuation: `// foo.bar`, `// x = 5`
/// - Dart keywords at start: `// return`, `// if (`, `// final x`
/// - Type declarations: `// int value`, `// String name`
/// - Function/method calls: `// doSomething()`, `// list.add(item)`
/// - Ends with semicolon: `// statement;`
/// - Starts with annotation: `// @override`
///
/// **BAD:**
/// ```dart
/// // this is a bad comment
/// // the user can click here
/// ```
///
/// **GOOD:**
/// ```dart
/// // This is a good comment.
/// // The user can click here.
/// // foo.bar()  ← Skipped (code)
/// // return x;  ← Skipped (code)
/// // TODO: fix this  ← Skipped (special marker)
/// ```
///
/// **Quick fix available:** Capitalizes the first letter of the comment.
///
/// See also: [CommentPatterns] for shared detection heuristics.
///
/// Formerly: `capitalize_comment_start`
class FormatCommentRule extends SaropaLintRule {
  FormatCommentRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases => const <String>['capitalize_comment_start'];

  static const LintCode _code = LintCode(
    'prefer_capitalized_comment_start',
    '[prefer_capitalized_comment_start] Comment should start with capital letter. Prose comments should start with a capital letter for readability. Commented-out code and continuation comments are automatically detected and skipped. {v4}',
    correctionMessage:
        'Capitalize the first letter of the comment text. Prose comments that start with lowercase letters reduce readability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      final lineInfo = unit.lineInfo;
      Token? token = unit.beginToken;

      while (token != null && !token.isEof) {
        Token? commentToken = token.precedingComments;
        int prevCommentLine = -2;

        while (commentToken != null) {
          final String lexeme = commentToken.lexeme;
          final int currentLine = lineInfo
              .getLocation(commentToken.offset)
              .lineNumber;

          // Only check single-line comments (not doc comments)
          if (lexeme.startsWith('//') && !lexeme.startsWith('///')) {
            final String content = lexeme.substring(2).trim();

            // Skip empty comments
            if (content.isEmpty) {
              prevCommentLine = currentLine;
              commentToken = commentToken.next;
              continue;
            }

            // Skip special task markers and ignore directives
            if (CommentPatterns.isSpecialMarker(content)) {
              prevCommentLine = currentLine;
              commentToken = commentToken.next;
              continue;
            }

            // Check if starts with lowercase letter
            if (CommentPatterns.startsWithLowercase(content)) {
              // Skip if this looks like commented-out code
              if (CommentPatterns.isLikelyCode(content)) {
                prevCommentLine = currentLine;
                commentToken = commentToken.next;
                continue;
              }
              // Skip continuation comments (immediately after another comment)
              if (currentLine == prevCommentLine + 1) {
                prevCommentLine = currentLine;
                commentToken = commentToken.next;
                continue;
              }
              reporter.atToken(commentToken);
            }
          }

          prevCommentLine = currentLine;
          commentToken = commentToken.next;
        }

        token = token.next;
      }
    });
  }
}

/// Quick fix that capitalizes the first letter of a comment.

/// Warns when class names don't match expected patterns.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  MatchClassNamePatternRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'match_class_name_pattern',
    '[match_class_name_pattern] Class name does not follow expected pattern. Class names should follow naming conventions for their purpose. {v4}',
    correctionMessage:
        'Rename the class to follow Dart naming conventions. Use UpperCamelCase and include a suffix matching its purpose (e.g., Widget, State, Screen).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  MatchGetterSetterFieldNamesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'match_getter_setter_field_names',
    '[match_getter_setter_field_names] Getter/setter name should match the backing field. Getter/setter must have the same name as the backing field (without underscore). {v4}',
    correctionMessage:
        'Rename the getter or setter to match the backing field name without the leading underscore. For example, _count must have getter count, not total.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  MatchLibFolderStructureRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'match_lib_folder_structure',
    '[match_lib_folder_structure] Test file location should mirror lib folder structure. This naming violation reduces readability and makes the codebase harder for teams to navigate. {v4}',
    correctionMessage:
        'Move the test file so its path mirrors the lib folder structure. For example, lib/src/utils/helper.dart must have test/src/utils/helper_test.dart.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      final String path = context.filePath;

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
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
class MatchPositionalFieldNamesOnAssignmentRule extends SaropaLintRule {
  MatchPositionalFieldNamesOnAssignmentRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'match_positional_field_names_on_assignment',
    '[match_positional_field_names_on_assignment] Positional field name should match the variable being assigned. This naming violation reduces readability and makes the codebase harder for teams to navigate. {v5}',
    correctionMessage:
        'Rename the positional field to match the variable it is assigned to. Mismatched names cause confusion when reading destructured assignments.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPatternAssignment((PatternAssignment node) {
      final DartPattern pattern = node.pattern;
      if (pattern is RecordPattern) {
        _checkRecordPattern(pattern, reporter);
      }
    });

    context.addPatternVariableDeclaration((PatternVariableDeclaration node) {
      final DartPattern pattern = node.pattern;
      if (pattern is RecordPattern) {
        _checkRecordPattern(pattern, reporter);
      }
    });
  }

  void _checkRecordPattern(
    RecordPattern pattern,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final PatternField field in pattern.fields) {
      final PatternFieldName? fieldName = field.name;
      if (fieldName == null) continue;

      final String? name = fieldName.name?.lexeme;
      if (name == null) continue;

      final DartPattern fieldPattern = field.pattern;
      if (fieldPattern is DeclaredVariablePattern) {
        final String varName = fieldPattern.name.lexeme;
        if (name != varName && !name.startsWith(r'$')) {
          reporter.atNode(field);
        }
      }
    }
  }
}

/// Warns when boolean field prefixes are missing (is/has/can/should/will/did).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// This rule only checks class fields and top-level variables, not local
/// variables inside functions/methods. Local variables are implementation
/// details and don't need strict naming conventions.
///
/// Example of **bad** code:
/// ```dart
/// class MyClass {
///   bool enabled = true;  // Should be isEnabled
///   bool visible = false; // Should be isVisible
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyClass {
///   bool isEnabled = true;
///   bool isVisible = false;
/// }
///
/// void myFunction() {
///   bool enabled = true; // OK - local variable
/// }
/// ```
class PreferBooleanPrefixesRule extends SaropaLintRule {
  PreferBooleanPrefixesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_boolean_prefixes',
    '[prefer_boolean_prefixes] Boolean variable must have a prefix (is/has/can/should/will/did). This rule only checks class fields and top-level variables, not local variables inside functions/methods. Local variables are implementation details and don\'t need strict naming conventions. {v7}',
    correctionMessage:
        'Rename this boolean field to use a standard prefix (is, has, can, should, will, did) or suffix (Enabled, Active, Visible). Example: enabled becomes isEnabled.',
    severity: DiagnosticSeverity.INFO,
  );

  static const List<String> _validPrefixes = <String>[
    'add',
    'allow',
    'animate',
    'apply',
    'are',
    'auto',
    'block',
    'cached',
    'can',
    'collapse',
    'default',
    'did',
    'disable',
    'do',
    'does',
    'enable',
    'exclude',
    'expand',
    'filter',
    'force',
    'has',
    'hide',
    'ignore',
    'include',
    'is',
    'keep',
    'load',
    'lock',
    'log',
    'merge',
    'mute',
    'need',
    'pin',
    'play',
    'prefer',
    'remove',
    'require',
    'reverse',
    'save',
    'send',
    'should',
    'show',
    'skip',
    'sort',
    'split',
    'support',
    'sync',
    'track',
    'trim',
    'use',
    'validate',
    'was',
    'will',
    'wrap',
  ];

  static const List<String> _validSuffixes = <String>[
    'Active',
    'Checked',
    'Disabled',
    'Enabled',
    'Hidden',
    'Loaded',
    'Loading',
    'Required',
    'Selected',
    'Valid',
    'Visibility',
    'Visible',
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only check field declarations (class members)
    context.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      if (type is! NamedType) return;
      if (type.name.lexeme != 'bool') return;

      for (final VariableDeclaration variable in node.fields.variables) {
        final String name = variable.name.lexeme;
        // Strip leading underscore for checking
        final String checkName = name.startsWith('_')
            ? name.substring(1)
            : name;

        if (!_hasValidBooleanName(checkName)) {
          reporter.atNode(variable);
        }
      }
    });

    // Also check top-level variables
    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      final TypeAnnotation? type = node.variables.type;
      if (type is! NamedType) return;
      if (type.name.lexeme != 'bool') return;

      for (final VariableDeclaration variable in node.variables.variables) {
        final String name = variable.name.lexeme;
        final String checkName = name.startsWith('_')
            ? name.substring(1)
            : name;

        if (!_hasValidBooleanName(checkName)) {
          reporter.atNode(variable);
        }
      }
    });
  }

  /// Exact names allowed without prefix/suffix validation.
  ///
  /// These are standard Flutter naming conventions that would be
  /// unnecessarily pedantic to flag:
  /// - `value`: Used by Checkbox, Switch, ToggleButton, Radio widgets
  static const Set<String> _allowedExactNames = <String>{'value'};

  bool _hasValidBooleanName(String name) {
    return _allowedExactNames.contains(name) ||
        _hasValidPrefix(name) ||
        _hasValidSuffix(name);
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

  bool _hasValidSuffix(String name) {
    for (final String suffix in _validSuffixes) {
      if (name.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when local boolean variables are missing prefixes or suffixes.
///
/// Since: v1.4.0 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
///
/// This rule only checks local variables inside functions/methods.
/// Enable this separately from [PreferBooleanPrefixesRule] for gradual adoption.
///
/// Variables with leading underscores are checked after stripping the underscore.
///
/// Example of **bad** code:
/// ```dart
/// void myFunction() {
///   bool status = true;  // Should be isEnabled, hasStatus, etc.
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void myFunction() {
///   bool isEnabled = true;
///   bool _deviceEnabled = false; // OK - ends with Enabled
///   bool defaultHideIcons = true; // OK - default prefix + Hide
/// }
/// ```
class PreferBooleanPrefixesForLocalsRule extends SaropaLintRule {
  PreferBooleanPrefixesForLocalsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_boolean_prefixes_for_locals',
    '[prefer_boolean_prefixes_for_locals] Prefixing boolean local variables with is/has/can/should is a naming convention with no impact on code behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Rename this local boolean variable to use a standard prefix (is, has, can, should, will, did) or suffix (Enabled, Active, Visible). Example: status becomes isActive.',
    severity: DiagnosticSeverity.INFO,
  );

  static const List<String> _validPrefixes = <String>[
    'add',
    'allow',
    'animate',
    'apply',
    'are',
    'auto',
    'block',
    'cached',
    'can',
    'collapse',
    'default',
    'did',
    'disable',
    'do',
    'does',
    'enable',
    'exclude',
    'expand',
    'filter',
    'force',
    'has',
    'hide',
    'ignore',
    'include',
    'is',
    'keep',
    'load',
    'lock',
    'log',
    'merge',
    'mute',
    'need',
    'pin',
    'play',
    'prefer',
    'remove',
    'require',
    'reverse',
    'save',
    'send',
    'should',
    'show',
    'skip',
    'sort',
    'split',
    'support',
    'sync',
    'track',
    'trim',
    'use',
    'validate',
    'was',
    'will',
    'wrap',
  ];

  static const List<String> _validSuffixes = <String>[
    'Active',
    'Checked',
    'Disabled',
    'Enabled',
    'Hidden',
    'Loaded',
    'Loading',
    'Required',
    'Selected',
    'Valid',
    'Visibility',
    'Visible',
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclarationStatement((
      VariableDeclarationStatement node,
    ) {
      final TypeAnnotation? type = node.variables.type;
      if (type is! NamedType) return;
      if (type.name.lexeme != 'bool') return;

      for (final VariableDeclaration variable in node.variables.variables) {
        final String name = variable.name.lexeme;
        // Strip leading underscore for checking
        final String checkName = name.startsWith('_')
            ? name.substring(1)
            : name;

        if (!_hasValidBooleanName(checkName)) {
          reporter.atNode(variable);
        }
      }
    });
  }

  /// Exact names allowed without prefix/suffix validation.
  ///
  /// These are standard Flutter naming conventions that would be
  /// unnecessarily pedantic to flag:
  /// - `value`: Used by Checkbox, Switch, ToggleButton, Radio widgets
  static const Set<String> _allowedExactNames = <String>{'value'};

  bool _hasValidBooleanName(String name) {
    return _allowedExactNames.contains(name) ||
        _hasValidPrefix(name) ||
        _hasValidSuffix(name);
  }

  bool _hasValidPrefix(String name) {
    final String lowerName = name.toLowerCase();
    for (final String prefix in _validPrefixes) {
      if (lowerName.startsWith(prefix)) {
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

  bool _hasValidSuffix(String name) {
    for (final String suffix in _validSuffixes) {
      if (name.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when boolean parameters are missing prefixes.
///
/// Since: v1.4.0 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
///
/// This rule only checks function/method/constructor parameters.
/// Enable this separately from [PreferBooleanPrefixesRule] for gradual adoption.
///
/// Example of **bad** code:
/// ```dart
/// void setVisibility(bool visible) { ... }
/// MyWidget({required bool enabled}) { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void setVisibility({required bool isVisible}) { ... }
/// MyWidget({required bool isEnabled}) { ... }
/// ```
class PreferBooleanPrefixesForParamsRule extends SaropaLintRule {
  PreferBooleanPrefixesForParamsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_boolean_prefixes_for_params',
    '[prefer_boolean_prefixes_for_params] Prefixing boolean parameters with is/has/can/should is a naming convention with no impact on code behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Rename this boolean parameter to use a standard prefix (is, has, can, should, will, did) or suffix (Enabled, Active, Visible). Example: visible becomes isVisible.',
    severity: DiagnosticSeverity.INFO,
  );

  static const List<String> _validPrefixes = <String>[
    'add',
    'allow',
    'animate',
    'apply',
    'are',
    'auto',
    'block',
    'cached',
    'can',
    'collapse',
    'default',
    'did',
    'disable',
    'do',
    'does',
    'enable',
    'exclude',
    'expand',
    'filter',
    'force',
    'has',
    'hide',
    'ignore',
    'include',
    'is',
    'keep',
    'load',
    'lock',
    'log',
    'merge',
    'mute',
    'need',
    'pin',
    'play',
    'prefer',
    'remove',
    'require',
    'reverse',
    'save',
    'send',
    'should',
    'show',
    'skip',
    'sort',
    'split',
    'support',
    'sync',
    'track',
    'trim',
    'use',
    'validate',
    'was',
    'will',
    'wrap',
  ];

  static const List<String> _validSuffixes = <String>[
    'Active',
    'Checked',
    'Disabled',
    'Enabled',
    'Hidden',
    'Loaded',
    'Loading',
    'Required',
    'Selected',
    'Valid',
    'Visibility',
    'Visible',
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check function declarations
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkParameters(node.functionExpression.parameters, reporter);
    });

    // Check method declarations
    context.addMethodDeclaration((MethodDeclaration node) {
      _checkParameters(node.parameters, reporter);
    });

    // Check constructor declarations
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      _checkParameters(node.parameters, reporter);
    });
  }

  void _checkParameters(
    FormalParameterList? parameters,
    SaropaDiagnosticReporter reporter,
  ) {
    if (parameters == null) return;

    for (final FormalParameter param in parameters.parameters) {
      _checkParameter(param, reporter);
    }
  }

  void _checkParameter(
    FormalParameter param,
    SaropaDiagnosticReporter reporter,
  ) {
    TypeAnnotation? typeAnnotation;
    String? paramName;
    Token? nameToken;

    if (param is SimpleFormalParameter) {
      typeAnnotation = param.type;
      paramName = param.name?.lexeme;
      nameToken = param.name;
    } else if (param is DefaultFormalParameter) {
      final FormalParameter innerParam = param.parameter;
      if (innerParam is SimpleFormalParameter) {
        typeAnnotation = innerParam.type;
        paramName = innerParam.name?.lexeme;
        nameToken = innerParam.name;
      }
    } else if (param is FieldFormalParameter) {
      // this.field parameters - check if bool type
      typeAnnotation = param.type;
      paramName = param.name.lexeme;
      nameToken = param.name;
    } else if (param is SuperFormalParameter) {
      typeAnnotation = param.type;
      paramName = param.name.lexeme;
      nameToken = param.name;
    }

    if (typeAnnotation == null || paramName == null || nameToken == null) {
      return;
    }

    // Check if it's a bool type
    if (typeAnnotation is! NamedType) return;
    if (typeAnnotation.name.lexeme != 'bool') return;

    final String checkName = paramName.startsWith('_')
        ? paramName.substring(1)
        : paramName;

    if (!_hasValidBooleanName(checkName)) {
      reporter.atToken(nameToken);
    }
  }

  /// Exact names allowed without prefix/suffix validation.
  ///
  /// These are standard Flutter naming conventions that would be
  /// unnecessarily pedantic to flag:
  /// - `value`: Used by Checkbox, Switch, ToggleButton, Radio widgets
  static const Set<String> _allowedExactNames = <String>{'value'};

  bool _hasValidBooleanName(String name) {
    return _allowedExactNames.contains(name) ||
        _hasValidPrefix(name) ||
        _hasValidSuffix(name);
  }

  bool _hasValidPrefix(String name) {
    final String lowerName = name.toLowerCase();
    for (final String prefix in _validPrefixes) {
      if (lowerName.startsWith(prefix)) {
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

  bool _hasValidSuffix(String name) {
    for (final String suffix in _validSuffixes) {
      if (name.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when callback fields don't follow onX naming convention.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
class PreferCorrectCallbackFieldNameRule extends SaropaLintRule {
  PreferCorrectCallbackFieldNameRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_callback_field_name',
    '[prefer_correct_callback_field_name] Using onXxx naming for callback fields is a Dart API convention. Callback naming does not affect code behavior or performance. Enable via the stylistic tier. {v5}',
    correctionMessage:
        "Rename callback fields to use the 'on' prefix following Flutter convention. For example, callback becomes onCallback and tapHandler becomes onTap.",
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? typeAnnotation = node.fields.type;
      if (typeAnnotation == null) return;

      // Check if this is a callback type (Function or VoidCallback or similar)
      final String typeStr = typeAnnotation.toSource();
      final bool isCallback =
          typeStr.contains('Function') ||
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
    context.addConstructorDeclaration((ConstructorDeclaration node) {
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
        final bool isCallback =
            typeStr.contains('Function') ||
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  PreferCorrectErrorNameRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_error_name',
    '[prefer_correct_error_name] Catch parameter uses nonstandard name. Use "e" or "error" for consistency and readability. Consistent naming of catch parameters improves readability. {v4}',
    correctionMessage:
        'Rename the catch parameter to "e" or "error" for consistency. Example: catch (e) { } or catch (error) { }.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
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
  PreferCorrectHandlerNameRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    'prefer_correct_handler_name',
    '[prefer_correct_handler_name] Using handleXxx or onXxx naming for handler methods is a convention. Handler naming does not affect code behavior or performance. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Rename the event handler method to start with "on" or "_on" prefix. For example, buttonPressed becomes onButtonPressed.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// **Readability benefit:** Research shows 8-20 character identifiers have optimal comprehension speed. Very short or very long names measurably slow code review.
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
  PreferCorrectIdentifierLengthRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_identifier_length',
    '[prefer_correct_identifier_length] Very short (1-2 char) or very long (>30 char) identifiers measurably impact code comprehension speed. Optimal readability is achieved with 8-20 character names. {v6}',
    correctionMessage:
        'Use names between 2 and 40 characters long. Single-character names (except i, j, k, x, y, z, e, n) reduce readability; overly long names hinder scanning.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
      _checkIdentifier(node.name.lexeme, node, reporter);
    });

    context.addFormalParameter((FormalParameter node) {
      final String? name = node.name?.lexeme;
      if (name != null) {
        _checkIdentifier(name, node, reporter);
      }
    });
  }

  void _checkIdentifier(
    String name,
    AstNode node,
    SaropaDiagnosticReporter reporter,
  ) {
    // Skip private names (start with _)
    final String publicName = name.startsWith('_') ? name.substring(1) : name;

    if (publicName.isEmpty) return;

    // Check minimum length
    if (publicName.length < _minLength &&
        !_allowedShortNames.contains(publicName)) {
      reporter.atNode(node);
      return;
    }

    // Check maximum length
    if (publicName.length > _maxLength) {
      reporter.atNode(node);
    }
  }
}

/// Warns when setter parameter is not named 'value'.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
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
  PreferCorrectSetterParameterNameRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_setter_parameter_name',
    '[prefer_correct_setter_parameter_name] Using value as the setter parameter name is a Dart convention. The parameter name does not affect setter behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Rename the setter parameter to "value" for consistency with Dart conventions. Example: set name(String value) => _name = value;',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
        reporter.atNode(param);
      }
    });
  }
}

/// Warns when function type parameters don't have names.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  PreferExplicitParameterNamesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_parameter_names',
    '[prefer_explicit_parameter_names] Function type parameters must have descriptive names. Unnamed parameters lose intent and force callers to guess what each positional argument represents. {v4}',
    correctionMessage:
        'Add descriptive names to function type parameters. Unnamed parameters lose intent: void Function(String) becomes void Function(String message).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addGenericFunctionType((GenericFunctionType node) {
      final FormalParameterList params = node.parameters;
      if (params.parameters.isEmpty) return;

      for (final FormalParameter param in params.parameters) {
        if (param is SimpleFormalParameter) {
          if (param.name == null && param.type != null) {
            reporter.atNode(param);
          }
        }
      }
    });
  }
}

/// Warns when the file name doesn't match the primary class/type name.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// **Discoverability benefit:** When the primary class name does not match the file name, IDE file search cannot find declarations, measurably slowing navigation.
///
/// By convention, the file name should match the main class or type defined
/// in the file to make it easier to locate code.
class PreferMatchFileNameRule extends SaropaLintRule {
  PreferMatchFileNameRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_match_file_name',
    '[prefer_match_file_name] When the primary class name does not match the file name, developers cannot use IDE file search to find declarations. This measurably slows navigation in large codebases. {v5}',
    correctionMessage:
        'Rename either the file or the primary class so they match. For example, user_service.dart should contain class UserService.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      final String filePath = context.filePath;
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  PreferPrefixedGlobalConstantsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_prefixed_global_constants',
    '[prefer_prefixed_global_constants] Global constant must have a descriptive prefix. Global constants must be prefixed with \'k\' or similar. {v5}',
    correctionMessage:
        'Prefix the global constant with "k" (e.g., kMaxRetries) or use a longer descriptive name to distinguish it from local variables.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
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
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class TagNameRule extends SaropaLintRule {
  TagNameRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  /// Alias: prefer_kebab_tag
  static const LintCode _code = LintCode(
    'prefer_kebab_tag_name',
    '[prefer_kebab_tag_name] Tag name should follow naming conventions. Widget tag names don\'t follow conventions. This naming violation reduces readability and makes the codebase harder for teams to navigate. {v4}',
    correctionMessage:
        'Use kebab-case (lowercase with hyphens) for tag names. Tag names must start with a lowercase letter and contain only lowercase letters, digits, and hyphens.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(firstArg);
      }
    });
  }
}

// =============================================================================
// FUTURE RULES
// =============================================================================

/// Future rule: prefer-named-extensions
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
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
  PreferNamedExtensionsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_named_extensions',
    '[prefer_named_extensions] Anonymous extension must be named. This naming violation reduces readability and makes the codebase harder for teams to navigate. {v5}',
    correctionMessage:
        'Add a name to the extension to improve debugging and documentation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExtensionDeclaration((ExtensionDeclaration node) {
      if (node.name == null) {
        reporter.atNode(node);
      }
    });
  }
}

/// Future rule: prefer-typedef-for-callbacks
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
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
  PreferTypedefForCallbacksRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_typedef_for_callbacks',
    '[prefer_typedef_for_callbacks] Use typedef for repeated function types. Duplicate inline function types reduce readability and make signature changes error-prone across the codebase. {v5}',
    correctionMessage:
        'Create a typedef for this function type to improve readability. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track function type signatures to find repeats
    final Map<String, List<GenericFunctionType>> signatures =
        <String, List<GenericFunctionType>>{};

    context.addGenericFunctionType((GenericFunctionType node) {
      final String signature = node.toSource();
      signatures
          .putIfAbsent(signature, () => <GenericFunctionType>[])
          .add(node);
    });

    // After traversal, check for repeats (using compilation unit end)
    context.addCompilationUnit((CompilationUnit unit) {
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
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
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
  PreferEnhancedEnumsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_enhanced_enums',
    '[prefer_enhanced_enums] Use enhanced enum instead of extension. An enum could use enhanced enum features instead of extensions. {v4}',
    correctionMessage:
        'Move extension members into the enum itself. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Collect enum names
    final Set<String> enumNames = <String>{};

    context.addEnumDeclaration((EnumDeclaration node) {
      enumNames.add(node.name.lexeme);
    });

    // Check for extensions on enums
    context.addExtensionDeclaration((ExtensionDeclaration node) {
      final ExtensionOnClause? onClause = node.onClause;
      if (onClause == null) return;

      final TypeAnnotation extendedType = onClause.extendedType;
      if (extendedType is NamedType) {
        final String typeName = extendedType.name.lexeme;
        if (enumNames.contains(typeName)) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when a parameter is unused and could use wildcard `_`.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v4
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
  PreferWildcardForUnusedParamRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_wildcard_for_unused_param',
    '[prefer_wildcard_for_unused_param] Unused parameter obscures intent and signals incomplete API design. Replacing it with a _ wildcard (Dart 3.7+) makes the function signature self-documenting, communicating that the parameter exists for interface conformance but is intentionally ignored in this implementation. {v4}',
    correctionMessage:
        'Replace the parameter with _ to make the function signature self-documenting and signal that the value is intentionally unused.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check function declarations
    context.addFunctionDeclaration((FunctionDeclaration node) {
      final FormalParameterList? params = node.functionExpression.parameters;
      if (params == null) return;

      final FunctionBody body = node.functionExpression.body;
      _checkUnusedParams(params.parameters, body, reporter);
    });

    // Check method declarations
    context.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      _checkUnusedParams(params.parameters, node.body, reporter);
    });

    // Check function expressions (lambdas, callbacks)
    context.addFunctionExpression((FunctionExpression node) {
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
        reporter.atToken(nameToken);
      }
    }
  }

  bool _isIdentifierUsedInBody(String name, AstNode body) {
    final _IdentifierUsageVisitor visitor = _IdentifierUsageVisitor(name);
    body.accept(visitor);
    return visitor.isUsed;
  }
}

// =============================================================================
// prefer_correct_package_name
// =============================================================================

/// Warns when a `library` directive name doesn't follow Dart naming conventions.
///
/// Since: v4.14.0 | Rule version: v2
///
/// Alias: package_name_convention, library_name_convention
///
/// Dart package and library names must be lowercase_with_underscores per the
/// Dart style guide (https://dart.dev/effective-dart/style#do-name-packages-and-file-sources-using-lowercase_with_underscores).
/// The pub.dev naming rules require: only lowercase letters, digits, and
/// underscores; must start with a lowercase letter; no hyphens, dots, or
/// uppercase letters.
///
/// **BAD:**
/// ```dart
/// library MyPackage;       // LINT - uppercase letters
/// library my-package;      // LINT - hyphens not allowed
/// library 1_bad;           // LINT - starts with digit
/// library my.package.name; // LINT - dots not allowed
/// ```
///
/// **GOOD:**
/// ```dart
/// library my_package;      // OK - lowercase_with_underscores
/// library;                 // OK - unnamed library (Dart 2.19+)
/// ```
class PreferCorrectPackageNameRule extends SaropaLintRule {
  PreferCorrectPackageNameRule() : super(code: _code);

  /// Invalid names break pub publish, import resolution, and tooling.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.trivial;

  /// Matches valid Dart package/library names per pub.dev rules:
  /// lowercase letter start, then lowercase letters, digits, underscores.
  static final RegExp _validPackageName = RegExp(r'^[a-z][a-z0-9_]*$');

  static const LintCode _code = LintCode(
    'prefer_correct_package_name',
    '[prefer_correct_package_name] Library directive name does not follow '
        'Dart naming conventions. Library and package names must use '
        'lowercase_with_underscores format: start with a lowercase letter, '
        'use only lowercase letters, digits, and underscores. Names with '
        'hyphens, dots, uppercase letters, or starting with digits break '
        'pub publish, import resolution, and IDE tooling. {v2}',
    correctionMessage:
        'Rename the library to use lowercase_with_underscores format '
        '(e.g., "my_package" instead of "MyPackage" or "my-package").',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addLibraryDirective((LibraryDirective node) {
      final LibraryIdentifier? libName = node.name;
      if (libName == null) return; // `library;` without name is valid

      final String libraryName = libName.name;
      if (libraryName.isEmpty) return;

      if (!_validPackageName.hasMatch(libraryName)) {
        reporter.atNode(libName);
      }
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
