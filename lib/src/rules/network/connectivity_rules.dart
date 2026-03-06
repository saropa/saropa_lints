// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Connectivity lint rules for Flutter applications.
///
/// These rules help ensure proper network connectivity handling with
/// appropriate error handling.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// require_connectivity_error_handling
// =============================================================================

/// Warns when connectivity check is called without error handling.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: connectivity_error, handle_connectivity_check
///
/// Connectivity checks can fail (e.g., airplane mode, no network interface).
/// Detect checkConnectivity without try-catch.
///
/// **BAD:**
/// ```dart
/// Future<bool> isOnline() async {
///   final result = await Connectivity().checkConnectivity();
///   return result != ConnectivityResult.none;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<bool> isOnline() async {
///   try {
///     final result = await Connectivity().checkConnectivity();
///     return result != ConnectivityResult.none;
///   } catch (e) {
///     // Handle platform exceptions
///     return false;
///   }
/// }
/// ```
class RequireConnectivityErrorHandlingRule extends SaropaLintRule {
  RequireConnectivityErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_connectivity_error_handling',
    '[require_connectivity_error_handling] Connectivity check without '
        'error handling. checkConnectivity() can throw platform exceptions. {v2}',
    correctionMessage:
        'Wrap connectivity checks in try-catch to handle platform exceptions.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for connectivity-related method calls
      if (methodName != 'checkConnectivity' &&
          methodName != 'onConnectivityChanged') {
        return;
      }

      // Check if inside try-catch
      AstNode? current = node.parent;
      bool isInsideTryCatch = false;

      while (current != null) {
        if (current is TryStatement) {
          isInsideTryCatch = true;
          break;
        }
        if (current is FunctionBody ||
            current is MethodDeclaration ||
            current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      if (isInsideTryCatch) return;

      // Check for .catchError
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is MethodInvocation) {
          final String parentMethod = parent.methodName.name;
          if (parentMethod == 'catchError' || parentMethod == 'onError') {
            return; // Has error handling
          }
        }
        if (parent is! MethodInvocation && parent is! CascadeExpression) {
          break;
        }
        parent = parent.parent;
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_connectivity_equals_internet
// =============================================================================

/// Warns when `ConnectivityResult` is used as a proxy for internet access.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: connectivity_not_internet, check_real_connectivity
///
/// `ConnectivityResult` only indicates the transport layer (WiFi, mobile,
/// ethernet), not whether the internet is actually reachable. A device can
/// be connected to WiFi behind a captive portal or on a mobile network with
/// no data. Use an actual HTTP ping or DNS lookup to verify connectivity.
///
/// **BAD:**
/// ```dart
/// final result = await Connectivity().checkConnectivity();
/// if (result != ConnectivityResult.none) {
///   // WRONG: assumes internet is available
///   await fetchData();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final result = await InternetAddress.lookup('example.com');
///   if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
///     await fetchData();
///   }
/// } on SocketException {
///   // No internet
/// }
/// ```
class AvoidConnectivityEqualsInternetRule extends SaropaLintRule {
  AvoidConnectivityEqualsInternetRule() : super(code: _code);

  /// Trusting transport type as internet causes silent failures.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_connectivity_equals_internet',
    '[avoid_connectivity_equals_internet] ConnectivityResult compared as a '
        'proxy for internet availability. ConnectivityResult only indicates '
        'the transport layer (WiFi, mobile, ethernet) and does not verify '
        'actual internet reachability. A device can report WiFi while behind '
        'a captive portal, or mobile data with no route to the internet. '
        'Use an actual HTTP ping or DNS lookup to verify connectivity. {v1}',
    correctionMessage:
        'Use InternetAddress.lookup or an HTTP health-check endpoint '
        'instead of comparing ConnectivityResult values.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _connectivityValues = <String>{
    'none',
    'wifi',
    'mobile',
    'ethernet',
    'bluetooth',
    'vpn',
    'other',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'ConnectivityResult') return;
      if (!_connectivityValues.contains(node.identifier.name)) return;

      // Walk up to find enclosing binary expression (== or !=)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is BinaryExpression) {
          final String op = current.operator.lexeme;
          if (op == '==' || op == '!=') {
            reporter.atNode(current);
            return;
          }
        }
        // Stop at statement boundary
        if (current is Statement || current is FunctionBody) break;
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// require_connectivity_timeout
// =============================================================================

/// Warns when HTTP requests are made without a timeout.
///
/// Network requests without timeouts can hang indefinitely. Connectivity
/// status can be misleading; always set a timeout so requests fail gracefully.
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
class RequireConnectivityTimeoutRule extends SaropaLintRule {
  RequireConnectivityTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
        '.get(',
        '.post(',
        '.put(',
        '.delete(',
        '.patch(',
        '.head(',
      };

  static const LintCode _code = LintCode(
    'require_connectivity_timeout',
    '[require_connectivity_timeout] Network request has no timeout. Requests can hang indefinitely; set a timeout so they fail gracefully.',
    correctionMessage:
        'Add .timeout(const Duration(seconds: 30)) to the request or configure timeouts on the client.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _httpMethods = <String>{
    'get',
    'post',
    'put',
    'delete',
    'patch',
    'head',
  };

  static final RegExp _httpTargetPattern = RegExp(
    r'\b(http|client|dio)\b',
    caseSensitive: false,
  );

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
      final String targetSource = target.toSource().toLowerCase();
      if (!_httpTargetPattern.hasMatch(targetSource)) {
        return;
      }

      AstNode? parent = node.parent;
      if (parent is MethodInvocation && parent.methodName.name == 'timeout') {
        return;
      }
      if (parent is AwaitExpression) {
        final awaitParent = parent.parent;
        if (awaitParent is MethodInvocation &&
            awaitParent.methodName.name == 'timeout') {
          return;
        }
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// prefer_connectivity_debounce
// =============================================================================

/// Prefer debouncing connectivity stream listeners to avoid rapid rebuilds.
class PreferConnectivityDebounceRule extends SaropaLintRule {
  PreferConnectivityDebounceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_connectivity_debounce',
    '[prefer_connectivity_debounce] Connectivity stream can emit rapidly. '
        'Debounce or distinct() the stream before rebuilding UI.',
    correctionMessage:
        'Use .distinct() or debounce on connectivity stream before listen.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// prefer_internet_connection_checker
// =============================================================================

/// Suggests internet_connection_checker for actual internet verification.
///
/// Connectivity (e.g. connectivity_plus) only reports interface state; it does
/// not verify that the device can reach the internet. For real connectivity
/// checks, use internet_connection_checker or similar.
///
/// **Bad:** Relying only on checkConnectivity() for "is user online?".
///
/// **Good:** Use InternetConnectionChecker() or package for actual reachability.
class PreferInternetConnectionCheckerRule extends SaropaLintRule {
  PreferInternetConnectionCheckerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_internet_connection_checker',
    '[prefer_internet_connection_checker] checkConnectivity() only reports '
        'interface state. For actual internet verification, consider '
        'internet_connection_checker package.',
    correctionMessage:
        'Use internet_connection_checker or similar for real reachability checks.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String content = context.fileContent;
    if (RegExp(r'\bInternetConnectionChecker\b').hasMatch(content)) return;
    if (RegExp(r'internet_connection_checker').hasMatch(content)) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'checkConnectivity') return;
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// require_connectivity_resume_check
// =============================================================================

/// Suggests re-checking connectivity when app resumes (Android 8+).
class RequireConnectivityResumeCheckRule extends SaropaLintRule {
  RequireConnectivityResumeCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_connectivity_resume_check',
    '[require_connectivity_resume_check] Re-check connectivity when app resumes. Android 8+ stops background updates.',
    correctionMessage:
        'Listen to WidgetsBindingObserver and re-check connectivity on resume.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}
