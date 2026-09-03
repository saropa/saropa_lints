# PROPOSAL: Prefer Intent Filter Export

**Status: Open**

Created: 2026-09-02

## Summary

Flags an Android `<intent-filter>`-bearing component (`<activity>`, `<service>`, `<receiver>`, `<provider>`) in `AndroidManifest.xml` that omits an explicit `android:exported` attribute, which is a mandatory declaration on API 31+ (Android 12) and an install-time manifest merge failure without it.

## Existing Coverage

Grepped `lib/src/rules/platforms/android_rules.dart` and `lib/src/android_manifest_utils.dart` for `android:exported` / `intent-filter` / `exported=` — no matches in either file. The existing `RequireAndroidManifestEntriesRule` (`require_android_manifest_entries`, line 27 of `android_rules.dart`) uses `AndroidManifestChecker.forFile(context.filePath)` to check for missing `<uses-permission>` entries corresponding to permission-gated API calls in Dart code (e.g. calling a camera API without `android.permission.CAMERA` declared) — a Dart-code-to-manifest cross-reference for *permissions*, not a manifest-internal structural check on component `<intent-filter>`/`exported` attributes.

**This is a genuine addition**, not covered by any existing rule:

- It requires parsing `AndroidManifest.xml` structurally (component + child `<intent-filter>` + sibling `android:exported` attribute), not cross-referencing against Dart source, so it is closer to a manifest-only structural lint than `require_android_manifest_entries`'s Dart-API-triggered pattern.
- The two other manifest-referencing rules found in `android_rules.dart` (`SCHEDULE_EXACT_ALARM` check around line 1064, `READ_MEDIA_VISUAL_USER_SELECTED` around line 1193) are also permission-presence checks via `AndroidManifestChecker`, not intent-filter/exported checks.

If this rule ships, it should reuse the existing `AndroidManifestChecker` / `android_manifest_utils.dart` XML-parsing infrastructure rather than adding a second manifest parser.

## Motivation

Since Android 12 (API 31), any `<activity>`, `<service>`, or `<receiver>` that declares an `<intent-filter>` MUST also explicitly declare `android:exported="true"` or `android:exported="false"` — Android no longer infers the value from the presence of an intent filter. A manifest missing this attribute on such a component fails to install or update on API 31+ devices/emulators, with a build/install-time error (`android:exported needs to be explicitly specified`) rather than a runtime crash. This is a total install blocker on the affected API level, not a soft warning, and is a frequent stumbling block when adding a new deep-link `<activity>` or a `BroadcastReceiver` for a plugin (FCM, share intents, deep links) without remembering the API 31 requirement — the app builds fine on older `compileSdkVersion` targets and only fails once the project bumps `targetSdkVersion`/`compileSdkVersion` to 31+.

## Detection / Behavior

Triggers on any `<activity>`, `<activity-alias>`, `<service>`, `<receiver>`, or `<provider>` element in `AndroidManifest.xml` that contains a child `<intent-filter>` element but has no `android:exported` attribute on the component element itself.

```xml
<!-- BAD: intent-filter present, android:exported omitted — fails to install on API 31+ -->
<activity android:name=".DeepLinkActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" />
    </intent-filter>
</activity>

<!-- GOOD: explicit android:exported declared -->
<activity
    android:name=".DeepLinkActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" />
    </intent-filter>
</activity>
```

## Quick Fix

Add `android:exported="true"` to the flagged component element as the default suggestion (since a component with an `<intent-filter>` is almost always meant to be externally reachable — that is the point of declaring the filter), with the correction message flagging that `false` may be more correct for filters scoped to internal use (e.g. an implicit-intent receiver not meant for other apps) and prompting a manual check either way.

## Alternatives Considered

Extending `require_android_manifest_entries`/`AndroidManifestChecker` with an intent-filter/exported check as a second detection mode inside the same rule was considered, since both rules parse the same manifest file. Kept separate in this proposal because the existing rule's trigger model is Dart-API-usage-driven (only checks the manifest when specific Dart code is present) whereas this check is unconditional on manifest structure alone — a different trigger shape that fits a standalone rule more naturally.
