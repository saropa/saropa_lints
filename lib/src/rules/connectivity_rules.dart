// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Connectivity lint rules for Flutter applications.
///
/// These rules help ensure proper network connectivity handling with
/// appropriate error handling.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

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
