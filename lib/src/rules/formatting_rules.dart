// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when case clauses don't have newlines before them.
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
  const NewlineBeforeCaseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_case',
    problemMessage: 'Add a newline before case clause for readability.',
    correctionMessage: 'Add blank line before this case.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final NodeList<SwitchMember> members = node.members;

      for (int i = 1; i < members.length; i++) {
        final SwitchMember current = members[i];
        final SwitchMember previous = members[i - 1];

        // Skip if previous is a fall-through (empty statements)
        if (previous.statements.isEmpty) continue;

        // Check if there's a blank line before current case
        final CompilationUnit unit = node.root as CompilationUnit;
        final int prevEndLine =
            unit.lineInfo.getLocation(previous.end).lineNumber;
        final int currStartLine =
            unit.lineInfo.getLocation(current.offset).lineNumber;

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
  const NewlineBeforeConstructorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_constructor',
    problemMessage: 'Add a blank line before constructor declaration.',
    correctionMessage: 'Add blank line for better readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      _checkMembers(node.members, node.root as CompilationUnit, reporter);
    });
  }

  void _checkMembers(
    NodeList<ClassMember> members,
    CompilationUnit unit,
    SaropaDiagnosticReporter reporter,
  ) {
    for (int i = 1; i < members.length; i++) {
      final ClassMember current = members[i];
      final ClassMember previous = members[i - 1];

      // Only check constructors
      if (current is! ConstructorDeclaration) continue;

      // Get line numbers
      final int prevEndLine =
          unit.lineInfo.getLocation(previous.end).lineNumber;
      final int currStartLine =
          unit.lineInfo.getLocation(current.offset).lineNumber;

      // Should have at least one blank line
      if (currStartLine - prevEndLine < 2) {
        final Token? nameToken = current.name;
        if (nameToken != null) {
          reporter.atToken(nameToken, code);
        } else {
          reporter.atNode(current.returnType, code);
        }
      }
    }
  }
}

/// Warns when methods don't have blank lines before them.
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
  const NewlineBeforeMethodRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_method',
    problemMessage: 'Add a blank line before method declaration.',
    correctionMessage: 'Add blank line for better readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      _checkMembers(node.members, node.root as CompilationUnit, reporter);
    });

    context.registry.addMixinDeclaration((MixinDeclaration node) {
      _checkMembers(node.members, node.root as CompilationUnit, reporter);
    });

    context.registry.addEnumDeclaration((EnumDeclaration node) {
      _checkMembers(node.members, node.root as CompilationUnit, reporter);
    });
  }

  void _checkMembers(
    NodeList<ClassMember> members,
    CompilationUnit unit,
    SaropaDiagnosticReporter reporter,
  ) {
    for (int i = 1; i < members.length; i++) {
      final ClassMember current = members[i];
      final ClassMember previous = members[i - 1];

      // Only check methods
      if (current is! MethodDeclaration) continue;

      // Get line numbers
      final int prevEndLine =
          unit.lineInfo.getLocation(previous.end).lineNumber;
      final int currStartLine =
          unit.lineInfo.getLocation(current.offset).lineNumber;

      // Should have at least one blank line
      if (currStartLine - prevEndLine < 2) {
        reporter.atToken(current.name, code);
      }
    }
  }
}

/// Warns when there's no blank line before a return statement.
///
/// Adding a blank line before return statements can improve readability
/// by visually separating the return from the preceding logic.
class NewlineBeforeReturnRule extends SaropaLintRule {
  const NewlineBeforeReturnRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_return',
    problemMessage: 'Add a blank line before the return statement.',
    correctionMessage: 'Insert a blank line before return for readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addReturnStatement((ReturnStatement node) {
      final AstNode? parent = node.parent;
      if (parent is! Block) return;

      final List<Statement> statements = parent.statements;
      final int index = statements.indexOf(node);

      // Don't warn if it's the first or only statement
      if (index <= 0) return;

      // Check if previous statement ends on the line immediately before
      final Statement previous = statements[index - 1];
      final int prevEndLine =
          resolver.lineInfo.getLocation(previous.end).lineNumber;
      final int returnStartLine =
          resolver.lineInfo.getLocation(node.offset).lineNumber;

      if (returnStartLine - prevEndLine < 2) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddBlankLineBeforeReturnFix()];
}

class _AddBlankLineBeforeReturnFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addReturnStatement((ReturnStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add blank line before return',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.offset, '\n');
      });
    });
  }
}

/// Warns when multi-line constructs are missing trailing commas.
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
  const PreferTrailingCommaRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_trailing_comma',
    problemMessage: 'Missing trailing comma in multi-line construct.',
    correctionMessage: 'Add a trailing comma.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addArgumentList((ArgumentList node) {
      _checkTrailingComma(node.arguments, node.rightParenthesis, reporter);
    });

    context.registry.addListLiteral((ListLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });

    context.registry.addFormalParameterList((FormalParameterList node) {
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
        reporter.atNode(last, code);
      }
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTrailingCommaFix()];
}

class _AddTrailingCommaFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
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
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.elements.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.elements.last.end, ',');
      });
    });

    context.registry.addArgumentList((ArgumentList node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.arguments.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.arguments.last.end, ',');
      });
    });
  }
}

/// Warns when trailing commas are unnecessary.
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
  const UnnecessaryTrailingCommaRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'unnecessary_trailing_comma',
    problemMessage: 'Unnecessary trailing comma for single-element collection.',
    correctionMessage: 'Remove trailing comma or keep on single line.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      _checkTrailingComma(node.elements, node.rightBracket, reporter);
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
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
      reporter.atToken(nextToken, code);
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveTrailingCommaFix()];
}

class _RemoveTrailingCommaFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      if (node.elements.length != 1) return;
      final Token? commaToken = node.elements.first.endToken.next;
      if (commaToken == null || commaToken.type != TokenType.COMMA) return;
      if (!SourceRange(commaToken.offset, commaToken.length)
          .intersects(analysisError.sourceRange)) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addDeletion(SourceRange(commaToken.offset, commaToken.length));
      });
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.elements.length != 1) return;
      final Token? commaToken = node.elements.first.endToken.next;
      if (commaToken == null || commaToken.type != TokenType.COMMA) return;
      if (!SourceRange(commaToken.offset, commaToken.length)
          .intersects(analysisError.sourceRange)) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove trailing comma',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addDeletion(SourceRange(commaToken.offset, commaToken.length));
      });
    });
  }
}

/// Warns when comments don't follow formatting conventions.
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
  const FormatCommentFormattingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'format_comment',
    problemMessage: 'Comment does not follow formatting conventions.',
    correctionMessage: 'Start with capital letter and end with punctuation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Comments are not part of the AST, so we need to check tokens
    context.registry.addCompilationUnit((CompilationUnit node) {
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
            content.startsWith('TODO') ||
            content.startsWith('FIXME') ||
            content.startsWith('HACK') ||
            content.startsWith('XXX')) {
          comment = comment.next;
          continue;
        }

        // Check if starts with lowercase (excluding URLs and code)
        if (content.isNotEmpty &&
            content[0].toLowerCase() == content[0] &&
            RegExp(r'^[a-z]').hasMatch(content) &&
            !content.startsWith('http') &&
            !content.contains('://')) {
          reporter.atToken(comment, code);
        }
      }

      comment = comment.next;
    }
  }
}

/// Warns when class members are not in the conventional order.
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
class MemberOrderingFormattingRule extends SaropaLintRule {
  const MemberOrderingFormattingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'member_ordering',
    problemMessage: 'Class members are not in conventional order.',
    correctionMessage:
        'Order members: static fields, fields, constructors, methods.',
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

      for (final ClassMember member in node.members) {
        final int category = _getMemberCategory(member);

        if (category < lastCategory) {
          reporter.atNode(member, code);
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
  const ParametersOrderingConventionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'parameters_ordering',
    problemMessage: 'Parameters are not in conventional order.',
    correctionMessage:
        'Order: required positional, optional positional, named.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkParameters(node.functionExpression.parameters, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkParameters(node.parameters, reporter);
    });
  }

  void _checkParameters(
      FormalParameterList? params, SaropaDiagnosticReporter reporter) {
    if (params == null) return;

    int lastCategory = -1;
    for (final FormalParameter param in params.parameters) {
      final int category = _getParamCategory(param);

      if (category < lastCategory) {
        reporter.atNode(param, code);
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
