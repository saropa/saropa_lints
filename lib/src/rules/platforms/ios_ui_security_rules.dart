// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

// cspell:disable

/// iOS platform-specific lint rules (split file).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../target_matcher_utils.dart';
import '../../saropa_lint_rule.dart';
import '../../fixes/platforms/ios/replace_http_with_https_fix.dart';

class PreferIosSafeAreaRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosSafeAreaRule].
  PreferIosSafeAreaRule() : super(code: _code);

  /// UI overlap affects user experience but is not critical.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_ios_safe_area',
    '[prefer_ios_safe_area] Scaffold body without SafeArea may have content hidden by iOS notch '
        'or Dynamic Island. {v2}',
    correctionMessage:
        'Wrap body content with SafeArea to avoid UI overlap on iOS devices.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

      reporter.atNode(node);
    });
  }
}

/// Quick fix that wraps Scaffold body with SafeArea.

/// Warns when hardcoded iOS status bar height values are used.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosHardcodedStatusBarRule() : super(code: _code);

  /// Hardcoded values cause UI bugs on specific devices.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_hardcoded_status_bar',
    '[avoid_ios_hardcoded_status_bar] Hardcoded status bar height (20, 44, 47, or 59) may cause UI issues '
        'on different iOS devices. {v2}',
    correctionMessage:
        'Use MediaQuery.of(context).padding.top for dynamic status bar height.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
      reporter.atNode(arg);
    }
  }
}

/// Quick fix that replaces hardcoded value with MediaQuery.padding.top.

/// Suggests adding haptic feedback for important button interactions on iOS.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferIosHapticFeedbackRule() : super(code: _code);

  /// Haptic feedback is a nice-to-have UX enhancement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_ios_haptic_feedback',
    '[prefer_ios_haptic_feedback] Consider adding haptic feedback for important button interactions '
        'on iOS. {v2}',
    correctionMessage:
        'Use HapticFeedback.mediumImpact() or similar for tactile response.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Button types that typically benefit from haptic feedback.
  static const Set<String> _importantButtonTypes = <String>{
    'ElevatedButton',
    'FilledButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_importantButtonTypes.contains(node.typeName)) {
        return;
      }

      final Expression? onPressedArg = node.getNamedParameterValue('onPressed');
      if (onPressedArg == null) {
        return;
      }

      // Check if HapticFeedback is already used in the callback
      final String source = onPressedArg.toSource();
      if (RegExp(r'\bHapticFeedback\b').hasMatch(source)) {
        return;
      }

      reporter.atNode(node);
    });
  }
}

/// Quick fix that adds HapticFeedback.mediumImpact() to button callback.

/// Suggests using Cupertino widgets in iOS-specific code blocks.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferCupertinoForIosRule() : super(code: _code);

  /// Using non-native widgets is a UX preference.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_cupertino_for_ios',
    '[prefer_cupertino_for_ios] Material widget in iOS-specific code block. Consider using '
        'Cupertino equivalent for native iOS feel. {v2}',
    correctionMessage:
        'Use CupertinoAlertDialog, CupertinoSwitch, etc. for native iOS feel.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;
      if (!_materialToCupertino.containsKey(typeName)) {
        return;
      }

      // Check if inside Platform.isIOS block
      if (_isInsideIosPlatformCheck(node)) {
        reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireHttpsForIosRule() : super(code: _code);

  /// HTTP requests fail without configuration.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceHttpWithHttpsFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'require_https_for_ios',
    '[require_https_for_ios] HTTP URL will be blocked by iOS App Transport Security unless '
        'exception is configured. {v2}',
    correctionMessage:
        'Use HTTPS or add NSAppTransportSecurity exception in Info.plist.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Localhost addresses that don't need HTTPS.
  static const Set<String> _localhostPatterns = <String>{
    'localhost',
    '127.0.0.1',
    '10.0.2.2', // Android emulator localhost
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(urlArg);
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
}

/// Quick fix that replaces http:// with https://.

/// Warns when permission-requiring APIs are used without Info.plist entries.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v5
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
class RequireAppleSignInRule extends SaropaLintRule {
  /// Creates a new instance of [RequireAppleSignInRule].
  RequireAppleSignInRule() : super(code: _code);

  /// App Store rejection is critical.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_apple_sign_in',
    '[require_apple_sign_in] Third-party login detected without Sign in with Apple. '
        'iOS apps with social login must offer Sign in with Apple. {v2}',
    correctionMessage:
        'Add Sign in with Apple using the sign_in_with_apple package '
        'per App Store Guidelines 4.8.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track if file has third-party sign-in and Apple sign-in
    bool hasThirdPartySignIn = false;
    bool hasAppleSignIn = false;
    MethodInvocation? firstThirdPartyNode;

    // Check file source for Apple sign-in presence
    final String fileSource = context.fileContent;
    for (final String indicator in _appleSignInIndicators) {
      if (fileSource.contains(indicator)) {
        hasAppleSignIn = true;
        break;
      }
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for third-party sign-in methods
      if (_thirdPartySignInMethods.contains(methodName)) {
        // Verify it's from a third-party sign-in class
        final Expression? target = node.target;
        if (target != null && isExactTarget(target, _thirdPartySignInClasses)) {
          hasThirdPartySignIn = true;
          firstThirdPartyNode ??= node;
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosKeychainAccessibilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosKeychainAccessibilityRule].
  RequireIosKeychainAccessibilityRule() : super(code: _code);

  /// Keychain misconfiguration can expose sensitive data.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_keychain_accessibility',
    '[require_ios_keychain_accessibility] Keychain write detected. Consider specifying iOS accessibility level '
        'for security. {v2}',
    correctionMessage:
        'Use IOSOptions with KeychainAccessibility to control when data '
        'is accessible.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _secureStorageTargets = {
    'secureStorage',
    'FlutterSecureStorage',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for secure storage write without IOSOptions
      if (methodName == 'write') {
        final Expression? target = node.target;
        if (target != null &&
            _secureStorageTargets.contains(extractTargetName(target))) {
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
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when bundle ID is hardcoded instead of from configuration.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosAtsExceptionDocumentationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAtsExceptionDocumentationRule].
  RequireIosAtsExceptionDocumentationRule() : super(code: _code);

  /// HTTP without ATS documentation causes confusion and potential issues.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_ats_exception_documentation',
    '[require_ios_ats_exception_documentation] HTTP URL detected. If intentional, document the ATS exception '
        'required in Info.plist with a comment. {v2}',
    correctionMessage:
        'Add a comment explaining why HTTP is needed and which ATS exception '
        'is configured in Info.plist.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
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
      final String fileSource = context.fileContent;
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

      reporter.atNode(node);
    });
  }
}

/// Warns when local notifications are scheduled without permission request.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosUniversalLinksDomainMatchingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosUniversalLinksDomainMatchingRule].
  RequireIosUniversalLinksDomainMatchingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_universal_links_domain_matching',
    '[require_ios_universal_links_domain_matching] Deep link pattern detected. Ensure apple-app-site-association '
        'paths match exactly for Universal Links to work. {v2}',
    correctionMessage:
        'Verify apple-app-site-association on server matches app paths exactly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (typeName == 'GoRoute' || typeName == 'MaterialPageRoute') {
        final String argSource = node.argumentList.toSource();
        // Check for deep link paths with parameters
        if (argSource.contains('/:') || argSource.contains('/:id')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when NFC usage is detected without capability check.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// NFC is not available on all iOS devices. Apps should check capability
/// before attempting NFC operations.
///
/// ## Device Compatibility
///
/// - NFC reading: iPhone 7 and later
/// - NFC writing: iPhone 7 and later with iOS 13+
/// - Background NFC: iPhone XS and later
class RequireIosCertificatePinningRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosCertificatePinningRule].
  RequireIosCertificatePinningRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_certificate_pinning',
    '[require_ios_certificate_pinning] Sensitive API endpoint detected. Consider implementing SSL '
        'certificate pinning for additional security. {v2}',
    correctionMessage:
        'Use Dio with certificate pinning or platform-specific SSL pinning.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if pinning is implemented
    if (fileSource.contains('certificatePinner') ||
        fileSource.contains('sslPinning') ||
        fileSource.contains('SecurityContext')) {
      return;
    }

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value.toLowerCase();
      for (final String pattern in _sensitivePatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when iOS Keychain credential storage isn't using Keychain.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Credentials should be stored in iOS Keychain, not UserDefaults
/// or SharedPreferences which are not encrypted.
