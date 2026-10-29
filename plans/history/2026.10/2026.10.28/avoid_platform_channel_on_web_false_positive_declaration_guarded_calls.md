# BUG: `avoid_platform_channel_on_web` — flags the channel declaration although all calls are web-guarded

**Status: Open**

Created: 2026-10-28
Rule: `avoid_platform_channel_on_web`
File: `lib/src/rules/platforms/web_rules.dart` (line ~81)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

The rule reports `static const MethodChannel _channel = MethodChannel('saropa/haptics');`. Constructing a `MethodChannel` is harmless on web. Only invocations fail, and those are behind `!kIsWeb && (defaultTargetPlatform == ...)`.

---

## Attribution Evidence

```bash
grep -rn "'avoid_platform_channel_on_web'" lib/src/rules/
# lib/src/rules/platforms/web_rules.dart:81:    'avoid_platform_channel_on_web',
```

---

## Reproducer

```dart
abstract final class Haptics {
  static const MethodChannel _channel = MethodChannel('app/haptics'); // LINT — but should NOT lint (declaration only)

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  static Future<void> tick() async {
    if (!_supported) return;
    await _channel.invokeMethod<void>('tick');
  }
}
```

**Frequency:** Always for a channel field declaration.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on the declaration; flag only unguarded `invokeMethod` calls |
| **Actual** | `[avoid_platform_channel_on_web]` on the declaration |

---

## Suggested Fix

Report at `invokeMethod`/`invokeListMethod`/`invokeMapMethod` calls, not at the constructor. Skip calls dominated by `kIsWeb` checks, including through a same-class getter that contains `!kIsWeb`.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/system/haptics/saropa_haptics.dart:43`
