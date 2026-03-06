// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

// cspell:disable

/// iOS platform-specific lint rules (split file).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../target_matcher_utils.dart';
import '../../mode_constants_utils.dart';
import '../../saropa_lint_rule.dart';

class AvoidIos13DeprecationsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIos13DeprecationsRule].
  AvoidIos13DeprecationsRule() : super(code: _code);

  /// Deprecated APIs cause App Store warnings and eventual rejection.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_13_deprecations',
    '[avoid_ios_13_deprecations] Deprecated iOS API detected. This API is deprecated since iOS 13 '
        'and may cause App Store rejection. {v2}',
    correctionMessage:
        'Use the modern replacement API. See Apple documentation for '
        'migration guidance.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String api in _deprecatedApis) {
        if (value.contains(api)) {
          reporter.atNode(node);
          return;
        }
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_deprecatedApis.contains(methodName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when iOS Simulator-only code patterns are detected.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosSimulatorOnlyCodeRule() : super(code: _code);

  /// Simulator-only code causes production failures.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ios_simulator_only_code',
    '[avoid_ios_simulator_only_code] iOS Simulator-only code pattern detected. This code may not work '
        'on real iOS devices. {v2}',
    correctionMessage:
        'Use platform-agnostic paths (path_provider) and proper environment '
        'detection.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip if in test file
      final String filePath = context.filePath;
      if (filePath.contains('_test.dart') || filePath.contains('/test/')) {
        return;
      }

      for (final String pattern in _simulatorPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when iOS version-specific APIs are used without version checks.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosMinimumVersionCheckRule() : super(code: _code);

  /// Missing version checks cause crashes on older iOS.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_minimum_version_check',
    '[require_ios_minimum_version_check] iOS version-specific API detected. Ensure iOS version is checked '
        'before using this API. {v2}',
    correctionMessage:
        'Add iOS version check before calling version-specific APIs.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String api in _versionSpecificApis) {
        if (value.contains(api)) {
          reporter.atNode(node);
          return;
        }
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_versionSpecificApis.contains(methodName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when deprecated UIKit APIs are used in platform channel code.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosDeprecatedUikitRule() : super(code: _code);

  /// Deprecated APIs cause warnings and potential rejection.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ios_deprecated_uikit',
    '[avoid_ios_deprecated_uikit] Deprecated UIKit API pattern detected in platform channel code. Platform channel code (Swift/Objective-C) that uses deprecated UIKit APIs will generate warnings during Xcode builds and may be rejected by App Store in future iOS versions. {v2}',
    correctionMessage:
        'Update platform channel code to use modern iOS APIs. Verify the change works correctly with existing tests and add coverage for the new behavior. '
        'See Xcode warnings for specific replacements.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String pattern in _deprecatedPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class AvoidIosInAppBrowserForAuthRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosInAppBrowserForAuthRule].
  AvoidIosInAppBrowserForAuthRule() : super(code: _code);

  /// OAuth via WebView is blocked by identity providers.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_in_app_browser_for_auth',
    '[avoid_ios_in_app_browser_for_auth] OAuth URL detected in WebView. Google and Apple block OAuth via '
        'in-app WebView for security reasons. {v2}',
    correctionMessage: 'Use flutter_appauth or url_launcher for OAuth. '
        'ASWebAuthenticationSession is required on iOS.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (!_webViewWidgets.contains(typeName)) {
        return;
      }

      // Check if any string argument contains OAuth URL
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        for (final String pattern in _oauthPatterns) {
          if (argSource.contains(pattern)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });

    // Also check string literals for OAuth URLs with WebView nearby
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      for (final String pattern in _oauthPatterns) {
        if (value.contains(pattern)) {
          // Check if file contains WebView
          final String fileSource = context.fileContent;
          for (final String webView in _webViewWidgets) {
            if (fileSource.contains(webView)) {
              reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosAppReviewPromptTimingRule() : super(code: _code);

  /// Poor review timing causes App Store rejection.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_app_review_prompt_timing',
    '[require_ios_app_review_prompt_timing] App review request detected in initialization context. '
        'Do not request reviews on first launch or during startup. {v2}',
    correctionMessage: 'Move review request after meaningful user engagement. '
        'Apple rejects apps that prompt too early.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
              reporter.atNode(node);
              return;
            }
          }
          break;
        }
        if (parent is FunctionDeclaration) {
          final String parentName = parent.name.lexeme;
          for (final String initContext in _initContexts) {
            if (parentName.toLowerCase().contains(initContext.toLowerCase())) {
              reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class AvoidIosHardcodedBundleIdRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedBundleIdRule].
  AvoidIosHardcodedBundleIdRule() : super(code: _code);

  /// Hardcoded bundle IDs cause deployment issues.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ios_hardcoded_bundle_id',
    '[avoid_ios_hardcoded_bundle_id] Hardcoded bundle ID detected. Bundle IDs should come from '
        'configuration, not hardcoded strings. {v2}',
    correctionMessage:
        'Use PackageInfo.fromPlatform().packageName or build-time configuration.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Pattern matching bundle IDs.
  static final RegExp _bundleIdPattern = RegExp(
    r'^com\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip if in test file
      final String filePath = context.filePath;
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
              reporter.atNode(node);
              return;
            }
          }
          if (parent is NamedExpression) {
            final String paramName = parent.name.label.name.toLowerCase();
            if (paramName.contains('bundle') ||
                paramName.contains('package') ||
                paramName.contains('appid')) {
              reporter.atNode(node);
              return;
            }
          }
          parent = parent.parent;
        }
      }
    });
  }
}

/// Warns when hardcoded iOS device model strings (e.g. iPhone, iPad) are detected.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v3
///
/// Device-specific code breaks when new devices are released. Use platform
/// APIs to detect capabilities instead of device names.
///
/// **Exempt:** Word-boundary matching avoids substring false positives
/// (e.g. domain names containing device substrings like 'tripadvisor').
class AvoidIosHardcodedDeviceModelRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedDeviceModelRule].
  AvoidIosHardcodedDeviceModelRule() : super(code: _code);

  /// Hardcoded device models break with new releases.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ios_hardcoded_device_model',
    '[avoid_ios_hardcoded_device_model] Hardcoded iOS device model detected. Device-specific code breaks '
        'when new devices are released. {v3}',
    correctionMessage:
        'Use platform APIs to detect capabilities instead of device names.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Device model patterns to detect.
  ///
  /// Word boundaries prevent false positives on substrings
  /// (e.g. 'tripadvisor' matching 'iPad').
  static final RegExp _deviceModelPattern = RegExp(
    r'\biPhone\s*\d+|\biPad\b(\s+(Pro|Air|mini))?\s*\d*|\biPod\s+touch\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Skip test files
      final String filePath = context.filePath;
      if (filePath.contains('_test.dart') || filePath.contains('/test/')) {
        return;
      }

      if (_deviceModelPattern.hasMatch(value)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when App Groups capability may be needed but not mentioned.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosReceiptValidationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosReceiptValidationRule].
  RequireIosReceiptValidationRule() : super(code: _code);

  /// Missing receipt validation enables fraud.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_receipt_validation',
    '[require_ios_receipt_validation] In-app purchase detected. Ensure receipt is validated with server, '
        'not just locally. {v2}',
    correctionMessage:
        'Send receipt data to your server for validation with Apple. '
        'Local-only validation can be bypassed.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check if file has validation logic
    final String fileSource = context.fileContent;
    final bool hasValidation = fileSource.contains('validateReceipt') ||
        fileSource.contains('verifyPurchase') ||
        fileSource.contains('/verify') ||
        fileSource.contains('receipt_validation');

    if (hasValidation) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_purchaseMethods.contains(methodName)) {
        reporter.atNode(node);
      }
    });
  }
}

// ============================================================================
// v2.3.16 - Even More iOS/macOS Platform Rules
// ============================================================================

/// Warns when Core Data or Realm sync is used without conflict resolution.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosDatabaseConflictResolutionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_database_conflict_resolution',
    '[require_ios_database_conflict_resolution] Database sync detected. Ensure conflict resolution is implemented '
        'for multi-device sync scenarios. {v2}',
    correctionMessage:
        'Implement conflict resolution handlers for sync errors.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final Expression? target = node.target;
      if (target != null && isExactTarget(target, _syncPatterns)) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when Core Location continuous tracking may drain battery.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosContinuousLocationTrackingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_continuous_location_tracking',
    '[avoid_ios_continuous_location_tracking] Continuous location tracking detected with high accuracy. '
        'Consider using lower accuracy or distance filters to save battery. {v2}',
    correctionMessage:
        'Use LocationAccuracy.medium or lower, and set distanceFilter.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'getPositionStream' ||
          methodName == 'startListening' ||
          methodName == 'startLocationUpdates') {
        // Check if high accuracy is used
        final String argSource = node.argumentList.toSource();
        if (argSource.contains('best') ||
            argSource.contains('bestForNavigation') ||
            argSource.contains('high')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when background audio capability may be needed.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class PreferIosStoreKit2Rule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosStoreKit2Rule].
  PreferIosStoreKit2Rule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_ios_storekit2',
    '[prefer_ios_storekit2] Consider using StoreKit 2 APIs for new in-app purchase implementations. '
        'StoreKit 2 offers better async support and automatic receipt verification. {v3}',
    correctionMessage:
        'Evaluate migrating to StoreKit 2 for simpler IAP implementation.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _inAppPurchaseTargets = {'InAppPurchase'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final Expression? target = node.target;
      if (target != null && isExactTarget(target, _inAppPurchaseTargets)) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when App Clip usage is detected without size considerations.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosKeychainSyncAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosKeychainSyncAwarenessRule].
  RequireIosKeychainSyncAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_keychain_sync_awareness',
    '[require_ios_keychain_sync_awareness] Keychain write of sensitive key detected. Consider if this should '
        'sync across devices via iCloud Keychain. {v2}',
    correctionMessage:
        'For device-only secrets, use accessibility ending in ThisDeviceOnly.',
    severity: DiagnosticSeverity.INFO,
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

  static final List<RegExp> _keychainSecureRegex = [
    RegExp(r'\bsecure\b'),
    RegExp(r'\bkeychain\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'write') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_keychainSecureRegex.any((re) => re.hasMatch(targetSource))) {
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
                reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// For sharing custom file types, your app needs UTI declarations in Info.plist.
/// Without them, files may not appear in the share sheet or may fail to open.
///
/// ## Required for Custom Types
///
/// - Exported UTI declarations for types you create
/// - Imported UTI declarations for types you consume
/// - Document types for files you can open
class RequireIosIcloudKvstoreLimitationsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosIcloudKvstoreLimitationsRule].
  RequireIosIcloudKvstoreLimitationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_icloud_kvstore_limitations',
    '[require_ios_icloud_kvstore_limitations] iCloud Key-Value Storage has 1 MB limit and 1024 keys max. '
        'Use only for small preferences. {v2}',
    correctionMessage:
        'For larger data, use CloudKit or iCloud Documents instead.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (value.contains('NSUbiquitousKeyValueStore') ||
          value.contains('ubiquitous_key_value')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when critical accessibility features may be missing.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// iOS apps should support VoiceOver and other accessibility features.
/// Common issues include missing labels, poor contrast, and touch targets.
///
/// ## VoiceOver Requirements
///
/// - All interactive elements need labels
/// - Images need descriptions
/// - Custom controls need traits
class RequireIosOrientationHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosOrientationHandlingRule].
  RequireIosOrientationHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_orientation_handling',
    '[require_ios_orientation_handling] Orientation lock detected. Ensure Info.plist declares supported '
        'orientations and UI handles all locked orientations. {v2}',
    correctionMessage:
        'Set UISupportedInterfaceOrientations in Info.plist to match '
        'SystemChrome.setPreferredOrientations calls.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'setPreferredOrientations') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when deep linking may conflict with iOS Universal Links.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// iOS Universal Links require exact domain matching. Subdomains and
/// path variations can cause routing issues.
class RequireIosSceneDelegateAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosSceneDelegateAwarenessRule].
  RequireIosSceneDelegateAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_scene_delegate_awareness',
    '[require_ios_scene_delegate_awareness] App lifecycle handling detected. On iOS 13+, consider using '
        'scene-based lifecycle for multi-window support. {v2}',
    correctionMessage: 'Use WidgetsBindingObserver.didChangeAppLifecycleState '
        'which handles both app and scene lifecycle.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Check for app lifecycle handling
    if (fileSource.contains('WidgetsBindingObserver') &&
        fileSource.contains('didChangeAppLifecycleState')) {
      return; // Already using Flutter's unified lifecycle handler
    }

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      if (value.contains('applicationDidBecomeActive') ||
          value.contains('applicationWillResignActive') ||
          value.contains('applicationDidEnterBackground')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when MethodChannel observer cleanup may be missing.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosMethodChannelCleanupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_method_channel_cleanup',
    '[require_ios_method_channel_cleanup] MethodChannel handler set without cleanup. Set handler to null '
        'in dispose() to prevent memory leaks. {v2}',
    correctionMessage:
        'Add channel.setMethodCallHandler(null) in dispose() method.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Check if there's proper cleanup
    if (fileSource.contains('setMethodCallHandler(null)') ||
        fileSource.contains('setMethodCallHandler( null)')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'setMethodCallHandler') {
        final String argSource = node.argumentList.toSource();
        if (!argSource.contains('null')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when force unwrapping in MethodChannel callbacks may cause crashes.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosForceUnwrapInCallbacksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ios_force_unwrap_in_callbacks',
    '[avoid_ios_force_unwrap_in_callbacks] Force unwrap on MethodChannel result detected. Native code may '
        'return null unexpectedly, causing crashes. {v2}',
    correctionMessage: 'Use null-safe access (?.) and provide default values.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _forceUnwrapSourceRegex = [
    RegExp(r'\bresult\b'),
    RegExp(r'\bResponse\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Only check files with MethodChannel
    if (!fileSource.contains('MethodChannel') &&
        !fileSource.contains('invokeMethod')) {
      return;
    }

    context.addPostfixExpression((PostfixExpression node) {
      if (node.operator.lexeme == '!') {
        final String source = node.toSource();
        if (_forceUnwrapSourceRegex.any((re) => re.hasMatch(source))) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when in-app review may be requested too frequently.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosReviewPromptFrequencyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_review_prompt_frequency',
    '[require_ios_review_prompt_frequency] In-app review detected. Apple limits StoreKit prompts to 3x per year. '
        'Track and limit prompt frequency. {v2}',
    correctionMessage:
        'Implement review prompt tracking to respect Apple\'s limits.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if frequency tracking exists
    if (fileSource.contains('reviewCount') ||
        fileSource.contains('lastReviewDate') ||
        fileSource.contains('reviewPromptCount')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'requestReview' ||
          node.methodName.name == 'openStoreListing') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when iOS deployment target may not match API usage.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosDeploymentTargetConsistencyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_deployment_target_consistency',
    '[require_ios_deployment_target_consistency] API requiring iOS 15+ detected. Ensure minimum deployment target '
        'matches or add version guards. {v2}',
    correctionMessage: 'Check iOS version before using newer APIs or increase '
        'minimum deployment target.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Map<String, String> _ios15PlusApis = {
    'SharePlay': 'iOS 15+',
    'GroupActivities': 'iOS 15+',
    'AttributedString': 'iOS 15+',
    'async': 'iOS 15+ (Swift concurrency)',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if version check exists
    if (fileSource.contains('@available') ||
        fileSource.contains('ProcessInfo') ||
        fileSource.contains('operatingSystemVersion')) {
      return;
    }

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      for (final String api in _ios15PlusApis.keys) {
        if (value.contains(api)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when iOS Dynamic Island area may not be accounted for.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosDynamicIslandSafeZonesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_dynamic_island_safe_zones',
    '[require_ios_dynamic_island_safe_zones] Fixed top padding (44pt or 59pt) detected. Dynamic Island height '
        'varies by device. Use MediaQuery.padding.top instead. {v2}',
    correctionMessage:
        'Replace hardcoded value with MediaQuery.of(context).padding.top.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (typeName == 'EdgeInsets' || typeName == 'Padding') {
        final String argSource = node.argumentList.toSource();
        // Check for common notch/Dynamic Island heights
        if (argSource.contains('top: 44') ||
            argSource.contains('top: 47') ||
            argSource.contains('top: 59')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when iOS App Intents framework should be considered.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferIosAppIntentsFrameworkRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_ios_app_intents_framework',
    '[prefer_ios_app_intents_framework] Legacy SiriKit Intent detected. Consider migrating to App Intents '
        'framework (iOS 16+) for better Siri and Shortcuts integration. {v2}',
    correctionMessage:
        'Migrate from INIntent to AppIntent for modern Siri integration.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;
      for (final String pattern in _legacySiriPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when iOS app may need age rating consideration.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Apps with user-generated content, web browsing, or mature themes
/// need appropriate age ratings in App Store Connect.
class RequireIosAgeRatingConsiderationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAgeRatingConsiderationRule].
  RequireIosAgeRatingConsiderationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_age_rating_consideration',
    '[require_ios_age_rating_consideration] Feature requiring age rating consideration detected. '
        'Verify App Store Connect age rating matches app content. {v2}',
    correctionMessage:
        'Review App Store Connect age rating for user-generated content, '
        'web access, or mature themes.',
    severity: DiagnosticSeverity.INFO,
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

  static final List<RegExp> _ageRatingTriggersRegex = _ageRatingTriggers
      .map((t) => RegExp(r'\b' + RegExp.escape(t) + r'\b'))
      .toList();

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;
      if (_ageRatingTriggersRegex.any((re) => re.hasMatch(typeName))) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when iOS certificate pinning may be needed for security.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// High-security apps (banking, healthcare) should use certificate
/// pinning to prevent man-in-the-middle attacks.
class RequireIosKeychainForCredentialsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosKeychainForCredentialsRule].
  RequireIosKeychainForCredentialsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_keychain_for_credentials',
    '[require_ios_keychain_for_credentials] Credential storage in SharedPreferences detected. Use iOS Keychain '
        '(flutter_secure_storage) for sensitive data. {v2}',
    correctionMessage:
        'Replace SharedPreferences with FlutterSecureStorage for credentials.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check for SharedPreferences credential storage
      if ((methodName == 'setString' || methodName == 'getString') &&
          target != null &&
          target.toSource().toLowerCase().contains('prefs')) {
        final String argSource = node.argumentList.toSource().toLowerCase();
        for (final String key in _credentialKeys) {
          if (argSource.contains(key.toLowerCase())) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

/// Warns when iOS debug code may be included in release builds.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Debug logging, assertions, and test code should be removed or
/// conditionally compiled out of release builds.
class AvoidIosDebugCodeInReleaseRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosDebugCodeInReleaseRule].
  AvoidIosDebugCodeInReleaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_debug_code_in_release',
    '[avoid_ios_debug_code_in_release] Debug code detected. Ensure this is conditionally compiled out '
        'for release builds. {v2}',
    correctionMessage:
        'Wrap debug code in kDebugMode or assert() for automatic removal.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if mode constant guard exists
    if (usesFlutterModeConstants(fileSource)) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'print' || methodName == 'debugPrint') {
        // Check for debug-specific logging
        final String argSource = node.argumentList.toSource().toLowerCase();
        if (argSource.contains('debug') ||
            argSource.contains('test') ||
            argSource.contains('todo')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when iOS biometric authentication may need fallback.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Not all iOS devices support Face ID or Touch ID. Apps should
/// provide alternative authentication methods.
class AvoidIosMisleadingPushNotificationsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosMisleadingPushNotificationsRule].
  AvoidIosMisleadingPushNotificationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_misleading_push_notifications',
    '[avoid_ios_misleading_push_notifications] Marketing notification pattern detected. Push notifications must '
        'be relevant to user interests to comply with Apple guidelines. {v2}',
    correctionMessage: 'Ensure notifications are personalized and relevant. '
        'Avoid generic marketing messages.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'show' ||
          node.methodName.name == 'send' ||
          node.methodName.name == 'schedule') {
        final Expression? target = node.target;
        if (target != null &&
            target.toSource().toLowerCase().contains('notification')) {
          final String argSource = node.argumentList.toSource().toLowerCase();
          for (final String pattern in _marketingPatterns) {
            if (argSource.contains(pattern)) {
              reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v3
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
/// ## What This Rule Checks
///
/// - `Isolate.spawn` - Creates a persistent isolate that could run
///   indefinitely. Always flagged unless `workmanager` or
///   `BGTaskScheduler` usage is detected nearby.
/// - `Isolate.run()` / `compute()` - Short-lived, one-shot operations that
///   automatically clean up. Only flagged if there's no indication the
///   developer understands it's for short-lived foreground work. Add comments
///   mentioning "foreground", "short-lived", "cpu-bound", "offload",
///   "fire-and-forget", or "never block" to suppress.
///
/// Note: `Isolate.run()` (Dart 2.19+) and `compute()` are designed for
/// one-shot operations that offload CPU-bound work to avoid UI jank. They
/// automatically spawn, execute, return the result, and exit — unlike
/// `Isolate.spawn` which creates a long-lived isolate.
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
///
/// // compute() for short-lived foreground work is fine
/// // Short-lived foreground processing - offloads CPU-bound work
/// final result = await compute(convertModels, data);
/// ```
///
/// @see [Background Execution](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background)
class AvoidLongRunningIsolatesRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidLongRunningIsolatesRule].
  AvoidLongRunningIsolatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_long_running_isolates',
    '[avoid_long_running_isolates] Long-running isolate detected. iOS kills background tasks after '
        '~30 seconds. Design tasks to complete quickly. {v3}',
    correctionMessage:
        'Use workmanager package for reliable background tasks, or break '
        'work into smaller chunks.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect Isolate.spawn - creates long-lived isolates
      if (methodName == 'spawn') {
        final Expression? target = node.target;
        if (target != null && target.toSource() == 'Isolate') {
          final String fileSource = context.fileContent;
          if (!fileSource.contains('workmanager') &&
              !fileSource.contains('Workmanager') &&
              !fileSource.contains('BGTaskScheduler')) {
            reporter.atNode(node);
          }
        }
      }

      // Detect Isolate.run() and compute() - both designed for short-lived,
      // one-shot operations. Less aggressive: skip if surrounding context
      // shows awareness of short-lived/foreground usage.
      if (methodName == 'compute' ||
          (methodName == 'run' &&
              node.target != null &&
              node.target!.toSource() == 'Isolate')) {
        final String fileSource = context.fileContent;
        if (!fileSource.contains('workmanager') &&
            !fileSource.contains('Workmanager')) {
          // Only warn if surrounding context doesn't show awareness
          // of short-lived foreground work
          final int nodeOffset = node.offset;
          final int startOffset = nodeOffset > 500 ? nodeOffset - 500 : 0;
          final String preceding = fileSource.substring(
            startOffset,
            nodeOffset,
          );
          final String precedingLower = preceding.toLowerCase();

          // Skip if comments indicate intentional short-lived foreground use
          if (precedingLower.contains('background') ||
              precedingLower.contains('foreground') ||
              precedingLower.contains('short-lived') ||
              precedingLower.contains('one-shot') ||
              precedingLower.contains('ui jank') ||
              precedingLower.contains('cpu-bound') ||
              precedingLower.contains('offload') ||
              precedingLower.contains('fire-and-forget') ||
              precedingLower.contains('never block')) {
            return;
          }

          // Skip if in a StreamTransformer (common legitimate pattern)
          if (fileSource.contains('StreamTransformer') ||
              fileSource.contains('asyncMap')) {
            return;
          }

          reporter.atNode(node);
        }
      }
    });
  }
}

/// Suggests showing notification for long-running tasks.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireNotificationForLongTasksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_notification_for_long_tasks',
    '[require_notification_for_long_tasks] Long-running operation detected without progress notification. '
        'Silent background work may be killed by OS. {v2}',
    correctionMessage:
        'Show a progress notification for operations that take more than '
        'a few seconds. This keeps users informed and prevents OS termination.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if notifications are being used
    if (fileSource.contains('showNotification') ||
        fileSource.contains('showProgressNotification') ||
        fileSource.contains('FlutterLocalNotifications')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      for (final String pattern in _longOperationPatterns) {
        if (methodName.toLowerCase().contains(pattern.toLowerCase())) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Suggests delaying permission prompt until user sees value.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferDelayedPermissionPromptRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_delayed_permission_prompt',
    '[prefer_delayed_permission_prompt] Permission request detected in main() or initState(). '
        'Asking too early reduces acceptance rates. {v2}',
    correctionMessage:
        'Wait until user interaction shows they need the feature, '
        'then explain the value before requesting permission.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _permissionPromptSourceRegex = [
    RegExp(r'\bnotification\b'),
    RegExp(r'\bpermission\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect permission requests
      if (methodName == 'requestPermission' ||
          methodName == 'requestPermissions' ||
          methodName == 'request') {
        final String source = node.toSource().toLowerCase();
        if (_permissionPromptSourceRegex.any((re) => re.hasMatch(source))) {
          // Check if we're in main() or initState()
          AstNode? current = node.parent;
          while (current != null) {
            if (current is FunctionDeclaration) {
              final String funcName = current.name.lexeme;
              if (funcName == 'main') {
                reporter.atNode(node);
                return;
              }
            }
            if (current is MethodDeclaration) {
              final String funcName = current.name.lexeme;
              if (funcName == 'initState' || funcName == 'main') {
                reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidNotificationSpamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_notification_spam',
    '[avoid_notification_spam] Notification inside loop detected. Sending too many notifications '
        'causes users to disable notifications or uninstall. {v2}',
    correctionMessage:
        'Batch notifications or use a summary notification when there are '
        'multiple items.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
              reporter.atNode(node);
              return;
            }
            // Check for forEach
            if (current is MethodInvocation &&
                current.methodName.name == 'forEach') {
              reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequirePurchaseVerificationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_purchase_verification',
    '[require_purchase_verification] In-app purchase without server verification detected. '
        'Client-side verification can be bypassed by attackers. {v2}',
    correctionMessage:
        'Verify purchase receipts server-side with Apple/Google. '
        'Consider using an IAP SDK for cross-platform verification.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if server verification is present
    if (fileSource.contains('serverVerificationData') ||
        fileSource.contains('verifyReceipt') ||
        fileSource.contains('RevenueCat') ||
        fileSource.contains('validateReceipt')) {
      return;
    }

    context.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      // Detect purchase status checks without verification
      if (name == 'PurchaseStatus') {
        final AstNode? parent = node.parent;
        if (parent != null) {
          final String parentSource = parent.toSource();
          if (parentSource.contains('purchased') ||
              parentSource.contains('restored')) {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when "Restore Purchases" functionality is missing.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequirePurchaseRestorationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_purchase_restoration',
    '[require_purchase_restoration] In-app purchase detected without restore functionality. '
        'App Store requires "Restore Purchases" for non-consumables. {v2}',
    correctionMessage: 'Add a "Restore Purchases" button that calls '
        'InAppPurchase.instance.restorePurchases().',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

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

    context.addSimpleIdentifier((SimpleIdentifier node) {
      if (node.name == 'InAppPurchase' || node.name == 'StoreKit') {
        reporter.atNode(node);
      }
    });
  }
}

/// Suggests using BGTaskScheduler for background sync on iOS.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferBackgroundSyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_background_sync',
    '[prefer_background_sync] Data sync in initState() only runs when app is open. '
        'Consider background sync for better user experience. {v2}',
    correctionMessage:
        'Use Workmanager for background sync. Data stays fresh even when '
        'the app is not actively used.',
    severity: DiagnosticSeverity.INFO,
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

  static final List<RegExp> _syncPatternsBodyRegex = _syncPatterns
      .map((p) => RegExp(r'\b' + RegExp.escape(p) + r'\b'))
      .toList();

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if workmanager is used
    if (fileSource.contains('Workmanager') ||
        fileSource.contains('workmanager')) {
      return;
    }

    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme == 'initState') {
        final String bodySource = node.body.toSource();
        if (_syncPatternsBodyRegex.any((re) => re.hasMatch(bodySource))) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when sync error recovery is missing.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireSyncErrorRecoveryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_sync_error_recovery',
    '[require_sync_error_recovery] Sync operation without error recovery detected. '
        'Failed syncs should retry and notify user of unrecoverable errors. {v2}',
    correctionMessage: 'Implement exponential backoff retry and notify user of '
        'persistent failures.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// Additional iOS-Specific Rules
// =============================================================================

/// Warns when code assumes WiFi-only connectivity.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosWifiOnlyAssumptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_wifi_only_assumption',
    '[avoid_ios_wifi_only_assumption] Large download without connectivity check. Users may have '
        'expensive cellular plans. {v2}',
    correctionMessage:
        'Check connectivity type and warn user before large downloads '
        'on cellular.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _methodNameDownload = RegExp(r'\bdownload\b');
  static final RegExp _methodNameLarge = RegExp(r'\blarge\b');
  static final RegExp _methodNameFile = RegExp(r'\bfile\b');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if connectivity is being checked
    if (fileSource.contains('Connectivity') ||
        fileSource.contains('connectivity') ||
        fileSource.contains('NetworkType')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      if (_methodNameDownload.hasMatch(methodName) &&
          (_methodNameLarge.hasMatch(methodName) ||
              _methodNameFile.hasMatch(methodName))) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when app doesn't handle iOS Low Power Mode.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosLowPowerModeHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_low_power_mode_handling',
    '[require_ios_low_power_mode_handling] Heavy animation or background activity detected. Consider '
        'checking iOS Low Power Mode and adapting behavior. {v2}',
    correctionMessage:
        'Check ProcessInfo.isLowPowerModeEnabled and reduce animations '
        'or defer background work when enabled.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if low power mode is being checked
    if (fileSource.contains('LowPower') ||
        fileSource.contains('lowPower') ||
        fileSource.contains('batteryState')) {
      return;
    }

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Suggests supporting Dynamic Type (large text) on iOS.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class PreferIosContextMenuRule extends SaropaLintRule {
  /// Creates a new instance of [PreferIosContextMenuRule].
  PreferIosContextMenuRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_ios_context_menu',
    '[prefer_ios_context_menu] ListTile with multiple actions could benefit from a context menu. '
        'iOS users expect long-press for secondary actions. {v2}',
    correctionMessage:
        'Wrap actionable items with CupertinoContextMenu for better iOS UX.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

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

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName == 'ListTile' || node.typeName == 'Card') {
        // Check if there are multiple interactive elements
        final String nodeSource = node.toSource();
        final RegExp actionPattern = RegExp(r'onTap|onPressed|trailing.*Icon');
        final int actionCount = actionPattern.allMatches(nodeSource).length;

        if (actionCount >= 2) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Reminds about iOS Quick Note feature compatibility.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class AvoidIosHardcodedKeyboardHeightRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidIosHardcodedKeyboardHeightRule].
  AvoidIosHardcodedKeyboardHeightRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_hardcoded_keyboard_height',
    '[avoid_ios_hardcoded_keyboard_height] Hardcoded bottom padding may be for keyboard. iOS keyboard height '
        'varies by device and input type. {v2}',
    correctionMessage:
        'Use MediaQuery.of(context).viewInsets.bottom for keyboard height.',
    severity: DiagnosticSeverity.WARNING,
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
    350,
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.typeName != 'EdgeInsets') {
        return;
      }

      // Check for hardcoded bottom values
      final Expression? bottom = node.getNamedParameterValue('bottom');
      if (bottom != null && bottom is IntegerLiteral) {
        final int value = bottom.value ?? 0;
        if (_keyboardHeights.contains(value)) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when iPad multitasking modes aren't handled.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosMultitaskingSupportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_multitasking_support',
    '[require_ios_multitasking_support] Fixed layout detected. iPads support Split View and Slide Over. '
        'Layouts should adapt to window size changes. {v2}',
    correctionMessage:
        'Use LayoutBuilder or MediaQuery breakpoints to create responsive '
        'layouts that work in multitasking modes.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if responsive patterns are used
    if (fileSource.contains('LayoutBuilder') ||
        fileSource.contains('OrientationBuilder') ||
        fileSource.contains('constraints.maxWidth') ||
        fileSource.contains('breakpoint')) {
      return;
    }

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Detect Row with fixed width children at top level
      if (node.typeName == 'Row') {
        // Check if parent suggests full-screen usage
        AstNode? current = node.parent;
        while (current != null) {
          if (current is InstanceCreationExpression) {
            if (current.typeName == 'Scaffold') {
              reporter.atNode(node);
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferIosSpotlightIndexingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_ios_spotlight_indexing',
    '[prefer_ios_spotlight_indexing] Searchable content detected. Consider indexing with Core Spotlight '
        'so users can find content from iOS home screen. {v2}',
    correctionMessage:
        'Use CSSearchableItem to index content for Spotlight search.',
    severity: DiagnosticSeverity.INFO,
  );

  static final List<RegExp> _spotlightBodyRegex = [
    RegExp(r'\bListView\b'),
    RegExp(r'\bitems\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

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

    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      if (className.contains('search') || className.contains('list')) {
        final String bodySource = node.toSource();
        if (_spotlightBodyRegex.any((re) => re.hasMatch(bodySource))) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Suggests using iOS Data Protection for sensitive files.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosDataProtectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_data_protection',
    '[require_ios_data_protection] Sensitive file storage detected. Consider using iOS Data Protection '
        'to encrypt files when device is locked. {v2}',
    correctionMessage: 'Set appropriate FileProtectionType for sensitive data. '
        'Use "complete" protection for highly sensitive files.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if data protection is being used
    if (fileSource.contains('FileProtection') ||
        fileSource.contains('dataProtection') ||
        fileSource.contains('setProtection')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Detect file write operations
      if (methodName == 'writeAsBytes' ||
          methodName == 'writeAsString' ||
          methodName == 'writeSync') {
        // Check if file name or surrounding context suggests sensitive data
        final String surroundingSource = node.toSource().toLowerCase();
        for (final String pattern in _sensitivePatterns) {
          if (surroundingSource.contains(pattern)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

/// Warns when code patterns may cause excessive battery drain.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidIosBatteryDrainPatternsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_ios_battery_drain_patterns',
    '[avoid_ios_battery_drain_patterns] Pattern detected that may cause excessive battery drain. '
        'iOS shows high battery usage in Settings. {v2}',
    correctionMessage: 'Use push notifications instead of polling. '
        'Reduce location accuracy and frequency.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
              reporter.atNode(node);
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
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when iOS entitlements may be needed for features.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosEntitlementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_entitlements',
    '[require_ios_entitlements] Feature detected that requires iOS entitlement/capability. '
        'Enable in Xcode Signing & Capabilities. {v2}',
    correctionMessage:
        'Open Xcode, select Runner target, go to Signing & Capabilities, '
        'and add the required capability.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      for (final String feature in _featureToCapability.keys) {
        if (name.contains(feature)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when iOS launch screen configuration may be missing.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosLaunchStoryboardRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_launch_storyboard',
    '[require_ios_launch_storyboard] iOS app detected. Ensure LaunchScreen.storyboard is properly '
        'configured. Apps without launch screen are rejected. {v2}',
    correctionMessage:
        'Verify ios/Runner/Base.lproj/LaunchScreen.storyboard exists '
        'and is configured in Xcode.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String filePath = context.filePath;

    // Only check main.dart
    if (!filePath.endsWith('main.dart')) {
      return;
    }

    final String fileSource = context.fileContent;

    // Check for iOS platform check
    if (!fileSource.contains('Platform.isIOS') && !fileSource.contains('ios')) {
      return;
    }

    context.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme == 'main') {
        // Check for launch screen comment
        final String surroundingSource = fileSource.substring(
          node.offset > 200 ? node.offset - 200 : 0,
          node.offset,
        );
        if (!surroundingSource.contains('LaunchScreen') &&
            !surroundingSource.contains('launch screen')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when iOS version-specific features lack platform checks.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosVersionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_version_check',
    '[require_ios_version_check] iOS version-specific feature detected without version check. '
        'Crashes may occur on older iOS versions. {v2}',
    correctionMessage: 'Check iOS version before using newer APIs. '
        'Use device_info_plus to get iOS version.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if version check is present
    if (fileSource.contains('iosVersion') ||
        fileSource.contains('systemVersion') ||
        fileSource.contains('operatingSystemVersion')) {
      return;
    }

    context.addSimpleIdentifier((SimpleIdentifier node) {
      final String name = node.name;

      for (final String api in _ios17Apis) {
        if (name.contains(api)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when iOS Focus mode integration is not handled.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosFocusModeAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_focus_mode_awareness',
    '[require_ios_focus_mode_awareness] Notification without interruption level detected. iOS Focus mode '
        'may silence notifications. Set appropriate interruption level. {v2}',
    correctionMessage:
        'Use interruptionLevel parameter to indicate notification importance. '
        'Time-sensitive notifications can break through Focus.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if interruption level is being used
    if (fileSource.contains('interruptionLevel') ||
        fileSource.contains('InterruptionLevel')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'show' || methodName == 'send') {
        final Expression? target = node.target;
        if (target != null &&
            target.toSource().toLowerCase().contains('notification')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Suggests implementing iOS Handoff for continuity between devices.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferIosHandoffSupportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_ios_handoff_support',
    '[prefer_ios_handoff_support] Document or content editing detected. Consider implementing '
        'iOS Handoff for continuity across devices. {v2}',
    correctionMessage:
        'Use NSUserActivity to enable Handoff. Users can continue work '
        'on other Apple devices.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if NSUserActivity is being used
    if (fileSource.contains('NSUserActivity') ||
        fileSource.contains('Handoff') ||
        fileSource.contains('handoff')) {
      return;
    }

    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      if (className.contains('editor') ||
          className.contains('compose') ||
          className.contains('draft')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when iOS voiceover gestures may conflict with app gestures.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
