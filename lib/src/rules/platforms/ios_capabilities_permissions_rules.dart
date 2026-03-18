// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

// cspell:disable

/// iOS platform-specific lint rules (split file).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../info_plist_utils.dart';
import '../../target_matcher_utils.dart';
import '../../saropa_lint_rule.dart';

class RequireIosPermissionDescriptionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPermissionDescriptionRule].
  RequireIosPermissionDescriptionRule() : super(code: _code);

  /// Missing permission descriptions cause App Store rejection.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_permission_description',
    '[require_ios_permission_description] Missing Info.plist keys cause App '
        'Store rejection or instant crash when the permission is requested. {v5}',
    correctionMessage: 'Add the missing key(s) to ios/Runner/Info.plist.',
    severity: DiagnosticSeverity.WARNING,
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
      'require_ios_permission_description',
      '[require_ios_permission_description] Permission-requiring API used. Missing Info.plist key(s): '
          '${missingKeys.join(", ")}',
      correctionMessage:
          'Add ${missingKeys.join(" and ")} to ios/Runner/Info.plist.',
      severity: DiagnosticSeverity.WARNING,
    );
  }

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Get the Info.plist checker for this file's project.
    final filePath = context.filePath;
    final plistChecker = InfoPlistChecker.forFile(filePath);

    // Check for permission-requiring types (non-ImagePicker).
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireIosPrivacyManifestRule() : super(code: _code);

  /// Missing privacy manifest can cause App Store rejection (iOS 17+).
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_privacy_manifest',
    '[require_ios_privacy_manifest] API requires an iOS Privacy Manifest entry (iOS 17+). Missing PrivacyInfo.xcprivacy declarations for required-reason APIs will cause automatic App Store rejection during review, block new releases, and may trigger runtime permission failures on user devices. {v3}',
    correctionMessage:
        'Add a PrivacyInfo.xcprivacy file with the required reason API declarations. This is mandatory for App Store approval and correct runtime behavior on iOS 17+.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (_privacyManifestTypes.contains(typeName)) {
        reporter.atNode(node);
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_privacyManifestMethods.contains(methodName)) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// Additional iOS-Specific Rules (v2.3.13)
// =============================================================================

/// Warns when apps use third-party login without Sign in with Apple.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosBackgroundModeRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBackgroundModeRule].
  RequireIosBackgroundModeRule() : super(code: _code);

  /// Background violations can cause app termination.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_background_mode',
    '[require_ios_background_mode] Background task pattern detected. iOS requires specific capabilities '
        'for background execution. {v2}',
    correctionMessage:
        'Add background capabilities in Xcode (Background fetch, '
        'Background processing, etc.) and use workmanager package.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_backgroundPatterns.contains(methodName)) {
        reporter.atNode(node);
      }
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (_backgroundPatterns.contains(typeName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when deprecated iOS 13+ APIs are used via platform channels.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosAppTrackingTransparencyRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppTrackingTransparencyRule].
  RequireIosAppTrackingTransparencyRule() : super(code: _code);

  /// ATT is required for App Store approval.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_app_tracking_transparency',
    '[require_ios_app_tracking_transparency] Advertising/tracking SDK detected. iOS 14.5+ requires App Tracking '
        'Transparency permission before tracking users. {v2}',
    correctionMessage:
        'Use AppTrackingTransparency.requestTrackingAuthorization() before '
        'initializing ad SDKs. Add NSUserTrackingUsageDescription to Info.plist.',
    severity: DiagnosticSeverity.ERROR,
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

  static final List<RegExp> _trackingTypeNameRegex = _trackingPatterns
      .map((p) => RegExp(r'\b' + RegExp.escape(p) + r'\b'))
      .toList();

  /// ATT-related patterns that indicate proper handling.
  static const Set<String> _attPatterns = {
    'AppTrackingTransparency',
    'requestTrackingAuthorization',
    'TrackingStatus',
    'ATTrackingManager',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check file source for ATT presence
    final String fileSource = context.fileContent;
    bool hasATT = false;
    for (final String pattern in _attPatterns) {
      if (fileSource.contains(pattern)) {
        hasATT = true;
        break;
      }
    }

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasATT) return;

      final String typeName = node.typeName;
      if (_trackingTypeNameRegex.any((re) => re.hasMatch(typeName))) {
        reporter.atNode(node);
        return;
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (hasATT) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;
      final String fullCall = target != null
          ? '${target.toSource()}.$methodName'
          : methodName;

      for (final String pattern in _trackingPatterns) {
        if (fullCall.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when Face ID is used without NSFaceIDUsageDescription.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireIosFaceIdUsageDescriptionRule() : super(code: _code);

  /// Missing Face ID description causes crashes and rejection.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_face_id_usage_description',
    '[require_ios_face_id_usage_description] Biometric authentication detected. iOS requires '
        'NSFaceIDUsageDescription in Info.plist for Face ID. {v4}',
    correctionMessage:
        'Add NSFaceIDUsageDescription to ios/Runner/Info.plist explaining '
        'why your app uses Face ID.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Type names from the local_auth package.
  static const Set<String> _localAuthTypeNames = {'LocalAuthentication'};

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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Get the Info.plist checker for this file's project.
    final filePath = context.filePath;
    final plistChecker = InfoPlistChecker.forFile(filePath);

    // Skip if NSFaceIDUsageDescription is already in Info.plist.
    if (plistChecker?.hasKey('NSFaceIDUsageDescription') ?? false) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Use element name for reliable type checking
      final String? typeName = node.constructorName.type.element?.name;

      if (typeName == 'LocalAuthentication' ||
          typeName == 'AuthenticationOptions') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when saving photos without NSPhotoLibraryAddUsageDescription.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosPhotoLibraryAddUsageRule() : super(code: _code);

  /// Missing permission causes crashes.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_photo_library_add_usage',
    '[require_ios_photo_library_add_usage] Photo saving detected. iOS requires NSPhotoLibraryAddUsageDescription '
        'for saving photos (separate from read permission). {v2}',
    correctionMessage:
        'Add NSPhotoLibraryAddUsageDescription to ios/Runner/Info.plist.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check method name
      if (_photoSavePatterns.contains(methodName)) {
        reporter.atNode(node);
        return;
      }

      if (target != null && isExactTarget(target, _photoSavePatterns)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when OAuth is performed via in-app WebView instead of system browser.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosPushNotificationCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPushNotificationCapabilityRule].
  RequireIosPushNotificationCapabilityRule() : super(code: _code);

  /// Missing push configuration causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_push_notification_capability',
    '[require_ios_push_notification_capability] Push notification usage detected. Ensure Push Notifications '
        'capability is enabled in Xcode and APNs is configured. {v3}',
    correctionMessage:
        'Enable Push Notifications in Xcode Signing & Capabilities. '
        'Configure APNs key/certificate in Apple Developer Console.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Push notification method name patterns.
  static const Set<String> _pushMethodPatterns = {
    'getToken',
    'onMessage',
    'onMessageOpenedApp',
    'requestPermission',
    'registerForRemoteNotifications',
  };

  /// Push notification class name patterns.
  ///
  /// Only these are checked against target source via substring matching.
  /// Method patterns are NOT checked against target source because they can
  /// false-positive on unrelated identifiers (e.g. `onMessage` matching
  /// inside `CommonMessagePanel`).
  static const Set<String> _pushClassPatterns = {
    'FirebaseMessaging',
    'UNUserNotificationCenter',
    'OneSignal',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Check method name (exact match)
      if (_pushMethodPatterns.contains(methodName) ||
          _pushClassPatterns.contains(methodName)) {
        reporter.atNode(node);
        hasReported = true;
        return;
      }

      if (target != null && isExactTarget(target, _pushClassPatterns)) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

// ============================================================================
// v2.3.15 - Additional iOS Platform Rules
// ============================================================================

/// Warns when HTTP connections are used without ATS exception documentation.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosLocalNotificationPermissionRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLocalNotificationPermissionRule].
  RequireIosLocalNotificationPermissionRule() : super(code: _code);

  /// Notifications without permission fail silently.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_local_notification_permission',
    '[require_ios_local_notification_permission] Local notification scheduling detected. Ensure iOS notification '
        'permission is requested before scheduling. {v2}',
    correctionMessage:
        'Call requestPermissions() on IOSFlutterLocalNotificationsPlugin '
        'before scheduling notifications.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Notification scheduling methods.
  static const Set<String> _scheduleMethods = {
    'zonedSchedule',
    'schedule',
    'periodicallyShow',
    'showDailyAtTime',
    'showWeeklyAtDayAndTime',
  };

  static const Set<String> _notificationTargets = {
    'Notification',
    'notification',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check if file has permission request
    final String fileSource = context.fileContent;
    final bool hasPermissionRequest =
        fileSource.contains('requestPermissions') ||
        fileSource.contains('IOSFlutterLocalNotificationsPlugin');

    if (hasPermissionRequest) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_scheduleMethods.contains(methodName)) {
        final Expression? target = node.target;
        if (target != null &&
            _notificationTargets.contains(extractTargetName(target))) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when device model names are hardcoded instead of detected.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosAppGroupCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppGroupCapabilityRule].
  RequireIosAppGroupCapabilityRule() : super(code: _code);

  /// Missing App Groups causes silent data sharing failures.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_app_group_capability',
    '[require_ios_app_group_capability] App extension data sharing detected. Ensure App Groups capability '
        'is enabled in Xcode for both main app and extensions. {v2}',
    correctionMessage:
        'Add App Groups capability in Xcode Signing & Capabilities. '
        'Use same group ID in both main app and extensions.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;

      // Check for group. prefix in suite name
      if (value.startsWith('group.')) {
        reporter.atNode(node);
        hasReported = true;
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;

      if (_appGroupPatterns.contains(methodName)) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when HealthKit APIs are used without authorization check.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosHealthKitAuthorizationRule() : super(code: _code);

  /// HealthKit access without authorization fails silently.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_healthkit_authorization',
    '[require_ios_healthkit_authorization] HealthKit data access detected. Ensure authorization is requested '
        'before reading or writing health data. {v2}',
    correctionMessage:
        'Call requestAuthorization() before accessing health data. '
        'Add NSHealthShareUsageDescription and NSHealthUpdateUsageDescription '
        'to Info.plist.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check if file has authorization call
    final String fileSource = context.fileContent;
    final bool hasAuthCheck =
        fileSource.contains('requestAuthorization') ||
        fileSource.contains('hasAuthorization') ||
        fileSource.contains('isAuthorized');

    if (hasAuthCheck) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_healthDataMethods.contains(methodName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Siri Shortcuts are implemented without intent definition.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosSiriIntentDefinitionRule() : super(code: _code);

  /// Missing Siri intent definition causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_siri_intent_definition',
    '[require_ios_siri_intent_definition] Siri Shortcuts usage detected. Ensure Intent Definition file '
        'exists in Xcode and SiriKit capability is enabled. {v2}',
    correctionMessage:
        'Add Intent Definition file in Xcode: File > New > File > Intent Definition. '
        'Enable SiriKit capability in Signing & Capabilities.',
    severity: DiagnosticSeverity.INFO,
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

  static final List<RegExp> _siriPatternsRegex = _siriPatterns
      .map((p) => RegExp(r'\b' + RegExp.escape(p) + r'\b'))
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

      if (_siriPatternsRegex.any((re) => re.hasMatch(typeName))) {
        reporter.atNode(node);
        hasReported = true;
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target != null) {
        final String fullCall = '${target.toSource()}.$methodName';
        if (fullCall.contains('Siri') && methodName == 'donate') {
          reporter.atNode(node);
          hasReported = true;
        }
      }
    });
  }
}

/// Warns when iOS Home Screen widgets are implemented without WidgetKit setup.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosWidgetExtensionCapabilityRule() : super(code: _code);

  /// Missing widget extension setup causes silent failures.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_ios_widget_extension_capability',
    '[require_ios_widget_extension_capability] Home Screen widget usage detected. Ensure Widget Extension target '
        'and App Groups are configured in Xcode. {v2}',
    correctionMessage:
        'Create Widget Extension target in Xcode. Enable App Groups in both '
        'main app and extension. Use shared UserDefaults for data.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (_widgetPatterns.contains(methodName)) {
        reporter.atNode(node);
        hasReported = true;
        return;
      }

      if (target != null && isExactTarget(target, _widgetPatterns)) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when in-app purchases are used without receipt validation.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosBackgroundAudioCapabilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBackgroundAudioCapabilityRule].
  RequireIosBackgroundAudioCapabilityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_background_audio_capability',
    '[require_ios_background_audio_capability] Audio playback detected. If audio should play in background, '
        'enable Background Modes > Audio capability in Xcode. {v2}',
    correctionMessage:
        'Add Background Modes capability and enable Audio, AirPlay, '
        'and Picture in Picture.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (hasReported) return;

      final String typeName = node.typeName;
      if (_audioPatterns.contains(typeName)) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when StoreKit 2 APIs should be preferred over original StoreKit.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v3
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
class RequireIosAppClipSizeLimitRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAppClipSizeLimitRule].
  RequireIosAppClipSizeLimitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_app_clip_size_limit',
    '[require_ios_app_clip_size_limit] App Clip detected. Ensure App Clip bundle stays under 10 MB. '
        'Large dependencies can exceed this limit. {v2}',
    correctionMessage:
        'Minimize dependencies and assets in App Clip target. '
        'Consider lazy loading heavy features.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check if file path suggests App Clip
    final String filePath = context.filePath;
    if (!filePath.contains('app_clip') && !filePath.contains('AppClip')) {
      return;
    }

    bool hasReported = false;

    context.addImportDirective((ImportDirective node) {
      if (hasReported) return;

      final String? uri = node.uri.stringValue;
      if (uri != null) {
        // Warn about potentially large packages
        if (uri.contains('tensorflow') ||
            uri.contains('firebase') ||
            uri.contains('video_player') ||
            uri.contains('webview')) {
          reporter.atNode(node);
          hasReported = true;
        }
      }
    });
  }
}

/// Warns when iOS Keychain is accessed without considering iCloud sync.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosShareSheetUtiDeclarationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosShareSheetUtiDeclarationRule].
  RequireIosShareSheetUtiDeclarationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_share_sheet_uti_declaration',
    '[require_ios_share_sheet_uti_declaration] File sharing with custom type detected. Ensure UTI is declared '
        'in Info.plist for custom file types. {v2}',
    correctionMessage:
        'Add UTExportedTypeDeclarations or UTImportedTypeDeclarations '
        'to Info.plist for custom file types.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'share' || methodName == 'shareFiles') {
        final String argSource = node.argumentList.toSource();
        // Check for custom file extensions
        if (argSource.contains('.custom') ||
            argSource.contains('.myapp') ||
            argSource.contains('mimeType:')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when NSUbiquitousKeyValueStore (iCloud Key-Value Storage) is used.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosAccessibilityLabelsRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAccessibilityLabelsRule].
  RequireIosAccessibilityLabelsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_accessibility_labels',
    '[require_ios_accessibility_labels] Interactive widget without Semantics wrapper. VoiceOver users '
        'cannot identify this element. {v2}',
    correctionMessage:
        'Wrap with Semantics widget and provide label for VoiceOver.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      // Check for icon buttons without semantics
      if (typeName == 'IconButton') {
        final String argSource = node.argumentList.toSource();
        if (!argSource.contains('tooltip') &&
            !fileSource.contains('Semantics')) {
          reporter.atNode(node);
        }
      }

      // Check for GestureDetector on images
      if (typeName == 'GestureDetector') {
        final String argSource = node.argumentList.toSource();
        if (argSource.contains('Image') &&
            !argSource.contains('semanticLabel') &&
            !fileSource.contains('Semantics')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when iOS app may not handle all device orientations.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Apps should explicitly declare supported orientations in Info.plist
/// and handle orientation changes gracefully.
///
/// ## Info.plist Keys
///
/// - UISupportedInterfaceOrientations (iPhone)
/// - UISupportedInterfaceOrientations~ipad (iPad)
class RequireIosNfcCapabilityCheckRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosNfcCapabilityCheckRule].
  RequireIosNfcCapabilityCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_nfc_capability_check',
    '[require_ios_nfc_capability_check] NFC usage detected. Not all iOS devices support NFC. '
        'Check capability before use. {v2}',
    correctionMessage:
        'Use NFCNDEFReaderSession.readingAvailable before scanning.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    if (fileSource.contains('isAvailable') ||
        fileSource.contains('readingAvailable') ||
        fileSource.contains('NFCReaderSession.readingAvailable')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_nfcPatterns.contains(methodName)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when CallKit integration may be missing for VoIP apps.
///
/// Since: v2.4.0 | Updated: v4.14.5 | Rule version: v4
///
/// iOS VoIP apps must use CallKit to display the native call UI.
/// Without CallKit, incoming calls won't appear on the lock screen,
/// call audio routing will fail, and Apple will reject the app.
///
/// Uses word-boundary matching (`\b`) to avoid false positives from
/// substring matches (e.g. "Zagora" does not match the "Agora" pattern).
///
/// **BAD:**
/// ```dart
/// // VoIP keyword without CallKit integration
/// const protocol = 'voip';
/// const sdk = 'Agora';
/// ```
///
/// **GOOD:**
/// ```dart
/// // CallKit already integrated (file contains 'CallKit')
/// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
/// const sdk = 'Agora';
/// ```
///
/// ## CallKit Requirements
///
/// - CXProvider for incoming calls
/// - CXCallController for outgoing calls
/// - Push notifications for VoIP
class RequireIosCallkitIntegrationRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosCallkitIntegrationRule].
  RequireIosCallkitIntegrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_callkit_integration',
    '[require_ios_callkit_integration] VoIP call handling detected. iOS requires CallKit integration for native call UI. Without CallKit, incoming calls will not appear on the lock screen, call audio routing will fail, and Apple will reject your app from the App Store during review. {v4}',
    correctionMessage:
        'Integrate CallKit using flutter_callkit_incoming or a similar package to ensure App Store compliance and a native call experience on iOS.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Unambiguous VoIP technical terms for string scanning.
  /// Brand names (Agora, Twilio, Vonage, WebRTC) removed because
  /// they have non-VoIP meanings and cause false positives.
  /// VoIP SDK usage is detected via import directives instead.
  static final List<RegExp> _voipStringRegexes =
      ['voip', 'incoming_call', 'outgoing_call', 'call_state']
          .map((p) => RegExp('\\b${RegExp.escape(p)}\\b', caseSensitive: false))
          .toList();

  /// Known VoIP/telephony package URIs detected via import directives.
  static const List<String> _voipPackages = <String>[
    'agora_rtc_engine',
    'agora_rtm',
    'flutter_webrtc',
    'twilio_voice',
    'twilio_programmable_video',
    'vonage_client_sdk',
    'flutter_voip_push_notification',
    'connectycube_flutter_call_kit',
    'sip_ua',
    'flutter_pjsip',
    'janus_client',
    'livekit_client',
    'stream_video_flutter',
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Check if CallKit is already integrated
    if (fileSource.contains('CallKit') ||
        fileSource.contains('flutter_callkit') ||
        fileSource.contains('CXProvider')) {
      return;
    }

    bool hasReported = false;

    // Check imports for known VoIP packages
    context.addImportDirective((ImportDirective node) {
      if (hasReported) return;

      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      for (final String package in _voipPackages) {
        if (uri.contains(package)) {
          reporter.atNode(node);
          hasReported = true;
          return;
        }
      }
    });

    // Check string literals for unambiguous VoIP technical terms
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;
      for (final RegExp regex in _voipStringRegexes) {
        if (regex.hasMatch(value)) {
          reporter.atNode(node);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when CarPlay integration may need additional setup.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosCarplaySetupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_carplay_setup',
    '[require_ios_carplay_setup] CarPlay-related code detected. CarPlay requires Apple approval '
        'and specific entitlements. {v2}',
    correctionMessage:
        'Apply for CarPlay entitlement at developer.apple.com. '
        'Implement CPTemplateApplicationSceneDelegate.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _carplayPatterns = {
    'CarPlay',
    'CPTemplate',
    'CPListTemplate',
    'CPMapTemplate',
    'flutter_carplay',
  };

  static final List<RegExp> _carplayPatternsRegex = _carplayPatterns
      .map((p) => RegExp(r'\b' + RegExp.escape(p) + r'\b'))
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
      if (_carplayPatternsRegex.any((re) => re.hasMatch(typeName))) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when Live Activities may need proper configuration.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// iOS 16.1+ Live Activities require:
/// - ActivityKit capability
/// - Widget Extension with ActivityConfiguration
/// - Proper push notification setup for remote updates
class RequireIosLiveActivitiesSetupRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosLiveActivitiesSetupRule].
  RequireIosLiveActivitiesSetupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_live_activities_setup',
    '[require_ios_live_activities_setup] Live Activity usage detected. Ensure ActivityKit capability '
        'and Widget Extension are configured. {v2}',
    correctionMessage:
        'Add Widget Extension with ActivityConfiguration. '
        'Enable Push Notifications for remote updates.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _liveActivityPatterns = {
    'LiveActivity',
    'ActivityKit',
    'ActivityConfiguration',
    'ActivityAttributes',
    'live_activities',
  };

  static final List<RegExp> _liveActivityTypeNameRegex = _liveActivityPatterns
      .map((p) => RegExp(r'\b' + RegExp.escape(p) + r'\b'))
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
      if (_liveActivityTypeNameRegex.any((re) => re.hasMatch(typeName))) {
        reporter.atNode(node);
        hasReported = true;
      }
    });

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (hasReported) return;

      final String value = node.value;
      for (final String pattern in _liveActivityPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node);
          hasReported = true;
          return;
        }
      }
    });
  }
}

/// Warns when ProMotion display support may be needed.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// iPhone 13 Pro and later have ProMotion displays (120Hz).
/// Apps should use CADisplayLink for smooth animations on these devices.
class RequireIosPromotionDisplaySupportRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPromotionDisplaySupportRule].
  RequireIosPromotionDisplaySupportRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_promotion_display_support',
    '[require_ios_promotion_display_support] Manual frame timing detected. ProMotion displays run at 120Hz. '
        'Use Flutter animations for automatic frame rate adaptation. {v2}',
    correctionMessage:
        'Use AnimationController instead of manual timing for smooth animations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.typeName;

      if (typeName == 'Duration') {
        final String argSource = node.argumentList.toSource();
        // Check for hardcoded 60fps timing (16-17ms)
        if (argSource.contains('milliseconds: 16') ||
            argSource.contains('milliseconds: 17')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when Photo Library limited access may not be handled.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// iOS 14+ supports limited photo library access. Apps should handle
/// the case where user only grants access to selected photos.
class RequireIosPhotoLibraryLimitedAccessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosPhotoLibraryLimitedAccessRule].
  RequireIosPhotoLibraryLimitedAccessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_photo_library_limited_access',
    '[require_ios_photo_library_limited_access] Photo library access detected. Handle iOS 14+ limited access mode '
        'where user may only grant access to selected photos. {v2}',
    correctionMessage:
        'Check for PHAuthorizationStatus.limited and provide UI to '
        'modify selection.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if limited access is handled
    if (fileSource.contains('limited') ||
        fileSource.contains('PHAuthorizationStatus') ||
        fileSource.contains('presentLimitedLibraryPicker')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'pickImage' ||
          methodName == 'pickMultiImage' ||
          methodName == 'pickVideo') {
        reporter.atNode(node);
      }
    });
  }
}

// ============================================================================
// v2.3.17 - Additional iOS/macOS Platform Rules
// ============================================================================

/// Warns when iOS pasteboard access may trigger iOS 16+ notification.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosPasteboardPrivacyHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_pasteboard_privacy_handling',
    '[require_ios_pasteboard_privacy_handling] Clipboard access detected. On iOS 16+, users see a notification '
        'when apps read the clipboard. Only access after explicit user action. {v2}',
    correctionMessage:
        'Access clipboard only in response to user paste action.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target != null &&
          target.toSource() == 'Clipboard' &&
          methodName == 'getData') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when background refresh may need capability declaration.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireIosBackgroundRefreshDeclarationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_background_refresh_declaration',
    '[require_ios_background_refresh_declaration] Background task scheduling detected. Ensure UIBackgroundModes '
        'includes "fetch" in Info.plist for background refresh. {v2}',
    correctionMessage: 'Add UIBackgroundModes with "fetch" to Info.plist.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasReported = false;

    context.addMethodInvocation((MethodInvocation node) {
      if (hasReported) return;

      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (_backgroundPatterns.contains(methodName) ||
          (target != null && isExactTarget(target, _backgroundPatterns))) {
        reporter.atNode(node);
        hasReported = true;
      }
    });
  }
}

/// Warns when iOS 13+ Scene Delegate lifecycle may not be handled.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosBiometricFallbackRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosBiometricFallbackRule].
  RequireIosBiometricFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_biometric_fallback',
    '[require_ios_biometric_fallback] Biometric authentication detected. Ensure fallback authentication '
        '(passcode) is available for devices without biometrics. {v2}',
    correctionMessage:
        'Handle BiometricType.none and provide alternative login method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if fallback is handled
    if (fileSource.contains('canCheckBiometrics') ||
        fileSource.contains('BiometricType.none') ||
        fileSource.contains('passcode') ||
        fileSource.contains('fallback')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'authenticate' ||
          node.methodName.name == 'authenticateWithBiometrics') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when iOS app may send misleading push notifications.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Apple rejects apps that send push notifications unrelated to
/// the user's interests or that spam users.
class RequireIosAccessibilityLargeTextRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosAccessibilityLargeTextRule].
  RequireIosAccessibilityLargeTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_accessibility_large_text',
    '[require_ios_accessibility_large_text] Hardcoded font size may not respect iOS Dynamic Type. '
        'Use theme text styles for accessibility. {v2}',
    correctionMessage:
        'Use Theme.of(context).textTheme styles or apply '
        'MediaQuery.textScaleFactorOf(context).',
    severity: DiagnosticSeverity.INFO,
  );

  static final List<RegExp> _themeSourceRegex = [
    RegExp(r'\btextTheme\b'),
    RegExp(r'\bThemeData\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          final String currentSource = current.toSource();
          if (_themeSourceRegex.any((re) => re.hasMatch(currentSource))) {
            return; // Part of theme definition
          }
          current = current.parent;
        }

        reporter.atNode(node);
      }
    });
  }
}

/// Suggests using iOS context menus for touch-and-hold interactions.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosQuickNoteAwarenessRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosQuickNoteAwarenessRule].
  RequireIosQuickNoteAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_ios_quick_note_awareness',
    '[require_ios_quick_note_awareness] Document viewing detected. Consider implementing NSUserActivity '
        'for iOS Quick Note compatibility. {v2}',
    correctionMessage:
        'Set NSUserActivity with document context so users can link '
        'Quick Notes to your app content.',
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
        fileSource.contains('UserActivity')) {
      return;
    }

    // Only check for document-like screens
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      if (className.contains('document') ||
          className.contains('article') ||
          className.contains('viewer') ||
          className.contains('reader')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when keyboard height is hardcoded instead of using ViewInsets.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
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
class RequireIosVoiceoverGestureCompatibilityRule extends SaropaLintRule {
  /// Creates a new instance of [RequireIosVoiceoverGestureCompatibilityRule].
  RequireIosVoiceoverGestureCompatibilityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_ios_voiceover_gesture_compatibility',
    '[require_ios_voiceover_gesture_compatibility] Custom gesture without accessibility action. VoiceOver users may '
        'not be able to perform this action. {v2}',
    correctionMessage:
        'Wrap with Semantics and provide onDismiss, onScrollLeft, '
        'or other accessibility actions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

      reporter.atNode(node);
    });
  }
}
