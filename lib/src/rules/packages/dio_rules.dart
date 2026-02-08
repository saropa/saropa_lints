// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Dio HTTP client-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of the Dio HTTP client package,
/// including timeout configuration, error handling, interceptors,
/// SSL pinning, and best practices.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// DIO HTTP CLIENT RULES
// =============================================================================

/// Warns when Dio is used without timeout configuration.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Network requests without timeouts can hang indefinitely, causing poor UX.
/// Always configure connectTimeout and receiveTimeout.
///
/// **BAD:**
/// ```dart
/// final dio = Dio();
/// await dio.get('https://api.example.com/data');
/// ```
///
/// **GOOD:**
/// ```dart
/// final dio = Dio(BaseOptions(
///   connectTimeout: Duration(seconds: 10),
///   receiveTimeout: Duration(seconds: 30),
/// ));
/// ```
class RequireDioTimeoutRule extends SaropaLintRule {
  const RequireDioTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_timeout',
    problemMessage:
        '[require_dio_timeout] Creating a Dio instance for network requests without setting connectTimeout and receiveTimeout in BaseOptions can cause HTTP requests to hang indefinitely if the server is slow or unresponsive. This can freeze the UI, degrade user experience, and make error recovery impossible, especially in mobile apps with unreliable networks. Always configure timeouts to ensure your app remains responsive and can handle network failures gracefully. See https://pub.dev/packages/dio#timeouts. {v3}',
    correctionMessage:
        'Set connectTimeout and receiveTimeout in Dio BaseOptions to ensure all HTTP requests fail fast and can be retried or handled appropriately. This prevents the UI from hanging and improves reliability. See https://pub.dev/packages/dio#timeouts.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      if (typeName != 'Dio') return;

      // Check if BaseOptions argument has timeout
      final NodeList<Expression> args = node.argumentList.arguments;

      if (args.isEmpty) {
        // No options at all
        reporter.atNode(node, code);
        return;
      }

      // Check for timeout in BaseOptions
      bool hasConnectTimeout = false;
      bool hasReceiveTimeout = false;

      for (final arg in args) {
        final String argSource = arg.toSource();
        if (argSource.contains('connectTimeout')) hasConnectTimeout = true;
        if (argSource.contains('receiveTimeout')) hasReceiveTimeout = true;
      }

      if (!hasConnectTimeout || !hasReceiveTimeout) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Dio requests are made without error handling.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Dio throws DioException on network errors. Unhandled exceptions crash the app.
///
/// **BAD:**
/// ```dart
/// final response = await dio.get('/users');
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final response = await dio.get('/users');
/// } on DioException catch (e) {
///   handleNetworkError(e);
/// }
/// ```
class RequireDioErrorHandlingRule extends SaropaLintRule {
  const RequireDioErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_error_handling',
    problemMessage:
        '[require_dio_error_handling] Making a Dio HTTP request without wrapping it in a try-catch block means any DioException (such as network errors, timeouts, or invalid responses) will crash the app and leave users with no feedback. This is especially problematic in production apps where network conditions are unpredictable. Always handle Dio errors to provide a robust and user-friendly experience. See https://pub.dev/packages/dio#handling-errors. {v3}',
    correctionMessage:
        'Wrap all Dio requests in try-catch blocks and handle DioException to show user-friendly error messages, retry logic, or fallback behavior. This prevents crashes and improves reliability. See https://pub.dev/packages/dio#handling-errors.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _dioMethods = <String>{
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'download',
    'fetch',
    'request',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_dioMethods.contains(methodName)) return;

      // Check if target is Dio
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dio')) return;

      // Check if inside try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return;
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when Dio InterceptorsWrapper doesn't have onError handler.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Interceptors without error handling let errors propagate unexpectedly.
///
/// **BAD:**
/// ```dart
/// dio.interceptors.add(InterceptorsWrapper(
///   onRequest: (options, handler) => handler.next(options),
/// ));
/// ```
///
/// **GOOD:**
/// ```dart
/// dio.interceptors.add(InterceptorsWrapper(
///   onRequest: (options, handler) => handler.next(options),
///   onError: (error, handler) => handler.next(error),
/// ));
/// ```
class RequireDioInterceptorErrorHandlerRule extends SaropaLintRule {
  const RequireDioInterceptorErrorHandlerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_interceptor_error_handler',
    problemMessage:
        '[require_dio_interceptor_error_handler] InterceptorsWrapper without onError handler. Errors may be unhandled. Interceptors without error handling let errors propagate unexpectedly. This pattern increases maintenance cost and the likelihood of introducing bugs during future changes. {v3}',
    correctionMessage:
        'Add onError callback to handle request errors in interceptor. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      if (typeName != 'InterceptorsWrapper') return;

      // Check for onError parameter
      bool hasOnError = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onError') {
          hasOnError = true;
          break;
        }
      }

      if (!hasOnError) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when long-running Dio requests don't use CancelToken.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Requests should be cancellable to avoid wasting resources when the user
/// navigates away.
///
/// **BAD:**
/// ```dart
/// await dio.download(url, path); // Can't be cancelled!
/// ```
///
/// **GOOD:**
/// ```dart
/// final cancelToken = CancelToken();
/// await dio.download(url, path, cancelToken: cancelToken);
/// // On dispose: cancelToken.cancel();
/// ```
class PreferDioCancelTokenRule extends SaropaLintRule {
  const PreferDioCancelTokenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_dio_cancel_token',
    problemMessage:
        '[prefer_dio_cancel_token] Long-running Dio request without CancelToken. Cannot be cancelled. Requests must be cancellable to avoid wasting resources when the user navigates away. {v3}',
    correctionMessage:
        'Add cancelToken parameter for cancellable requests. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _longRunningMethods = <String>{'download', 'fetch'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_longRunningMethods.contains(methodName)) return;

      // Check if target is Dio
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dio')) return;

      // Check for cancelToken parameter
      bool hasCancelToken = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'cancelToken') {
          hasCancelToken = true;
          break;
        }
      }

      if (!hasCancelToken) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Dio is used for auth endpoints without SSL pinning.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Sensitive endpoints should use certificate pinning to prevent MITM attacks.
///
/// **BAD:**
/// ```dart
/// dio.post('/login', data: credentials);
/// ```
///
/// **GOOD:**
/// ```dart
/// dio.httpClientAdapter = IOHttpClientAdapter(
///   createHttpClient: () {
///     final client = HttpClient(context: SecurityContext());
///     client.badCertificateCallback = (cert, host, port) =>
///         validateCertificate(cert);
///     return client;
///   },
/// );
/// ```
class RequireDioSslPinningRule extends SaropaLintRule {
  const RequireDioSslPinningRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_ssl_pinning',
    problemMessage:
        '[require_dio_ssl_pinning] Making authentication or sensitive API requests with Dio without SSL pinning exposes your app to man-in-the-middle (MITM) attacks, where attackers can intercept or modify network traffic. This is a critical security risk for login, registration, and token endpoints. Always configure SSL pinning for all sensitive endpoints to protect user credentials and data. See https://pub.dev/packages/dio#ssl-pinning. {v3}',
    correctionMessage:
        'Set up SSL pinning in Dio by configuring httpClientAdapter with certificate validation for all authentication and sensitive endpoints. This prevents MITM attacks and protects user data. See https://pub.dev/packages/dio#ssl-pinning.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _authEndpoints = <String>{
    'login',
    'auth',
    'signin',
    'sign-in',
    'signup',
    'sign-up',
    'register',
    'token',
    'oauth',
    'password',
    'credentials',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'post' && methodName != 'get') return;

      // Check if target is Dio
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dio')) return;

      // Check URL argument for auth endpoints
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String urlSource = args.first.toSource().toLowerCase();

      for (final endpoint in _authEndpoints) {
        if (urlSource.contains(endpoint)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when FormData with files is not properly cleaned up.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// FormData with file streams should be cleaned up to avoid resource leaks.
///
/// **BAD:**
/// ```dart
/// final formData = FormData.fromMap({
///   'file': await MultipartFile.fromFile(path),
/// });
/// await dio.post('/upload', data: formData);
/// // FormData never cleaned up
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use in try-finally or with proper disposal
/// ```
class AvoidDioFormDataLeakRule extends SaropaLintRule {
  const AvoidDioFormDataLeakRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_dio_form_data_leak',
    problemMessage:
        '[avoid_dio_form_data_leak] FormData with file. Ensure proper cleanup of file resources. FormData with file streams must be cleaned up to avoid resource leaks. FormData with files is not properly cleaned up. {v3}',
    correctionMessage:
        'Prefer cleanup or using try-finally for file uploads. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for MultipartFile.fromFile
      if (methodName != 'fromFile') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      if (target.name == 'MultipartFile') {
        // Check if inside try-finally
        AstNode? current = node.parent;
        bool insideTryFinally = false;

        while (current != null) {
          if (current is TryStatement && current.finallyBlock != null) {
            insideTryFinally = true;
            break;
          }
          current = current.parent;
        }

        if (!insideTryFinally) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Dio debug logging is enabled without kDebugMode check.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: dio_debug_logging_prod, dio_debug_interceptor
///
/// Debug logging in production exposes sensitive data and hurts performance.
///
/// **BAD:**
/// ```dart
/// dio.interceptors.add(LogInterceptor());  // Logs in prod!
/// ```
///
/// **GOOD:**
/// ```dart
/// if (kDebugMode) {
///   dio.interceptors.add(LogInterceptor());
/// }
/// ```
class AvoidDioDebugPrintProductionRule extends SaropaLintRule {
  const AvoidDioDebugPrintProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_dio_debug_print_production',
    problemMessage:
        '[avoid_dio_debug_print_production] Using Dio LogInterceptor in production exposes sensitive request and response data\u2014including authentication tokens, user information, and API payloads\u2014to device logs. This can lead to data leaks, privacy violations, and compliance issues, especially on shared or rooted devices. Always restrict debug logging to development builds only. {v3}',
    correctionMessage:
        'Wrap LogInterceptor usage in an if (kDebugMode) block to ensure it is only active in development. Never log sensitive data in production. Review your build configuration and audit for accidental log exposure.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'add') return;

      // Only apply to files that import Dio
      if (!fileImportsPackage(node, PackageImports.dio)) return;

      // Check if adding LogInterceptor - use type check, not string contains
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;
      // Check for LogInterceptor constructor or type
      if (firstArg is! InstanceCreationExpression) return;
      final typeName = firstArg.constructorName.type.element?.name;
      if (typeName != 'LogInterceptor') return;

      // Check if target is interceptors property
      final target = node.target;
      if (target == null) return;
      // Use property access check instead of string contains
      if (target is! PropertyAccess ||
          target.propertyName.name != 'interceptors') {
        if (target is! SimpleIdentifier ||
            !target.name.endsWith('interceptors')) {
          return;
        }
      }

      // Check for kDebugMode guard
      AstNode? current = node.parent;
      bool hasDebugGuard = false;

      while (current != null) {
        if (current is IfStatement) {
          final condition = current.expression.toSource();
          if (condition.contains('kDebugMode')) {
            hasDebugGuard = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasDebugGuard) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when multiple Dio instances are created instead of using singleton.
///
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: dio_multiple_instances, dio_no_singleton
///
/// Creating multiple Dio instances wastes resources and makes interceptor
/// configuration inconsistent.
///
/// **BAD:**
/// ```dart
/// class ApiService {
///   Future<Response> get() => Dio().get('/endpoint');
/// }
/// class OtherService {
///   Future<Response> get() => Dio().get('/other');  // Another instance!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class DioClient {
///   static final Dio instance = Dio()..interceptors.add(...);
/// }
/// ```
class RequireDioSingletonRule extends SaropaLintRule {
  const RequireDioSingletonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_singleton',
    problemMessage:
        '[require_dio_singleton] Use a singleton Dio instance. Creating multiple Dio instances wastes resources and makes interceptor configuration inconsistent. {v2}',
    correctionMessage:
        'Create a shared Dio instance with consistent configuration. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Dio') return;

      // Check if it's being assigned to a static final field
      AstNode? current = node.parent;
      while (current != null) {
        if (current is VariableDeclaration) {
          final parent = current.parent;
          if (parent is VariableDeclarationList) {
            final grandParent = parent.parent;
            if (grandParent is FieldDeclaration &&
                grandParent.isStatic &&
                parent.isFinal) {
              return; // Singleton pattern - OK
            }
          }
        }
        if (current is MethodInvocation ||
            current is ExpressionStatement ||
            current is ReturnStatement) {
          // Inline Dio() usage
          reporter.atNode(node.constructorName, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when request options are repeated instead of using BaseOptions.
///
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: dio_repeated_options, dio_use_base_options
///
/// Repeated headers/timeouts across requests should be in BaseOptions.
///
/// **BAD:**
/// ```dart
/// dio.get('/a', options: Options(headers: {'Auth': token}));
/// dio.get('/b', options: Options(headers: {'Auth': token}));
/// ```
///
/// **GOOD:**
/// ```dart
/// final dio = Dio(BaseOptions(headers: {'Auth': token}));
/// dio.get('/a');
/// dio.get('/b');
/// ```
class PreferDioBaseOptionsRule extends SaropaLintRule {
  const PreferDioBaseOptionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_dio_base_options',
    problemMessage:
        '[prefer_dio_base_options] Repeated options in Dio requests. Use BaseOptions. Repeated headers/timeouts across requests must be in BaseOptions. {v2}',
    correctionMessage:
        'Move common headers/timeouts to BaseOptions in Dio constructor. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track options usage in file
    final List<MethodInvocation> dioRequestsWithOptions = [];

    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (!['get', 'post', 'put', 'patch', 'delete'].contains(methodName)) {
        return;
      }

      final target = node.target;
      if (target == null) return;

      final targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dio')) return;

      // Check for options parameter
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'options') {
          dioRequestsWithOptions.add(node);
          break;
        }
      }

      // If we've seen multiple requests with options, report
      if (dioRequestsWithOptions.length >= 3) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Dio is used without baseUrl.
///
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: dio_missing_base_url, dio_full_urls
///
/// Using full URLs in each request is error-prone. Set baseUrl once.
///
/// **BAD:**
/// ```dart
/// dio.get('https://api.example.com/users');
/// dio.get('https://api.example.com/posts');  // Repeated base!
/// ```
///
/// **GOOD:**
/// ```dart
/// final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
/// dio.get('/users');
/// dio.get('/posts');
/// ```
class AvoidDioWithoutBaseUrlRule extends SaropaLintRule {
  const AvoidDioWithoutBaseUrlRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_dio_without_base_url',
    problemMessage:
        '[avoid_dio_without_base_url] Dio request with full URL. Prefer setting baseUrl. Using full URLs in each request is error-prone. Set baseUrl once. {v2}',
    correctionMessage:
        'Set baseUrl in BaseOptions and use relative paths in requests. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (!['get', 'post', 'put', 'patch', 'delete'].contains(methodName)) {
        return;
      }

      final target = node.target;
      if (target == null) return;

      final targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dio')) return;

      // Check first argument for full URL
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;
      if (firstArg is SimpleStringLiteral) {
        final url = firstArg.value;
        if (url.startsWith('http://') || url.startsWith('https://')) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }
}

/// Warns when using the http package instead of Dio.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: use_dio, prefer_dio, http_to_dio
///
/// Dio provides better features than the http package: interceptors,
/// request cancellation, FormData, better error handling.
///
/// **BAD:**
/// ```dart
/// import 'package:http/http.dart' as http;
/// final response = await http.get(Uri.parse(url));
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:dio/dio.dart';
/// final dio = Dio();
/// final response = await dio.get(url);
/// ```
class PreferDioOverHttpRule extends SaropaLintRule {
  const PreferDioOverHttpRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_dio_over_http',
    problemMessage:
        '[prefer_dio_over_http] Using http package. Dio provides interceptors, cancellation, and structured error handling suited for production apps. {v2}',
    correctionMessage:
        'Use Dio for interceptors, cancellation, and error handling. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == 'package:http/http.dart') {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// require_dio_response_type
// =============================================================================

/// Explicitly set responseType when processing binary data.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Dio defaults responseType to JSON, which causes issues when downloading
/// files or handling binary responses.
///
/// **BAD:**
/// ```dart
/// final response = await dio.get(url);  // Defaults to JSON
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await dio.get(
///   url,
///   options: Options(responseType: ResponseType.bytes),
/// );
/// ```
class RequireDioResponseTypeRule extends SaropaLintRule {
  const RequireDioResponseTypeRule() : super(code: _code);

  /// Binary data corruption if wrong response type used.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_response_type',
    problemMessage:
        '[require_dio_response_type] Dio download without explicit responseType may corrupt binary data. Dio defaults responseType to JSON, which causes issues when downloading files or handling binary responses. {v2}',
    correctionMessage:
        'Add options: Options(responseType: ResponseType.bytes) for downloads. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      // Only check download-related methods
      if (methodName != 'download' && methodName != 'downloadUri') return;

      // Check if target is Dio instance
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('dio') && !targetSource.contains('Dio')) {
        return;
      }

      // Check for Options with responseType
      final ArgumentList args = node.argumentList;
      bool hasResponseType = false;

      for (final Expression arg in args.arguments) {
        final String argSource = arg.toSource();
        if (argSource.contains('responseType') ||
            argSource.contains('ResponseType')) {
          hasResponseType = true;
          break;
        }
      }

      if (!hasResponseType) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// require_dio_retry_interceptor
// =============================================================================

/// Network requests should have retry logic for resilience.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Network failures are common on mobile. Without retry logic, transient
/// failures cause unnecessary errors.
///
/// **BAD:**
/// ```dart
/// final dio = Dio();
/// ```
///
/// **GOOD:**
/// ```dart
/// final dio = Dio()
///   ..interceptors.add(RetryInterceptor(
///     dio: dio,
///     retries: 3,
///   ));
/// ```
class RequireDioRetryInterceptorRule extends SaropaLintRule {
  const RequireDioRetryInterceptorRule() : super(code: _code);

  /// User experience degradation from transient failures.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dio_retry_interceptor',
    problemMessage:
        '[require_dio_retry_interceptor] Dio instance without retry interceptor. Network failures are common on mobile. Without retry logic, transient failures cause unnecessary errors. {v2}',
    correctionMessage:
        'Add RetryInterceptor for network resilience. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Dio') return;

      // Look for cascade with interceptors.add
      final AstNode? parent = node.parent;
      if (parent is CascadeExpression) {
        final String cascadeSource = parent.toSource();
        if (cascadeSource.contains('RetryInterceptor') ||
            cascadeSource.contains('retry') ||
            cascadeSource.contains('Retry')) {
          return;
        }
      }

      // Check if part of an assignment where interceptors are added later
      // This is a simple heuristic - just flag bare Dio() calls
      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// prefer_dio_transformer
// =============================================================================

/// Large JSON parsing should use custom transformer with isolates.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Parsing large JSON responses on the main thread causes jank.
/// Use BackgroundTransformer or compute() for heavy parsing.
///
/// **BAD:**
/// ```dart
/// final response = await dio.get('/large-data');
/// final data = response.data;  // Parsing on main thread
/// ```
///
/// **GOOD:**
/// ```dart
/// dio.transformer = BackgroundTransformer();
/// ```
class PreferDioTransformerRule extends SaropaLintRule {
  const PreferDioTransformerRule() : super(code: _code);

  /// UI jank from main thread JSON parsing.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_dio_transformer',
    problemMessage:
        '[prefer_dio_transformer] Dio instance without custom transformer for large data. Parsing large JSON responses on the main thread causes jank. Use BackgroundTransformer or compute() for heavy parsing. {v2}',
    correctionMessage:
        'Set dio.transformer = BackgroundTransformer() for off-main-thread parsing. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Dio') return;

      // Look for transformer assignment in cascade
      final AstNode? parent = node.parent;
      if (parent is CascadeExpression) {
        final String cascadeSource = parent.toSource();
        if (cascadeSource.contains('transformer') ||
            cascadeSource.contains('BackgroundTransformer') ||
            cascadeSource.contains('Transformer')) {
          return;
        }
      }

      // Simple heuristic - flag Dio() without transformer configuration
      reporter.atNode(node, code);
    });
  }
}
