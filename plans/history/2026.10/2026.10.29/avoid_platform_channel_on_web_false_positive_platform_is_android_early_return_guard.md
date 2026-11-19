# BUG: `avoid_platform_channel_on_web` — flags `_channel.invokeMethod` after `if (!Platform.isAndroid) return null;`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_platform_channel_on_web`
File: `lib/src/rules/platforms/web_rules.dart` (class at line 63)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`_hasPrecedingPlatformGuard` accepts only `kIsWeb` (or a getter that mentions `kIsWeb`) as an early-exit guard. A platform early return such as `if (!Platform.isAndroid) return null;` is not recognized, although the same rule treats `Platform.` in an enclosing `if` condition as a guard.

---

## Attribution Evidence

```bash
grep -rn "'avoid_platform_channel_on_web'" lib/src/rules/
# lib/src/rules/platforms/web_rules.dart:82:    'avoid_platform_channel_on_web',
```

**Rule class:** `AvoidPlatformChannelOnWebRule` (`lib/src/rules/platforms/web_rules.dart:63`)
**Diagnostic as seen in Problems panel:** `[avoid_platform_channel_on_web] MethodChannel throws MissingPluginException on web, crashing the application. {v4} (line 29, col 49)` (source: saropa_lints)

---

## Reproducer

Standalone (needs the Flutter SDK). Real code: `lib/service/location/network_country_channel.dart` lines 14-30 (`NetworkCountryChannel.getNetworkCountry`). The app has no web target (no `web/` folder).

```dart
import 'dart:io';

import 'package:flutter/services.dart';

abstract final class NetworkCountry {
  static const MethodChannel _channel = MethodChannel('app/network_country');

  static Future<String?> get() async {
    if (!Platform.isAndroid) {
      return null; // Android-only bridge: every other platform exits here
    }

    return _channel.invokeMethod<String>('getNetworkCountry'); // LINT — but should NOT lint
  }
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the call is reachable only when `Platform.isAndroid` is true |
| **Actual** | `[avoid_platform_channel_on_web]` on `invokeMethod` |

---

## AST Context

`ClassDeclaration(NetworkCountryChannel)` > `MethodDeclaration(getNetworkCountry, async)` > `BlockFunctionBody` > `Block` > [`IfStatement(!Platform.isAndroid)` > `Block` > `ReturnStatement(null)`, `TryStatement` > `Block` > `VariableDeclarationStatement` > `AwaitExpression` > `MethodInvocation(invokeMethod<String>)` (reported, target `SimpleIdentifier(_channel)`, a static field)].

---

## Root Cause

`web_rules.dart` second callback (lines 118-138): the `invokeMethod` target is a static field, so it is not exempt as a local; `_hasWebPlatformCheck(node)` (`_hasWebPlatformCheck`, called at lines 115 and 137) then walks the ancestors. `IfStatement` and `ConditionalExpression` ancestors use `_containsPlatformCheck`, which accepts `kIsWeb`, `Platform.` and `defaultTargetPlatform`. The sibling-statement path `_hasPrecedingPlatformGuard` (line 182) only accepts `_isWebExitGuard` (requires the identifier `kIsWeb` with positive polarity) or `_isGetterExitGuard` (negated getter that mentions `kIsWeb`). `!Platform.isAndroid` followed by `return` matches neither, so the early exit is not seen as a guard. The two paths disagree on what counts as a platform check.

---

## Why the code is correct

After `if (!Platform.isAndroid) return null;` no non-Android platform, web included, reaches the channel call. The channel is therefore only invoked on Android. (`Platform` from `dart:io` is not usable on web at all, so the guard cannot let a web run reach the call.)

## Affected project locations

- `lib/service/location/network_country_channel.dart:29`

---

## Suggested Fix

Make `_hasPrecedingPlatformGuard` use the same `_containsPlatformCheck` vocabulary as the enclosing-`if` path: a preceding `if (cond) { ...; return/throw }` whose condition mentions `kIsWeb`, `Platform.` or `defaultTargetPlatform` with the exit polarity that excludes web (`!Platform.isAndroid`, `!Platform.isIOS`, `kIsWeb`, `defaultTargetPlatform != TargetPlatform.android`) counts as a guard.

---

## Fixture Gap

- GOOD: `if (!Platform.isAndroid) return null; await _channel.invokeMethod(...)`
- GOOD: `if (defaultTargetPlatform != TargetPlatform.android) return; await _channel.invokeMethod(...)`
- BAD: `await _channel.invokeMethod(...)` with no guard
- BAD: `if (Platform.isAndroid) return; await _channel.invokeMethod(...)` (wrong polarity: web still reaches the call, once `Platform` is replaced by a web-safe check)

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
