// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

// cspell:disable

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
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../info_plist_utils.dart';
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
          final String? paddingConstructor =
              paddingArg.constructorName.name?.name;
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
/// `HapticFeedback` improves user experience by providing tactile confirmation
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHapticFeedbackFix()];
}

/// Quick fix that adds HapticFeedback.mediumImpact() to button callback.
class _AddHapticFeedbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      final Expression? onPressedArg = node.getNamedParameterValue('onPressed');
      if (onPressedArg == null) {
        return;
      }

      // Handle function expression callbacks: () { ... } or () => ...
      if (onPressedArg is FunctionExpression) {
        final FunctionBody body = onPressedArg.body;

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add HapticFeedback.mediumImpact()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          if (body is BlockFunctionBody) {
            // Insert at the start of the block: { HapticFeedback.mediumImpact(); ...
            final int insertOffset = body.block.leftBracket.end;
            builder.addSimpleInsertion(
              insertOffset,
              '\n    HapticFeedback.mediumImpact();',
            );
          } else if (body is ExpressionFunctionBody) {
            // Convert => expr to { HapticFeedback.mediumImpact(); expr; }
            final int arrowOffset = body.functionDefinition.offset;
            final Expression expression = body.expression;
            builder.addSimpleReplacement(
              SourceRange(arrowOffset, body.end - arrowOffset),
              '{\n    HapticFeedback.mediumImpact();\n    ${expression.toSource()};\n  }',
            );
          }
        });
      }
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
    correctionMessage: 'Wrap iOS-specific code with if (Platform.isIOS) check.',
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_WrapWithPlatformCheckFix()];
}

/// Quick fix that wraps MethodChannel with if (Platform.isIOS) check.
class _WrapWithPlatformCheckFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) {
        return;
      }

      if (node.typeName != 'MethodChannel') {
        return;
      }

      // Find the containing statement to wrap
      AstNode? statementToWrap = node.parent;
      while (statementToWrap != null && statementToWrap is! Statement) {
        statementToWrap = statementToWrap.parent;
      }

      if (statementToWrap == null) {
        return;
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap with if (Platform.isIOS)',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final String statementSource = statementToWrap!.toSource();
        final String indentedStatement =
            statementSource.split('\n').map((line) => '  $line').join('\n');
        builder.addSimpleReplacement(
          statementToWrap.sourceRange,
          'if (Platform.isIOS) {\n$indentedStatement\n}',
        );
      });
    });
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
/// experience. `PlatformMenuBar` provides this integration in Flutter.
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

  static const LintCode _code = LintCode(
    name: 'prefer_macos_keyboard_shortcuts',
    problemMessage: 'macOS apps should implement standard keyboard shortcuts.',
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
      if (!pathSource.contains(':') &&
          !pathSource.contains(RegExp(r'\{[^}]+\}'))) {
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
/// ## Smart Detection
///
/// This rule **actually reads your Info.plist** file to check if the required
/// permission keys are present. It only reports warnings when keys are
/// genuinely missing, avoiding false positives.
///
/// - Finds your project's `ios/Runner/Info.plist` automatically
/// - Caches the result per project for performance
/// - Reports which specific key(s) are missing
/// - Silently passes if Info.plist already has the required keys
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
/// | Face ID | NSFaceIDUsageDescription |
/// | Health | NSHealthShareUsageDescription, NSHealthUpdateUsageDescription |
///
/// ## Detected Packages
///
/// This rule detects usage of common Flutter packages that require permissions:
/// - image_picker (camera + photo library)
/// - camera (camera)
/// - geolocator / location (location)
/// - speech_to_text (speech recognition + microphone)
/// - contacts_service / flutter_contacts (contacts)
/// - device_calendar (calendar)
/// - flutter_blue_plus / flutter_blue (bluetooth)
/// - local_authentication (face ID)
/// - health (health data)
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
        'Permission-requiring API used. Missing Info.plist key(s): {0}',
    correctionMessage: 'Add the missing key(s) to ios/Runner/Info.plist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Methods on ImagePicker that access device resources.
  static const Set<String> _imagePickerMethods = <String>{
    'pickImage',
    'pickVideo',
    'pickMedia',
    'pickMultiImage',
    'pickMultipleMedia',
  };

  /// Creates a LintCode with specific missing keys in the message.
  static LintCode _codeWithMissingKeys(List<String> missingKeys) {
    return LintCode(
      name: 'require_ios_permission_description',
      problemMessage:
          'Permission-requiring API used. Missing Info.plist key(s): '
          '${missingKeys.join(", ")}',
      correctionMessage:
          'Add ${missingKeys.join(" and ")} to ios/Runner/Info.plist.',
      errorSeverity: DiagnosticSeverity.WARNING,
    );
  }

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Get the Info.plist checker for this file's project.
    final filePath = resolver.source.fullName;
    final plistChecker = InfoPlistChecker.forFile(filePath);

    // Check for permission-requiring types (non-ImagePicker).
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      // Get required keys for this type.
      final requiredKeys = IosPermissionMapping.getRequiredKeys(typeName);
      if (requiredKeys == null) return;

      // Check if any keys are missing from Info.plist.
      final missingKeys = plistChecker?.getMissingKeys(requiredKeys) ?? [];

      // Only report if keys are actually missing.
      if (missingKeys.isNotEmpty) {
        reporter.atNode(node, _codeWithMissingKeys(missingKeys));
      }
    });

    // Smart ImagePicker detection: check the actual source parameter.
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check ImagePicker methods.
      if (!_imagePickerMethods.contains(methodName)) return;

      // Check if this is called on an ImagePicker instance.
      final Expression? target = node.target;
      if (target == null) return;

      // Check if target is ImagePicker type.
      final bool isImagePicker = _isImagePickerTarget(target);
      if (!isImagePicker) return;

      // Determine which source is being used.
      final _ImageSource source = _getImageSource(node);

      // Get required keys based on source.
      final List<String> requiredKeys;
      switch (source) {
        case _ImageSource.gallery:
          requiredKeys = ['NSPhotoLibraryUsageDescription'];
        case _ImageSource.camera:
          requiredKeys = ['NSCameraUsageDescription'];
        case _ImageSource.unknown:
          requiredKeys = [
            'NSPhotoLibraryUsageDescription',
            'NSCameraUsageDescription',
          ];
      }

      // Check if any keys are missing from Info.plist.
      final missingKeys = plistChecker?.getMissingKeys(requiredKeys) ?? [];

      // Only report if keys are actually missing.
      if (missingKeys.isNotEmpty) {
        reporter.atNode(node, _codeWithMissingKeys(missingKeys));
      }
    });
  }

  /// Checks if the target expression is an ImagePicker instance.
  ///
  /// Uses actual type resolution for reliability rather than heuristics.
  static bool _isImagePickerTarget(Expression target) {
    // Direct constructor call: ImagePicker().pickImage(...)
    if (target is InstanceCreationExpression) {
      return target.typeName == 'ImagePicker';
    }

    // Use resolved static type for reliable detection.
    final String? typeName = target.staticType?.element?.name;
    return typeName == 'ImagePicker';
  }

  /// Extracts the ImageSource from a method invocation's source parameter.
  static _ImageSource _getImageSource(MethodInvocation node) {
    // Look for the 'source' named parameter.
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'source') {
        final Expression value = arg.expression;

        // Check for ImageSource.gallery or ImageSource.camera.
        if (value is PrefixedIdentifier) {
          final String identifier = value.identifier.name;
          if (identifier == 'gallery') return _ImageSource.gallery;
          if (identifier == 'camera') return _ImageSource.camera;
        }

        // Also check for PropertyAccess (e.g., if using a variable).
        if (value is PropertyAccess) {
          final String propertyName = value.propertyName.name;
          if (propertyName == 'gallery') return _ImageSource.gallery;
          if (propertyName == 'camera') return _ImageSource.camera;
        }

        // Check for simple identifier that might be a variable.
        // Can't determine statically, so return unknown.
        return _ImageSource.unknown;
      }
    }

    // No source parameter found - for pickMultiImage, default is gallery.
    final String methodName = node.methodName.name;
    if (methodName == 'pickMultiImage' || methodName == 'pickMultipleMedia') {
      return _ImageSource.gallery;
    }

    // For other methods without explicit source, we can't determine.
    return _ImageSource.unknown;
  }
}

/// Internal enum for ImageSource detection.
enum _ImageSource { gallery, camera, unknown }

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
    problemMessage: 'API requires iOS Privacy Manifest entry (iOS 17+).',
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
    problemMessage: 'Third-party login detected without Sign in with Apple. '
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
      if (hasThirdPartySignIn &&
          !hasAppleSignIn &&
          firstThirdPartyNode != null) {
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

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
    correctionMessage: 'Update platform channel code to use modern iOS APIs. '
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

// =============================================================================
// Additional iOS-Specific Rules (v2.3.14)
// =============================================================================

/// Warns when apps use advertising/tracking without App Tracking Transparency.
///
/// iOS 14.5+ requires apps to request user permission before tracking via
/// App Tracking Transparency (ATT). Apps that track without permission are
/// **rejected by App Store review**.
///
/// ## What Requires ATT
///
/// - IDFA (Identifier for Advertisers) access
/// - Third-party advertising SDKs (AdMob, Facebook Ads, etc.)
/// - Analytics that link user data across apps/websites
/// - Any form of cross-app user tracking
///
/// ## What Does NOT Require ATT
///
/// - First-party analytics (no cross-app linking)
/// - Fraud detection
/// - Security purposes
/// - Contextual advertising (not user-based)
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Using AdMob without ATT check
/// await AdMob.initialize();
/// ```
///
/// **GOOD:**
/// ```dart
/// // Request ATT permission first
/// final status = await AppTrackingTransparency.requestTrackingAuthorization();
/// if (status == TrackingStatus.authorized) {
///   await AdMob.initialize();
/// }
/// ```
///
/// @see [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency)
/// @see [app_tracking_transparency package](https://pub.dev/packages/app_tracking_transparency)
class RequireIosAppTrackingTransparencyRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppTrackingTransparencyRule].
  const RequireIosAppTrackingTransparencyRule() : super(code: _code);

  /// ATT is required for App Store approval.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_ios_app_tracking_transparency',
    problemMessage:
        'Advertising/tracking SDK detected. iOS 14.5+ requires App Tracking '
        'Transparency permission before tracking users.',
    correctionMessage:
        'Use AppTrackingTransparency.requestTrackingAuthorization() before '
        'initializing ad SDKs. Add NSUserTrackingUsageDescription to Info.plist.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Advertising/tracking SDK patterns.
  static const Set<String> _trackingPatterns = {
    'AdMob',
    'GoogleMobileAds',
    'MobileAds',
    'FacebookAds',
    'FBAds',
    'UnityAds',
    'IronSource',
    'AppLovin',
    'Chartboost',
    'Vungle',
    'AdColony',
    'requestIDFA',
    'advertisingIdentifier',
    'ASIdentifierManager',
  };

  /// ATT-related patterns that indicate proper handling.
  static const Set<String> _attPatterns = {
    'AppTrackingTransparency',
    'requestTrackingAuthorization',
    'TrackingStatus',
    'ATTrackingManager',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check file source for ATT presence
    final String fileSource = resolver.source.contents.data;
    bool hasATT = false;
    for (final String pattern in _attPatterns) {
      if (fileSource.contains(pattern)) {
        hasATT = true;
        break;
      }
    }

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasATT) return;

      final String typeName = node.typeName;
      for (final String pattern in _trackingPatterns) {
        if (typeName.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (hasATT) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;
      final String fullCall =
          target != null ? '${target.toSource()}.$methodName' : methodName;

      for (final String pattern in _trackingPatterns) {
        if (fullCall.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when Face ID is used without NSFaceIDUsageDescription.
///
/// iOS requires NSFaceIDUsageDescription in Info.plist for any app that uses
/// Face ID authentication. Apps without this entry crash when attempting
/// Face ID authentication.
///
/// ## Why This Matters
///
/// - App crashes on Face ID devices without usage description
/// - App Store rejects apps missing required Info.plist entries
/// - Touch ID doesn't require a separate description (covered by LAPolicy)
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// await LocalAuthentication().authenticate(
///   localizedReason: 'Authenticate to access account',
///   options: AuthenticationOptions(biometricOnly: true),
/// );
/// ```
///
/// **Required Info.plist entry:**
/// ```xml
/// <key>NSFaceIDUsageDescription</key>
/// <string>We use Face ID to securely authenticate you.</string>
/// ```
///
/// @see [LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
/// @see [local_auth package](https://pub.dev/packages/local_auth)
class RequireIosFaceIdUsageDescriptionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosFaceIdUsageDescriptionRule].
  const RequireIosFaceIdUsageDescriptionRule() : super(code: _code);

  /// Missing Face ID description causes crashes and rejection.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_ios_face_id_usage_description',
    problemMessage: 'Biometric authentication detected. iOS requires '
        'NSFaceIDUsageDescription in Info.plist for Face ID.',
    correctionMessage:
        'Add NSFaceIDUsageDescription to ios/Runner/Info.plist explaining '
        'why your app uses Face ID.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Type names from the local_auth package.
  static const Set<String> _localAuthTypeNames = {
    'LocalAuthentication',
  };

  /// Method names that are unique to LocalAuthentication class.
  /// These methods only exist on LocalAuthentication, so type checking
  /// the receiver is sufficient.
  static const Set<String> _localAuthMethods = {
    'authenticate',
    'canCheckBiometrics',
    'getAvailableBiometrics',
    'isDeviceSupported',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check methods that could be from local_auth
      if (!_localAuthMethods.contains(methodName)) {
        return;
      }

      // Verify the receiver is LocalAuthentication using type resolution
      final Expression? target = node.target;
      if (target == null) return;

      // Use static type resolution - this is the reliable way
      final String? typeName = target.staticType?.element?.name;
      if (typeName != null && _localAuthTypeNames.contains(typeName)) {
        reporter.atNode(node, code);
      }
    });

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      // Use element name for reliable type checking
      final String? typeName = node.constructorName.type.element?.name;

      if (typeName == 'LocalAuthentication' ||
          typeName == 'AuthenticationOptions') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when saving photos without NSPhotoLibraryAddUsageDescription.
///
/// iOS separates permissions for reading vs writing to the photo library:
/// - **NSPhotoLibraryUsageDescription**: Reading photos (picker)
/// - **NSPhotoLibraryAddUsageDescription**: Saving photos (write-only)
///
/// Apps that save photos without NSPhotoLibraryAddUsageDescription crash.
///
/// ## Why This Matters
///
/// - Different from read permission (NSPhotoLibraryUsageDescription)
/// - Many developers forget the "Add" variant
/// - Crashes when saving screenshots, downloads, or generated images
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// await ImageGallerySaver.saveImage(bytes);
/// await GallerySaver.saveImage(path);
/// ```
///
/// **Required Info.plist entry:**
/// ```xml
/// <key>NSPhotoLibraryAddUsageDescription</key>
/// <string>We save photos you create to your photo library.</string>
/// ```
///
/// @see [PHPhotoLibrary](https://developer.apple.com/documentation/photokit/phphotolibrary)
class RequireIosPhotoLibraryAddUsageRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPhotoLibraryAddUsageRule].
  const RequireIosPhotoLibraryAddUsageRule() : super(code: _code);

  /// Missing permission causes crashes.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_photo_library_add_usage',
    problemMessage:
        'Photo saving detected. iOS requires NSPhotoLibraryAddUsageDescription '
        'for saving photos (separate from read permission).',
    correctionMessage:
        'Add NSPhotoLibraryAddUsageDescription to ios/Runner/Info.plist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Photo saving patterns.
  static const Set<String> _photoSavePatterns = {
    'ImageGallerySaver',
    'GallerySaver',
    'saveImage',
    'saveVideo',
    'saveFile',
    'PHPhotoLibrary',
    'creationRequestForAsset',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check method name
      if (_photoSavePatterns.contains(methodName)) {
        reporter.atNode(node, code);
        return;
      }

      // Check target class
      if (target != null) {
        final String targetSource = target.toSource();
        for (final String pattern in _photoSavePatterns) {
          if (targetSource.contains(pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when OAuth is performed via in-app WebView instead of system browser.
///
/// Google and Apple block OAuth via in-app WebView for security reasons.
/// OAuth must use ASWebAuthenticationSession (iOS) or Custom Tabs (Android).
///
/// ## Why This Matters
///
/// - Google blocks OAuth in WebView since 2017
/// - Apple requires ASWebAuthenticationSession for Sign in with Apple
/// - In-app WebView can intercept credentials (security risk)
/// - Users can't verify they're on the real login page
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // OAuth in WebView - blocked by Google/Apple
/// WebView(
///   initialUrl: 'https://accounts.google.com/o/oauth2/auth?...',
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use flutter_appauth for proper OAuth flow
/// await appAuth.authorizeAndExchangeCode(
///   AuthorizationTokenRequest('client_id', 'redirect_uri'),
/// );
/// ```
///
/// @see [Google OAuth policy](https://developers.googleblog.com/2016/08/modernizing-oauth-interactions-in-native-apps.html)
/// @see [flutter_appauth package](https://pub.dev/packages/flutter_appauth)
class AvoidIosInAppBrowserForAuthRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosInAppBrowserForAuthRule].
  const AvoidIosInAppBrowserForAuthRule() : super(code: _code);

  /// OAuth via WebView is blocked by identity providers.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_in_app_browser_for_auth',
    problemMessage:
        'OAuth URL detected in WebView. Google and Apple block OAuth via '
        'in-app WebView for security reasons.',
    correctionMessage: 'Use flutter_appauth or url_launcher for OAuth. '
        'ASWebAuthenticationSession is required on iOS.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// OAuth URL patterns.
  static const List<String> _oauthPatterns = [
    'accounts.google.com/o/oauth',
    'appleid.apple.com/auth',
    'facebook.com/v',
    '/dialog/oauth',
    'login.microsoftonline.com',
    'github.com/login/oauth',
    'twitter.com/oauth',
    'api.twitter.com/oauth',
  ];

  /// WebView widget names.
  static const Set<String> _webViewWidgets = {
    'WebView',
    'InAppWebView',
    'WebViewWidget',
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

      if (!_webViewWidgets.contains(typeName)) {
        return;
      }

      // Check if any string argument contains OAuth URL
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        for (final String pattern in _oauthPatterns) {
          if (argSource.contains(pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });

    // Also check string literals for OAuth URLs with WebView nearby
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String pattern in _oauthPatterns) {
        if (value.contains(pattern)) {
          // Check if file contains WebView
          final String fileSource = resolver.source.contents.data;
          for (final String webView in _webViewWidgets) {
            if (fileSource.contains(webView)) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when app review is requested too early or too frequently.
///
/// Apple's App Store Review Guidelines require that apps not prompt for
/// reviews on first launch or too frequently. Apps that violate this are
/// **rejected during App Store review**.
///
/// ## Apple Guidelines
///
/// - Don't prompt on first launch
/// - Don't prompt more than 3 times per 365-day period
/// - Don't interrupt user tasks to ask for review
/// - Use SKStoreReviewController (in_app_review package)
///
/// ## Best Practices
///
/// - Wait until user has engaged meaningfully with app
/// - Prompt after positive experience (completed task, achievement)
/// - Never prompt after negative experience (error, crash recovery)
/// - Track when last prompt occurred
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // In initState or main - too early!
/// void initState() {
///   super.initState();
///   InAppReview.instance.requestReview();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // After positive engagement
/// void onOrderCompleted() {
///   if (await shouldRequestReview()) {
///     await InAppReview.instance.requestReview();
///   }
/// }
/// ```
///
/// @see [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
/// @see [in_app_review package](https://pub.dev/packages/in_app_review)
class RequireIosAppReviewPromptTimingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppReviewPromptTimingRule].
  const RequireIosAppReviewPromptTimingRule() : super(code: _code);

  /// Poor review timing causes App Store rejection.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_app_review_prompt_timing',
    problemMessage: 'App review request detected in initialization context. '
        'Do not request reviews on first launch or during startup.',
    correctionMessage: 'Move review request after meaningful user engagement. '
        'Apple rejects apps that prompt too early.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Review request patterns.
  static const Set<String> _reviewPatterns = {
    'requestReview',
    'openStoreListing',
    'SKStoreReviewController',
  };

  /// Initialization contexts where review requests are problematic.
  static const Set<String> _initContexts = {
    'initState',
    'main',
    'init',
    'initialize',
    'setup',
    'configure',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_reviewPatterns.contains(methodName)) {
        return;
      }

      // Check if we're in an initialization context
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is MethodDeclaration) {
          final String parentName = parent.name.lexeme;
          for (final String initContext in _initContexts) {
            if (parentName.toLowerCase().contains(initContext.toLowerCase())) {
              reporter.atNode(node, code);
              return;
            }
          }
          break;
        }
        if (parent is FunctionDeclaration) {
          final String parentName = parent.name.lexeme;
          for (final String initContext in _initContexts) {
            if (parentName.toLowerCase().contains(initContext.toLowerCase())) {
              reporter.atNode(node, code);
              return;
            }
          }
          break;
        }
        parent = parent.parent;
      }
    });
  }
}

/// Warns when Keychain is used without specifying accessibility level.
///
/// iOS Keychain items should specify when they're accessible for security.
/// Default accessibility may not be appropriate for sensitive data.
///
/// ## Accessibility Levels
///
/// | Level | When Accessible | Use Case |
/// |-------|-----------------|----------|
/// | whenUnlocked | Device unlocked | Most apps |
/// | afterFirstUnlock | After first unlock since boot | Background apps |
/// | whenPasscodeSetThisDeviceOnly | Passcode set, this device | High security |
/// | whenUnlockedThisDeviceOnly | Unlocked, this device | Maximum security |
///
/// ## Why This Matters
///
/// - Default accessibility may allow access when device locked
/// - "ThisDeviceOnly" prevents iCloud Keychain sync (more secure)
/// - Background apps may fail if accessibility is too restrictive
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // No accessibility specified
/// await secureStorage.write(key: 'token', value: token);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Explicit accessibility
/// await secureStorage.write(
///   key: 'token',
///   value: token,
///   iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
/// );
/// ```
///
/// @see [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
/// @see [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
class RequireIosKeychainAccessibilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosKeychainAccessibilityRule].
  const RequireIosKeychainAccessibilityRule() : super(code: _code);

  /// Keychain misconfiguration can expose sensitive data.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_keychain_accessibility',
    problemMessage:
        'Keychain write detected. Consider specifying iOS accessibility level '
        'for security.',
    correctionMessage:
        'Use IOSOptions with KeychainAccessibility to control when data '
        'is accessible.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for secure storage write without IOSOptions
      if (methodName == 'write') {
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource();
          if (targetSource.contains('secureStorage') ||
              targetSource.contains('FlutterSecureStorage')) {
            // Check if iOptions is specified
            bool hasIOSOptions = false;
            for (final Expression arg in node.argumentList.arguments) {
              if (arg is NamedExpression) {
                if (arg.name.label.name == 'iOptions' ||
                    arg.name.label.name == 'aOptions') {
                  hasIOSOptions = true;
                  break;
                }
              }
            }
            if (!hasIOSOptions) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when bundle ID is hardcoded instead of from configuration.
///
/// Bundle IDs should come from build configuration, not hardcoded strings.
/// Hardcoded bundle IDs cause issues when:
/// - Using different bundle IDs for dev/staging/production
/// - Sharing code across multiple apps
/// - White-labeling apps
///
/// ## Why This Matters
///
/// - Different environments need different bundle IDs
/// - Hardcoded IDs break when copied to other projects
/// - Universal Links/App Links are bundle ID specific
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// const bundleId = 'com.example.myapp';
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use package_info_plus to get bundle ID at runtime
/// final info = await PackageInfo.fromPlatform();
/// final bundleId = info.packageName;
///
/// // Or use build configuration
/// const bundleId = String.fromEnvironment('BUNDLE_ID');
/// ```
///
/// @see [package_info_plus](https://pub.dev/packages/package_info_plus)
class AvoidIosHardcodedBundleIdRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedBundleIdRule].
  const AvoidIosHardcodedBundleIdRule() : super(code: _code);

  /// Hardcoded bundle IDs cause deployment issues.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_hardcoded_bundle_id',
    problemMessage: 'Hardcoded bundle ID detected. Bundle IDs should come from '
        'configuration, not hardcoded strings.',
    correctionMessage:
        'Use PackageInfo.fromPlatform().packageName or build-time configuration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern matching bundle IDs.
  static final RegExp _bundleIdPattern = RegExp(
    r'^com\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
    caseSensitive: false,
  );

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

      // Check if value looks like a bundle ID
      if (_bundleIdPattern.hasMatch(value)) {
        // Check if it's being used in a bundle ID context
        AstNode? parent = node.parent;
        while (parent != null) {
          if (parent is VariableDeclaration) {
            final String varName = parent.name.lexeme.toLowerCase();
            if (varName.contains('bundle') ||
                varName.contains('package') ||
                varName.contains('appid')) {
              reporter.atNode(node, code);
              return;
            }
          }
          if (parent is NamedExpression) {
            final String paramName = parent.name.label.name.toLowerCase();
            if (paramName.contains('bundle') ||
                paramName.contains('package') ||
                paramName.contains('appid')) {
              reporter.atNode(node, code);
              return;
            }
          }
          parent = parent.parent;
        }
      }
    });
  }
}

/// Warns when push notifications are used without capability reminder.
///
/// iOS push notifications require:
/// 1. Push Notifications capability in Xcode
/// 2. APNs certificate or key configured in Apple Developer Console
/// 3. Proper provisioning profile
///
/// Without proper configuration, push notifications silently fail.
///
/// ## Required Setup
///
/// 1. Enable Push Notifications capability in Xcode
/// 2. Create APNs key or certificate in Apple Developer Console
/// 3. Configure Firebase/OneSignal with APNs credentials
/// 4. Use proper provisioning profile
///
/// ## Example
///
/// **Triggers reminder:**
/// ```dart
/// await FirebaseMessaging.instance.requestPermission();
/// await FirebaseMessaging.instance.getToken();
/// ```
///
/// @see [Push Notifications](https://developer.apple.com/documentation/usernotifications)
/// @see [firebase_messaging](https://pub.dev/packages/firebase_messaging)
class RequireIosPushNotificationCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPushNotificationCapabilityRule].
  const RequireIosPushNotificationCapabilityRule() : super(code: _code);

  /// Missing push configuration causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_push_notification_capability',
    problemMessage:
        'Push notification usage detected. Ensure Push Notifications '
        'capability is enabled in Xcode and APNs is configured.',
    correctionMessage:
        'Enable Push Notifications in Xcode Signing & Capabilities. '
        'Configure APNs key/certificate in Apple Developer Console.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Push notification patterns.
  static const Set<String> _pushPatterns = {
    'FirebaseMessaging',
    'getToken',
    'onMessage',
    'onMessageOpenedApp',
    'requestPermission',
    'UNUserNotificationCenter',
    'OneSignal',
    'registerForRemoteNotifications',
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

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check method name
      if (_pushPatterns.contains(methodName)) {
        reporter.atNode(node, code);
        hasReported = true;
        return;
      }

      // Check target
      if (target != null) {
        final String targetSource = target.toSource();
        for (final String pattern in _pushPatterns) {
          if (targetSource.contains(pattern)) {
            reporter.atNode(node, code);
            hasReported = true;
            return;
          }
        }
      }
    });
  }
}

/// Warns when macOS file access may require user intent.
///
/// macOS sandboxed apps can only access files the user explicitly chooses
/// via NSOpenPanel, NSSavePanel, or drag-and-drop. Attempting to access
/// arbitrary file paths fails silently or throws permission errors.
///
/// ## What Requires User Intent
///
/// - Any file outside app sandbox
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

  static const LintCode _code = LintCode(
    name: 'require_macos_file_access_intent',
    problemMessage:
        'Direct file path access detected. macOS sandboxed apps require '
        'user intent (file picker, drag-drop) for file access.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_macos_deprecated_security_apis',
    problemMessage:
        'Deprecated macOS Security API detected. Use modern equivalents.',
    correctionMessage:
        'Replace deprecated Keychain APIs with SecItem* functions.',
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

// ============================================================================
// v2.3.15 - Additional iOS/macOS Platform Rules
// ============================================================================

/// Warns when HTTP connections are used without ATS exception documentation.
///
/// iOS App Transport Security (ATS) blocks HTTP connections by default.
/// If your app must use HTTP (e.g., connecting to IoT devices, local servers),
/// you need both Info.plist exceptions AND code comments explaining why.
///
/// ## ATS Exception Types
///
/// | Exception | Use Case |
/// |-----------|----------|
/// | NSAllowsArbitraryLoads | Disables all ATS (not recommended) |
/// | NSExceptionDomains | Per-domain exceptions |
/// | NSAllowsLocalNetworking | Local network only (iOS 10+) |
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// // HTTP without explanation
/// final response = await http.get(Uri.parse('http://192.168.1.100/api'));
/// ```
///
/// **Better:**
/// ```dart
/// // IoT device communication - ATS exception in Info.plist for local network
/// // NSAllowsLocalNetworking = true
/// final response = await http.get(Uri.parse('http://192.168.1.100/api'));
/// ```
///
/// @see [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
class RequireIosAtsExceptionDocumentationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAtsExceptionDocumentationRule].
  const RequireIosAtsExceptionDocumentationRule() : super(code: _code);

  /// HTTP without ATS documentation causes confusion and potential issues.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_ats_exception_documentation',
    problemMessage:
        'HTTP URL detected. If intentional, document the ATS exception '
        'required in Info.plist with a comment.',
    correctionMessage:
        'Add a comment explaining why HTTP is needed and which ATS exception '
        'is configured in Info.plist.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Check for HTTP URLs (not HTTPS)
      if (!value.startsWith('http://')) {
        return;
      }

      // Skip localhost and common dev URLs
      if (value.contains('localhost') || value.contains('127.0.0.1')) {
        return;
      }

      // Check if there's a comment nearby explaining ATS
      final String fileSource = resolver.source.contents.data;
      final int nodeOffset = node.offset;
      final int lineStart = fileSource.lastIndexOf('\n', nodeOffset) + 1;
      final String precedingLine = fileSource.substring(
        lineStart > 50 ? lineStart - 50 : 0,
        lineStart,
      );

      if (precedingLine.contains('ATS') ||
          precedingLine.contains('NSAllows') ||
          precedingLine.contains('NSException') ||
          precedingLine.contains('Info.plist')) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when local notifications are scheduled without permission request.
///
/// iOS requires explicit permission for local notifications since iOS 10.
/// Notifications scheduled without permission are silently dropped.
///
/// ## Why This Matters
///
/// - Notifications won't show without permission
/// - Permission must be requested before scheduling
/// - Different from push notification permission
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Schedules without permission check
/// await FlutterLocalNotificationsPlugin().zonedSchedule(...);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Request permission first
/// final granted = await flutterLocalNotificationsPlugin
///     .resolvePlatformSpecificImplementation<
///         IOSFlutterLocalNotificationsPlugin>()
///     ?.requestPermissions(alert: true, badge: true, sound: true);
///
/// if (granted ?? false) {
///   await flutterLocalNotificationsPlugin.zonedSchedule(...);
/// }
/// ```
///
/// @see [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
class RequireIosLocalNotificationPermissionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLocalNotificationPermissionRule].
  const RequireIosLocalNotificationPermissionRule() : super(code: _code);

  /// Notifications without permission fail silently.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_local_notification_permission',
    problemMessage:
        'Local notification scheduling detected. Ensure iOS notification '
        'permission is requested before scheduling.',
    correctionMessage:
        'Call requestPermissions() on IOSFlutterLocalNotificationsPlugin '
        'before scheduling notifications.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Notification scheduling methods.
  static const Set<String> _scheduleMethods = {
    'zonedSchedule',
    'schedule',
    'periodicallyShow',
    'showDailyAtTime',
    'showWeeklyAtDayAndTime',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if file has permission request
    final String fileSource = resolver.source.contents.data;
    final bool hasPermissionRequest =
        fileSource.contains('requestPermissions') ||
            fileSource.contains('IOSFlutterLocalNotificationsPlugin');

    if (hasPermissionRequest) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_scheduleMethods.contains(methodName)) {
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource();
          if (targetSource.contains('Notification') ||
              targetSource.contains('notification')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when device model names are hardcoded instead of detected.
///
/// Hardcoding device model names (iPhone, iPad, etc.) causes maintenance
/// issues when Apple releases new devices with different characteristics.
///
/// ## Why This Matters
///
/// - New devices released annually break hardcoded checks
/// - Screen sizes, notch presence, etc. change with new models
/// - Use platform APIs to detect capabilities, not device names
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// if (deviceModel.contains('iPhone 14') || deviceModel.contains('iPhone 15')) {
///   // Dynamic Island handling
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use MediaQuery for safe area detection
/// final topPadding = MediaQuery.of(context).padding.top;
/// final hasDynamicIsland = topPadding > 50;
/// ```
///
/// @see [device_info_plus](https://pub.dev/packages/device_info_plus)
class AvoidIosHardcodedDeviceModelRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedDeviceModelRule].
  const AvoidIosHardcodedDeviceModelRule() : super(code: _code);

  /// Hardcoded device models break with new releases.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_hardcoded_device_model',
    problemMessage:
        'Hardcoded iOS device model detected. Device-specific code breaks '
        'when new devices are released.',
    correctionMessage:
        'Use platform APIs to detect capabilities instead of device names.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Device model patterns to detect.
  static final RegExp _deviceModelPattern = RegExp(
    r'iPhone\s*\d+|iPad\s*(Pro|Air|mini)?\s*\d*|iPod\s+touch',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip test files
      final String filePath = resolver.source.fullName;
      if (filePath.contains('_test.dart') || filePath.contains('/test/')) {
        return;
      }

      if (_deviceModelPattern.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when App Groups capability may be needed but not mentioned.
///
/// iOS App Groups are required for sharing data between:
/// - Main app and app extensions (widgets, share extensions, etc.)
/// - Main app and Watch app
/// - Main app and Today extension
///
/// ## Required for
///
/// - Home Screen widgets (WidgetKit)
/// - Share extensions
/// - Watch apps
/// - Today extensions
/// - Action extensions
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// // Widget extension data sharing
/// final sharedDefaults = UserDefaults(suiteName: 'group.com.example.app');
/// ```
///
/// @see [App Groups](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
class RequireIosAppGroupCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppGroupCapabilityRule].
  const RequireIosAppGroupCapabilityRule() : super(code: _code);

  /// Missing App Groups causes silent data sharing failures.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_app_group_capability',
    problemMessage:
        'App extension data sharing detected. Ensure App Groups capability '
        'is enabled in Xcode for both main app and extensions.',
    correctionMessage:
        'Add App Groups capability in Xcode Signing & Capabilities. '
        'Use same group ID in both main app and extensions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Patterns indicating App Groups usage.
  static const Set<String> _appGroupPatterns = {
    'suiteName',
    'group.',
    'UserDefaults',
    'NSUserDefaults',
    'sharedContainerIdentifier',
    'WidgetCenter',
    'reloadTimelines',
    'reloadAllTimelines',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;

      // Check for group. prefix in suite name
      if (value.startsWith('group.')) {
        reporter.atNode(node, code);
        hasReported = true;
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;

      if (_appGroupPatterns.contains(methodName)) {
        reporter.atNode(node, code);
        hasReported = true;
      }
    });
  }
}

/// Warns when HealthKit APIs are used without authorization check.
///
/// iOS HealthKit requires explicit user authorization for each data type.
/// Apps must request authorization before reading or writing health data.
///
/// ## Authorization Requirements
///
/// - Separate read and write permissions
/// - Per-data-type authorization
/// - HealthKit capability in Xcode
/// - NSHealthShareUsageDescription in Info.plist (read)
/// - NSHealthUpdateUsageDescription in Info.plist (write)
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Reading without authorization check
/// final steps = await health.getHealthDataFromTypes(
///   startTime: yesterday,
///   endTime: now,
///   types: [HealthDataType.STEPS],
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Request authorization first
/// final authorized = await health.requestAuthorization([HealthDataType.STEPS]);
/// if (authorized) {
///   final steps = await health.getHealthDataFromTypes(...);
/// }
/// ```
///
/// @see [HealthKit](https://developer.apple.com/documentation/healthkit)
/// @see [health package](https://pub.dev/packages/health)
class RequireIosHealthKitAuthorizationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosHealthKitAuthorizationRule].
  const RequireIosHealthKitAuthorizationRule() : super(code: _code);

  /// HealthKit access without authorization fails silently.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_healthkit_authorization',
    problemMessage:
        'HealthKit data access detected. Ensure authorization is requested '
        'before reading or writing health data.',
    correctionMessage:
        'Call requestAuthorization() before accessing health data. '
        'Add NSHealthShareUsageDescription and NSHealthUpdateUsageDescription '
        'to Info.plist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// HealthKit data access methods.
  static const Set<String> _healthDataMethods = {
    'getHealthDataFromTypes',
    'writeHealthData',
    'getHealthDataFromType',
    'getTotalStepsInInterval',
    'writeWorkoutData',
    'writeAudiogram',
    'writeBloodPressure',
    'writeMeal',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if file has authorization call
    final String fileSource = resolver.source.contents.data;
    final bool hasAuthCheck = fileSource.contains('requestAuthorization') ||
        fileSource.contains('hasAuthorization') ||
        fileSource.contains('isAuthorized');

    if (hasAuthCheck) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_healthDataMethods.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS app may not meet Hardened Runtime requirements.
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

  static const LintCode _code = LintCode(
    name: 'require_macos_hardened_runtime',
    problemMessage:
        'Operation detected that may require Hardened Runtime entitlement. '
        'Ensure proper entitlements are configured for notarization.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_macos_catalyst_unsupported_apis',
    problemMessage: 'API detected that is not available on Mac Catalyst. '
        'Add platform check if supporting Mac Catalyst.',
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

/// Warns when Siri Shortcuts are implemented without intent definition.
///
/// iOS Siri Shortcuts require an Intent Definition file (.intentdefinition)
/// in Xcode for custom intents. Without it, Siri integration won't work.
///
/// ## Requirements
///
/// 1. SiriKit capability in Xcode
/// 2. Intent Definition file for custom intents
/// 3. NSUserActivityTypes in Info.plist
/// 4. Handle intents in AppDelegate
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// // Siri shortcut donation
/// await FlutterSiriShortcuts.donate(
///   FlutterSiriActivity(
///     title: 'Order Coffee',
///     suggestedInvocationPhrase: 'Order my usual',
///   ),
/// );
/// ```
///
/// @see [SiriKit](https://developer.apple.com/documentation/sirikit)
/// @see [flutter_siri_shortcuts](https://pub.dev/packages/flutter_siri_shortcuts)
class RequireIosSiriIntentDefinitionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosSiriIntentDefinitionRule].
  const RequireIosSiriIntentDefinitionRule() : super(code: _code);

  /// Missing Siri intent definition causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_siri_intent_definition',
    problemMessage:
        'Siri Shortcuts usage detected. Ensure Intent Definition file '
        'exists in Xcode and SiriKit capability is enabled.',
    correctionMessage:
        'Add Intent Definition file in Xcode: File > New > File > Intent Definition. '
        'Enable SiriKit capability in Signing & Capabilities.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Siri-related patterns.
  static const Set<String> _siriPatterns = {
    'SiriShortcuts',
    'FlutterSiriActivity',
    'donate',
    'INIntent',
    'INInteraction',
    'NSUserActivity',
    'suggestedInvocationPhrase',
    'shortcutIdentifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;

      for (final String pattern in _siriPatterns) {
        if (typeName.contains(pattern)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target != null) {
        final String fullCall = '${target.toSource()}.$methodName';
        if (fullCall.contains('Siri') && methodName == 'donate') {
          reporter.atNode(node, code);
          hasReported = true;
        }
      }
    });
  }
}

/// Warns when iOS Home Screen widgets are implemented without WidgetKit setup.
///
/// iOS Home Screen widgets (WidgetKit) require specific Xcode setup:
/// - Widget Extension target
/// - App Groups for data sharing
/// - Timeline Provider implementation
///
/// ## Setup Requirements
///
/// 1. Add Widget Extension target in Xcode
/// 2. Enable App Groups capability in both targets
/// 3. Use shared UserDefaults with suite name
/// 4. Call WidgetCenter.shared.reloadTimelines
///
/// ## Example
///
/// **Triggers reminder:**
/// ```dart
/// // Triggering widget update from Flutter
/// await HomeWidget.updateWidget(name: 'MyWidgetProvider');
/// ```
///
/// @see [WidgetKit](https://developer.apple.com/documentation/widgetkit)
/// @see [home_widget package](https://pub.dev/packages/home_widget)
class RequireIosWidgetExtensionCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosWidgetExtensionCapabilityRule].
  const RequireIosWidgetExtensionCapabilityRule() : super(code: _code);

  /// Missing widget extension setup causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_widget_extension_capability',
    problemMessage:
        'Home Screen widget usage detected. Ensure Widget Extension target '
        'and App Groups are configured in Xcode.',
    correctionMessage:
        'Create Widget Extension target in Xcode. Enable App Groups in both '
        'main app and extension. Use shared UserDefaults for data.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Widget-related patterns.
  static const Set<String> _widgetPatterns = {
    'HomeWidget',
    'updateWidget',
    'WidgetCenter',
    'reloadTimelines',
    'reloadAllTimelines',
    'WidgetConfiguration',
    'TimelineProvider',
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

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (_widgetPatterns.contains(methodName)) {
        reporter.atNode(node, code);
        hasReported = true;
        return;
      }

      if (target != null) {
        final String targetSource = target.toSource();
        for (final String pattern in _widgetPatterns) {
          if (targetSource.contains(pattern)) {
            reporter.atNode(node, code);
            hasReported = true;
            return;
          }
        }
      }
    });
  }
}

/// Warns when in-app purchases are used without receipt validation.
///
/// iOS in-app purchases must be validated to prevent fraud. Local receipt
/// validation is insufficient; server-side validation is required.
///
/// ## Why This Matters
///
/// - Local validation can be bypassed by jailbroken devices
/// - Receipt must be validated with Apple's servers
/// - Subscription status requires server-side verification
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // No receipt validation
/// final result = await InAppPurchase.instance.buyNonConsumable(
///   purchaseParam: purchaseParam,
/// );
/// if (result) {
///   // Unlock feature immediately
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await InAppPurchase.instance.buyNonConsumable(...);
/// if (result) {
///   // Validate receipt with your server
///   final valid = await validateReceiptWithServer(result.receiptData);
///   if (valid) {
///     // Unlock feature
///   }
/// }
/// ```
///
/// @see [in_app_purchase](https://pub.dev/packages/in_app_purchase)
/// @see [Validating Receipts](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/validating_receipts_with_the_app_store)
class RequireIosReceiptValidationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosReceiptValidationRule].
  const RequireIosReceiptValidationRule() : super(code: _code);

  /// Missing receipt validation enables fraud.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_receipt_validation',
    problemMessage:
        'In-app purchase detected. Ensure receipt is validated with server, '
        'not just locally.',
    correctionMessage:
        'Send receipt data to your server for validation with Apple. '
        'Local-only validation can be bypassed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// In-app purchase methods.
  static const Set<String> _purchaseMethods = {
    'buyNonConsumable',
    'buyConsumable',
    'completePurchase',
    'restorePurchases',
    'purchaseUpdatedStream',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if file has validation logic
    final String fileSource = resolver.source.contents.data;
    final bool hasValidation = fileSource.contains('validateReceipt') ||
        fileSource.contains('verifyPurchase') ||
        fileSource.contains('/verify') ||
        fileSource.contains('receipt_validation');

    if (hasValidation) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_purchaseMethods.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

// ============================================================================
// v2.3.16 - Even More iOS/macOS Platform Rules
// ============================================================================

/// Warns when Core Data or Realm sync is used without conflict resolution.
///
/// Cloud-synced databases can have conflicts when the same record is
/// modified on multiple devices. Without conflict resolution, data loss occurs.
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // No conflict handling
/// await realm.syncSession.resume();
/// ```
///
/// **GOOD:**
/// ```dart
/// realm.syncSession.connectionStateChanges.listen((change) {
///   if (change.current == ConnectionState.connected) {
///     // Handle sync conflicts
///   }
/// });
/// ```
class RequireIosDatabaseConflictResolutionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosDatabaseConflictResolutionRule].
  const RequireIosDatabaseConflictResolutionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_database_conflict_resolution',
    problemMessage:
        'Database sync detected. Ensure conflict resolution is implemented '
        'for multi-device sync scenarios.',
    correctionMessage:
        'Implement conflict resolution handlers for sync errors.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _syncPatterns = {
    'syncSession',
    'CloudKit',
    'NSPersistentCloudKitContainer',
    'SyncConfiguration',
    'FlexibleSyncConfiguration',
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
      if (target != null) {
        final String targetSource = target.toSource();
        for (final String pattern in _syncPatterns) {
          if (targetSource.contains(pattern)) {
            reporter.atNode(node, code);
            hasReported = true;
            return;
          }
        }
      }
    });
  }
}

/// Warns when Core Location continuous tracking may drain battery.
///
/// iOS location services have significant battery impact. Apps should use
/// appropriate accuracy levels and stop tracking when not needed.
///
/// ## Battery Impact
///
/// | Accuracy | Battery Impact |
/// |----------|---------------|
/// | best | Very High |
/// | nearestTenMeters | High |
/// | hundredMeters | Medium |
/// | kilometer | Low |
/// | threeKilometers | Very Low |
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Always-on high accuracy
/// await Geolocator.getPositionStream(
///   locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use appropriate accuracy for use case
/// await Geolocator.getPositionStream(
///   locationSettings: LocationSettings(
///     accuracy: LocationAccuracy.medium,
///     distanceFilter: 100, // Only update every 100 meters
///   ),
/// );
/// ```
class AvoidIosContinuousLocationTrackingRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosContinuousLocationTrackingRule].
  const AvoidIosContinuousLocationTrackingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_continuous_location_tracking',
    problemMessage: 'Continuous location tracking detected with high accuracy. '
        'Consider using lower accuracy or distance filters to save battery.',
    correctionMessage:
        'Use LocationAccuracy.medium or lower, and set distanceFilter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'getPositionStream' ||
          methodName == 'startListening' ||
          methodName == 'startLocationUpdates') {
        // Check if high accuracy is used
        final String argSource = node.argumentList.toSource();
        if (argSource.contains('best') ||
            argSource.contains('bestForNavigation') ||
            argSource.contains('high')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when background audio capability may be needed.
///
/// iOS requires Background Modes capability with "Audio, AirPlay, and Picture in Picture"
/// enabled for apps that play audio in the background.
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// final player = AudioPlayer();
/// await player.play(UrlSource('https://example.com/audio.mp3'));
/// ```
class RequireIosBackgroundAudioCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBackgroundAudioCapabilityRule].
  const RequireIosBackgroundAudioCapabilityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_background_audio_capability',
    problemMessage:
        'Audio playback detected. If audio should play in background, '
        'enable Background Modes > Audio capability in Xcode.',
    correctionMessage:
        'Add Background Modes capability and enable Audio, AirPlay, '
        'and Picture in Picture.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _audioPatterns = {
    'AudioPlayer',
    'AudioCache',
    'AssetsAudioPlayer',
    'just_audio',
    'audioplayers',
    'play',
    'setUrl',
    'setAsset',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;
      if (_audioPatterns.contains(typeName)) {
        reporter.atNode(node, code);
        hasReported = true;
      }
    });
  }
}

/// Warns when StoreKit 2 APIs should be preferred over original StoreKit.
///
/// Apple recommends StoreKit 2 for new apps. It has better Swift concurrency
/// support, simpler API, and server-side receipt verification.
///
/// ## StoreKit 2 Benefits
///
/// - Built-in async/await support
/// - Automatic receipt verification
/// - Subscription status API
/// - Better transaction handling
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// // Original StoreKit API
/// await InAppPurchase.instance.buyNonConsumable(...);
/// ```
class PreferIosStoreKit2Rule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosStoreKit2Rule].
  const PreferIosStoreKit2Rule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_storekit2',
    problemMessage:
        'Consider using StoreKit 2 APIs for new in-app purchase implementations. '
        'StoreKit 2 offers better async support and automatic receipt verification.',
    correctionMessage:
        'Evaluate migrating to StoreKit 2 for simpler IAP implementation.',
    errorSeverity: DiagnosticSeverity.INFO,
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

      final Expression? target = node.target;
      if (target != null && target.toSource().contains('InAppPurchase')) {
        reporter.atNode(node, code);
        hasReported = true;
      }
    });
  }
}

/// Warns when App Clip usage is detected without size considerations.
///
/// App Clips have a 10 MB size limit. Including large dependencies
/// can cause the App Clip to exceed this limit.
///
/// ## Size Limit
///
/// - App Clips must be under 10 MB
/// - Shared code with main app still counts
/// - Images and assets add up quickly
///
/// ## Example
///
/// **Triggers warning:**
/// ```dart
/// // App Clip code should be lightweight
/// import 'package:heavy_ml_package/ml.dart';
/// ```
class RequireIosAppClipSizeLimitRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppClipSizeLimitRule].
  const RequireIosAppClipSizeLimitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_app_clip_size_limit',
    problemMessage:
        'App Clip detected. Ensure App Clip bundle stays under 10 MB. '
        'Large dependencies can exceed this limit.',
    correctionMessage: 'Minimize dependencies and assets in App Clip target. '
        'Consider lazy loading heavy features.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if file path suggests App Clip
    final String filePath = resolver.source.fullName;
    if (!filePath.contains('app_clip') && !filePath.contains('AppClip')) {
      return;
    }

    bool hasReported = false;

    context.registry.addImportDirective((ImportDirective node) {
      if (hasReported) return;

      final String? uri = node.uri.stringValue;
      if (uri != null) {
        // Warn about potentially large packages
        if (uri.contains('tensorflow') ||
            uri.contains('firebase') ||
            uri.contains('video_player') ||
            uri.contains('webview')) {
          reporter.atNode(node, code);
          hasReported = true;
        }
      }
    });
  }
}

/// Warns when iOS Keychain is accessed without considering iCloud sync.
///
/// Keychain items sync across devices via iCloud by default. For sensitive
/// data that should stay on one device, use kSecAttrSynchronizable = false.
///
/// ## Sync Behavior
///
/// | Accessibility | Syncs to iCloud |
/// |---------------|-----------------|
/// | whenUnlocked | Yes |
/// | whenUnlockedThisDeviceOnly | No |
/// | afterFirstUnlock | Yes |
/// | afterFirstUnlockThisDeviceOnly | No |
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // May sync to other devices
/// await secureStorage.write(key: 'private_key', value: key);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Device-only storage
/// await secureStorage.write(
///   key: 'private_key',
///   value: key,
///   iOptions: IOSOptions(
///     accessibility: KeychainAccessibility.when_unlocked_this_device_only,
///   ),
/// );
/// ```
class RequireIosKeychainSyncAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosKeychainSyncAwarenessRule].
  const RequireIosKeychainSyncAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_keychain_sync_awareness',
    problemMessage:
        'Keychain write of sensitive key detected. Consider if this should '
        'sync across devices via iCloud Keychain.',
    correctionMessage:
        'For device-only secrets, use accessibility ending in ThisDeviceOnly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _sensitiveKeyPatterns = {
    'private',
    'secret',
    'encryption',
    'signing',
    'biometric',
    'device_id',
    'device_key',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'write') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('secure') &&
          !targetSource.contains('keychain')) {
        return;
      }

      // Check if key contains sensitive patterns
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'key') {
          final String keyValue = arg.expression.toSource().toLowerCase();
          for (final String pattern in _sensitiveKeyPatterns) {
            if (keyValue.contains(pattern)) {
              // Check if ThisDeviceOnly is specified
              final String fullArgs = node.argumentList.toSource();
              if (!fullArgs.contains('ThisDeviceOnly') &&
                  !fullArgs.contains('this_device_only')) {
                reporter.atNode(node, code);
              }
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when iOS Share Sheet is used without proper UTI declarations.
///
/// For sharing custom file types, your app needs UTI declarations in Info.plist.
/// Without them, files may not appear in the share sheet or may fail to open.
///
/// ## Required for Custom Types
///
/// - Exported UTI declarations for types you create
/// - Imported UTI declarations for types you consume
/// - Document types for files you can open
class RequireIosShareSheetUtiDeclarationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosShareSheetUtiDeclarationRule].
  const RequireIosShareSheetUtiDeclarationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_share_sheet_uti_declaration',
    problemMessage:
        'File sharing with custom type detected. Ensure UTI is declared '
        'in Info.plist for custom file types.',
    correctionMessage:
        'Add UTExportedTypeDeclarations or UTImportedTypeDeclarations '
        'to Info.plist for custom file types.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'share' || methodName == 'shareFiles') {
        final String argSource = node.argumentList.toSource();
        // Check for custom file extensions
        if (argSource.contains('.custom') ||
            argSource.contains('.myapp') ||
            argSource.contains('mimeType:')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when SceneDelegate or AppDelegate lifecycle is not handled properly.
///
/// iOS 13+ apps use SceneDelegate for multi-window support. Apps need to
/// handle both app lifecycle and scene lifecycle correctly.
///
/// ## Lifecycle Methods
///
/// - SceneDelegate: sceneDidBecomeActive, sceneWillResignActive
/// - AppDelegate: applicationDidBecomeActive, applicationWillResignActive
///
/// For Flutter apps, use WidgetsBindingObserver.didChangeAppLifecycleState.
class RequireIosLifecycleHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLifecycleHandlingRule].
  const RequireIosLifecycleHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_lifecycle_handling',
    problemMessage:
        'Timer or subscription detected without lifecycle handling. '
        'Stop background work when app is inactive to save battery.',
    correctionMessage: 'Implement WidgetsBindingObserver and pause/resume in '
        'didChangeAppLifecycleState.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Check if file has lifecycle handling
    if (fileSource.contains('WidgetsBindingObserver') ||
        fileSource.contains('didChangeAppLifecycleState') ||
        fileSource.contains('AppLifecycleListener')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check for Timer.periodic
      if (target != null &&
          target.toSource() == 'Timer' &&
          methodName == 'periodic') {
        reporter.atNode(node, code);
        return;
      }

      // Check for stream subscriptions
      if (methodName == 'listen') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when NSUbiquitousKeyValueStore (iCloud Key-Value Storage) is used.
///
/// iCloud Key-Value Storage has limitations:
/// - 1 MB total storage limit
/// - 1024 keys maximum
/// - Not for large data or frequent updates
///
/// ## Best Practices
///
/// - Use for small user preferences only
/// - Don't store large data structures
/// - Handle conflicts (last write wins)
class RequireIosIcloudKvstoreLimitationsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosIcloudKvstoreLimitationsRule].
  const RequireIosIcloudKvstoreLimitationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_icloud_kvstore_limitations',
    problemMessage:
        'iCloud Key-Value Storage has 1 MB limit and 1024 keys max. '
        'Use only for small preferences.',
    correctionMessage:
        'For larger data, use CloudKit or iCloud Documents instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (value.contains('NSUbiquitousKeyValueStore') ||
          value.contains('ubiquitous_key_value')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when critical accessibility features may be missing.
///
/// iOS apps should support VoiceOver and other accessibility features.
/// Common issues include missing labels, poor contrast, and touch targets.
///
/// ## VoiceOver Requirements
///
/// - All interactive elements need labels
/// - Images need descriptions
/// - Custom controls need traits
class RequireIosAccessibilityLabelsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAccessibilityLabelsRule].
  const RequireIosAccessibilityLabelsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_accessibility_labels',
    problemMessage:
        'Interactive widget without Semantics wrapper. VoiceOver users '
        'cannot identify this element.',
    correctionMessage:
        'Wrap with Semantics widget and provide label for VoiceOver.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      // Check for icon buttons without semantics
      if (typeName == 'IconButton') {
        final String argSource = node.argumentList.toSource();
        if (!argSource.contains('tooltip') &&
            !fileSource.contains('Semantics')) {
          reporter.atNode(node, code);
        }
      }

      // Check for GestureDetector on images
      if (typeName == 'GestureDetector') {
        final String argSource = node.argumentList.toSource();
        if (argSource.contains('Image') &&
            !argSource.contains('semanticLabel') &&
            !fileSource.contains('Semantics')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when iOS app may not handle all device orientations.
///
/// Apps should explicitly declare supported orientations in Info.plist
/// and handle orientation changes gracefully.
///
/// ## Info.plist Keys
///
/// - UISupportedInterfaceOrientations (iPhone)
/// - UISupportedInterfaceOrientations~ipad (iPad)
class RequireIosOrientationHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosOrientationHandlingRule].
  const RequireIosOrientationHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_orientation_handling',
    problemMessage:
        'Orientation lock detected. Ensure Info.plist declares supported '
        'orientations and UI handles all locked orientations.',
    correctionMessage:
        'Set UISupportedInterfaceOrientations in Info.plist to match '
        'SystemChrome.setPreferredOrientations calls.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'setPreferredOrientations') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when deep linking may conflict with iOS Universal Links.
///
/// iOS Universal Links require exact domain matching. Subdomains and
/// path variations can cause routing issues.
class RequireIosUniversalLinksDomainMatchingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosUniversalLinksDomainMatchingRule].
  const RequireIosUniversalLinksDomainMatchingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_universal_links_domain_matching',
    problemMessage:
        'Deep link pattern detected. Ensure apple-app-site-association '
        'paths match exactly for Universal Links to work.',
    correctionMessage:
        'Verify apple-app-site-association on server matches app paths exactly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (typeName == 'GoRoute' || typeName == 'MaterialPageRoute') {
        final String argSource = node.argumentList.toSource();
        // Check for deep link paths with parameters
        if (argSource.contains('/:') || argSource.contains('/:id')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when NFC usage is detected without capability check.
///
/// NFC is not available on all iOS devices. Apps should check capability
/// before attempting NFC operations.
///
/// ## Device Compatibility
///
/// - NFC reading: iPhone 7 and later
/// - NFC writing: iPhone 7 and later with iOS 13+
/// - Background NFC: iPhone XS and later
class RequireIosNfcCapabilityCheckRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosNfcCapabilityCheckRule].
  const RequireIosNfcCapabilityCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_nfc_capability_check',
    problemMessage: 'NFC usage detected. Not all iOS devices support NFC. '
        'Check capability before use.',
    correctionMessage:
        'Use NFCNDEFReaderSession.readingAvailable before scanning.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _nfcPatterns = {
    'NfcManager',
    'NFCNDEFReaderSession',
    'startSession',
    'readNdef',
    'writeNdef',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    if (fileSource.contains('isAvailable') ||
        fileSource.contains('readingAvailable') ||
        fileSource.contains('NFCReaderSession.readingAvailable')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_nfcPatterns.contains(methodName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when CallKit integration may be missing for VoIP apps.
///
/// iOS VoIP apps must use CallKit to display the native call UI.
/// Apps that don't use CallKit have limited functionality.
///
/// ## CallKit Requirements
///
/// - CXProvider for incoming calls
/// - CXCallController for outgoing calls
/// - Push notifications for VoIP
class RequireIosCallkitIntegrationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosCallkitIntegrationRule].
  const RequireIosCallkitIntegrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_callkit_integration',
    problemMessage:
        'VoIP call handling detected. iOS requires CallKit for native call UI.',
    correctionMessage:
        'Implement CallKit using flutter_callkit_incoming or similar package.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _voipPatterns = {
    'voip',
    'incoming_call',
    'outgoing_call',
    'call_state',
    'WebRTC',
    'Twilio',
    'Agora',
    'Vonage',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Check if CallKit is already integrated
    if (fileSource.contains('CallKit') ||
        fileSource.contains('flutter_callkit') ||
        fileSource.contains('CXProvider')) {
      return;
    }

    bool hasReported = false;

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value.toLowerCase();
      for (final String pattern in _voipPatterns) {
        if (value.contains(pattern.toLowerCase())) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when CarPlay integration may need additional setup.
///
/// CarPlay apps require specific entitlements and must follow
/// Apple's CarPlay App Programming Guide.
///
/// ## Requirements
///
/// - CarPlay entitlement (approved by Apple)
/// - CPTemplateApplicationSceneDelegate
/// - Limited UI templates
class RequireIosCarplaySetupRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosCarplaySetupRule].
  const RequireIosCarplaySetupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_carplay_setup',
    problemMessage:
        'CarPlay-related code detected. CarPlay requires Apple approval '
        'and specific entitlements.',
    correctionMessage: 'Apply for CarPlay entitlement at developer.apple.com. '
        'Implement CPTemplateApplicationSceneDelegate.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _carplayPatterns = {
    'CarPlay',
    'CPTemplate',
    'CPListTemplate',
    'CPMapTemplate',
    'flutter_carplay',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;
      for (final String pattern in _carplayPatterns) {
        if (typeName.contains(pattern)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when Live Activities may need proper configuration.
///
/// iOS 16.1+ Live Activities require:
/// - ActivityKit capability
/// - Widget Extension with ActivityConfiguration
/// - Proper push notification setup for remote updates
class RequireIosLiveActivitiesSetupRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLiveActivitiesSetupRule].
  const RequireIosLiveActivitiesSetupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_live_activities_setup',
    problemMessage:
        'Live Activity usage detected. Ensure ActivityKit capability '
        'and Widget Extension are configured.',
    correctionMessage: 'Add Widget Extension with ActivityConfiguration. '
        'Enable Push Notifications for remote updates.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _liveActivityPatterns = {
    'LiveActivity',
    'ActivityKit',
    'ActivityConfiguration',
    'ActivityAttributes',
    'live_activities',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;
      for (final String pattern in _liveActivityPatterns) {
        if (typeName.contains(pattern)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;
      for (final String pattern in _liveActivityPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when ProMotion display support may be needed.
///
/// iPhone 13 Pro and later have ProMotion displays (120Hz).
/// Apps should use CADisplayLink for smooth animations on these devices.
class RequireIosPromotionDisplaySupportRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPromotionDisplaySupportRule].
  const RequireIosPromotionDisplaySupportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_promotion_display_support',
    problemMessage:
        'Manual frame timing detected. ProMotion displays run at 120Hz. '
        'Use Flutter animations for automatic frame rate adaptation.',
    correctionMessage:
        'Use AnimationController instead of manual timing for smooth animations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (typeName == 'Duration') {
        final String argSource = node.argumentList.toSource();
        // Check for hardcoded 60fps timing (16-17ms)
        if (argSource.contains('milliseconds: 16') ||
            argSource.contains('milliseconds: 17')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Photo Library limited access may not be handled.
///
/// iOS 14+ supports limited photo library access. Apps should handle
/// the case where user only grants access to selected photos.
class RequireIosPhotoLibraryLimitedAccessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPhotoLibraryLimitedAccessRule].
  const RequireIosPhotoLibraryLimitedAccessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_photo_library_limited_access',
    problemMessage:
        'Photo library access detected. Handle iOS 14+ limited access mode '
        'where user may only grant access to selected photos.',
    correctionMessage:
        'Check for PHAuthorizationStatus.limited and provide UI to '
        'modify selection.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if limited access is handled
    if (fileSource.contains('limited') ||
        fileSource.contains('PHAuthorizationStatus') ||
        fileSource.contains('presentLimitedLibraryPicker')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'pickImage' ||
          methodName == 'pickMultiImage' ||
          methodName == 'pickVideo') {
        reporter.atNode(node, code);
      }
    });
  }
}

// ============================================================================
// v2.3.17 - Additional iOS/macOS Platform Rules
// ============================================================================

/// Warns when iOS pasteboard access may trigger iOS 16+ notification.
///
/// iOS 16+ shows a notification when apps access the pasteboard. Apps should
/// provide clear UX indication before reading clipboard content.
///
/// ## iOS 16+ Changes
///
/// - System shows "pasted from \[app\]" notification
/// - Users may find unexpected clipboard access intrusive
/// - Only access clipboard when user explicitly triggers paste
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Reading clipboard without user action
/// final data = await Clipboard.getData(Clipboard.kTextPlain);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Only read after user taps paste button
/// onPastePressed: () async {
///   final data = await Clipboard.getData(Clipboard.kTextPlain);
/// }
/// ```
class RequireIosPasteboardPrivacyHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPasteboardPrivacyHandlingRule].
  const RequireIosPasteboardPrivacyHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_pasteboard_privacy_handling',
    problemMessage:
        'Clipboard access detected. On iOS 16+, users see a notification '
        'when apps read the clipboard. Only access after explicit user action.',
    correctionMessage:
        'Access clipboard only in response to user paste action.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target != null &&
          target.toSource() == 'Clipboard' &&
          methodName == 'getData') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when background refresh may need capability declaration.
///
/// iOS apps that fetch data in the background must declare the capability
/// in Info.plist and handle the background fetch appropriately.
///
/// ## Requirements
///
/// - UIBackgroundModes array with "fetch" value in Info.plist
/// - Application delegate handles `application:performFetchWithCompletionHandler:`
/// - Background refresh must complete within 30 seconds
class RequireIosBackgroundRefreshDeclarationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBackgroundRefreshDeclarationRule].
  const RequireIosBackgroundRefreshDeclarationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_background_refresh_declaration',
    problemMessage:
        'Background task scheduling detected. Ensure UIBackgroundModes '
        'includes "fetch" in Info.plist for background refresh.',
    correctionMessage: 'Add UIBackgroundModes with "fetch" to Info.plist.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _backgroundPatterns = {
    'Workmanager',
    'BackgroundFetch',
    'registerPeriodicTask',
    'registerOneOffTask',
    'BGTaskScheduler',
    'backgroundFetch',
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

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      for (final String pattern in _backgroundPatterns) {
        if (methodName.contains(pattern) ||
            (target != null && target.toSource().contains(pattern))) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when iOS 13+ Scene Delegate lifecycle may not be handled.
///
/// iOS 13+ apps can support multiple windows using Scene Delegate.
/// Apps should handle scene lifecycle events, not just app lifecycle.
///
/// ## Scene Lifecycle
///
/// - sceneDidBecomeActive (replaces applicationDidBecomeActive for foreground)
/// - sceneWillResignActive (replaces applicationWillResignActive)
/// - sceneDidEnterBackground
/// - sceneWillEnterForeground
class RequireIosSceneDelegateAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosSceneDelegateAwarenessRule].
  const RequireIosSceneDelegateAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_scene_delegate_awareness',
    problemMessage:
        'App lifecycle handling detected. On iOS 13+, consider using '
        'scene-based lifecycle for multi-window support.',
    correctionMessage: 'Use WidgetsBindingObserver.didChangeAppLifecycleState '
        'which handles both app and scene lifecycle.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Check for app lifecycle handling
    if (fileSource.contains('WidgetsBindingObserver') &&
        fileSource.contains('didChangeAppLifecycleState')) {
      return; // Already using Flutter's unified lifecycle handler
    }

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (value.contains('applicationDidBecomeActive') ||
          value.contains('applicationWillResignActive') ||
          value.contains('applicationDidEnterBackground')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when MethodChannel observer cleanup may be missing.
///
/// MethodChannel listeners must be removed when no longer needed to
/// prevent memory leaks and crashes from callbacks on disposed objects.
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   channel.setMethodCallHandler(_handleMethod);
/// }
/// // No cleanup!
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void dispose() {
///   channel.setMethodCallHandler(null);
///   super.dispose();
/// }
/// ```
class RequireIosMethodChannelCleanupRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosMethodChannelCleanupRule].
  const RequireIosMethodChannelCleanupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_method_channel_cleanup',
    problemMessage:
        'MethodChannel handler set without cleanup. Set handler to null '
        'in dispose() to prevent memory leaks.',
    correctionMessage:
        'Add channel.setMethodCallHandler(null) in dispose() method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Check if there's proper cleanup
    if (fileSource.contains('setMethodCallHandler(null)') ||
        fileSource.contains('setMethodCallHandler( null)')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'setMethodCallHandler') {
        final String argSource = node.argumentList.toSource();
        if (!argSource.contains('null')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when force unwrapping in MethodChannel callbacks may cause crashes.
///
/// Native code may return unexpected null values. Using force unwrap (!)
/// on MethodChannel results can cause crashes on iOS/macOS.
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// final result = await channel.invokeMethod('getData');
/// final value = result!['key']; // Crash if null
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await channel.invokeMethod<Map>('getData');
/// final value = result?['key'] ?? defaultValue;
/// ```
class AvoidIosForceUnwrapInCallbacksRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosForceUnwrapInCallbacksRule].
  const AvoidIosForceUnwrapInCallbacksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_force_unwrap_in_callbacks',
    problemMessage:
        'Force unwrap on MethodChannel result detected. Native code may '
        'return null unexpectedly, causing crashes.',
    correctionMessage: 'Use null-safe access (?.) and provide default values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Only check files with MethodChannel
    if (!fileSource.contains('MethodChannel') &&
        !fileSource.contains('invokeMethod')) {
      return;
    }

    context.registry.addPostfixExpression((PostfixExpression node) {
      if (node.operator.lexeme == '!') {
        // Check if this is related to invokeMethod result
        final String source = node.toSource();
        if (source.contains('result') || source.contains('Response')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when in-app review may be requested too frequently.
///
/// Apple limits StoreKit review requests to 3 times per year per user.
/// Requesting more frequently results in no prompt being shown.
///
/// ## Apple Guidelines
///
/// - Maximum 3 prompts per 365-day period
/// - Don't prompt during onboarding
/// - Don't prompt after errors or failures
/// - Let users complete a task before prompting
class RequireIosReviewPromptFrequencyRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosReviewPromptFrequencyRule].
  const RequireIosReviewPromptFrequencyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_review_prompt_frequency',
    problemMessage:
        'In-app review detected. Apple limits StoreKit prompts to 3x per year. '
        'Track and limit prompt frequency.',
    correctionMessage:
        'Implement review prompt tracking to respect Apple\'s limits.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if frequency tracking exists
    if (fileSource.contains('reviewCount') ||
        fileSource.contains('lastReviewDate') ||
        fileSource.contains('reviewPromptCount')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'requestReview' ||
          node.methodName.name == 'openStoreListing') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS window restoration may not be implemented.
///
/// macOS users expect window position and size to be restored between
/// app launches. Apps should implement NSWindowRestoration or equivalent.
class RequireMacosWindowRestorationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireMacosWindowRestorationRule].
  const RequireMacosWindowRestorationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_macos_window_restoration',
    problemMessage:
        'macOS window configuration detected. Consider implementing window '
        'state restoration for better UX.',
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

/// Warns when iOS deployment target may not match API usage.
///
/// Using APIs from newer iOS versions without version guards causes
/// crashes on older devices.
///
/// ## Common Version Requirements
///
/// - CupertinoContextMenu: iOS 13.0+
/// - SharePlay: iOS 15.0+
/// - Live Activities: iOS 16.1+
/// - StandBy mode: iOS 17.0+
class RequireIosDeploymentTargetConsistencyRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosDeploymentTargetConsistencyRule].
  const RequireIosDeploymentTargetConsistencyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_deployment_target_consistency',
    problemMessage:
        'API requiring iOS 15+ detected. Ensure minimum deployment target '
        'matches or add version guards.',
    correctionMessage: 'Check iOS version before using newer APIs or increase '
        'minimum deployment target.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Map<String, String> _ios15PlusApis = {
    'SharePlay': 'iOS 15+',
    'GroupActivities': 'iOS 15+',
    'AttributedString': 'iOS 15+',
    'async': 'iOS 15+ (Swift concurrency)',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if version check exists
    if (fileSource.contains('@available') ||
        fileSource.contains('ProcessInfo') ||
        fileSource.contains('operatingSystemVersion')) {
      return;
    }

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      for (final String api in _ios15PlusApis.keys) {
        if (value.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when iOS Dynamic Island area may not be accounted for.
///
/// iPhone 14 Pro/15 Pro have Dynamic Island which takes up more
/// screen space than the notch. Fixed padding values don't adapt.
///
/// ## Device Variations
///
/// | Device | Top Safe Area |
/// |--------|---------------|
/// | iPhone X-13 (notch) | 44pt |
/// | iPhone 14 Pro (Dynamic Island) | 59pt |
/// | iPhone 15 Pro (Dynamic Island) | 59pt |
class RequireIosDynamicIslandSafeZonesRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosDynamicIslandSafeZonesRule].
  const RequireIosDynamicIslandSafeZonesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_dynamic_island_safe_zones',
    problemMessage:
        'Fixed top padding (44pt or 59pt) detected. Dynamic Island height '
        'varies by device. Use MediaQuery.padding.top instead.',
    correctionMessage:
        'Replace hardcoded value with MediaQuery.of(context).padding.top.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (typeName == 'EdgeInsets' || typeName == 'Padding') {
        final String argSource = node.argumentList.toSource();
        // Check for common notch/Dynamic Island heights
        if (argSource.contains('top: 44') ||
            argSource.contains('top: 47') ||
            argSource.contains('top: 59')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when iOS App Intents framework should be considered.
///
/// iOS 16+ introduces App Intents as the modern way to integrate with
/// Siri, Shortcuts, and Spotlight. Replaces older SiriKit Intents.
///
/// ## Migration
///
/// - INIntent → AppIntent
/// - IntentHandler → AppIntentsPackage
/// - Better Swift concurrency support
class PreferIosAppIntentsFrameworkRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosAppIntentsFrameworkRule].
  const PreferIosAppIntentsFrameworkRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_app_intents_framework',
    problemMessage:
        'Legacy SiriKit Intent detected. Consider migrating to App Intents '
        'framework (iOS 16+) for better Siri and Shortcuts integration.',
    correctionMessage:
        'Migrate from INIntent to AppIntent for modern Siri integration.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _legacySiriPatterns = {
    'INIntent',
    'IntentHandler',
    'INExtension',
    'INInteraction',
    'SiriKit',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;
      for (final String pattern in _legacySiriPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when macOS app may need Full Disk Access alternatives.
///
/// Full Disk Access requires user interaction in System Preferences.
/// Apps should use scoped file access (NSOpenPanel) when possible.
class AvoidMacosFullDiskAccessRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidMacosFullDiskAccessRule].
  const AvoidMacosFullDiskAccessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_macos_full_disk_access',
    problemMessage:
        'Accessing protected paths detected. Consider using NSOpenPanel '
        'for user-selected file access instead of Full Disk Access.',
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

/// Warns when iOS app may need age rating consideration.
///
/// Apps with user-generated content, web browsing, or mature themes
/// need appropriate age ratings in App Store Connect.
class RequireIosAgeRatingConsiderationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAgeRatingConsiderationRule].
  const RequireIosAgeRatingConsiderationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_age_rating_consideration',
    problemMessage: 'Feature requiring age rating consideration detected. '
        'Verify App Store Connect age rating matches app content.',
    correctionMessage:
        'Review App Store Connect age rating for user-generated content, '
        'web access, or mature themes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _ageRatingTriggers = {
    'WebView',
    'InAppWebView',
    'userContent',
    'chat',
    'dating',
    'gambling',
    'alcohol',
    'tobacco',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasReported = false;

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;
      for (final String trigger in _ageRatingTriggers) {
        if (typeName.contains(trigger)) {
          reporter.atNode(node, code);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when iOS certificate pinning may be needed for security.
///
/// High-security apps (banking, healthcare) should use certificate
/// pinning to prevent man-in-the-middle attacks.
class RequireIosCertificatePinningRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosCertificatePinningRule].
  const RequireIosCertificatePinningRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_certificate_pinning',
    problemMessage:
        'Sensitive API endpoint detected. Consider implementing SSL '
        'certificate pinning for additional security.',
    correctionMessage:
        'Use Dio with certificate pinning or platform-specific SSL pinning.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _sensitivePatterns = {
    '/auth',
    '/login',
    '/payment',
    '/bank',
    '/health',
    '/medical',
    '/financial',
    '/transfer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if pinning is implemented
    if (fileSource.contains('certificatePinner') ||
        fileSource.contains('sslPinning') ||
        fileSource.contains('SecurityContext')) {
      return;
    }

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value.toLowerCase();
      for (final String pattern in _sensitivePatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when iOS Keychain credential storage isn't using Keychain.
///
/// Credentials should be stored in iOS Keychain, not UserDefaults
/// or SharedPreferences which are not encrypted.
class RequireIosKeychainForCredentialsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosKeychainForCredentialsRule].
  const RequireIosKeychainForCredentialsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_ios_keychain_for_credentials',
    problemMessage:
        'Credential storage in SharedPreferences detected. Use iOS Keychain '
        '(flutter_secure_storage) for sensitive data.',
    correctionMessage:
        'Replace SharedPreferences with FlutterSecureStorage for credentials.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _credentialKeys = {
    'password',
    'token',
    'secret',
    'apiKey',
    'api_key',
    'accessToken',
    'access_token',
    'refreshToken',
    'refresh_token',
    'privateKey',
    'private_key',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check for SharedPreferences credential storage
      if ((methodName == 'setString' || methodName == 'getString') &&
          target != null &&
          target.toSource().toLowerCase().contains('prefs')) {
        final String argSource = node.argumentList.toSource().toLowerCase();
        for (final String key in _credentialKeys) {
          if (argSource.contains(key.toLowerCase())) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when iOS debug code may be included in release builds.
///
/// Debug logging, assertions, and test code should be removed or
/// conditionally compiled out of release builds.
class AvoidIosDebugCodeInReleaseRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosDebugCodeInReleaseRule].
  const AvoidIosDebugCodeInReleaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_debug_code_in_release',
    problemMessage:
        'Debug code detected. Ensure this is conditionally compiled out '
        'for release builds.',
    correctionMessage:
        'Wrap debug code in kDebugMode or assert() for automatic removal.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if kDebugMode guard exists
    if (fileSource.contains('kDebugMode') ||
        fileSource.contains('kReleaseMode') ||
        fileSource.contains('kProfileMode')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'print' || methodName == 'debugPrint') {
        // Check for debug-specific logging
        final String argSource = node.argumentList.toSource().toLowerCase();
        if (argSource.contains('debug') ||
            argSource.contains('test') ||
            argSource.contains('todo')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when iOS biometric authentication may need fallback.
///
/// Not all iOS devices support Face ID or Touch ID. Apps should
/// provide alternative authentication methods.
class RequireIosBiometricFallbackRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBiometricFallbackRule].
  const RequireIosBiometricFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_biometric_fallback',
    problemMessage:
        'Biometric authentication detected. Ensure fallback authentication '
        '(passcode) is available for devices without biometrics.',
    correctionMessage:
        'Handle BiometricType.none and provide alternative login method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if fallback is handled
    if (fileSource.contains('canCheckBiometrics') ||
        fileSource.contains('BiometricType.none') ||
        fileSource.contains('passcode') ||
        fileSource.contains('fallback')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'authenticate' ||
          node.methodName.name == 'authenticateWithBiometrics') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when macOS sandbox entitlements may be missing.
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

  static const LintCode _code = LintCode(
    name: 'require_macos_sandbox_entitlements',
    problemMessage: 'Feature requiring macOS sandbox entitlement detected. '
        'Ensure entitlements file includes required permissions.',
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

/// Warns when iOS app may send misleading push notifications.
///
/// Apple rejects apps that send push notifications unrelated to
/// the user's interests or that spam users.
class AvoidIosMisleadingPushNotificationsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosMisleadingPushNotificationsRule].
  const AvoidIosMisleadingPushNotificationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_misleading_push_notifications',
    problemMessage:
        'Marketing notification pattern detected. Push notifications must '
        'be relevant to user interests to comply with Apple guidelines.',
    correctionMessage: 'Ensure notifications are personalized and relevant. '
        'Avoid generic marketing messages.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _marketingPatterns = {
    'sale',
    'discount',
    'offer',
    'deal',
    'promo',
    'special',
    'limited time',
    'act now',
    'don\'t miss',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'show' ||
          node.methodName.name == 'send' ||
          node.methodName.name == 'schedule') {
        final Expression? target = node.target;
        if (target != null &&
            target.toSource().toLowerCase().contains('notification')) {
          final String argSource = node.argumentList.toSource().toLowerCase();
          for (final String pattern in _marketingPatterns) {
            if (argSource.contains(pattern)) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// v2.4.0 Additional Rules - Background Processing, Notifications, Payments
// =============================================================================

/// Warns when background tasks may exceed iOS 30-second limit.
///
/// iOS kills background tasks after approximately 30 seconds. Long-running
/// operations must be designed to complete quickly or use appropriate
/// background modes.
///
/// ## Why This Matters
///
/// - iOS terminates apps that exceed background execution time
/// - Users may lose data if operations are interrupted
/// - App may be flagged for poor battery performance
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Long operation without background task handling
/// Future.delayed(Duration(minutes: 5), () => syncAllData());
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use workmanager for reliable background tasks
/// Workmanager().registerOneOffTask(
///   'sync',
///   'syncTask',
///   constraints: Constraints(networkType: NetworkType.connected),
/// );
/// ```
///
/// @see [Background Execution](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background)
class AvoidLongRunningIsolatesRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidLongRunningIsolatesRule].
  const AvoidLongRunningIsolatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_long_running_isolates',
    problemMessage:
        'Long-running isolate detected. iOS kills background tasks after '
        '~30 seconds. Design tasks to complete quickly.',
    correctionMessage:
        'Use workmanager package for reliable background tasks, or break '
        'work into smaller chunks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect Isolate.spawn or compute with long operations
      if (methodName == 'spawn' || methodName == 'run') {
        final Expression? target = node.target;
        if (target != null && target.toSource() == 'Isolate') {
          // Check if there's a comment indicating awareness
          final String fileSource = resolver.source.contents.data;
          if (!fileSource.contains('workmanager') &&
              !fileSource.contains('Workmanager') &&
              !fileSource.contains('BGTaskScheduler')) {
            reporter.atNode(node, code);
          }
        }
      }

      // Also detect compute() calls
      if (methodName == 'compute') {
        final String fileSource = resolver.source.contents.data;
        if (!fileSource.contains('workmanager') &&
            !fileSource.contains('Workmanager')) {
          // Only warn if file doesn't show background task awareness
          final int nodeOffset = node.offset;
          final String preceding = fileSource.substring(
            nodeOffset > 100 ? nodeOffset - 100 : 0,
            nodeOffset,
          );
          if (!preceding.contains('background') &&
              !preceding.contains('Background')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when workmanager is needed for reliable background tasks.
///
/// Dart isolates die when the app goes to background. For reliable
/// background execution on iOS and Android, use the workmanager package.
///
/// ## Why This Matters
///
/// - Isolates are killed when app backgrounds
/// - Data sync may be interrupted
/// - Scheduled tasks won't run
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Timer in isolate - won't work in background
/// Timer.periodic(Duration(hours: 1), (_) => syncData());
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use workmanager for background tasks
/// Workmanager().registerPeriodicTask(
///   'hourlySync',
///   'syncData',
///   frequency: Duration(hours: 1),
/// );
/// ```
///
/// @see [workmanager package](https://pub.dev/packages/workmanager)
class RequireWorkmanagerForBackgroundRule extends SaropaLintRule {
  /// Creates a new instance of [RequireWorkmanagerForBackgroundRule].
  const RequireWorkmanagerForBackgroundRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_workmanager_for_background',
    problemMessage:
        'Periodic task detected without workmanager. Dart isolates die when '
        'app backgrounds. Use workmanager for reliable background tasks.',
    correctionMessage:
        'Replace Timer.periodic with Workmanager().registerPeriodicTask() '
        'for reliable background execution.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if workmanager is already being used
    if (fileSource.contains('Workmanager') ||
        fileSource.contains('workmanager')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Detect Timer.periodic
      if (methodName == 'periodic') {
        if (target != null && target.toSource() == 'Timer') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests showing notification for long-running tasks.
///
/// Long operations (uploads, processing, downloads) should show progress
/// notifications. Silent background work gets killed by the OS and users
/// have no visibility into progress.
///
/// ## Why This Matters
///
/// - OS kills silent background tasks aggressively
/// - Users can't tell if app is working or frozen
/// - Better UX with progress feedback
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Long upload with no progress indication
/// await uploadLargeFile(file);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Show progress notification
/// await showProgressNotification('Uploading...');
/// await uploadLargeFile(
///   file,
///   onProgress: (progress) => updateNotification(progress),
/// );
/// await cancelNotification();
/// ```
class RequireNotificationForLongTasksRule extends SaropaLintRule {
  /// Creates a new instance of [RequireNotificationForLongTasksRule].
  const RequireNotificationForLongTasksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_notification_for_long_tasks',
    problemMessage:
        'Long-running operation detected without progress notification. '
        'Silent background work may be killed by OS.',
    correctionMessage:
        'Show a progress notification for operations that take more than '
        'a few seconds. This keeps users informed and prevents OS termination.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns indicating potentially long operations.
  static const Set<String> _longOperationPatterns = {
    'uploadFile',
    'uploadLarge',
    'downloadFile',
    'downloadLarge',
    'syncAll',
    'processAll',
    'exportAll',
    'importAll',
    'backupData',
    'restoreData',
    'migrateDatabase',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if notifications are being used
    if (fileSource.contains('showNotification') ||
        fileSource.contains('showProgressNotification') ||
        fileSource.contains('FlutterLocalNotifications')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      for (final String pattern in _longOperationPatterns) {
        if (methodName.toLowerCase().contains(pattern.toLowerCase())) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Suggests delaying permission prompt until user sees value.
///
/// Don't ask for notification permission on first launch. Wait until
/// the user understands the app's value, then explain why notifications
/// are helpful before asking.
///
/// ## Why This Matters
///
/// - Users deny permissions they don't understand
/// - First-launch prompts have lower acceptance rates
/// - Explaining value first increases acceptance
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// void main() async {
///   await requestNotificationPermission(); // Too early!
///   runApp(MyApp());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // After user creates first reminder
/// showDialog(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Enable notifications?'),
///     content: Text("We'll remind you about your tasks on time."),
///     actions: [
///       TextButton(
///         onPressed: () => Navigator.pop(context),
///         child: Text('Not now'),
///       ),
///       TextButton(
///         onPressed: () async {
///           Navigator.pop(context);
///           await requestNotificationPermission();
///         },
///         child: Text('Enable'),
///       ),
///     ],
///   ),
/// );
/// ```
///
/// @see [Apple HIG - Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
class PreferDelayedPermissionPromptRule extends SaropaLintRule {
  /// Creates a new instance of [PreferDelayedPermissionPromptRule].
  const PreferDelayedPermissionPromptRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_delayed_permission_prompt',
    problemMessage: 'Permission request detected in main() or initState(). '
        'Asking too early reduces acceptance rates.',
    correctionMessage:
        'Wait until user interaction shows they need the feature, '
        'then explain the value before requesting permission.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect permission requests
      if (methodName == 'requestPermission' ||
          methodName == 'requestPermissions' ||
          methodName == 'request') {
        final String source = node.toSource().toLowerCase();
        if (source.contains('notification') || source.contains('permission')) {
          // Check if we're in main() or initState()
          AstNode? current = node.parent;
          while (current != null) {
            if (current is FunctionDeclaration) {
              final String funcName = current.name.lexeme;
              if (funcName == 'main') {
                reporter.atNode(node, code);
                return;
              }
            }
            if (current is MethodDeclaration) {
              final String funcName = current.name.lexeme;
              if (funcName == 'initState' || funcName == 'main') {
                reporter.atNode(node, code);
                return;
              }
            }
            current = current.parent;
          }
        }
      }
    });
  }
}

/// Warns when notification frequency may be too high.
///
/// Too many notifications cause users to disable all notifications or
/// uninstall the app. Batch, deduplicate, and respect user preferences.
///
/// ## Why This Matters
///
/// - Notification fatigue leads to opt-out
/// - Apple may reject apps with notification spam
/// - User trust is damaged by excessive notifications
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Notification for every single event
/// for (final item in items) {
///   await showNotification('New: ${item.title}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Batch notifications
/// if (items.length > 1) {
///   await showNotification('${items.length} new items');
/// } else {
///   await showNotification('New: ${items.first.title}');
/// }
/// ```
class AvoidNotificationSpamRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidNotificationSpamRule].
  const AvoidNotificationSpamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_notification_spam',
    problemMessage:
        'Notification inside loop detected. Sending too many notifications '
        'causes users to disable notifications or uninstall.',
    correctionMessage:
        'Batch notifications or use a summary notification when there are '
        'multiple items.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect notification calls
      if (methodName == 'show' || methodName == 'send') {
        final Expression? target = node.target;
        if (target != null &&
            target.toSource().toLowerCase().contains('notification')) {
          // Check if inside a loop
          AstNode? current = node.parent;
          while (current != null) {
            if (current is ForStatement ||
                current is ForElement ||
                current is WhileStatement ||
                current is DoStatement) {
              reporter.atNode(node, code);
              return;
            }
            // Check for forEach
            if (current is MethodInvocation &&
                current.methodName.name == 'forEach') {
              reporter.atNode(node, code);
              return;
            }
            current = current.parent;
          }
        }
      }
    });
  }
}

/// Warns when in-app purchases lack server-side verification.
///
/// Client-side purchase verification can be bypassed by attackers.
/// Always verify receipts server-side with Apple/Google.
///
/// ## Why This Matters
///
/// - Client-side verification is easily bypassed
/// - Revenue loss from fraudulent purchases
/// - App Store policy requires proper verification
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Client-side only verification
/// if (purchaseDetails.status == PurchaseStatus.purchased) {
///   unlockPremium(); // Easily bypassed!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Server-side verification
/// if (purchaseDetails.status == PurchaseStatus.purchased) {
///   final verified = await verifyPurchaseOnServer(
///     purchaseDetails.verificationData.serverVerificationData,
///   );
///   if (verified) {
///     unlockPremium();
///   }
/// }
/// ```
///
/// @see [Validating Receipts](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/validating_receipts_with_the_app_store)
class RequirePurchaseVerificationRule extends SaropaLintRule {
  /// Creates a new instance of [RequirePurchaseVerificationRule].
  const RequirePurchaseVerificationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_purchase_verification',
    problemMessage: 'In-app purchase without server verification detected. '
        'Client-side verification can be bypassed by attackers.',
    correctionMessage:
        'Verify purchase receipts server-side with Apple/Google. '
        'Consider using RevenueCat for cross-platform verification.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if server verification is present
    if (fileSource.contains('serverVerificationData') ||
        fileSource.contains('verifyReceipt') ||
        fileSource.contains('RevenueCat') ||
        fileSource.contains('validateReceipt')) {
      return;
    }

    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      // Detect purchase status checks without verification
      if (name == 'PurchaseStatus') {
        final AstNode? parent = node.parent;
        if (parent != null) {
          final String parentSource = parent.toSource();
          if (parentSource.contains('purchased') ||
              parentSource.contains('restored')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when "Restore Purchases" functionality is missing.
///
/// App Store requires a "Restore Purchases" button for non-consumable
/// purchases and subscriptions. Users switching devices need this.
///
/// ## Why This Matters
///
/// - App Store rejection without restore functionality
/// - Users lose access to purchases on new devices
/// - Required by Apple App Store Guidelines 3.1.1
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // No restore functionality
/// class SettingsScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return ListView(
///       children: [
///         ListTile(title: Text('Account')),
///         ListTile(title: Text('Privacy')),
///       ],
///     );
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class SettingsScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return ListView(
///       children: [
///         ListTile(title: Text('Account')),
///         ListTile(
///           title: Text('Restore Purchases'),
///           onTap: () => InAppPurchase.instance.restorePurchases(),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// @see [App Store Guidelines 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)
class RequirePurchaseRestorationRule extends SaropaLintRule {
  /// Creates a new instance of [RequirePurchaseRestorationRule].
  const RequirePurchaseRestorationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_purchase_restoration',
    problemMessage: 'In-app purchase detected without restore functionality. '
        'App Store requires "Restore Purchases" for non-consumables.',
    correctionMessage: 'Add a "Restore Purchases" button that calls '
        'InAppPurchase.instance.restorePurchases().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Check if file uses in-app purchases
    if (!fileSource.contains('InAppPurchase') &&
        !fileSource.contains('in_app_purchase') &&
        !fileSource.contains('StoreKit') &&
        !fileSource.contains('RevenueCat')) {
      return;
    }

    // Check if restore is implemented
    if (fileSource.contains('restorePurchases') ||
        fileSource.contains('restore') && fileSource.contains('Purchase')) {
      return;
    }

    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      if (node.name == 'InAppPurchase' || node.name == 'StoreKit') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Suggests using RevenueCat for cross-platform in-app purchases.
///
/// In-app purchases are complex with many edge cases. RevenueCat handles
/// cross-platform receipt validation, subscription management, and analytics.
///
/// ## Why This Matters
///
/// - Subscription renewals, cancellations, refunds are complex
/// - Receipt validation differs between platforms
/// - Analytics for subscription revenue
/// - Reduces development and maintenance time
///
/// ## Example
///
/// **MANUAL (complex):**
/// ```dart
/// // Handle all edge cases yourself
/// await InAppPurchase.instance.buyNonConsumable(...);
/// await verifyReceiptOnServer(...);
/// await handleRenewal(...);
/// await handleCancellation(...);
/// await handleRefund(...);
/// ```
///
/// **WITH REVENUECAT (simpler):**
/// ```dart
/// await Purchases.purchaseProduct(productId);
/// final info = await Purchases.getCustomerInfo();
/// if (info.entitlements.active.containsKey('premium')) {
///   // User has access
/// }
/// ```
///
/// @see [RevenueCat](https://www.revenuecat.com/)
class PreferRevenueCatRule extends SaropaLintRule {
  /// Creates a new instance of [PreferRevenueCatRule].
  const PreferRevenueCatRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_revenue_cat',
    problemMessage:
        'Manual in-app purchase implementation detected. Consider using '
        'RevenueCat for simpler cross-platform subscription management.',
    correctionMessage:
        'RevenueCat handles receipt validation, subscription management, '
        'and analytics. See https://www.revenuecat.com/',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if already using RevenueCat
    if (fileSource.contains('RevenueCat') ||
        fileSource.contains('purchases_flutter') ||
        fileSource.contains('Purchases.')) {
      return;
    }

    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      if (node.name == 'InAppPurchase') {
        // Only report once per file
        final int nodeOffset = node.offset;
        final String preceding = fileSource.substring(0, nodeOffset);
        if (!preceding.contains('InAppPurchase')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests using BGTaskScheduler for background sync on iOS.
///
/// Use WorkManager (Android) or BGTaskScheduler (iOS) to sync data when
/// the app is backgrounded, not just when open.
///
/// ## Why This Matters
///
/// - Data stays fresh even when app isn't used
/// - Better user experience with up-to-date content
/// - Efficient battery usage with system-managed scheduling
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Only syncs when app is open
/// @override
/// void initState() {
///   super.initState();
///   syncData();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Register background sync
/// void main() async {
///   await Workmanager().initialize(callbackDispatcher);
///   await Workmanager().registerPeriodicTask(
///     'backgroundSync',
///     'syncData',
///     frequency: Duration(hours: 1),
///   );
/// }
/// ```
///
/// @see [BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks)
class PreferBackgroundSyncRule extends SaropaLintRule {
  /// Creates a new instance of [PreferBackgroundSyncRule].
  const PreferBackgroundSyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_background_sync',
    problemMessage: 'Data sync in initState() only runs when app is open. '
        'Consider background sync for better user experience.',
    correctionMessage:
        'Use Workmanager for background sync. Data stays fresh even when '
        'the app is not actively used.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Patterns indicating sync operations.
  static const Set<String> _syncPatterns = {
    'syncData',
    'refreshData',
    'fetchData',
    'loadData',
    'pullData',
    'updateData',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if workmanager is used
    if (fileSource.contains('Workmanager') ||
        fileSource.contains('workmanager')) {
      return;
    }

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme == 'initState') {
        final String bodySource = node.body.toSource();
        for (final String pattern in _syncPatterns) {
          if (bodySource.contains(pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when sync error recovery is missing.
///
/// Failed syncs must retry with exponential backoff. Unrecoverable errors
/// should notify the user, not silently lose data.
///
/// ## Why This Matters
///
/// - Network failures are common on mobile
/// - Silent failures lose user data
/// - Exponential backoff prevents server overload
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// try {
///   await syncToServer(data);
/// } catch (e) {
///   print('Sync failed'); // Data lost!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> syncWithRetry(Data data, {int attempt = 0}) async {
///   try {
///     await syncToServer(data);
///   } catch (e) {
///     if (attempt < 3) {
///       await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
///       return syncWithRetry(data, attempt: attempt + 1);
///     }
///     await notifyUser('Sync failed. Changes saved locally.');
///     await saveLocally(data);
///   }
/// }
/// ```
class RequireSyncErrorRecoveryRule extends SaropaLintRule {
  /// Creates a new instance of [RequireSyncErrorRecoveryRule].
  const RequireSyncErrorRecoveryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_sync_error_recovery',
    problemMessage: 'Sync operation without error recovery detected. '
        'Failed syncs should retry and notify user of unrecoverable errors.',
    correctionMessage: 'Implement exponential backoff retry and notify user of '
        'persistent failures.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns indicating sync operations that should have retry.
  static const Set<String> _syncPatterns = {
    'syncData',
    'syncToServer',
    'syncToCloud',
    'uploadSync',
    'serverSync',
    'cloudSync',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check specific sync patterns, not any method containing 'sync'
      bool isSyncMethod = false;
      for (final String pattern in _syncPatterns) {
        if (methodName.toLowerCase().contains(pattern.toLowerCase())) {
          isSyncMethod = true;
          break;
        }
      }

      if (!isSyncMethod) {
        return;
      }

      // Check for try-catch with proper recovery
      AstNode? current = node.parent;
      bool inTryCatch = false;
      bool hasRetry = false;

      while (current != null) {
        if (current is TryStatement) {
          inTryCatch = true;
          final String catchSource = current.toSource();
          hasRetry = catchSource.contains('retry') ||
              catchSource.contains('attempt') ||
              catchSource.contains('backoff') ||
              catchSource.contains('Retry');
        }
        current = current.parent;
      }

      if (!inTryCatch || !hasRetry) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// Additional iOS-Specific Rules
// =============================================================================

/// Warns when code assumes WiFi-only connectivity.
///
/// iOS devices frequently switch between WiFi and cellular. Code that
/// assumes WiFi-only connectivity may fail or waste cellular data.
///
/// ## Why This Matters
///
/// - Users may have expensive cellular data plans
/// - Large downloads should wait for WiFi
/// - Connectivity can change during operations
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Assumes stable WiFi
/// await downloadLargeFile(url);
/// ```
///
/// **GOOD:**
/// ```dart
/// final connectivity = await Connectivity().checkConnectivity();
/// if (connectivity == ConnectivityResult.wifi) {
///   await downloadLargeFile(url);
/// } else {
///   showDialog(
///     context: context,
///     builder: (_) => AlertDialog(
///       title: Text('Large Download'),
///       content: Text('Download 500MB over cellular?'),
///       actions: [
///         TextButton(onPressed: () => Navigator.pop(context), child: Text('Wait for WiFi')),
///         TextButton(onPressed: () => downloadLargeFile(url), child: Text('Download')),
///       ],
///     ),
///   );
/// }
/// ```
///
/// @see [connectivity_plus](https://pub.dev/packages/connectivity_plus)
class AvoidIosWifiOnlyAssumptionRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosWifiOnlyAssumptionRule].
  const AvoidIosWifiOnlyAssumptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_wifi_only_assumption',
    problemMessage: 'Large download without connectivity check. Users may have '
        'expensive cellular plans.',
    correctionMessage:
        'Check connectivity type and warn user before large downloads '
        'on cellular.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if connectivity is being checked
    if (fileSource.contains('Connectivity') ||
        fileSource.contains('connectivity') ||
        fileSource.contains('NetworkType')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      if (methodName.contains('download') &&
          (methodName.contains('large') || methodName.contains('file'))) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when app doesn't handle iOS Low Power Mode.
///
/// iOS Low Power Mode throttles background activity, network requests,
/// and animations. Apps should adapt their behavior accordingly.
///
/// ## Why This Matters
///
/// - Background fetch is disabled
/// - Network requests may be delayed
/// - Visual effects should be reduced
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Always uses heavy animations
/// AnimationController(duration: Duration(seconds: 2));
/// ```
///
/// **GOOD:**
/// ```dart
/// final isLowPower = await ProcessInfo.isLowPowerModeEnabled;
/// AnimationController(
///   duration: isLowPower
///     ? Duration(milliseconds: 200)
///     : Duration(seconds: 2),
/// );
/// ```
///
/// @see [ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo)
class RequireIosLowPowerModeHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLowPowerModeHandlingRule].
  const RequireIosLowPowerModeHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_low_power_mode_handling',
    problemMessage: 'Heavy animation or background activity detected. Consider '
        'checking iOS Low Power Mode and adapting behavior.',
    correctionMessage:
        'Check ProcessInfo.isLowPowerModeEnabled and reduce animations '
        'or defer background work when enabled.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if low power mode is being checked
    if (fileSource.contains('LowPower') ||
        fileSource.contains('lowPower') ||
        fileSource.contains('batteryState')) {
      return;
    }

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      // Detect heavy animations
      if (typeName == 'AnimationController') {
        // Check duration
        final Expression? duration = node.getNamedParameterValue('duration');
        if (duration != null) {
          final String durationSource = duration.toSource();
          // Check for long durations (over 1 second)
          if (durationSource.contains('seconds') &&
              !durationSource.contains('milliseconds')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Suggests supporting Dynamic Type (large text) on iOS.
///
/// iOS users can increase text size in Settings > Accessibility.
/// Apps should respect this preference for accessibility.
///
/// ## Why This Matters
///
/// - Accessibility requirement for many users
/// - Required for certain enterprise/government contracts
/// - Better user experience for all
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// Text('Hello', style: TextStyle(fontSize: 14));
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: Theme.of(context).textTheme.bodyMedium,
///   // Or explicitly scale:
///   // style: TextStyle(fontSize: 14 * MediaQuery.textScaleFactorOf(context)),
/// );
/// ```
///
/// @see [Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography)
class RequireIosAccessibilityLargeTextRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAccessibilityLargeTextRule].
  const RequireIosAccessibilityLargeTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_accessibility_large_text',
    problemMessage: 'Hardcoded font size may not respect iOS Dynamic Type. '
        'Use theme text styles for accessibility.',
    correctionMessage: 'Use Theme.of(context).textTheme styles or apply '
        'MediaQuery.textScaleFactorOf(context).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName != 'TextStyle') {
        return;
      }

      // Check if fontSize is hardcoded
      final Expression? fontSize = node.getNamedParameterValue('fontSize');
      if (fontSize != null) {
        // Allow if using textScaleFactor
        final String fontSizeSource = fontSize.toSource();
        if (fontSizeSource.contains('textScaleFactor') ||
            fontSizeSource.contains('textScaler') ||
            fontSizeSource.contains('MediaQuery')) {
          return;
        }

        // Check parent to see if this is from a theme
        AstNode? current = node.parent;
        while (current != null) {
          if (current.toSource().contains('textTheme') ||
              current.toSource().contains('ThemeData')) {
            return; // Part of theme definition
          }
          current = current.parent;
        }

        reporter.atNode(node, code);
      }
    });
  }
}

/// Suggests using iOS context menus for touch-and-hold interactions.
///
/// iOS users expect context menus (long press) on actionable items.
/// This provides quick access to secondary actions.
///
/// ## Why This Matters
///
/// - Platform convention on iOS
/// - Efficient access to secondary actions
/// - Better discoverability of features
///
/// ## Example
///
/// **BASIC:**
/// ```dart
/// ListTile(
///   title: Text(item.title),
///   onTap: () => viewItem(item),
/// );
/// ```
///
/// **WITH CONTEXT MENU:**
/// ```dart
/// CupertinoContextMenu(
///   actions: [
///     CupertinoContextMenuAction(
///       child: Text('Share'),
///       onPressed: () => shareItem(item),
///     ),
///     CupertinoContextMenuAction(
///       isDestructiveAction: true,
///       child: Text('Delete'),
///       onPressed: () => deleteItem(item),
///     ),
///   ],
///   child: ListTile(
///     title: Text(item.title),
///     onTap: () => viewItem(item),
///   ),
/// );
/// ```
///
/// @see [CupertinoContextMenu](https://api.flutter.dev/flutter/cupertino/CupertinoContextMenu-class.html)
class PreferIosContextMenuRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosContextMenuRule].
  const PreferIosContextMenuRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_context_menu',
    problemMessage:
        'ListTile with multiple actions could benefit from a context menu. '
        'iOS users expect long-press for secondary actions.',
    correctionMessage:
        'Wrap actionable items with CupertinoContextMenu for better iOS UX.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if already using context menus
    if (fileSource.contains('CupertinoContextMenu') ||
        fileSource.contains('ContextMenu') ||
        fileSource.contains('onLongPress')) {
      return;
    }

    // Skip non-iOS files
    if (!fileSource.contains('Platform.isIOS') &&
        !fileSource.contains('cupertino')) {
      return;
    }

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName == 'ListTile' || node.typeName == 'Card') {
        // Check if there are multiple interactive elements
        final String nodeSource = node.toSource();
        final RegExp actionPattern = RegExp(r'onTap|onPressed|trailing.*Icon');
        final int actionCount = actionPattern.allMatches(nodeSource).length;

        if (actionCount >= 2) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Reminds about iOS Quick Note feature compatibility.
///
/// iOS 15+ has Quick Note that allows users to link notes to app content.
/// Apps can provide better context for Quick Note by implementing
/// NSUserActivity.
///
/// ## Why This Matters
///
/// - Users can add notes linked to app content
/// - Notes show app context when reopened
/// - Professional feature for enterprise apps
///
/// ## Example
///
/// **GOOD:**
/// ```dart
/// // Set user activity for Quick Note
/// final activity = NSUserActivity(
///   activityType: 'com.example.viewDocument',
///   title: document.title,
///   webpageURL: 'https://example.com/doc/${document.id}',
/// );
/// activity.becomeCurrent();
/// ```
///
/// @see [NSUserActivity](https://developer.apple.com/documentation/foundation/nsuseractivity)
class RequireIosQuickNoteAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosQuickNoteAwarenessRule].
  const RequireIosQuickNoteAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_quick_note_awareness',
    problemMessage:
        'Document viewing detected. Consider implementing NSUserActivity '
        'for iOS Quick Note compatibility.',
    correctionMessage:
        'Set NSUserActivity with document context so users can link '
        'Quick Notes to your app content.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if NSUserActivity is being used
    if (fileSource.contains('NSUserActivity') ||
        fileSource.contains('UserActivity')) {
      return;
    }

    // Only check for document-like screens
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      if (className.contains('document') ||
          className.contains('article') ||
          className.contains('viewer') ||
          className.contains('reader')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when keyboard height is hardcoded instead of using ViewInsets.
///
/// iOS keyboard height varies by device, orientation, and input type.
/// Hardcoding heights causes UI issues on different devices.
///
/// ## Why This Matters
///
/// - Keyboard height varies by device (iPhone vs iPad)
/// - Third-party keyboards have different heights
/// - Predictive text bar adds height
/// - Orientation affects keyboard dimensions
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.only(bottom: 300), // Hardcoded keyboard height
///   child: content,
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.only(
///     bottom: MediaQuery.of(context).viewInsets.bottom,
///   ),
///   child: content,
/// );
/// ```
///
/// @see [viewInsets](https://api.flutter.dev/flutter/widgets/MediaQueryData/viewInsets.html)
class AvoidIosHardcodedKeyboardHeightRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedKeyboardHeightRule].
  const AvoidIosHardcodedKeyboardHeightRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_hardcoded_keyboard_height',
    problemMessage:
        'Hardcoded bottom padding may be for keyboard. iOS keyboard height '
        'varies by device and input type.',
    correctionMessage:
        'Use MediaQuery.of(context).viewInsets.bottom for keyboard height.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Common hardcoded keyboard heights.
  static const Set<int> _keyboardHeights = {
    250,
    260,
    270,
    280,
    290,
    300,
    310,
    320,
    330,
    340,
    350
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName != 'EdgeInsets') {
        return;
      }

      // Check for hardcoded bottom values
      final Expression? bottom = node.getNamedParameterValue('bottom');
      if (bottom != null && bottom is IntegerLiteral) {
        final int value = bottom.value ?? 0;
        if (_keyboardHeights.contains(value)) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when iPad multitasking modes aren't handled.
///
/// iPads support Split View, Slide Over, and Stage Manager. Apps must
/// handle window size changes gracefully.
///
/// ## Why This Matters
///
/// - iPad users expect multitasking support
/// - Window size can change at runtime
/// - Layouts must adapt to narrow widths
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Assumes full screen
/// Container(
///   width: MediaQuery.of(context).size.width,
///   child: Row(
///     children: [sidebar, content], // Breaks in Split View
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     if (constraints.maxWidth > 600) {
///       return Row(children: [sidebar, content]);
///     }
///     return Column(children: [content]); // Navigation via drawer
///   },
/// );
/// ```
///
/// @see [Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking)
class RequireIosMultitaskingSupportRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosMultitaskingSupportRule].
  const RequireIosMultitaskingSupportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_multitasking_support',
    problemMessage:
        'Fixed layout detected. iPads support Split View and Slide Over. '
        'Layouts should adapt to window size changes.',
    correctionMessage:
        'Use LayoutBuilder or MediaQuery breakpoints to create responsive '
        'layouts that work in multitasking modes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if responsive patterns are used
    if (fileSource.contains('LayoutBuilder') ||
        fileSource.contains('OrientationBuilder') ||
        fileSource.contains('constraints.maxWidth') ||
        fileSource.contains('breakpoint')) {
      return;
    }

    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      // Detect Row with fixed width children at top level
      if (node.typeName == 'Row') {
        // Check if parent suggests full-screen usage
        AstNode? current = node.parent;
        while (current != null) {
          if (current is InstanceCreationExpression) {
            if (current.typeName == 'Scaffold') {
              reporter.atNode(node, code);
              return;
            }
          }
          current = current.parent;
        }
      }
    });
  }
}

/// Suggests implementing Spotlight search indexing.
///
/// iOS Spotlight allows users to search app content from the home screen.
/// Apps can index their content to appear in Spotlight results.
///
/// ## Why This Matters
///
/// - Users can find app content from home screen
/// - Increases app engagement
/// - Required for some enterprise features
///
/// ## Example
///
/// **GOOD:**
/// ```dart
/// // Index content for Spotlight
/// final item = CSSearchableItem(
///   uniqueIdentifier: 'document-\${doc.id}',
///   domainIdentifier: 'com.example.documents',
///   attributeSet: CSSearchableItemAttributeSet(
///     title: doc.title,
///     contentDescription: doc.summary,
///   ),
/// );
/// await CSSearchableIndex.defaultSearchableIndex().indexSearchableItems([item]);
/// ```
///
/// @see [Core Spotlight](https://developer.apple.com/documentation/corespotlight)
class PreferIosSpotlightIndexingRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosSpotlightIndexingRule].
  const PreferIosSpotlightIndexingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_spotlight_indexing',
    problemMessage:
        'Searchable content detected. Consider indexing with Core Spotlight '
        'so users can find content from iOS home screen.',
    correctionMessage:
        'Use CSSearchableItem to index content for Spotlight search.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if Spotlight is being used
    if (fileSource.contains('Spotlight') ||
        fileSource.contains('CSSearchable') ||
        fileSource.contains('searchable')) {
      return;
    }

    // Only check files with search functionality
    if (!fileSource.contains('search') && !fileSource.contains('Search')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      if (className.contains('search') || className.contains('list')) {
        final String bodySource = node.toSource();
        if (bodySource.contains('ListView') || bodySource.contains('items')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests using iOS Data Protection for sensitive files.
///
/// iOS Data Protection encrypts files based on device passcode.
/// Sensitive data should use appropriate protection classes.
///
/// ## Why This Matters
///
/// - Data encrypted when device locked
/// - Multiple protection levels available
/// - Required for security compliance
///
/// ## Protection Classes
///
/// - `complete`: Only accessible when device unlocked
/// - `completeUnlessOpen`: Accessible until file closed
/// - `completeUntilFirstUserAuthentication`: Accessible after first unlock
///
/// ## Example
///
/// **GOOD:**
/// ```dart
/// // Set data protection class
/// final file = File(path);
/// await file.writeAsBytes(data);
/// await file.setProtection(
///   FileProtectionType.complete, // Encrypted when locked
/// );
/// ```
///
/// @see [Data Protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files)
class RequireIosDataProtectionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosDataProtectionRule].
  const RequireIosDataProtectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_data_protection',
    problemMessage:
        'Sensitive file storage detected. Consider using iOS Data Protection '
        'to encrypt files when device is locked.',
    correctionMessage: 'Set appropriate FileProtectionType for sensitive data. '
        'Use "complete" protection for highly sensitive files.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns indicating sensitive data.
  static const Set<String> _sensitivePatterns = {
    'password',
    'secret',
    'token',
    'credential',
    'private',
    'encrypt',
    'secure',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if data protection is being used
    if (fileSource.contains('FileProtection') ||
        fileSource.contains('dataProtection') ||
        fileSource.contains('setProtection')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect file write operations
      if (methodName == 'writeAsBytes' ||
          methodName == 'writeAsString' ||
          methodName == 'writeSync') {
        // Check if file name or surrounding context suggests sensitive data
        final String surroundingSource = node.toSource().toLowerCase();
        for (final String pattern in _sensitivePatterns) {
          if (surroundingSource.contains(pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when code patterns may cause excessive battery drain.
///
/// iOS aggressively manages battery. Apps with poor battery performance
/// may be throttled or flagged in Settings.
///
/// ## Why This Matters
///
/// - High battery usage shown in Settings
/// - OS may throttle background activity
/// - Users may uninstall battery-draining apps
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Polling too frequently
/// Timer.periodic(Duration(seconds: 1), (_) => checkForUpdates());
///
/// // High-accuracy location continuously
/// Geolocator.getPositionStream(desiredAccuracy: LocationAccuracy.best);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use push notifications instead of polling
/// await FirebaseMessaging.instance.subscribeToTopic('updates');
///
/// // Use significant location changes
/// Geolocator.getPositionStream(
///   desiredAccuracy: LocationAccuracy.low,
///   distanceFilter: 100, // meters
/// );
/// ```
///
/// @see [Energy Efficiency Guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/)
class AvoidIosBatteryDrainPatternsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosBatteryDrainPatternsRule].
  const AvoidIosBatteryDrainPatternsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ios_battery_drain_patterns',
    problemMessage: 'Pattern detected that may cause excessive battery drain. '
        'iOS shows high battery usage in Settings.',
    correctionMessage: 'Use push notifications instead of polling. '
        'Reduce location accuracy and frequency.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect frequent polling
      if (methodName == 'periodic') {
        final Expression? target = node.target;
        if (target != null && target.toSource() == 'Timer') {
          // Check duration
          final List<Expression> args =
              node.argumentList.arguments.whereType<Expression>().toList();
          if (args.isNotEmpty) {
            final String durationSource = args.first.toSource();
            // Very short intervals are battery-draining
            if (durationSource.contains('milliseconds') ||
                (durationSource.contains('seconds') &&
                    durationSource.contains(RegExp(r'[1-5]\)')))) {
              reporter.atNode(node, code);
            }
          }
        }
      }

      // Detect continuous high-accuracy location
      if (methodName == 'getPositionStream' || methodName == 'watchPosition') {
        final String argSource = node.argumentList.toSource();
        if (argSource.contains('best') || argSource.contains('high')) {
          // Check for distance filter
          if (!argSource.contains('distanceFilter') ||
              argSource.contains('distanceFilter: 0')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// macOS Additional Rules
// =============================================================================

/// Warns when macOS sandbox entitlements may be needed.
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

  static const LintCode _code = LintCode(
    name: 'require_macos_sandbox_exceptions',
    problemMessage: 'Feature requiring macOS sandbox entitlement detected. '
        'App Store apps must declare entitlements.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_macos_hardened_runtime_violations',
    problemMessage: 'Pattern detected that may violate macOS Hardened Runtime. '
        'Apps must pass notarization for distribution.',
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

  static const LintCode _code = LintCode(
    name: 'require_macos_app_transport_security',
    problemMessage: 'HTTP URL detected. macOS enforces App Transport Security. '
        'Use HTTPS or declare exception in Info.plist.',
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

  static const LintCode _code = LintCode(
    name: 'require_macos_notarization_ready',
    problemMessage:
        'macOS app detected. Ensure notarization is configured for distribution. '
        'Apps without notarization show security warnings.',
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

  static const LintCode _code = LintCode(
    name: 'require_macos_entitlements',
    problemMessage: 'Feature detected that requires macOS entitlement. '
        'Sandboxed apps crash without proper entitlements.',
    correctionMessage:
        'Add the required entitlement to macos/Runner/Release.entitlements '
        'and macos/Runner/DebugProfile.entitlements.',
    errorSeverity: DiagnosticSeverity.INFO,
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

/// Warns when iOS entitlements may be needed for features.
///
/// iOS features like Push Notifications, HealthKit, and Sign in with Apple
/// require corresponding entitlements in Xcode.
///
/// ## Why This Matters
///
/// - Features fail silently without entitlements
/// - App Store rejection
/// - Runtime crashes for some features
///
/// ## Common Entitlements
///
/// | Feature | Capability |
/// |---------|------------|
/// | Push Notifications | Push Notifications |
/// | Sign in with Apple | Sign in with Apple |
/// | HealthKit | HealthKit |
/// | In-App Purchase | In-App Purchase |
/// | Apple Pay | Apple Pay |
///
/// @see [Xcode Capabilities](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)
class RequireIosEntitlementsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosEntitlementsRule].
  const RequireIosEntitlementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_entitlements',
    problemMessage:
        'Feature detected that requires iOS entitlement/capability. '
        'Enable in Xcode Signing & Capabilities.',
    correctionMessage:
        'Open Xcode, select Runner target, go to Signing & Capabilities, '
        'and add the required capability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Features and their required capabilities.
  static const Map<String, String> _featureToCapability = {
    'HealthKit': 'HealthKit capability',
    'ApplePay': 'Apple Pay capability',
    'HomeKit': 'HomeKit capability',
    'Siri': 'Siri capability',
    'Wallet': 'Wallet capability',
    'CloudKit': 'iCloud capability',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      for (final String feature in _featureToCapability.keys) {
        if (name.contains(feature)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when iOS launch screen configuration may be missing.
///
/// iOS apps without LaunchScreen.storyboard are rejected from the App Store.
/// Flutter apps must have proper launch screen configuration.
///
/// ## Why This Matters
///
/// - App Store rejection without launch screen
/// - Poor first impression with black screen
/// - Required since iOS 13
///
/// ## Configuration
///
/// 1. Ensure `ios/Runner/Base.lproj/LaunchScreen.storyboard` exists
/// 2. Configure launch screen appearance in Xcode
/// 3. Test on device (simulator may cache old launch screens)
///
/// @see [Launch Screen](https://developer.apple.com/design/human-interface-guidelines/launching)
class RequireIosLaunchStoryboardRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLaunchStoryboardRule].
  const RequireIosLaunchStoryboardRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_launch_storyboard',
    problemMessage:
        'iOS app detected. Ensure LaunchScreen.storyboard is properly '
        'configured. Apps without launch screen are rejected.',
    correctionMessage:
        'Verify ios/Runner/Base.lproj/LaunchScreen.storyboard exists '
        'and is configured in Xcode.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String filePath = resolver.source.fullName;

    // Only check main.dart
    if (!filePath.endsWith('main.dart')) {
      return;
    }

    final String fileSource = resolver.source.contents.data;

    // Check for iOS platform check
    if (!fileSource.contains('Platform.isIOS') && !fileSource.contains('ios')) {
      return;
    }

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme == 'main') {
        // Check for launch screen comment
        final String surroundingSource = fileSource.substring(
          node.offset > 200 ? node.offset - 200 : 0,
          node.offset,
        );
        if (!surroundingSource.contains('LaunchScreen') &&
            !surroundingSource.contains('launch screen')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when iOS version-specific features lack platform checks.
///
/// New iOS features require version checks to avoid crashes on older devices.
/// Always check iOS version before using newer APIs.
///
/// ## Why This Matters
///
/// - Crashes on older iOS versions
/// - Poor App Store reviews
/// - Users on older devices can't use app
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Uses iOS 17+ API without check
/// await ShareExtension.shareWithPreview(data);
/// ```
///
/// **GOOD:**
/// ```dart
/// if (Platform.isIOS) {
///   final version = await DeviceInfo.iosVersion;
///   if (version >= 17) {
///     await ShareExtension.shareWithPreview(data);
///   } else {
///     await Share.share(data);
///   }
/// }
/// ```
class RequireIosVersionCheckRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosVersionCheckRule].
  const RequireIosVersionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_ios_version_check',
    problemMessage:
        'iOS version-specific feature detected without version check. '
        'Crashes may occur on older iOS versions.',
    correctionMessage: 'Check iOS version before using newer APIs. '
        'Use device_info_plus to get iOS version.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// iOS 17+ APIs.
  static const Set<String> _ios17Apis = {
    'ShareExtension',
    'JournalingSuggestions',
    'TipKit',
    'SwiftData',
    'StandbyMode',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if version check is present
    if (fileSource.contains('iosVersion') ||
        fileSource.contains('systemVersion') ||
        fileSource.contains('operatingSystemVersion')) {
      return;
    }

    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      for (final String api in _ios17Apis) {
        if (name.contains(api)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when iOS Focus mode integration is not handled.
///
/// iOS 15+ Focus modes can affect app behavior. Apps should respect
/// Focus settings and adapt notifications accordingly.
///
/// ## Why This Matters
///
/// - Users expect apps to respect Focus mode
/// - Notifications may be silenced
/// - Time-sensitive notifications need special handling
///
/// ## Example
///
/// **GOOD:**
/// ```dart
/// // Mark critical notifications as time-sensitive
/// await NotificationService.show(
///   title: 'Payment Due',
///   body: 'Your payment is due today',
///   interruptionLevel: InterruptionLevel.timeSensitive,
/// );
/// ```
///
/// @see [Focus](https://developer.apple.com/design/human-interface-guidelines/focus)
class RequireIosFocusModeAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosFocusModeAwarenessRule].
  const RequireIosFocusModeAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_ios_focus_mode_awareness',
    problemMessage:
        'Notification without interruption level detected. iOS Focus mode '
        'may silence notifications. Set appropriate interruption level.',
    correctionMessage:
        'Use interruptionLevel parameter to indicate notification importance. '
        'Time-sensitive notifications can break through Focus.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if interruption level is being used
    if (fileSource.contains('interruptionLevel') ||
        fileSource.contains('InterruptionLevel')) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'show' || methodName == 'send') {
        final Expression? target = node.target;
        if (target != null &&
            target.toSource().toLowerCase().contains('notification')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests implementing iOS Handoff for continuity between devices.
///
/// iOS Handoff allows users to continue activities across devices.
/// Apps can implement NSUserActivity for seamless transitions.
///
/// ## Why This Matters
///
/// - Users with multiple Apple devices expect continuity
/// - Better user experience across iPhone, iPad, Mac
/// - Required for some enterprise features
///
/// ## Example
///
/// **GOOD:**
/// ```dart
/// // Enable Handoff for document editing
/// final activity = NSUserActivity(
///   activityType: 'com.example.editing',
///   title: 'Editing ${document.title}',
///   userInfo: {'documentId': document.id},
/// );
/// activity.becomeCurrent();
/// ```
///
/// @see [Handoff](https://developer.apple.com/handoff/)
class PreferIosHandoffSupportRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosHandoffSupportRule].
  const PreferIosHandoffSupportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ios_handoff_support',
    problemMessage:
        'Document or content editing detected. Consider implementing '
        'iOS Handoff for continuity across devices.',
    correctionMessage:
        'Use NSUserActivity to enable Handoff. Users can continue work '
        'on other Apple devices.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String fileSource = resolver.source.contents.data;

    // Skip if NSUserActivity is being used
    if (fileSource.contains('NSUserActivity') ||
        fileSource.contains('Handoff') ||
        fileSource.contains('handoff')) {
      return;
    }

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      if (className.contains('editor') ||
          className.contains('compose') ||
          className.contains('draft')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when iOS voiceover gestures may conflict with app gestures.
///
/// VoiceOver uses different gestures than standard touch interactions.
/// Apps should ensure all functionality is accessible with VoiceOver.
///
/// ## Why This Matters
///
/// - Accessibility requirement
/// - Swipe gestures work differently with VoiceOver
/// - Custom gestures may not be accessible
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Custom gesture without accessibility action
/// GestureDetector(
///   onHorizontalDragEnd: (details) => dismissItem(),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Provide accessibility action
/// Semantics(
///   onDismiss: () => dismissItem(),
///   child: GestureDetector(
///     onHorizontalDragEnd: (details) => dismissItem(),
///   ),
/// );
/// ```
///
/// @see [VoiceOver Gestures](https://support.apple.com/guide/iphone/use-voiceover-gestures-iph3e2e2281/ios)
class RequireIosVoiceoverGestureCompatibilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosVoiceoverGestureCompatibilityRule].
  const RequireIosVoiceoverGestureCompatibilityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_ios_voiceover_gesture_compatibility',
    problemMessage:
        'Custom gesture without accessibility action. VoiceOver users may '
        'not be able to perform this action.',
    correctionMessage:
        'Wrap with Semantics and provide onDismiss, onScrollLeft, '
        'or other accessibility actions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName != 'GestureDetector') {
        return;
      }

      // Check for drag gestures
      final bool hasDragGesture =
          node.getNamedParameterValue('onHorizontalDragEnd') != null ||
              node.getNamedParameterValue('onVerticalDragEnd') != null ||
              node.getNamedParameterValue('onPanEnd') != null;

      if (!hasDragGesture) {
        return;
      }

      // Check if wrapped in Semantics
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          if (current.typeName == 'Semantics') {
            return; // Already has Semantics wrapper
          }
        }
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}
