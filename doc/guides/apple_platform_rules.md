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

## Planned Rules

The following iOS/macOS rules are planned for future releases:

| Rule | Description |
|------|-------------|
| `require_apple_sign_in` | Apps with third-party login must offer Sign in with Apple |
| `require_ios_entitlements` | Detect feature usage without matching Xcode entitlements |
| `require_macos_entitlements` | macOS sandboxed apps require entitlements for network, file, camera |
| `avoid_macos_hardened_runtime_violations` | Code injection and unsigned libraries block notarization |
| `require_ios_launch_storyboard` | iOS apps without LaunchScreen.storyboard are rejected |

See [ROADMAP.md](https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md) for the complete list of planned rules.

## FFI/Native Interop

When using `dart:ffi` for iOS/macOS native code integration, the Dart analyzer provides built-in diagnostics:

| Diagnostic | Description |
|------------|-------------|
| `ffi_native_must_be_external` | Functions with `@Native` must be `external` |
| `ffi_native_invalid_multiple_annotations` | Only one `@Native` annotation allowed |
| `native_function_missing_type` | Type hints required on `@Native` |
| `native_field_not_static` | Native fields must be static |

These are automatically enabled when using `dart:ffi`.

## Related Resources

- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
- [macOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
