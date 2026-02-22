// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

import '../import_utils.dart';
import '../saropa_lint_rule.dart';
import '../fixes/stylistic_additional/add_import_group_comments_fix.dart';
import '../fixes/stylistic_additional/prefer_double_quotes_fix.dart';
import '../fixes/stylistic_additional/prefer_object_over_dynamic_fix.dart';
import '../fixes/stylistic_additional/sort_imports_fix.dart';
import '../fixes/stylistic_error_testing/replace_assert_with_expect_fix.dart';

// ============================================================================
// ADDITIONAL STYLISTIC RULES - String, Import, Class Structure, Types
// ============================================================================

// =============================================================================
// SHARED HELPERS
// =============================================================================

/// Checks if a class member is static.
bool _isStaticMember(ClassMember member) {
  if (member is FieldDeclaration) {
    return member.isStatic;
  } else if (member is MethodDeclaration) {
    return member.isStatic;
  }
  return false;
}

/// Checks if a class member is private (name starts with underscore).
bool _isPrivateMember(ClassMember member) {
  if (member is FieldDeclaration) {
    return member.fields.variables.any((v) => v.name.lexeme.startsWith('_'));
  } else if (member is MethodDeclaration) {
    return member.name.lexeme.startsWith('_');
  }
  return false;
}

// =============================================================================
// STRING HANDLING RULES
// =============================================================================

/// Warns when string concatenation is used instead of interpolation.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final message = 'Hello, $name!';
/// final path = '${base}/${file}';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final message = 'Hello, ' + name + '!';
/// final path = base + '/' + file;
/// ```
///
/// **Pros:** More readable, less error-prone, Dart idiomatic
/// **Cons:** Some prefer explicit concatenation for complex expressions
class PreferInterpolationOverConcatenationRule extends SaropaLintRule {
  PreferInterpolationOverConcatenationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_interpolation_over_concatenation',
    '[prefer_interpolation_over_concatenation] String concatenation with the + operator was detected where interpolation would be cleaner. Concatenation adds visual noise and is less idiomatic in Dart. Use \$-interpolation for improved readability. {v2}',
    correctionMessage:
        'Replace string concatenation with \$-interpolation for readability and to reduce operator noise.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((node) {
      if (node.operator.lexeme != '+') return;

      // Check if either operand is a string literal
      final left = node.leftOperand;
      final right = node.rightOperand;

      final hasStringLiteral =
          left is SimpleStringLiteral || right is SimpleStringLiteral;

      if (hasStringLiteral) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when interpolation is used instead of concatenation (opposite).
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final message = 'Hello, ' + name + '!';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final message = 'Hello, $name!';
/// ```
///
/// **Pros:** Explicit about string building, easier to debug
/// **Cons:** More verbose, less Dart idiomatic
class PreferConcatenationOverInterpolationRule extends SaropaLintRule {
  PreferConcatenationOverInterpolationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_concatenation_over_interpolation',
    '[prefer_concatenation_over_interpolation] String interpolation was used where explicit concatenation is preferred. Use the + operator to build strings for a consistent style that keeps expressions visually separated from literal text. {v2}',
    correctionMessage:
        'Replace \$-interpolation with explicit + concatenation for a consistent string-building style.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addStringInterpolation((node) {
      reporter.atNode(node);
    });
  }
}

/// Warns when double quotes are used instead of single quotes.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v6
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final name = 'John';
/// final message = 'Hello';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final name = "John";
/// final message = "Hello";
/// ```
///
/// **Pros:** Consistent style, single quotes are Dart convention
/// **Cons:** Double quotes needed for strings with apostrophes
class PreferDoubleQuotesRule extends SaropaLintRule {
  PreferDoubleQuotesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => "String name = 'John';";

  @override
  String get exampleGood => 'String name = "John";';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferDoubleQuotesFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_double_quotes',
    '[prefer_double_quotes] String literal uses single quotes instead of double quotes. Mixing quote styles creates inconsistent formatting that distracts during code review. {v6}',
    correctionMessage:
        'Replace single quotes with double quotes across all string literals for a consistent codebase style.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((node) {
      final lexeme = node.literal.lexeme;
      if (lexeme.startsWith("'") && !lexeme.contains('"')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Quick fix for [PreferDoubleQuotesRule].
///
/// Converts single-quoted strings to double-quoted strings.
/// Example: `'hello'` → `"hello"`

// =============================================================================
// IMPORT ORGANIZATION RULES
// =============================================================================

/// Warns when absolute imports are used instead of relative imports.
///
/// Since: v4.1.0 | Updated: v4.13.0 | Rule version: v5
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// import '../utils/helpers.dart';
/// import './models/user.dart';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// import 'package:my_app/utils/helpers.dart';
/// import 'package:my_app/models/user.dart';
/// ```
///
/// **Pros:** Easier refactoring, shorter imports
/// **Cons:** Can be confusing in deep directory structures
class PreferAbsoluteImportsRule extends SaropaLintRule {
  PreferAbsoluteImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => "import '../utils.dart';";

  @override
  String get exampleGood => "import 'package:my_app/src/utils.dart';";

  static const LintCode _code = LintCode(
    'prefer_absolute_imports',
    '[prefer_absolute_imports] Relative import detected instead of the preferred absolute package import. Absolute imports provide a canonical path that avoids breakage when files are moved and improves cross-file searchability. {v5}',
    correctionMessage:
        'Replace relative imports with absolute package: imports so every file references the same canonical path.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      // Flag relative imports (starting with . or ..)
      if (uri.startsWith('.')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when imports are not grouped by type (dart, package, relative).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// import 'dart:async';
/// import 'dart:io';
///
/// import 'package:flutter/material.dart';
/// import 'package:provider/provider.dart';
///
/// import '../utils/helpers.dart';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// import '../utils/helpers.dart';
/// import 'dart:async';
/// import 'package:flutter/material.dart';
/// ```
///
/// **Pros:** Organized, easy to find imports
/// **Cons:** Requires manual maintenance
class PreferGroupedImportsRule extends SaropaLintRule {
  PreferGroupedImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      "import '../a.dart'; import 'dart:io'; import 'package:x/x.dart';";

  @override
  String get exampleGood =>
      "import 'dart:io'; \\n import 'package:x/x.dart'; \\n import '../a.dart';";

  static const LintCode _code = LintCode(
    'prefer_grouped_imports',
    '[prefer_grouped_imports] Imports are not grouped by type (dart:, package:, relative). Ungrouped imports make it harder to locate dependencies at a glance; organize them into dart:, package:, and relative sections separated by blank lines. {v4}',
    correctionMessage:
        'Organize imports into dart:, package:, and relative groups separated by blank lines for quick scanning.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((node) {
      final imports = node.directives.whereType<ImportDirective>().toList();
      if (imports.length < 2) return;

      int lastGroup = -1; // 0 = dart, 1 = package, 2 = relative

      for (final import in imports) {
        final uri = import.uri.stringValue;
        if (uri == null) continue;

        int currentGroup;
        if (uri.startsWith('dart:')) {
          currentGroup = 0;
        } else if (uri.startsWith('package:')) {
          currentGroup = 1;
        } else {
          currentGroup = 2;
        }

        // Check if imports are out of order (higher group before lower)
        if (lastGroup > currentGroup) {
          reporter.atNode(import);
        }
        lastGroup = currentGroup;
      }
    });
  }
}

/// Warns when imports are grouped (opposite - prefers flat import list).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// import 'dart:async';
/// import 'package:flutter/material.dart';
/// import '../utils/helpers.dart';
/// ```
///
/// ## Bad Example (flagged - with blank lines between groups)
/// ```dart
/// import 'dart:async';
///
/// import 'package:flutter/material.dart';
///
/// import '../utils/helpers.dart';
/// ```
///
/// **Pros:** Compact, alphabetical sorting easier
/// **Cons:** Harder to distinguish import types
class PreferFlatImportsRule extends SaropaLintRule {
  PreferFlatImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      "import 'dart:io'; \\n\\n import 'package:x/x.dart'; // blank line groups";

  @override
  String get exampleGood =>
      "import 'dart:io'; \\n import 'package:x/x.dart'; // flat, sorted";

  static const LintCode _code = LintCode(
    'prefer_flat_imports',
    '[prefer_flat_imports] Import block uses blank-line grouping that fragments the import list. A flat, alphabetically sorted import block is easier to scan and produces fewer merge conflicts. {v4}',
    correctionMessage:
        'Remove blank lines between import groups so the entire import block stays compact and alphabetically sorted.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((node) {
      final imports = node.directives.whereType<ImportDirective>().toList(
        growable: false,
      );
      if (imports.length < 2) return;

      final lineInfo = context.lineInfo;

      for (var i = 1; i < imports.length; i++) {
        final prevImport = imports[i - 1];
        final currImport = imports[i];

        // Get line numbers for previous and current imports
        final prevEndLine = lineInfo.getLocation(prevImport.end).lineNumber;
        final currStartLine = lineInfo
            .getLocation(currImport.offset)
            .lineNumber;

        // If there's more than one line gap (blank line), report
        if (currStartLine - prevEndLine > 1) {
          reporter.atNode(currImport);
        }
      }
    });
  }
}

/// Warns when imports within a group are not sorted alphabetically.
///
/// Since: v5.0.0 | Rule version: v1
///
/// Sorted imports within each group (dart:, package:, relative) make it
/// easier to find specific imports and reduce merge conflicts.
///
/// ## Good Example
/// ```dart
/// import 'dart:async';
/// import 'dart:io';
///
/// import 'package:flutter/material.dart';
/// import 'package:provider/provider.dart';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// import 'dart:io';
/// import 'dart:async';
///
/// import 'package:provider/provider.dart';
/// import 'package:flutter/material.dart';
/// ```
class PreferSortedImportsRule extends SaropaLintRule {
  PreferSortedImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        SortImportsFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_sorted_imports',
    '[prefer_sorted_imports] Imports within a group are not sorted '
        'alphabetically (A-Z by URI). Unsorted imports make it harder to '
        'locate specific dependencies and increase the likelihood of merge '
        'conflicts when multiple developers add imports to the same file. '
        '{v1}',
    correctionMessage:
        'Sort imports alphabetically within each group '
        '(dart:, package:, relative) for easier scanning.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      final imports = node.directives.whereType<ImportDirective>().toList(
        growable: false,
      );
      if (imports.length < 2) return;

      String? lastUri;
      int lastGroup = -1;

      for (final imp in imports) {
        final group = ImportGroup.classify(imp);
        final uri = imp.uri.stringValue ?? '';

        if (group == lastGroup && lastUri != null) {
          if (uri.compareTo(lastUri) < 0) {
            reporter.atNode(imp);
          }
        }

        if (group != lastGroup) {
          lastGroup = group;
        }
        lastUri = uri;
      }
    });
  }
}

/// Warns when import groups lack doc-comment section headers.
///
/// Since: v5.0.0 | Rule version: v1
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// /// Dart imports
/// import 'dart:async';
/// import 'dart:io';
///
/// /// Package imports
/// import 'package:flutter/material.dart';
///
/// /// Relative imports
/// import '../utils/helpers.dart';
/// ```
///
/// ## Bad Example (flagged - no section headers)
/// ```dart
/// import 'dart:async';
///
/// import 'package:flutter/material.dart';
///
/// import '../utils/helpers.dart';
/// ```
class PreferImportGroupCommentsRule extends SaropaLintRule {
  PreferImportGroupCommentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddImportGroupCommentsFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_import_group_comments',
    '[prefer_import_group_comments] Import group is missing a doc-comment '
        'section header. Adding section headers like "/// Dart imports" '
        'before each group makes the import block self-documenting and '
        'helps developers quickly identify which group a new import '
        'belongs to. {v1}',
    correctionMessage:
        'Add section headers (/// Dart imports, /// Package imports, '
        '/// Relative imports) before each import group.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      final imports = node.directives.whereType<ImportDirective>().toList(
        growable: false,
      );
      if (imports.isEmpty) return;

      final content = context.fileContent;
      final lineInfo = context.lineInfo;

      int? lastGroup;
      for (final imp in imports) {
        final group = ImportGroup.classify(imp);

        if (group == lastGroup) continue;
        lastGroup = group;

        // First import of a new group — check for header above.
        final importLine = lineInfo.getLocation(imp.offset).lineNumber - 1;
        if (importLine == 0) {
          reporter.atNode(imp);
          continue;
        }

        final prevLineStart = lineInfo.getOffsetOfLine(importLine - 1);
        final prevLineEnd = importLine < lineInfo.lineCount
            ? lineInfo.getOffsetOfLine(importLine) - 1
            : content.length;
        final prevLine = content.substring(prevLineStart, prevLineEnd).trim();

        if (prevLine != ImportGroup.headers[group]) {
          reporter.atNode(imp);
        }
      }
    });
  }
}

// =============================================================================
// CLASS STRUCTURE RULES
// =============================================================================

/// Warns when fields are not declared before methods.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   final String name;
///   final int age;
///
///   void greet() => print('Hello, $name');
/// }
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// class User {
///   void greet() => print('Hello, $name');
///
///   final String name;
///   final int age;
/// }
/// ```
///
/// **Pros:** Data before behavior, easier to understand class state
/// **Cons:** Some prefer methods near related fields
class PreferFieldsBeforeMethodsRule extends SaropaLintRule {
  PreferFieldsBeforeMethodsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_fields_before_methods',
    '[prefer_fields_before_methods] A method appears before a field declaration in this class. Placing fields first improves readability by showing the data model before behavior. Move all field declarations above methods. {v4}',
    correctionMessage:
        'Move field declarations above method declarations so readers see the data model before the behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      bool seenMethod = false;

      for (final member in node.members) {
        if (member is MethodDeclaration) {
          seenMethod = true;
        } else if (member is FieldDeclaration && seenMethod) {
          reporter.atNode(member);
        }
      }
    });
  }
}

/// Warns when methods are not declared before fields (opposite).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   void greet() => print('Hello');
///   void save() => db.save(this);
///
///   final String name;
///   final int age;
/// }
/// ```
///
/// **Pros:** API/behavior first, implementation details last
/// **Cons:** Unconventional, harder to see class state
class PreferMethodsBeforeFieldsRule extends SaropaLintRule {
  PreferMethodsBeforeFieldsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_methods_before_fields',
    '[prefer_methods_before_fields] A field declaration appears before a method in this class. Placing methods first highlights the public API before implementation details. Move all method declarations above fields. {v4}',
    correctionMessage:
        'Move method declarations above field declarations so the public API is visible before implementation details.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      bool seenField = false;

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          seenField = true;
        } else if (member is MethodDeclaration && seenField) {
          reporter.atNode(member);
        }
      }
    });
  }
}

/// Warns when static members are not declared before instance members.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class Config {
///   static const defaultTimeout = Duration(seconds: 30);
///   static Config? _instance;
///
///   final String apiUrl;
///   final int timeout;
/// }
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// class Config {
///   final String apiUrl;
///   static const defaultTimeout = Duration(seconds: 30);
/// }
/// ```
///
/// **Pros:** Class-level constants visible first
/// **Cons:** Some prefer grouping by purpose
class PreferStaticMembersFirstRule extends SaropaLintRule {
  PreferStaticMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'final String name; static const max = 10;';

  @override
  String get exampleGood => 'static const max = 10; final String name;';

  static const LintCode _code = LintCode(
    'prefer_static_members_first',
    '[prefer_static_members_first] A static member appears after an instance member in the class body. Mixing declaration order makes it harder to locate class-level constants and factories; move all static members above instance members. {v4}',
    correctionMessage:
        'Move static declarations above instance declarations to group class-level constants and factories together.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      bool seenInstanceMember = false;

      for (final member in node.members) {
        final isStatic = _isStaticMember(member);

        if (!isStatic) {
          seenInstanceMember = true;
        } else if (isStatic && seenInstanceMember) {
          reporter.atNode(member);
        }
      }
    });
  }
}

/// Warns when instance members are not declared before static members (opposite).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   final String name;
///   void greet() {}
///
///   static User fromJson(Map json) => User();
///   static const tableName = 'users';
/// }
/// ```
///
/// **Pros:** Instance API first, factory/constants last
/// **Cons:** Unconventional ordering
class PreferInstanceMembersFirstRule extends SaropaLintRule {
  PreferInstanceMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'static const max = 10; final String name;';

  @override
  String get exampleGood => 'final String name; static const max = 10;';

  static const LintCode _code = LintCode(
    'prefer_instance_members_first',
    '[prefer_instance_members_first] An instance member appears after a static member in the class body. Placing instance members first highlights per-object state before shared class-level members; reorder so all instance declarations precede static ones. {v4}',
    correctionMessage:
        'Move instance declarations above static declarations so per-object state is visible before shared members.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      bool seenStaticMember = false;

      for (final member in node.members) {
        final isStatic = _isStaticMember(member);

        if (isStatic) {
          seenStaticMember = true;
        } else if (!isStatic && seenStaticMember) {
          reporter.atNode(member);
        }
      }
    });
  }
}

/// Warns when public members are not declared before private members.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   final String name;
///   void greet() {}
///
///   String _internalId;
///   void _validate() {}
/// }
/// ```
///
/// **Pros:** Public API visible first
/// **Cons:** Some prefer grouping by functionality
class PreferPublicMembersFirstRule extends SaropaLintRule {
  PreferPublicMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'String _internalId; final String name;';

  @override
  String get exampleGood => 'final String name; String _internalId;';

  static const LintCode _code = LintCode(
    'prefer_public_members_first',
    '[prefer_public_members_first] A public member appears after a private member in the class body. Declaring public members first surfaces the external API at the top, making the class easier to consume. {v4}',
    correctionMessage:
        'Move public declarations above private declarations so the external API is visible at the top of the class.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      bool seenPrivateMember = false;

      for (final member in node.members) {
        final isPrivate = _isPrivateMember(member);

        if (isPrivate) {
          seenPrivateMember = true;
        } else if (!isPrivate && seenPrivateMember) {
          reporter.atNode(member);
        }
      }
    });
  }
}

/// Warns when private members are not declared before public members (opposite).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   String _internalId;
///   void _validate() {}
///
///   final String name;
///   void greet() {}
/// }
/// ```
///
/// **Pros:** Implementation details first, encapsulation emphasis
/// **Cons:** Unconventional, hides public API
class PreferPrivateMembersFirstRule extends SaropaLintRule {
  PreferPrivateMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'final String name; String _internalId;';

  @override
  String get exampleGood => 'String _internalId; final String name;';

  static const LintCode _code = LintCode(
    'prefer_private_members_first',
    '[prefer_private_members_first] A public member appears before a private member in the class body. Declaring private members first groups internal state at the top so implementation details are established before the public API. {v4}',
    correctionMessage:
        'Move private declarations above public declarations so internal state is defined before the public surface.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      bool seenPublicMember = false;

      for (final member in node.members) {
        final isPrivate = _isPrivateMember(member);

        if (!isPrivate) {
          seenPublicMember = true;
        } else if (isPrivate && seenPublicMember) {
          reporter.atNode(member);
        }
      }
    });
  }
}

// =============================================================================
// TYPE ANNOTATION RULES
// =============================================================================

/// Warns when `var` is used instead of explicit type annotations.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// String name = 'John';
/// List<int> numbers = [1, 2, 3];
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// var name = 'John';
/// var numbers = [1, 2, 3];
/// ```
///
/// **Pros:** Self-documenting, explicit about types
/// **Cons:** More verbose, type inference is powerful
class PreferVarOverExplicitTypeRule extends SaropaLintRule {
  PreferVarOverExplicitTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => "String name = 'John';";

  @override
  String get exampleGood => "var name = 'John';";

  static const LintCode _code = LintCode(
    'prefer_var_over_explicit_type',
    '[prefer_var_over_explicit_type] An explicit type annotation is redundant when the right-hand side already makes the type obvious. Use var to reduce visual noise and let the initializer communicate the type. {v3}',
    correctionMessage:
        'Replace the explicit type annotation with var when the right-hand side already makes the type obvious.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclarationStatement((node) {
      final type = node.variables.type;
      if (type == null) return; // Already using var

      // Only flag if there's an initializer that makes type obvious
      for (final variable in node.variables.variables) {
        final init = variable.initializer;
        if (init == null) continue;

        // Type is obvious from literal or constructor
        if (init is Literal ||
            init is InstanceCreationExpression ||
            init is ListLiteral ||
            init is SetOrMapLiteral) {
          reporter.atNode(type);
        }
      }
    });
  }
}

/// Warns when `dynamic` is used instead of `Object?`.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// Object? value;
/// void process(Object? data) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// dynamic value;
/// void process(dynamic data) {}
/// ```
///
/// **Pros:** Type-safe, catches errors at compile time
/// **Cons:** Requires explicit casting, more verbose
class PreferObjectOverDynamicRule extends SaropaLintRule {
  PreferObjectOverDynamicRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferObjectOverDynamicFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_object_over_dynamic',
    '[prefer_object_over_dynamic] Type is declared as dynamic, which disables static type checking and allows any member access without compile-time verification. Use Object? instead to retain type safety while still accepting any runtime type. {v4}',
    correctionMessage:
        'Replace dynamic with Object? to gain static type-safety while still accepting values of any runtime type.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((node) {
      if (node.name.lexeme == 'dynamic') {
        reporter.atNode(node);
      }
    });
  }
}

/// Quick fix for [PreferObjectOverDynamicRule].
///
/// Replaces `dynamic` type with `Object?` for better type safety.
/// Example: `dynamic value` → `Object? value`

/// Warns when `Object?` is used instead of `dynamic` (opposite).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// dynamic value;
/// void process(dynamic data) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// Object? value;
/// void process(Object? data) {}
/// ```
///
/// **Pros:** Less verbose, easier JSON/serialization handling
/// **Cons:** Less type-safe, runtime errors possible
class PreferDynamicOverObjectRule extends SaropaLintRule {
  PreferDynamicOverObjectRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceAssertWithExpectFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_dynamic_over_object',
    '[prefer_dynamic_over_object] Type is declared as Object? where dynamic is intended. Object? forces explicit casts on every access which adds verbosity; use dynamic to signal that static type checking is intentionally bypassed. {v4}',
    correctionMessage:
        'Replace Object? with dynamic when the variable intentionally bypasses static type checks on every access.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((node) {
      if (node.name.lexeme == 'Object' && node.question != null) {
        reporter.atNode(node);
      }
    });
  }
}

/// Quick fix for [PreferDynamicOverObjectRule].
///
/// Replaces `Object?` type with `dynamic` for more flexible typing.
/// Example: `Object? value` → `dynamic value`

// =============================================================================
// NAMING CONVENTION RULES
// =============================================================================

/// Warns when constant names don't use lowerCamelCase.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// const maxRetries = 3;
/// const defaultTimeout = Duration(seconds: 30);
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// const MAX_RETRIES = 3;
/// const DEFAULT_TIMEOUT = Duration(seconds: 30);
/// ```
///
/// **Pros:** Consistent with Dart style guide
/// **Cons:** Some prefer SCREAMING_CASE for visibility
class PreferLowerCamelCaseConstantsRule extends SaropaLintRule {
  PreferLowerCamelCaseConstantsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_lower_camel_case_constants',
    '[prefer_lower_camel_case_constants] Constant name does not follow lowerCamelCase convention. Inconsistent casing breaks IDE autocompletion expectations and diverges from the Dart style guide. {v3}',
    correctionMessage:
        'Rename the constant to lowerCamelCase (e.g., maxRetries) to match the Dart style-guide convention.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTopLevelVariableDeclaration((node) {
      if (!node.variables.isConst) return;

      for (final variable in node.variables.variables) {
        final name = variable.name.lexeme;
        if (_isScreamingCase(name)) {
          reporter.atNode(variable);
        }
      }
    });

    context.addFieldDeclaration((node) {
      if (!node.fields.isConst) return;

      for (final variable in node.fields.variables) {
        final name = variable.name.lexeme;
        if (_isScreamingCase(name)) {
          reporter.atNode(variable);
        }
      }
    });
  }

  bool _isScreamingCase(String name) {
    return name.contains('_') && name == name.toUpperCase();
  }
}

/// Warns when method names use underscores (non-private).
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// void fetchUserData() {}
/// void processPayment() {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// void fetch_user_data() {}
/// void process_payment() {}
/// ```
///
/// **Pros:** Consistent with Dart naming conventions
/// **Cons:** Some prefer snake_case for readability
class PreferCamelCaseMethodNamesRule extends SaropaLintRule {
  PreferCamelCaseMethodNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_camel_case_method_names',
    '[prefer_camel_case_method_names] Method name does not follow lowerCamelCase convention. Non-standard casing breaks IDE autocompletion and makes the API inconsistent with Dart SDK and package conventions. {v2}',
    correctionMessage:
        'Rename the method to lowerCamelCase (e.g., fetchUserData) to follow the Dart naming convention.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((node) {
      final name = node.name.lexeme;
      // Skip private methods and operators
      if (name.startsWith('_') || node.isOperator) return;

      // Check for snake_case pattern (underscores in middle)
      if (name.contains('_')) {
        reporter.atNode(node);
      }
    });

    context.addFunctionDeclaration((node) {
      final name = node.name.lexeme;
      if (name.startsWith('_')) return;

      if (name.contains('_')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when variable names are too short (less than 3 characters).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final index = 0;
/// final user = getUser();
/// for (final item in items) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final i = 0;
/// final u = getUser();
/// for (final x in items) {}
/// ```
///
/// **Pros:** Self-documenting code, clearer intent
/// **Cons:** Short names fine for small scopes (i, j, x, y)
class PreferDescriptiveVariableNamesRule extends SaropaLintRule {
  PreferDescriptiveVariableNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_descriptive_variable_names',
    '[prefer_descriptive_variable_names] Variable name is shorter than 3 characters, making its purpose unclear without reading surrounding context. Use a descriptive name that communicates intent at the point of use. {v3}',
    correctionMessage:
        'Rename the variable to a descriptive name that communicates its purpose without requiring surrounding context.',
    severity: DiagnosticSeverity.INFO,
  );

  static const _allowedShortNames = {'id', 'db', 'io', 'ui', 'x', 'y', 'z'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((node) {
      final name = node.name.lexeme;
      // Skip private and allowed short names
      if (name.startsWith('_')) return;
      if (_allowedShortNames.contains(name.toLowerCase())) return;

      if (name.length < 3) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when variable names are too long (more than 30 characters).
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final userEmail = getEmail();
/// final maxRetryCount = 3;
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final theCurrentlyLoggedInUserEmailAddress = getEmail();
/// final maximumNumberOfRetryAttemptsAllowed = 3;
/// ```
///
/// **Pros:** More readable, fits on screen
/// **Cons:** Sometimes long names are necessary for clarity
class PreferConciseVariableNamesRule extends SaropaLintRule {
  PreferConciseVariableNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_concise_variable_names',
    '[prefer_concise_variable_names] Variable name exceeds 30 characters, which reduces readability and makes code harder to scan. Shorten it to a concise name that still conveys its purpose. {v2}',
    correctionMessage:
        'Shorten the variable name to 30 characters or fewer while still communicating its purpose clearly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((node) {
      final name = node.name.lexeme;
      if (name.length > 30) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// EXPRESSION STYLE RULES
// =============================================================================

/// Warns when explicit `this.` is not used for field access.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   String name;
///   void greet() => print('Hello, ${this.name}');
/// }
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// class User {
///   String name;
///   void greet() => print('Hello, $name');
/// }
/// ```
///
/// **Pros:** Explicit about field access, avoids shadowing confusion
/// **Cons:** More verbose, Dart style guide discourages this
class PreferExplicitThisRule extends SaropaLintRule {
  PreferExplicitThisRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_this',
    '[prefer_explicit_this] Instance field accessed without an explicit this. prefix, making it ambiguous whether the identifier refers to a local variable or a field. Add this. to clarify ownership and improve readability. {v3}',
    correctionMessage:
        'Add an explicit this. prefix to every instance-field reference so readers can distinguish fields from locals.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Note: Full implementation would require semantic analysis to distinguish
    // field access from local variables. This implementation detects cases where
    // a method parameter shadows a field name, which is the most common issue.
    context.addMethodDeclaration((node) {
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;

      // Get all field names in the class
      final fieldNames = <String>{};
      for (final member in parent.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            fieldNames.add(variable.name.lexeme);
          }
        }
      }

      // Check method parameters for shadowing
      final params = node.parameters;
      if (params == null) return;

      for (final param in params.parameters) {
        final paramName = param.name?.lexeme;
        if (paramName != null && fieldNames.contains(paramName)) {
          // Parameter shadows a field - recommend explicit this.
          reporter.atNode(param);
        }
      }
    });
  }
}

/// Warns when `== true` is used for boolean expressions.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// if (isValid) {}
/// if (!isEnabled) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// if (isValid == true) {}
/// if (isEnabled == false) {}
/// ```
///
/// **Pros:** More concise, idiomatic Dart
/// **Cons:** Explicit comparison can be clearer for nullable bools
class PreferImplicitBooleanComparisonRule extends SaropaLintRule {
  PreferImplicitBooleanComparisonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_implicit_boolean_comparison',
    '[prefer_implicit_boolean_comparison] Comparing a boolean expression to a boolean literal (== true or == false) is redundant and adds visual noise. Remove the comparison and use the expression directly for cleaner, idiomatic Dart. {v4}',
    correctionMessage:
        'Remove the redundant == true or == false comparison — the expression is already a bool and reads more naturally.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((node) {
      if (node.operator.lexeme != '==' && node.operator.lexeme != '!=') return;

      final right = node.rightOperand;
      if (right is! BooleanLiteral) return;

      // Skip nullable booleans — explicit comparison is semantically necessary
      final leftType = node.leftOperand.staticType;
      if (leftType == null ||
          leftType.nullabilitySuffix != NullabilitySuffix.none) {
        return;
      }

      reporter.atNode(node);
    });
  }
}

/// Warns when explicit `== true` is not used for nullable boolean expressions.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// if (isValid == true) {}
/// if (user?.isActive == true) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// if (isValid ?? false) {}
/// ```
///
/// **Pros:** Explicit about null handling, clearer intent
/// **Cons:** More verbose
class PreferExplicitBooleanComparisonRule extends SaropaLintRule {
  PreferExplicitBooleanComparisonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_boolean_comparison',
    '[prefer_explicit_boolean_comparison] A nullable boolean expression is used without an explicit comparison, which can hide null-is-false behavior and confuse readers. Add == true to make the intent clear and self-documenting. {v4}',
    correctionMessage:
        'Add an explicit == true comparison so the nullable bool intent is clear and avoids implicit null-is-false confusion.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect `?? false` patterns - suggest using `== true` instead
    context.addBinaryExpression((node) {
      if (node.operator.lexeme != '??') return;

      final right = node.rightOperand;
      if (right is BooleanLiteral && !right.value) {
        // `expr ?? false` - suggest `expr == true`
        reporter.atNode(node);
      }
    });
  }
}
