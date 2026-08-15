// ignore_for_file: depend_on_referenced_packages

/// Shared detection for "does this catch block forward the caught error to a
/// logging or crash-reporting call" — the single source of truth for the
/// method/receiver name lists used by [error_handling_rules.dart]'s
/// `require_error_logging` rule and by `avoid_catching_generic_exception`'s
/// body-inspection exemption for deliberately-broad `on Object`/`on
/// Exception` catches that immediately report before falling back.
library;

import 'package:analyzer/dart/ast/ast.dart';

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
/// Source-text regex scan rather than a full AST walk: catch bodies are
/// small, and this mirrors the exact heuristic `require_error_logging` has
/// used since v2 — matching behavior here avoids the two rules disagreeing
/// on the same block.
bool catchBodyHasLoggingCall(Block body) {
  final String bodySource = body.toSource();

  for (final String method in catchBodyLoggingMethodNames) {
    final String escaped = RegExp.escape(method);
    if (RegExp('\\b$escaped\\s*\\(').hasMatch(bodySource) ||
        RegExp('\\.$escaped\\s*\\(').hasMatch(bodySource)) {
      return true;
    }
  }

  for (final String receiver in catchBodyLoggerReceiverNames) {
    if (RegExp('${RegExp.escape(receiver)}\\.').hasMatch(bodySource)) {
      return true;
    }
  }

  if (RegExp(r'\brethrow\b').hasMatch(bodySource)) return true;
  if (RegExp(r'\bthrow\s+').hasMatch(bodySource)) return true;

  return false;
}
