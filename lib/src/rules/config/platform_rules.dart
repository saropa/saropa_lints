// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

import '../../conditional_import_utils.dart';
import '../../fixes/platform/add_k_is_web_guard_fix.dart';
import '../../fixes/platform/replace_platform_check_fix.dart';
import '../../saropa_lint_rule.dart';
import '../../string_slice_utils.dart';

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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
    // If the project can't produce a web build, `dart:io` can't throw
    // `UnsupportedError` at runtime — the rule's entire justification
    // does not apply. See sibling bug report
    // bugs/platform_gate_missing_from_sibling_rules.md.
    if (!ProjectContext.hasWebSupport(context.filePath)) return;

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddKIsWebGuardFix(context: context),
  ];

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
    // Non-Flutter projects never run on web — Platform.* checks are safe
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;

    // Mobile-only / desktop-only Flutter projects (no `web/` directory)
    // can never hit the "Platform.* throws on web" failure mode, so the
    // kIsWeb guard the rule demands is pure ceremony. See sibling bug
    // report bugs/platform_gate_missing_from_sibling_rules.md.
    if (!ProjectContext.hasWebSupport(context.filePath)) return;

    // Files that are the native branch of a conditional import (dart.library.io
    // or dart.library.ffi) are never loaded on web; no need to require kIsWeb.
    if (isNativeOnlyConditionalImportTarget(context.filePath)) return;

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Platform') return;

      final String property = node.identifier.name;
      if (!property.startsWith('is')) return; // Platform.isAndroid, etc.

      if (!_isGuardedByKIsWeb(node)) {
        reporter.atNode(node);
      }
    });
  }

  /// True if an ancestor IfStatement or ConditionalExpression's condition
  /// source mentions kIsWeb (guard present).
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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplacePlatformCheckFix(context: context),
  ];

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

// =============================================================================
// prefer_platform_widget_adaptive
// =============================================================================

/// Suggests platform-adaptive widgets for cross-platform apps.
///
/// Using only Material widgets on iOS (or only Cupertino on Android) can feel
/// inconsistent. Prefer Platform.isIOS / Theme.of(context).platform or adaptive widgets.
///
/// **Bad:** MaterialApp with no platform-specific theming on iOS.
///
/// **Good:** Use Platform.isIOS to switch or use adaptive widgets.
class PreferPlatformWidgetAdaptiveRule extends SaropaLintRule {
  PreferPlatformWidgetAdaptiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_platform_widget_adaptive',
    '[prefer_platform_widget_adaptive] Consider platform-adaptive widgets. '
        'Material-only UI on iOS (or Cupertino-only on Android) may feel inconsistent.',
    correctionMessage:
        'Use Theme.of(context).platform or Platform.isIOS to adapt widgets.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String name = node.constructorName.type.name.lexeme;
      if (name != 'MaterialApp') return;
      reporter.atNode(node);
    });
  }
}

/// Requires desktop runner setup files when desktop-only APIs are used.
class RequireDesktopWindowSetupRule extends SaropaLintRule {
  RequireDesktopWindowSetupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform', 'desktop'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_desktop_window_setup',
    '[require_desktop_window_setup] Desktop window APIs are used but the project appears to miss desktop runner setup files. This usually means desktop platform configuration is incomplete. {v1}',
    correctionMessage:
        'Ensure desktop platform folders and runner setup files exist before using desktop window APIs.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _desktopMethods = <String>{
    'ensureInitialized',
    'setMinimumSize',
    'setMaximumSize',
    'setTitle',
    'setSize',
    'waitUntilReadyToShow',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;

    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (!_desktopMethods.contains(methodName)) return;
      final targetName = node.target?.toSource();
      if (targetName != 'windowManager') return;

      final projectRoot = _findProjectRoot(context.filePath);
      if (projectRoot == null) return;
      if (_hasDesktopRunnerFiles(projectRoot)) return;

      reporter.atNode(node);
    });
  }

  static bool _hasDesktopRunnerFiles(String projectRoot) {
    const candidatePaths = <String>[
      'windows/runner/main.cpp',
      'linux/runner/main.cc',
      'macos/Runner/AppDelegate.swift',
      'macos/Runner/MainFlutterWindow.swift',
    ];

    for (final relativePath in candidatePaths) {
      if (File('$projectRoot/$relativePath').existsSync()) {
        return true;
      }
    }
    return false;
  }

  static String? _findProjectRoot(String filePath) {
    var current = filePath.replaceAll('\\', '/');
    while (current.contains('/')) {
      final lastSlash = current.lastIndexOf('/');
      if (lastSlash <= 0) break;
      current = current.prefix(lastSlash);
      if (File('$current/pubspec.yaml').existsSync()) {
        return current;
      }
    }
    return null;
  }
}
