// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// Platform-Specific Rules (v4.1.6)
// =============================================================================

/// Warns when platform-specific APIs are used without Platform checks.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
///
/// Using dart:io APIs without platform checks can cause crashes on web.
/// Always guard platform-specific code with appropriate conditionals.
///
/// **BAD:**
/// ```dart
/// void saveFile() {
///   final file = File('data.txt'); // Crashes on web!
///   file.writeAsStringSync('Hello');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void saveFile() {
///   if (!kIsWeb) {
///     final file = File('data.txt');
///     file.writeAsStringSync('Hello');
///   }
/// }
/// ```
class RequirePlatformCheckRule extends SaropaLintRule {
  RequirePlatformCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_platform_check',
    '[require_platform_check] Platform-specific API from dart:io used without a platform guard. On Flutter web, dart:io classes throw UnsupportedError at runtime because they are unavailable in the browser environment. This crashes the app immediately when the code path executes, making the web version completely unusable for affected features. {v2}',
    correctionMessage:
        'Guard platform-specific code with if (!kIsWeb) before accessing dart:io APIs, or use conditional imports to provide web-compatible implementations.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _platformSpecificClasses = {
    'File',
    'Directory',
    'Process',
    'ProcessResult',
    'Socket',
    'ServerSocket',
    'RawSocket',
    'RawServerSocket',
    'Stdin',
    'Stdout',
    'IOSink',
    'RandomAccessFile',
    'FileSystemEntity',
    'Link',
    'FileStat',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;

      if (!_platformSpecificClasses.contains(constructorName)) return;

      if (!_hasPlatformGuard(node)) {
        reporter.atNode(node);
      }
    });
  }

  bool _hasPlatformGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('Platform.') ||
            condition.contains('kIsWeb') ||
            condition.contains('defaultTargetPlatform')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Platform is used for web checks instead of kIsWeb.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
///
/// Platform from dart:io doesn't exist on web. Use kIsWeb from
/// foundation for web detection.
///
/// **BAD:**
/// ```dart
/// if (Platform.isAndroid || Platform.isIOS) { // Crashes on web!
///   // Mobile code
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (!kIsWeb) {
///   if (Platform.isAndroid) { /* Android code */ }
///   if (Platform.isIOS) { /* iOS code */ }
/// }
/// ```
class PreferPlatformIoConditionalRule extends SaropaLintRule {
  PreferPlatformIoConditionalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_platform_io_conditional',
    '[prefer_platform_io_conditional] Platform class from dart:io throws UnsupportedError at runtime on Flutter web because dart:io is unavailable in browser environments. Accessing Platform.isAndroid, Platform.isIOS, or any Platform property without first checking kIsWeb crashes the web app immediately with an unrecoverable runtime error. {v2}',
    correctionMessage:
        'Check kIsWeb first before accessing Platform properties: if (!kIsWeb && Platform.isAndroid) to prevent runtime crashes on Flutter web deployments.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Platform') return;

      final String property = node.identifier.name;
      if (!property.startsWith('is')) return; // Platform.isAndroid, etc.

      // Check if already guarded by kIsWeb
      if (!_isGuardedByKIsWeb(node)) {
        reporter.atNode(node);
      }
    });
  }

  bool _isGuardedByKIsWeb(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('kIsWeb') || condition.contains('!kIsWeb')) {
          return true;
        }
      }
      if (current is ConditionalExpression) {
        final String condition = current.condition.toSource();
        if (condition.contains('kIsWeb')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Platform is used in widget context instead of defaultTargetPlatform.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
///
/// In widget code, defaultTargetPlatform from foundation is safer and
/// allows for testing overrides. Platform requires dart:io which
/// doesn't exist on web.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (Platform.isIOS) { // dart:io import required, crashes on web
///     return CupertinoButton(...);
///   }
///   return ElevatedButton(...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (defaultTargetPlatform == TargetPlatform.iOS) {
///     return CupertinoButton(...);
///   }
///   return ElevatedButton(...);
/// }
/// ```
class PreferFoundationPlatformCheckRule extends SaropaLintRule {
  PreferFoundationPlatformCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_foundation_platform_check',
    '[prefer_foundation_platform_check] Use defaultTargetPlatform in widget code. In widget code, defaultTargetPlatform from foundation is safer and allows for testing overrides. Platform requires dart:io which doesn\'t exist on web. {v2}',
    correctionMessage:
        'Replace Platform.isX with defaultTargetPlatform == TargetPlatform.X. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Platform') return;

      final String property = node.identifier.name;
      if (!property.startsWith('is')) return;

      // Check if inside a widget build method
      if (_isInsideBuildMethod(node)) {
        reporter.atNode(node);
      }
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration && current.name.lexeme == 'build') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
