// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// Platform-Specific Rules (v4.1.6)
// =============================================================================

/// Warns when platform-specific APIs are used without Platform checks.
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
  const RequirePlatformCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_platform_check',
    problemMessage:
        '[require_platform_check] Platform-specific API from dart:io used without a platform guard. On Flutter web, dart:io classes throw UnsupportedError at runtime because they are unavailable in the browser environment. This crashes the app immediately when the code path executes, making the web version completely unusable for affected features.',
    correctionMessage:
        'Guard platform-specific code with if (!kIsWeb) before accessing dart:io APIs, or use conditional imports to provide web-compatible implementations.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name2.lexeme;

      if (!_platformSpecificClasses.contains(constructorName)) return;

      if (!_hasPlatformGuard(node)) {
        reporter.atNode(node, code);
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
  const PreferPlatformIoConditionalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_platform_io_conditional',
    problemMessage:
        '[prefer_platform_io_conditional] Platform class from dart:io throws UnsupportedError at runtime on Flutter web because dart:io is unavailable in browser environments. Accessing Platform.isAndroid, Platform.isIOS, or any Platform property without first checking kIsWeb crashes the web app immediately with an unrecoverable runtime error.',
    correctionMessage:
        'Check kIsWeb first before accessing Platform properties: if (!kIsWeb && Platform.isAndroid) to prevent runtime crashes on Flutter web deployments.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Platform') return;

      final String property = node.identifier.name;
      if (!property.startsWith('is')) return; // Platform.isAndroid, etc.

      // Check if already guarded by kIsWeb
      if (!_isGuardedByKIsWeb(node)) {
        reporter.atNode(node, code);
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

  @override
  List<Fix> getFixes() => <Fix>[_AddKIsWebGuardFix()];
}

class _AddKIsWebGuardFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String condition = node.expression.toSource();
      if (!condition.contains('Platform.')) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add kIsWeb guard',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.expression.sourceRange,
          '!kIsWeb && ($condition)',
        );
      });
    });
  }
}

/// Warns when Platform is used in widget context instead of defaultTargetPlatform.
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
  const PreferFoundationPlatformCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_foundation_platform_check',
    problemMessage:
        '[prefer_foundation_platform_check] Use defaultTargetPlatform in widget code. In widget code, defaultTargetPlatform from foundation is safer and allows for testing overrides. Platform requires dart:io which doesn\'t exist on web.',
    correctionMessage:
        'Replace Platform.isX with defaultTargetPlatform == TargetPlatform.X. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Platform') return;

      final String property = node.identifier.name;
      if (!property.startsWith('is')) return;

      // Check if inside a widget build method
      if (_isInsideBuildMethod(node)) {
        reporter.atNode(node, code);
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

  @override
  List<Fix> getFixes() => <Fix>[_ReplacePlatformCheckFix()];
}

class _ReplacePlatformCheckFix extends DartFix {
  static const Map<String, String> _platformMap = {
    'isAndroid': 'TargetPlatform.android',
    'isIOS': 'TargetPlatform.iOS',
    'isFuchsia': 'TargetPlatform.fuchsia',
    'isLinux': 'TargetPlatform.linux',
    'isMacOS': 'TargetPlatform.macOS',
    'isWindows': 'TargetPlatform.windows',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.prefix.name != 'Platform') return;

      final String property = node.identifier.name;
      final String? targetPlatform = _platformMap[property];
      if (targetPlatform == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with defaultTargetPlatform',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'defaultTargetPlatform == $targetPlatform',
        );
      });
    });
  }
}
