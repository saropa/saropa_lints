// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Documentation lint rules for Flutter/Dart applications.
///
/// These rules help enforce documentation standards and ensure
/// code is properly documented for maintainability.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
  const RequirePublicApiDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_public_api_documentation',
    problemMessage:
        '[require_public_api_documentation] Public API must be documented. Public classes, methods, and properties must have doc comments to help other developers understand their purpose. {v4}',
    correctionMessage:
        'Add a doc comment explaining the purpose and usage. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip private classes
      if (node.name.lexeme.startsWith('_')) return;

      // Check for documentation comment
      if (node.documentationComment == null) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      // Skip overridden methods (they inherit docs)
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') return;
      }

      // Check if in public class
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl != null && classDecl.name.lexeme.startsWith('_')) return;

      if (node.documentationComment == null) {
        reporter.atNode(node, code);
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
  const AvoidMisleadingDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_misleading_documentation',
    problemMessage:
        '[avoid_misleading_documentation] Documentation does not match the method name or code behavior. Mismatched docs confuse maintainers and lead to incorrect usage. {v4}',
    correctionMessage:
        'Update documentation to match the method name and actual code behavior. Example: If the method is getUserEmail(), the doc should describe returning the user email, not something else.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final Comment? docComment = node.documentationComment;
      if (docComment == null) return;

      final String methodName = node.name.lexeme.toLowerCase();
      final String docText =
          docComment.tokens.map((Token t) => t.lexeme).join(' ').toLowerCase();

      // Check for common mismatches
      if (methodName.contains('get') && docText.contains('sets ')) {
        reporter.atNode(docComment, code);
      }
      if (methodName.contains('set') &&
          docText.contains('gets ') &&
          !docText.contains('sets ')) {
        reporter.atNode(docComment, code);
      }
      if (methodName.contains('delete') && docText.contains('creates ')) {
        reporter.atNode(docComment, code);
      }
      if (methodName.contains('create') && docText.contains('deletes ')) {
        reporter.atNode(docComment, code);
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
  const RequireDeprecationMessageRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_deprecation_message',
    problemMessage:
        '[require_deprecation_message] Deprecated annotation should include migration guidance. Missing documentation makes the API harder to use correctly and increases onboarding time. {v6}',
    correctionMessage:
        'Use @Deprecated("message") with explanation of what to use instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  List<Fix> get customFixes => [_UseDeprecatedWithMessageFix()];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAnnotation((Annotation node) {
      final String name = node.name.name;

      // Check for lowercase @deprecated (without message)
      if (name == 'deprecated') {
        reporter.atNode(node, code);
        return;
      }

      // Check for @Deprecated with empty or generic message
      if (name == 'Deprecated') {
        final ArgumentList? args = node.arguments;
        if (args == null || args.arguments.isEmpty) {
          reporter.atNode(node, code);
          return;
        }

        final String message = args.arguments.first.toSource();
        final String msgLower = message.toLowerCase();
        if (msgLower.contains("'deprecated'") ||
            msgLower.contains('"deprecated"') ||
            message.length < 20) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

class _UseDeprecatedWithMessageFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addAnnotation((Annotation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.name.name != 'deprecated') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: "Replace with @Deprecated('...')",
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          "@Deprecated('TODO: Add migration guidance.')",
        );
      });
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
  const RequireComplexLogicCommentsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_complex_logic_comments',
    problemMessage:
        '[require_complex_logic_comments] Complex method lacks explanatory comments. Complex logic must have comments explaining the reasoning. {v5}',
    correctionMessage:
        'Add comments explaining the logic, especially for chained operations. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _complexityThreshold = 3;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
            bodySource.contains('//') || bodySource.contains('/*');
        if (!hasComments && node.documentationComment == null) {
          reporter.atNode(node, code);
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
  const RequireParameterDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_parameter_documentation',
    problemMessage:
        '[require_parameter_documentation] Parameters must be documented. Parameters must be documented to explain their purpose. Parameter documentation is missing for public methods. {v5}',
    correctionMessage:
        'Add [paramName] documentation for each parameter. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _paramThreshold = 2;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      // Only check methods with multiple parameters
      if (params.parameters.length < _paramThreshold) return;

      final Comment? docComment = node.documentationComment;
      if (docComment == null) return;

      final String docText =
          docComment.tokens.map((Token t) => t.lexeme).join(' ');

      // Check if parameters are documented
      for (final FormalParameter param in params.parameters) {
        final String? paramName = _getParameterName(param);
        if (paramName != null && !paramName.startsWith('_')) {
          if (!docText.contains('[$paramName]')) {
            reporter.atNode(param, code);
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
  const RequireReturnDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_return_documentation',
    problemMessage:
        '[require_return_documentation] Return value must be documented. Non-void methods should document what they return. Return value documentation is missing. {v4}',
    correctionMessage:
        'Add documentation explaining what the method returns. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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

      final String docText =
          docComment.tokens.map((Token t) => t.lexeme).join(' ').toLowerCase();

      // Check for return documentation
      if (!docText.contains('return') && !docText.contains('yields')) {
        reporter.atNode(node, code);
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
  const RequireExceptionDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_exception_documentation',
    problemMessage:
        '[require_exception_documentation] Thrown exceptions must be documented. Methods that throw should document the exceptions. Exception documentation is missing. {v4}',
    correctionMessage:
        'Add "Throws [ExceptionType]" to documentation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip private methods
      if (node.name.lexeme.startsWith('_')) return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check if method throws
      if (!bodySource.contains('throw ')) return;

      final Comment? docComment = node.documentationComment;
      if (docComment == null) {
        reporter.atNode(node, code);
        return;
      }

      final String docText =
          docComment.tokens.map((Token t) => t.lexeme).join(' ').toLowerCase();

      // Check for throw documentation
      if (!docText.contains('throw')) {
        reporter.atNode(node, code);
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
  const RequireExampleInDocumentationRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_example_in_documentation',
    problemMessage:
        '[require_example_in_documentation] Public class documentation should include an example. Complex classes benefit from example usage in their docs. {v4}',
    correctionMessage:
        'Add an example code block showing typical usage. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip private classes
      if (node.name.lexeme.startsWith('_')) return;

      // Only check complex classes
      final String className = node.name.lexeme;
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

      final String docText =
          docComment.tokens.map((Token t) => t.lexeme).join(' ');

      // Check for example code block
      if (!docText.contains('```') && !docText.contains('Example')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a dartdoc `[name]` references a parameter that does not exist
///
/// Since: v4.10.1 | Updated: v4.13.0 | Rule version: v2
///
/// in the function, method, or constructor signature.
///
/// The existing `require_parameter_documentation` rule checks that real
/// parameters are documented. This rule checks the inverse: that documented
/// `[names]` actually correspond to real parameters (or valid type/field
/// references).
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
  const VerifyDocumentedParametersExistRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'verify_documented_parameters_exist',
    problemMessage:
        '[verify_documented_parameters_exist] Documentation references '
        'a parameter that does not exist in the signature. {v3}',
    correctionMessage:
        'Remove the stale parameter reference or update it to match '
        'an actual parameter name.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Creates a [LintCode] with the specific ghost parameter name.
  static LintCode _codeForName(String name) => LintCode(
        name: 'verify_documented_parameters_exist',
        problemMessage:
            '[verify_documented_parameters_exist] Documentation references '
            "'[$name]' which does not exist in the signature. {v3}",
        correctionMessage:
            'Remove the stale parameter reference or update it to match '
            'an actual parameter name.',
        errorSeverity: DiagnosticSeverity.WARNING,
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

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkDeclaration(
        docComment: node.documentationComment,
        parameters: node.parameters,
        enclosingClass: node.thisOrAncestorOfType<ClassDeclaration>(),
        reporter: reporter,
      );
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkDeclaration(
        docComment: node.documentationComment,
        parameters: node.functionExpression.parameters,
        reporter: reporter,
      );
    });

    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
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
    final String docText =
        docComment.tokens.map((Token t) => t.lexeme).join('\n');

    // Iterate per-token so reported offsets map to the correct source line.
    // Joining tokens into a single string loses inter-line gaps (non-doc
    // comment lines, blank lines), which shifts offsets.
    int docTextOffset = 0;
    for (final Token token in docComment.tokens) {
      final String lexeme = token.lexeme;
      for (final RegExpMatch match
          in _bracketedNamePattern.allMatches(lexeme)) {
        final String name = match.group(1)!;

        if (paramNames.contains(name)) continue;
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
          errorCode: _codeForName(name),
        );
      }
      docTextOffset += lexeme.length + 1; // +1 for join('\n')
    }
  }

  /// Returns true when the context around `[Name]` at [start]..[end] in
  /// [docText] confirms it is a parameter reference, not a type reference.
  bool _isConfirmedParameterRef(
    String docText,
    int start,
    int end,
  ) {
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
    for (final ClassMember member in classDecl.members) {
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
