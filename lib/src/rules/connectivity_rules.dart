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
