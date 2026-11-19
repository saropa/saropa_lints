# BUG: `avoid_platform_channel_on_web` — `if (!isSupported) return;` is not recognised when `isSupported` is a cache flag only ever set true after a `kIsWeb` check

**Status: Fixed** (2026-10-29): `_mentionsWebGetter` now accepts a private flag whose every non-false assignment follows a kIsWeb-guarded early exit; scoped to the enclosing class. Resolved scan confirmed the guarded call no longer lints and unguarded flags still lint.

Created: 2026-10-29
Rule: `avoid_platform_channel_on_web`
File: `lib/src/rules/platforms/web_rules.dart` (`_isGetterExitGuard` ~248, `_mentionsWebGetter` ~259)
Severity: False positive
Found in: contacts app `lib/utils/system/haptics/saropa_haptics.dart` lines 121, 145, 189, 224 (same pattern; lines 78, 86, 107 and
`utils/device_home_screen_widget/device_home_screen_widget_path_utils.dart:79` are already covered by the beta.4 fixes
`_isPlatformSupported` getter guard and `_channel == null` guard, so they should vanish once beta.4 is actually resolved).

## Reproducer

```dart
class Haptics {
  static const MethodChannel _channel = MethodChannel('x/haptics');
  static bool? _isSupported; // only ever assigned inside ensureInitialized()
  static bool get _isPlatformSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // Public sync accessor: the getter body does NOT mention kIsWeb.
  static bool get isSupported => _isSupported ?? false;

  static Future<void> ensureInitialized() async {
    if (!_isPlatformSupported) { _isSupported = false; return; } // web exits here
    _isSupported = await _channel.invokeMethod<bool>('canVibrate') ?? false;
  }

  static Future<void> vibrate() async {
    if (!isSupported) return;                 // false on web, always
    await _channel.invokeMethod<void>('buzz'); // LINT — should NOT lint
  }
}
```

## Why it is a false positive

`_isSupported` is written in exactly one place, behind `if (!_isPlatformSupported) { _isSupported = false; return; }`, so on web
it is never `true` and `isSupported` is always `false`. The early exit in `vibrate()` therefore always fires on web and the channel
call is unreachable there. The rule only accepts a guard whose getter/field declaration mentions `kIsWeb` itself, so the guard is
missed because the web check lives one hop away.

## Suggested fix

In `_mentionsWebGetter`, follow one level of indirection: when the named getter's body (or field) references another
same-unit getter or field, also scan that declaration for `kIsWeb`; additionally, for a private field referenced by the getter, treat
it as web-safe when every assignment of a non-`false` value in the unit sits after an early exit on a web-guarded getter/`kIsWeb`.
A cheaper first step is the one-hop token scan only; it covers the common "public sync flag over a guarded private field" shape.
Keep reporting unguarded calls (for example `vibrateRaw` at line 163 of the same file, which deliberately skips the guard for a
background isolate and is a true positive by the rule's own definition; the project suppresses or accepts it).

## Verification

Add fixture cases: (1) the reproducer above expects no lint; (2) same class without the `_isPlatformSupported` assignment guard
expects a lint; (3) `isSupported` getter returning a field never assigned `true` behind a guard expects a lint.
