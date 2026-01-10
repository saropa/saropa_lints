// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// API and network lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper API usage patterns, network error
/// handling, and resilient communication with backend services.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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

  static const LintCode _code = LintCode(
    name: 'require_http_status_check',
    problemMessage:
        'HTTP response body used without checking status. Errors may be silently ignored.',
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
class RequireApiTimeoutRule extends SaropaLintRule {
  const RequireApiTimeoutRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_api_timeout',
    problemMessage:
        'API call has no timeout. Request may hang indefinitely on poor networks.',
    correctionMessage:
        'Add .timeout(Duration(seconds: 30)) or configure timeout in client options.',
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
class AvoidHardcodedApiUrlsRule extends SaropaLintRule {
  const AvoidHardcodedApiUrlsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_api_urls',
    problemMessage:
        'Hardcoded API URL. Cannot switch between dev/staging/prod environments.',
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

  static const LintCode _code = LintCode(
    name: 'require_retry_logic',
    problemMessage:
        'Network call has no retry logic. Transient failures will not recover.',
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

  static const LintCode _code = LintCode(
    name: 'require_typed_api_response',
    problemMessage: 'API response should be parsed into a typed model.',
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

  static const LintCode _code = LintCode(
    name: 'require_connectivity_check',
    problemMessage: 'Consider checking connectivity before network operations.',
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

  static const LintCode _code = LintCode(
    name: 'require_api_error_mapping',
    problemMessage: 'API errors should be mapped to domain exceptions.',
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

  static const LintCode _code = LintCode(
    name: 'require_request_timeout',
    problemMessage: 'HTTP request without timeout may hang indefinitely.',
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

  static const LintCode _code = LintCode(
    name: 'require_offline_indicator',
    problemMessage:
        'Connectivity check without offline indicator. Users should see when offline.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_streaming_response',
    problemMessage:
        'Large download uses bodyBytes. Consider streaming for large files.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_http_connection_reuse',
    problemMessage:
        'HTTP client created inside method. Connection overhead on every call.',
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
    context.registry.addInstanceCreationExpression(
      (InstanceCreationExpression node) {
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
      },
    );
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

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_requests',
    problemMessage:
        'API call in build() or similar may cause redundant requests.',
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

  static const LintCode _code = LintCode(
    name: 'require_response_caching',
    problemMessage:
        'GET request without caching. Consider caching static data.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_pagination',
    problemMessage:
        'API fetches all items without pagination. May cause memory issues.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_over_fetching',
    problemMessage:
        'Fetching full object but only using few fields. Consider optimizing.',
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
      final RegExp fetchPattern = RegExp(
        r'await\s+\w+\.(get|fetch|query)\([^)]+\)',
      );

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
          final int totalProps = RegExp(r'\.(name|title|id|label|text)\b')
              .allMatches(bodySource)
              .length;
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

  static const LintCode _code = LintCode(
    name: 'require_cancel_token',
    problemMessage:
        'Async request in StatefulWidget without cancellation support.',
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

  static const LintCode _code = LintCode(
    name: 'require_websocket_error_handling',
    problemMessage: 'WebSocket listener without onError can crash on errors.',
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
          insertOffset,
          ', onError: (error) { /* TODO: Handle error */ }',
        );
      });
    });
  }
}
