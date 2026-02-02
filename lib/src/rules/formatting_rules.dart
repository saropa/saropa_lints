// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, todo

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when case clauses don't have newlines before them.
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
  const NewlineBeforeCaseRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_case',
    problemMessage:
        '[prefer_blank_line_before_case] Add a newline before case clause for readability.',
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
  const NewlineBeforeConstructorRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_constructor',
    problemMessage:
        '[prefer_blank_line_before_constructor] Add a blank line before constructor declaration.',
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
  const NewlineBeforeMethodRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_method',
    problemMessage:
        '[prefer_blank_line_before_method] Add a blank line before method declaration.',
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
/// Alias: blank_line_before_return, return_spacing, newline_before_return
///
/// Adding a blank line before return statements can improve readability
/// by visually separating the return from the preceding logic.
class NewlineBeforeReturnRule extends SaropaLintRule {
  const NewlineBeforeReturnRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_blank_line_before_return',
    problemMessage:
        '[prefer_blank_line_before_return] Add a blank line before the return statement.',
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
  const PreferTrailingCommaRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_trailing_comma',
    problemMessage:
        '[prefer_trailing_comma] Missing trailing comma in multi-line construct.',
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
  const UnnecessaryTrailingCommaRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'unnecessary_trailing_comma',
    problemMessage:
        '[unnecessary_trailing_comma] Unnecessary trailing comma for single-element collection.',
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
  const FormatCommentFormattingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'format_comment_style',
    problemMessage:
        '[format_comment_style] Comment does not follow formatting conventions.',
    correctionMessage: 'Start with capital letter and end with punctuation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Annotation markers that have their own formatting conventions.
  static final RegExp _annotationMarker = RegExp(
    r'^(TODO|FIXME|FIX|NOTE|HACK|XXX|BUG|OPTIMIZE|WARNING|CHANGED|REVIEW|DEPRECATED|IMPORTANT|MARK)\b',
    caseSensitive: false,
  );

  // Cached regex for performance - matches lowercase start
  static final RegExp _lowercaseStart = RegExp(r'^[a-z]');

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
          reporter.atToken(comment, code);
        }
      }

      comment = comment.next;
    }
  }
}

/// Warns when class members are not in the conventional order.
///
/// Alias: sort_class_members, class_member_order, fields_before_methods
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
  const MemberOrderingFormattingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases =>
      const <String>['enforce_member_ordering', 'member_ordering'];

  static const LintCode _code = LintCode(
    name: 'prefer_member_ordering',
    problemMessage:
        '[prefer_member_ordering] Class members are not in conventional order.',
    correctionMessage:
        'Reorder class members to follow the conventional layout: static fields, instance fields, constructors, then methods.',
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
  const ParametersOrderingConventionRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: parameters_ordering
  @override
  List<String> get configAliases => const <String>['parameters_ordering'];

  static const LintCode _code = LintCode(
    name: 'enforce_parameters_ordering',
    problemMessage:
        '[enforce_parameters_ordering] Parameters are not in conventional order.',
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

/// Warns when enum constants are not in alphabetical order.
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
  const EnumConstantsOrderingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'enum_constants_ordering',
    problemMessage:
        '[enum_constants_ordering] Enum constants are not in alphabetical order.',
    correctionMessage: 'Consider ordering enum constants alphabetically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addEnumDeclaration((EnumDeclaration node) {
      final List<EnumConstantDeclaration> constants = node.constants.toList();
      if (constants.length < 2) return;

      // Check if already sorted
      String? previousName;
      for (final EnumConstantDeclaration constant in constants) {
        final String currentName = constant.name.lexeme;
        if (previousName != null &&
            currentName.toLowerCase().compareTo(previousName.toLowerCase()) <
                0) {
          reporter.atNode(node, code);
          return; // Only report once per enum
        }
        previousName = currentName;
      }
    });
  }
}
