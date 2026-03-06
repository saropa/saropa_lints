// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// API and network lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper API usage patterns, network error
/// handling, and resilient communication with backend services.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

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

  static const Set<String> _httpPackagePrefixes = <String>{
    'package:http/',
    'package:dio/',
  };

  static final List<RegExp> _httpCallPatterns = [
    RegExp(r'\bhttp\.get\s*\('),
    RegExp(r'\bhttp\.post\s*\('),
    RegExp(r'\bhttp\.put\s*\('),
    RegExp(r'\bhttp\.delete\s*\('),
    RegExp(r'\bdio\.get\s*\('),
    RegExp(r'\bdio\.post\s*\('),
    RegExp(r'\bclient\.get\s*\('),
    RegExp(r'\bclient\.post\s*\('),
  ];
  static final List<RegExp> _statusCheckPatterns = [
    RegExp(r'\bstatusCode\b'),
    RegExp(r'\bisSuccessful\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Only run in files that use HTTP client (avoids FP on Map.get, GetIt.get, etc.)
      if (!fileImportsPackage(node, _httpPackagePrefixes)) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HTTP calls (word-boundary regex to avoid FP on myhttp.get, dio.getSomething)
      final hasHttpCall = _httpCallPatterns.any((p) => p.hasMatch(bodySource));
      if (!hasHttpCall) return;

      // Check if statusCode is checked (word-boundary to avoid FP on myStatusCode)
      final hasStatusCheck = _statusCheckPatterns.any(
        (p) => p.hasMatch(bodySource),
      );
      if (!hasStatusCheck) reporter.atNode(node);
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

  static final List<RegExp> _httpCallPatternsRetry = [
    RegExp(r'\bhttp\.'),
    RegExp(r'\bdio\.'),
    RegExp(r'\bclient\.get\s*\('),
    RegExp(r'\bclient\.post\s*\('),
  ];
  static final List<RegExp> _retryPatterns = [
    RegExp(r'\bretry\b'),
    RegExp(r'\bRetry\b'),
    RegExp(r'\bmaxRetries\b'),
  ];

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

      // Check for HTTP calls (word-boundary to avoid FP)
      if (!_httpCallPatternsRetry.any((p) => p.hasMatch(bodySource))) {
        return;
      }

      // Check for retry logic
      if (!_retryPatterns.any((p) => p.hasMatch(bodySource))) {
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
      String? variableName;
      String? bodySource;
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
          variableName = parent.name.lexeme;
          final AstNode? methodBody = _findMethodBody(parent);
          bodySource = methodBody?.toSource();
          break;
        }
        parent = parent.parent;
      }
      if (variableName != null && bodySource != null) {
        final dynamicAccessPattern = RegExp(
          '${RegExp.escape(variableName)}\\s*\\[\\s*[\'"]',
        );
        if (dynamicAccessPattern.hasMatch(bodySource)) {
          reporter.atNode(node);
        }
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

  static final List<RegExp> _connectivityHttpPatterns = [
    RegExp(r'\bhttp\.'),
    RegExp(r'\bdio\.'),
    RegExp(r'\bclient\.post\s*\('),
    RegExp(r'\bclient\.get\s*\('),
  ];
  static final List<RegExp> _connectivityCheckPatterns = [
    RegExp(r'\bConnectivity\b'),
    RegExp(r'\bcheckConnectivity\b'),
    RegExp(r'\bisConnected\b'),
    RegExp(r'\bhasConnection\b'),
  ];

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

      // Check for HTTP calls (word-boundary to avoid FP)
      if (!_connectivityHttpPatterns.any((p) => p.hasMatch(bodySource))) {
        return;
      }

      // Check for connectivity check
      if (!_connectivityCheckPatterns.any((p) => p.hasMatch(bodySource))) {
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
    // Not HTTP: we only inspect try-block source for client.get/http./dio.
    // Presence of statusCode satisfies require_http_status_check (no real HTTP here).
    final int? statusCode = null; // ignore: unused_local_variable
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
  static final List<RegExp> _timeoutConfigPatterns = [
    RegExp(r'\bconnectTimeout\b'),
    RegExp(r'\breceiveTimeout\b'),
    RegExp(r'\bsendTimeout\b'),
    RegExp(r'\bBaseOptions\b'),
  ];

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
      // (e.g., Dio with connectTimeout in options; word-boundary to avoid FP)
      AstNode? current = node.parent;
      int depth = 0;
      while (current != null && depth < 10) {
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          final String bodySource = current.toSource();
          if (_timeoutConfigPatterns.any((p) => p.hasMatch(bodySource))) {
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

  static final List<RegExp> _connectivityTargetPatterns = [
    RegExp(r'\bonConnectivityChanged\b'),
    RegExp(r'\bconnectivityStream\b'),
  ];
  static final List<RegExp> _uiFeedbackPatterns = [
    RegExp(r'\bshowSnackBar\b'),
    RegExp(r'\bshowDialog\b'),
    RegExp(r'\bBanner\b'),
    RegExp(r'\bOverlay\b'),
    RegExp(r'\bshowToast\b'),
    RegExp(r'\bshowNotification\b'),
    RegExp(r'\bofflineWidget\b'),
    RegExp(r'\bOfflineBuilder\b'),
    RegExp(r'\bNoInternetWidget\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'listen') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!_connectivityTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      if (node.argumentList.arguments.isEmpty) return;

      final Expression callback = node.argumentList.arguments.first;
      final String callbackSource = callback.toSource();

      if (!_uiFeedbackPatterns.any((p) => p.hasMatch(callbackSource))) {
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

  static final List<RegExp> _responseTargetPatterns = [
    RegExp(r'\bresponse\b'),
    RegExp(r'\bhttp\b'),
    RegExp(r'\bdio\b'),
  ];
  static final List<RegExp> _fileContextPatterns = [
    RegExp(r'\bwriteAsBytes\b'),
    RegExp(r'\bwriteAsBytesSync\b'),
    RegExp(r'\.pdf\b'),
    RegExp(r'\.zip\b'),
    RegExp(r'\.mp4\b'),
    RegExp(r'\.mp3\b'),
    RegExp(r'\.png\b'),
    RegExp(r'\.jpg\b'),
    RegExp(r'\.jpeg\b'),
    RegExp(r'\bdownload\b'),
    RegExp(r'\bDownload\b'),
    RegExp(r'\bfile\b'),
  ];
  static final List<RegExp> _fileOpPatterns = [
    RegExp(r'\bwriteAsBytes\b'),
    RegExp(r'\bFile\s*\('),
    RegExp(r'\bsavePath\b'),
  ];
  static final RegExp _responseTypeStreamPattern = RegExp(
    r'\bResponseType\.stream\b',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;

      if (propertyName != 'bodyBytes' && propertyName != 'body') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_responseTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      AstNode? current = node.parent;
      int depth = 0;
      bool isFileContext = false;

      while (current != null && depth < 10) {
        final String source = current.toSource();
        if (_fileContextPatterns.any((p) => p.hasMatch(source))) {
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

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'get' && methodName != 'download') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!RegExp(r'\bdio\b').hasMatch(targetSource) &&
          !RegExp(r'\bhttp\b').hasMatch(targetSource)) {
        return;
      }

      final String nodeSource = node.toSource();
      if (_responseTypeStreamPattern.hasMatch(nodeSource) ||
          RegExp(r'responseType:\s*ResponseType\.bytes').hasMatch(nodeSource)) {
        return;
      }

      if (RegExp(r'\.pdf\b').hasMatch(nodeSource) ||
          RegExp(r'\.zip\b').hasMatch(nodeSource) ||
          RegExp(r'\.mp4\b').hasMatch(nodeSource) ||
          RegExp(r'\bdownload\b').hasMatch(nodeSource)) {
        AstNode? current = node.parent;
        int depth = 0;

        while (current != null && depth < 5) {
          final String source = current.toSource();
          if (_fileOpPatterns.any((p) => p.hasMatch(source))) {
            if (!_responseTypeStreamPattern.hasMatch(nodeSource)) {
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

  static final List<RegExp> _clientCreationPatterns = [
    RegExp(r'\bhttp\.Client\s*\(\s*\)'),
    RegExp(r'\bClient\s*\(\s*\)'),
    RegExp(r'\bDio\s*\(\s*\)'),
  ];
  static final List<RegExp> _clientLocalVarPatterns = [
    RegExp(r'\bfinal\s+client\s*='),
    RegExp(r'\bvar\s+client\s*='),
    RegExp(r'\bfinal\s+dio\s*='),
    RegExp(r'\bvar\s+dio\s*='),
  ];
  static final RegExp _closeCallPattern = RegExp(r'\.close\s*\(\s*\)');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for client creation inside method (word-boundary to avoid FP)
      if (!_clientCreationPatterns.any((p) => p.hasMatch(bodySource))) {
        return;
      }

      // Check if client is created as local variable (not returned)
      if (_clientLocalVarPatterns.any((p) => p.hasMatch(bodySource)) &&
          _closeCallPattern.hasMatch(bodySource)) {
        reporter.atNode(node);
      }
    });

    // Also check for inline Client() usage that isn't assigned to local variable
    // (The MethodDeclaration check above handles local variable + close pattern)
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

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

  static final List<RegExp> _buildMethodApiPatterns = [
    RegExp(r'\bhttp\.get\s*\('),
    RegExp(r'\bclient\.get\s*\('),
    RegExp(r'\bdio\.get\s*\('),
    RegExp(r'\.post\s*\('),
    RegExp(r'\.fetch\s*\('),
    RegExp(r'\bhttp\.'),
    RegExp(r'\bdio\.'),
  ];
  static final List<RegExp> _buildMethodCachingPatterns = [
    RegExp(r'\bcache\b'),
    RegExp(r'\bCache\b'),
    RegExp(r'\b_pending\b'),
    RegExp(r'\bputIfAbsent\b'),
    RegExp(r'\bmemoize\b'),
  ];

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

      final bool hasApiCall = _buildMethodApiPatterns.any(
        (p) => p.hasMatch(bodySource),
      );
      if (!hasApiCall) return;

      final bool hasCaching = _buildMethodCachingPatterns.any(
        (p) => p.hasMatch(bodySource),
      );
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

  static final List<RegExp> _getRequestPatterns = [
    RegExp(r'\.get\s*\('),
    RegExp(r'\bhttp\.get\s*\('),
  ];
  static final List<RegExp> _responseCachingPatterns = [
    RegExp(r'\bcache\b'),
    RegExp(r'\bCache\b'),
    RegExp(r'\b_cached\b'),
    RegExp(r'\bcached\b'),
    RegExp(r'\bttl\b'),
    RegExp(r'\bTTL\b'),
    RegExp(r'\bDuration\b'),
  ];
  static final List<RegExp> _classCachePatterns = [
    RegExp(r'\b_cache\b'),
    RegExp(r'\bCache\b'),
    RegExp(r'\b_cached\b'),
  ];
  static final List<RegExp> _configOrSettingsMethodPatterns = [
    RegExp(r'\bconfig\b'),
    RegExp(r'\bsettings\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      if (!methodName.startsWith('get') &&
          !methodName.startsWith('fetch') &&
          !methodName.startsWith('load') &&
          !_configOrSettingsMethodPatterns.any((p) => p.hasMatch(methodName))) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      if (!_getRequestPatterns.any((p) => p.hasMatch(bodySource))) return;

      final bool hasCaching = _responseCachingPatterns.any(
        (p) => p.hasMatch(bodySource),
      );

      final AstNode? parent = node.parent;
      if (parent is ClassDeclaration) {
        final String classSource = parent.toSource();
        if (_classCachePatterns.any((p) => p.hasMatch(classSource))) {
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

  static final List<RegExp> _paginationApiPatterns = [
    RegExp(r'\.get\s*\('),
    RegExp(r'\bhttp\.'),
    RegExp(r'\bdio\.'),
  ];
  static final List<RegExp> _paginationParamPatterns = [
    RegExp(r'\blimit\b'),
    RegExp(r'\boffset\b'),
    RegExp(r'\bpage\b'),
    RegExp(r'\bcursor\b'),
    RegExp(r'\bpageSize\b'),
    RegExp(r'\bperPage\b'),
  ];
  static final RegExp _paginationAllPattern = RegExp(r'\ball\b');
  static final RegExp _listOrIterableReturnPattern = RegExp(
    r'List\s*<|Iterable\s*<',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      if (!_paginationAllPattern.hasMatch(methodName) &&
          !methodName.startsWith('get') &&
          !methodName.startsWith('fetch') &&
          !methodName.startsWith('list') &&
          !methodName.startsWith('load')) {
        return;
      }

      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;
      final String returnTypeStr = returnType.toSource();
      if (!_listOrIterableReturnPattern.hasMatch(returnTypeStr)) {
        return;
      }

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      if (!_paginationApiPatterns.any((p) => p.hasMatch(bodySource))) return;

      final String paramsSource = node.parameters?.toSource() ?? '';
      final bool hasPagination =
          _paginationParamPatterns.any((p) => p.hasMatch(bodySource)) ||
          _paginationParamPatterns.any((p) => p.hasMatch(paramsSource));

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

      if (apiCalls > 0 && propertyAccesses <= 3 && bodySource.length < 500) {
        // Additional heuristic: check for .name, .id, .title only (word-boundary)
        if (RegExp(r'\.(name|title|id)\b').hasMatch(bodySource)) {
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

  static final List<RegExp> _cancelTokenHttpPatterns = [
    RegExp(r'\.get\s*\('),
    RegExp(r'\.post\s*\('),
    RegExp(r'\.fetch\s*\('),
    RegExp(r'\bhttp\.'),
    RegExp(r'\bdio\.'),
  ];
  static final List<RegExp> _cancelTokenCancellationPatterns = [
    RegExp(r'\bCancelToken\b'),
    RegExp(r'\bcancelToken\b'),
    RegExp(r'\b_cancelled\b'),
    RegExp(r'\bisCancelled\b'),
    RegExp(r'\b_canceled\b'),
    RegExp(r'\bisCanceled\b'),
    RegExp(r'\.cancel\s*\(\s*\)'),
  ];
  static final List<RegExp> _cancelTokenMountedPatterns = [
    RegExp(r'\bif\s*\(\s*mounted\s*\)'),
    RegExp(r'\bif\s*\(\s*!mounted\s*\)'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('State<')) return;

      final String classSource = node.toSource();

      final bool hasHttpCalls = _cancelTokenHttpPatterns.any(
        (p) => p.hasMatch(classSource),
      );
      if (!hasHttpCalls) return;

      final bool hasCancellation = _cancelTokenCancellationPatterns.any(
        (p) => p.hasMatch(classSource),
      );
      final bool hasMountedCheck = _cancelTokenMountedPatterns.any(
        (p) => p.hasMatch(classSource),
      );

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

  static final List<RegExp> _websocketListenTargetPatterns = [
    RegExp(r'\bsocket\b'),
    RegExp(r'\bSocket\b'),
    RegExp(r'\bchannel\b'),
    RegExp(r'\bChannel\b'),
    RegExp(r'\.stream\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!_websocketListenTargetPatterns.any(
        (p) => p.hasMatch(targetSource),
      )) {
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

  static final List<RegExp> _heartbeatClassPatterns = [
    RegExp(r'\bping\b'),
    RegExp(r'\bheartbeat\b'),
    RegExp(r'\bkeepalive\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      final target = node.target;
      if (target is! SimpleIdentifier) {
        return;
      }

      if (!RegExp(r'WebSocket').hasMatch(target.name)) {
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

      if (_heartbeatClassPatterns.any((p) => p.hasMatch(classSource)) ||
          (RegExp(r'\btimer\.periodic\b').hasMatch(classSource) &&
              RegExp(r'\bsink\.add\b').hasMatch(classSource))) {
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

  static final List<RegExp> _nullCheckInContextPatterns = [
    RegExp(r'==\s*null'),
    RegExp(r'!=\s*null'),
    RegExp(r'\?'),
  ];
  static final List<RegExp> _nullCheckStmtPatterns = [
    RegExp(r'==\s*null'),
    RegExp(r'!=\s*null'),
  ];

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
          if (_nullCheckInContextPatterns.any((p) => p.hasMatch(source))) {
            return;
          }
        }
        if (parent is VariableDeclaration) {
          AstNode? stmt = parent.parent?.parent;
          if (stmt is VariableDeclarationStatement) {
            AstNode? nextNode = stmt.parent;
            if (nextNode is Block) {
              final statements = nextNode.statements;
              final stmtIndex = statements.indexOf(stmt);
              if (stmtIndex >= 0 && stmtIndex < statements.length - 1) {
                final nextSource = statements[stmtIndex + 1].toSource();
                if (_nullCheckStmtPatterns.any((p) => p.hasMatch(nextSource))) {
                  return;
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
      final typeName = node.constructorName.type.name.lexeme;
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

      final bodySource = node.body.toSource();
      if (RegExp(r'oldVersion\s*[<>=]').hasMatch(bodySource)) {
        return;
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

  static final RegExp _permissionTypeOrSource = RegExp(r'Permission');
  static final RegExp _permissionSourceLower = RegExp(r'\bpermission\b');
  static final List<RegExp> _rationaleBodyPatterns = [
    RegExp(r'shouldshowrequestrationale'),
    RegExp(r'shouldshowrationale'),
  ];
  static final RegExp _rationaleShow = RegExp(r'\bshow\b');
  static final RegExp _rationaleWord = RegExp(r'\brationale\b');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;

      if (methodName != 'request' && methodName != 'requestPermission') {
        return;
      }

      final target = node.target;
      if (target == null) return;

      final targetType = target.staticType?.toString() ?? '';
      final targetSource = target.toSource().toLowerCase();
      if (!_permissionTypeOrSource.hasMatch(targetType) &&
          !_permissionSourceLower.hasMatch(targetSource)) {
        return;
      }

      final methodDeclaration = node.thisOrAncestorOfType<MethodDeclaration>();
      if (methodDeclaration == null) return;

      final bodySource = methodDeclaration.body.toSource().toLowerCase();
      if (_rationaleBodyPatterns.any((p) => p.hasMatch(bodySource)) ||
          (_rationaleShow.hasMatch(bodySource) &&
              _rationaleWord.hasMatch(bodySource))) {
        return;
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

  static final List<RegExp> _permissionCheckBodyPatterns = [
    RegExp(r'\bisgranted\b'),
    RegExp(r'\bis_granted\b'),
    RegExp(r'permissionstatus\.granted'),
    RegExp(r'status\s*==\s*permissionstatus\.granted'),
    RegExp(r'\.request\s*\(\s*\)'),
    RegExp(r'\bhaspermission\b'),
    RegExp(r'\bcheckpermission\b'),
  ];

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

      if (_permissionCheckBodyPatterns.any((p) => p.hasMatch(bodySource))) {
        return;
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

  static final RegExp _notificationTypeOrTarget = RegExp(
    r'notification|local_notifications|flutterlocalnoti',
    caseSensitive: false,
  );
  static final List<RegExp> _notificationPermissionBodyPatterns = [
    RegExp(r'permission\.notification'),
    RegExp(r'post_notifications'),
    RegExp(r'notificationpermission'),
    RegExp(r'notification_permission'),
    RegExp(r'requestnotificationpermission'),
  ];
  static final List<RegExp> _notificationPermissionClassPatterns = [
    RegExp(r'permission\.notification'),
    RegExp(r'notificationpermission'),
  ];

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

      final target = node.target;
      if (target == null) return;

      final targetType = target.staticType?.toString().toLowerCase() ?? '';
      final targetSource = target.toSource().toLowerCase();
      if (!_notificationTypeOrTarget.hasMatch(targetType) &&
          !_notificationTypeOrTarget.hasMatch(targetSource)) {
        return;
      }

      final methodDeclaration = node.thisOrAncestorOfType<MethodDeclaration>();
      if (methodDeclaration == null) return;

      final bodySource = methodDeclaration.body.toSource().toLowerCase();
      if (_notificationPermissionBodyPatterns.any(
        (p) => p.hasMatch(bodySource),
      )) {
        return;
      }

      final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl != null) {
        final classSource = classDecl.toSource().toLowerCase();
        if (_notificationPermissionClassPatterns.any(
          (p) => p.hasMatch(classSource),
        )) {
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

  static final Map<String, RegExp> _sseTypePatterns = {
    for (final String s in _sseTypes)
      s: RegExp('\\b${RegExp.escape(s)}\\b', caseSensitive: false),
  };
  static final RegExp _sseNamePattern = RegExp(r'(^|_)sse($|_|[A-Z])');

  static bool _sseFieldClosePattern(
    String body,
    String fieldName,
    String method,
  ) {
    return RegExp(
      '${RegExp.escape(fieldName)}\\s*[?.]\\s*$method\\s*\\(',
    ).hasMatch(body);
  }

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

            if (typeName != null) {
              for (final String sseType in _sseTypes) {
                final pattern = _sseTypePatterns[sseType];
                if (pattern != null && pattern.hasMatch(typeName)) {
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
              if (fieldNameLower.contains('eventsource') ||
                  fieldNameLower.contains('event_source') ||
                  _sseNamePattern.hasMatch(fieldNameOriginal) ||
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

      for (final String fieldName in sseFields) {
        final bool isClosed =
            disposeBody != null &&
            (_sseFieldClosePattern(disposeBody, fieldName, 'close') ||
                _sseFieldClosePattern(disposeBody, fieldName, 'dispose') ||
                _sseFieldClosePattern(disposeBody, fieldName, 'cancel'));

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

  static final List<RegExp> _httpTimeoutTargetPatterns = [
    RegExp(r'\bhttp\b'),
    RegExp(r'\bclient\b'),
    RegExp(r'\bClient\b'),
    RegExp(r'\bdio\b'),
    RegExp(r'\bDio\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_httpMethods.contains(methodName)) return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!_httpTimeoutTargetPatterns.any((p) => p.hasMatch(targetSource))) {
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

  static final List<RegExp> _websocketClassPatterns = [
    RegExp(r'\bWebSocketChannel\b'),
    RegExp(r'\bWebSocket\b'),
  ];
  static final List<RegExp> _reconnectionClassPatterns = [
    RegExp(r'\breconnect\b'),
    RegExp(r'\bretry\b'),
    RegExp(r'\bonDone\s*:'),
    RegExp(r'\bonError\s*:'),
    RegExp(r'\bbackoff\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      if (className == 'WebSocketChannel' || className == 'WebSocket') return;

      final String classSource = node.toSource();

      if (!_websocketClassPatterns.any((p) => p.hasMatch(classSource))) {
        return;
      }

      final bool hasReconnection = _reconnectionClassPatterns.any(
        (p) => p.hasMatch(classSource),
      );

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

// =============================================================================
// prefer_batch_requests
// =============================================================================

/// Prefer batch API calls over multiple small requests in a loop.
///
/// N+1 network requests in a for loop add latency. This rule flags for-statements
/// whose body contains await and a fetch-like method name (get, fetch, load,
/// read, query, find). Test files skipped. Heuristic: does not verify same
/// receiver across iterations; may have false positives (e.g. pagination).
class PreferBatchRequestsRule extends SaropaLintRule {
  PreferBatchRequestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_batch_requests',
    '[prefer_batch_requests] Multiple await calls in a loop. Consider a batch endpoint to reduce network overhead.',
    correctionMessage:
        'Consider using a batch endpoint (e.g., getUsers(ids)) instead of individual requests in a loop.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _fetchNames = <String>{
    'get',
    'fetch',
    'load',
    'read',
    'query',
    'find',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isInTestDirectory) return;
    context.addForStatement((ForStatement node) {
      final String body = node.body.toSource();
      if (!body.contains('await ')) return;
      for (final name in _fetchNames) {
        if (body.contains('.$name(') || body.contains('$name(')) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

// =============================================================================
// require_accept_encoding_header
// =============================================================================

/// HTTP requests should request gzip compression when appropriate.
///
/// Requests without Accept-Encoding miss 60–80% bandwidth savings on typical
/// JSON/text. Only runs when the project uses `http` or `dio`. Only flags
/// invocations whose target source contains "http" or "dio" to avoid false
/// positives on unrelated .get()/.post() calls. Test files are skipped.
class RequireCompressionRule extends SaropaLintRule {
  RequireCompressionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_accept_encoding_header',
    '[require_accept_encoding_header] HTTP request without Accept-Encoding. Add headers: {\'Accept-Encoding\': \'gzip\'} to reduce bandwidth.',
    correctionMessage:
        'Add headers: {\'Accept-Encoding\': \'gzip\'} to request compressed responses.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<String> get configAliases => const ['require_compression'];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final path = context.filePath;
    if (!ProjectContext.hasDependency(path, 'http') &&
        !ProjectContext.hasDependency(path, 'dio')) {
      return;
    }
    if (context.isInTestDirectory) return;

    context.addMethodInvocation((MethodInvocation node) {
      final name = node.methodName.name;
      if (name != 'get' &&
          name != 'post' &&
          name != 'put' &&
          name != 'delete') {
        return;
      }
      // Only flag invocations on http/dio (e.g. http.get, dio.get).
      final Expression? target = node.target;
      if (target != null) {
        final String targetSrc = target.toSource().toLowerCase();
        if (!targetSrc.contains('http') && !targetSrc.contains('dio')) {
          return;
        }
      }
      bool hasGzip = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'headers') {
          final String headers = arg.expression.toSource();
          if (headers.contains('Accept-Encoding') || headers.contains('gzip')) {
            hasGzip = true;
          }
          break;
        }
      }
      if (!hasGzip) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when HTTP POST/PUT/PATCH to sensitive (auth) endpoints is made
/// without certificate pinning.
///
/// **Category:** API & network security (OWASP M5, M3).
/// **Since:** v4.14.0 | **Rule version:** v1
///
/// Sensitive operations (login, token, credentials) should use SSL pinning
/// to mitigate MitM on compromised or custom CAs. URL path is heuristic
/// (e.g. /auth, /login, /token); false positives possible for non-auth paths.
/// Suppressed when project uses `http_certificate_pinning` or
/// `ssl_pinning_plugin`, and for localhost/127.0.0.1.
///
/// **Bad:**
/// ```dart
/// await http.post(
///   Uri.parse('https://api.example.com/auth/login'),
///   body: {'email': email, 'password': password},
/// );
/// ```
///
/// **Good:**
/// ```dart
/// await HttpCertificatePinning.check(
///   serverURL: 'https://api.example.com/auth/login',
///   sha: SHA.SHA256,
///   allowedSHAFingerprints: ['AB:CD:EF:...'],
///   ...
/// );
/// ```
class RequireSslPinningSensitiveRule extends SaropaLintRule {
  RequireSslPinningSensitiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ssl_pinning_sensitive',
    '[require_ssl_pinning_sensitive] Sensitive API endpoint (auth/login/token) '
        'called without certificate pinning. Use http_certificate_pinning or '
        'ssl_pinning_plugin to mitigate MitM on compromised CAs. OWASP M5, M3. {v1}',
    correctionMessage:
        'Use a pinning-capable client (e.g. HttpCertificatePinning.check or '
        'Dio with CertificatePinningInterceptor) for auth and sensitive endpoints.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitivePathSegments = <String>{
    'auth',
    'login',
    'signin',
    'token',
    'oauth',
    'credentials',
    'sign-in',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final path = context.filePath;
    if (ProjectContext.hasDependency(path, 'http_certificate_pinning') ||
        ProjectContext.hasDependency(path, 'ssl_pinning_plugin')) {
      return;
    }
    if (context.isInTestDirectory) return;

    context.addMethodInvocation((MethodInvocation node) {
      final name = node.methodName.name;
      if (name != 'post' && name != 'put' && name != 'patch') return;
      final Expression? target = node.target;
      if (target != null) {
        final String targetSrc = target.toSource().toLowerCase();
        if (!targetSrc.contains('http') && !targetSrc.contains('dio')) return;
      }

      final String? urlString = _getUrlStringFromInvocation(node);
      if (urlString == null) return;
      final lower = urlString.toLowerCase().trim();
      if (lower.contains('localhost') || lower.contains('127.0.0.1')) return;
      // Full URL must be HTTPS; path-only (e.g. Dio baseUrl + path) is checked below
      if (lower.contains('://') && !lower.startsWith('https://')) return;

      final hasSensitivePath = _sensitivePathSegments.any(
        (s) => lower.contains('/$s'),
      );
      if (!hasSensitivePath) return;

      reporter.atNode(node);
    });
  }

  String? _getUrlStringFromInvocation(MethodInvocation node) {
    final args = node.argumentList.arguments;
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is NamedExpression) {
      final name = first.name.label.name;
      if (name != 'url' && name != 'uri' && name != 'path') return null;
      return _extractStringLiteral(first.expression);
    }
    return _extractStringLiteral(first);
  }

  String? _extractStringLiteral(Expression expr) {
    if (expr is SimpleStringLiteral) return expr.value;
    if (expr is MethodInvocation &&
        expr.methodName.name == 'parse' &&
        expr.argumentList.arguments.isNotEmpty) {
      final arg = expr.argumentList.arguments.first;
      if (arg is SimpleStringLiteral) return arg.value;
      if (arg is AdjacentStrings) {
        return arg.strings
            .whereType<SimpleStringLiteral>()
            .map((s) => s.value)
            .join();
      }
    }
    return null;
  }
}

// =============================================================================
// prefer_stale_while_revalidate
// =============================================================================

/// Suggests stale-while-revalidate cache pattern for API data.
class PreferStaleWhileRevalidateRule extends SaropaLintRule {
  PreferStaleWhileRevalidateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_stale_while_revalidate',
    '[prefer_stale_while_revalidate] Consider stale-while-revalidate for cached API data.',
    correctionMessage:
        'Serve cached data immediately and refresh in background.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// require_api_response_validation
// =============================================================================

/// Returns the innermost [Block] that contains [node], or null.
Block? _blockContaining(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is Block) return current;
    current = current.parent;
  }
  return null;
}

/// Returns the outermost [Block] that contains [node], or null.
Block? _outermostBlockContaining(AstNode node) {
  Block? block = _blockContaining(node);
  while (block != null) {
    final parent = block.parent;
    if (parent is! Block) break;
    block = parent;
  }
  return block;
}

/// Returns the [Statement] that is a direct child of [block] and contains [node].
Statement? _directChildStatementOf(Block block, AstNode node) {
  AstNode? current = node;
  while (current != null && current.parent != block) {
    current = current.parent;
  }
  return current is Statement ? current : null;
}

/// Returns the [Statement] that is a direct child of a [Block] and contains [node].
Statement? _statementInBlockContaining(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    final parent = current.parent;
    if (parent is Block && current is Statement) return current;
    current = parent;
  }
  return null;
}

/// True when [node] (a jsonDecode call) is the direct argument to a fromJson call.
bool _isDirectArgumentToFromJson(MethodInvocation node) {
  final parent = node.parent;
  if (parent is ArgumentList) {
    final grandparent = parent.parent;
    if (grandparent is MethodInvocation &&
        grandparent.methodName.name == 'fromJson' &&
        parent.arguments.length == 1 &&
        parent.arguments.single == node) {
      return true;
    }
  }
  return false;
}

/// Variable name if [node] is the RHS of an assignment to a variable; null otherwise.
String? _assignedVariableName(MethodInvocation node) {
  final parent = node.parent;
  if (parent is VariableDeclaration && parent.initializer == node) {
    return parent.name.lexeme;
  }
  if (parent is AssignmentExpression && parent.rightHandSide == node) {
    final left = parent.leftHandSide;
    if (left is SimpleIdentifier) return left.name;
  }
  return null;
}

void _collectIdentifiers(AstNode node, String name, List<SimpleIdentifier> out) {
  if (node is SimpleIdentifier && node.name == name) {
    out.add(node);
  }
  for (final c in node.childEntities) {
    if (c is AstNode) _collectIdentifiers(c, name, out);
  }
}

/// True when the only use of variable [name] in [block] (after [stmt]) is as the single argument to a fromJson call.
bool _variableOnlyPassedToFromJson(Block block, String name, Statement stmt) {
  final stmtIndex = block.statements.indexOf(stmt);
  if (stmtIndex < 0) return false;
  final afterStmt = block.statements.sublist(stmtIndex);
  final identifiers = <SimpleIdentifier>[];
  for (final s in afterStmt) {
    _collectIdentifiers(s, name, identifiers);
  }
  for (final id in identifiers) {
    if (id.parent is VariableDeclaration) continue;
    if (!_isArgumentToFromJson(id)) return false;
  }
  return true;
}

/// True when [name] is validated by a type check after [stmt] (e.g. if (x is! Map && x is! List) throw).
/// Heuristic: condition source contains variable name and Map/List, and then-branch returns or throws.
bool _variableValidatedByTypeCheck(Block block, String name, Statement stmt) {
  final stmtIndex = block.statements.indexOf(stmt);
  if (stmtIndex < 0) return false;
  final afterStmt = block.statements.sublist(stmtIndex + 1);
  for (final s in afterStmt) {
    if (s is IfStatement) {
      final conditionSrc = s.expression.toSource();
      if (!conditionSrc.contains(name)) continue;
      if (!conditionSrc.contains('Map') && !conditionSrc.contains('List')) continue;
      if (!_thenReturnsOrThrows(s.thenStatement)) continue;
      return true;
    }
  }
  return false;
}

bool _isArgumentToFromJson(SimpleIdentifier identifier) {
  final parent = identifier.parent;
  if (parent is ArgumentList &&
      parent.arguments.length == 1 &&
      parent.arguments.single == identifier) {
    final grandparent = parent.parent;
    if (grandparent is MethodInvocation &&
        grandparent.methodName.name == 'fromJson') {
      return true;
    }
  }
  return false;
}

/// Suggests validating API response shape before use.
///
/// Reports on [jsonDecode] when the decoded value may be used without validation (e.g. direct field access).
/// Does **not** report when:
/// - The [jsonDecode] call is the direct single argument to a [fromJson] call (e.g. `MyType.fromJson(jsonDecode(body))`), or
/// - The decoded value is assigned to a variable and that variable is only ever passed as the single argument to a [fromJson] call, or
/// - The decoded value is assigned to a variable and a subsequent [IfStatement] in the same block validates it (e.g. type check for Map/List) and returns or throws on failure (validation-helper pattern).
///
/// **BAD:**
/// ```dart
/// final data = jsonDecode(response.body);
/// print(data['key']); // Unvalidated use
/// ```
///
/// **GOOD:**
/// ```dart
/// final data = MyModel.fromJson(jsonDecode(response.body));
/// // or: final decoded = jsonDecode(response.body); ... MyModel.fromJson(decoded);
/// // or: decodeAndValidateJson(body) that checks Map/List and throws.
/// ```
class RequireApiResponseValidationRule extends SaropaLintRule {
  RequireApiResponseValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_api_response_validation',
    '[require_api_response_validation] API response used without validation. Validate shape before use.',
    correctionMessage:
        'Check response fields or use json_serializable with fromJson.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;
      if (_isDirectArgumentToFromJson(node)) return;
      final varName = _assignedVariableName(node);
      if (varName != null) {
        final block = _blockContaining(node);
        final stmt = _statementInBlockContaining(node);
        if (block != null && stmt != null) {
          if (_variableOnlyPassedToFromJson(block, varName, stmt)) return;
          if (_variableValidatedByTypeCheck(block, varName, stmt)) return;
        }
      }
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// require_api_version_handling
// =============================================================================

/// Suggests handling API version in requests or config.
class RequireApiVersionHandlingRule extends SaropaLintRule {
  RequireApiVersionHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_api_version_handling',
    '[require_api_version_handling] Consider API version in URL or headers.',
    correctionMessage:
        'Include version in path or Accept header for API compatibility.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// require_content_type_validation
// =============================================================================

/// True when the then-branch returns or throws (content-type guard before decode).
bool _thenReturnsOrThrows(Statement thenStatement) {
  if (thenStatement is ReturnStatement) return true;
  if (thenStatement is ExpressionStatement &&
      thenStatement.expression is ThrowExpression) {
    return true;
  }
  if (thenStatement is Block && thenStatement.statements.length == 1) {
    final only = thenStatement.statements.single;
    if (only is ExpressionStatement && only.expression is ThrowExpression) {
      return true;
    }
  }
  return false;
}

/// True when [stmt] is an IfStatement that returns or throws when Content-Type is not application/json.
/// Uses a guarded heuristic on condition source (contentType/mimeType + application/json) per CONTRIBUTING.md.
bool _isContentTypeGuardStatement(Statement stmt) {
  if (stmt is! IfStatement) return false;
  final condition = stmt.expression.toSource();
  final hasContentType = condition.contains('contentType') ||
      condition.contains('mimeType') ||
      condition.contains('content_type');
  final hasJson = condition.contains('application/json');
  if (!hasContentType || !hasJson) return false;
  return _thenReturnsOrThrows(stmt.thenStatement);
}

/// Recurses into if-then blocks to find nested content-type guards (e.g. if (headers != null) { if (!json) throw }).
bool _hasContentTypeGuardInStatement(Statement s) {
  if (_isContentTypeGuardStatement(s)) return true;
  if (s is IfStatement) {
    final then = s.thenStatement;
    if (then is Block) {
      for (final child in then.statements) {
        if (_hasContentTypeGuardInStatement(child)) return true;
      }
    }
  }
  return false;
}

/// True when a dominating content-type check exists before the jsonDecode at [node].
bool _hasContentTypeGuardBeforeJsonDecode(AstNode node) {
  Block? block = _outermostBlockContaining(node);
  while (block != null) {
    final stmt = _directChildStatementOf(block, node);
    if (stmt != null) {
      final stmtIndex = block.statements.indexOf(stmt);
      if (stmtIndex > 0) {
        for (var i = 0; i < stmtIndex; i++) {
          if (_hasContentTypeGuardInStatement(block.statements[i])) return true;
        }
      }
    }
    final parent = block.parent;
    if (parent is! Block) break;
    block = parent;
  }
  return false;
}

/// Suggests validating Content-Type before parsing response.
///
/// Reports on [jsonDecode] when there is no dominating content-type guard before the call.
/// Does **not** report when a preceding [IfStatement] in the same or outer (including nested) block
/// checks contentType/mimeType and `application/json`, and returns or throws before the decode.
/// Guard detection accepts both return and throw in the then-branch (guarded heuristic on condition source; see CONTRIBUTING.md).
///
/// **BAD:**
/// ```dart
/// final data = jsonDecode(response.body); // No Content-Type check
/// ```
///
/// **GOOD:**
/// ```dart
/// if (request.headers.contentType?.mimeType != 'application/json') {
///   return (error: 'Content-Type must be application/json');
/// }
/// final data = jsonDecode(body);
/// ```
///
/// **GOOD (throw in helper):**
/// ```dart
/// if (responseHeaders != null && !contentType.toLowerCase().contains('application/json')) {
///   throw FormatException('Unexpected Content-Type');
/// }
/// final decoded = jsonDecode(source);
/// ```
class RequireContentTypeValidationRule extends SaropaLintRule {
  RequireContentTypeValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_content_type_validation',
    '[require_content_type_validation] Response body parsed without Content-Type check.',
    correctionMessage:
        'Check response.headers Content-Type before parsing body.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;
      if (_hasContentTypeGuardBeforeJsonDecode(node)) return;
      reporter.atNode(node);
    });
  }
}
