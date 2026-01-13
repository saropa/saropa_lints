// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// API and network lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper API usage patterns, network error
/// handling, and resilient communication with backend services.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../import_utils.dart';
import '../saropa_lint_rule.dart';

// =============================================================================
// HTTP Rules
// =============================================================================

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
class RequireHttpStatusCheckRule extends SaropaLintRule {
  const RequireHttpStatusCheckRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_http_status_check',
    problemMessage:
        '[require_http_status_check] HTTP response body is used without first checking the status code. This can result in undetected failures, silent data corruption, or security issues if error responses are parsed as valid data. Always check if (response.statusCode == 200) before parsing response.body to ensure only successful responses are processed and errors are handled appropriately.',
    correctionMessage:
        'Check if (response.statusCode == 200) before parsing response.body.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidHardcodedApiUrlsRule extends SaropaLintRule {
  const AvoidHardcodedApiUrlsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_api_urls',
    problemMessage:
        '[avoid_hardcoded_api_urls] Hardcoded API URLs prevent switching between development, staging, and production environments, making code inflexible and error-prone. This practice also risks leaking sensitive endpoints and complicates maintenance. Always extract API URLs to configuration constants (e.g., ApiConfig.baseUrl) to enable environment switching and improve security.',
    correctionMessage:
        "Extract to a config constant: Uri.parse('\${ApiConfig.baseUrl}/endpoint').",
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _apiUrlPattern = RegExp(
    r'https?://[a-zA-Z0-9.-]+\.(com|io|net|org|dev|app)/api',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireRetryLogicRule extends SaropaLintRule {
  const RequireRetryLogicRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_retry_logic',
    problemMessage:
        '[require_retry_logic] Network call does not implement retry logic, so transient failures (e.g., temporary network loss, server hiccups) will not recover automatically. This can lead to poor reliability and frustrated users. Always wrap network calls with retry() or implement exponential backoff for SocketException/TimeoutException to improve robustness.',
    correctionMessage:
        'Wrap with retry() or implement exponential backoff for SocketException/TimeoutException.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireTypedApiResponseRule extends SaropaLintRule {
  const RequireTypedApiResponseRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_typed_api_response',
    problemMessage:
        '[require_typed_api_response] Untyped API access via dynamic keys '
        'loses type safety. Typos cause runtime errors, not compile errors.',
    correctionMessage: 'Create a model class and use fromJson/fromMap.',
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
class RequireConnectivityCheckRule extends SaropaLintRule {
  const RequireConnectivityCheckRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_connectivity_check',
    problemMessage:
        '[require_connectivity_check] Network calls without connectivity check '
        'cause poor UX with long timeouts and unhelpful error messages.',
    correctionMessage: 'Use Connectivity package to check network status.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireApiErrorMappingRule extends SaropaLintRule {
  const RequireApiErrorMappingRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_api_error_mapping',
    problemMessage:
        '[require_api_error_mapping] Raw API exceptions are exposed to users, leaking implementation details and providing unhelpful error messages. This can confuse users and expose sensitive information. Always catch specific exceptions and map them to domain errors with clear, actionable messages for better user experience and security.',
    correctionMessage: 'Catch specific exceptions and map to domain errors.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

/// Warns when HTTP requests don't specify a timeout.
///
/// Alias: require_api_timeout
///
/// Network requests without timeouts can hang indefinitely, leading to poor
/// user experience. Always specify a reasonable timeout for HTTP calls.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse('https://api.example.com/data'));
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(
///   Uri.parse('https://api.example.com/data'),
/// ).timeout(Duration(seconds: 30));
/// ```
///
/// **Also GOOD (Dio with timeout):**
/// ```dart
/// final dio = Dio(BaseOptions(
///   connectTimeout: Duration(seconds: 5),
///   receiveTimeout: Duration(seconds: 30),
/// ));
/// final response = await dio.get('https://api.example.com/data');
/// ```
class RequireRequestTimeoutRule extends SaropaLintRule {
  const RequireRequestTimeoutRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_request_timeout',
    problemMessage:
        '[require_request_timeout] HTTP request is missing a timeout configuration, which means it may hang indefinitely if the server does not respond. This can cause the app to freeze, degrade user experience, and waste resources. Always add .timeout(Duration(seconds: 30)) or configure timeout in client options to ensure requests fail gracefully and users are informed of network issues.',
    correctionMessage:
        'Add .timeout(Duration(seconds: 30)) or configure timeout in client options.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _httpMethods = <String>{
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'read',
    'readBytes',
    'readString',
    'send',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check HTTP methods
      if (!_httpMethods.contains(methodName)) return;

      // Check if target looks like an HTTP client
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();

      // cspell:ignore httpclient
      // Check if this is an HTTP-related call
      // Be specific to avoid false positives (e.g., apiResponse.get() is not HTTP)
      // Look for actual HTTP client patterns, not just 'api' which matches too broadly
      final bool isHttpCall = targetSource.contains('http') ||
          targetSource == 'dio' ||
          targetSource.endsWith('.dio') ||
          targetSource.contains('httpclient') ||
          targetSource.contains('http.client') ||
          // Client without 'api' prefix to avoid matching apiClient, apiResponse, etc.
          (targetSource == 'client' || targetSource.endsWith('.client'));

      if (!isHttpCall) return;

      // Check if .timeout() is chained on this call
      final AstNode? parent = node.parent;
      if (parent is MethodInvocation) {
        final String parentMethod = parent.methodName.name;
        if (parentMethod == 'timeout') return; // Has timeout
      }

      // Check if in await expression with timeout
      if (parent is AwaitExpression) {
        final AstNode? awaitParent = parent.parent;
        if (awaitParent is MethodInvocation &&
            awaitParent.methodName.name == 'timeout') {
          return; // await http.get(...).timeout(...)
        }
      }

      // Check if timeout is configured in the surrounding context
      // (e.g., Dio with connectTimeout in options)
      AstNode? current = node.parent;
      int depth = 0;
      while (current != null && depth < 10) {
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          final String bodySource = current.toSource();
          if (bodySource.contains('connectTimeout') ||
              bodySource.contains('receiveTimeout') ||
              bodySource.contains('sendTimeout') ||
              bodySource.contains('BaseOptions')) {
            return; // Timeout likely configured at client level
          }
          break;
        }
        current = current.parent;
        depth++;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when connectivity monitoring is used without an offline indicator.
///
/// Users should know when they're offline. Using connectivity monitoring
/// without providing visual feedback creates a confusing experience where
/// actions fail silently.
///
/// **BAD:**
/// ```dart
/// class MyApp extends StatefulWidget {
///   void initState() {
///     Connectivity().onConnectivityChanged.listen((result) {
///       _isOnline = result != ConnectivityResult.none;
///       // No UI feedback!
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyApp extends StatefulWidget {
///   void initState() {
///     Connectivity().onConnectivityChanged.listen((result) {
///       _isOnline = result != ConnectivityResult.none;
///       if (!_isOnline) {
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('You are offline')),
///         );
///       }
///     });
///   }
/// }
/// ```
class RequireOfflineIndicatorRule extends SaropaLintRule {
  const RequireOfflineIndicatorRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_offline_indicator',
    problemMessage:
        '[require_offline_indicator] Connectivity is checked, but there is no offline indicator shown to users. Without a clear indicator, users may not understand why features are unavailable or why requests fail. Always show a banner, snackbar, or icon when connectivity is lost to improve transparency and user experience.',
    correctionMessage:
        'Show a banner, snackbar, or icon when connectivity is lost.',
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

      // Check for connectivity stream listening
      if (methodName != 'listen') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('onConnectivityChanged') &&
          !targetSource.contains('connectivityStream')) {
        return;
      }

      // Check if the callback contains UI feedback
      if (node.argumentList.arguments.isEmpty) return;

      final Expression callback = node.argumentList.arguments.first;
      final String callbackSource = callback.toSource();

      // Look for common UI feedback patterns
      final bool hasUiFeedback = callbackSource.contains('showSnackBar') ||
          callbackSource.contains('showDialog') ||
          callbackSource.contains('Banner') ||
          callbackSource.contains('Overlay') ||
          callbackSource.contains('showToast') ||
          callbackSource.contains('showNotification') ||
          callbackSource.contains('offlineWidget') ||
          callbackSource.contains('OfflineBuilder') ||
          callbackSource.contains('NoInternetWidget');

      if (!hasUiFeedback) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when large file downloads don't use streaming.
///
/// Large downloads should stream to disk instead of buffering in memory.
/// Loading large files entirely into memory can cause out-of-memory crashes.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse(largeFileUrl));
/// final bytes = response.bodyBytes; // Entire file in memory!
/// await file.writeAsBytes(bytes);
/// ```
///
/// **GOOD:**
/// ```dart
/// final request = http.Request('GET', Uri.parse(largeFileUrl));
/// final response = await client.send(request);
/// final file = File(path);
/// await response.stream.pipe(file.openWrite()); // Streams to disk
/// ```
class PreferStreamingResponseRule extends SaropaLintRule {
  const PreferStreamingResponseRule() : super(code: _code);

  /// Large file downloads without streaming can cause OOM crashes.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_streaming_response',
    problemMessage:
        '[prefer_streaming_response] bodyBytes loads entire file into memory, '
        'causing OutOfMemoryError for large downloads. Stream to disk instead.',
    correctionMessage:
        'Use client.send() with StreamedResponse and pipe to file.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;

      // Check for bodyBytes access which loads entire response into memory
      if (propertyName != 'bodyBytes' && propertyName != 'body') {
        return;
      }

      // Check if target looks like an HTTP response
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('response') &&
          !targetSource.contains('http') &&
          !targetSource.contains('dio')) {
        return;
      }

      // Check if this is likely a large file context
      // Look for file-related operations nearby
      AstNode? current = node.parent;
      int depth = 0;
      bool isFileContext = false;

      while (current != null && depth < 10) {
        final String source = current.toSource();
        if (source.contains('writeAsBytes') ||
            source.contains('writeAsBytesSync') ||
            source.contains('.pdf') ||
            source.contains('.zip') ||
            source.contains('.mp4') ||
            source.contains('.mp3') ||
            source.contains('.png') ||
            source.contains('.jpg') ||
            source.contains('.jpeg') ||
            source.contains('download') ||
            source.contains('Download') ||
            source.contains('file')) {
          isFileContext = true;
          break;
        }
        current = current.parent;
        depth++;
      }

      if (isFileContext) {
        reporter.atNode(node, code);
      }
    });

    // Also check for dio's response.data in file context
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for dio download without streaming
      if (methodName != 'get' && methodName != 'download') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dio') && !targetSource.contains('http')) {
        return;
      }

      // Check for responseType configuration
      final String nodeSource = node.toSource();
      if (nodeSource.contains('ResponseType.stream') ||
          nodeSource.contains('responseType: ResponseType.bytes')) {
        return; // Already using streaming or explicit bytes
      }

      // Check if downloading to file
      if (nodeSource.contains('.pdf') ||
          nodeSource.contains('.zip') ||
          nodeSource.contains('.mp4') ||
          nodeSource.contains('download')) {
        // Check parent context for file operations
        AstNode? current = node.parent;
        int depth = 0;

        while (current != null && depth < 5) {
          final String source = current.toSource();
          if (source.contains('writeAsBytes') ||
              source.contains('File(') ||
              source.contains('savePath')) {
            // If not using streaming response type, warn
            if (!nodeSource.contains('ResponseType.stream')) {
              reporter.atNode(node.methodName, code);
            }
            break;
          }
          current = current.parent;
          depth++;
        }
      }
    });
  }
}

/// Warns when HTTP clients are created without connection reuse.
///
/// Each new HTTP client requires DNS lookup, TCP handshake, and TLS
/// negotiation. Reusing connections is much more efficient.
///
/// **BAD:**
/// ```dart
/// Future<Data> fetchData() async {
///   final client = http.Client(); // New client each call
///   final response = await client.get(url);
///   client.close();
///   return Data.fromJson(response.body);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class ApiService {
///   final http.Client _client = http.Client(); // Reused client
///
///   Future<Data> fetchData() async {
///     final response = await _client.get(url);
///     return Data.fromJson(response.body);
///   }
///
///   void dispose() => _client.close();
/// }
/// ```
class PreferHttpConnectionReuseRule extends SaropaLintRule {
  const PreferHttpConnectionReuseRule() : super(code: _code);

  /// Performance issue - connection overhead adds latency.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_http_connection_reuse',
    problemMessage:
        '[prefer_http_connection_reuse] HTTP client created inside method. Connection overhead on every call.',
    correctionMessage:
        'Create HTTP client as a class field and reuse across requests.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for client creation inside method
      if (!bodySource.contains('http.Client()') &&
          !bodySource.contains('Client()') &&
          !bodySource.contains('Dio()')) {
        return;
      }

      // Check if client is created as local variable (not returned)
      if (bodySource.contains('final client = ') ||
          bodySource.contains('var client = ') ||
          bodySource.contains('final dio = ') ||
          bodySource.contains('var dio = ')) {
        // Check if closed in same method (ephemeral pattern)
        if (bodySource.contains('.close()')) {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check for inline Client() usage that isn't assigned to local variable
    // (The MethodDeclaration check above handles local variable + close pattern)
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'Client' && typeName != 'Dio') return;

      // Check if this is assigned to a local variable (handled above)
      final AstNode? parent = node.parent;
      if (parent is VariableDeclaration) {
        // Already handled by the MethodDeclaration check
        return;
      }

      // Check if inside a method body (not a field declaration)
      AstNode? current = parent;
      while (current != null) {
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          // Inline usage inside method - should reuse
          reporter.atNode(node, code);
          return;
        }
        if (current is FieldDeclaration ||
            current is TopLevelVariableDeclaration) {
          // Field declaration - good pattern
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when the same API endpoint might be called redundantly.
///
/// Multiple widgets or methods requesting the same data simultaneously
/// wastes bandwidth and server resources. Deduplicate concurrent requests.
///
/// **BAD:**
/// ```dart
/// class UserWidget extends StatelessWidget {
///   Future<User> build() async {
///     return await api.getUser(userId); // Called in multiple widgets
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserRepository {
///   final Map<String, Future<User>> _pending = {};
///
///   Future<User> getUser(String id) {
///     return _pending.putIfAbsent(id, () async {
///       final user = await api.getUser(id);
///       _pending.remove(id);
///       return user;
///     });
///   }
/// }
/// ```
class AvoidRedundantRequestsRule extends SaropaLintRule {
  const AvoidRedundantRequestsRule() : super(code: _code);

  /// Performance and resource waste.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_requests',
    problemMessage:
        '[avoid_redundant_requests] API call in build() or similar may cause redundant requests.',
    correctionMessage: 'Cache results or use request deduplication pattern.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;

      // Check methods that run frequently
      if (methodName != 'build' &&
          methodName != 'initState' &&
          methodName != 'didChangeDependencies' &&
          methodName != 'didUpdateWidget') {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP API calls without caching
      // Note: Avoid matching generic .get() which could be Map.get() or Box.get()
      final bool hasApiCall = bodySource.contains('http.get(') ||
          bodySource.contains('client.get(') ||
          bodySource.contains('dio.get(') ||
          bodySource.contains('.post(') ||
          bodySource.contains('.fetch(') ||
          bodySource.contains('http.') ||
          bodySource.contains('dio.');

      if (!hasApiCall) return;

      // Check for caching patterns
      final bool hasCaching = bodySource.contains('cache') ||
          bodySource.contains('Cache') ||
          bodySource.contains('_pending') ||
          bodySource.contains('putIfAbsent') ||
          bodySource.contains('memoize');

      if (!hasCaching) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when GET responses are not cached.
///
/// GET responses for static or slowly-changing data should be cached
/// to reduce bandwidth usage and improve responsiveness.
///
/// **BAD:**
/// ```dart
/// Future<Config> getConfig() async {
///   return await api.get('/config'); // Fetches every time
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Config? _cachedConfig;
/// DateTime? _cacheTime;
///
/// Future<Config> getConfig() async {
///   if (_cachedConfig != null &&
///       DateTime.now().difference(_cacheTime!) < Duration(minutes: 5)) {
///     return _cachedConfig!;
///   }
///   _cachedConfig = await api.get('/config');
///   _cacheTime = DateTime.now();
///   return _cachedConfig!;
/// }
/// ```
class RequireResponseCachingRule extends SaropaLintRule {
  const RequireResponseCachingRule() : super(code: _code);

  /// Caching depends on data freshness requirements - may not be appropriate.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_response_caching',
    problemMessage:
        '[require_response_caching] GET request without caching. Consider caching static data.',
    correctionMessage:
        'Add response caching with TTL for data that changes infrequently.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      // Check for getter methods that likely fetch data
      if (!methodName.startsWith('get') &&
          !methodName.startsWith('fetch') &&
          !methodName.startsWith('load') &&
          !methodName.contains('config') &&
          !methodName.contains('settings')) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for GET requests
      if (!bodySource.contains('.get(') && !bodySource.contains('http.get')) {
        return;
      }

      // Check for caching patterns
      final bool hasCaching = bodySource.contains('cache') ||
          bodySource.contains('Cache') ||
          bodySource.contains('_cached') ||
          bodySource.contains('cached') ||
          bodySource.contains('ttl') ||
          bodySource.contains('TTL') ||
          bodySource.contains('Duration');

      // Check class for cache fields
      final AstNode? parent = node.parent;
      if (parent is ClassDeclaration) {
        final String classSource = parent.toSource();
        if (classSource.contains('_cache') ||
            classSource.contains('Cache') ||
            classSource.contains('_cached')) {
          return; // Class has caching infrastructure
        }
      }

      if (!hasCaching) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when APIs return large collections without pagination.
///
/// Loading thousands of items at once is slow and memory-intensive.
/// Use pagination with limit/offset or cursor-based pagination.
///
/// **BAD:**
/// ```dart
/// Future<List<Item>> getAllItems() async {
///   final response = await api.get('/items');
///   return response.map((e) => Item.fromJson(e)).toList();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<List<Item>> getItems({int page = 0, int limit = 20}) async {
///   final response = await api.get('/items?page=$page&limit=$limit');
///   return response.map((e) => Item.fromJson(e)).toList();
/// }
/// ```
class PreferPaginationRule extends SaropaLintRule {
  const PreferPaginationRule() : super(code: _code);

  /// Performance and memory usage.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_pagination',
    problemMessage:
        '[prefer_pagination] API fetches all items without pagination. May cause memory issues.',
    correctionMessage:
        'Add pagination parameters: limit, offset, page, or cursor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      // Check for methods that fetch collections
      if (!methodName.contains('all') &&
          !methodName.startsWith('get') &&
          !methodName.startsWith('fetch') &&
          !methodName.startsWith('list') &&
          !methodName.startsWith('load')) {
        return;
      }

      // Check return type for List
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;
      final String returnTypeStr = returnType.toSource();
      if (!returnTypeStr.contains('List<') &&
          !returnTypeStr.contains('Iterable<')) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for API calls
      if (!bodySource.contains('.get(') &&
          !bodySource.contains('http.') &&
          !bodySource.contains('dio.')) {
        return;
      }

      // Check for pagination patterns
      final bool hasPagination = bodySource.contains('limit') ||
          bodySource.contains('offset') ||
          bodySource.contains('page') ||
          bodySource.contains('cursor') ||
          bodySource.contains('pageSize') ||
          bodySource.contains('perPage') ||
          node.parameters?.toSource().contains('limit') == true ||
          node.parameters?.toSource().contains('page') == true;

      if (!hasPagination) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when API responses fetch more data than needed.
///
/// Fetching entire objects when only a few fields are needed wastes
/// bandwidth. Use field selection or create dedicated endpoints.
///
/// **BAD:**
/// ```dart
/// // Fetches entire user object just to display name
/// final user = await api.getUser(id);
/// return Text(user.name);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Only fetch needed fields
/// final name = await api.getUserName(id);
/// // Or use GraphQL field selection
/// final user = await api.query('{ user(id: $id) { name } }');
/// ```
class AvoidOverFetchingRule extends SaropaLintRule {
  const AvoidOverFetchingRule() : super(code: _code);

  /// Optimization depends on API design - may require backend changes.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_over_fetching',
    problemMessage:
        '[avoid_over_fetching] Fetching full object but only using few fields. Consider optimizing.',
    correctionMessage:
        'Use field selection, sparse fieldsets, or dedicated endpoints.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This rule requires more sophisticated analysis
    // Detect patterns like: fetch full object, use 1-2 properties
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Look for API fetch followed by single property access
      final RegExp fetchPattern =
          RegExp(r'await\s+\w+\.(get|fetch|query)\([^)]+\)');

      if (!fetchPattern.hasMatch(bodySource)) return;

      // Count property accesses on result vs fields available
      // This is a heuristic - if method is short and only accesses
      // one or two properties after fetch, might be over-fetching
      final int propertyAccesses =
          RegExp(r'\.\w+(?!\()').allMatches(bodySource).length;
      final int apiCalls =
          RegExp(r'\.(get|fetch|post|query)\(').allMatches(bodySource).length;

      // If we have an API call and very few property accesses relative
      // to typical object size, might be over-fetching
      if (apiCalls > 0 && propertyAccesses <= 3 && bodySource.length < 500) {
        // Additional heuristic: check for .name, .id, .title only patterns
        if (bodySource.contains('.name') ||
            bodySource.contains('.title') ||
            bodySource.contains('.id')) {
          final int totalProps = RegExp(
            r'\.(name|title|id|label|text)\b',
          ).allMatches(bodySource).length;
          if (totalProps >= 1 && totalProps <= 2) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when async requests lack cancellation support.
///
/// Requests for disposed screens waste resources and can cause errors.
/// Use CancelToken or cancel HTTP requests when the widget is disposed.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   Future<void> loadData() async {
///     final data = await api.fetchData(); // No cancellation
///     setState(() => _data = data);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final CancelToken _cancelToken = CancelToken();
///
///   Future<void> loadData() async {
///     final data = await api.fetchData(cancelToken: _cancelToken);
///     if (mounted) setState(() => _data = data);
///   }
///
///   @override
///   void dispose() {
///     _cancelToken.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireCancelTokenRule extends SaropaLintRule {
  const RequireCancelTokenRule() : super(code: _code);

  /// Resource management and avoiding errors.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_cancel_token',
    problemMessage:
        '[require_cancel_token] Async request without cancellation continues after widget disposes, wasting resources and causing setState errors. Not cancelling can lead to memory leaks, wasted bandwidth, and crashes from setState on disposed widgets.',
    correctionMessage:
        'Use CancelToken (Dio) or implement request cancellation on dispose.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('State<')) return;

      final String classSource = node.toSource();

      // Check for HTTP calls
      final bool hasHttpCalls = classSource.contains('.get(') ||
          classSource.contains('.post(') ||
          classSource.contains('.fetch(') ||
          classSource.contains('http.') ||
          classSource.contains('dio.');

      if (!hasHttpCalls) return;

      // Check for cancellation patterns
      final bool hasCancellation = classSource.contains('CancelToken') ||
          classSource.contains('cancelToken') ||
          classSource.contains('_cancelled') ||
          classSource.contains('isCancelled') ||
          classSource.contains('cancel()');

      // Check for mounted check (partial mitigation)
      final bool hasMountedCheck = classSource.contains('if (mounted)') ||
          classSource.contains('if (!mounted)');

      if (!hasCancellation && !hasMountedCheck) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when WebSocket listeners don't have error handlers.
///
/// WebSocket streams can emit errors. Without error handling,
/// the app may crash or behave unexpectedly.
///
/// **BAD:**
/// ```dart
/// socket.stream.listen((data) {
///   processData(data);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// socket.stream.listen(
///   (data) => processData(data),
///   onError: (error) => handleError(error),
///   onDone: () => handleDisconnect(),
/// );
/// ```
///
/// **Quick fix available:** Adds an onError handler stub.
class RequireWebSocketErrorHandlingRule extends SaropaLintRule {
  const RequireWebSocketErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_websocket_error_handling',
    problemMessage:
        '[require_websocket_error_handling] WebSocket listener without onError can crash on errors.',
    correctionMessage: 'Add onError handler to WebSocket stream.listen().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if target is WebSocket-related
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('socket') &&
          !targetSource.contains('Socket') &&
          !targetSource.contains('channel') &&
          !targetSource.contains('Channel') &&
          !targetSource.contains('.stream')) {
        return;
      }

      // Check for onError parameter
      bool hasOnError = false;
      for (final Expression arg in node.argumentList.arguments) {
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

  @override
  List<Fix> getFixes() => <Fix>[_AddOnErrorHandlerFix()];
}

class _AddOnErrorHandlerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.methodName.name != 'listen') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add onError handler',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert before closing parenthesis
        final int insertOffset = args.rightParenthesis.offset;
        builder.addSimpleInsertion(
            insertOffset, ', onError: (error) { /* HACK: Handle error */ }');
      });
    });
  }
}

// =============================================================================
// Part 5 Rules: Dio HTTP Client Rules
// =============================================================================

/// Warns when Dio is used without timeout configuration.
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
        '[require_dio_timeout] Dio instance without timeout configuration. Requests may hang indefinitely.',
    correctionMessage:
        'Configure connectTimeout and receiveTimeout in BaseOptions.',
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
        '[require_dio_error_handling] Dio request without error handling. DioException will crash the app.',
    correctionMessage: 'Wrap in try-catch to handle DioException.',
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
        '[require_dio_interceptor_error_handler] InterceptorsWrapper without onError handler. Errors may be unhandled.',
    correctionMessage:
        'Add onError callback to handle request errors in interceptor.',
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
        '[prefer_dio_cancel_token] Long-running Dio request without CancelToken. Cannot be cancelled.',
    correctionMessage: 'Add cancelToken parameter for cancellable requests.',
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
        '[require_dio_ssl_pinning] Auth endpoint without SSL pinning. Vulnerable to MITM attacks.',
    correctionMessage:
        'Configure httpClientAdapter with certificate validation.',
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
        '[avoid_dio_form_data_leak] FormData with file. Ensure proper cleanup of file resources.',
    correctionMessage:
        'Consider cleanup or using try-finally for file uploads.',
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

/// Warns when HTTP response is parsed without Content-Type check.
///
/// APIs may return different content types on error. Parsing JSON
/// without checking Content-Type may fail unexpectedly.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(url);
/// final data = jsonDecode(response.body);
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(url);
/// if (response.headers['content-type']?.contains('application/json') == true) {
///   final data = jsonDecode(response.body);
/// } else {
///   throw FormatException('Expected JSON but got ${response.headers['content-type']}');
/// }
/// ```
class RequireContentTypeCheckRule extends SaropaLintRule {
  const RequireContentTypeCheckRule() : super(code: _code);

  /// Reliability issue - parsing may fail unexpectedly.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_content_type_check',
    problemMessage:
        '[require_content_type_check] Parsing response without Content-Type check. May fail on error responses.',
    correctionMessage:
        'Check response.headers[\'content-type\'] before parsing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;

      // Check for JSON parsing
      if (methodName != 'jsonDecode' && methodName != 'decode') {
        return;
      }

      // Check if argument references response.body
      final args = node.argumentList.arguments;
      if (args.isEmpty) {
        return;
      }

      final argSource = args.first.toSource().toLowerCase();
      if (!argSource.contains('response') || !argSource.contains('body')) {
        return;
      }

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) {
        return;
      }

      final methodSource = enclosingMethod.toSource().toLowerCase();

      // cspell:ignore contenttype
      // Check for Content-Type check
      if (methodSource.contains('content-type') ||
          methodSource.contains('contenttype')) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when WebSocket is used without heartbeat/ping mechanism.
///
/// WebSocket connections can silently fail. Periodic pings help
/// detect dead connections and keep firewalls from closing idle sockets.
///
/// **BAD:**
/// ```dart
/// final channel = WebSocketChannel.connect(Uri.parse('wss://...'));
/// channel.stream.listen((data) => handleData(data));
/// ```
///
/// **GOOD:**
/// ```dart
/// final channel = WebSocketChannel.connect(Uri.parse('wss://...'));
/// Timer.periodic(Duration(seconds: 30), (_) {
///   channel.sink.add('ping');
/// });
/// channel.stream.listen((data) => handleData(data));
/// ```
class AvoidWebsocketWithoutHeartbeatRule extends SaropaLintRule {
  const AvoidWebsocketWithoutHeartbeatRule() : super(code: _code);

  /// Reliability issue - dead connections go undetected.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_websocket_without_heartbeat',
    problemMessage:
        '[avoid_websocket_without_heartbeat] WebSocket without heartbeat/ping. Dead connections won\'t be detected.',
    correctionMessage:
        'Add periodic ping messages to detect connection failures.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Check for WebSocketChannel.connect
      final target = node.target;
      if (target is! SimpleIdentifier) {
        return;
      }

      if (!target.name.contains('WebSocket')) {
        return;
      }

      if (node.methodName.name != 'connect') {
        return;
      }

      // Find enclosing class or method
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null) {
        return;
      }

      final classSource = enclosingClass.toSource().toLowerCase();

      // Check for heartbeat patterns
      if (classSource.contains('ping') ||
          classSource.contains('heartbeat') ||
          classSource.contains('keepalive') ||
          (classSource.contains('timer.periodic') &&
              classSource.contains('sink.add'))) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// Part 7: Dio HTTP Client Rules
// =============================================================================

/// Warns when Dio debug logging is enabled without kDebugMode check.
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
        '[avoid_dio_debug_print_production] Dio LogInterceptor in production leaks sensitive request/response data to device logs.',
    correctionMessage: 'Wrap with: if (kDebugMode) { dio.interceptors.add... }',
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
        '[require_dio_singleton] Consider using a singleton Dio instance.',
    correctionMessage:
        'Create a shared Dio instance with consistent configuration.',
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
        '[prefer_dio_base_options] Repeated options in Dio requests. Consider using BaseOptions.',
    correctionMessage:
        'Move common headers/timeouts to BaseOptions in Dio constructor.',
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
        '[avoid_dio_without_base_url] Dio request with full URL. Consider setting baseUrl.',
    correctionMessage:
        'Set baseUrl in BaseOptions and use relative paths in requests.',
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

// =============================================================================
// Part 7: URL Launcher Rules
// =============================================================================

/// Warns when launchUrl is called without try-catch error handling.
///
/// Alias: url_launch_unhandled, launch_url_try_catch
///
/// launchUrl can throw PlatformException if no app can handle the URL.
///
/// **BAD:**
/// ```dart
/// await launchUrl(Uri.parse(url));  // May throw!
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   if (await canLaunchUrl(uri)) {
///     await launchUrl(uri);
///   }
/// } catch (e) {
///   // Handle error
/// }
/// ```
class RequireUrlLauncherErrorHandlingRule extends SaropaLintRule {
  const RequireUrlLauncherErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_url_launcher_error_handling',
    problemMessage:
        '[require_url_launcher_error_handling] launchUrl without error handling can crash.',
    correctionMessage: 'Wrap in try-catch or check with canLaunchUrl first.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'launchUrl' &&
          node.methodName.name != 'launch') {
        return;
      }

      // Check if inside try block
      AstNode? current = node.parent;
      bool inTryBlock = false;
      bool hasCanLaunchCheck = false;

      while (current != null) {
        if (current is TryStatement) {
          inTryBlock = true;
          break;
        }
        if (current is IfStatement) {
          final condition = current.expression.toSource();
          if (condition.contains('canLaunchUrl') ||
              condition.contains('canLaunch')) {
            hasCanLaunchCheck = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!inTryBlock && !hasCanLaunchCheck) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

// =============================================================================
// Part 7: Image Picker Rules
// =============================================================================

/// Warns when pickImage is called without null check or try-catch.
///
/// Alias: image_picker_no_error_handling, pick_image_crash
///
/// pickImage returns null if user cancels and can throw on permission denied.
///
/// **BAD:**
/// ```dart
/// final image = await picker.pickImage(source: ImageSource.camera);
/// File file = File(image!.path);  // Crash if cancelled!
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final image = await picker.pickImage(source: ImageSource.camera);
///   if (image == null) return;  // User cancelled
///   File file = File(image.path);
/// } catch (e) {
///   // Handle permission error
/// }
/// ```
class RequireImagePickerErrorHandlingRule extends SaropaLintRule {
  const RequireImagePickerErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_picker_error_handling',
    problemMessage:
        '[require_image_picker_error_handling] pickImage without null check or error handling.',
    correctionMessage: 'Add null check for cancelled and try-catch for errors.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'pickImage' &&
          node.methodName.name != 'pickVideo' &&
          node.methodName.name != 'pickMultiImage') {
        return;
      }

      // Check if inside try block
      AstNode? current = node.parent;
      bool inTryBlock = false;

      while (current != null) {
        if (current is TryStatement) {
          inTryBlock = true;
          break;
        }
        current = current.parent;
      }

      if (!inTryBlock) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when ImageSource is hardcoded without giving user choice.
///
/// Alias: image_picker_source_fixed, no_source_choice
///
/// Users should be able to choose between camera and gallery.
///
/// **BAD:**
/// ```dart
/// picker.pickImage(source: ImageSource.camera);  // No gallery option
/// ```
///
/// **GOOD:**
/// ```dart
/// showModalBottomSheet(
///   builder: (_) => Column(children: [
///     ListTile(onTap: () => pickImage(ImageSource.camera)),
///     ListTile(onTap: () => pickImage(ImageSource.gallery)),
///   ]),
/// );
/// ```
class RequireImagePickerSourceChoiceRule extends SaropaLintRule {
  const RequireImagePickerSourceChoiceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_picker_source_choice',
    problemMessage:
        '[require_image_picker_source_choice] Hardcoded ImageSource. Consider offering user a choice.',
    correctionMessage: 'Show dialog letting user choose camera or gallery.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'pickImage') return;

      // Check for hardcoded ImageSource
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'source') {
          final sourceValue = arg.expression.toSource();
          if (sourceValue == 'ImageSource.camera' ||
              sourceValue == 'ImageSource.gallery') {
            // Hardcoded source - check if in a method that handles both
            AstNode? current = node.parent;
            MethodDeclaration? enclosingMethod;

            while (current != null) {
              if (current is MethodDeclaration) {
                enclosingMethod = current;
                break;
              }
              current = current.parent;
            }

            // If method has ImageSource parameter, it's OK
            if (enclosingMethod != null) {
              final params = enclosingMethod.parameters?.toSource() ?? '';
              if (params.contains('ImageSource')) return;
            }

            reporter.atNode(arg.expression, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// Part 7: Geolocator Rules
// =============================================================================

/// Warns when getCurrentPosition is called without timeLimit.
///
/// Alias: geolocator_no_timeout, position_timeout_missing
///
/// Without timeout, getCurrentPosition can hang indefinitely.
///
/// **BAD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition();  // May hang!
/// ```
///
/// **GOOD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition(
///   timeLimit: Duration(seconds: 10),
/// );
/// ```
class RequireGeolocatorTimeoutRule extends SaropaLintRule {
  const RequireGeolocatorTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_geolocator_timeout',
    problemMessage:
        '[require_geolocator_timeout] getCurrentPosition without timeLimit can hang.',
    correctionMessage: 'Add timeLimit parameter (e.g., Duration(seconds: 10)).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getCurrentPosition') return;

      // Only apply to files that import geolocator
      if (!fileImportsPackage(node, PackageImports.geolocator)) return;

      // Check if target is Geolocator class (static method call)
      final target = node.target;
      if (target == null) return;
      // Use type-based check: target should be SimpleIdentifier 'Geolocator'
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check for timeLimit parameter
      bool hasTimeLimit = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'timeLimit') {
          hasTimeLimit = true;
          break;
        }
      }

      if (!hasTimeLimit) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

// =============================================================================
// Part 7: Connectivity Rules
// =============================================================================

/// Warns when connectivity subscription isn't cancelled.
///
/// Alias: connectivity_leak, connectivity_no_cancel
///
/// Connectivity subscriptions must be cancelled to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class _State extends State<W> {
///   @override
///   void initState() {
///     super.initState();
///     Connectivity().onConnectivityChanged.listen((_) {});  // Leak!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _State extends State<W> {
///   StreamSubscription? _connectivitySub;
///
///   @override
///   void initState() {
///     super.initState();
///     _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {});
///   }
///
///   @override
///   void dispose() {
///     _connectivitySub?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireConnectivitySubscriptionCancelRule extends SaropaLintRule {
  const RequireConnectivitySubscriptionCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_connectivity_subscription_cancel',
    problemMessage:
        '[require_connectivity_subscription_cancel] Connectivity subscription without cancel causes memory leak.',
    correctionMessage: 'Store subscription and cancel in dispose().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Only apply to files that import connectivity package
      if (!fileImportsPackage(node, PackageImports.connectivity)) return;

      // Check if target is onConnectivityChanged property access
      final target = node.target;
      if (target == null) return;
      // Use property-based check instead of string contains
      if (target is PropertyAccess) {
        if (target.propertyName.name != 'onConnectivityChanged') return;
      } else if (target is PrefixedIdentifier) {
        if (target.identifier.name != 'onConnectivityChanged') return;
      } else {
        return; // Not a recognized pattern
      }

      // Check if result is stored
      AstNode? parent = node.parent;
      if (parent is AssignmentExpression ||
          (parent is VariableDeclaration && parent.name.lexeme.isNotEmpty)) {
        return; // Result is stored - assume proper handling
      }

      // Check if we're in initState without storing result
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration &&
            current.name.lexeme == 'initState') {
          reporter.atNode(node.methodName, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// Part 7: Notification Rules
// =============================================================================

/// Warns when background notification handler is an instance method.
///
/// Alias: notification_handler_instance, fcm_handler_top_level
///
/// Firebase messaging background handler must be a top-level function.
///
/// **BAD:**
/// ```dart
/// class MyService {
///   void handleBackground(RemoteMessage msg) {}  // Won't work!
/// }
/// FirebaseMessaging.onBackgroundMessage(service.handleBackground);
/// ```
///
/// **GOOD:**
/// ```dart
/// @pragma('vm:entry-point')
/// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {}
///
/// FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
/// ```
class RequireNotificationHandlerTopLevelRule extends SaropaLintRule {
  const RequireNotificationHandlerTopLevelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_notification_handler_top_level',
    problemMessage:
        '[require_notification_handler_top_level] Non-top-level handlers fail '
        'silently in background. Messages are lost when app is terminated.',
    correctionMessage:
        'Move handler to top-level function with @pragma("vm:entry-point").',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'onBackgroundMessage') return;

      // Only apply to files that import firebase_messaging
      if (!fileImportsPackage(node, PackageImports.firebaseMessaging)) return;

      // Check if target is FirebaseMessaging class
      final target = node.target;
      if (target == null) return;
      // Use type-based check: target should be SimpleIdentifier 'FirebaseMessaging'
      if (target is! SimpleIdentifier || target.name != 'FirebaseMessaging') {
        // Also check for property access like FirebaseMessaging.instance
        if (target is! PropertyAccess) return;
        final targetExpr = target.target;
        if (targetExpr is! SimpleIdentifier ||
            targetExpr.name != 'FirebaseMessaging') {
          return;
        }
      }

      // Check the handler argument
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final handler = args.first;

      // Check if handler is an instance method reference (contains dot but not a simple identifier)
      if (handler is PrefixedIdentifier) {
        // e.g., service.handleBackground - instance method
        reporter.atNode(handler, code);
      } else if (handler is PropertyAccess) {
        // e.g., this.handleBackground or obj.method
        reporter.atNode(handler, code);
      }
      // SimpleIdentifier like _handleBackground or handleBackground are OK (top-level or static)
    });
  }
}

// =============================================================================
// Part 7: Permission Handler Rules
// =============================================================================

/// Warns when permission denied state is not handled.
///
/// Alias: permission_denied_unhandled, missing_denied_handler
///
/// Users may deny permissions. Apps must handle denied state gracefully.
///
/// **BAD:**
/// ```dart
/// await Permission.camera.request();
/// // Proceeds assuming permission granted!
/// ```
///
/// **GOOD:**
/// ```dart
/// final status = await Permission.camera.request();
/// if (status.isDenied || status.isPermanentlyDenied) {
///   // Show explanation or alternative
///   return;
/// }
/// ```
class RequirePermissionDeniedHandlingRule extends SaropaLintRule {
  const RequirePermissionDeniedHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_permission_denied_handling',
    problemMessage:
        '[require_permission_denied_handling] Permission request ignoring denied state leaves users stuck with no explanation or settings link.',
    correctionMessage:
        'Check and handle isDenied and isPermanentlyDenied states.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;

      // Only apply to files that import permission_handler
      if (!fileImportsPackage(node, PackageImports.permissionHandler)) return;

      // Check if target is a Permission property (e.g., Permission.camera)
      final target = node.target;
      if (target == null) return;
      // Use type-based check: should be PropertyAccess on Permission class
      if (target is PropertyAccess) {
        final targetExpr = target.target;
        if (targetExpr is! SimpleIdentifier ||
            targetExpr.name != 'Permission') {
          return;
        }
      } else if (target is PrefixedIdentifier) {
        if (target.prefix.name != 'Permission') return;
      } else {
        return; // Not a recognized Permission pattern
      }

      // Find enclosing method and check for status handling
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) return;

      // Check for status property access patterns
      // These property names are specific to PermissionStatus and safe to check
      final hasStatusCheck = _hasPermissionStatusCheck(enclosingMethod.body);

      if (!hasStatusCheck) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  /// Check if the method body contains permission status property access.
  /// Uses AST walking to find PropertyAccess or PrefixedIdentifier nodes.
  bool _hasPermissionStatusCheck(FunctionBody body) {
    const statusProperties = <String>{
      'isDenied',
      'isPermanentlyDenied',
      'isGranted',
      'isLimited',
      'isRestricted',
    };

    bool found = false;

    void checkNode(AstNode node) {
      if (found) return;

      if (node is PropertyAccess) {
        if (statusProperties.contains(node.propertyName.name)) {
          found = true;
          return;
        }
      } else if (node is PrefixedIdentifier) {
        if (statusProperties.contains(node.identifier.name)) {
          found = true;
          return;
        }
      }

      node.childEntities.whereType<AstNode>().forEach(checkNode);
    }

    checkNode(body);
    return found;
  }
}

// =============================================================================
// ROADMAP_NEXT Part 7 Rules - Additional
// =============================================================================

/// Warns when pickImage result is not checked for null.
///
/// Alias: image_picker_result, handle_picker_null
///
/// ImagePicker.pickImage returns null when the user cancels. Ignoring the
/// result leads to null pointer errors.
///
/// **BAD:**
/// ```dart
/// final image = await picker.pickImage(source: ImageSource.camera);
/// final bytes = await image.readAsBytes(); // Crashes if null!
/// ```
///
/// **GOOD:**
/// ```dart
/// final image = await picker.pickImage(source: ImageSource.camera);
/// if (image == null) return;
/// final bytes = await image.readAsBytes();
/// ```
class RequireImagePickerResultHandlingRule extends SaropaLintRule {
  const RequireImagePickerResultHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_picker_result_handling',
    problemMessage:
        '[require_image_picker_result_handling] pickImage returns null when '
        'user cancels. Missing null check causes NoSuchMethodError crash.',
    correctionMessage: 'Add null check: if (image == null) return;',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (methodName != 'pickImage' && methodName != 'pickVideo') return;

      // Check if result is used directly without null check
      AstNode? parent = node.parent;

      // Skip if this is inside a null-aware operation
      while (parent != null) {
        if (parent is AwaitExpression) {
          parent = parent.parent;
          continue;
        }
        if (parent is ConditionalExpression ||
            parent is IfStatement ||
            parent is BinaryExpression) {
          final source = parent.toSource();
          if (source.contains('== null') ||
              source.contains('!= null') ||
              source.contains('?')) {
            return; // Has null check
          }
        }
        if (parent is VariableDeclaration) {
          // Check if followed by null check
          AstNode? stmt = parent.parent?.parent;
          if (stmt is VariableDeclarationStatement) {
            AstNode? nextNode = stmt.parent;
            if (nextNode is Block) {
              final statements = nextNode.statements;
              final stmtIndex = statements.indexOf(stmt);
              if (stmtIndex >= 0 && stmtIndex < statements.length - 1) {
                final nextStmt = statements[stmtIndex + 1];
                if (nextStmt.toSource().contains('== null') ||
                    nextStmt.toSource().contains('!= null')) {
                  return; // Has null check after
                }
              }
            }
          }
          break;
        }
        parent = parent.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when CachedNetworkImage uses a variable cacheKey in build.
///
/// Alias: cached_image_key, stable_cache_key
///
/// Using a changing cacheKey in build causes the image to reload on every
/// rebuild, defeating the purpose of caching.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   return CachedNetworkImage(
///     imageUrl: url,
///     cacheKey: DateTime.now().toString(), // Changes every build!
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(context) {
///   return CachedNetworkImage(
///     imageUrl: url,
///     cacheKey: 'stable_key_$id', // Stable key
///   );
/// }
/// ```
class AvoidCachedImageInBuildRule extends SaropaLintRule {
  const AvoidCachedImageInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_cached_image_in_build',
    problemMessage:
        '[avoid_cached_image_in_build] Variable cacheKey in build method defeats caching.',
    correctionMessage: 'Use a stable cacheKey that does not change on rebuild.',
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
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'CachedNetworkImage') return;

      // Check if inside build method
      AstNode? current = node.parent;
      bool inBuild = false;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          inBuild = true;
          break;
        }
        current = current.parent;
      }

      if (!inBuild) return;

      // Check cacheKey argument
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'cacheKey') {
          final valueSource = arg.expression.toSource();
          // Flag if using DateTime.now(), Random, uuid generation, etc.
          if (valueSource.contains('DateTime.now') ||
              valueSource.contains('Random') ||
              valueSource.contains('.v4()') ||
              valueSource.contains('.v1()') ||
              valueSource.contains('uuid')) {
            reporter.atNode(arg, code);
          }
        }
      }
    });
  }
}

/// Warns when SQLite onUpgrade doesn't check oldVersion properly.
///
/// Alias: sqflite_version_check, database_migration
///
/// Database migrations must check oldVersion to apply only necessary changes.
/// Missing version checks can corrupt data or skip migrations.
///
/// **BAD:**
/// ```dart
/// database.onUpgrade = (db, oldVersion, newVersion) async {
///   await db.execute('ALTER TABLE users ADD COLUMN age INTEGER');
/// };
/// ```
///
/// **GOOD:**
/// ```dart
/// database.onUpgrade = (db, oldVersion, newVersion) async {
///   if (oldVersion < 2) {
///     await db.execute('ALTER TABLE users ADD COLUMN age INTEGER');
///   }
///   if (oldVersion < 3) {
///     await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
///   }
/// };
/// ```
class RequireSqfliteMigrationRule extends SaropaLintRule {
  const RequireSqfliteMigrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_sqflite_migration',
    problemMessage:
        '[require_sqflite_migration] onUpgrade without oldVersion check runs all migrations, corrupting data for users upgrading from recent versions.',
    correctionMessage:
        'Add version checks: if (oldVersion < 2) { ... migrations ... }',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Check if this is an onUpgrade callback (has oldVersion parameter)
      final params = node.parameters;
      if (params == null) return;

      final paramNames =
          params.parameters.map((p) => p.name?.lexeme ?? '').toList();
      if (!paramNames.contains('oldVersion') &&
          !paramNames.contains('old') &&
          !paramNames.any((p) => p.toLowerCase().contains('version'))) {
        return;
      }

      // Check if body contains version check
      final bodySource = node.body.toSource();
      if (bodySource.contains('oldVersion <') ||
          bodySource.contains('oldVersion <=') ||
          bodySource.contains('oldVersion >') ||
          bodySource.contains('oldVersion >=') ||
          bodySource.contains('oldVersion ==')) {
        return; // Has version check
      }

      // cspell:ignore onupgrade
      // Check if parent is assignment to onUpgrade
      AstNode? current = node.parent;
      while (current != null) {
        if (current is AssignmentExpression) {
          final leftSource = current.leftHandSide.toSource().toLowerCase();
          if (leftSource.contains('onupgrade') ||
              leftSource.contains('on_upgrade')) {
            reporter.atNode(node, code);
            return;
          }
        }
        if (current is NamedExpression) {
          final name = current.name.label.name.toLowerCase();
          if (name.contains('onupgrade') || name.contains('on_upgrade')) {
            reporter.atNode(node, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// Permission Rules (Part 7)
// =============================================================================

/// Warns when requesting permissions without showing a rationale first.
///
/// Alias: permission_rationale, show_rationale
///
/// Android best practice is to explain why the app needs a permission before
/// requesting it using shouldShowRequestRationale.
///
/// **BAD:**
/// ```dart
/// await Permission.camera.request();
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await Permission.camera.shouldShowRequestRationale) {
///   showRationaleDialog();
/// }
/// await Permission.camera.request();
/// ```
class RequirePermissionRationaleRule extends SaropaLintRule {
  const RequirePermissionRationaleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_permission_rationale',
    problemMessage:
        '[require_permission_rationale] Permission request without checking shouldShowRequestRationale.',
    correctionMessage:
        'Check shouldShowRequestRationale() before requesting permission.',
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

      // Check for permission request patterns
      if (methodName != 'request' && methodName != 'requestPermission') {
        return;
      }

      // Check if target is Permission related
      final target = node.target;
      if (target == null) return;

      final targetType = target.staticType?.toString() ?? '';
      final targetSource = target.toSource().toLowerCase();
      if (!targetType.contains('Permission') &&
          !targetSource.contains('permission')) {
        return;
      }

      // Look for shouldShowRequestRationale check in parent method
      final methodDeclaration = node.thisOrAncestorOfType<MethodDeclaration>();
      if (methodDeclaration == null) return;

      // cspell:ignore shouldshowrequestrationale shouldshowrationale
      final bodySource = methodDeclaration.body.toSource().toLowerCase();
      if (bodySource.contains('shouldshowrequestrationale') ||
          bodySource.contains('shouldshowrationale') ||
          bodySource.contains('show') && bodySource.contains('rationale')) {
        return; // Has rationale check
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when using permission-gated features without checking status.
///
/// Alias: check_permission_status, permission_before_use
///
/// Using features like camera, location, or microphone without checking if
/// permission was granted leads to crashes or silent failures.
///
/// **BAD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition();
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await Permission.location.isGranted) {
///   final position = await Geolocator.getCurrentPosition();
/// }
/// ```
class RequirePermissionStatusCheckRule extends SaropaLintRule {
  const RequirePermissionStatusCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_permission_status_check',
    problemMessage:
        '[require_permission_status_check] Using camera/location without permission check crashes on denied permission.',
    correctionMessage: 'Check permission.status.isGranted before use.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _gatedFeatures = <String>{
    'getCurrentPosition',
    'getLastKnownPosition',
    'takePicture',
    'pickImage',
    'scanBarcodes',
    'startScan',
    'startListening',
    'requestContactsPermission',
    'getContacts',
    'openCamera',
    'accessMicrophone',
    'recordAudio',
    'startRecording',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;

      if (!_gatedFeatures.contains(methodName)) {
        return;
      }

      // Look for permission check in parent method
      final methodDeclaration = node.thisOrAncestorOfType<MethodDeclaration>();
      if (methodDeclaration == null) return;

      final bodySource = methodDeclaration.body.toSource().toLowerCase();

      // cspell:ignore isgranted permissionstatus haspermission checkpermission
      // Check for common permission check patterns
      if (bodySource.contains('isgranted') ||
          bodySource.contains('is_granted') ||
          bodySource.contains('permissionstatus.granted') ||
          bodySource.contains('status == permissionstatus.granted') ||
          bodySource.contains('.request()') ||
          bodySource.contains('haspermission') ||
          bodySource.contains('checkpermission')) {
        return; // Has permission check
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when showing notifications without Android 13+ permission check.
///
/// Alias: android13_notification, post_notifications
///
/// Android 13 (API 33) requires explicit POST_NOTIFICATIONS permission.
/// Without this check, notifications silently fail on Android 13+ devices.
///
/// **BAD:**
/// ```dart
/// await notificationsPlugin.show(0, 'Title', 'Body', details);
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await Permission.notification.isGranted) {
///   await notificationsPlugin.show(0, 'Title', 'Body', details);
/// }
/// ```
class RequireNotificationPermissionAndroid13Rule extends SaropaLintRule {
  const RequireNotificationPermissionAndroid13Rule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_notification_permission_android13',
    problemMessage:
        '[require_notification_permission_android13] Notification shown without POST_NOTIFICATIONS permission check.',
    correctionMessage:
        'Request Permission.notification before showing notifications.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _notificationMethods = <String>{
    'show',
    'showNotification',
    'displayNotification',
    'createNotification',
    'schedule',
    'scheduleNotification',
    'zonedSchedule',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;

      if (!_notificationMethods.contains(methodName)) {
        return;
      }

      // Check if target is notification-related
      final target = node.target;
      if (target == null) return;

      // cspell:ignore flutterlocalnoti
      final targetType = target.staticType?.toString() ?? '';
      final targetSource = target.toSource().toLowerCase();
      if (!targetType.toLowerCase().contains('notification') &&
          !targetSource.contains('notification') &&
          !targetSource.contains('local_notifications') &&
          !targetSource.contains('flutterlocalnoti')) {
        return;
      }

      // Look for notification permission check in the method or class
      final methodDeclaration = node.thisOrAncestorOfType<MethodDeclaration>();
      if (methodDeclaration == null) return;

      final bodySource = methodDeclaration.body.toSource().toLowerCase();

      // cspell:ignore notificationpermission requestnotificationpermission
      // Check for notification permission patterns
      if (bodySource.contains('permission.notification') ||
          bodySource.contains('post_notifications') ||
          bodySource.contains('notificationpermission') ||
          bodySource.contains('notification_permission') ||
          bodySource.contains('requestnotificationpermission')) {
        return; // Has permission check
      }

      // Check class-level for permission check
      final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl != null) {
        final classSource = classDecl.toSource().toLowerCase();
        if (classSource.contains('permission.notification') ||
            classSource.contains('notificationpermission')) {
          return;
        }
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// Server-Sent Events (SSE) Subscription Rules
// =============================================================================

/// Warns when EventSource/SSE connection is created without close() cleanup.
///
/// Alias: sse_subscription_cancel, event_source_close, sse_close
///
/// Server-Sent Events (SSE) connections via EventSource or similar packages
/// must be closed when the widget is disposed to prevent resource leaks and
/// orphaned network connections.
///
/// This rule checks for:
/// - html.EventSource (dart:html)
/// - EventSource from sse_client package
/// - SseClient from flutter_client_sse package
/// - Any field with "sse" or "eventSource" in the name
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   EventSource? _eventSource;
///
///   @override
///   void initState() {
///     super.initState();
///     _eventSource = EventSource('https://api.example.com/stream');
///     _eventSource?.onMessage.listen((event) {
///       // Handle SSE event
///     });
///   }
///   // Missing close() in dispose - connection stays open!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   EventSource? _eventSource;
///
///   @override
///   void initState() {
///     super.initState();
///     _eventSource = EventSource('https://api.example.com/stream');
///     _eventSource?.onMessage.listen((event) {
///       // Handle SSE event
///     });
///   }
///
///   @override
///   void dispose() {
///     _eventSource?.close();
///     super.dispose();
///   }
/// }
/// ```
class RequireSseSubscriptionCancelRule extends SaropaLintRule {
  const RequireSseSubscriptionCancelRule() : super(code: _code);

  /// SSE connections are long-lived and must be properly closed.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_sse_subscription_cancel',
    problemMessage:
        '[require_sse_subscription_cancel] EventSource/SSE connection must be closed in dispose() to prevent resource leaks.',
    correctionMessage:
        'Add _eventSource?.close() in dispose() method before super.dispose().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Types that represent SSE connections
  static const Set<String> _sseTypes = <String>{
    'EventSource',
    'SseClient',
    'SSEClient',
    'ServerSentEvent',
    'SseConnection',
    'SSEConnection',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find SSE-related fields
      final List<String> sseFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();

          for (final VariableDeclaration variable in member.fields.variables) {
            final String fieldNameOriginal = variable.name.lexeme;
            final String fieldNameLower = fieldNameOriginal.toLowerCase();
            bool isSseField = false;

            // Check by type name
            if (typeName != null) {
              for (final String sseType in _sseTypes) {
                if (typeName.contains(sseType)) {
                  isSseField = true;
                  break;
                }
              }
            }

            // cspell:ignore eventsource serversentevent
            // Also check by field name patterns using word boundaries
            // Use regex to avoid false positives like "addressesFuture" or "hasSearched"
            if (!isSseField) {
              // Match 'sse' only at word boundaries:
              // - Start of string: ^sse followed by uppercase (sseClient) or underscore
              // - After underscore: _sse followed by uppercase or underscore or end
              // - Use original case for camelCase detection (sseC), lowercase for contains
              final ssePattern = RegExp(r'(^|_)sse($|_|[A-Z])');
              if (fieldNameLower.contains('eventsource') ||
                  fieldNameLower.contains('event_source') ||
                  ssePattern.hasMatch(fieldNameOriginal) ||
                  fieldNameLower.contains('serversentevent')) {
                isSseField = true;
              }
            }

            if (isSseField) {
              sseFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (sseFields.isEmpty) return;

      // Find dispose method and check for close calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Report SSE fields not closed in dispose
      for (final String fieldName in sseFields) {
        final bool isClosed = disposeBody != null &&
            (disposeBody.contains('$fieldName.close()') ||
                disposeBody.contains('$fieldName?.close()') ||
                disposeBody.contains('$fieldName.dispose()') ||
                disposeBody.contains('$fieldName?.dispose()') ||
                disposeBody.contains('$fieldName.cancel()') ||
                disposeBody.contains('$fieldName?.cancel()'));

        if (!isClosed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when HTTP requests don't have a timeout specified.
///
/// Alias: http_timeout, network_timeout, request_timeout
///
/// HTTP requests without timeouts can hang indefinitely, freezing the UI
/// or consuming resources. Always set a reasonable timeout.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse(url));
/// ```
///
/// **GOOD:**
/// ```dart
/// final response = await http.get(Uri.parse(url))
///     .timeout(const Duration(seconds: 30));
/// ```
class PreferTimeoutOnRequestsRule extends SaropaLintRule {
  const PreferTimeoutOnRequestsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_timeout_on_requests',
    problemMessage:
        '[prefer_timeout_on_requests] HTTP request without timeout. Request may hang indefinitely.',
    correctionMessage:
        'Add .timeout(Duration(seconds: 30)) or configure client timeout.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _httpMethods = <String>{
    'get',
    'post',
    'put',
    'delete',
    'patch',
    'head',
    'read',
    'readBytes',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_httpMethods.contains(methodName)) return;

      // Check if target looks like an http call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('http') &&
          !targetSource.contains('client') &&
          !targetSource.contains('Client') &&
          !targetSource.contains('dio') &&
          !targetSource.contains('Dio')) {
        return;
      }

      // Check if .timeout is chained
      AstNode? parent = node.parent;
      if (parent is MethodInvocation && parent.methodName.name == 'timeout') {
        return;
      }

      // Check if wrapped in await with timeout
      if (parent is AwaitExpression) {
        AstNode? awaitParent = parent.parent;
        if (awaitParent is MethodInvocation &&
            awaitParent.methodName.name == 'timeout') {
          return;
        }
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[
        _AddTimeout30SecondsFix(),
        _AddTimeout60SecondsFix(),
      ];
}

/// Quick fix: adds `.timeout(const Duration(seconds: 30))` to HTTP requests.
class _AddTimeout30SecondsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add .timeout(const Duration(seconds: 30))',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final int insertOffset = node.argumentList.rightParenthesis.end;
        builder.addSimpleInsertion(
          insertOffset,
          '.timeout(const Duration(seconds: 30))',
        );
      });
    });
  }
}

/// Quick fix: adds `.timeout(const Duration(seconds: 60))` for slower APIs.
class _AddTimeout60SecondsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add .timeout(const Duration(seconds: 60))',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        final int insertOffset = node.argumentList.rightParenthesis.end;
        builder.addSimpleInsertion(
          insertOffset,
          '.timeout(const Duration(seconds: 60))',
        );
      });
    });
  }
}

/// Warns when using the http package instead of Dio.
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
        '[prefer_dio_over_http] Using http package. Dio provides better features for production apps.',
    correctionMessage:
        'Consider using Dio for interceptors, cancellation, and error handling.',
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
        '[require_dio_response_type] Dio download without explicit responseType may corrupt binary data.',
    correctionMessage:
        'Add options: Options(responseType: ResponseType.bytes) for downloads.',
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
        '[require_dio_retry_interceptor] Dio instance without retry interceptor.',
    correctionMessage: 'Add RetryInterceptor for network resilience.',
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
        '[prefer_dio_transformer] Dio instance without custom transformer for large data.',
    correctionMessage:
        'Set dio.transformer = BackgroundTransformer() for off-main-thread parsing.',
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
