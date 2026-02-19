# Task: `require_firebase_app_check_production`

## Summary
- **Rule Name**: `require_firebase_app_check_production`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.29 Firebase Advanced Rules

## Problem Statement

Firebase App Check verifies that API calls to Firebase services come from **your legitimate app** (not scripts, emulators, or other apps). Without App Check:

1. **API abuse**: Anyone can use your Firebase project's configuration to make calls (your API key is not a secret)
2. **Quota exhaustion**: Malicious actors can exhaust your Firebase quotas
3. **Data exfiltration**: If Firestore rules have any weaknesses, an attacker can exploit them at scale
4. **Cost explosion**: Firebase bills by usage — unbounded access = unbounded costs

App Check uses platform attestation (Play Integrity on Android, Device Check / App Attest on iOS) to verify the request comes from a real, unmodified instance of your app.

```dart
// Missing App Check initialization:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // ← No FirebaseAppCheck.instance.activate() → no App Check!
  runApp(const MyApp());
}
```

## Description (from ROADMAP)

> Enable App Check for production. Detect production without App Check.

## Trigger Conditions

1. `Firebase.initializeApp()` called without `FirebaseAppCheck.instance.activate()` nearby
2. Project uses Firebase (detected via `firebase_core` package) but has no `firebase_app_check` package

**Phase 1 (Conservative)**: Flag if `firebase_core` is used but `firebase_app_check` package is NOT in the project.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isFirebaseInitializeApp(node)) return;
  if (_projectHasAppCheck(context)) return; // firebase_app_check detected
  reporter.atNode(node, code);
});
```

`_isFirebaseInitializeApp`: check method name `initializeApp` on `Firebase`.
`_projectHasAppCheck`: `ProjectContext.usesPackage('firebase_app_check')`.

**Alternative**: Project-level check — if `firebase_core` is used but `firebase_app_check` is absent, add a project-level warning (once per project, not per call).

## Code Examples

### Bad (Should trigger)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ← trigger: Firebase initialized but no App Check activation
  runApp(const MyApp());
}
```

### Good (Should NOT trigger)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );

  runApp(const MyApp());
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Debug mode with `DebugProvider` | **Suppress** — debug App Check is fine | |
| Test files | **Suppress** | |
| `firebase_app_check` in pubspec but not activated in code | **Trigger** — package present but not used | |
| Non-production app (dev flavor) | **Complex** — can't detect flavor at lint time | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Firebase.initializeApp()` with `firebase_core` but no `firebase_app_check` → 1 lint

### Non-Violations
1. `firebase_app_check` package in pubspec + `FirebaseAppCheck.instance.activate()` → no lint
2. Test file → no lint

## Quick Fix

No automated fix — App Check requires platform-specific configuration (Play Integrity, DeviceCheck registration). Suggest documentation link to Firebase App Check setup guide.

## Notes & Issues

1. **firebase_core-only**: Only fire if `ProjectContext.usesPackage('firebase_core')`.
2. **Package presence is not activation**: Having `firebase_app_check` in pubspec but not calling `activate()` is still a bug. Phase 2 should check for the `activate()` call.
3. **DebugProvider**: In development, `kDebugProvider` or `DebugProvider` can be used with App Check — these don't enforce real attestation but allow App Check to be configured and tested. Detect these as acceptable for debug builds.
4. **OWASP**: Maps to **M1: Improper Platform Usage** — not using available platform security features.
5. **Cost impact**: Without App Check, Firebase usage-based billing is exposed to abuse. For production apps, this is a financial risk as well as a security risk.
6. **App Check enforcement**: App Check can be in `debug` mode (not enforced) or `enforced` mode (required). The Firebase console must also be configured to enforce App Check. The Dart code is only half the story.
7. **App Check + Emulator**: Firebase Emulator doesn't need App Check. The DebugProvider allows local testing. Ensure emulator configurations are suppressed.
