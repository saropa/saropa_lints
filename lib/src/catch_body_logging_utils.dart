// ignore_for_file: depend_on_referenced_packages

/// Shared detection for "does this catch block forward the caught error to a
/// logging or crash-reporting call" — the single source of truth for the
/// method/receiver name lists used by `error_handling_rules.dart`'s
/// `require_error_logging` rule and by `avoid_catching_generic_exception`'s
/// body-inspection exemption for deliberately-broad `on Object`/`on
/// Exception` catches that immediately report before falling back.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Method/function names that indicate logging is happening.
///
/// Kept broad (standard logging, structured logger methods, and named crash
/// reporting SDK calls) because the goal is to recognize "this error was
/// reported somewhere", not to validate which framework was used.
const Set<String> catchBodyLoggingMethodNames = <String>{
  // Standard logging
  'log',
  'print',
  'debugPrint',
  'debugPrintStack',

  // Common logger methods
  'error',
  'warning',
  'warn',
  'info',
  'debug',
  'severe',
  'shout',
  'fine',
  'finer',
  'finest',

  // Crash reporting services
  'recordError',
  'recordFlutterError',
  'captureException',
  'captureMessage',
  'logError',
  'logException',
  'reportError',
  'report',

  // Firebase Crashlytics
  'recordFlutterFatalError',

  // Sentry
  'captureEvent',

  // Custom debug helpers
  'debugException',
  'logDebug',
  'logWarning',
  'logInfo',
};

/// Receiver names that indicate a logger object (e.g. `Crashlytics.instance`,
/// `Sentry.captureException`) even when the method name itself isn't in
/// [catchBodyLoggingMethodNames].
const Set<String> catchBodyLoggerReceiverNames = <String>{
  'logger',
  'log',
  'Logger',
  'Crashlytics',
  'crashlytics',
  'FirebaseCrashlytics',
  'Sentry',
  'sentry',
  'analytics',
  'Analytics',
  'debugger',
  'console',
};

/// Returns true if [body] contains a call that forwards the caught error to
/// a logging/crash-reporting sink, or re-raises it (`rethrow`/`throw`).
///
/// Walks the real AST rather than regex-scanning `body.toSource()`: a prior
/// source-text version matched `catchBodyLoggingMethodNames`/
/// `catchBodyLoggerReceiverNames` against the raw reconstructed source, so a
/// string literal that merely contained a logging method's name followed by
/// `(` (e.g. `showMessage('please log(in) again')`) was misdetected as a
/// logging call. An AST visitor only matches actual [MethodInvocation]
/// targets/names, [RethrowExpression], and [ThrowExpression] nodes.
bool catchBodyHasLoggingCall(Block body) {
  final _LoggingCallVisitor visitor = _LoggingCallVisitor();
  body.accept(visitor);
  return visitor.found;
}

/// Finds the leftmost identifier of a call-target expression chain, e.g.
/// `Crashlytics` in `Crashlytics.instance.recordError(...)`, so a receiver
/// match doesn't require the exact immediate target to be the logger name.
String? _leftmostIdentifierName(Expression? target) {
  if (target == null) return null;
  if (target is SimpleIdentifier) return target.name;
  if (target is PrefixedIdentifier) return target.prefix.name;
  if (target is PropertyAccess) return _leftmostIdentifierName(target.target);
  if (target is MethodInvocation) {
    return _leftmostIdentifierName(target.target) ?? target.methodName.name;
  }
  return null;
}

/// Returns true when a catch body's top-level statements include a
/// `return`, `continue`, or `break` — control-flow constructs that indicate
/// the catch is intentionally handling the exception by returning a fallback
/// value, skipping a bad item, or aborting a loop rather than silently
/// swallowing the error.
///
/// Shared between `require_catch_logging` (security) and
/// `avoid_swallowing_exceptions` (error handling) so both rules apply the
/// same exemption logic. Extracted here (O2) to eliminate the duplicated
/// inline check that previously lived in each rule's `runWithReporter`.
bool catchHandlesViaControlFlow(Block body) {
  for (final Statement stmt in body.statements) {
    if (stmt is ReturnStatement ||
        stmt is ContinueStatement ||
        stmt is BreakStatement) {
      return true;
    }
  }
  return false;
}

/// Returns true when [body] references [exceptionName] in a meaningful way
/// (not just assignment or basic property access like `.toString()` or
/// `.message`).
///
/// Uses an AST visitor to check actual identifier nodes rather than
/// substring-matching the source text — avoids false positives from
/// exception names that appear inside string literals or unrelated
/// identifiers.
bool catchBodyUsesException(Block body, String exceptionName) {
  bool used = false;
  body.visitChildren(_IdentifierUsageVisitor(exceptionName, () => used = true));
  return used;
}

/// AST visitor that fires [onFound] when a [SimpleIdentifier] matching
/// [name] is encountered. Used by [catchBodyUsesException] and by
/// `avoid_swallowing_exceptions` to detect whether the exception variable
/// is actually referenced in the catch body.
class CatchIdentifierUsageVisitor extends RecursiveAstVisitor<void> {
  CatchIdentifierUsageVisitor(this.name, this.onFound);

  /// The identifier name to search for.
  final String name;

  /// Callback invoked when a matching identifier is found.
  final void Function() onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) {
      onFound();
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Private convenience wrapper so internal callers don't need to construct
/// the visitor directly.
class _IdentifierUsageVisitor extends CatchIdentifierUsageVisitor {
  _IdentifierUsageVisitor(super.name, super.onFound);
}

class _LoggingCallVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!found) {
      final String methodName = node.methodName.name;
      if (catchBodyLoggingMethodNames.contains(methodName)) {
        found = true;
      } else {
        final String? receiver = _leftmostIdentifierName(node.target);
        if (receiver != null &&
            catchBodyLoggerReceiverNames.contains(receiver)) {
          found = true;
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    found = true;
    super.visitRethrowExpression(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    found = true;
    super.visitThrowExpression(node);
  }
}
