// ignore_for_file: depend_on_referenced_packages

/// iOS and macOS platform-specific lint rules for Flutter applications.
///
/// These rules help ensure Flutter apps follow Apple platform best practices,
/// handle iOS/macOS-specific requirements, and avoid common App Store rejection
/// reasons.
///
/// ## iOS App Store Requirements
///
/// Apple has strict requirements for iOS apps including:
/// - **Info.plist usage descriptions**: Camera, location, microphone, etc.
/// - **App Transport Security (ATS)**: HTTPS required unless exceptions declared
/// - **Privacy Manifest (iOS 17+)**: Required reason APIs must be declared
/// - **Sign in with Apple**: Required if other social logins are offered
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
/// - [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
/// - [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
/// - [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
/// - [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
/// - [Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// iOS-Specific Rules
// =============================================================================

/// Warns when Scaffold body is not wrapped in SafeArea.
///
/// iOS devices have notches (iPhone X+), Dynamic Islands (iPhone 14 Pro+),
/// and home indicators that can overlap content. SafeArea ensures content
/// is visible and interactive on all iOS devices.
///
/// ## Why This Matters
///
/// Without SafeArea:
/// - Content may be hidden behind the notch or Dynamic Island
/// - Interactive elements may be unreachable near the home indicator
/// - The app looks unprofessional on modern iOS devices
///
/// ## Exceptions
///
/// This rule does NOT flag:
/// - Bodies already wrapped in SafeArea
/// - ListView, CustomScrollView, NestedScrollView (handle safe area via slivers)
/// - SingleChildScrollView (can use SafeArea internally)
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       Text('Header'), // May be hidden behind notch
///     ],
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(
///   body: SafeArea(
///     child: Column(
///       children: [
///         Text('Header'),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// @see [SafeArea class](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
/// @see [MediaQuery.padding](https://api.flutter.dev/flutter/widgets/MediaQueryData/padding.html)
class PreferIosSafeAreaRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosSafeAreaRule].
  const PreferIosSafeAreaRule() : super(code: _code);

  /// UI overlap affects user experience but is not critical.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_safe_area',
    problemMessage:
        'Scaffold body without SafeArea may have content hidden by iOS notch '
        'or Dynamic Island.',
    correctionMessage:
        'Wrap body content with SafeArea to avoid UI overlap on iOS devices.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Widgets that handle safe area internally and don't need explicit SafeArea.
  static const Set<String> _safeAreaAwareWidgets = {
    'SafeArea',
    'ListView',
    'CustomScrollView',
    'NestedScrollView',
    'SingleChildScrollView',
    'GridView',
    'PageView',
    'TabBarView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Only check Scaffold widgets
      if (node.typeName != 'Scaffold') {
        return;
      }

      // Check if body parameter exists
      final Expression? bodyArg = node.getNamedParameterValue('body');
      if (bodyArg == null) {
        return;
      }

      // Check if body is a safe-area-aware widget
      if (bodyArg is InstanceCreationExpression) {
        final String bodyTypeName = bodyArg.typeName;
        if (_safeAreaAwareWidgets.contains(bodyTypeName)) {
          return; // Already handles safe area
        }
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapWithSafeAreaFix()];
}

/// Quick fix that wraps Scaffold body with SafeArea.
class _WrapWithSafeAreaFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      if (node.typeName != 'Scaffold') {
        return;
      }

      final Expression? bodyArg = node.getNamedParameterValue('body');
      if (bodyArg == null) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap body with SafeArea',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert SafeArea( before the body content
        builder.addSimpleInsertion(bodyArg.offset, 'SafeArea(child: ');
        // Insert ) after the body content
        builder.addSimpleInsertion(bodyArg.end, ')');
      });
    });
  }
}

/// Warns when hardcoded iOS status bar height values are used.
///
/// iOS status bar height varies significantly by device:
/// - **20pt**: iPhone 8 and earlier (pre-notch)
/// - **44pt**: iPhone X, XS, 11 Pro (notch)
/// - **47pt**: iPhone 12, 13, 14 (notch)
/// - **59pt**: iPhone 14 Pro, 15 Pro (Dynamic Island)
///
/// Hardcoding these values causes UI issues on different devices.
///
/// ## Why This Matters
///
/// Hardcoded status bar heights:
/// - Break on new device releases with different dimensions
/// - Cause inconsistent UI across device models
/// - Require app updates for each new iPhone release
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.only(top: 44), // Only works on iPhone X
/// )
///
/// SizedBox(height: 59) // Only works on iPhone 14 Pro
/// ```
///
/// **GOOD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
/// )
///
/// // Or use SafeArea which handles this automatically
/// SafeArea(child: YourWidget())
/// ```
///
/// @see [MediaQuery.padding](https://api.flutter.dev/flutter/widgets/MediaQueryData/padding.html)
class AvoidIosHardcodedStatusBarRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedStatusBarRule].
  const AvoidIosHardcodedStatusBarRule() : super(code: _code);

  /// Hardcoded values cause UI bugs on specific devices.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_hardcoded_status_bar',
    problemMessage:
        'Hardcoded status bar height (20, 44, 47, or 59) may cause UI issues '
        'on different iOS devices.',
    correctionMessage:
        'Use MediaQuery.of(context).padding.top for dynamic status bar height.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Known iOS status bar heights in logical pixels.
  ///
  /// These values are specific to iOS devices:
  /// - 20: Pre-notch iPhones (iPhone 8 and earlier)
  /// - 44: First-gen notch (iPhone X, XS, 11 Pro)
  /// - 47: Second-gen notch (iPhone 12, 13, 14 standard)
  /// - 59: Dynamic Island (iPhone 14 Pro, 15 Pro)
  static final Set<int> _statusBarHeights = <int>{20, 44, 47, 59};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Check EdgeInsets.only(top: XX)
      if (node.typeName == 'EdgeInsets') {
        final String? constructorName = node.constructorName.name?.name;
        if (constructorName == 'only') {
          _checkNumericArgument(node, 'top', reporter);
        }
      }

      // Check SizedBox(height: XX)
      if (node.typeName == 'SizedBox') {
        _checkNumericArgument(node, 'height', reporter);
      }

      // Check Container with padding
      if (node.typeName == 'Container') {
        final Expression? paddingArg = node.getNamedParameterValue('padding');
        if (paddingArg is InstanceCreationExpression &&
            paddingArg.typeName == 'EdgeInsets') {
          final String? paddingConstructor = paddingArg.constructorName.name?.name;
          if (paddingConstructor == 'only') {
            _checkNumericArgument(paddingArg, 'top', reporter);
          }
        }
      }
    });
  }

  /// Checks if a named parameter has a hardcoded status bar height value.
  void _checkNumericArgument(
    InstanceCreationExpression node,
    String paramName,
    SaropaDiagnosticReporter reporter,
  ) {
    final Expression? arg = node.getNamedParameterValue(paramName);
    if (arg == null) {
      return;
    }

    int? value;
    if (arg is IntegerLiteral) {
      value = arg.value;
    } else if (arg is DoubleLiteral) {
      // Only flag if it's a round number matching status bar heights
      final double doubleValue = arg.value;
      if (doubleValue == doubleValue.roundToDouble()) {
        value = doubleValue.toInt();
      }
    }

    if (value != null && _statusBarHeights.contains(value)) {
      reporter.atNode(arg, code);
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseMediaQueryPaddingFix()];
}

/// Quick fix that replaces hardcoded value with MediaQuery.padding.top.
class _UseMediaQueryPaddingFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use MediaQuery.of(context).padding.top',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'MediaQuery.of(context).padding.top',
        );
      });
    });

    context.registry.addDoubleLiteral((DoubleLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use MediaQuery.of(context).padding.top',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'MediaQuery.of(context).padding.top',
        );
      });
    });
  }
}

/// Suggests adding haptic feedback for important button interactions on iOS.
///
/// iOS provides rich haptic feedback through the Taptic Engine. Using
/// [HapticFeedback] improves user experience by providing tactile confirmation
/// of actions.
///
/// ## Why This Matters
///
/// Haptic feedback:
/// - Confirms button presses without looking at the screen
/// - Provides a premium feel expected by iOS users
/// - Improves accessibility for users with visual impairments
///
/// ## When to Use Haptic Feedback
///
/// - Form submissions
/// - Toggle switches
/// - Important actions (delete, confirm, etc.)
/// - Navigation gestures
///
/// ## Example
///
/// **Without haptic feedback:**
/// ```dart
/// ElevatedButton(
///   onPressed: () => submitForm(),
///   child: Text('Submit'),
/// )
/// ```
///
/// **With haptic feedback:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     HapticFeedback.mediumImpact();
///     submitForm();
///   },
///   child: Text('Submit'),
/// )
/// ```
///
/// @see [HapticFeedback class](https://api.flutter.dev/flutter/services/HapticFeedback-class.html)
class PreferIosHapticFeedbackRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosHapticFeedbackRule].
  const PreferIosHapticFeedbackRule() : super(code: _code);

  /// Haptic feedback is a nice-to-have UX enhancement.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_haptic_feedback',
    problemMessage:
        'Consider adding haptic feedback for important button interactions '
        'on iOS.',
    correctionMessage:
        'Use HapticFeedback.mediumImpact() or similar for tactile response.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Button types that typically benefit from haptic feedback.
  static const Set<String> _importantButtonTypes = <String>{
    'ElevatedButton',
    'FilledButton',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_importantButtonTypes.contains(node.typeName)) {
        return;
      }

      final Expression? onPressedArg = node.getNamedParameterValue('onPressed');
      if (onPressedArg == null) {
        return;
      }

      // Check if HapticFeedback is already used in the callback
      final String source = onPressedArg.toSource();
      if (source.contains('HapticFeedback')) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when iOS-specific MethodChannel calls lack Platform.isIOS guard.
///
/// Platform-specific MethodChannel calls should be wrapped in platform checks
/// to prevent runtime errors when running on unsupported platforms.
///
/// ## Why This Matters
///
/// Without platform checks:
/// - Code crashes on Android/Web/Desktop if iOS-specific channel is called
/// - MissingPluginException thrown at runtime
/// - Poor user experience on non-iOS platforms
///
/// ## Detection
///
/// This rule detects MethodChannel instantiations with names containing:
/// - `ios`
/// - `apple`
/// - `darwin`
/// - `cupertino`
/// - `uikit`
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// final channel = MethodChannel('com.example/ios_feature');
/// final result = await channel.invokeMethod('doThing');
/// ```
///
/// **GOOD:**
/// ```dart
/// if (Platform.isIOS) {
///   final channel = MethodChannel('com.example/ios_feature');
///   final result = await channel.invokeMethod('doThing');
/// }
/// ```
///
/// @see [Platform class](https://api.flutter.dev/flutter/dart-io/Platform-class.html)
/// @see [MethodChannel class](https://api.flutter.dev/flutter/services/MethodChannel-class.html)
class RequireIosPlatformCheckRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPlatformCheckRule].
  const RequireIosPlatformCheckRule() : super(code: _code);

  /// Missing platform checks can cause crashes.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_platform_check',
    problemMessage:
        'iOS-specific MethodChannel without Platform.isIOS check may crash '
        'on other platforms.',
    correctionMessage:
        'Wrap iOS-specific code with if (Platform.isIOS) check.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns in channel names that suggest iOS-specific functionality.
  static const Set<String> _iosChannelPatterns = <String>{
    'ios',
    'apple',
    'darwin',
    'cupertino',
    'uikit',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName != 'MethodChannel') {
        return;
      }

      // Get the channel name argument (first positional argument)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) {
        return;
      }

      final Expression firstArg = args.first;
      if (firstArg is! StringLiteral) {
        return;
      }

      final String channelName = firstArg.stringValue?.toLowerCase() ?? '';

      // Check if channel name suggests iOS-specific functionality
      bool isIosSpecific = false;
      for (final String pattern in _iosChannelPatterns) {
        if (channelName.contains(pattern)) {
          isIosSpecific = true;
          break;
        }
      }

      if (!isIosSpecific) {
        return;
      }

      // Check if wrapped in Platform.isIOS check by walking up the tree
      if (_isInsidePlatformCheck(node)) {
        return;
      }

      reporter.atNode(node, code);
    });
  }

  /// Checks if the node is inside a Platform.isIOS/isMacOS conditional.
  bool _isInsidePlatformCheck(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('Platform.isIOS') ||
            condition.contains('Platform.isMacOS') ||
            condition.contains('defaultTargetPlatform') ||
            condition.contains('kIsWeb')) {
          return true;
        }
      }
      // Also check ternary expressions
      if (current is ConditionalExpression) {
        final String condition = current.condition.toSource();
        if (condition.contains('Platform.isIOS') ||
            condition.contains('Platform.isMacOS')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Future.delayed exceeds iOS background fetch time limits.
///
/// iOS terminates background tasks after approximately 30 seconds. Using
/// [Future.delayed] with durations exceeding this limit in background
/// contexts will result in incomplete execution.
///
/// ## Why This Matters
///
/// iOS background execution limits:
/// - Background fetch: ~30 seconds maximum
/// - Background URLSession: System managed
/// - Push notification handling: ~30 seconds
///
/// Tasks exceeding these limits are terminated by iOS, potentially leaving
/// operations incomplete.
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// void backgroundTask() async {
///   await Future.delayed(Duration(minutes: 5)); // Will be killed by iOS
///   await syncAllData();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void backgroundTask() async {
///   await syncIncrementalData(); // Complete within 30 seconds
/// }
/// ```
///
/// @see [iOS Background Execution](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background)
class AvoidIosBackgroundFetchAbuseRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosBackgroundFetchAbuseRule].
  const AvoidIosBackgroundFetchAbuseRule() : super(code: _code);

  /// Exceeding background limits causes incomplete operations.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_background_fetch_abuse',
    problemMessage:
        'Future.delayed duration exceeds iOS 30-second background limit.',
    correctionMessage:
        'Design background tasks to complete within iOS time limits '
        '(~30 seconds).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// iOS background task time limit in seconds.
  static const int _iosBackgroundLimitSeconds = 30;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Future.delayed
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Future') {
        return;
      }

      if (node.methodName.name != 'delayed') {
        return;
      }

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) {
        return;
      }

      final Expression durationArg = args.first;
      if (durationArg is! InstanceCreationExpression) {
        return;
      }

      if (durationArg.typeName != 'Duration') {
        return;
      }

      // Calculate total seconds from duration arguments
      int totalSeconds = 0;

      final Expression? minutesArg =
          durationArg.getNamedParameterValue('minutes');
      if (minutesArg is IntegerLiteral) {
        totalSeconds += (minutesArg.value ?? 0) * 60;
      }

      final Expression? secondsArg =
          durationArg.getNamedParameterValue('seconds');
      if (secondsArg is IntegerLiteral) {
        totalSeconds += secondsArg.value ?? 0;
      }

      final Expression? hoursArg = durationArg.getNamedParameterValue('hours');
      if (hoursArg is IntegerLiteral) {
        totalSeconds += (hoursArg.value ?? 0) * 3600;
      }

      if (totalSeconds > _iosBackgroundLimitSeconds) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// macOS-Specific Rules
// =============================================================================

/// Suggests using PlatformMenuBar for native macOS menu integration.
///
/// macOS apps should integrate with the system menu bar for a native
/// experience. [PlatformMenuBar] provides this integration in Flutter.
///
/// ## Why This Matters
///
/// macOS users expect:
/// - Standard menu bar with File, Edit, View, Window, Help menus
/// - Keyboard shortcuts accessible via menus
/// - Application menu with About, Preferences, Quit items
///
/// Without native menus, the app feels out of place on macOS.
///
/// ## Detection
///
/// This rule only fires for files that appear to be macOS-specific
/// (contain Platform.isMacOS, TargetPlatform.macOS, or window_manager imports).
///
/// ## Example
///
/// **Without native menus:**
/// ```dart
/// MaterialApp(
///   home: Scaffold(
///     appBar: AppBar(title: Text('My App')),
///   ),
/// )
/// ```
///
/// **With native menus:**
/// ```dart
/// MaterialApp(
///   home: PlatformMenuBar(
///     menus: [
///       PlatformMenu(
///         label: 'File',
///         menus: [
///           PlatformMenuItem(
///             label: 'New',
///             shortcut: SingleActivator(LogicalKeyboardKey.keyN, meta: true),
///             onSelected: () => createNew(),
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

  static const LintCode _code = LintCode(
    name: 'prefer_macos_menu_bar_integration',
    problemMessage:
        'macOS apps should use PlatformMenuBar for native menu integration.',
    correctionMessage:
        'Add PlatformMenuBar with standard macOS menus (File, Edit, View, etc.).',
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
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName == 'MaterialApp' || node.typeName == 'CupertinoApp') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Suggests implementing standard macOS keyboard shortcuts.
///
/// macOS users expect standard keyboard shortcuts like Cmd+S (Save),
/// Cmd+Z (Undo), Cmd+C/V/X (Copy/Paste/Cut). Flutter provides [Shortcuts]
/// and [CallbackShortcuts] widgets to implement these.
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

  static const LintCode _code = LintCode(
    name: 'prefer_macos_keyboard_shortcuts',
    problemMessage:
        'macOS apps should implement standard keyboard shortcuts.',
    correctionMessage:
        'Use Shortcuts widget with common macOS shortcuts (Cmd+S, Cmd+Z, etc.).',
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
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName == 'MaterialApp' || node.typeName == 'CupertinoApp') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS apps lack window size constraints.
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

  static const LintCode _code = LintCode(
    name: 'require_macos_window_size_constraints',
    problemMessage:
        'macOS app without window size constraints may resize to unusable '
        'dimensions.',
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

// =============================================================================
// Cross-Platform Apple Rules (iOS & macOS)
// =============================================================================

/// Warns when MethodChannel.invokeMethod is used without error handling.
///
/// Platform channels can fail on iOS/macOS for various reasons:
/// - Plugin not implemented on native side
/// - Permission denied
/// - Native exception thrown
/// - Invalid arguments
///
/// Always wrap platform channel calls in try-catch blocks.
///
/// ## Why This Matters
///
/// Unhandled PlatformException:
/// - Crashes the app
/// - Provides poor user experience
/// - May lose user data
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// final result = await channel.invokeMethod('getData');
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final result = await channel.invokeMethod('getData');
///   return result;
/// } on PlatformException catch (e) {
///   debugPrint('Platform error: ${e.message}');
///   return null;
/// }
/// ```
///
/// @see [PlatformException class](https://api.flutter.dev/flutter/services/PlatformException-class.html)
class RequireMethodChannelErrorHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMethodChannelErrorHandlingRule].
  const RequireMethodChannelErrorHandlingRule() : super(code: _code);

  /// Unhandled platform errors cause crashes.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_method_channel_error_handling',
    problemMessage:
        'MethodChannel.invokeMethod without error handling may crash on '
        'iOS/macOS.',
    correctionMessage: 'Wrap in try-catch and handle PlatformException.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Method names on MethodChannel that require error handling.
  static const Set<String> _invokeMethodNames = <String>{
    'invokeMethod',
    'invokeListMethod',
    'invokeMapMethod',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_invokeMethodNames.contains(node.methodName.name)) {
        return;
      }

      // Check if this looks like a MethodChannel call
      final Expression? target = node.target;
      if (target == null) {
        return;
      }

      // Check if wrapped in try-catch
      if (_isInsideTryCatch(node)) {
        return;
      }

      reporter.atNode(node, code);
    });
  }

  /// Checks if the node is inside a try-catch block with appropriate handling.
  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        // Check if it catches any exception type
        for (final CatchClause catchClause in current.catchClauses) {
          final TypeAnnotation? exceptionType = catchClause.exceptionType;
          // Accept: catch (e), catch (PlatformException e), catch (Exception e)
          if (exceptionType == null) {
            return true; // Bare catch catches everything
          }
          final String typeSource = exceptionType.toSource();
          if (typeSource.contains('PlatformException') ||
              typeSource.contains('Exception') ||
              typeSource == 'Object') {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapWithTryCatchFix()];
}

/// Quick fix that wraps the invokeMethod call with try-catch.
class _WrapWithTryCatchFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      // Find the await expression or expression statement containing this
      AstNode? statementNode = node.parent;
      while (statementNode != null &&
          statementNode is! ExpressionStatement &&
          statementNode is! VariableDeclarationStatement) {
        statementNode = statementNode.parent;
      }

      if (statementNode == null) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap with try-catch',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          statementNode!.offset,
          'try {\n  ',
        );
        builder.addSimpleInsertion(
          statementNode.end,
          '\n} on PlatformException catch (e) {\n'
          '  // TODO: Handle platform error\n'
          '  debugPrint(\'Platform error: \${e.message}\');\n'
          '}',
        );
      });
    });
  }
}

/// Reminds to validate iOS Universal Links server configuration.
///
/// iOS Universal Links (and Android App Links) require proper server-side
/// configuration:
/// - **iOS**: apple-app-site-association file at /.well-known/
/// - **Android**: assetlinks.json at /.well-known/
///
/// This rule flags parameterized routes in go_router as a reminder to
/// verify server configuration.
///
/// ## Why This Matters
///
/// Without proper server configuration:
/// - Deep links open in Safari instead of the app
/// - Universal Links fail silently
/// - Users have poor experience
///
/// ## Example
///
/// **Route that likely needs Universal Link configuration:**
/// ```dart
/// GoRoute(
///   path: '/product/:id',  // Parameterized route
///   builder: (context, state) => ProductPage(id: state.params['id']!),
/// )
/// ```
///
/// **Server configuration needed:**
/// ```json
/// // apple-app-site-association
/// {
///   "applinks": {
///     "apps": [],
///     "details": [{
///       "appID": "TEAM_ID.com.example.app",
///       "paths": ["/product/*"]
///     }]
///   }
/// }
/// ```
///
/// @see [Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
class RequireUniversalLinkValidationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireUniversalLinkValidationRule].
  const RequireUniversalLinkValidationRule() : super(code: _code);

  /// Server misconfiguration causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_universal_link_validation',
    problemMessage:
        'Deep link route may need iOS Universal Links server configuration.',
    correctionMessage:
        'Ensure apple-app-site-association is configured and test on real '
        'iOS device.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName != 'GoRoute') {
        return;
      }

      final Expression? pathArg = node.getNamedParameterValue('path');
      if (pathArg == null) {
        return;
      }

      // Check if path contains parameters (likely a deep link)
      final String pathSource = pathArg.toSource();
      // go_router uses :param syntax, also check for regex-style {param}
      if (!pathSource.contains(':') && !pathSource.contains(RegExp(r'\{[^}]+\}'))) {
        return; // Not a parameterized route
      }

      reporter.atNode(node, code);
    });
  }
}

/// Suggests using Cupertino widgets in iOS-specific code blocks.
///
/// When code explicitly checks for Platform.isIOS, using Material widgets
/// misses the opportunity to provide a native iOS experience. Cupertino
/// widgets match iOS design language.
///
/// ## Widget Mappings
///
/// | Material | Cupertino |
/// |----------|-----------|
/// | AlertDialog | CupertinoAlertDialog |
/// | CircularProgressIndicator | CupertinoActivityIndicator |
/// | Switch | CupertinoSwitch |
/// | Slider | CupertinoSlider |
/// | TextField | CupertinoTextField |
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// if (Platform.isIOS) {
///   return AlertDialog(
///     title: Text('Confirm'),
///     content: Text('Delete this item?'),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (Platform.isIOS) {
///   return CupertinoAlertDialog(
///     title: Text('Confirm'),
///     content: Text('Delete this item?'),
///   );
/// }
/// ```
///
/// @see [Cupertino widgets](https://docs.flutter.dev/ui/widgets/cupertino)
class PreferCupertinoForIosRule extends SaropaLintRule {
  /// Creates a new instance of [PreferCupertinoForIosRule].
  const PreferCupertinoForIosRule() : super(code: _code);

  /// Using non-native widgets is a UX preference.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_cupertino_for_ios',
    problemMessage:
        'Material widget in iOS-specific code block. Consider using '
        'Cupertino equivalent for native iOS feel.',
    correctionMessage:
        'Use CupertinoAlertDialog, CupertinoSwitch, etc. for native iOS feel.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Material widgets and their Cupertino equivalents.
  static const Map<String, String> _materialToCupertino = <String, String>{
    'AlertDialog': 'CupertinoAlertDialog',
    'SimpleDialog': 'CupertinoAlertDialog',
    'CircularProgressIndicator': 'CupertinoActivityIndicator',
    'Switch': 'CupertinoSwitch',
    'Slider': 'CupertinoSlider',
    'TextField': 'CupertinoTextField',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;
      if (!_materialToCupertino.containsKey(typeName)) {
        return;
      }

      // Check if inside Platform.isIOS block
      if (_isInsideIosPlatformCheck(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  /// Checks if node is inside a Platform.isIOS conditional.
  bool _isInsideIosPlatformCheck(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('Platform.isIOS') ||
            condition.contains('TargetPlatform.iOS')) {
          return true;
        }
      }
      if (current is ConditionalExpression) {
        final String condition = current.condition.toSource();
        if (condition.contains('Platform.isIOS')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when HTTP URLs are used that iOS App Transport Security will block.
///
/// iOS App Transport Security (ATS) blocks non-HTTPS connections by default.
/// HTTP URLs require explicit exceptions in Info.plist to function.
///
/// ## Why This Matters
///
/// Without ATS exceptions:
/// - HTTP requests fail silently or throw errors
/// - App appears broken to users
/// - Security is compromised if exceptions are added carelessly
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse('http://api.example.com/data'));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use HTTPS
/// final response = await http.get(Uri.parse('https://api.example.com/data'));
/// ```
///
/// **If HTTP is required (add to Info.plist):**
/// ```xml
/// <key>NSAppTransportSecurity</key>
/// <dict>
///   <key>NSExceptionDomains</key>
///   <dict>
///     <key>api.example.com</key>
///     <dict>
///       <key>NSExceptionAllowsInsecureHTTPLoads</key>
///       <true/>
///     </dict>
///   </dict>
/// </dict>
/// ```
///
/// @see [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
class RequireHttpsForIosRule extends SaropaLintRule {
  /// Creates a new instance of [RequireHttpsForIosRule].
  const RequireHttpsForIosRule() : super(code: _code);

  /// HTTP requests fail without configuration.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_https_for_ios',
    problemMessage:
        'HTTP URL will be blocked by iOS App Transport Security unless '
        'exception is configured.',
    correctionMessage:
        'Use HTTPS or add NSAppTransportSecurity exception in Info.plist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Localhost addresses that don't need HTTPS.
  static const Set<String> _localhostPatterns = <String>{
    'localhost',
    '127.0.0.1',
    '10.0.2.2', // Android emulator localhost
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Uri.parse('http://...')
      if (node.methodName.name != 'parse') {
        return;
      }

      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Uri') {
        return;
      }

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) {
        return;
      }

      final Expression urlArg = args.first;
      if (urlArg is! StringLiteral) {
        return;
      }

      final String url = urlArg.stringValue ?? '';
      if (_isInsecureUrl(url)) {
        reporter.atNode(urlArg, code);
      }
    });
  }

  /// Checks if URL uses HTTP and is not localhost.
  bool _isInsecureUrl(String url) {
    if (!url.startsWith('http://')) {
      return false;
    }

    for (final String localhost in _localhostPatterns) {
      if (url.contains(localhost)) {
        return false;
      }
    }

    return true;
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceHttpWithHttpsFix()];
}

/// Quick fix that replaces http:// with https://.
class _ReplaceHttpWithHttpsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      if (!node.value.startsWith('http://')) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Change to HTTPS',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final String newUrl = node.value.replaceFirst('http://', 'https://');
        builder.addSimpleReplacement(node.sourceRange, "'$newUrl'");
      });
    });
  }
}

/// Warns when permission-requiring APIs are used without Info.plist entries.
///
/// iOS requires Info.plist usage description entries for any app that accesses
/// protected resources (camera, location, microphone, etc.). Apps without
/// these entries are **rejected by App Store review**.
///
/// ## Required Info.plist Keys
///
/// | API | Info.plist Key |
/// |-----|----------------|
/// | Camera | NSCameraUsageDescription |
/// | Photo Library | NSPhotoLibraryUsageDescription |
/// | Location | NSLocationWhenInUseUsageDescription |
/// | Microphone | NSMicrophoneUsageDescription |
/// | Speech Recognition | NSSpeechRecognitionUsageDescription |
/// | Contacts | NSContactsUsageDescription |
/// | Calendar | NSCalendarsUsageDescription |
/// | Bluetooth | NSBluetoothAlwaysUsageDescription |
///
/// ## Detection
///
/// This rule detects usage of common Flutter packages that require permissions:
/// - image_picker
/// - camera
/// - geolocator / location
/// - speech_to_text
/// - contacts_service
/// - device_calendar
///
/// @see [Info.plist Keys](https://developer.apple.com/documentation/bundleresources/information_property_list)
class RequireIosPermissionDescriptionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPermissionDescriptionRule].
  const RequireIosPermissionDescriptionRule() : super(code: _code);

  /// Missing permission descriptions cause App Store rejection.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_ios_permission_description',
    problemMessage:
        'Permission-requiring API used. Ensure Info.plist has usage '
        'description.',
    correctionMessage:
        'Add NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, '
        'etc. to ios/Runner/Info.plist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Package/class names that require iOS permission descriptions.
  ///
  /// Keys are class/type names, values are the required Info.plist keys.
  static const Map<String, String> _permissionTypes = <String, String>{
    'ImagePicker': 'NSPhotoLibraryUsageDescription + NSCameraUsageDescription',
    'CameraPlatform': 'NSCameraUsageDescription',
    'CameraController': 'NSCameraUsageDescription',
    'Geolocator': 'NSLocationWhenInUseUsageDescription',
    'LocationService': 'NSLocationWhenInUseUsageDescription',
    'SpeechToText': 'NSSpeechRecognitionUsageDescription + NSMicrophoneUsageDescription',
    'FlutterSoundRecorder': 'NSMicrophoneUsageDescription',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (_permissionTypes.containsKey(typeName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when APIs requiring iOS 17+ Privacy Manifest are used.
///
/// Starting with iOS 17, Apple requires apps to declare usage of certain
/// "required reason APIs" in a PrivacyInfo.xcprivacy file. Apps using these
/// APIs without declaration may be rejected from the App Store.
///
/// ## Required Reason API Categories
///
/// 1. **File timestamp APIs** (NSPrivacyAccessedAPICategoryFileTimestamp)
///    - File creation/modification dates
///
/// 2. **System boot time APIs** (NSPrivacyAccessedAPICategorySystemBootTime)
///    - systemUptime, ProcessInfo.processInfo
///
/// 3. **Disk space APIs** (NSPrivacyAccessedAPICategoryDiskSpace)
///    - volumeAvailableCapacity, diskSpace
///
/// 4. **User defaults APIs** (NSPrivacyAccessedAPICategoryUserDefaults)
///    - UserDefaults, SharedPreferences
///
/// ## Note
///
/// Most Flutter apps use SharedPreferences, which uses UserDefaults internally.
/// This rule provides a reminder, but SharedPreferences plugin should handle
/// the privacy manifest in its own package.
///
/// @see [Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
class RequireIosPrivacyManifestRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPrivacyManifestRule].
  const RequireIosPrivacyManifestRule() : super(code: _code);

  /// Missing privacy manifest can cause App Store rejection (iOS 17+).
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_privacy_manifest',
    problemMessage:
        'API requires iOS Privacy Manifest entry (iOS 17+).',
    correctionMessage:
        'Add PrivacyInfo.xcprivacy with required reason API declarations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// APIs that require privacy manifest declarations.
  ///
  /// Note: SharedPreferences is intentionally NOT included because
  /// the plugin handles its own privacy manifest.
  static const Set<String> _privacyManifestTypes = <String>{
    'UserDefaults', // Direct usage (not via SharedPreferences)
    'ProcessInfo',
  };

  /// Method names that indicate privacy manifest APIs.
  static const Set<String> _privacyManifestMethods = <String>{
    'systemUptime',
    'volumeAvailableCapacity',
    'fileModificationDate',
    'creationDate',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (_privacyManifestTypes.contains(typeName)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_privacyManifestMethods.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// Additional iOS-Specific Rules (v2.3.13)
// =============================================================================

/// Warns when apps use third-party login without Sign in with Apple.
///
/// Apple's App Store Review Guidelines (Section 4.8) require that apps offering
/// third-party login options (Google, Facebook, Twitter, etc.) must also offer
/// Sign in with Apple as an equally prominent option.
///
/// ## Why This Matters
///
/// Apps that violate this guideline are **rejected during App Store review**.
/// This is one of the most common rejection reasons for apps with social login.
///
/// ## App Store Guideline
///
/// > "Apps that exclusively use a third-party or social login service
/// > (such as Facebook Login, Google Sign-In, Sign in with Twitter,
/// > Sign In with LinkedIn, Login with Amazon, or WeChat Login) to set up
/// > or authenticate the user's primary account with the app must also offer
/// > Sign in with Apple as an equivalent option."
///
/// ## Exceptions
///
/// Sign in with Apple is NOT required when:
/// - App uses only your own first-party login system
/// - App is for education/enterprise with managed accounts
/// - App uses government or industry-backed citizen ID
/// - App is a client for a specific third-party service
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Only Google sign-in without Apple
/// await GoogleSignIn().signIn();
/// ```
///
/// **GOOD:**
/// ```dart
/// // Offer both options
/// await GoogleSignIn().signIn();
/// // ... elsewhere in app
/// await SignInWithApple.getAppleIDCredential(...);
/// ```
///
/// @see [App Store Review Guidelines 4.8](https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple)
/// @see [sign_in_with_apple package](https://pub.dev/packages/sign_in_with_apple)
class RequireAppleSignInRule extends SaropaLintRule {
  /// Creates a new instance of [RequireAppleSignInRule].
  const RequireAppleSignInRule() : super(code: _code);

  /// App Store rejection is critical.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_apple_sign_in',
    problemMessage:
        'Third-party login detected without Sign in with Apple. '
        'iOS apps with social login must offer Sign in with Apple.',
    correctionMessage:
        'Add Sign in with Apple using the sign_in_with_apple package '
        'per App Store Guidelines 4.8.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Third-party sign-in method patterns that trigger this rule.
  static const Set<String> _thirdPartySignInMethods = {
    'signIn', // GoogleSignIn().signIn()
    'signInWithCredential', // Firebase auth
    'signInWithProvider', // Firebase auth
    'logIn', // Facebook
    'login', // Various SDKs
  };

  /// Third-party sign-in class names.
  static const Set<String> _thirdPartySignInClasses = {
    'GoogleSignIn',
    'FacebookAuth',
    'FacebookLogin',
    'TwitterLogin',
    'LinkedInLogin',
    'AmazonLogin',
  };

  /// Apple sign-in indicators.
  static const Set<String> _appleSignInIndicators = {
    'SignInWithApple',
    'getAppleIDCredential',
    'AppleIDAuthorizationRequest',
    'ASAuthorizationController',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track if file has third-party sign-in and Apple sign-in
    bool hasThirdPartySignIn = false;
    bool hasAppleSignIn = false;
    MethodInvocation? firstThirdPartyNode;

    // Check file source for Apple sign-in presence
    final String fileSource = resolver.source.contents.data;
    for (final String indicator in _appleSignInIndicators) {
      if (fileSource.contains(indicator)) {
        hasAppleSignIn = true;
        break;
      }
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for third-party sign-in methods
      if (_thirdPartySignInMethods.contains(methodName)) {
        // Verify it's from a third-party sign-in class
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource();
          for (final String className in _thirdPartySignInClasses) {
            if (targetSource.contains(className)) {
              hasThirdPartySignIn = true;
              firstThirdPartyNode ??= node;
              break;
            }
          }
        }
      }
    });

    // Report after all nodes processed
    context.addPostRunCallback(() {
      if (hasThirdPartySignIn && !hasAppleSignIn && firstThirdPartyNode != null) {
        reporter.atNode(firstThirdPartyNode!, code);
      }
    });
  }
}

/// Warns when iOS-specific background task patterns exceed time limits.
///
/// iOS strictly limits background execution time:
/// - **Background fetch**: ~30 seconds maximum
/// - **Background processing**: 1-10 minutes (requires BGProcessingTask)
/// - **Audio/Location**: Continuous but must actively use capability
///
/// Apps that exceed these limits are **terminated by iOS** and may be
/// throttled or have background refresh disabled entirely.
///
/// ## Why This Matters
///
/// Unlike Android's more permissive background processing:
/// - iOS aggressively kills background tasks that exceed limits
/// - Repeated violations cause iOS to reduce your app's background time
/// - Users may see "App is using significant energy" warnings
///
/// ## Background Capabilities
///
/// To enable background processing, add capabilities in Xcode:
/// - Background fetch
/// - Background processing
/// - Remote notifications
/// - Audio (for audio apps)
/// - Location updates (for navigation)
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Heavy processing in background - will be killed
/// void handleBackgroundFetch() async {
///   await syncAllData(); // May take minutes
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Light processing, defer heavy work
/// void handleBackgroundFetch() async {
///   await syncCriticalDataOnly(); // Complete in <25 seconds
///   scheduleBGProcessingTask(); // Heavy work later
/// }
/// ```
///
/// @see [Background Execution](https://developer.apple.com/documentation/backgroundtasks)
/// @see [workmanager package](https://pub.dev/packages/workmanager)
class RequireIosBackgroundModeRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBackgroundModeRule].
  const RequireIosBackgroundModeRule() : super(code: _code);

  /// Background violations can cause app termination.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_background_mode',
    problemMessage:
        'Background task pattern detected. iOS requires specific capabilities '
        'for background execution.',
    correctionMessage:
        'Add background capabilities in Xcode (Background fetch, '
        'Background processing, etc.) and use workmanager package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Background-related class/method patterns.
  static const Set<String> _backgroundPatterns = {
    'Workmanager',
    'BackgroundFetch',
    'BackgroundTask',
    'registerPeriodicTask',
    'registerOneOffTask',
    'executeTask',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_backgroundPatterns.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (_backgroundPatterns.contains(typeName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when deprecated iOS 13+ APIs are used via platform channels.
///
/// iOS 13 deprecated several UIKit APIs that were commonly used. Apps using
/// these deprecated APIs receive App Store warnings and may eventually be
/// rejected as Apple removes support.
///
/// ## Deprecated APIs
///
/// | Deprecated | Replacement |
/// |------------|-------------|
/// | UIWebView | WKWebView |
/// | UIAlertView | UIAlertController |
/// | UIActionSheet | UIAlertController |
/// | UISearchDisplayController | UISearchController |
/// | addressBook framework | Contacts framework |
///
/// ## Why This Matters
///
/// - App Store Connect shows deprecation warnings during upload
/// - Future iOS versions may remove deprecated APIs entirely
/// - UIWebView specifically is **no longer accepted** in new apps
///
/// ## Example
///
/// **BAD (Swift/ObjC platform channel):**
/// ```swift
/// // UIWebView is rejected
/// let webView = UIWebView(frame: .zero)
/// ```
///
/// **GOOD:**
/// ```swift
/// // WKWebView is the modern replacement
/// let webView = WKWebView(frame: .zero)
/// ```
///
/// In Flutter, use `webview_flutter` package which uses WKWebView.
///
/// @see [UIWebView deprecation](https://developer.apple.com/documentation/uikit/uiwebview)
class AvoidIos13DeprecationsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIos13DeprecationsRule].
  const AvoidIos13DeprecationsRule() : super(code: _code);

  /// Deprecated APIs cause App Store warnings and eventual rejection.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_13_deprecations',
    problemMessage:
        'Deprecated iOS API detected. This API is deprecated since iOS 13 '
        'and may cause App Store rejection.',
    correctionMessage:
        'Use the modern replacement API. See Apple documentation for '
        'migration guidance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Deprecated iOS API names that appear in platform channel code.
  static const Set<String> _deprecatedApis = {
    'UIWebView',
    'UIAlertView',
    'UIActionSheet',
    'UISearchDisplayController',
    'UIPopoverController',
    'ABAddressBook',
    'ABPerson',
    'ABRecord',
    'UILocalNotification',
    'registerUserNotificationSettings',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String api in _deprecatedApis) {
        if (value.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_deprecatedApis.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when iOS Simulator-only code patterns are detected.
///
/// Code that only works on iOS Simulator (not real devices) should be properly
/// guarded to prevent runtime failures in production.
///
/// ## Common Simulator-Only Patterns
///
/// - File paths starting with `/Users/` (Mac-only paths)
/// - Hardcoded localhost URLs (Simulator can access Mac's localhost)
/// - Mock location data without device checks
/// - Debug-only API endpoints
///
/// ## Why This Matters
///
/// Code that works in Simulator may fail on real devices:
/// - Different file system structure
/// - No access to Mac's network
/// - Different security restrictions
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Only works on Simulator running on Mac
/// final file = File('/Users/developer/test.json');
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use app's documents directory
/// final dir = await getApplicationDocumentsDirectory();
/// final file = File('${dir.path}/test.json');
/// ```
///
/// @see [path_provider package](https://pub.dev/packages/path_provider)
class AvoidIosSimulatorOnlyCodeRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosSimulatorOnlyCodeRule].
  const AvoidIosSimulatorOnlyCodeRule() : super(code: _code);

  /// Simulator-only code causes production failures.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_simulator_only_code',
    problemMessage:
        'iOS Simulator-only code pattern detected. This code may not work '
        'on real iOS devices.',
    correctionMessage:
        'Use platform-agnostic paths (path_provider) and proper environment '
        'detection.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns that indicate Simulator-only code.
  static const List<String> _simulatorPatterns = [
    '/Users/',
    '/var/folders/',
    '/tmp/',
    'localhost:',
    '127.0.0.1:',
    '0.0.0.0:',
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

      for (final String pattern in _simulatorPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when iOS version-specific APIs are used without version checks.
///
/// iOS APIs have minimum version requirements. Using newer APIs without
/// version guards causes crashes on older iOS versions that users may still
/// have installed.
///
/// ## Common Version-Specific Features
///
/// | Feature | Minimum iOS |
/// |---------|-------------|
/// | SharePlay | iOS 15.0 |
/// | Focus filters | iOS 16.0 |
/// | Live Activities | iOS 16.1 |
/// | Interactive widgets | iOS 17.0 |
/// | App Intents | iOS 16.0 |
///
/// ## Why This Matters
///
/// - Apps crash on older iOS versions without guards
/// - App Store still allows iOS 12+ deployments
/// - Enterprise apps may target older devices
///
/// ## Example
///
/// **BAD (platform channel without version check):**
/// ```dart
/// // LiveActivity requires iOS 16.1+
/// await channel.invokeMethod('startLiveActivity', data);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Check iOS version first
/// final version = await channel.invokeMethod('getIOSVersion');
/// if (version >= 16.1) {
///   await channel.invokeMethod('startLiveActivity', data);
/// }
/// ```
///
/// @see [Checking iOS Version](https://developer.apple.com/documentation/swift/checking-api-availability)
class RequireIosMinimumVersionCheckRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosMinimumVersionCheckRule].
  const RequireIosMinimumVersionCheckRule() : super(code: _code);

  /// Missing version checks cause crashes on older iOS.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_minimum_version_check',
    problemMessage:
        'iOS version-specific API detected. Ensure iOS version is checked '
        'before using this API.',
    correctionMessage:
        'Add iOS version check before calling version-specific APIs.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// APIs that require specific iOS versions.
  static const Set<String> _versionSpecificApis = {
    // iOS 15+
    'SharePlay',
    'GroupActivity',
    // iOS 16+
    'LiveActivity',
    'ActivityKit',
    'AppIntents',
    'FocusFilter',
    'LockScreenWidget',
    // iOS 17+
    'InteractiveWidget',
    'TipKit',
    'StandbyMode',
    'JournalingSuggestion',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String api in _versionSpecificApis) {
        if (value.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      for (final String api in _versionSpecificApis) {
        if (methodName.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when deprecated UIKit APIs are used in platform channel code.
///
/// Platform channel code (Swift/Objective-C) that uses deprecated UIKit APIs
/// will generate warnings during Xcode builds and may be rejected by App Store
/// in future iOS versions.
///
/// ## Common Deprecated UIKit APIs
///
/// | Deprecated | Replacement | Since |
/// |------------|-------------|-------|
/// | UIApplication.keyWindow | connectedScenes | iOS 13 |
/// | UIScreen.main.bounds | UIWindowScene.screen | iOS 13 |
/// | statusBarOrientation | interfaceOrientation | iOS 13 |
/// | beginBackgroundTask (old) | BGTaskScheduler | iOS 13 |
/// | UIDevice.current.model (on Mac) | ProcessInfo | iOS 14 |
///
/// ## Why This Matters
///
/// - Xcode shows deprecation warnings during build
/// - App Store may reject apps with deprecated APIs
/// - Deprecated APIs may behave incorrectly on newer iOS
///
/// ## Example
///
/// **BAD:**
/// ```swift
/// // keyWindow is deprecated
/// let window = UIApplication.shared.keyWindow
/// ```
///
/// **GOOD:**
/// ```swift
/// // Use scene-based API
/// let window = UIApplication.shared.connectedScenes
///   .compactMap { $0 as? UIWindowScene }
///   .first?.windows.first { $0.isKeyWindow }
/// ```
///
/// @see [iOS 13 Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-13-release-notes)
class AvoidIosDeprecatedUikitRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosDeprecatedUikitRule].
  const AvoidIosDeprecatedUikitRule() : super(code: _code);

  /// Deprecated APIs cause warnings and potential rejection.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_deprecated_uikit',
    problemMessage:
        'Deprecated UIKit API pattern detected in platform channel code.',
    correctionMessage:
        'Update platform channel code to use modern iOS APIs. '
        'See Xcode warnings for specific replacements.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Deprecated UIKit API patterns.
  static const Set<String> _deprecatedPatterns = {
    'keyWindow',
    'statusBarOrientation',
    'statusBarFrame',
    'statusBarHidden',
    'UIScreen.main',
    'beginBackgroundTask',
    'endBackgroundTask',
    'backgroundTimeRemaining',
    'applicationIconBadgeNumber',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String pattern in _deprecatedPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}
