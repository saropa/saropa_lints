# Apple Platform Rules (iOS & macOS)

This guide explains how saropa_lints helps you build Flutter apps that follow Apple platform best practices, pass App Store review, and provide a native user experience on iOS and macOS.

## Why This Matters

Apple has strict requirements for apps distributed through the App Store. Apps that violate these requirements are **rejected during review**, often with vague feedback that takes multiple resubmissions to resolve.

Common rejection reasons that saropa_lints helps prevent:

| Rejection Reason | What Happens | Rule |
|-----------------|--------------|------|
| Missing Info.plist descriptions | App crashes or is rejected for camera/location access | `require_ios_permission_description` |
| HTTP connections blocked | Network calls fail silently due to App Transport Security | `require_https_for_ios` |
| Missing Privacy Manifest (iOS 17+) | App rejected for using APIs without declared reasons | `require_ios_privacy_manifest` |
| Content hidden by notch/Dynamic Island | Poor user experience, potential rejection | `prefer_ios_safe_area` |
| Hardcoded device dimensions | UI breaks on new device releases | `avoid_ios_hardcoded_status_bar` |

## Implemented Rules

### iOS Platform Rules

#### prefer_ios_safe_area

Warns when Scaffold body is not wrapped in SafeArea. Content may be hidden by iOS notch or Dynamic Island.

```dart
// BAD - content may be hidden behind notch
Scaffold(
  body: Column(
    children: [
      Text('Header'), // Hidden on iPhone X+
    ],
  ),
)

// GOOD - SafeArea prevents overlap
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        Text('Header'),
      ],
    ),
  ),
)
```

**Tier**: Recommended | **Severity**: INFO

**Note**: This rule does not flag ListView, CustomScrollView, GridView, PageView, or TabBarView as these handle safe area internally via slivers.

#### avoid_ios_hardcoded_status_bar

Warns when hardcoded status bar heights are used. iOS status bar height varies by device:

| Device | Height |
|--------|--------|
| iPhone 8 and earlier | 20pt |
| iPhone X, XS, 11 Pro | 44pt |
| iPhone 12, 13, 14 | 47pt |
| iPhone 14 Pro, 15 Pro (Dynamic Island) | 59pt |

```dart
// BAD - only works on one device type
Padding(
  padding: EdgeInsets.only(top: 44),
)

SizedBox(height: 59)

// GOOD - adapts to any device
Padding(
  padding: EdgeInsets.only(
    top: MediaQuery.of(context).padding.top,
  ),
)
```

**Tier**: Recommended | **Severity**: WARNING

#### prefer_ios_haptic_feedback

Suggests adding haptic feedback for important button interactions. iOS devices have the Taptic Engine which provides tactile confirmation of actions.

```dart
// GOOD - provides tactile feedback
ElevatedButton(
  onPressed: () {
    HapticFeedback.mediumImpact();
    // ... action
  },
  child: Text('Submit'),
)
```

**Tier**: Comprehensive | **Severity**: INFO

Available feedback types:
- `HapticFeedback.lightImpact()` - Subtle feedback
- `HapticFeedback.mediumImpact()` - Standard feedback
- `HapticFeedback.heavyImpact()` - Strong feedback
- `HapticFeedback.selectionClick()` - Selection changes
- `HapticFeedback.vibrate()` - Error/warning

#### require_ios_platform_check

Warns when iOS-specific MethodChannel calls lack Platform.isIOS guard.

```dart
// BAD - crashes on non-iOS platforms
await MethodChannel('com.example/native').invokeMethod('iosOnly');

// GOOD - guarded for iOS
if (Platform.isIOS) {
  await MethodChannel('com.example/native').invokeMethod('iosOnly');
}
```

**Tier**: Recommended | **Severity**: WARNING

#### avoid_ios_background_fetch_abuse

Warns when Future.delayed exceeds iOS 30-second background limit. iOS terminates apps that exceed background execution time.

```dart
// BAD - iOS will kill the app
await Future.delayed(Duration(minutes: 5));

// GOOD - within iOS limits
await Future.delayed(Duration(seconds: 25));
```

**Tier**: Recommended | **Severity**: WARNING

### macOS Platform Rules

#### prefer_macos_menu_bar_integration

Suggests using PlatformMenuBar for native macOS menu integration. macOS users expect standard menu bar items.

```dart
// GOOD - native macOS menu bar
PlatformMenuBar(
  menus: [
    PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItem(
          label: 'New',
          shortcut: SingleActivator(LogicalKeyboardKey.keyN, meta: true),
          onSelected: () { /* ... */ },
        ),
      ],
    ),
  ],
  child: MyApp(),
)
```

**Tier**: Comprehensive | **Severity**: INFO

#### prefer_macos_keyboard_shortcuts

Suggests implementing standard macOS keyboard shortcuts. macOS users expect Cmd+S, Cmd+Z, Cmd+C, etc.

```dart
// GOOD - standard macOS shortcuts
Shortcuts(
  shortcuts: {
    SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true): UndoIntent(),
  },
  child: MyApp(),
)
```

**Tier**: Comprehensive | **Severity**: INFO

#### require_macos_window_size_constraints

Warns when macOS apps lack minimum/maximum window size constraints. Desktop apps should have sensible size limits.

```dart
// GOOD - constrained window sizes
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(Size(400, 300));
  await windowManager.setMaximumSize(Size(1920, 1080));

  runApp(MyApp());
}
```

**Tier**: Recommended | **Severity**: INFO

### Cross-Platform Apple Rules

#### require_method_channel_error_handling

Warns when MethodChannel.invokeMethod lacks try-catch for PlatformException. Native calls can fail and must be handled.

```dart
// BAD - crashes if native code fails
final result = await channel.invokeMethod('getData');

// GOOD - handles platform errors
try {
  final result = await channel.invokeMethod('getData');
} on PlatformException catch (e) {
  debugPrint('Platform error: ${e.message}');
}
```

**Tier**: Essential | **Severity**: WARNING

**Quick Fix**: Wrap with try-catch

#### require_https_for_ios

Warns when HTTP URLs are used. iOS App Transport Security (ATS) blocks non-HTTPS connections by default.

```dart
// BAD - blocked by ATS
final response = await http.get(Uri.parse('http://api.example.com/data'));

// GOOD - HTTPS required
final response = await http.get(Uri.parse('https://api.example.com/data'));
```

**Tier**: Essential | **Severity**: WARNING

**Quick Fix**: Change to HTTPS

If you absolutely must use HTTP (e.g., local development), add an ATS exception in your Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>localhost</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
  </dict>
</dict>
```

#### require_ios_permission_description

Warns when permission-requiring APIs are used without Info.plist entries. Apps without proper usage descriptions are **rejected by App Store review**.

| API | Required Info.plist Key |
|-----|------------------------|
| Camera | NSCameraUsageDescription |
| Photo Library | NSPhotoLibraryUsageDescription |
| Location | NSLocationWhenInUseUsageDescription |
| Microphone | NSMicrophoneUsageDescription |
| Contacts | NSContactsUsageDescription |
| Calendar | NSCalendarsUsageDescription |
| Bluetooth | NSBluetoothAlwaysUsageDescription |

```dart
// Triggers warning - ensure Info.plist has NSCameraUsageDescription
final image = await ImagePicker().pickImage(source: ImageSource.camera);
```

**Tier**: Essential | **Severity**: WARNING

#### require_ios_privacy_manifest

Warns when APIs requiring iOS 17+ Privacy Manifest entries are used. Apple requires apps to declare why they use certain APIs.

APIs that require Privacy Manifest entries:
- `UserDefaults` / `NSUserDefaults` (via MethodChannel)
- `ProcessInfo.processInfo` (for system uptime)
- File timestamp APIs
- Disk space APIs

```dart
// Triggers reminder to add Privacy Manifest entry
await channel.invokeMethod('getUserDefaults', {'key': 'value'});
```

**Tier**: Essential | **Severity**: WARNING

See Apple's [Privacy Manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) for the complete list of required reason APIs.

#### require_universal_link_validation

Reminds to validate iOS Universal Links server configuration when deep link routes are detected.

```dart
// Triggers reminder to verify apple-app-site-association
GoRouter(
  routes: [
    GoRoute(
      path: '/product/:id',  // Deep link route
      builder: (context, state) => ProductScreen(),
    ),
  ],
)
```

**Tier**: Recommended | **Severity**: INFO

Universal Links require:
1. `apple-app-site-association` file on your server
2. Associated Domains entitlement in Xcode
3. Proper SSL certificate (no self-signed)

#### prefer_cupertino_for_ios

Suggests using Cupertino widgets over Material widgets in Platform.isIOS blocks.

```dart
// OK but not native feeling
if (Platform.isIOS) {
  return MaterialButton(...);
}

// BETTER - native iOS look and feel
if (Platform.isIOS) {
  return CupertinoButton(...);
}
```

**Tier**: Comprehensive | **Severity**: INFO

## Tier Assignments

| Rule | Tier | Rationale |
|------|------|-----------|
| `require_method_channel_error_handling` | Essential | Unhandled exceptions crash the app |
| `require_https_for_ios` | Essential | HTTP is blocked by default, causes silent failures |
| `require_ios_permission_description` | Essential | App Store rejection without proper Info.plist |
| `require_ios_privacy_manifest` | Essential | App Store rejection on iOS 17+ |
| `prefer_ios_safe_area` | Recommended | UI quality issue, not blocking |
| `avoid_ios_hardcoded_status_bar` | Recommended | Breaks on new devices |
| `require_ios_platform_check` | Recommended | Cross-platform safety |
| `avoid_ios_background_fetch_abuse` | Recommended | iOS terminates violating apps |
| `require_universal_link_validation` | Recommended | Deep links silently fail without server config |
| `require_macos_window_size_constraints` | Recommended | Desktop UX expectation |
| `prefer_ios_haptic_feedback` | Comprehensive | Enhancement, not required |
| `prefer_macos_menu_bar_integration` | Comprehensive | Enhancement, not required |
| `prefer_macos_keyboard_shortcuts` | Comprehensive | Enhancement, not required |
| `prefer_cupertino_for_ios` | Comprehensive | Style preference |

## v2.4.0 Additional Rules

v2.4.0 adds 28 additional iOS/macOS rules covering:

**Background Processing (5 rules)**
- `avoid_long_running_isolates` - iOS terminates isolates after 30 seconds
- `require_workmanager_for_background` - Use workmanager for reliable background tasks
- `require_notification_for_long_tasks` - Show progress for long operations
- `prefer_background_sync` - Use BGTaskScheduler for sync
- `require_sync_error_recovery` - Retry failed syncs with backoff

**Notification Rules (2 rules)**
- `prefer_delayed_permission_prompt` - Don't request permissions on launch
- `avoid_notification_spam` - Batch notifications properly

**In-App Purchase Rules (2 rules)**
- `require_purchase_verification` - Server-side receipt verification
- `require_purchase_restoration` - App Store requires restore button

**iOS Platform Enhancement (16 rules)**
- `avoid_ios_wifi_only_assumption`, `require_ios_low_power_mode_handling`, `require_ios_accessibility_large_text`, `prefer_ios_context_menu`, `require_ios_quick_note_awareness`, `avoid_ios_hardcoded_keyboard_height`, `require_ios_multitasking_support`, `prefer_ios_spotlight_indexing`, `require_ios_data_protection`, `avoid_ios_battery_drain_patterns`, `require_ios_entitlements`, `require_ios_launch_storyboard`, `require_ios_version_check`, `require_ios_focus_mode_awareness`, `prefer_ios_handoff_support`, `require_ios_voiceover_gesture_compatibility`

**macOS Platform Enhancement (5 rules)**
- `require_macos_sandbox_exceptions`, `avoid_macos_hardened_runtime_violations`, `require_macos_app_transport_security`, `require_macos_notarization_ready`, `require_macos_entitlements`

See [ROADMAP.md](https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md) for additional planned rules.

## FFI/Native Interop

When using `dart:ffi` for iOS/macOS native code integration, the Dart analyzer provides built-in diagnostics:

| Diagnostic | Description |
|------------|-------------|
| `ffi_native_must_be_external` | Functions with `@Native` must be `external` |
| `ffi_native_invalid_multiple_annotations` | Only one `@Native` annotation allowed |
| `native_function_missing_type` | Type hints required on `@Native` |
| `native_field_not_static` | Native fields must be static |

These are automatically enabled when using `dart:ffi`.

## Out of Scope: Commercial Product Recommendations

saropa_lints intentionally does **not** recommend specific commercial products or services. While some third-party SDKs can simplify complex tasks like in-app purchases (IAP), subscription management, or analytics, recommending specific vendors is outside the scope of a lint package.

**Examples of products NOT recommended by these rules:**
- IAP SDKs (RevenueCat, Adapty, Qonversion, Purchasely, etc.)
- Analytics platforms (Amplitude, Mixpanel, Segment, etc.)
- Crash reporting services (beyond Firebase Crashlytics which is free-tier)
- Push notification services

The rules focus on **correct usage patterns** and **platform requirements**, not vendor selection. Teams should evaluate commercial products based on their own requirements, pricing, and support needs.

## Related Resources

- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)

---

## Appendix: Unimplementable Rules (Static Analysis Limitations)

The following Apple platform requirements **cannot be detected by static Dart analysis** because they involve Xcode project configuration, native code, or runtime behavior that exists outside the Dart codebase. These are documented here for awareness and must be verified manually or through other tooling.

### Info.plist and Entitlements Validation

| Requirement | Why It Can't Be Detected |
|-------------|-------------------------|
| **Missing Info.plist keys** | Info.plist is an XML file in the iOS/macOS project folder (`ios/Runner/Info.plist`). Dart analyzers cannot read non-Dart files. We can warn when APIs that *typically* need permissions are used, but cannot verify the actual Info.plist content. |
| **Incorrect entitlements** | Entitlements files (`.entitlements`) are in the Xcode project. The Dart analyzer has no access to Xcode project structure. |
| **Provisioning profile mismatches** | Provisioning profiles are binary files managed by Xcode and Apple Developer Portal. Not accessible to static analysis. |
| **App Store Connect configuration** | App privacy declarations, age ratings, and export compliance are configured in App Store Connect, not in code. |

### Xcode Project Configuration

| Requirement | Why It Can't Be Detected |
|-------------|-------------------------|
| **Capability enabling** | Push Notifications, Sign in with Apple, HealthKit, etc. are enabled in Xcode's "Signing & Capabilities" tab. This modifies `.pbxproj` files which are not Dart. |
| **Build settings** | Minimum deployment target, Swift version, architectures, and other build settings are in Xcode project files. |
| **Widget Extension targets** | Whether a Widget Extension target exists is determined by Xcode project structure, not Dart code. |
| **Watch app targets** | WatchOS companion apps are separate Xcode targets with their own Info.plist and entitlements. |
| **App Extensions** | Share extensions, Today extensions, Notification extensions are Xcode targets, not detectable from Dart. |

### Native Code and Bridging

| Requirement | Why It Can't Be Detected |
|-------------|-------------------------|
| **Objective-C/Swift implementation** | Native iOS code implementing MethodChannel handlers is in `.m`, `.swift` files. Dart analyzer only sees Dart. |
| **CocoaPods/SPM dependencies** | Native dependencies in `Podfile` or `Package.swift` are not visible to Dart analysis. |
| **Framework linking** | Whether system frameworks (HealthKit.framework, etc.) are linked is in Xcode build phases. |
| **Bridging headers** | Swift-Objective-C bridging configuration is in Xcode project settings. |

### Runtime and Environment

| Requirement | Why It Can't Be Detected |
|-------------|-------------------------|
| **Server-side configuration** | Universal Links require `apple-app-site-association` file on your web server. Not in the app codebase. |
| **APNs certificate/key** | Push notification credentials are configured in Apple Developer Console and backend servers. |
| **App Store review guidelines compliance** | Many guidelines (like review prompt frequency) are behavioral and depend on runtime state that can't be statically analyzed. |
| **Notarization requirements** | Whether an app will pass notarization depends on code signing, entitlements, and runtime behavior that the Dart analyzer cannot evaluate. |

### Cross-File and Multi-Project Analysis

| Requirement | Why It Can't Be Detected |
|-------------|-------------------------|
| **Permission request before use** | Verifying that permission is requested *before* using protected APIs requires cross-file control flow analysis across potentially many files. Our rules use heuristics (checking if file contains both patterns) but cannot guarantee ordering. |
| **Initialization before access** | Rules like "Hive must be initialized before opening box" require understanding execution order across files, which static single-file analysis cannot guarantee. |
| **Complete App Groups setup** | App Groups require configuration in both the main app AND extensions, across different Xcode targets. |

### What We Do Instead

For issues we cannot detect directly, saropa_lints provides:

1. **Reminder rules**: When we detect usage patterns (e.g., HealthKit APIs), we remind developers about related requirements (e.g., `require_ios_healthkit_authorization`).

2. **Documentation**: Each rule's doc comments explain the full setup required, even if we can only detect part of it.

3. **Best practices**: We catch common mistakes that *can* be detected statically, reducing the debugging surface.

4. **Pattern matching**: We use heuristics to identify likely issues, accepting some false positives in exchange for catching real problems.

### Recommended Complementary Tools

For complete Apple platform compliance, use these tools alongside saropa_lints:

<!-- cspell:ignore xcrun altool -->
| Tool | What It Checks |
|------|----------------|
| **Xcode Analyzer** | Static analysis of Swift/Objective-C code |
| **fastlane** | Automated certificate, provisioning, and deployment checks |
| **App Store Connect API** | Validate app metadata before submission |
| **Firebase App Distribution** | Test on real devices before App Store submission |
| **Transporter** | Apple's tool for validating app packages |
| **xcrun altool** | Notarization and validation for macOS apps |

### Manual Checklist

Before submitting to the App Store, manually verify:

- [ ] All required Info.plist keys are present with user-facing descriptions
- [ ] Entitlements match the capabilities your app uses
- [ ] Privacy Manifest is complete for iOS 17+
- [ ] Universal Links server configuration is correct
- [ ] APNs certificate/key is valid and not expired
- [ ] Provisioning profiles include all required capabilities
- [ ] App passes local notarization (macOS)
- [ ] All third-party SDKs are updated and compliant
