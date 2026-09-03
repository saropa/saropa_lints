// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticCode;
import 'package:analyzer/source/line_info.dart';

import '../../saropa_lint_rule.dart';
import '../../fixes/formatting/add_blank_line_before_return_fix.dart';
import '../../fixes/formatting/add_blank_line_before_statement_fix.dart';
import '../../fixes/formatting/add_blank_line_fix.dart';
import '../../fixes/formatting/add_trailing_comma_fix.dart';
import '../../fixes/formatting/remove_unnecessary_trailing_comma_fix.dart';
import '../../fixes/formatting/require_ignore_comment_plugin_prefix_fix.dart';
import '../../fixes/formatting/require_ignore_comment_spacing_fix.dart';
import '../../fixes/stylistic/capitalize_comment_fix.dart';
import '../../rule_name_utils.dart' as rule_names;

/// Warns when case clauses don't have newlines before them.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_case, newline_before_case, case_spacing
///
/// Newlines before case clauses improve readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (x) {
///   case 1: return 'one'; case 2: return 'two';
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// switch (x) {
///   case 1:
///     return 'one';
///
///   case 2:
///     return 'two';
/// }
/// ```
class NewlineBeforeCaseRule extends SaropaLintRule {
  NewlineBeforeCaseRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'switch (x) {\n'
      '  case 1: break;\n'
      '  case 2: break;  // no blank line\n'
      '}';

  @override
  String get exampleGood =>
      'switch (x) {\n'
      '  case 1: break;\n'
      '\n'
      '  case 2: break;\n'
      '}';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_case',
    '[prefer_blank_line_before_case] Adding blank lines before case clauses is a formatting preference with no impact on code behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Add blank line before this case. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((SwitchStatement node) {
      final NodeList<SwitchMember> members = node.members;

      for (int i = 1; i < members.length; i++) {
        final SwitchMember current = members[i];
        final SwitchMember previous = members[i - 1];

        // Skip if previous is a fall-through (empty statements)
        if (previous.statements.isEmpty) continue;

        // Check if there's a blank line before current case
        final root = node.root;
        if (root is! CompilationUnit) continue;
        final unit = root;
        final int prevEndLine = unit.lineInfo
            .getLocation(previous.end)
            .lineNumber;
        final int currStartLine = unit.lineInfo
            .getLocation(current.offset)
            .lineNumber;

        if (currStartLine - prevEndLine < 2) {
          // Use beginToken to handle SwitchCase, SwitchDefault, and SwitchPatternCase
          reporter.atToken(current.beginToken, code);
        }
      }
    });
  }
}

/// Warns when constructors don't have blank lines before them.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_constructor, constructor_spacing, newline_before_constructor
///
/// Blank lines before constructors improve readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Foo {
///   final int value;
///   Foo(this.value); // No blank line
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Foo {
///   final int value;
///
///   Foo(this.value);
/// }
/// ```
class NewlineBeforeConstructorRule extends SaropaLintRule {
  NewlineBeforeConstructorRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'class Foo {\n'
      '  final int v;\n'
      '  Foo(this.v);  // no blank line\n'
      '}';

  @override
  String get exampleGood =>
      'class Foo {\n'
      '  final int v;\n'
      '\n'
      '  Foo(this.v);\n'
      '}';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_constructor',
    '[prefer_blank_line_before_constructor] Adding blank lines before constructors is a formatting preference with no impact on code behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Add blank line to improve readability. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final root = node.root;
      if (root is CompilationUnit) {
        _checkMembers(node.bodyMembers, root, reporter);
      }
    });
  }

  void _checkMembers(
    List<ClassMember> members,
    CompilationUnit unit,
    SaropaDiagnosticReporter reporter,
  ) {
    for (int i = 1; i < members.length; i++) {
      final ClassMember current = members[i];
      final ClassMember previous = members[i - 1];

      // Only check constructors
      if (current is! ConstructorDeclaration) continue;

      // Get line numbers
      final int prevEndLine = unit.lineInfo
          .getLocation(previous.end)
          .lineNumber;
      final int currStartLine = unit.lineInfo
          .getLocation(current.offset)
          .lineNumber;

      // Should have at least one blank line
      if (currStartLine - prevEndLine < 2) {
        // typeName is null for unnamed factory constructors
        final Token? nameToken = current.name ?? current.typeName?.beginToken;
        if (nameToken != null) {
          reporter.atToken(nameToken);
        }
      }
    }
  }
}

/// Warns when methods don't have blank lines before them.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_method, method_spacing, newline_before_method
///
/// Blank lines before methods improve readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Foo {
///   void foo() { }
///   void bar() { } // No blank line
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Foo {
///   void foo() { }
///
///   void bar() { }
/// }
/// ```
class NewlineBeforeMethodRule extends SaropaLintRule {
  NewlineBeforeMethodRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'class C {\n'
      '  void a() {}\n'
      '  void b() {}  // no blank line\n'
      '}';

  @override
  String get exampleGood =>
      'class C {\n'
      '  void a() {}\n'
      '\n'
      '  void b() {}\n'
      '}';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_method',
    '[prefer_blank_line_before_method] Adding blank lines before methods is a formatting preference with no impact on code behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Add blank line to improve readability. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final root = node.root;
      if (root is CompilationUnit) {
        _checkMembers(node.bodyMembers, root, reporter);
      }
    });

    context.addMixinDeclaration((MixinDeclaration node) {
      final root = node.root;
      if (root is CompilationUnit) {
        _checkMembers(node.bodyMembers, root, reporter);
      }
    });

    context.addEnumDeclaration((EnumDeclaration node) {
      final root = node.root;
      if (root is CompilationUnit) {
        _checkMembers(node.bodyMembers, root, reporter);
      }
    });
  }

  void _checkMembers(
    List<ClassMember> members,
    CompilationUnit unit,
    SaropaDiagnosticReporter reporter,
  ) {
    for (int i = 1; i < members.length; i++) {
      final ClassMember current = members[i];
      final ClassMember previous = members[i - 1];

      // Only check methods
      if (current is! MethodDeclaration) continue;

      // Get line numbers
      final int prevEndLine = unit.lineInfo
          .getLocation(previous.end)
          .lineNumber;
      final int currStartLine = unit.lineInfo
          .getLocation(current.offset)
          .lineNumber;

      // Should have at least one blank line
      if (currStartLine - prevEndLine < 2) {
        reporter.atToken(current.name, code);
      }
    }
  }
}

/// Warns when there's no blank line before a return statement.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v5
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_return, return_spacing, newline_before_return
///
/// Adding a blank line before return statements can improve readability
/// by visually separating the return from the preceding logic.
class NewlineBeforeReturnRule extends SaropaLintRule {
  NewlineBeforeReturnRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'final x = compute();\n'
      'return x;  // no blank line';

  @override
  String get exampleGood =>
      'final x = compute();\n'
      '\n'
      'return x;';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeReturnFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_return',
    '[prefer_blank_line_before_return] Adding blank lines before return statements is a formatting preference with no impact on code behavior or performance. Enable via the stylistic tier. {v5}',
    correctionMessage:
        'Insert a blank line before return for readability. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addReturnStatement((ReturnStatement node) {
      final AstNode? parent = node.parent;
      if (parent is! Block) return;

      final List<Statement> statements = parent.statements;
      final int index = statements.indexOf(node);

      // Don't warn if it's the first or only statement
      if (index <= 0) return;

      // Check if previous statement ends on the line immediately before
      final Statement previous = statements[index - 1];
      final int prevEndLine = context.lineInfo
          .getLocation(previous.end)
          .lineNumber;
      final int returnStartLine = context.lineInfo
          .getLocation(node.offset)
          .lineNumber;

      if (returnStartLine - prevEndLine < 2) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when there is no blank line before a standalone `else` clause.
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
/// A blank line before `else` separates branches visually and improves
/// readability (see [doc/guides/good_methods.md](../../../doc/guides/good_methods.md) §9).
///
/// **Implementation notes for developers:**
/// - Uses `addIfStatement` only; no string or name heuristics.
/// - Reports on `elseStatement` so [AddBlankLineBeforeFix] inserts at the
///   start of the line containing the else clause.
/// - Skips when there is no else (no false positive on `if (x) { }`).
/// - Skips `else if` chains — they are a single control-flow construct and
///   inserting a blank line before `else if` would be a syntax error.
///
/// **Bad:**
/// ```dart
/// if (x) {
///   a();
/// } else {
///   b();
/// }
/// ```
///
/// **Good:**
/// ```dart
/// if (x) {
///   a();
/// }
///
/// else {
///   b();
/// }
/// ```
class NewlineBeforeElseRule extends SaropaLintRule {
  NewlineBeforeElseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'if (x) {\n'
      '  a();\n'
      '} else {\n'
      '  b();  // no blank line before else\n'
      '}';

  @override
  String get exampleGood =>
      'if (x) {\n'
      '  a();\n'
      '}\n'
      '\n'
      'else {\n'
      '  b();\n'
      '}';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_else',
    '[prefer_blank_line_before_else] Adding a blank line before a standalone '
        'else clause separates branches and improves readability. Enable via the stylistic tier. {v2}',
    correctionMessage: 'Add a blank line before this else clause.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      final Statement? elseStmt = node.elseStatement;
      final Token? elseToken = node.elseKeyword;
      if (elseStmt == null || elseToken == null) return;

      // Skip `else if` chains — they are a single control-flow construct.
      if (elseStmt is IfStatement) return;

      final LineInfo lineInfo = context.lineInfo;
      final int thenEndLine = lineInfo
          .getLocation(node.thenStatement.end)
          .lineNumber;
      final int elseStartLine = lineInfo
          .getLocation(elseToken.offset)
          .lineNumber;
      // At least one full blank line required (gap >= 2).
      if (elseStartLine - thenEndLine < 2) {
        reporter.atNode(elseStmt, code);
      }
    });
  }
}

/// Warns when there is no blank line after a for or while loop before the next statement.
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
/// A blank line after a loop separates it from the following logic (see
/// [doc/guides/good_methods.md](../../../doc/guides/good_methods.md) §9).
///
/// **Implementation notes for developers:**
/// - Uses `addBlock` and iterates [Block.statements]; no recursion.
/// - Only [ForStatement] and [WhileStatement] count as loops (for-in is
///   [ForStatement] with [ForEachParts], so it is covered).
/// - Reports on the *next* statement so [AddBlankLineBeforeFix] inserts
///   a blank line before it (i.e. after the loop).
/// - Blocks with fewer than two statements are skipped (no false positive).
///
/// **Bad:**
/// ```dart
/// for (final x in list) {
///   process(x);
/// }
/// doNext();
/// ```
///
/// **Good:**
/// ```dart
/// for (final x in list) {
///   process(x);
/// }
///
/// doNext();
/// ```
class NewlineAfterLoopRule extends SaropaLintRule {
  NewlineAfterLoopRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'for (final x in list) { process(x); }\n'
      'doNext();  // no blank line after loop';

  @override
  String get exampleGood =>
      'for (final x in list) { process(x); }\n'
      '\n'
      'doNext();';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_after_loop',
    '[prefer_blank_line_after_loop] Adding a blank line after a for/while loop '
        'separates the loop from the next statement and improves readability. Enable via the stylistic tier. {v1}',
    correctionMessage:
        'Add a blank line after the loop (before this statement).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final List<Statement> statements = node.statements;
      if (statements.length < 2) return;

      final LineInfo lineInfo = context.lineInfo;

      for (int i = 0; i < statements.length - 1; i++) {
        final Statement current = statements[i];
        final Statement next = statements[i + 1];

        final bool currentIsLoop =
            current is ForStatement || current is WhileStatement;
        if (!currentIsLoop) continue;

        final int loopEndLine = lineInfo.getLocation(current.end).lineNumber;
        final int nextStartLine = lineInfo.getLocation(next.offset).lineNumber;
        // At least one full blank line required (gap >= 2).
        if (nextStartLine - loopEndLine < 2) {
          reporter.atNode(next, code);
        }
      }
    });
  }
}

/// Warns when multi-line constructs are missing trailing commas.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: require_trailing_comma, add_trailing_comma, multiline_comma
///
/// Trailing commas make diffs cleaner and prevent formatting issues.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final list = [
///   'a',
///   'b',
///   'c'  // Missing trailing comma
/// ];
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = [
///   'a',
///   'b',
///   'c',  // Has trailing comma
/// ];
/// ```
class PreferTrailingCommaRule extends SaropaLintRule {
  PreferTrailingCommaRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'final list = [\n'
      "  'a',\n"
      "  'b'\n"
      '];  // missing trailing comma';

  @override
  String get exampleGood =>
      'final list = [\n'
      "  'a',\n"
      "  'b',\n"
      '];';

  static const LintCode _code = LintCode(
    'prefer_trailing_comma',
    '[prefer_trailing_comma] Adding trailing commas in multi-line constructs is a formatting preference that affects diff readability. No performance or correctness impact. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Add a trailing comma. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addArgumentList((ArgumentList node) {
      _checkTrailingComma(node.arguments, node.rightParenthesis, reporter);
    });

    context.addListLiteral((ListLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });

    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });

    context.addFormalParameterList((FormalParameterList node) {
      _checkTrailingComma(node.parameters, node.rightParenthesis, reporter);
    });
  }

  void _checkTrailingComma(
    NodeList<AstNode> elements,
    Token closingToken,
    SaropaDiagnosticReporter reporter,
  ) {
    if (elements.isEmpty) return;

    final AstNode first = elements.first;
    final AstNode last = elements.last;

    // Check if multi-line by comparing offsets
    final int closingOffset = closingToken.charOffset;
    final int firstOffset = first.offset;
    final int lastEnd = last.end;

    // If construct spans multiple lines (approximate heuristic)
    // Check if there's significant distance between first and closing
    if (closingOffset > firstOffset + 50 && closingOffset > lastEnd + 5) {
      // Check for trailing comma by looking at tokens
      Token? token = last.endToken.next;
      bool hasTrailingComma = false;

      while (token != null && token != closingToken) {
        if (token.lexeme == ',') {
          hasTrailingComma = true;
          break;
        }
        token = token.next;
      }

      if (!hasTrailingComma && elements.length >= 2) {
        // Only report if it looks like a multi-line construct
        reporter.atNode(last);
      }
    }
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddTrailingCommaFix(context: context),
  ];
}

/// Warns when trailing commas are unnecessary.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: remove_trailing_comma, single_element_comma, extra_comma
///
/// Single-element lists/parameters don't need trailing commas.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final list = [
///   'single item',
/// ];
/// ```
///
/// #### GOOD:
/// ```dart
/// final list = ['single item'];
/// // OR for multiple items:
/// final list = [
///   'item1',
///   'item2',
/// ];
/// ```
class UnnecessaryTrailingCommaRule extends SaropaLintRule {
  UnnecessaryTrailingCommaRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'final list = [1, 2, 3,];';

  @override
  String get exampleGood => 'final list = [1, 2, 3];';

  static const LintCode _code = LintCode(
    'unnecessary_trailing_comma',
    '[unnecessary_trailing_comma] Removing trailing commas in single-line constructs is a formatting preference. No impact on code behavior or performance. Enable via the stylistic tier. {v4}',
    correctionMessage:
        'Remove trailing comma or keep on single line. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });

    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });
  }

  void _checkTrailingComma(
    NodeList<CollectionElement> elements,
    Token rightBracket,
    SaropaDiagnosticReporter reporter,
  ) {
    if (elements.length != 1) return;

    // Check if there's a trailing comma
    final CollectionElement element = elements.first;
    final Token? nextToken = element.endToken.next;
    if (nextToken != null && nextToken.type == TokenType.COMMA) {
      // Single element with trailing comma
      reporter.atToken(nextToken);
    }
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryTrailingCommaFix(context: context),
  ];
}

/// Warns when comments don't follow formatting conventions.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v3
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: comment_style, comment_capitalization, comment_punctuation
///
/// Comments should start with a capital letter and end with punctuation.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// // this is a comment
/// // TODO fix this
/// ```
///
/// #### GOOD:
/// ```dart
/// // This is a comment.
/// // TODO: Fix this.
/// ```
class FormatCommentFormattingRule extends SaropaLintRule {
  FormatCommentFormattingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => '// this is a comment  // lowercase start';

  @override
  String get exampleGood => '// This is a comment.';

  static const LintCode _code = LintCode(
    'format_comment_style',
    '[format_comment_style] Enforcing specific comment formatting conventions is a stylistic preference. Comment format has no impact on code behavior or performance. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Start with capital letter and end with punctuation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  // Reuse CapitalizeCommentFix: this rule reports only on lowercase-start
  // comments today, so capitalization is the meaningful correction. If the
  // rule grows to also flag missing terminal punctuation, add a second
  // generator rather than overloading this one.
  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        CapitalizeCommentFix(context: context),
  ];

  /// Annotation markers that have their own formatting conventions.
  static final RegExp _annotationMarker = RegExp(
    r'^(TODO|FIXME|FIX|NOTE|HACK|XXX|BUG|OPTIMIZE|WARNING|CHANGED|REVIEW|DEPRECATED|IMPORTANT|MARK)\b',
    caseSensitive: false,
  );

  // Cached regex for performance - matches lowercase start
  static final RegExp _lowercaseStart = RegExp(r'^[a-z]');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Comments are not part of the AST, so we need to check tokens
    context.addCompilationUnit((CompilationUnit node) {
      Token? token = node.beginToken;
      while (token != null && token != node.endToken) {
        _checkPrecedingComments(token, reporter);
        token = token.next;
      }
    });
  }

  void _checkPrecedingComments(Token token, SaropaDiagnosticReporter reporter) {
    Token? comment = token.precedingComments;
    while (comment != null) {
      final String lexeme = comment.lexeme;

      // Skip doc comments, they have their own rules
      if (lexeme.startsWith('///') || lexeme.startsWith('/**')) {
        comment = comment.next;
        continue;
      }

      // Check single-line comments
      if (lexeme.startsWith('//')) {
        final String content = lexeme.substring(2).trim();

        // Skip empty comments, special markers, and ignore directives
        if (content.isEmpty ||
            content.startsWith('ignore') ||
            _annotationMarker.hasMatch(content)) {
          comment = comment.next;
          continue;
        }

        // Check if starts with lowercase (excluding URLs and code)
        if (content.isNotEmpty &&
            content[0].toLowerCase() == content[0] &&
            _lowercaseStart.hasMatch(content) &&
            !content.startsWith('http') &&
            !content.contains('://')) {
          reporter.atToken(comment);
        }
      }

      comment = comment.next;
    }
  }
}

/// Warns when `// ignore:` or `// ignore_for_file:` has no space after the colon.
///
/// The Dart analyzer expects a space after the colon (e.g. `// ignore: rule_name`).
/// Without it, the directive may not suppress the lint. This rule detects the
/// missing space and offers a quick fix to insert it.
///
/// **Tier:** Stylistic (opt-in). **Impact:** Opinionated. **Cost:** Trivial
/// (single token walk). **Since:** v6.2.1.
///
/// **Detection:** Only reports when the comment content (after `//`) starts with
/// `ignore:` or `ignore_for_file:` and the character immediately after that
/// prefix is not space or tab. Does not report when the directive is already
/// correctly formatted or when the comment is merely describing ignore syntax.
///
/// **BAD:**
/// ```dart
/// // ignore:require_debouncer_cancel
/// // ignore_for_file:avoid_print
/// ```
///
/// **GOOD:**
/// ```dart
/// // ignore: require_debouncer_cancel
/// // ignore_for_file: avoid_print
/// ```
class RequireIgnoreCommentSpacingRule extends SaropaLintRule {
  RequireIgnoreCommentSpacingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.trivial;

  @override
  String get exampleBad => '// ignore:rule_name  // no space after colon';

  @override
  String get exampleGood => '// ignore: rule_name';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RequireIgnoreCommentSpacingFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'require_ignore_comment_spacing',
    '[require_ignore_comment_spacing] Put a space after the colon in '
        '// ignore: and // ignore_for_file: so the analyzer can apply the directive.',
    correctionMessage: 'Add a space after the colon.',
    severity: DiagnosticSeverity.INFO,
  );

  static const List<String> _ignorePrefixes = <String>[
    'ignore:',
    'ignore_for_file:',
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      Token? token = node.beginToken;
      while (token != null && token != node.endToken) {
        _checkPrecedingComments(token, reporter);
        token = token.next;
      }
    });
  }

  void _checkPrecedingComments(Token token, SaropaDiagnosticReporter reporter) {
    Token? comment = token.precedingComments;
    while (comment != null) {
      final String lexeme = comment.lexeme;
      if (lexeme.startsWith('//')) {
        final String content = lexeme.substring(2).trimLeft();
        for (final prefix in _ignorePrefixes) {
          if (content.startsWith(prefix)) {
            final afterColon = prefix.length;
            if (afterColon < content.length) {
              final next = content[afterColon];
              if (next != ' ' && next != '\t') {
                reporter.atToken(comment);
              }
            }
            break;
          }
        }
      }
      comment = comment.next;
    }
  }
}

/// Warns when `// ignore:` or `// ignore_for_file:` references a saropa_lints
/// rule without the required `saropa_lints/` prefix.
///
/// Since: v14.5.6 | Rule version: v1
///
/// The Dart analyzer's native-plugin pipeline requires diagnostics from
/// plugins to be suppressed with a namespaced form
/// (`// ignore: saropa_lints/rule_name`). A bare `// ignore: rule_name` is
/// silently ineffective for IDE-surfaced diagnostics — the comment is
/// accepted without error, but the diagnostic keeps reappearing.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// // ignore: avoid_null_assertion
/// final x = value!;
/// ```
///
/// #### GOOD:
/// ```dart
/// // ignore: saropa_lints/avoid_null_assertion
/// final x = value!;
/// ```
class RequireIgnoreCommentPluginPrefixRule extends SaropaLintRule {
  RequireIgnoreCommentPluginPrefixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.trivial;

  @override
  String get exampleBad =>
      '// ignore: avoid_null_assertion  // bare — silently ignored by IDE';

  @override
  String get exampleGood => '// ignore: saropa_lints/avoid_null_assertion';

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RequireIgnoreCommentPluginPrefixFix(context: context),
    ({required CorrectionProducerContext context}) =>
        ReplaceUnknownPrefixedRuleNameFix(context: context),
  ];

  /// Default diagnostic: bare saropa rule name missing the plugin prefix.
  static const LintCode _code = LintCode(
    'require_ignore_comment_plugin_prefix',
    '[require_ignore_comment_plugin_prefix] This // ignore: comment references '
        'a saropa_lints rule without the required saropa_lints/ prefix — the '
        'IDE and analyzer will not suppress this diagnostic. Prefix each '
        'saropa_lints rule name with saropa_lints/ so the suppression works.',
    correctionMessage: 'Add the saropa_lints/ prefix before the rule name.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final Set<String> _allSaropaRuleNames = rule_names.allSaropaRuleNames;

  static const _prefix = 'saropa_lints/';

  static const List<String> _ignorePrefixes = <String>[
    'ignore:',
    'ignore_for_file:',
  ];

  /// Temporarily holds a per-diagnostic LintCode override. Set just before
  /// reporting and cleared immediately after, so `diagnosticCode` returns
  /// the correct message for the unknown-prefix variant. Synchronous
  /// reporting guarantees this is safe (no interleaving).
  LintCode? _pendingCode;

  /// Returns the per-diagnostic override when set, otherwise the default.
  /// Fixes the bug where the unknown-prefix diagnostic showed the
  /// bare-name "add prefix" message because the reporter always reads
  /// `diagnosticCode` and ignores the optional LintCode argument.
  /// When _pendingCode is active, applies user-configured severity
  /// overrides so the unknown-prefix variant respects config too.
  @override
  DiagnosticCode get diagnosticCode {
    final pending = _pendingCode;
    if (pending == null) return super.diagnosticCode;
    // Check if the base getter applied a severity override. The base
    // returns the static _code (or a severity-overridden copy). Compare
    // against the static _code's severity to detect overrides.
    final base = super.diagnosticCode;
    if (base is LintCode && base.severity != _code.severity) {
      // User configured a severity override — apply it to the pending
      // code so both diagnostic variants honor the same config.
      return LintCode(
        pending.lowerCaseName,
        pending.problemMessage,
        correctionMessage: pending.correctionMessage,
        severity: base.severity,
      );
    }
    return pending;
  }

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      Token? token = node.beginToken;
      final end = node.endToken;
      while (token != null && token != end) {
        _checkPrecedingComments(token, reporter);
        token = token.next;
      }
      // endToken's own precedingComments are skipped by the loop above.
      _checkPrecedingComments(end, reporter);
    });
  }

  void _checkPrecedingComments(Token token, SaropaDiagnosticReporter reporter) {
    Token? comment = token.precedingComments;
    while (comment != null) {
      final String lexeme = comment.lexeme;
      if (lexeme.startsWith('//') && !lexeme.startsWith('///')) {
        final String content = lexeme.substring(2).trimLeft();
        for (final prefix in _ignorePrefixes) {
          if (content.startsWith(prefix)) {
            final ruleList = content.substring(prefix.length).trimLeft();
            // Check for bare saropa rule names (missing prefix).
            if (_hasBareRuleName(ruleList)) {
              reporter.atToken(comment);
            }
            // Check for prefixed names whose suffix isn't a real rule.
            // Swap diagnosticCode temporarily so the reporter emits the
            // "not a registered rule" message instead of "add prefix".
            final unknownSuffix = _firstUnknownPrefixedSuffix(ruleList);
            if (unknownSuffix != null) {
              // try/finally ensures _pendingCode is cleared even if
              // reporter.atToken throws, preventing stale diagnostic state.
              _pendingCode = _buildUnknownPrefixedCode(unknownSuffix);
              try {
                reporter.atToken(comment);
              } finally {
                _pendingCode = null;
              }
            }
            break;
          }
        }
      }
      comment = comment.next;
    }
  }

  /// Returns true when [ruleList] contains a bare (unprefixed) name that
  /// matches a registered saropa_lints rule.
  bool _hasBareRuleName(String ruleList) {
    final trailingComment = ruleList.indexOf('--');
    final effective = trailingComment >= 0
        ? ruleList.substring(0, trailingComment)
        : ruleList;

    for (final part in effective.split(',')) {
      final name = part.trim();
      if (name.isEmpty) continue;
      if (name.startsWith(_prefix)) continue;
      final bare = name.replaceAll('-', '_');
      if (_allSaropaRuleNames.contains(bare)) return true;
    }
    return false;
  }

  /// Returns the first unknown suffix from a prefixed ignore-comment name,
  /// or null if all prefixed names are registered.
  String? _firstUnknownPrefixedSuffix(String ruleList) {
    final trailingComment = ruleList.indexOf('--');
    final effective = trailingComment >= 0
        ? ruleList.substring(0, trailingComment)
        : ruleList;

    for (final part in effective.split(',')) {
      final name = part.trim();
      if (name.isEmpty) continue;
      if (!name.startsWith(_prefix)) continue;
      // Strip the prefix and normalize hyphens to underscores.
      final suffix = name.substring(_prefix.length).replaceAll('-', '_');
      if (suffix.isEmpty) continue;
      if (!_allSaropaRuleNames.contains(suffix)) return suffix;
    }
    return null;
  }

  /// Builds a diagnostic with a "did you mean?" suggestion when the unknown
  /// suffix is close to a registered rule name.
  LintCode _buildUnknownPrefixedCode(String unknownSuffix) {
    final suggestion = rule_names.closestRuleName(unknownSuffix);
    final didYouMean = suggestion != null
        ? ' Did you mean \'$suggestion\'?'
        : '';

    return LintCode(
      'require_ignore_comment_plugin_prefix',
      '[require_ignore_comment_plugin_prefix] This // ignore: comment uses '
          'saropa_lints/ prefix but \'$unknownSuffix\' is not a registered '
          'saropa_lints rule — the suppression has no effect because the '
          'analyzer matches ignore comments by exact rule id.$didYouMean',
      correctionMessage: suggestion != null
          ? 'Replace with saropa_lints/$suggestion.'
          : 'Replace the rule name with a registered saropa_lints rule name.',
      severity: DiagnosticSeverity.WARNING,
    );
  }
}

/// Warns when class members are not in the conventional order.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: sort_class_members, class_member_order, fields_before_methods,
/// prefer_sorted_members
///
/// Members should be ordered: fields, constructors, methods.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Foo {
///   void doSomething() {}
///   final int value;
///   Foo(this.value);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Foo {
///   final int value;
///   Foo(this.value);
///   void doSomething() {}
/// }
/// ```
///
/// Formerly: `enforce_member_ordering`
class MemberOrderingFormattingRule extends SaropaLintRule {
  MemberOrderingFormattingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'class Foo {\n'
      '  void doIt() {}\n'
      '  final int value;  // field after method\n'
      '}';

  @override
  String get exampleGood =>
      'class Foo {\n'
      '  final int value;\n'
      '  void doIt() {}\n'
      '}';

  @override
  List<String> get configAliases => const <String>[
    'enforce_member_ordering',
    'member_ordering',
    'prefer_sorted_members',
  ];

  static const LintCode _code = LintCode(
    'prefer_member_ordering',
    '[prefer_member_ordering] Class members are not in conventional order. Members must be ordered: fields, constructors, methods. {v4}',
    correctionMessage:
        'Reorder class members to follow the conventional layout: static fields, instance fields, constructors, then methods.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      int lastCategory = -1;

      for (final ClassMember member in node.bodyMembers) {
        final int category = _getMemberCategory(member);

        if (category < lastCategory) {
          reporter.atNode(member);
        }

        if (category > lastCategory) {
          lastCategory = category;
        }
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

/// Warns when parameters are not in conventional order.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: sort_parameters, parameter_order, required_before_optional
///
/// Parameters should be ordered: required positional, optional positional,
/// then named parameters (required named before optional named).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void foo({String? name}, int count) {}
/// ```
///
/// #### GOOD:
/// ```dart
/// void foo(int count, {String? name}) {}
/// ```
class ParametersOrderingConventionRule extends SaropaLintRule {
  ParametersOrderingConventionRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'void f({String? n}, int c) {}  // named before positional';

  @override
  String get exampleGood => 'void f(int c, {String? n}) {}';

  /// Alias: parameters_ordering
  @override
  List<String> get configAliases => const <String>['parameters_ordering'];

  static const LintCode _code = LintCode(
    'enforce_parameters_ordering',
    '[enforce_parameters_ordering] Ordering parameters in a specific sequence is a convention preference. Parameter order does not affect performance or compiled output. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Order: required positional, optional positional, named. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkParameters(node.functionExpression.parameters, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkParameters(node.parameters, reporter);
    });
  }

  void _checkParameters(
    FormalParameterList? params,
    SaropaDiagnosticReporter reporter,
  ) {
    if (params == null) return;

    int lastCategory = -1;
    for (final FormalParameter param in params.parameters) {
      final int category = _getParamCategory(param);

      if (category < lastCategory) {
        reporter.atNode(param);
      }

      if (category > lastCategory) {
        lastCategory = category;
      }
    }
  }

  int _getParamCategory(FormalParameter param) {
    if (param.isRequiredPositional) return 0;
    if (param.isOptionalPositional) return 1;
    if (param.isRequiredNamed) return 2;
    return 3; // Optional named
  }
}

/// Warns when enum constants are not in alphabetical order.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: sort_enum_constants, alphabetical_enum, enum_alphabetical_order
///
/// Keeping enum constants in alphabetical order improves readability
/// and makes it easier to find specific values.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// enum Priority {
///   high,
///   critical,
///   low,
///   medium,
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// enum Priority {
///   critical,
///   high,
///   low,
///   medium,
/// }
/// ```
class EnumConstantsOrderingRule extends SaropaLintRule {
  EnumConstantsOrderingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad => 'enum P { high, critical, low }  // not sorted';

  @override
  String get exampleGood => 'enum P { critical, high, low }  // alphabetical';

  static const LintCode _code = LintCode(
    'enum_constants_ordering',
    '[enum_constants_ordering] Ordering enum constants alphabetically is a stylistic preference. Enum constant order does not affect runtime behavior or performance. Enable via the stylistic tier. {v2}',
    correctionMessage:
        'Prefer ordering enum constants alphabetically. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addEnumDeclaration((EnumDeclaration node) {
      final List<EnumConstantDeclaration> constants = node.bodyConstants
          .toList();
      if (constants.length < 2) return;

      // Check if already sorted
      String? previousName;
      for (final EnumConstantDeclaration constant in constants) {
        final String currentName = constant.name.lexeme;
        if (previousName != null &&
            currentName.toLowerCase().compareTo(previousName.toLowerCase()) <
                0) {
          reporter.atNode(node);
          return; // Only report once per enum
        }
        previousName = currentName;
      }
    });
  }
}

// =============================================================================
// prefer_readable_line_length
// =============================================================================

/// Suggests keeping lines under ~80 characters for readability.
///
/// Long lines are harder to read and review. Prefer wrapping or breaking.
///
/// **Bad:** Lines over 80 characters.
///
/// **Good:** Wrap at ~80 characters or use dart format line length.
class PreferReadableLineLengthRule extends SaropaLintRule {
  PreferReadableLineLengthRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'final x = someVeryLongMethodName(argumentOne, argumentTwo, argumentThree, argumentFour);  // >80 chars';

  @override
  String get exampleGood =>
      'final x = someMethod(\n'
      '  argOne,\n'
      '  argTwo,\n'
      ');';

  static const LintCode _code = LintCode(
    'prefer_readable_line_length',
    '[prefer_readable_line_length] Line exceeds 80 characters. '
        'Consider wrapping for readability.',
    correctionMessage:
        'Break long lines at ~80 characters or configure dart format line length.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _maxLineLength = 80;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      final LineInfo lineInfo = context.lineInfo;
      final String content = context.fileContent;
      for (int i = 0; i < lineInfo.lineCount; i++) {
        final int lineStart = lineInfo.getOffsetOfLine(i);
        final int lineEnd = i + 1 < lineInfo.lineCount
            ? lineInfo.getOffsetOfLine(i + 1) - 1
            : content.length;
        final int length = lineEnd - lineStart;
        if (length > _maxLineLength) {
          reporter.atOffset(offset: lineStart, length: length.clamp(1, 81));
          return;
        }
      }
    });
  }
}

// =============================================================================
// blank-line-before-exit-statement family: break / continue / throw
// =============================================================================
//
// Shared helper for the three rules below. `break`, `continue`, and (via its
// wrapping ExpressionStatement) `throw` are all block-exiting statements, so
// each rule needs to find the statement's preceding sibling in the same
// enclosing statement list to check for a blank-line gap. A `switch` case
// body is a [SwitchMember], NOT a [Block] — `NewlineBeforeCaseRule` already
// relies on this distinction — so both are handled here to match the DCM
// parity proposals' bad-example switch/case scenarios.

/// Returns the index of [statement] within its enclosing statement list
/// (a [Block]'s `statements` or a [SwitchMember]'s `statements`), or `null`
/// when there is no such enclosing list, or when [statement] is the first
/// (or only) statement in it. The `index <= 0` case is intentionally treated
/// as "nothing to separate from" — mirrors the guard in
/// [NewlineBeforeReturnRule] that skips a lone/leading return.
int? _blankLineBeforeExitSiblingIndex(Statement statement) {
  final AstNode? parent = statement.parent;

  // Both Block and SwitchMember expose a `NodeList<Statement> statements`
  // list, but they are unrelated types, so a switch expression picks the
  // right accessor rather than duplicating the lookup/index logic twice.
  final NodeList<Statement>? statements = switch (parent) {
    Block block => block.statements,
    SwitchMember member => member.statements,
    _ => null,
  };
  if (statements == null) return null;

  final int index = statements.indexOf(statement);
  if (index <= 0) return null;
  return index;
}

/// Returns true when [statement] (at [index] within [statements]) is not
/// preceded by a full blank line — i.e. the gap between the previous
/// statement's end line and this statement's start line is less than 2.
bool _blankLineBeforeExitIsMissing(
  LineInfo lineInfo,
  NodeList<Statement> statements,
  int index,
  Statement statement,
) {
  final Statement previous = statements[index - 1];
  final int prevEndLine = lineInfo.getLocation(previous.end).lineNumber;
  final int startLine = lineInfo.getLocation(statement.offset).lineNumber;
  return startLine - prevEndLine < 2;
}

/// Warns when a `break` statement is not preceded by a blank line.
///
/// Since: v15.3.0 | Rule version: v1
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_break, newline_before_break, break_spacing
///
/// A blank line before `break` visually marks the loop/switch exit point
/// and separates it from the logic that led to it — the same rationale
/// already documented for [NewlineBeforeReturnRule]. Closes the DCM
/// `newline-before-break` parity gap.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (x) {
///   case 1:
///     doSomething();
///     break;  // no blank line
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// switch (x) {
///   case 1:
///     doSomething();
///
///     break;
/// }
/// ```
class PreferBlankLineBeforeBreakRule extends SaropaLintRule {
  PreferBlankLineBeforeBreakRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  // No addBreakStatement callback exists in the native RuleVisitorRegistry
  // (unlike addContinueStatement/addThrowExpression), so this rule walks the
  // whole compilation unit with a RecursiveAstVisitor — the same workaround
  // used by AvoidLabeledStatementsRule for LabeledStatement.
  @override
  RuleCost get cost => RuleCost.high;

  @override
  String get exampleBad =>
      'switch (x) {\n'
      '  case 1:\n'
      '    doSomething();\n'
      '    break;  // no blank line\n'
      '}';

  @override
  String get exampleGood =>
      'switch (x) {\n'
      '  case 1:\n'
      '    doSomething();\n'
      '\n'
      '    break;\n'
      '}';

  @override
  List<String> get configAliases => const <String>[
    'blank_line_before_break',
    'newline_before_break',
    'break_spacing',
  ];

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeStatementFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_break',
    '[prefer_blank_line_before_break] Adding a blank line before a break statement is a formatting preference with no impact on code behavior or performance, but it visually marks the loop/switch exit point and separates it from the logic that led to it. Enable via the stylistic tier. {v1}',
    correctionMessage:
        'Add a blank line before this break statement. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      node.visitChildren(
        _BreakStatementBlankLineVisitor(reporter, context.lineInfo),
      );
    });
  }
}

/// Walks an AST subtree reporting every [BreakStatement] missing a blank
/// line before it, so labeled/nested breaks anywhere in the file (not just
/// at the top level) are caught.
class _BreakStatementBlankLineVisitor extends RecursiveAstVisitor<void> {
  _BreakStatementBlankLineVisitor(this.reporter, this.lineInfo);

  final SaropaDiagnosticReporter reporter;
  final LineInfo lineInfo;

  @override
  void visitBreakStatement(BreakStatement node) {
    final int? index = _blankLineBeforeExitSiblingIndex(node);
    if (index == null) return;

    // `parent` is guaranteed non-null here because
    // _blankLineBeforeExitSiblingIndex only returns non-null when it found
    // a Block or SwitchMember statements list off node.parent.
    final AstNode parent = node.parent!;
    final NodeList<Statement> statements = parent is Block
        ? parent.statements
        : (parent as SwitchMember).statements;

    if (_blankLineBeforeExitIsMissing(lineInfo, statements, index, node)) {
      reporter.atNode(node);
    }

    super.visitBreakStatement(node);
  }
}

/// Warns when a `continue` statement is not preceded by a blank line.
///
/// Since: v15.3.0 | Rule version: v1
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_continue, newline_before_continue, continue_spacing
///
/// A blank line before `continue` visually marks the loop-control exit
/// point, distinguishing it from ordinary sequential statements — the same
/// rationale already documented for [NewlineBeforeReturnRule]. Closes the
/// DCM `newline-before-continue` parity gap.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// for (final item in items) {
///   if (item.isInvalid) {
///     log('skipping');
///     continue;  // no blank line
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// for (final item in items) {
///   if (item.isInvalid) {
///     log('skipping');
///
///     continue;
///   }
/// }
/// ```
class PreferBlankLineBeforeContinueRule extends SaropaLintRule {
  PreferBlankLineBeforeContinueRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  // addContinueStatement is a native single-node-kind callback (unlike
  // break's missing callback), so this is a cheap per-node check.
  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'for (final x in xs) {\n'
      '  if (x.invalid) {\n'
      '    log(x);\n'
      '    continue;  // no blank line\n'
      '  }\n'
      '}';

  @override
  String get exampleGood =>
      'for (final x in xs) {\n'
      '  if (x.invalid) {\n'
      '    log(x);\n'
      '\n'
      '    continue;\n'
      '  }\n'
      '}';

  @override
  List<String> get configAliases => const <String>[
    'blank_line_before_continue',
    'newline_before_continue',
    'continue_spacing',
  ];

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeStatementFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_continue',
    '[prefer_blank_line_before_continue] Adding a blank line before a continue statement is a formatting preference with no impact on code behavior or performance, but it visually marks the loop-control exit point and distinguishes it from ordinary sequential logic. Enable via the stylistic tier. {v1}',
    correctionMessage:
        'Add a blank line before this continue statement. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addContinueStatement((ContinueStatement node) {
      final int? index = _blankLineBeforeExitSiblingIndex(node);
      if (index == null) return;

      final AstNode parent = node.parent!;
      final NodeList<Statement> statements = parent is Block
          ? parent.statements
          : (parent as SwitchMember).statements;

      if (_blankLineBeforeExitIsMissing(
        context.lineInfo,
        statements,
        index,
        node,
      )) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a `throw` statement is not preceded by a blank line.
///
/// Since: v15.3.0 | Rule version: v1
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Alias: blank_line_before_throw, newline_before_throw, throw_spacing
///
/// A `throw` statement is a block-exiting statement, structurally identical
/// to `return` for this purpose — the same rationale already documented for
/// [NewlineBeforeReturnRule]. Closes the DCM `newline-before-throw` parity
/// gap.
///
/// **Scope:** only visits block-level `throw` statements (an
/// [ExpressionStatement] wrapping a [ThrowExpression]), matching
/// `return`'s scope. An inline throw-*expression* used inside a ternary or
/// `??` chain (e.g. `value ?? (throw StateError('required'))`) has no
/// preceding sibling statement to compare against and is intentionally not
/// flagged. `rethrow` (a [RethrowExpression], not a [ThrowExpression]) is
/// out of scope for this rule version — see
/// `plans/tier_1_quick_wins/proposal_prefer_blank_line_before_throw.md` edge
/// case 2 for the follow-up decision.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (trimmed.isEmpty) {
///   throw ArgumentError('id cannot be empty');  // no blank line
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// if (trimmed.isEmpty) {
///   log('rejecting empty id');
///
///   throw ArgumentError('id cannot be empty');
/// }
/// ```
class PreferBlankLineBeforeThrowRule extends SaropaLintRule {
  PreferBlankLineBeforeThrowRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention'};

  // addThrowExpression is a native single-node-kind callback, so this is a
  // cheap per-node check (same cost class as prefer_blank_line_before_continue).
  @override
  RuleCost get cost => RuleCost.medium;

  @override
  String get exampleBad =>
      'if (trimmed.isEmpty) {\n'
      "  throw ArgumentError('empty');  // no blank line\n"
      '}';

  @override
  String get exampleGood =>
      'if (trimmed.isEmpty) {\n'
      "  log('rejecting');\n"
      '\n'
      "  throw ArgumentError('empty');\n"
      '}';

  @override
  List<String> get configAliases => const <String>[
    'blank_line_before_throw',
    'newline_before_throw',
    'throw_spacing',
  ];

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddBlankLineBeforeStatementFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_blank_line_before_throw',
    '[prefer_blank_line_before_throw] Adding a blank line before a throw statement is a formatting preference with no impact on code behavior or performance, but it visually marks the point where control leaves the enclosing block, matching the same rationale already applied to return statements. Enable via the stylistic tier. {v1}',
    correctionMessage:
        'Add a blank line before this throw statement. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
      // Only handle block-level `throw stmt;` — a throw used as an inline
      // expression (ternary/??) has no enclosing statement list to compare
      // against and must not be flagged (see class doc "Scope").
      final AstNode? parent = node.parent;
      if (parent is! ExpressionStatement) return;

      final int? index = _blankLineBeforeExitSiblingIndex(parent);
      if (index == null) return;

      final AstNode statementParent = parent.parent!;
      final NodeList<Statement> statements = statementParent is Block
          ? statementParent.statements
          : (statementParent as SwitchMember).statements;

      if (_blankLineBeforeExitIsMissing(
        context.lineInfo,
        statements,
        index,
        parent,
      )) {
        // Report on the ExpressionStatement (the whole `throw ...;`), not
        // just the ThrowExpression, so the quick fix inserts before the
        // full statement's own line.
        reporter.atNode(parent);
      }
    });
  }
}
