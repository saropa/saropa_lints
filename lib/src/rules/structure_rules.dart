// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when a file only contains export statements (barrel file).
///
/// Barrel files can cause unnecessary code to be pulled into the build
/// and make dependency tracking harder.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// // lib/src/models.dart
/// export 'user.dart';
/// export 'product.dart';
/// export 'order.dart';
/// ```
///
/// #### GOOD:
/// ```dart
/// // Import specific files where needed
/// import 'package:app/src/user.dart';
/// ```
class AvoidBarrelFilesRule extends SaropaLintRule {
  const AvoidBarrelFilesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_barrel_files',
    problemMessage:
        '[avoid_barrel_files] File contains only export statements (barrel file).',
    correctionMessage:
        'Import specific files where needed instead of using barrel files.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      // Check if file has any declarations
      if (unit.declarations.isNotEmpty) return;

      // Count exports and imports
      int exportCount = 0;
      int importCount = 0;

      for (final Directive directive in unit.directives) {
        if (directive is ExportDirective) {
          exportCount++;
        } else if (directive is ImportDirective) {
          importCount++;
        }
      }

      // If only exports (no declarations, possibly some imports for types)
      if (exportCount > 0 && unit.declarations.isEmpty) {
        // Allow if there's significant import usage (not just re-exports)
        if (importCount == 0 || exportCount >= 2) {
          reporter.atToken(unit.beginToken, code);
        }
      }
    });
  }
}

/// Warns when double slashes are used in import paths.
///
/// Example of **bad** code:
/// ```dart
/// import 'package:foo//bar.dart';
/// import '//src/utils.dart';
/// ```
///
/// Example of **good** code:
/// ```dart
/// import 'package:foo/bar.dart';
/// import 'src/utils.dart';
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidDoubleSlashImportsRule extends SaropaLintRule {
  const AvoidDoubleSlashImportsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_double_slash_imports',
    problemMessage:
        '[avoid_double_slash_imports] Import path contains double slashes.',
    correctionMessage: 'Remove the extra slash from the import path.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      final StringLiteral uri = node.uri;
      if (uri is SimpleStringLiteral) {
        final String path = uri.value;
        if (path.contains('//')) {
          reporter.atNode(uri, code);
        }
      }
    });

    context.registry.addExportDirective((ExportDirective node) {
      final StringLiteral uri = node.uri;
      if (uri is SimpleStringLiteral) {
        final String path = uri.value;
        if (path.contains('//')) {
          reporter.atNode(uri, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForDoubleSlashImportFix()];
}

/// Warns when the same file is exported multiple times.
///
/// Example of **bad** code:
/// ```dart
/// export 'utils.dart';
/// export 'utils.dart';  // Duplicate export
/// ```
///
/// Example of **good** code:
/// ```dart
/// export 'utils.dart';
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidDuplicateExportsRule extends SaropaLintRule {
  const AvoidDuplicateExportsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_exports',
    problemMessage:
        '[avoid_duplicate_exports] File is exported multiple times.',
    correctionMessage: 'Remove the duplicate export directive.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final Set<String> seenExports = <String>{};

      for (final Directive directive in node.directives) {
        if (directive is ExportDirective) {
          final String uri = directive.uri.stringValue ?? '';
          if (seenExports.contains(uri)) {
            reporter.atNode(directive, code);
          } else {
            seenExports.add(uri);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForDuplicateExportFix()];
}

/// Warns when the same mixin is applied multiple times in a class hierarchy.
///
/// Example of **bad** code:
/// ```dart
/// class MyClass extends BaseClass with MixinA, MixinA { }  // Duplicate mixin
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyClass extends BaseClass with MixinA, MixinB { }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidDuplicateMixinsRule extends SaropaLintRule {
  const AvoidDuplicateMixinsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_mixins',
    problemMessage: '[avoid_duplicate_mixins] Mixin is applied multiple times.',
    correctionMessage: 'Remove the duplicate mixin application.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final WithClause? withClause = node.withClause;
      if (withClause == null) return;

      final Set<String> seenMixins = <String>{};
      for (final NamedType mixin in withClause.mixinTypes) {
        final String mixinName = mixin.name.lexeme;
        if (seenMixins.contains(mixinName)) {
          reporter.atNode(mixin, code);
        } else {
          seenMixins.add(mixinName);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForDuplicateMixinFix()];
}

/// Warns when the same import is declared with different prefixes.
///
/// Example of **bad** code:
/// ```dart
/// import 'package:foo/foo.dart' as foo;
/// import 'package:foo/foo.dart' as bar;  // Same import with different prefix
/// ```
///
/// Example of **good** code:
/// ```dart
/// import 'package:foo/foo.dart' as foo;
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidDuplicateNamedImportsRule extends SaropaLintRule {
  const AvoidDuplicateNamedImportsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_named_imports',
    problemMessage:
        '[avoid_duplicate_named_imports] Import is declared multiple times with different prefixes.',
    correctionMessage: 'Use a single import with one prefix.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final Set<String> seenImports = <String>{};

      for (final Directive directive in node.directives) {
        if (directive is ImportDirective) {
          final String uri = directive.uri.stringValue ?? '';
          if (seenImports.contains(uri)) {
            reporter.atNode(directive, code);
          } else {
            seenImports.add(uri);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForDuplicateNamedImportFix()];
}

/// Warns when mutable global state is declared.
///
/// Mutable global state can lead to hard-to-track bugs and makes testing difficult.
///
/// Example of **bad** code:
/// ```dart
/// int globalCounter = 0;  // Mutable global
/// List<String> globalItems = [];  // Mutable global collection
/// ```
///
/// Example of **good** code:
/// ```dart
/// const int maxItems = 100;  // Immutable
/// final List<String> defaultItems = const ['a', 'b'];  // Immutable
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidGlobalStateRule extends SaropaLintRule {
  const AvoidGlobalStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_global_state',
    problemMessage: '[avoid_global_state] Avoid mutable global state.',
    correctionMessage: 'Use const, final, or encapsulate in a class.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      for (final CompilationUnitMember declaration in node.declarations) {
        if (declaration is TopLevelVariableDeclaration) {
          final VariableDeclarationList variables = declaration.variables;

          // Skip const and final declarations
          if (variables.isConst || variables.isFinal) continue;

          // This is a mutable top-level variable
          for (final VariableDeclaration variable in variables.variables) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForGlobalStateFix()];
}

// =============================================================================
// FILE LENGTH RULES (Tiered) - OPINIONATED STYLE PREFERENCES
// =============================================================================
//
// These are OPINIONATED style preferences, NOT quality indicators.
//
// Large files are often necessary and completely valid for:
// - Data files, enums, constants, lookup tables
// - Generated code
// - Configuration/theme files
// - Localization/translation files
// - Test fixtures with many test cases
//
// All rules use INFO severity. Enable only if your team prefers smaller files.
// Disable for files where large size is intentional (use ignore comments).
//
// | Threshold | Rule                    | Tier          |
// |-----------|-------------------------|---------------|
// | 200 lines | prefer_small_files      | insanity      |
// | 300 lines | avoid_medium_files      | professional  |
// | 500 lines | avoid_long_files        | comprehensive |
// | 1000 lines| avoid_very_long_files   | recommended   |
// =============================================================================

/// **OPINIONATED**: Suggests keeping files under 200 lines for maximum
/// maintainability.
///
/// Small files are easier to understand at a glance, have clearer
/// responsibilities, and are simpler to test in isolation. The 200-line
/// threshold encourages the Single Responsibility Principle - if a file
/// exceeds this, it likely has multiple concerns that could be separated.
///
/// **Best practice**: Each file should do one thing well. When you can't
/// describe what a file does in a single sentence, it's probably too big.
///
/// Disable for data files, enums, or generated code:
/// ```dart
/// // ignore_for_file: prefer_small_files
/// ```
class PreferSmallFilesRule extends SaropaLintRule {
  const PreferSmallFilesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.trivial;

  static const int _maxLines = 200;

  static const LintCode _code = LintCode(
    name: 'prefer_small_files',
    problemMessage:
        '[prefer_small_files] File has more than $_maxLines lines. '
        'Smaller files are easier to understand and maintain.',
    correctionMessage:
        'Split this file into focused modules with single responsibilities. '
        'For data/enum files, disable with: // ignore_for_file: prefer_small_files',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Token endToken = unit.endToken;
      final int lineCount = unit.lineInfo.getLocation(endToken.end).lineNumber;

      if (lineCount > _maxLines) {
        reporter.atToken(unit.beginToken, code);
      }
    });
  }
}

/// **OPINIONATED**: Flags files exceeding 300 lines.
///
/// This is ESLint's default threshold. Many valid files exceed this.
///
/// Disable for files where size is intentional:
/// ```dart
/// // ignore_for_file: avoid_medium_files
/// ```
class AvoidMediumFilesRule extends SaropaLintRule {
  const AvoidMediumFilesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.trivial;

  static const int _maxLines = 300;

  static const LintCode _code = LintCode(
    name: 'avoid_medium_files',
    problemMessage: '[avoid_medium_files] File exceeds $_maxLines lines.',
    correctionMessage:
        'Consider splitting into smaller modules, or disable this rule '
        'for data/enum files where large size is intentional.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Token endToken = unit.endToken;
      final int lineCount = unit.lineInfo.getLocation(endToken.end).lineNumber;

      if (lineCount > _maxLines) {
        reporter.atToken(unit.beginToken, code);
      }
    });
  }
}

/// **OPINIONATED**: Flags files exceeding 500 lines.
///
/// A common threshold in style guides. Many valid files exceed this.
///
/// Disable for files where size is intentional:
/// ```dart
/// // ignore_for_file: avoid_long_files
/// ```
class AvoidLongFilesRule extends SaropaLintRule {
  const AvoidLongFilesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.trivial;

  static const int _maxLines = 500;

  static const LintCode _code = LintCode(
    name: 'avoid_long_files',
    problemMessage: '[avoid_long_files] File exceeds $_maxLines lines.',
    correctionMessage:
        'Consider splitting into smaller modules, or disable this rule '
        'for data/enum files where large size is intentional.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Token endToken = unit.endToken;
      final int lineCount = unit.lineInfo.getLocation(endToken.end).lineNumber;

      if (lineCount > _maxLines) {
        reporter.atToken(unit.beginToken, code);
      }
    });
  }
}

/// **OPINIONATED**: Flags files exceeding 1000 lines.
///
/// Large files are often necessary for data, enums, constants, configs,
/// generated code, and lookup tables. This rule is a style preference,
/// not a quality indicator.
///
/// Disable for files where size is intentional:
/// ```dart
/// // ignore_for_file: avoid_very_long_files
/// ```
class AvoidVeryLongFilesRule extends SaropaLintRule {
  const AvoidVeryLongFilesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.trivial;

  static const int _maxLines = 1000;

  static const LintCode _code = LintCode(
    name: 'avoid_very_long_files',
    problemMessage: '[avoid_very_long_files] File exceeds $_maxLines lines.',
    correctionMessage:
        'Consider splitting into smaller modules, or disable this rule '
        'for data/enum files where large size is intentional.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      final Token endToken = unit.endToken;
      final int lineCount = unit.lineInfo.getLocation(endToken.end).lineNumber;

      if (lineCount > _maxLines) {
        reporter.atToken(unit.beginToken, code);
      }
    });
  }
}

/// Warns when a function or method body exceeds the maximum line count.
///
/// Long functions are harder to understand and test. Consider
/// extracting parts into smaller functions.
///
/// ### Configuration
/// Default maximum: 100 lines
class AvoidLongFunctionsRule extends SaropaLintRule {
  const AvoidLongFunctionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxLines = 100;

  static const LintCode _code = LintCode(
    name: 'avoid_long_functions',
    problemMessage:
        '[avoid_long_functions] Function body exceeds $_maxLines lines.',
    correctionMessage: 'Consider extracting parts into smaller functions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(node.functionExpression.body, node.name, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, node.name, reporter);
    });
  }

  void _checkFunctionBody(
    FunctionBody? body,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    if (body == null) return;
    if (body is EmptyFunctionBody) return;

    // Count lines in the function body source
    final String source = body.toSource();
    final int lineCount = '\n'.allMatches(source).length + 1;

    if (lineCount > _maxLines) {
      reporter.atToken(nameToken, code);
    }
  }
}

/// Warns when a function has too many parameters.
///
/// Example of **bad** code:
/// ```dart
/// void process(int a, int b, int c, int d, int e, int f, int g) { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void process(ProcessConfig config) { }
/// ```
class AvoidLongParameterListRule extends SaropaLintRule {
  const AvoidLongParameterListRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_long_parameter_list',
    problemMessage:
        '[avoid_long_parameter_list] Function has too many parameters (max 5).',
    correctionMessage:
        'Consider using a configuration object or named parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxParameters = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FunctionExpression function = node.functionExpression;
      final FormalParameterList? params = function.parameters;
      if (params != null && params.parameters.length > _maxParameters) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params != null && params.parameters.length > _maxParameters) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when local functions are declared inside other functions.
///
/// Example of **bad** code:
/// ```dart
/// void outer() {
///   void inner() { }  // Local function
///   inner();
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void _inner() { }
///
/// void outer() {
///   _inner();
/// }
/// ```
class AvoidLocalFunctionsRule extends SaropaLintRule {
  const AvoidLocalFunctionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_local_functions',
    problemMessage: '[avoid_local_functions] Avoid declaring local functions.',
    correctionMessage: 'Extract to a private top-level or class method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addFunctionDeclarationStatement((FunctionDeclarationStatement node) {
      reporter.atNode(node.functionDeclaration, code);
    });
  }
}

/// Warns when a file has too many import statements.
///
/// Too many imports may indicate the file has too many responsibilities.
///
/// ### Configuration
/// Default maximum: 20 imports
class MaxImportsRule extends SaropaLintRule {
  const MaxImportsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxImports = 20;

  static const LintCode _code = LintCode(
    name: 'max_imports',
    problemMessage: '[max_imports] File has more than $_maxImports imports.',
    correctionMessage: 'Consider splitting the file or reducing dependencies.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit unit) {
      int importCount = 0;

      for (final Directive directive in unit.directives) {
        if (directive is ImportDirective) {
          importCount++;
        }
      }

      if (importCount > _maxImports) {
        reporter.atToken(unit.beginToken, code);
      }
    });
  }
}

/// Warns when class members are not in a consistent order.
///
/// A consistent member ordering makes code easier to navigate. Typical order:
/// 1. Static fields
/// 2. Instance fields
/// 3. Constructors
/// 4. Static methods
/// 5. Instance methods
class MemberOrderingRule extends SaropaLintRule {
  const MemberOrderingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sorted_members',
    problemMessage:
        '[prefer_sorted_members] Consider reordering class members.',
    correctionMessage:
        'Order: static fields, instance fields, constructors, static methods, instance methods.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      int lastCategory = -1;
      bool hasOrderingIssue = false;

      for (final ClassMember member in node.members) {
        final int category = _getMemberCategory(member);
        if (category < lastCategory) {
          hasOrderingIssue = true;
          break;
        }
        lastCategory = category;
      }

      if (hasOrderingIssue) {
        reporter.atToken(node.name, code);
      }
    });
  }

  int _getMemberCategory(ClassMember member) {
    if (member is FieldDeclaration) {
      return member.isStatic ? 0 : 1;
    } else if (member is ConstructorDeclaration) {
      return 2;
    } else if (member is MethodDeclaration) {
      return member.isStatic ? 3 : 4;
    }
    return 5;
  }
}

/// Warns when function parameters are not in alphabetical order.
///
/// Consistent parameter ordering improves readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void foo({required String zebra, required String apple}) { }
/// ```
///
/// #### GOOD:
/// ```dart
/// void foo({required String apple, required String zebra}) { }
/// ```
class PreferSortedParametersRule extends SaropaLintRule {
  const PreferSortedParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_sorted_parameters',
    problemMessage:
        '[prefer_sorted_parameters] Named parameters should be in alphabetical order.',
    correctionMessage: 'Reorder parameters alphabetically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    void checkParameters(FormalParameterList? params, Token reportAt) {
      if (params == null) return;

      final List<String> namedParams = <String>[];

      for (final FormalParameter param in params.parameters) {
        if (param.isNamed) {
          namedParams.add(param.name?.lexeme ?? '');
        }
      }

      // Check if named parameters are sorted
      for (int i = 1; i < namedParams.length; i++) {
        if (namedParams[i].compareTo(namedParams[i - 1]) < 0) {
          reporter.atToken(reportAt, code);
          return;
        }
      }
    }

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      checkParameters(
        node.functionExpression.parameters,
        node.name,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      checkParameters(node.parameters, node.name);
    });
  }
}

/// Warns when boolean parameters are positional instead of named.
///
/// Positional boolean parameters make call sites unclear about what
/// the boolean value means.
///
/// Example of **bad** code:
/// ```dart
/// void setEnabled(bool enabled) {}
/// setEnabled(true);  // Unclear what true means
/// ```
///
/// Example of **good** code:
/// ```dart
/// void setEnabled({required bool enabled}) {}
/// setEnabled(enabled: true);  // Clear intent
/// ```
class PreferNamedBooleanParametersRule extends SaropaLintRule {
  const PreferNamedBooleanParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_named_boolean_parameters',
    problemMessage:
        '[prefer_named_boolean_parameters] Boolean parameter should be named, not positional.',
    correctionMessage: 'Convert to a named parameter for clearer call sites.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFormalParameterList((FormalParameterList node) {
      for (final FormalParameter param in node.parameters) {
        // Skip if already named
        if (param.isNamed) continue;

        // Check if the parameter type is bool
        final SimpleFormalParameter? simpleParam =
            param is SimpleFormalParameter
                ? param
                : (param is DefaultFormalParameter &&
                        param.parameter is SimpleFormalParameter
                    ? param.parameter as SimpleFormalParameter
                    : null);

        if (simpleParam == null) continue;

        final TypeAnnotation? type = simpleParam.type;
        if (type is NamedType && type.name.lexeme == 'bool') {
          reporter.atNode(param, code);
        }
      }
    });
  }
}

/// Warns when imports should use named imports for clarity.
class PreferNamedImportsRule extends SaropaLintRule {
  const PreferNamedImportsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_named_imports',
    problemMessage:
        '[prefer_named_imports] Consider using named imports (show/hide) for clarity.',
    correctionMessage: 'Use "show" to explicitly list imported symbols.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      // Skip if already has show/hide or prefix
      if (node.combinators.isNotEmpty) return;
      if (node.prefix != null) return;

      // Skip dart: imports
      final String uri = node.uri.stringValue ?? '';
      if (uri.startsWith('dart:')) return;

      // Skip relative imports (usually internal)
      if (!uri.startsWith('package:')) return;

      // Warn on package imports without show/hide
      reporter.atNode(node, code);
    });
  }
}

/// Warns when a function has many positional parameters.
///
/// Functions with many positional parameters are hard to call correctly.
/// Consider using named parameters for clarity.
///
/// Example of **bad** code:
/// ```dart
/// void createUser(String name, int age, String email, String phone, bool active) {}
/// createUser('John', 30, 'john@example.com', '555-1234', true);  // What's what?
/// ```
///
/// Example of **good** code:
/// ```dart
/// void createUser({
///   required String name,
///   required int age,
///   required String email,
///   String? phone,
///   bool active = true,
/// }) {}
/// ```
class PreferNamedParametersRule extends SaropaLintRule {
  const PreferNamedParametersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_named_parameters',
    problemMessage:
        '[prefer_named_parameters] Function has too many positional parameters.',
    correctionMessage:
        'Consider using named parameters for better readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxPositionalParams = 3;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFormalParameterList((FormalParameterList node) {
      int positionalCount = 0;

      for (final FormalParameter param in node.parameters) {
        if (!param.isNamed) {
          positionalCount++;
        }
      }

      if (positionalCount > _maxPositionalParams) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a class only has static members and could be a namespace.
///
/// Classes with only static members are essentially namespaces. Consider
/// using top-level functions and constants instead.
class PreferStaticClassRule extends SaropaLintRule {
  const PreferStaticClassRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_static_class',
    problemMessage: '[prefer_static_class] Class only has static members.',
    correctionMessage:
        'Consider using top-level functions and constants instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip if class extends something other than Object
      if (node.extendsClause != null) return;

      // Skip if class has mixins or implements interfaces
      if (node.withClause != null || node.implementsClause != null) return;

      // Check if all members are static
      bool hasNonStaticMember = false;
      bool hasStaticMember = false;

      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          // Allow private/factory constructors
          if (member.name == null || !member.name!.lexeme.startsWith('_')) {
            if (member.factoryKeyword == null) {
              hasNonStaticMember = true;
            }
          }
        } else if (member is FieldDeclaration) {
          if (member.isStatic) {
            hasStaticMember = true;
          } else {
            hasNonStaticMember = true;
          }
        } else if (member is MethodDeclaration) {
          if (member.isStatic) {
            hasStaticMember = true;
          } else {
            hasNonStaticMember = true;
          }
        }
      }

      if (hasStaticMember && !hasNonStaticMember) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when a variable is declared, used once, and returned immediately.
///
/// Example of **bad** code:
/// ```dart
/// int calculate() {
///   final result = 2 + 2;
///   return result;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// int calculate() {
///   return 2 + 2;
/// }
/// ```
class AvoidUnnecessaryLocalVariableRule extends SaropaLintRule {
  const AvoidUnnecessaryLocalVariableRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_local_variable',
    problemMessage:
        '[avoid_unnecessary_local_variable] Variable is only used once and returned immediately.',
    correctionMessage: 'Return the expression directly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final List<Statement> statements = node.statements;
      if (statements.length < 2) return;

      // Check for pattern: variable declaration followed by return of that variable
      for (int i = 0; i < statements.length - 1; i++) {
        final Statement current = statements[i];
        final Statement next = statements[i + 1];

        if (current is! VariableDeclarationStatement) continue;
        if (next is! ReturnStatement) continue;

        final VariableDeclarationList varList = current.variables;
        if (varList.variables.length != 1) continue;

        final VariableDeclaration varDecl = varList.variables.first;
        if (varDecl.initializer == null) continue;

        final Expression? returnExpr = next.expression;
        if (returnExpr is! SimpleIdentifier) continue;

        // Check if return uses the same variable
        if (returnExpr.name == varDecl.name.lexeme) {
          reporter.atNode(current, code);
        }
      }
    });
  }
}

/// Warns when a variable is assigned the same value it already has.
///
/// Example of **bad** code:
/// ```dart
/// String value = 'default';
/// value = value;  // Pointless reassignment
/// ```
///
/// Example of **good** code:
/// ```dart
/// String value = 'default';
/// // Don't reassign if the value is the same
/// ```
class AvoidUnnecessaryReassignmentRule extends SaropaLintRule {
  const AvoidUnnecessaryReassignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_reassignment',
    problemMessage:
        '[avoid_unnecessary_reassignment] Variable is assigned the same value it already has.',
    correctionMessage: 'Remove the unnecessary reassignment.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Only check simple assignments (not +=, etc.)
      if (node.operator.type != TokenType.EQ) return;

      final Expression left = node.leftHandSide;
      final Expression right = node.rightHandSide;

      // Both sides must be simple identifiers
      if (left is! SimpleIdentifier) return;
      if (right is! SimpleIdentifier) return;

      // Check if both sides refer to the same variable
      if (left.name == right.name) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an instance method doesn't use `this` and could be static.
///
/// Example of **bad** code:
/// ```dart
/// class Utils {
///   int add(int a, int b) => a + b;  // Doesn't use this
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class Utils {
///   static int add(int a, int b) => a + b;
/// }
/// ```
class PreferStaticMethodRule extends SaropaLintRule {
  const PreferStaticMethodRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_static_method',
    problemMessage:
        '[prefer_static_method] Method does not use instance members and could be static.',
    correctionMessage: 'Make this method static.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip already static methods
      if (node.isStatic) return;

      // Skip getters, setters, operators
      if (node.isGetter || node.isSetter || node.isOperator) return;

      // Skip overridden methods
      if (_hasOverrideAnnotation(node)) return;

      // Skip abstract methods
      if (node.isAbstract) return;

      // Check if method body uses 'this' or instance members
      final bool usesThis = _usesThisOrInstanceMembers(node);

      if (!usesThis) {
        reporter.atToken(node.name, code);
      }
    });
  }

  bool _hasOverrideAnnotation(MethodDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      if (annotation.name.name == 'override') return true;
    }
    return false;
  }

  bool _usesThisOrInstanceMembers(MethodDeclaration node) {
    bool usesThis = false;
    node.body.visitChildren(
      _ThisUsageFinder(() {
        usesThis = true;
      }),
    );
    return usesThis;
  }
}

class _ThisUsageFinder extends RecursiveAstVisitor<void> {
  _ThisUsageFinder(this.onFound);
  final void Function() onFound;

  @override
  void visitThisExpression(ThisExpression node) {
    onFound();
    super.visitThisExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Check if identifier refers to an instance member
    // This is a simplification - ideally we'd check the element
    final AstNode? parent = node.parent;
    if (parent is! PropertyAccess && parent is! PrefixedIdentifier) {
      // Could be an unqualified instance member reference
      // Full implementation would check if it resolves to instance member
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when a class with only static members could be abstract final.
///
/// Example of **bad** code:
/// ```dart
/// class Constants {
///   Constants._();  // Private constructor to prevent instantiation
///   static const pi = 3.14;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// abstract final class Constants {
///   static const pi = 3.14;
/// }
/// ```
class PreferAbstractFinalStaticClassRule extends SaropaLintRule {
  const PreferAbstractFinalStaticClassRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_abstract_final_static_class',
    problemMessage:
        '[prefer_abstract_final_static_class] Class with only static members should be abstract final.',
    correctionMessage: 'Use "abstract final class" to prevent instantiation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip if already abstract or final
      if (node.abstractKeyword != null) return;
      if (node.finalKeyword != null) return;

      // Skip if class extends or implements
      if (node.extendsClause != null) return;
      if (node.implementsClause != null) return;
      if (node.withClause != null) return;

      bool hasOnlyStaticMembers = true;
      bool hasPrivateConstructor = false;
      bool hasStaticMembers = false;

      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          // Check for private constructor
          final String? name = member.name?.lexeme;
          if (name != null && name.startsWith('_')) {
            hasPrivateConstructor = true;
          } else if (member.factoryKeyword == null) {
            hasOnlyStaticMembers = false;
          }
        } else if (member is FieldDeclaration) {
          if (!member.isStatic) {
            hasOnlyStaticMembers = false;
          } else {
            hasStaticMembers = true;
          }
        } else if (member is MethodDeclaration) {
          if (!member.isStatic) {
            hasOnlyStaticMembers = false;
          } else {
            hasStaticMembers = true;
          }
        }
      }

      // Warn if class has only static members and a private constructor
      if (hasOnlyStaticMembers && hasPrivateConstructor && hasStaticMembers) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when Color values are hardcoded instead of using theme colors.
///
/// Example of **bad** code:
/// ```dart
/// Container(color: Color(0xFF000000));
/// Text('Hi', style: TextStyle(color: Colors.red));
/// ```
///
/// Example of **good** code:
/// ```dart
/// Container(color: Theme.of(context).colorScheme.surface);
/// Text('Hi', style: Theme.of(context).textTheme.bodyMedium);
/// ```
class AvoidHardcodedColorsRule extends SaropaLintRule {
  const AvoidHardcodedColorsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_colors',
    problemMessage: '[avoid_hardcoded_colors] Avoid hardcoded color values.',
    correctionMessage:
        'Use theme colors instead (e.g., Theme.of(context).colorScheme.primary).',
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
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for Color constructor
      if (typeName == 'Color') {
        reporter.atNode(node, code);
        return;
      }

      // Check for Color.fromARGB, Color.fromRGBO
      if (typeName == 'Color' ||
          node.constructorName.name?.name == 'fromARGB' ||
          node.constructorName.name?.name == 'fromRGBO') {
        final NamedType type = node.constructorName.type;
        if (type.name.lexeme == 'Color') {
          reporter.atNode(node, code);
        }
      }
    });

    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      // Check for Colors.xxx usage
      if (node.prefix.name == 'Colors') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when type parameters are declared but never used.
///
/// Example of **bad** code:
/// ```dart
/// class Container<T> {
///   final Object value;  // T is not used
///   Container(this.value);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class Container<T> {
///   final T value;
///   Container(this.value);
/// }
/// ```
class AvoidUnusedGenericsRule extends SaropaLintRule {
  const AvoidUnusedGenericsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_generics',
    problemMessage:
        '[avoid_unused_generics] Type parameter is declared but never used.',
    correctionMessage:
        'Remove unused type parameter or use it in the declaration.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final TypeParameterList? typeParams = node.typeParameters;
      if (typeParams == null) return;

      for (final TypeParameter param in typeParams.typeParameters) {
        final String paramName = param.name.lexeme;
        if (!_isTypeUsedInClass(node, paramName)) {
          reporter.atToken(param.name, code);
        }
      }
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final TypeParameterList? typeParams = node.typeParameters;
      if (typeParams == null) return;

      for (final TypeParameter param in typeParams.typeParameters) {
        final String paramName = param.name.lexeme;
        if (!_isTypeUsedInMethod(node, paramName)) {
          reporter.atToken(param.name, code);
        }
      }
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeParameterList? typeParams =
          node.functionExpression.typeParameters;
      if (typeParams == null) return;

      for (final TypeParameter param in typeParams.typeParameters) {
        final String paramName = param.name.lexeme;
        if (!_isTypeUsedInFunction(node, paramName)) {
          reporter.atToken(param.name, code);
        }
      }
    });
  }

  bool _isTypeUsedInClass(ClassDeclaration node, String typeName) {
    bool found = false;
    node.visitChildren(_TypeNameFinder(typeName, () => found = true));
    return found;
  }

  bool _isTypeUsedInMethod(MethodDeclaration node, String typeName) {
    bool found = false;
    // Check return type
    final TypeAnnotation? returnType = node.returnType;
    if (returnType != null) {
      returnType.visitChildren(_TypeNameFinder(typeName, () => found = true));
      if (found) return true;
    }
    // Check parameters and body
    node.parameters
        ?.visitChildren(_TypeNameFinder(typeName, () => found = true));
    if (found) return true;
    node.body.visitChildren(_TypeNameFinder(typeName, () => found = true));
    return found;
  }

  bool _isTypeUsedInFunction(FunctionDeclaration node, String typeName) {
    bool found = false;
    final TypeAnnotation? returnType = node.returnType;
    if (returnType != null) {
      returnType.visitChildren(_TypeNameFinder(typeName, () => found = true));
      if (found) return true;
    }
    node.functionExpression.parameters
        ?.visitChildren(_TypeNameFinder(typeName, () => found = true));
    if (found) return true;
    node.functionExpression.body
        .visitChildren(_TypeNameFinder(typeName, () => found = true));
    return found;
  }
}

class _TypeNameFinder extends RecursiveAstVisitor<void> {
  _TypeNameFinder(this.typeName, this.onFound);
  final String typeName;
  final void Function() onFound;

  @override
  void visitNamedType(NamedType node) {
    if (node.name.lexeme == typeName) {
      onFound();
    }
    super.visitNamedType(node);
  }
}

/// Warns when unused parameters don't have underscore prefix.
///
/// Example of **bad** code:
/// ```dart
/// list.map((item) => 'fixed');
/// ```
///
/// Example of **good** code:
/// ```dart
/// list.map((_) => 'fixed');
/// ```
class PreferTrailingUnderscoreForUnusedRule extends SaropaLintRule {
  const PreferTrailingUnderscoreForUnusedRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_trailing_underscore_for_unused',
    problemMessage:
        '[prefer_trailing_underscore_for_unused] Unused parameter should be named with underscore.',
    correctionMessage: 'Rename to _ or _paramName to indicate it is unused.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      final Set<String> usedIdentifiers = <String>{};
      node.body.visitChildren(_IdentifierCollectorStructure(usedIdentifiers));

      for (final FormalParameter param in params.parameters) {
        final String? name = param.name?.lexeme;
        if (name == null) continue;
        if (name.startsWith('_')) continue;

        if (!usedIdentifiers.contains(name)) {
          reporter.atToken(param.name!, code);
        }
      }
    });
  }
}

class _IdentifierCollectorStructure extends RecursiveAstVisitor<void> {
  _IdentifierCollectorStructure(this.identifiers);
  final Set<String> identifiers;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when async/await is used unnecessarily.
///
/// Example of **bad** code:
/// ```dart
/// Future<int> getValue() async {
///   return 42;  // No await needed
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> getValue() {
///   return Future.value(42);
/// }
/// // Or just:
/// int getValue() => 42;
/// ```
class AvoidUnnecessaryFuturesRule extends SaropaLintRule {
  const AvoidUnnecessaryFuturesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_futures',
    problemMessage:
        '[avoid_unnecessary_futures] Async function has no await expressions.',
    correctionMessage: 'Remove async keyword or add await expressions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final FunctionBody body = node.functionExpression.body;
      if (!body.isAsynchronous) return;
      if (body.isGenerator) return; // async* is valid

      if (!_containsAwaitExpression(body)) {
        reporter.atToken(node.name, code);
      }
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      if (!body.isAsynchronous) return;
      if (body.isGenerator) return;

      if (!_containsAwaitExpression(body)) {
        reporter.atToken(node.name, code);
      }
    });
  }

  bool _containsAwaitExpression(FunctionBody body) {
    bool found = false;
    body.visitChildren(_AwaitExpressionFinder(() => found = true));
    return found;
  }
}

class _AwaitExpressionFinder extends RecursiveAstVisitor<void> {
  _AwaitExpressionFinder(this.onFound);
  final void Function() onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound();
    super.visitAwaitExpression(node);
  }
}

/// Warns when throw is used in finally blocks.
///
/// Example of **bad** code:
/// ```dart
/// try {
///   doSomething();
/// } finally {
///   throw Exception('cleanup failed');  // Hides original exception
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// try {
///   doSomething();
/// } finally {
///   try {
///     cleanup();
///   } catch (e) {
///     log(e);
///   }
/// }
/// ```
class AvoidThrowInFinallyRule extends SaropaLintRule {
  const AvoidThrowInFinallyRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_throw_in_finally',
    problemMessage: '[avoid_throw_in_finally] Avoid throw in finally blocks.',
    correctionMessage: 'Throwing in finally can hide the original exception.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      final Block? finallyBlock = node.finallyBlock;
      if (finallyBlock == null) return;

      finallyBlock.visitChildren(
        _ThrowFinder((ThrowExpression throwExpr) {
          reporter.atNode(throwExpr, code);
        }),
      );
    });
  }
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  _ThrowFinder(this.onFound);
  final void Function(ThrowExpression) onFound;

  @override
  void visitThrowExpression(ThrowExpression node) {
    onFound(node);
    super.visitThrowExpression(node);
  }
}

/// Warns when a function's return type is nullable but never returns null.
///
/// Example of **bad** code:
/// ```dart
/// String? getValue() {
///   return 'always a value';
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// String getValue() {
///   return 'always a value';
/// }
/// ```
class AvoidUnnecessaryNullableReturnTypeRule extends SaropaLintRule {
  const AvoidUnnecessaryNullableReturnTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_nullable_return_type',
    problemMessage:
        '[avoid_unnecessary_nullable_return_type] Return type is nullable but function never returns null.',
    correctionMessage: 'Remove the ? from the return type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;
      if (returnType is! NamedType) return;
      if (returnType.question == null) return; // Not nullable

      // Check if any return statement returns null
      final FunctionBody body = node.body;
      if (_canReturnNull(body)) return;

      reporter.atNode(returnType, code);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;
      if (returnType is! NamedType) return;
      if (returnType.question == null) return;

      final FunctionBody body = node.functionExpression.body;
      if (_canReturnNull(body)) return;

      reporter.atNode(returnType, code);
    });
  }

  bool _canReturnNull(FunctionBody body) {
    bool returnsNull = false;
    bool hasImplicitReturn = false;

    if (body is ExpressionFunctionBody) {
      return body.expression is NullLiteral;
    }

    if (body is BlockFunctionBody) {
      body.block.visitChildren(
        _NullReturnFinder(
          onNullReturn: () => returnsNull = true,
          onImplicitReturn: () => hasImplicitReturn = true,
        ),
      );
    }

    return returnsNull || hasImplicitReturn;
  }
}

class _NullReturnFinder extends RecursiveAstVisitor<void> {
  _NullReturnFinder(
      {required this.onNullReturn, required this.onImplicitReturn});
  final void Function() onNullReturn;
  final void Function() onImplicitReturn;

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (node.expression == null || node.expression is NullLiteral) {
      onNullReturn();
    }
    super.visitReturnStatement(node);
  }
}

class _AddHackForDoubleSlashImportFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for double slash import',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: remove extra slash from import path\n',
        );
      });
    });
  }
}

class _AddHackForDuplicateExportFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addExportDirective((ExportDirective node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for duplicate export',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: remove this duplicate export\n',
        );
      });
    });
  }
}

class _AddHackForDuplicateMixinFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final WithClause? withClause = node.withClause;
      if (withClause == null) return;

      // Find the duplicate mixin that matches the error
      for (final NamedType mixin in withClause.mixinTypes) {
        if (!mixin.sourceRange.intersects(analysisError.sourceRange)) continue;

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add HACK comment for duplicate mixin',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            mixin.offset,
            '/* HACK: duplicate mixin */ ',
          );
        });
        return;
      }
    });
  }
}

class _AddHackForDuplicateNamedImportFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for duplicate import',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: use single import with one prefix\n',
        );
      });
    });
  }
}

class _AddHackForGlobalStateFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for mutable global',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: make const/final or encapsulate in class\n',
        );
      });
    });
  }
}
