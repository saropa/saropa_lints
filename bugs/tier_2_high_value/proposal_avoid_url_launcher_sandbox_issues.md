# PROPOSAL: Avoid Url Launcher Sandbox Issues

**Status: Open**

Created: 2026-09-02

## Summary

Flags `launchUrl` calls using a scheme or `LaunchMode` that breaks under platform sandboxing (e.g. custom URL schemes on iOS without an `LSApplicationQueriesSchemes` entry, or `mailto:`/`tel:` links without the corresponding manifest/plist declaration), where the call fails silently at runtime instead of at build time.

## Existing Coverage

`lib/src/rules/packages/url_launcher_rules.dart` has `RequireUrlLauncherModeRule` (requires an explicit `LaunchMode` for cross-platform consistency), `RequireUrlLauncherCanLaunchCheckRule` (requires a `canLaunchUrl` guard), and `PreferUrlLauncherFallbackRule`. None of these cross-reference the app's `Info.plist`/`AndroidManifest.xml` to check whether the scheme being launched is actually declared — this is a genuine extension: it catches the sandbox/manifest-declaration gap the existing rules do not inspect.

## Motivation

iOS requires every custom URL scheme an app intends to query or open (via `canOpenURL`/`launchUrl`) to be listed in `LSApplicationQueriesSchemes` in `Info.plist`; without it, `canLaunchUrl` silently returns `false` and `launchUrl` fails, even though the code compiles and looks correct. The same class of failure occurs on Android when a manifest `<queries>` block omits the target package/intent for API 30+. Because the failure is silent (no exception, just a no-op or a caught `false`), it typically surfaces only in production or store-review testing, on the specific OS versions that enforce the restriction — expensive to diagnose without static help.

## Detection / Behavior

Cross-references `launchUrl`/`canLaunchUrl` call sites that use a non-`http(s)` scheme (`mailto:`, `tel:`, `sms:`, a custom app scheme) against the project's `ios/Runner/Info.plist` (`LSApplicationQueriesSchemes`) and `android/app/src/main/AndroidManifest.xml` (`<queries>`), flagging schemes used in code but not declared in either manifest.

```dart
// Bad (scheme 'myapp://' used but not declared in Info.plist LSApplicationQueriesSchemes):
await launchUrl(Uri.parse('myapp://open-profile')); // LINT: scheme 'myapp' not declared for iOS querying; canLaunchUrl will silently return false

// Good — Info.plist declares:
// <key>LSApplicationQueriesSchemes</key>
// <array><string>myapp</string></array>
await launchUrl(Uri.parse('myapp://open-profile'));
```

## Security Mapping

OWASP Mobile M8: Security Misconfiguration (missing platform manifest declaration causes a security/availability-relevant feature — deep link or external-app handoff — to fail without a build-time signal).

## Quick Fix

Add the missing scheme entry to `Info.plist` (`LSApplicationQueriesSchemes`) and/or `AndroidManifest.xml` (`<queries>`) automatically, when the file exists and the fix can insert the entry without disturbing unrelated plist/manifest structure.

## Alternatives Considered

Limiting the rule to iOS `Info.plist` only was considered, since the `LSApplicationQueriesSchemes` requirement is the more common source of silent failure; Android's `<queries>` restriction (API 30+ package visibility) was kept in scope because it fails the same way (silent, review-time-only) and the manifest-cross-reference machinery is shared.
