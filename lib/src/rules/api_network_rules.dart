// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// API and network lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper API usage patterns, network error
/// handling, and resilient communication with backend services.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../import_utils.dart';
import '../saropa_lint_rule.dart';

// =============================================================================
// HTTP Rules
// =============================================================================

/// Warns when HTTP response status is not checked.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequireHttpStatusCheckRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_http_status_check',
    '[require_http_status_check] HTTP response body is used without first checking the status code. This can result in undetected failures, silent data corruption, or security issues if error responses are parsed as valid data. Always check if (response.statusCode == 200) before parsing response.body to ensure only successful responses are processed and errors are handled appropriately. {v5}',
    correctionMessage:
        'Check if (response.statusCode == 200) before parsing response.body to ensure only successful responses are processed and error payloads are handled separately.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP calls (specific client patterns only)
      if (!bodySource.contains('http.get') &&
          !bodySource.contains('http.post') &&
          !bodySource.contains('http.put') &&
          !bodySource.contains('http.delete') &&
          !bodySource.contains('dio.get') &&
          !bodySource.contains('dio.post') &&
          !bodySource.contains('client.get') &&
          !bodySource.contains('client.post')) {
        return;
      }

      // Check if statusCode is checked
      if (!bodySource.contains('statusCode') &&
          !bodySource.contains('isSuccessful')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when API endpoint URLs are hardcoded.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidHardcodedApiUrlsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_hardcoded_api_urls',
    '[avoid_hardcoded_api_urls] Hardcoded API URLs prevent switching between development, staging, and production environments, making code inflexible and error-prone. This practice also risks leaking sensitive endpoints and complicates maintenance. Always extract API URLs to configuration constants (e.g., ApiConfig.baseUrl) to enable environment switching and improve security. {v5}',
    correctionMessage:
        "Extract the URL to a configuration constant (e.g., ApiConfig.baseUrl) so endpoints can be switched per environment without code changes.",
    severity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _apiUrlPattern = RegExp(
    r'https?://[a-zA-Z0-9.-]+\.(com|io|net|org|dev|app)/api',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip config files
    final String path = context.filePath;
    if (path.contains('config') || path.contains('constants')) return;

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (_apiUrlPattern.hasMatch(value)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when retry logic is missing for network calls.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
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
  RequireRetryLogicRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_retry_logic',
    '[require_retry_logic] Network call does not implement retry logic, so transient failures (e.g., temporary network loss, server hiccups) will not recover automatically. This can lead to poor reliability and frustrated users. Always wrap network calls with retry() or implement exponential backoff for SocketException/TimeoutException to improve robustness. {v6}',
    correctionMessage:
        'Wrap with retry() or implement exponential backoff for SocketException/TimeoutException.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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

      // Check for HTTP calls (specific client patterns only)
      if (!bodySource.contains('http.') &&
          !bodySource.contains('dio.') &&
          !bodySource.contains('client.get') &&
          !bodySource.contains('client.post')) {
        return;
      }

      // Check for retry logic
      if (!bodySource.contains('retry') &&
          !bodySource.contains('Retry') &&
          !bodySource.contains('maxRetries')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when API response is not properly typed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  RequireTypedApiResponseRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_typed_api_response',
    '[require_typed_api_response] Untyped API access via dynamic keys '
        'loses type safety. Typos cause runtime errors, not compile errors. {v4}',
    correctionMessage: 'Create a model class and use fromJson/fromMap.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'jsonDecode' && methodName != 'decode') return;

      // Check if result is used with index access (dynamic)
      AstNode? parent = node.parent;

      // Skip if assigned to a fromJson call
      while (parent != null) {
        if (parent is MethodInvocation) {
          final String parentMethod = parent.methodName.name;
          if (parentMethod == 'fromJson' ||
              parentMethod == 'fromMap' ||
              parentMethod == 'parse' ||
              parentMethod == 'tryParse') {
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
              reporter.atNode(node);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  RequireConnectivityCheckRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_connectivity_check',
    '[require_connectivity_check] Network calls without connectivity check '
        'cause poor UX with long timeouts and unhelpful error messages. {v4}',
    correctionMessage: 'Use Connectivity package to check network status.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Check methods that do network operations
      final String methodName = node.name.lexeme.toLowerCase();
      // Use word-boundary-aware checks to avoid matching 'resync', 'async', etc.
      if (!methodName.startsWith('sync') &&
          !methodName.startsWith('upload') &&
          !methodName.startsWith('download') &&
          !methodName.startsWith('fetch') &&
          !methodName.startsWith('submit') &&
          !methodName.endsWith('sync') &&
          !methodName.endsWith('upload') &&
          !methodName.endsWith('download')) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP calls (specific client patterns only)
      if (!bodySource.contains('http.') &&
          !bodySource.contains('dio.') &&
          !bodySource.contains('client.post') &&
          !bodySource.contains('client.get')) {
        return;
      }

      // Check for connectivity check
      if (!bodySource.contains('Connectivity') &&
          !bodySource.contains('checkConnectivity') &&
          !bodySource.contains('isConnected') &&
          !bodySource.contains('hasConnection')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when API errors are not mapped to domain errors.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  RequireApiErrorMappingRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_api_error_mapping',
    '[require_api_error_mapping] Raw API exceptions are exposed to users, leaking implementation details and providing unhelpful error messages. This can confuse users and expose sensitive information such as server paths, stack traces, or internal status codes. Always catch specific exceptions and map them to domain errors with clear, actionable messages to protect against information disclosure and improve error recovery. {v4}',
    correctionMessage:
        'Catch specific exceptions (SocketException, TimeoutException, HttpException) and map each to a typed domain error with a user-facing message.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      final String trySource = node.body.toSource();

      // Check if try block contains API calls (specific client patterns only)
      if (!trySource.contains('http.') &&
          !trySource.contains('dio.') &&
          !trySource.contains('client.get') &&
          !trySource.contains('client.post')) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when HTTP requests don't specify a timeout.
///
/// Since: v1.4.3 | Updated: v4.13.0 | Rule version: v4
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
  RequireRequestTimeoutRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_request_timeout',
    '[require_request_timeout] HTTP request is missing a timeout configuration, which means it may hang indefinitely if the server does not respond. This can cause the app to freeze, degrade user experience, and waste socket connections and memory. Always add .timeout(Duration(seconds: 30)) or configure timeout in client options to ensure requests fail gracefully and users are informed of network issues. {v4}',
    correctionMessage:
        'Add .timeout(Duration(seconds: 30)) to the request or configure connectTimeout and receiveTimeout in your HTTP client options.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check HTTP methods
      if (!_httpMethods.contains(methodName)) return;

      // Check if target looks like an HTTP client
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();

      // cspell:ignore httpclient
      // Check if this is an HTTP-related call using exact target patterns
      final bool isHttpCall =
          targetSource == 'http' ||
          targetSource == 'dio' ||
          targetSource == 'client' ||
          targetSource.endsWith('.http') ||
          targetSource.endsWith('.dio') ||
          targetSource.endsWith('.client') ||
          targetSource == 'httpclient' ||
          targetSource.endsWith('.httpclient');

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

      reporter.atNode(node);
    });
  }
}

/// Warns when connectivity monitoring is used without an offline indicator.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireOfflineIndicatorRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_offline_indicator',
    '[require_offline_indicator] Connectivity is checked, but there is no offline indicator shown to users. Without a clear indicator, users may not understand why features are unavailable or why requests fail. Always show a banner, snackbar, or icon when connectivity is lost to improve transparency and user experience. {v4}',
    correctionMessage:
        'Show a visible offline indicator (banner, snackbar, or status icon) when connectivity is lost so users understand why features are unavailable.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
      final bool hasUiFeedback =
          callbackSource.contains('showSnackBar') ||
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
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v2
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
  PreferStreamingResponseRule() : super(code: _code);

  /// Large file downloads without streaming can cause OOM crashes.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_streaming_response',
    '[prefer_streaming_response] bodyBytes loads entire file into memory, '
        'causing OutOfMemoryError for large downloads. Stream to disk instead. {v2}',
    correctionMessage:
        'Use client.send() with StreamedResponse and pipe to file.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
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
        reporter.atNode(node);
      }
    });

    // Also check for dio's response.data in file context
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v4
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
  PreferHttpConnectionReuseRule() : super(code: _code);

  /// Performance issue - connection overhead adds latency.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_http_connection_reuse',
    '[prefer_http_connection_reuse] HTTP client created inside method. Connection overhead on every call. Each new HTTP client requires DNS lookup, TCP handshake, and TLS negotiation. Reusing connections is much more efficient. {v4}',
    correctionMessage:
        'Create HTTP client as a class field and reuse across requests. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
          reporter.atNode(node);
        }
      }
    });

    // Also check for inline Client() usage that isn't assigned to local variable
    // (The MethodDeclaration check above handles local variable + close pattern)
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          reporter.atNode(node);
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
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v5
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
  AvoidRedundantRequestsRule() : super(code: _code);

  /// Performance and resource waste.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_redundant_requests',
    '[avoid_redundant_requests] API call in build() or similar may cause redundant requests. Multiple widgets or methods requesting the same data simultaneously wastes bandwidth and server resources. Deduplicate concurrent requests. {v5}',
    correctionMessage:
        'Cache results or use request deduplication pattern. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
      final bool hasApiCall =
          bodySource.contains('http.get(') ||
          bodySource.contains('client.get(') ||
          bodySource.contains('dio.get(') ||
          bodySource.contains('.post(') ||
          bodySource.contains('.fetch(') ||
          bodySource.contains('http.') ||
          bodySource.contains('dio.');

      if (!hasApiCall) return;

      // Check for caching patterns
      final bool hasCaching =
          bodySource.contains('cache') ||
          bodySource.contains('Cache') ||
          bodySource.contains('_pending') ||
          bodySource.contains('putIfAbsent') ||
          bodySource.contains('memoize');

      if (!hasCaching) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when GET responses are not cached.
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v5
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
  RequireResponseCachingRule() : super(code: _code);

  /// Caching depends on data freshness requirements - may not be appropriate.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_response_caching',
    '[require_response_caching] GET request without caching. Static or rarely-changing data wastes bandwidth on every call. GET responses for static or slowly-changing data must be cached to reduce bandwidth usage and improve responsiveness. {v5}',
    correctionMessage:
        'Add response caching with a TTL header or local cache layer for data that changes infrequently to reduce network load.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
      final bool hasCaching =
          bodySource.contains('cache') ||
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when APIs return large collections without pagination.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v2
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
  PreferPaginationRule() : super(code: _code);

  /// Performance and memory usage.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_api_pagination',
    '[prefer_api_pagination] API fetches all items without pagination. May cause memory issues. Loading thousands of items at once is slow and memory-intensive. Use pagination with limit/offset or cursor-based pagination. {v2}',
    correctionMessage:
        'Add pagination parameters: limit, offset, page, or cursor. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
      final bool hasPagination =
          bodySource.contains('limit') ||
          bodySource.contains('offset') ||
          bodySource.contains('page') ||
          bodySource.contains('cursor') ||
          bodySource.contains('pageSize') ||
          bodySource.contains('perPage') ||
          node.parameters?.toSource().contains('limit') == true ||
          node.parameters?.toSource().contains('page') == true;

      if (!hasPagination) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when API responses fetch more data than needed.
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v5
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
  AvoidOverFetchingRule() : super(code: _code);

  /// Optimization depends on API design - may require backend changes.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_over_fetching',
    '[avoid_over_fetching] Fetching the full object but only using a few fields, wasting bandwidth and serialization time. This network pattern wastes bandwidth and server resources, increasing latency and data costs for users. {v5}',
    correctionMessage:
        'Use field selection, sparse fieldsets, or a dedicated endpoint to fetch only the fields this call-site actually uses.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This rule requires more sophisticated analysis
    // Detect patterns like: fetch full object, use 1-2 properties
    context.addMethodDeclaration((MethodDeclaration node) {
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
      final int propertyAccesses = RegExp(
        r'\.\w+(?!\()',
      ).allMatches(bodySource).length;
      final int apiCalls = RegExp(
        r'\.(get|fetch|post|query)\(',
      ).allMatches(bodySource).length;

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
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when async requests lack cancellation support.
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v4
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
  RequireCancelTokenRule() : super(code: _code);

  /// Resource management and avoiding errors.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_cancel_token',
    '[require_cancel_token] Async request without cancellation continues after a StatefulWidget disposes its State, wasting bandwidth and causing setState errors. Not canceling can lead to memory leaks, wasted network connections, and crashes from calling setState on a disposed State object after the parent removes the child from the widget tree. {v4}',
    correctionMessage:
        'Use CancelToken (Dio) or implement request cancellation in the State dispose() method to stop in-flight requests when the widget is removed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('State<')) return;

      final String classSource = node.toSource();

      // Check for HTTP calls
      final bool hasHttpCalls =
          classSource.contains('.get(') ||
          classSource.contains('.post(') ||
          classSource.contains('.fetch(') ||
          classSource.contains('http.') ||
          classSource.contains('dio.');

      if (!hasHttpCalls) return;

      // Check for cancellation patterns
      final bool hasCancellation =
          classSource.contains('CancelToken') ||
          classSource.contains('cancelToken') ||
          classSource.contains('_cancelled') || // US spelling
          classSource.contains('isCancelled') || // US spelling
          classSource.contains('_canceled') || // UK spelling
          classSource.contains('isCanceled') || // UK spelling
          classSource.contains('cancel()');

      // Check for mounted check (partial mitigation)
      final bool hasMountedCheck =
          classSource.contains('if (mounted)') ||
          classSource.contains('if (!mounted)');

      if (!hasCancellation && !hasMountedCheck) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when WebSocket listeners don't have error handlers.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
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
  RequireWebSocketErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_websocket_error_handling',
    '[require_websocket_error_handling] WebSocket stream.listen() is missing an onError handler. Unhandled errors can crash your app, disconnect users, and make debugging network issues difficult. All WebSocket listeners must handle errors to ensure robust, production-quality networking. {v3}',
    correctionMessage:
        'Always provide an onError handler to WebSocket stream.listen(). Log errors, show user feedback, and attempt reconnection if appropriate. Audit your codebase for missing error handlers and add tests for network failure scenarios.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when HTTP response is parsed without Content-Type check.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireContentTypeCheckRule() : super(code: _code);

  /// Reliability issue - parsing may fail unexpectedly.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_content_type_check',
    '[require_content_type_check] Parsing response without Content-Type check. May fail on error responses. APIs may return different content types on error. Parsing JSON without checking Content-Type may fail unexpectedly. {v4}',
    correctionMessage:
        'Check the Content-Type header before parsing the response body. APIs may return HTML error pages or plain text instead of JSON on failure, causing parse exceptions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when WebSocket is used without heartbeat/ping mechanism.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
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
  AvoidWebsocketWithoutHeartbeatRule() : super(code: _code);

  /// Reliability issue - dead connections go undetected.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_websocket_without_heartbeat',
    '[avoid_websocket_without_heartbeat] WebSocket without heartbeat/ping. Dead connections won\'t be detected. WebSocket connections can silently fail. Periodic pings help detect dead connections and keep firewalls from closing idle sockets. {v3}',
    correctionMessage:
        'Add periodic ping messages to detect connection failures. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// Part 7: URL Launcher Rules
// =============================================================================

/// Warns when launchUrl is called without try-catch error handling.
///
/// Since: v4.5.5 | Updated: v4.13.0 | Rule version: v2
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
  RequireUrlLauncherErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_url_launcher_error_handling',
    '[require_url_launcher_error_handling] Calling launchUrl without error handling can cause your app to crash or leave users stranded if the URL cannot be opened (e.g., missing browser, invalid URL, or platform restrictions). This results in a poor user experience and can break critical app flows. {v2}',
    correctionMessage:
        'Always check canLaunchUrl before calling launchUrl, and wrap the call in a try-catch block to handle errors gracefully. Provide user feedback if the URL cannot be opened.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v4.5.5 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: image_picker_no_error_handling, pick_image_crash
///
/// pickImage returns null if user cancels and can throw on permission denied.
///
/// **BAD:**
/// ```dart
/// final image = await picker.pickImage(source: ImageSource.camera);
/// File file = File(image!.path);  // Crash if canceled!
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final image = await picker.pickImage(source: ImageSource.camera);
///   if (image == null) return;  // User canceled
///   File file = File(image.path);
/// } catch (e) {
///   // Handle permission error
/// }
/// ```
class RequireImagePickerErrorHandlingRule extends SaropaLintRule {
  RequireImagePickerErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_image_picker_error_handling',
    '[require_image_picker_error_handling] Using pickImage, pickVideo, or pickMultiImage without null checks or error handling can result in null dereference errors or unhandled exceptions if the user cancels the picker or a platform error occurs. This can crash your app or cause unpredictable UI states. {v2}',
    correctionMessage:
        'Always check for null results and wrap picker calls in try-catch blocks. Provide user feedback for cancellations and handle errors to prevent crashes.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v4.13.0 | Rule version: v1
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
  RequireImagePickerSourceChoiceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_image_picker_source_choice',
    '[require_image_picker_source_choice] Hardcoded ImageSource. Prefer offering user a choice. Users must be able to choose between camera and gallery. {v1}',
    correctionMessage:
        'Show dialog letting user choose camera or gallery. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireGeolocatorTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_geolocator_timeout',
    '[require_geolocator_timeout] Calling getCurrentPosition without a timeLimit can cause the request to hang indefinitely if the device cannot acquire a location fix (e.g., poor GPS signal, airplane mode). This can freeze your UI and frustrate users. {v3}',
    correctionMessage:
        'Always set the timeLimit parameter (e.g., Duration(seconds: 10)) to ensure location requests fail gracefully and your app remains responsive.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

/// Warns when connectivity subscription isn't canceled.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: connectivity_leak, connectivity_no_cancel
///
/// Connectivity subscriptions must be canceled to prevent memory leaks.
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
  RequireConnectivitySubscriptionCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_connectivity_subscription_cancel',
    '[require_connectivity_subscription_cancel] If you do not cancel your connectivity subscription, your app will leak memory and system resources. This can cause crashes, slowdowns, and unpredictable behavior, especially after repeated hot reloads or navigation. {v3}',
    correctionMessage:
        'Always store your connectivity subscription and call cancel() in dispose() to prevent memory leaks and keep your app stable.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireNotificationHandlerTopLevelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_notification_handler_top_level',
    '[require_notification_handler_top_level] If your notification handler is not a top-level function, background messages will be silently dropped when the app is terminated or in the background. Users will miss important notifications and your app may fail compliance checks. {v3}',
    correctionMessage:
        'Move your notification handler to a top-level function and annotate it with @pragma("vm:entry-point") to ensure background messages are always delivered.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(handler);
      } else if (handler is PropertyAccess) {
        // e.g., this.handleBackground or obj.method
        reporter.atNode(handler);
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
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v4
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
  RequirePermissionDeniedHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_permission_denied_handling',
    '[require_permission_denied_handling] Requesting permissions without handling denied or permanently denied states leaves users unable to proceed, with no explanation or way to enable permissions. This can block critical app features and frustrate users. {v4}',
    correctionMessage:
        'Check for isDenied and isPermanentlyDenied states after requesting permissions. Show clear explanations and provide a link to app settings if needed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireImagePickerResultHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_image_picker_result_handling',
    '[require_image_picker_result_handling] pickImage returns null when '
        'user cancels. Missing null check causes NoSuchMethodError crash. {v2}',
    correctionMessage: 'Add null check: if (image == null) return;',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when CachedNetworkImage uses a variable cacheKey in build.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidCachedImageInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_cached_image_in_build',
    '[avoid_cached_image_in_build] Variable cacheKey in build method defeats caching. Using a changing cacheKey in build causes the image to reload on every rebuild, defeating the purpose of caching. {v2}',
    correctionMessage:
        'Use a stable cacheKey that does not change on rebuild. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
            reporter.atNode(arg);
          }
        }
      }
    });
  }
}

/// Warns when SQLite onUpgrade doesn't check oldVersion properly.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireSqfliteMigrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_sqflite_migration',
    '[require_sqflite_migration] Implementing onUpgrade without checking oldVersion can cause all migrations to run for every upgrade, corrupting user data and breaking app updates. This is especially dangerous for users upgrading from recent versions. {v4}',
    correctionMessage:
        'Always check oldVersion and newVersion in onUpgrade, and only run migrations needed for the user’s upgrade path. Test migrations thoroughly before release.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
      // Check if this is an onUpgrade callback (has oldVersion parameter)
      final params = node.parameters;
      if (params == null) return;

      final paramNames = params.parameters
          .map((p) => p.name?.lexeme ?? '')
          .toList();
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
            reporter.atNode(node);
            return;
          }
        }
        if (current is NamedExpression) {
          final name = current.name.label.name.toLowerCase();
          if (name.contains('onupgrade') || name.contains('on_upgrade')) {
            reporter.atNode(node);
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
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
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
  RequirePermissionRationaleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_permission_rationale',
    '[require_permission_rationale] Permission request without checking shouldShowRequestRationale. Android established convention is to explain why the app needs a permission before requesting it using shouldShowRequestRationale. {v3}',
    correctionMessage:
        'Check shouldShowRequestRationale() before requesting permission. Test with slow and interrupted connections to verify network resilience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when using permission-gated features without checking status.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v4
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
  RequirePermissionStatusCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_permission_status_check',
    '[require_permission_status_check] Accessing camera, location, or other gated features without checking permission status can cause runtime exceptions or crashes if the user has denied permission. This can break critical app flows and frustrate users. {v4}',
    correctionMessage:
        'Always check permission.status.isGranted before accessing gated features. Handle denied permissions gracefully and inform the user.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when showing notifications without Android 13+ permission check.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireNotificationPermissionAndroid13Rule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_notification_permission_android13',
    '[require_notification_permission_android13] Notification displayed without checking POST_NOTIFICATIONS permission on Android 13+. On API level 33 and above, notifications fail silently without this runtime permission, causing users to miss critical alerts, messages, and updates with no error feedback to the developer or the user. {v3}',
    correctionMessage:
        'Check and request Permission.notification at runtime before calling any notification display method on Android 13+ (API 33+) devices.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// Server-Sent Events (SSE) Subscription Rules
// =============================================================================

/// Warns when EventSource/SSE connection is created without close() cleanup.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v4
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
  RequireSseSubscriptionCancelRule() : super(code: _code);

  /// SSE connections are long-lived and must be properly closed.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_sse_subscription_cancel',
    '[require_sse_subscription_cancel] If a widget (such as a StatefulWidget managing a live data feed) opens a Server-Sent Events (SSE) or EventSource connection but does not cancel it in dispose(), the connection remains open after the widget is removed. This can result in orphaned network connections, wasted bandwidth, and memory leaks, especially in dashboards, chat clients, or any UI with dynamic SSE usage. Always close SSE/EventSource connections in the correct State object’s dispose() method. See https://docs.flutter.dev/perf/memory#dispose-resources. {v4}',
    correctionMessage:
        'In every State class that owns an SSE or EventSource connection, call connection.close() in the dispose() method before calling super.dispose(). This ensures the connection is properly terminated when the widget is removed, preventing leaks and network resource exhaustion. See https://docs.flutter.dev/perf/memory#dispose-resources for more details.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        final bool isClosed =
            disposeBody != null &&
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
                  reporter.atNode(variable);
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
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v3
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
  PreferTimeoutOnRequestsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_timeout_on_requests',
    '[prefer_timeout_on_requests] Making HTTP requests without a timeout can cause your app to hang indefinitely if the server is slow or unresponsive. This degrades user experience and can block critical app flows. {v3}',
    correctionMessage:
        'Always set a timeout on HTTP requests (e.g., .timeout(Duration(seconds: 30))) or configure a client-wide timeout to ensure your app remains responsive.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

/// Quick fix: adds `.timeout(const Duration(seconds: 30))` to HTTP requests.

/// Quick fix: adds `.timeout(const Duration(seconds: 60))` for slower APIs.

// =============================================================================
// WebSocket Rules (from v4.1.7)
// =============================================================================

/// Warns when WebSocket connections lack reconnection logic.
///
/// Since: v4.1.8 | Updated: v4.14.2 | Rule version: v4
///
/// `[HEURISTIC]` - Detects WebSocketChannel without reconnection handling.
///
/// WebSocket connections drop unexpectedly. Implement automatic reconnection
/// with exponential backoff.
///
/// **BAD:**
/// ```dart
/// class ChatService {
///   late WebSocketChannel _channel;
///
///   void connect() {
///     _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
///     // No reconnection logic - connection lost forever on disconnect!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class ChatService {
///   WebSocketChannel? _channel;
///   int _retryCount = 0;
///
///   void connect() {
///     _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
///     _channel!.stream.listen(
///       onMessage,
///       onDone: _reconnect, // Handle disconnection
///       onError: (e) => _reconnect(),
///     );
///   }
///
///   void _reconnect() {
///     final delay = Duration(seconds: pow(2, _retryCount++).toInt());
///     Future.delayed(delay, connect);
///   }
/// }
/// ```
class RequireWebsocketReconnectionRule extends SaropaLintRule {
  RequireWebsocketReconnectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_websocket_reconnection',
    '[require_websocket_reconnection] WebSocket connection without reconnection logic will stay permanently disconnected after network interruptions, server restarts, or mobile network handoffs. Users will see stale data, miss real-time updates, and have no indication that the live connection has dropped until they manually refresh or restart the app. {v4}',
    correctionMessage:
        'Implement automatic reconnection with exponential backoff for WebSocket connections.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Skip WebSocket class definitions — only check classes that USE
      // WebSocket, not classes that ARE WebSocket stubs/mocks.
      if (className == 'WebSocketChannel' || className == 'WebSocket') return;

      final String classSource = node.toSource();

      // Check if class uses WebSocket
      if (!classSource.contains('WebSocketChannel') &&
          !classSource.contains('WebSocket')) {
        return;
      }

      // Check for reconnection logic indicators
      final bool hasReconnection =
          classSource.contains('reconnect') ||
          classSource.contains('retry') ||
          classSource.contains('onDone:') ||
          classSource.contains('onError:') ||
          classSource.contains('backoff');

      if (!hasReconnection) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when analytics event names do not follow snake_case convention.
///
/// Since: v4.14.0 | Rule version: v1
///
/// GitHub: https://github.com/saropa/saropa_lints/issues/19
///
/// `[HEURISTIC]` - Detects calls to known analytics methods and checks
/// the first string literal argument against a strict snake_case pattern.
///
/// **BAD:**
/// ```dart
/// analytics.logEvent(name: 'UserSignedUp');
/// ```
///
/// **GOOD:**
/// ```dart
/// analytics.logEvent(name: 'user_signed_up');
/// ```
class RequireAnalyticsEventNamingRule extends SaropaLintRule {
  RequireAnalyticsEventNamingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_analytics_event_naming',
    '[require_analytics_event_naming] Analytics event name does not '
        'follow snake_case convention. Inconsistent naming fragments '
        'dashboards, breaks funnel queries, and makes cross-platform '
        'analysis unreliable. Most analytics platforms recommend or '
        'require snake_case for event names. {v1}',
    correctionMessage:
        'Rename the event to snake_case (e.g., "user_signed_up" '
        'instead of "UserSignedUp" or "user-signed-up").',
    severity: DiagnosticSeverity.INFO,
  );

  /// Unambiguous analytics method names - always trigger without
  /// receiver filtering since they are specific to analytics APIs.
  static const Set<String> _unambiguousMethods = <String>{
    'logEvent',
    'trackEvent',
    'logCustomEvent',
  };

  /// Ambiguous method names that appear in non-analytics contexts.
  /// Require an analytics-like receiver to avoid false positives
  /// (e.g., shipment.track(), stateMachine.sendEvent()).
  static const Set<String> _ambiguousMethods = <String>{'track', 'sendEvent'};

  /// Receivers that indicate an analytics context.
  static final RegExp _analyticsTargetPattern = RegExp(
    r'(analytics|tracker|segment|mixpanel|amplitude|firebase|appFlyer|braze|clevertap|appsFlyer|posthog)',
    caseSensitive: false,
  );

  static final RegExp _snakeCasePattern = RegExp(
    r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_ambiguousMethods.contains(methodName)) {
        // Require an analytics-like receiver
        final Expression? target = node.target;
        if (target == null) return;
        if (!_analyticsTargetPattern.hasMatch(target.toSource())) return;
      } else if (!_unambiguousMethods.contains(methodName)) {
        return;
      }

      final String? eventName = _extractEventName(node);
      if (eventName == null || eventName.isEmpty) return;
      if (!_snakeCasePattern.hasMatch(eventName)) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  static String? _extractEventName(MethodInvocation node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'name') {
        final Expression value = arg.expression;
        if (value is StringLiteral) return value.stringValue;
        return null;
      }
    }
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is! NamedExpression && arg is StringLiteral) {
        return arg.stringValue;
      }
    }
    return null;
  }
}
