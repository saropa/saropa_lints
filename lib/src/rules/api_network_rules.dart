// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// API and network lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper API usage patterns, network error
/// handling, and resilient communication with backend services.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when HTTP response status is not checked.
///
/// API responses should always check status codes before processing.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(url);
/// final data = jsonDecode(response.body); // No status check
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(url);
/// if (response.statusCode == 200) {
///   final data = jsonDecode(response.body);
/// } else {
///   throw HttpException('Failed: ${response.statusCode}');
/// }
/// ```
class RequireHttpStatusCheckRule extends DartLintRule {
  const RequireHttpStatusCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_http_status_check',
    problemMessage: 'HTTP response status should be checked.',
    correctionMessage: 'Check response.statusCode before processing body.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP calls
      if (!bodySource.contains('http.get') &&
          !bodySource.contains('http.post') &&
          !bodySource.contains('http.put') &&
          !bodySource.contains('http.delete') &&
          !bodySource.contains('.get(') &&
          !bodySource.contains('.post(')) {
        return;
      }

      // Check if statusCode is checked
      if (!bodySource.contains('statusCode') &&
          !bodySource.contains('isSuccessful')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when API calls lack timeout configuration.
///
/// Network requests should have timeouts to prevent indefinite waiting.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(url);
/// final response = await dio.get(path);
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(url).timeout(Duration(seconds: 30));
/// final response = await dio.get(path,
///   options: Options(sendTimeout: 30000, receiveTimeout: 30000));
/// ```
class RequireApiTimeoutRule extends DartLintRule {
  const RequireApiTimeoutRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_api_timeout',
    problemMessage: 'API call should have a timeout configured.',
    correctionMessage: 'Add .timeout() or configure timeout in options.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for common HTTP methods
      if (methodName != 'get' &&
          methodName != 'post' &&
          methodName != 'put' &&
          methodName != 'delete' &&
          methodName != 'patch') {
        return;
      }

      // Check target - should be http client
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('http') &&
          !targetSource.contains('dio') &&
          !targetSource.contains('client')) {
        return;
      }

      // Check if parent chain contains .timeout()
      AstNode? current = node.parent;
      bool hasTimeout = false;

      while (current != null) {
        if (current is MethodInvocation &&
            current.methodName.name == 'timeout') {
          hasTimeout = true;
          break;
        }
        // Check if statement block contains timeout
        if (current is MethodDeclaration) {
          final String bodySource = current.body.toSource();
          if (bodySource.contains('Timeout') ||
              bodySource.contains('timeout') ||
              bodySource.contains('connectTimeout') ||
              bodySource.contains('receiveTimeout')) {
            hasTimeout = true;
          }
          break;
        }
        current = current.parent;
      }

      if (!hasTimeout) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when API endpoint URLs are hardcoded.
///
/// API URLs should come from configuration for different environments.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(
///   Uri.parse('https://api.example.com/users'));
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(
///   Uri.parse('${ApiConfig.baseUrl}/users'));
/// ```
class AvoidHardcodedApiUrlsRule extends DartLintRule {
  const AvoidHardcodedApiUrlsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_api_urls',
    problemMessage: 'API URL should not be hardcoded.',
    correctionMessage: 'Use configuration constants for API URLs.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _apiUrlPattern = RegExp(
    r'https?://[a-zA-Z0-9.-]+\.(com|io|net|org|dev|app)/api',
    caseSensitive: false,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip config files
    final String path = resolver.source.fullName;
    if (path.contains('config') || path.contains('constants')) return;

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (_apiUrlPattern.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when retry logic is missing for network calls.
///
/// Network operations should handle transient failures with retries.
///
/// **BAD:**
/// ```dart
/// Future<User> fetchUser(String id) async {
///   final response = await http.get(Uri.parse('$baseUrl/users/$id'));
///   return User.fromJson(jsonDecode(response.body));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<User> fetchUser(String id) async {
///   return retry(
///     () async {
///       final response = await http.get(Uri.parse('$baseUrl/users/$id'));
///       return User.fromJson(jsonDecode(response.body));
///     },
///     retryIf: (e) => e is SocketException || e is TimeoutException,
///   );
/// }
/// ```
class RequireRetryLogicRule extends DartLintRule {
  const RequireRetryLogicRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_retry_logic',
    problemMessage:
        'Network call should have retry logic for transient failures.',
    correctionMessage: 'Use a retry mechanism for network operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check if this is an API/fetch method
      final String methodName = node.name.lexeme.toLowerCase();
      if (!methodName.startsWith('fetch') &&
          !methodName.startsWith('get') &&
          !methodName.startsWith('load') &&
          !methodName.startsWith('request')) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP calls
      if (!bodySource.contains('http.') &&
          !bodySource.contains('dio.') &&
          !bodySource.contains('.get(') &&
          !bodySource.contains('.post(')) {
        return;
      }

      // Check for retry logic
      if (!bodySource.contains('retry') &&
          !bodySource.contains('Retry') &&
          !bodySource.contains('attempts') &&
          !bodySource.contains('maxRetries')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when API response is not properly typed.
///
/// API responses should be parsed into strongly-typed models.
///
/// **BAD:**
/// ```dart
/// final data = jsonDecode(response.body);
/// final name = data['user']['name']; // Dynamic access
/// ```
///
/// **GOOD:**
/// ```dart
/// final user = User.fromJson(jsonDecode(response.body));
/// final name = user.name; // Type-safe access
/// ```
class RequireTypedApiResponseRule extends DartLintRule {
  const RequireTypedApiResponseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_typed_api_response',
    problemMessage: 'API response should be parsed into a typed model.',
    correctionMessage: 'Create a model class and use fromJson/fromMap.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'jsonDecode' && methodName != 'decode') return;

      // Check if result is used with index access (dynamic)
      AstNode? parent = node.parent;

      // Skip if assigned to a fromJson call
      while (parent != null) {
        if (parent is MethodInvocation) {
          final String parentMethod = parent.methodName.name;
          if (parentMethod.contains('fromJson') ||
              parentMethod.contains('fromMap') ||
              parentMethod.contains('parse')) {
            return; // Good - being parsed into model
          }
        }
        if (parent is VariableDeclaration) {
          // Check if later used with index access
          final String variableName = parent.name.lexeme;
          final AstNode? methodBody = _findMethodBody(parent);
          if (methodBody != null) {
            final String bodySource = methodBody.toSource();
            // Check for dynamic access like data['key']
            if (bodySource.contains("$variableName['") ||
                bodySource.contains('$variableName["')) {
              reporter.atNode(node, code);
            }
          }
          return;
        }
        parent = parent.parent;
      }
    });
  }

  AstNode? _findMethodBody(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.body;
      }
      if (current is FunctionDeclaration) {
        return current.functionExpression.body;
      }
      current = current.parent;
    }
    return null;
  }
}

/// Warns when connectivity is not checked before network operations.
///
/// Apps should check connectivity to provide better UX for offline users.
///
/// **BAD:**
/// ```dart
/// Future<void> syncData() async {
///   final response = await http.post(url, body: data);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> syncData() async {
///   final connectivity = await Connectivity().checkConnectivity();
///   if (connectivity == ConnectivityResult.none) {
///     throw NoInternetException();
///   }
///   final response = await http.post(url, body: data);
/// }
/// ```
class RequireConnectivityCheckRule extends DartLintRule {
  const RequireConnectivityCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_connectivity_check',
    problemMessage: 'Consider checking connectivity before network operations.',
    correctionMessage: 'Use Connectivity package to check network status.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check methods that do network operations
      final String methodName = node.name.lexeme.toLowerCase();
      if (!methodName.contains('sync') &&
          !methodName.contains('upload') &&
          !methodName.contains('download') &&
          !methodName.contains('fetch') &&
          !methodName.contains('submit')) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP calls
      if (!bodySource.contains('http.') &&
          !bodySource.contains('dio.') &&
          !bodySource.contains('.post(') &&
          !bodySource.contains('.get(')) {
        return;
      }

      // Check for connectivity check
      if (!bodySource.contains('connectivity') &&
          !bodySource.contains('Connectivity') &&
          !bodySource.contains('isConnected') &&
          !bodySource.contains('hasConnection')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when API errors are not mapped to domain errors.
///
/// Network errors should be translated to meaningful domain exceptions.
///
/// **BAD:**
/// ```dart
/// try {
///   await fetchUser(id);
/// } catch (e) {
///   print('Error: $e'); // Generic handling
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await fetchUser(id);
/// } on SocketException {
///   throw NetworkException('No internet connection');
/// } on HttpException catch (e) {
///   throw ApiException.fromStatusCode(e.statusCode);
/// }
/// ```
class RequireApiErrorMappingRule extends DartLintRule {
  const RequireApiErrorMappingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_api_error_mapping',
    problemMessage: 'API errors should be mapped to domain exceptions.',
    correctionMessage: 'Catch specific exceptions and map to domain errors.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      final String trySource = node.body.toSource();

      // Check if try block contains API calls
      if (!trySource.contains('http.') &&
          !trySource.contains('dio.') &&
          !trySource.contains('.get(') &&
          !trySource.contains('.post(') &&
          !trySource.contains('fetch')) {
        return;
      }

      // Check if there are specific catch clauses
      bool hasSpecificCatch = false;
      for (final CatchClause catchClause in node.catchClauses) {
        final TypeAnnotation? exceptionType = catchClause.exceptionType;
        if (exceptionType != null) {
          final String typeName = exceptionType.toSource();
          if (typeName != 'Exception' && typeName != 'Object') {
            hasSpecificCatch = true;
            break;
          }
        }
      }

      if (!hasSpecificCatch) {
        reporter.atNode(node, code);
      }
    });
  }
}
