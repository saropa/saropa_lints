// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Documentation lint rules for Flutter/Dart applications.
///
/// These rules help enforce documentation standards and ensure
/// code is properly documented for maintainability.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when public API lacks documentation.
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
class RequirePublicApiDocumentationRule extends DartLintRule {
  const RequirePublicApiDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_public_api_documentation',
    problemMessage: 'Public API should be documented.',
    correctionMessage: 'Add a doc comment explaining the purpose and usage.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidMisleadingDocumentationRule extends DartLintRule {
  const AvoidMisleadingDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_misleading_documentation',
    problemMessage: 'Documentation may not match the method name.',
    correctionMessage: 'Ensure documentation accurately describes the code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireDeprecationMessageRule extends DartLintRule {
  const RequireDeprecationMessageRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_deprecation_message',
    problemMessage: 'Deprecated annotation should include migration guidance.',
    correctionMessage:
        'Use @Deprecated("message") with explanation of what to use instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

/// Warns when complex methods lack explanatory comments.
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
class RequireComplexLogicCommentsRule extends DartLintRule {
  const RequireComplexLogicCommentsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_complex_logic_comments',
    problemMessage: 'Complex method lacks explanatory comments.',
    correctionMessage:
        'Add comments explaining the logic, especially for chained operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _complexityThreshold = 3;

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireParameterDocumentationRule extends DartLintRule {
  const RequireParameterDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_parameter_documentation',
    problemMessage: 'Parameters should be documented.',
    correctionMessage: 'Add [paramName] documentation for each parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _paramThreshold = 2;

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireReturnDocumentationRule extends DartLintRule {
  const RequireReturnDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_return_documentation',
    problemMessage: 'Return value should be documented.',
    correctionMessage: 'Add documentation explaining what the method returns.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireExceptionDocumentationRule extends DartLintRule {
  const RequireExceptionDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_exception_documentation',
    problemMessage: 'Thrown exceptions should be documented.',
    correctionMessage: 'Add "Throws [ExceptionType]" to documentation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireExampleInDocumentationRule extends DartLintRule {
  const RequireExampleInDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_example_in_documentation',
    problemMessage: 'Public class documentation should include an example.',
    correctionMessage: 'Add an example code block showing typical usage.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
