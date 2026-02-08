// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

// cspell:disable

/// macOS platform-specific lint rules for Flutter applications.
///
/// These rules help ensure Flutter apps follow macOS platform best practices,
/// handle macOS-specific requirements like sandboxing, Hardened Runtime,
/// notarization, and native UX patterns.
///
/// ## macOS Considerations
///
/// macOS desktop apps have additional considerations:
/// - **Sandboxing**: Required for Mac App Store distribution
/// - **Hardened Runtime**: Required for notarization
/// - **Menu bar integration**: Expected by macOS users
/// - **Keyboard shortcuts**: Standard shortcuts expected (Cmd+S, Cmd+Z, etc.)
///
/// ## Related Documentation
///
/// - [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
/// - [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
/// - [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
/// - [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// macOS-Specific Rules
// =============================================================================

/// Suggests using PlatformMenuBar for native macOS menu integration.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS apps should integrate with the system menu bar for a native
/// experience. `PlatformMenuBar` provides this integration in Flutter.
///
/// ## Why This Matters
///
/// macOS users expect:
/// - File, Edit, View menus
/// - Window menu for window management
/// - Help menu with search
///
/// Without native menus, the app feels out of place on macOS.
///
/// ## Detection Strategy
///
/// This rule only fires for files that appear to be macOS-specific
/// (contain Platform.isMacOS, TargetPlatform.macOS, or window_manager imports).
/// It checks if `PlatformMenuBar` is used anywhere in the file.
///
/// ## Example
///
/// **Without PlatformMenuBar:**
/// ```dart
/// MaterialApp(home: MyHomePage())
/// ```
///
/// **With PlatformMenuBar:**
/// ```dart
/// MaterialApp(
///   home: PlatformMenuBar(
///     menus: [
///       PlatformMenu(
///         label: 'File',
///         menus: [
///           PlatformMenuItem(
///             label: 'New',
///             shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
///             onSelected: () => createNewDocument(),
///           ),
///         ],
///       ),
///     ],
///     child: Scaffold(...),
///   ),
/// )
/// ```
///
/// @see [PlatformMenuBar class](https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html)
class PreferMacosMenuBarIntegrationRule extends SaropaLintRule {
  /// Creates a new instance of [PreferMacosMenuBarIntegrationRule].
  const PreferMacosMenuBarIntegrationRule() : super(code: _code);

  /// Missing menu bar is a UX issue, not critical.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_macos_menu_bar_integration',
    problemMessage:
        '[prefer_macos_menu_bar_integration] macOS apps should use PlatformMenuBar for native menu integration. macOS apps should integrate with the system menu bar for a native experience. PlatformMenuBar provides this integration in Flutter. {v2}',
    correctionMessage:
        'Add PlatformMenuBar with standard macOS menus (File, Edit, View, etc.). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // First, check if this appears to be a macOS app
    final String fileSource = resolver.source.contents.data;
    final bool isMacosApp = fileSource.contains('Platform.isMacOS') ||
        fileSource.contains('TargetPlatform.macOS') ||
        fileSource.contains('window_manager') ||
        fileSource.contains('WindowManager');

    if (!isMacosApp) {
      return;
    }

    // Check if PlatformMenuBar is used anywhere in the file
    final bool hasPlatformMenuBar = fileSource.contains('PlatformMenuBar');

    if (hasPlatformMenuBar) {
      return;
    }

    // Find MaterialApp or CupertinoApp and report
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName == 'MaterialApp' || node.typeName == 'CupertinoApp') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Suggests implementing standard macOS keyboard shortcuts.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS users expect standard keyboard shortcuts like Cmd+S (Save),
/// Cmd+Z (Undo), Cmd+C/V/X (Copy/Paste/Cut). Flutter provides `Shortcuts`
/// and `CallbackShortcuts` widgets to implement these.
///
/// ## Why This Matters
///
/// macOS power users rely heavily on keyboard shortcuts:
/// - Cmd+S: Save
/// - Cmd+Z/Shift+Cmd+Z: Undo/Redo
/// - Cmd+C/V/X: Copy/Paste/Cut
/// - Cmd+A: Select All
/// - Cmd+W: Close Window
/// - Cmd+Q: Quit
///
/// Apps without shortcuts feel incomplete on macOS.
///
/// ## Example
///
/// **Without shortcuts:**
/// ```dart
/// MaterialApp(home: MyHomePage())
/// ```
///
/// **With shortcuts:**
/// ```dart
/// MaterialApp(
///   home: Shortcuts(
///     shortcuts: {
///       LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
///           SaveIntent(),
///     },
///     child: Actions(
///       actions: {
///         SaveIntent: CallbackAction<SaveIntent>(
///           onInvoke: (intent) => saveDocument(),
///         ),
///       },
///       child: MyHomePage(),
///     ),
///   ),
/// )
/// ```
///
/// @see [Shortcuts class](https://api.flutter.dev/flutter/widgets/Shortcuts-class.html)
class PreferMacosKeyboardShortcutsRule extends SaropaLintRule {
  /// Creates a new instance of [PreferMacosKeyboardShortcutsRule].
  const PreferMacosKeyboardShortcutsRule() : super(code: _code);

  /// Missing shortcuts is a UX issue, not critical.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_macos_keyboard_shortcuts',
    problemMessage:
        '[prefer_macos_keyboard_shortcuts] macOS apps should implement standard keyboard shortcuts. macOS users expect standard keyboard shortcuts like Cmd+S (Save), Cmd+Z (Undo), Cmd+C/V/X (Copy/Paste/Cut). Flutter provides Shortcuts and CallbackShortcuts widgets to implement these. {v2}',
    correctionMessage:
        'Use Shortcuts widget with common macOS shortcuts (Cmd+S, Cmd+Z, etc.). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // First, check if this appears to be a macOS app
    final String fileSource = resolver.source.contents.data;
    final bool isMacosApp = fileSource.contains('Platform.isMacOS') ||
        fileSource.contains('TargetPlatform.macOS') ||
        fileSource.contains('window_manager') ||
        fileSource.contains('WindowManager');

    if (!isMacosApp) {
      return;
    }

    // Check if Shortcuts widget is used anywhere in the file
    final bool hasShortcuts = fileSource.contains('Shortcuts') ||
        fileSource.contains('CallbackShortcuts') ||
        fileSource.contains('LogicalKeySet');

    if (hasShortcuts) {
      return;
    }

    // Find MaterialApp or CupertinoApp and report
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName == 'MaterialApp' || node.typeName == 'CupertinoApp') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS apps lack window size constraints.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS windows can be resized freely by default. Without minimum/maximum
/// size constraints, windows can become unusably small or excessively large.
///
/// ## Why This Matters
///
/// Without size constraints:
/// - Users can resize window to 1x1 pixel
/// - Layout breaks at extreme sizes
/// - Content becomes unreadable or unusable
///
/// ## Example
///
/// **Without constraints:**
/// ```dart
/// void main() {
///   runApp(MyApp());
/// }
/// ```
///
/// **With constraints:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await windowManager.ensureInitialized();
///
///   WindowOptions windowOptions = WindowOptions(
///     minimumSize: Size(400, 300),
///     maximumSize: Size(1920, 1080),
///   );
///   windowManager.waitUntilReadyToShow(windowOptions);
///
///   runApp(MyApp());
/// }
/// ```
///
/// @see [window_manager package](https://pub.dev/packages/window_manager)
class RequireMacosWindowSizeConstraintsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosWindowSizeConstraintsRule].
  const RequireMacosWindowSizeConstraintsRule() : super(code: _code);

  /// Missing constraints affects UX but isn't critical.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_macos_window_size_constraints',
    problemMessage:
        '[require_macos_window_size_constraints] macOS app without window size constraints may resize to unusable '
        'dimensions. {v2}',
    correctionMessage:
        'Use window_manager package to set minimum/maximum window size.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // First, check if this appears to be a macOS app
    final String fileSource = resolver.source.contents.data;
    final bool isMacosApp = fileSource.contains('Platform.isMacOS') ||
        fileSource.contains('TargetPlatform.macOS') ||
        fileSource.contains('window_manager');

    if (!isMacosApp) {
      return;
    }

    // Check for window size constraint patterns
    final bool hasConstraints = fileSource.contains('setMinimumSize') ||
        fileSource.contains('setMaximumSize') ||
        fileSource.contains('minimumSize') ||
        fileSource.contains('WindowOptions');

    if (hasConstraints) {
      return;
    }

    // Find main function and report
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme == 'main') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS file access may require user intent.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS sandboxed apps can only access files the user explicitly chooses
/// (via file picker or drag-and-drop), not arbitrary file paths.
///
/// ## Protected Locations
///
/// - Files in ~/Documents, ~/Downloads (without entitlement)
/// - Files on external drives
///
/// ## What Doesn't Require User Intent
///
/// - App's own container (Application Support, Caches, etc.)
/// - Files explicitly opened via file picker
/// - Files with read/write entitlements
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Direct path access fails in sandbox
/// final file = File('/Users/name/Documents/file.txt');
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use file picker for user intent
/// final result = await FilePicker.platform.pickFiles();
/// if (result != null) {
///   final file = File(result.files.single.path!);
/// }
/// ```
///
/// @see [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
/// @see [file_picker](https://pub.dev/packages/file_picker)
class RequireMacosFileAccessIntentRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosFileAccessIntentRule].
  const RequireMacosFileAccessIntentRule() : super(code: _code);

  /// Sandbox violations cause silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_macos_file_access_intent',
    problemMessage:
        '[require_macos_file_access_intent] Direct file path access detected. macOS sandboxed apps require '
        'user intent (file picker, drag-drop) for file access. {v2}',
    correctionMessage:
        'Use FilePicker or drag-and-drop for user-selected files. '
        'Or add appropriate entitlements for specific directories.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// User home directory patterns that indicate potential sandbox issues.
  static const List<String> _userPathPatterns = [
    '/Users/',
    '~/Documents',
    '~/Downloads',
    '~/Desktop',
    '~/Pictures',
    '~/Music',
    '~/Movies',
    'NSHomeDirectory',
    'homeDirectory',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip if in test file
      final String filePath = resolver.source.fullName;
      if (filePath.contains('_test.dart') || filePath.contains('/test/')) {
        return;
      }

      for (final String pattern in _userPathPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when deprecated macOS Security framework APIs are used.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS Security framework has deprecated several APIs that may cause
/// issues with notarization or future macOS versions.
///
/// ## Deprecated APIs
///
/// | Deprecated | Replacement |
/// |------------|-------------|
/// | SecKeychainItemCopyContent | SecItemCopyMatching |
/// | SecKeychainAddGenericPassword | SecItemAdd |
/// | SecKeychainFindGenericPassword | SecItemCopyMatching |
/// | SecTrustedApplicationCreateFromPath | Code signing |
///
/// ## Why This Matters
///
/// - Notarization may fail with deprecated APIs
/// - Future macOS versions may remove deprecated APIs
/// - Modern APIs are more secure
///
/// @see [Security Framework](https://developer.apple.com/documentation/security)
class AvoidMacosDeprecatedSecurityApisRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidMacosDeprecatedSecurityApisRule].
  const AvoidMacosDeprecatedSecurityApisRule() : super(code: _code);

  /// Deprecated APIs may cause notarization issues.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_macos_deprecated_security_apis',
    problemMessage:
        '[avoid_macos_deprecated_security_apis] Deprecated macOS Security API detected. Use modern equivalents. macOS Security framework has deprecated several APIs that may cause issues with notarization or future macOS versions. {v2}',
    correctionMessage:
        'Replace deprecated Keychain APIs with SecItem* functions. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Deprecated Security framework APIs.
  static const Set<String> _deprecatedSecurityApis = {
    'SecKeychainItemCopyContent',
    'SecKeychainAddGenericPassword',
    'SecKeychainFindGenericPassword',
    'SecKeychainItemModifyContent',
    'SecTrustedApplicationCreateFromPath',
    'SecACLCreateFromSimpleContents',
    'SecAccessCreate',
    'SecKeychainItemCopyAccess',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String api in _deprecatedSecurityApis) {
        if (value.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_deprecatedSecurityApis.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS app may not meet Hardened Runtime requirements.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS apps distributed outside the Mac App Store must be notarized,
/// which requires Hardened Runtime. Certain operations are blocked
/// unless you have specific entitlements.
///
/// ## Blocked Without Entitlements
///
/// | Operation | Required Entitlement |
/// |-----------|---------------------|
/// | JIT compilation | com.apple.security.cs.allow-jit |
/// | Unsigned code | com.apple.security.cs.disable-library-validation |
/// | Debug | com.apple.security.get-task-allow |
/// | Camera | com.apple.security.device.camera |
/// | Microphone | com.apple.security.device.audio-input |
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// // Dynamic library loading may require entitlement
/// DynamicLibrary.open('libcustom.dylib');
/// ```
///
/// @see [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
class RequireMacosHardenedRuntimeRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosHardenedRuntimeRule].
  const RequireMacosHardenedRuntimeRule() : super(code: _code);

  /// Hardened Runtime issues block notarization.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_macos_hardened_runtime',
    problemMessage:
        '[require_macos_hardened_runtime] Operation detected that may require Hardened Runtime entitlement. '
        'Ensure proper entitlements are configured for notarization. {v2}',
    correctionMessage:
        'Add required entitlements in macos/Runner/Release.entitlements.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Operations requiring Hardened Runtime entitlements.
  static const Set<String> _sensitiveOperations = {
    'DynamicLibrary',
    'dlopen',
    'dlsym',
    'Process.run',
    'Process.start',
    'FFI',
    'NativeFunction',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final Expression? target = node.target;

      // Check for Process.run, DynamicLibrary.open, etc.
      if (target != null) {
        final String targetSource = target.toSource();
        for (final String op in _sensitiveOperations) {
          if (targetSource.contains(op)) {
            reporter.atNode(node, code);
            hasReported = true;
            return;
          }
        }
      }
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;

      for (final String op in _sensitiveOperations) {
        if (typeName.contains(op)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when Mac Catalyst unsupported APIs may be used.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Mac Catalyst allows iOS apps to run on macOS, but not all iOS APIs
/// are available. Using unavailable APIs causes crashes on Mac Catalyst.
///
/// ## Unavailable on Mac Catalyst
///
/// - ARKit (augmented reality)
/// - CallKit (phone calls)
/// - CarPlay
/// - HealthKit
/// - HomeKit
/// - NFC
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // ARKit crashes on Mac Catalyst
/// await ARKitController.create();
/// ```
///
/// **GOOD:**
/// ```dart
/// if (!Platform.isMacOS) {
///   await ARKitController.create();
/// }
/// ```
///
/// @see [Mac Catalyst](https://developer.apple.com/documentation/uikit/mac_catalyst)
class AvoidMacosCatalystUnsupportedApisRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidMacosCatalystUnsupportedApisRule].
  const AvoidMacosCatalystUnsupportedApisRule() : super(code: _code);

  /// Unsupported APIs crash on Mac Catalyst.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_macos_catalyst_unsupported_apis',
    problemMessage:
        '[avoid_macos_catalyst_unsupported_apis] API detected that is not available on Mac Catalyst. '
        'Add platform check if supporting Mac Catalyst. {v2}',
    correctionMessage:
        'Wrap with Platform.isMacOS check or use kIsWeb/defaultTargetPlatform.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// APIs unavailable on Mac Catalyst.
  static const Set<String> _unsupportedApis = {
    'ARKit',
    'ARSession',
    'ARView',
    'ARKitController',
    'CallKit',
    'CXProvider',
    'CXCallController',
    'CarPlay',
    'CPTemplate',
    'HealthKit',
    'HKHealthStore',
    'HomeKit',
    'HMHome',
    'HMHomeManager',
    'CoreNFC',
    'NFCTagReaderSession',
    'NFCNDEFReaderSession',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      for (final String api in _unsupportedApis) {
        if (typeName.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;

      if (target != null) {
        final String targetSource = target.toSource();
        for (final String api in _unsupportedApis) {
          if (targetSource.contains(api)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when macOS window restoration may not be implemented.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS users expect window position and size to be restored between
/// app launches. Apps should implement NSWindowRestoration or equivalent.
class RequireMacosWindowRestorationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosWindowRestorationRule].
  const RequireMacosWindowRestorationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_macos_window_restoration',
    problemMessage:
        '[require_macos_window_restoration] macOS window configuration detected. Consider implementing window '
        'state restoration for better UX. {v2}',
    correctionMessage:
        'Save and restore window position/size using SharedPreferences '
        'or window_manager package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if restoration is implemented
    if (fileSource.contains('windowPosition') ||
        fileSource.contains('windowSize') ||
        fileSource.contains('restoreWindow') ||
        fileSource.contains('saveWindowState')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target != null && target.toSource().contains('windowManager')) {
        final String methodName = node.methodName.name;
        if (methodName == 'setSize' || methodName == 'setPosition') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when macOS app may need Full Disk Access alternatives.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Full Disk Access requires user interaction in System Preferences.
/// Apps should use scoped file access (NSOpenPanel) when possible.
class AvoidMacosFullDiskAccessRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidMacosFullDiskAccessRule].
  const AvoidMacosFullDiskAccessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_macos_full_disk_access',
    problemMessage:
        '[avoid_macos_full_disk_access] Accessing protected paths detected. Consider using NSOpenPanel '
        'for user-selected file access instead of Full Disk Access. {v2}',
    correctionMessage:
        'Use file_picker or NSOpenPanel to let users choose files '
        'instead of requiring Full Disk Access.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _protectedPaths = {
    '/Users/',
    '~/Library/',
    '~/Documents/',
    '~/Desktop/',
    '~/Downloads/',
    '/Library/',
    '/Applications/',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      for (final String path in _protectedPaths) {
        if (value.startsWith(path)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when macOS sandbox entitlements may be missing.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS App Store apps must be sandboxed. Network, file, and
/// hardware access require specific entitlements.
///
/// ## Common Entitlements
///
/// - com.apple.security.network.client (outgoing network)
/// - com.apple.security.network.server (incoming network)
/// - com.apple.security.files.user-selected.read-only
/// - com.apple.security.device.camera
class RequireMacosSandboxEntitlementsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosSandboxEntitlementsRule].
  const RequireMacosSandboxEntitlementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_macos_sandbox_entitlements',
    problemMessage:
        '[require_macos_sandbox_entitlements] Feature requiring macOS sandbox entitlement detected. '
        'Ensure entitlements file includes required permissions. {v2}',
    correctionMessage:
        'Add required entitlements to macOS/Runner/Release.entitlements.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;

      // Check for network access
      if (methodName == 'get' ||
          methodName == 'post' ||
          methodName == 'fetch') {
        final Expression? target = node.target;
        if (target != null &&
            (target.toSource().contains('http') ||
                target.toSource().contains('dio'))) {
          reporter.atNode(node, code);
          hasReported = true;
        }
      }
    });
  }
}

/// Warns when macOS sandbox entitlements may be needed.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS App Store apps must be sandboxed. Certain features require
/// explicit entitlements in the sandbox configuration.
///
/// ## Why This Matters
///
/// - App Store rejection without proper entitlements
/// - Runtime crashes when accessing restricted resources
/// - Security model requires explicit permissions
///
/// ## Required Entitlements
///
/// - `com.apple.security.network.client`: Outgoing network connections
/// - `com.apple.security.network.server`: Incoming connections
/// - `com.apple.security.files.user-selected.read-write`: User-selected files
/// - `com.apple.security.device.camera`: Camera access
/// - `com.apple.security.device.microphone`: Microphone access
///
/// ## Example
///
/// Add to `macos/Runner/Release.entitlements`:
/// ```xml
/// <key>com.apple.security.network.client</key>
/// <true/>
/// ```
///
/// @see [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
class RequireMacosSandboxExceptionsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosSandboxExceptionsRule].
  const RequireMacosSandboxExceptionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_macos_sandbox_exceptions',
    problemMessage:
        '[require_macos_sandbox_exceptions] Feature requiring macOS sandbox entitlement detected. '
        'App Store apps must declare entitlements. {v2}',
    correctionMessage:
        'Add the required entitlement to macos/Runner/Release.entitlements.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if not desktop-related
    if (!fileSource.contains('Platform.isMacOS') &&
        !fileSource.contains('macos') &&
        !fileSource.contains('desktop')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect network calls
      if (methodName == 'get' || methodName == 'post' || methodName == 'send') {
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource();
          if (targetSource.contains('http') ||
              targetSource.contains('Http') ||
              targetSource.contains('Dio')) {
            reporter.atNode(node, code);
          }
        }
      }

      // Detect camera/microphone
      if (methodName.contains('Camera') ||
          methodName.contains('Microphone') ||
          methodName.contains('startRecording')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when code may violate macOS Hardened Runtime requirements.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS apps must enable Hardened Runtime for notarization. Certain
/// operations (like code injection) are blocked.
///
/// ## Why This Matters
///
/// - Notarization required for distribution
/// - Code injection blocked by default
/// - JIT compilation requires entitlement
///
/// ## Example
///
/// **BLOCKED:**
/// ```dart
/// // Dynamic library loading from arbitrary paths
/// DynamicLibrary.open('/path/to/unsigned.dylib');
/// ```
///
/// **ALLOWED:**
/// ```dart
/// // Use bundled, signed libraries
/// DynamicLibrary.open('libfoo.dylib'); // From app bundle
/// ```
///
/// @see [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
class AvoidMacosHardenedRuntimeViolationsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidMacosHardenedRuntimeViolationsRule].
  const AvoidMacosHardenedRuntimeViolationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_macos_hardened_runtime_violations',
    problemMessage:
        '[avoid_macos_hardened_runtime_violations] Pattern detected that may violate macOS Hardened Runtime. '
        'Apps must pass notarization for distribution. {v2}',
    correctionMessage:
        'Avoid loading unsigned dynamic libraries or using JIT compilation '
        'without the appropriate entitlement.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect dynamic library loading with paths
      if (methodName == 'open') {
        final Expression? target = node.target;
        if (target != null && target.toSource() == 'DynamicLibrary') {
          // Check if path is absolute
          final List<Expression> args =
              node.argumentList.arguments.whereType<Expression>().toList();
          if (args.isNotEmpty) {
            final String pathArg = args.first.toSource();
            if (pathArg.contains('/') && !pathArg.contains('Frameworks')) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when macOS App Transport Security is needed.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Like iOS, macOS enforces ATS (App Transport Security). HTTP connections
/// need explicit exceptions in Info.plist.
///
/// ## Why This Matters
///
/// - HTTP blocked by default on macOS
/// - Same rules as iOS ATS
/// - Security requirement for App Store
///
/// ## Example
///
/// Add to `macos/Runner/Info.plist` for exceptions:
/// ```xml
/// <key>NSAppTransportSecurity</key>
/// <dict>
///   <key>NSAllowsLocalNetworking</key>
///   <true/>
/// </dict>
/// ```
///
/// @see [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
class RequireMacosAppTransportSecurityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosAppTransportSecurityRule].
  const RequireMacosAppTransportSecurityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_macos_app_transport_security',
    problemMessage:
        '[require_macos_app_transport_security] HTTP URL detected. macOS enforces App Transport Security. '
        'Use HTTPS or declare exception in Info.plist. {v2}',
    correctionMessage:
        'Change to HTTPS or add NSAppTransportSecurity exception '
        'in macos/Runner/Info.plist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if not desktop-related
    if (!fileSource.contains('Platform.isMacOS') &&
        !fileSource.contains('macos')) {
      return;
    }

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (value.startsWith('http://') &&
          !value.startsWith('http://localhost') &&
          !value.startsWith('http://127.0.0.1')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Reminds about notarization requirements for macOS distribution.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS apps must be notarized for distribution. This requires proper
/// code signing and Hardened Runtime.
///
/// ## Why This Matters
///
/// - Apps without notarization show security warnings
/// - Required for macOS 10.15+
/// - Blocks app launch on some systems
///
/// ## Requirements
///
/// 1. Apple Developer account
/// 2. Code signing certificate
/// 3. Hardened Runtime enabled
/// 4. No notarization issues reported
///
/// ## Example
///
/// ```bash
/// # Notarize app
/// xcrun notarytool submit MyApp.app --apple-id <email> --team-id <team>
/// ```
///
/// @see [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
class RequireMacosNotarizationReadyRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosNotarizationReadyRule].
  const RequireMacosNotarizationReadyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_macos_notarization_ready',
    problemMessage:
        '[require_macos_notarization_ready] macOS app detected. Ensure notarization is configured for distribution. '
        'Apps without notarization show security warnings. {v2}',
    correctionMessage:
        'Configure code signing, enable Hardened Runtime, and notarize '
        'the app before distribution.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Only check main.dart for macOS apps
    final String filePath = resolver.source.fullName;
    if (!filePath.endsWith('main.dart')) {
      return;
    }

    if (!fileSource.contains('Platform.isMacOS') &&
        !fileSource.contains('macos')) {
      return;
    }

    // Only report once at the start of main
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme == 'main') {
        // Check for comment about notarization
        final String surroundingSource = fileSource.substring(
          node.offset > 200 ? node.offset - 200 : 0,
          node.offset,
        );
        if (!surroundingSource.contains('notariz') &&
            !surroundingSource.contains('code sign')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when features requiring macOS entitlements are used.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// macOS sandboxed apps require entitlements for many features. Detect
/// usage without corresponding entitlement configuration.
///
/// ## Why This Matters
///
/// - Runtime crashes without entitlements
/// - App Store rejection
/// - Security model enforcement
///
/// ## Common Entitlements
///
/// | Feature | Entitlement |
/// |---------|-------------|
/// | Network | `com.apple.security.network.client` |
/// | Camera | `com.apple.security.device.camera` |
/// | Microphone | `com.apple.security.device.microphone` |
/// | Location | `com.apple.security.personal-information.location` |
/// | USB | `com.apple.security.device.usb` |
///
/// @see [Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
class RequireMacosEntitlementsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosEntitlementsRule].
  const RequireMacosEntitlementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_macos_entitlements',
    problemMessage:
        '[require_macos_entitlements] Feature detected that requires macOS entitlement. '
        'Sandboxed apps crash without proper entitlements. {v2}',
    correctionMessage:
        'Add the required entitlement to macos/Runner/Release.entitlements '
        'and macos/Runner/DebugProfile.entitlements.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if not desktop-related
    if (!fileSource.contains('Platform.isMacOS') &&
        !fileSource.contains('macos') &&
        !fileSource.contains('desktop')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final String nodeSource = node.toSource().toLowerCase();

      // Detect USB access
      if (methodName == 'getDevices' || methodName == 'openDevice') {
        if (nodeSource.contains('usb')) {
          reporter.atNode(node, code);
        }
      }

      // Detect Bluetooth
      if (methodName == 'startScan' || methodName == 'connect') {
        if (nodeSource.contains('bluetooth') || nodeSource.contains('ble')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}
