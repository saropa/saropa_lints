// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Documentation lint rules for Flutter/Dart applications.
///
/// These rules help enforce documentation standards and ensure
/// code is properly documented for maintainability.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';

/// Warns when public API lacks documentation.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Public classes, methods, and properties should have doc comments
/// to help other developers understand their purpose.
///
/// **BAD:**
/// ```dart
/// class UserService {
///   Future<User> getUser(String id) async { ... }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Service for managing user operations.
/// class UserService {
///   /// Retrieves a user by their unique identifier.
///   ///
///   /// Throws [UserNotFoundException] if user doesn't exist.
///   Future<User> getUser(String id) async { ... }
/// }
/// ```
class RequirePublicApiDocumentationRule extends SaropaLintRule {
  RequirePublicApiDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_public_api_documentation',
    '[require_public_api_documentation] Public API must be documented. Public classes, methods, and properties must have doc comments to help other developers understand their purpose. {v4}',
    correctionMessage:
        'Add a doc comment explaining the purpose and usage. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Skip private classes
      if (node.namePart.typeName.lexeme.startsWith('_')) return;

      // Check for documentation comment
      if (node.documentationComment == null) {
        reporter.atNode(node);
      }
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      // Skip overridden methods (they inherit docs)
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') return;
      }

      // Check if in public class
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl != null &&
          classDecl.namePart.typeName.lexeme.startsWith('_')) {
        return;
      }

      if (node.documentationComment == null) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when documentation is outdated or misleading.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Doc comments should accurately describe the code behavior.
///
/// **BAD:**
/// ```dart
/// /// Returns the user's name.
/// String getUserEmail() => user.email; // Doc says name but returns email
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Returns the user's email address.
/// String getUserEmail() => user.email;
/// ```
class AvoidMisleadingDocumentationRule extends SaropaLintRule {
  AvoidMisleadingDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_misleading_documentation',
    '[avoid_misleading_documentation] Documentation does not match the method name or code behavior. Mismatched docs confuse maintainers and lead to incorrect usage. {v4}',
    correctionMessage:
        'Update documentation to match the method name and actual code behavior. Example: If the method is getUserEmail(), the doc should describe returning the user email, not something else.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final Comment? docComment = node.documentationComment;
      if (docComment == null) return;

      final String methodName = node.name.lexeme.toLowerCase();
      final String docText = docComment.tokens
          .map((Token t) => t.lexeme)
          .join(' ')
          .toLowerCase();

      // Check for common mismatches (word-boundary for method name)
      if ((methodName == 'get' || methodName.startsWith('get')) &&
          docText.contains('sets ')) {
        reporter.atNode(docComment);
      }
      if ((methodName == 'set' || methodName.startsWith('set')) &&
          docText.contains('gets ') &&
          !docText.contains('sets ')) {
        reporter.atNode(docComment);
      }
      if ((methodName == 'delete' || methodName.startsWith('delete')) &&
          docText.contains('creates ')) {
        reporter.atNode(docComment);
      }
      if ((methodName == 'create' || methodName.startsWith('create')) &&
          docText.contains('deletes ')) {
        reporter.atNode(docComment);
      }
    });
  }
}

/// Warns when deprecated API lacks migration guidance.
///
/// Since: v4.9.7 | Updated: v4.13.0 | Rule version: v6
///
/// Deprecated APIs should explain what to use instead.
///
/// **BAD:**
/// ```dart
/// @deprecated
/// void oldMethod() { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// @Deprecated('Use newMethod() instead. Will be removed in v2.0.')
/// void oldMethod() { ... }
/// ```
class RequireDeprecationMessageRule extends SaropaLintRule {
  RequireDeprecationMessageRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_deprecation_message',
    '[require_deprecation_message] Deprecated annotation should include migration guidance. Missing documentation makes the API harder to use correctly and increases onboarding time. {v6}',
    correctionMessage:
        'Use @Deprecated("message") with explanation of what to use instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );
  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAnnotation((Annotation node) {
      final String name = node.name.name;

      // Check for lowercase @deprecated (without message)
      if (name == 'deprecated') {
        reporter.atNode(node);
        return;
      }

      // Check for @Deprecated with empty or generic message
      if (name == 'Deprecated') {
        final ArgumentList? args = node.arguments;
        if (args == null || args.arguments.isEmpty) {
          reporter.atNode(node);
          return;
        }

        final String message = args.arguments.first.toSource();
        final String msgLower = message.toLowerCase();
        if (msgLower.contains("'deprecated'") ||
            msgLower.contains('"deprecated"') ||
            message.length < 20) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when complex methods lack explanatory comments.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Complex logic should have comments explaining the reasoning.
///
/// **BAD:**
/// ```dart
/// double calculate(List<Item> items) {
///   return items.where((i) => i.active && i.price > 0)
///     .map((i) => i.price * (1 - i.discount) * (i.taxable ? 1.08 : 1))
///     .fold(0, (a, b) => a + b);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// double calculate(List<Item> items) {
///   // Filter to only active items with valid prices
///   // Apply discounts and tax as applicable
///   // Sum all line totals
///   return items.where((i) => i.active && i.price > 0)
///     .map((i) => i.price * (1 - i.discount) * (i.taxable ? 1.08 : 1))
///     .fold(0, (a, b) => a + b);
/// }
/// ```
class RequireComplexLogicCommentsRule extends SaropaLintRule {
  RequireComplexLogicCommentsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_complex_logic_comments',
    '[require_complex_logic_comments] Complex method lacks explanatory comments. Complex logic must have comments explaining the reasoning. {v5}',
    correctionMessage:
        'Add comments explaining the logic, especially for chained operations. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _lineCommentRegex = RegExp(r'//');
  static final RegExp _blockCommentStartRegex = RegExp(r'/\*');
  static const int _complexityThreshold = 3;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;

      // Count complexity indicators
      int complexity = 0;
      final String bodySource = body.toSource();

      // Check for chained method calls
      complexity += '.where('.allMatches(bodySource).length;
      complexity += '.map('.allMatches(bodySource).length;
      complexity += '.fold('.allMatches(bodySource).length;
      complexity += '.reduce('.allMatches(bodySource).length;
      complexity += '.expand('.allMatches(bodySource).length;

      // Check for ternary operators
      complexity += '?'.allMatches(bodySource).length;

      if (complexity >= _complexityThreshold) {
        // Check if there are any comments
        final bool hasComments =
            _lineCommentRegex.hasMatch(bodySource) ||
            _blockCommentStartRegex.hasMatch(bodySource);
        if (!hasComments && node.documentationComment == null) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when parameter documentation is missing for public methods.
///
/// Since: v4.10.1 | Updated: v4.13.0 | Rule version: v5
///
/// Parameters should be documented to explain their purpose.
///
/// **BAD:**
/// ```dart
/// /// Creates a new user.
/// Future<User> createUser(String name, String email, int age) { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Creates a new user.
/// ///
/// /// [name] The user's full name.
/// /// [email] The user's email address for notifications.
/// /// [age] The user's age in years (must be >= 18).
/// Future<User> createUser(String name, String email, int age) { ... }
/// ```
class RequireParameterDocumentationRule extends SaropaLintRule {
  RequireParameterDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_parameter_documentation',
    '[require_parameter_documentation] Parameters must be documented. Parameters must be documented to explain their purpose. Parameter documentation is missing for public methods. {v5}',
    correctionMessage:
        'Add [paramName] documentation for each parameter. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _paramThreshold = 2;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      // Only check methods with multiple parameters
      if (params.parameters.length < _paramThreshold) return;

      final Comment? docComment = node.documentationComment;
      if (docComment == null) return;

      final String docText = docComment.tokens
          .map((Token t) => t.lexeme)
          .join(' ');

      // Check if parameters are documented
      for (final FormalParameter param in params.parameters) {
        final String? paramName = _getParameterName(param);
        if (paramName != null && !paramName.startsWith('_')) {
          if (!docText.contains('[$paramName]')) {
            reporter.atNode(param);
          }
        }
      }
    });
  }

  String? _getParameterName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.name?.lexeme;
    } else if (param is DefaultFormalParameter) {
      return _getParameterName(param.parameter);
    } else if (param is FieldFormalParameter) {
      return param.name.lexeme;
    }
    return null;
  }
}

/// Warns when return value documentation is missing.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Non-void methods should document what they return.
///
/// **BAD:**
/// ```dart
/// /// Processes the order.
/// OrderResult processOrder(Order order) { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Processes the order.
/// ///
/// /// Returns [OrderResult] with success status and tracking number,
/// /// or error details if processing failed.
/// OrderResult processOrder(Order order) { ... }
/// ```
class RequireReturnDocumentationRule extends SaropaLintRule {
  RequireReturnDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_return_documentation',
    '[require_return_documentation] Return value must be documented. Non-void methods should document what they return. Return value documentation is missing. {v4}',
    correctionMessage:
        'Add documentation explaining what the method returns. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      // Skip void methods
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      final String returnTypeName = returnType.toSource();
      if (returnTypeName == 'void' || returnTypeName == 'Future<void>') return;

      // Skip getters (obvious return)
      if (node.isGetter) return;

      final Comment? docComment = node.documentationComment;
      if (docComment == null) return;

      final String docText = docComment.tokens
          .map((Token t) => t.lexeme)
          .join(' ')
          .toLowerCase();

      // Check for return documentation
      if (!docText.contains('return') && !docText.contains('yields')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when exception documentation is missing.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Methods that throw should document the exceptions.
///
/// **BAD:**
/// ```dart
/// /// Gets the user.
/// User getUser(String id) {
///   if (id.isEmpty) throw ArgumentError('ID required');
///   return _users[id] ?? throw UserNotFoundException(id);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Gets the user.
/// ///
/// /// Throws [ArgumentError] if [id] is empty.
/// /// Throws [UserNotFoundException] if no user with [id] exists.
/// User getUser(String id) { ... }
/// ```
class RequireExceptionDocumentationRule extends SaropaLintRule {
  RequireExceptionDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static final RegExp _throwKeywordRegex = RegExp(r'\bthrow\s');

  static const LintCode _code = LintCode(
    'require_exception_documentation',
    '[require_exception_documentation] Thrown exceptions must be documented. Methods that throw should document the exceptions. Exception documentation is missing. {v4}',
    correctionMessage:
        'Add "Throws [ExceptionType]" to documentation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check if method throws
      if (!_throwKeywordRegex.hasMatch(bodySource)) return;

      final Comment? docComment = node.documentationComment;
      if (docComment == null) {
        reporter.atNode(node);
        return;
      }

      final String docText = docComment.tokens
          .map((Token t) => t.lexeme)
          .join(' ')
          .toLowerCase();

      // Check for throw documentation
      if (!docText.contains('throw')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when public class lacks example usage in documentation.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Complex classes benefit from example usage in their docs.
///
/// **BAD:**
/// ```dart
/// /// Repository for managing user data.
/// class UserRepository { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Repository for managing user data.
/// ///
/// /// Example:
/// /// ```dart
/// /// final repo = UserRepository(database);
/// /// final user = await repo.getById('123');
/// /// ```
/// class UserRepository { ... }
/// ```
class RequireExampleInDocumentationRule extends SaropaLintRule {
  RequireExampleInDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_example_in_documentation',
    '[require_example_in_documentation] Public class documentation should include an example. Complex classes benefit from example usage in their docs. {v4}',
    correctionMessage:
        'Add an example code block showing typical usage. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _complexClassSuffixes = <String>{
    'Repository',
    'Service',
    'Controller',
    'Manager',
    'Handler',
    'Provider',
    'Factory',
    'Builder',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Skip private classes
      if (node.namePart.typeName.lexeme.startsWith('_')) return;

      // Only check complex classes
      final String className = node.namePart.typeName.lexeme;
      bool isComplexClass = false;
      for (final String suffix in _complexClassSuffixes) {
        if (className.endsWith(suffix)) {
          isComplexClass = true;
          break;
        }
      }
      if (!isComplexClass) return;

      final Comment? docComment = node.documentationComment;
      if (docComment == null) return;

      final String docText = docComment.tokens
          .map((Token t) => t.lexeme)
          .join(' ');

      // Check for example code block
      if (!docText.contains('```') && !docText.contains('Example')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a dartdoc `[name]` reference does not match any parameter,
/// type, or field in scope.
///
/// **Since:** v4.10.1 | **Updated:** v4.13.0 | **Rule version:** v3
///
/// The existing `require_parameter_documentation` rule checks that real
/// parameters are documented. This rule checks the inverse: that documented
/// `[names]` correspond to real parameters, class fields, or known doc
/// references (e.g. built-in types, literals).
///
/// **Suppressions:** No lint for `[String]`, `[int]`, `[null]`, `[true]`,
/// `[false]`, or other `_knownDocRefNames`; single-letter uppercase (type
/// params); PascalCase only when confirmed as parameter context (bullet or
/// "parameter"/"argument" keyword); class field names.
///
/// **BAD:**
/// ```dart
/// /// Restores from [context] for the toast.
/// Future<bool> fileRestore(String filePath) async { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Restores from [filePath].
/// Future<bool> fileRestore(String filePath) async { ... }
/// ```
class VerifyDocumentedParametersExistRule extends SaropaLintRule {
  VerifyDocumentedParametersExistRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'verify_documented_parameters_exist',
    '[verify_documented_parameters_exist] Documentation references '
        'a parameter that does not exist in the signature. {v3}',
    correctionMessage:
        'Remove the stale parameter reference or update it to match '
        'an actual parameter name.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Pattern to extract `[bracketedName]` from doc comments.
  ///
  /// Matches `[name]` but not `[name.field]` (dotted refs are
  /// field/enum accesses, not parameter references).
  static final RegExp _bracketedNamePattern = RegExp(r'\[([a-zA-Z_]\w*)\]');

  /// Words after `[name]` that confirm parameter intent.
  static const Set<String> _parameterKeywords = <String>{
    'parameter',
    'param',
    'argument',
    'arg',
  };

  /// Built-in types and literals that are valid doc references (not parameters).
  /// Suppresses false positives for [String], [int], `null`, `true`, `false`, etc.
  static const Set<String> _knownDocRefNames = <String>{
    'null',
    'true',
    'false',
    'String',
    'int',
    'bool',
    'double',
    'num',
    'List',
    'Map',
    'Set',
    'Iterable',
    'Future',
    'Stream',
    'Object',
    'dynamic',
    'void',
    'Never',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      _checkDeclaration(
        docComment: node.documentationComment,
        parameters: node.parameters,
        enclosingClass: node.thisOrAncestorOfType<ClassDeclaration>(),
        reporter: reporter,
      );
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkDeclaration(
        docComment: node.documentationComment,
        parameters: node.functionExpression.parameters,
        reporter: reporter,
      );
    });

    context.addConstructorDeclaration((ConstructorDeclaration node) {
      _checkDeclaration(
        docComment: node.documentationComment,
        parameters: node.parameters,
        enclosingClass: node.thisOrAncestorOfType<ClassDeclaration>(),
        reporter: reporter,
      );
    });
  }

  void _checkDeclaration({
    required Comment? docComment,
    required FormalParameterList? parameters,
    ClassDeclaration? enclosingClass,
    required SaropaDiagnosticReporter reporter,
  }) {
    if (docComment == null) return;
    if (parameters == null) return;

    final Set<String> paramNames = _extractParamNames(parameters);
    final Set<String> classFieldNames = _extractClassFieldNames(enclosingClass);

    // Joined text for semantic context (e.g. bullet/keyword detection).
    final String docText = docComment.tokens
        .map((Token t) => t.lexeme)
        .join('\n');

    // Iterate per-token so reported offsets map to the correct source line.
    // Joining tokens into a single string loses inter-line gaps (non-doc
    // comment lines, blank lines), which shifts offsets.
    int docTextOffset = 0;
    for (final Token token in docComment.tokens) {
      final String lexeme = token.lexeme;
      for (final RegExpMatch match in _bracketedNamePattern.allMatches(
        lexeme,
      )) {
        final String? name = match.group(1);
        if (name == null) continue;

        if (paramNames.contains(name)) continue;
        if (_knownDocRefNames.contains(name)) continue;
        if (name.length == 1 && name == name.toUpperCase()) continue;

        if (name[0] == name[0].toUpperCase()) {
          final int joinedStart = docTextOffset + match.start;
          final int joinedEnd = docTextOffset + match.end;
          if (!_isConfirmedParameterRef(docText, joinedStart, joinedEnd)) {
            continue;
          }
        }

        if (classFieldNames.contains(name)) continue;

        reporter.atOffset(
          offset: match.start + token.offset,
          length: match.end - match.start,
        );
      }
      docTextOffset += lexeme.length + 1; // +1 for join('\n')
    }
  }

  /// Returns true when the context around `[Name]` at [start]..[end] in
  /// [docText] confirms it is a parameter reference, not a type reference.
  bool _isConfirmedParameterRef(String docText, int start, int end) {
    // Bullet-style: `/// - [Name]`
    if (start >= 2) {
      final String before = docText.substring(start - 2, start).trimLeft();
      if (before.endsWith('-')) return true;
    }

    // Keyword after: `[Name] parameter`, `[Name] argument`
    if (end < docText.length) {
      final String after = docText.substring(end).trimLeft();
      final String firstWord =
          after.split(RegExp(r'\s+')).firstOrNull?.toLowerCase() ?? '';
      if (_parameterKeywords.contains(firstWord)) return true;
    }

    return false;
  }

  Set<String> _extractParamNames(FormalParameterList parameters) {
    final Set<String> names = <String>{};
    for (final FormalParameter param in parameters.parameters) {
      final String? name = _getParameterName(param);
      if (name != null) names.add(name);
    }
    return names;
  }

  Set<String> _extractClassFieldNames(ClassDeclaration? classDecl) {
    if (classDecl == null) return const <String>{};
    final Set<String> names = <String>{};
    for (final ClassMember member in classDecl.body.members) {
      if (member is FieldDeclaration) {
        for (final VariableDeclaration variable in member.fields.variables) {
          names.add(variable.name.lexeme);
        }
      }
    }
    return names;
  }

  String? _getParameterName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.name?.lexeme;
    } else if (param is DefaultFormalParameter) {
      return _getParameterName(param.parameter);
    } else if (param is FieldFormalParameter) {
      return param.name.lexeme;
    } else if (param is SuperFormalParameter) {
      return param.name.lexeme;
    }
    return null;
  }
}

/// Suggests documenting thrown exceptions with `@Throws` annotation.
///
/// Since: v4.13.0 | Rule version: v1
///
/// **Bad:**
/// ```dart
/// void loadUser(String id) {
///   if (id.isEmpty) throw ArgumentError('id');
/// }
/// ```
///
/// **Good:**
/// ```dart
/// @Throws(ArgumentError)
/// void loadUser(String id) {
///   if (id.isEmpty) throw ArgumentError('id');
/// }
/// ```
class PreferCorrectThrowsRule extends SaropaLintRule {
  PreferCorrectThrowsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_throws',
    '[prefer_correct_throws] Document thrown exceptions with @Throws annotation. Methods that throw should declare @Throws so callers know what to catch.',
    correctionMessage:
        'Add @Throws(ExceptionType) to the declaration (e.g. from package:documentation or a custom annotation).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme.startsWith('_')) return;
      if (_hasThrowsAnnotation(node.metadata)) return;
      if (!_bodyContainsThrow(node.body)) return;
      reporter.atNode(node, _code);
    });
    context.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme.startsWith('_')) return;
      if (node.name.lexeme == 'main') return;
      if (_hasThrowsAnnotation(node.metadata)) return;
      if (!_bodyContainsThrow(node.functionExpression.body)) return;
      reporter.atNode(node, _code);
    });
  }

  static bool _hasThrowsAnnotation(NodeList<Annotation> metadata) {
    for (final Annotation a in metadata) {
      if (a.name.name == 'Throws') return true;
    }
    return false;
  }

  static bool _bodyContainsThrow(FunctionBody body) {
    var found = false;
    body.visitChildren(_ThrowFinder(() => found = true));
    return found;
  }
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  _ThrowFinder(this._onThrow);

  final void Function() _onThrow;

  @override
  void visitThrowExpression(ThrowExpression node) {
    _onThrow();
    super.visitThrowExpression(node);
  }
}

// =============================================================================
// Shared doc comment utilities
// =============================================================================

/// Strips `///`, `/** */`, or ` * ` prefix from a doc comment token.
///
/// Handles all standard Dart doc comment formats:
/// - `/// content` and `///` (triple-slash)
/// - `/** content` (block doc start)
/// - ` * content` and ` *` (block doc continuation)
String _stripDocCommentPrefix(String line) {
  if (line.startsWith('/// ')) return line.substring(4);
  if (line.startsWith('///')) return line.substring(3);
  if (line.startsWith('/** ')) return line.substring(4);
  if (line.startsWith('/**')) return line.substring(3);
  if (line.startsWith(' * ')) return line.substring(3);
  if (line.startsWith(' *')) return line.substring(2);
  return line;
}

/// Fence regex: matches ``` at start of content (after optional whitespace)
/// with nothing after it except optional trailing whitespace. Used for both
/// opening fences without language tags and closing fences, since they are
/// syntactically identical. Start-anchored to avoid false matches on prose.
final RegExp _fenceWithoutTag = RegExp(r'^\s*```\s*$');

/// Fence regex: matches ``` at start of content (after optional whitespace),
/// immediately followed by a word character indicating a language tag
/// (e.g. ```dart, ```json). Start-anchored to avoid false matches on prose
/// like "Example using ```dart blocks:" where the fence is mid-line.
final RegExp _fenceWithTag = RegExp(r'^\s*```\w');

/// Visits all doc comments in a compilation unit — both top-level
/// declarations AND class/enum/mixin/extension members.
void _visitAllDocComments(
  CompilationUnit unit,
  void Function(Comment docComment) callback,
) {
  for (final declaration in unit.declarations) {
    // Top-level declaration doc comment
    final topDoc = declaration.documentationComment;
    if (topDoc != null) callback(topDoc);

    // Member doc comments inside classes, enums, mixins, extensions
    final NodeList<ClassMember>? members;
    if (declaration is ClassDeclaration) {
      members = declaration.body.members;
    } else if (declaration is EnumDeclaration) {
      members = declaration.body.members;
    } else if (declaration is MixinDeclaration) {
      members = declaration.body.members;
    } else if (declaration is ExtensionDeclaration) {
      members = declaration.body.members;
    } else if (declaration is ExtensionTypeDeclaration) {
      members = declaration.body.members;
    } else {
      members = null;
    }

    if (members == null) continue;
    for (final member in members) {
      final memberDoc = member.documentationComment;
      if (memberDoc != null) callback(memberDoc);
    }
  }
}

// =============================================================================
// missing_code_block_language_in_doc_comment
// =============================================================================

/// Warns when a fenced code block in a doc comment lacks a language tag.
///
/// Since: v9.10.0 | Rule version: v2
///
/// Code blocks in doc comments should specify a language (e.g. ```dart)
/// for proper syntax highlighting in generated documentation and IDEs.
/// Checks doc comments on top-level declarations and class members.
///
/// **BAD:**
/// ```dart
/// /// Example:
/// /// ```
/// /// final x = 1;
/// /// ```
/// class MyClass {}
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Example:
/// /// ```dart
/// /// final x = 1;
/// /// ```
/// class MyClass {}
/// ```
class MissingCodeBlockLanguageInDocCommentRule extends SaropaLintRule {
  MissingCodeBlockLanguageInDocCommentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'documentation'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'missing_code_block_language_in_doc_comment',
    '[missing_code_block_language_in_doc_comment] Fenced code block in doc comment is missing a language identifier. Without a language tag (e.g. ```dart), generated documentation and IDEs cannot apply syntax highlighting, reducing readability and discoverability of code examples. {v2}',
    correctionMessage:
        'Add a language identifier after the opening fence, e.g. ```dart.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      _visitAllDocComments(unit, (Comment doc) {
        _checkDocComment(doc, reporter);
      });
    });
  }

  void _checkDocComment(Comment docComment, SaropaDiagnosticReporter reporter) {
    bool inCodeBlock = false;

    for (final Token token in docComment.tokens) {
      final String content = _stripDocCommentPrefix(token.lexeme);

      if (inCodeBlock) {
        // Inside a code block — look for closing fence
        if (_fenceWithoutTag.hasMatch(content)) {
          inCodeBlock = false;
        }
        continue;
      }

      // Outside code block — check for opening fence
      if (_fenceWithTag.hasMatch(content)) {
        inCodeBlock = true; // Has a language tag — good
        continue;
      }

      if (_fenceWithoutTag.hasMatch(content)) {
        // Opening fence without language tag — report
        reporter.atNode(docComment);
        return; // One report per doc comment is enough
      }
    }
  }
}

// =============================================================================
// unintended_html_in_doc_comment
// =============================================================================

/// Warns when angle brackets in doc comments may be interpreted as HTML.
///
/// Since: v9.10.0 | Rule version: v2
///
/// Angle brackets like `<String>` or `<int>` in doc comment prose are
/// interpreted as HTML tags by documentation generators, causing content
/// to disappear or render incorrectly. Wrap in backticks or use `[...]`.
/// Checks both top-level and member doc comments. Skips content inside
/// fenced code blocks and inline backtick-delimited code.
///
/// **BAD:**
/// ```dart
/// /// Returns a `List<String>` of names.
/// void getNames() {}
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Returns a `List<String>` of names.
/// void getNames() {}
/// ```
class UnintendedHtmlInDocCommentRule extends SaropaLintRule {
  UnintendedHtmlInDocCommentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'documentation'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'unintended_html_in_doc_comment',
    '[unintended_html_in_doc_comment] Angle brackets in doc comment text may be interpreted as HTML tags by documentation generators. Content like <String> or <MyType> will be treated as unknown HTML elements, causing text to disappear or render incorrectly in generated documentation. {v2}',
    correctionMessage:
        'Wrap the type reference in backticks (e.g. `List<String>`) or use square bracket references (e.g. [List]<[String]>).',
    severity: DiagnosticSeverity.INFO,
  );

  /// Matches `<word>` patterns that look like unintended HTML.
  /// Captures the first word inside angle brackets (e.g. `String` from
  /// `<String>`, or `String` from `<String, int>`). Does not match
  /// nested generics like `<Map<String, int>>` as a whole — it matches
  /// the innermost `<String, int>` fragment.
  static final RegExp _angleBracketType = RegExp(r'<(\w+)(?:\s*,\s*\w+)*>');

  /// Known safe HTML tags intentionally used in doc comments.
  static const Set<String> _safeHtmlTags = <String>{
    'br',
    'p',
    'b',
    'i',
    'em',
    'strong',
    'code',
    'pre',
    'ul',
    'ol',
    'li',
    'a',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'table',
    'tr',
    'td',
    'th',
    'thead',
    'tbody',
    'blockquote',
    'hr',
    'div',
    'span',
    'img',
    'sup',
    'sub',
  };

  /// Single uppercase letters used as generic type parameters.
  static final RegExp _singleTypeParam = RegExp(r'^[A-Z]$');

  /// Strips inline code spans (backtick-wrapped) from a line.
  static final RegExp _inlineCode = RegExp(r'`[^`]+`');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      _visitAllDocComments(unit, (Comment doc) {
        _checkDocComment(doc, reporter);
      });
    });
  }

  void _checkDocComment(Comment docComment, SaropaDiagnosticReporter reporter) {
    bool inCodeBlock = false;

    for (final Token token in docComment.tokens) {
      final String content = _stripDocCommentPrefix(token.lexeme);

      // Track code block boundaries using end-of-line-anchored regex
      // to avoid false toggles from prose mentions of triple backticks.
      if (_fenceWithTag.hasMatch(content) ||
          _fenceWithoutTag.hasMatch(content)) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;

      // Strip inline code spans before checking for angle brackets
      final String withoutInlineCode = content.replaceAll(_inlineCode, '');

      for (final Match match in _angleBracketType.allMatches(
        withoutInlineCode,
      )) {
        final String innerType = match.group(1) ?? '';
        if (_safeHtmlTags.contains(innerType.toLowerCase())) continue;
        if (_singleTypeParam.hasMatch(innerType)) continue;

        reporter.atNode(docComment);
        return; // One report per doc comment
      }
    }
  }
}

// =============================================================================
// uri_does_not_exist_in_doc_import
// =============================================================================

/// Warns when a `@docImport` URI refers to a non-existent file.
///
/// Since: v9.10.0 | Rule version: v2
///
/// The `@docImport` directive (Dart 3.2+) imports symbols for use in
/// doc comment references. A broken URI means those references will fail
/// silently, producing broken links in generated documentation.
///
/// `@docImport` is only valid in the library-level doc comment (the doc
/// comment before the `library;` directive). This rule checks only that
/// location.
///
/// **BAD:**
/// ```dart
/// /// @docImport 'missing_file.dart';
/// library;
/// ```
///
/// **GOOD:**
/// ```dart
/// /// @docImport 'existing_file.dart';
/// library;
/// ```
class UriDoesNotExistInDocImportRule extends SaropaLintRule {
  UriDoesNotExistInDocImportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'documentation'};

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'uri_does_not_exist_in_doc_import',
    '[uri_does_not_exist_in_doc_import] A @docImport URI refers to a file that does not exist. Broken doc imports cause documentation references ([ClassName]) to fail silently, producing broken links in generated documentation and preventing IDE navigation to the referenced symbols. {v2}',
    correctionMessage:
        'Fix the URI to point to an existing file, or remove the @docImport if it is no longer needed.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Matches @docImport directives in doc comments.
  /// Captures the URI string (single or double quoted).
  static final RegExp _docImportPattern = RegExp(
    r'''@docImport\s+['"]([^'"]+)['"]''',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      // @docImport is only valid in the library-level doc comment
      // (before the `library;` directive). Check only that location.
      final Comment? libraryDoc = unit.directives
          .whereType<LibraryDirective>()
          .firstOrNull
          ?.documentationComment;

      if (libraryDoc == null) return;
      _checkForBrokenDocImports(libraryDoc, context.filePath, reporter);
    });
  }

  void _checkForBrokenDocImports(
    Comment docComment,
    String filePath,
    SaropaDiagnosticReporter reporter,
  ) {
    final String docText = docComment.tokens
        .map((Token t) => t.lexeme)
        .join('\n');

    for (final Match match in _docImportPattern.allMatches(docText)) {
      final String uri = match.group(1) ?? '';
      if (uri.isEmpty) continue;

      // Skip package: and dart: URIs — we can't resolve those without
      // package_config. They are less likely to have broken paths.
      if (uri.startsWith('package:') || uri.startsWith('dart:')) continue;

      // Resolve relative URI against the current file's directory
      final String dir = filePath.replaceAll('\\', '/');
      final int lastSlash = dir.lastIndexOf('/');
      if (lastSlash < 0) continue;
      final String dirPath = dir.substring(0, lastSlash);
      final String resolvedPath = '$dirPath/$uri';

      if (!File(resolvedPath).existsSync()) {
        reporter.atNode(docComment);
        return; // One report per doc comment
      }
    }
  }
}

// =============================================================================
// deprecated_new_in_comment_reference
// =============================================================================

/// Doc comments should not use deprecated `new` in reference links.
///
/// Since: v10.0.3 | Rule version: v1
///
/// Dart doc style prefers `[TypeName]` over `[new TypeName]`.
///
/// **BAD:**
/// ```dart
/// /// See [new Object] for details.
/// class C {}
/// ```
///
/// **GOOD:**
/// ```dart
/// /// See [Object] for details.
/// class C {}
/// ```
class DeprecatedNewInCommentReferenceRule extends SaropaLintRule {
  DeprecatedNewInCommentReferenceRule() : super(code: _code);

  @override
  Set<String>? get requiredPatterns => const {'[new '};

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'documentation'};

  @override
  RuleCost get cost => RuleCost.low;

  static final RegExp _newRef = RegExp(r'\[\s*new\s+[\w.]+\s*\]');

  static const LintCode _code = LintCode(
    'deprecated_new_in_comment_reference',
    '[deprecated_new_in_comment_reference] Documentation references should not use the deprecated `new` keyword inside `[...]` links. Use `[ClassName]` or `[prefix.ClassName]` instead. {v1}',
    correctionMessage:
        'Remove `new` from the doc reference so it uses modern Dart doc link syntax.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      void checkDoc(Comment? doc) {
        if (doc == null) return;
        final String text = doc.tokens.map((Token t) => t.lexeme).join(' ');
        if (_newRef.hasMatch(text)) {
          reporter.atNode(doc, code);
        }
      }

      checkDoc(_libraryDocFromUnit(unit));

      for (final Declaration decl in unit.declarations) {
        _walkDeclarationForDoc(decl, checkDoc);
      }
    });
  }

  /// Library doc from a `library` directive when present.
  static Comment? _libraryDocFromUnit(CompilationUnit unit) {
    for (final Directive d in unit.directives) {
      if (d is LibraryDirective) {
        return d.documentationComment;
      }
    }
    return null;
  }

  static void _walkDeclarationForDoc(
    Declaration decl,
    void Function(Comment?) checkDoc,
  ) {
    checkDoc(decl.documentationComment);
    if (decl is ClassDeclaration) {
      for (final ClassMember m in decl.body.members) {
        if (m is MethodDeclaration) {
          checkDoc(m.documentationComment);
        } else if (m is FieldDeclaration) {
          checkDoc(m.documentationComment);
        } else if (m is ConstructorDeclaration) {
          checkDoc(m.documentationComment);
        }
      }
    } else if (decl is MixinDeclaration) {
      for (final ClassMember m in decl.body.members) {
        if (m is MethodDeclaration) checkDoc(m.documentationComment);
        if (m is FieldDeclaration) checkDoc(m.documentationComment);
      }
    } else if (decl is EnumDeclaration) {
      for (final EnumConstantDeclaration c in decl.body.constants) {
        checkDoc(c.documentationComment);
      }
      for (final ClassMember m in decl.body.members) {
        if (m is MethodDeclaration) checkDoc(m.documentationComment);
        if (m is FieldDeclaration) checkDoc(m.documentationComment);
        if (m is ConstructorDeclaration) checkDoc(m.documentationComment);
      }
    } else if (decl is ExtensionDeclaration) {
      for (final ClassMember m in decl.body.members) {
        if (m is MethodDeclaration) checkDoc(m.documentationComment);
        if (m is FieldDeclaration) checkDoc(m.documentationComment);
      }
    }
  }
}
