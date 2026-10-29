# BUG: `avoid_platform_channel_on_web` — flags `_channel?.invokeMethod` after `if (_channel == null) return` when the field is `kIsWeb ? null : MethodChannel(...)`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_platform_channel_on_web`
File: `lib/src/rules/platforms/web_rules.dart` (line ~63; invocation check 123-139; guard helpers 148-215)
Severity: False positive
Rule version: v4 | Since: unknown | Updated: 17.0.1-beta.2

Related (different case, closed): `plans/history/2026.10/2026.10.28/avoid_platform_channel_on_web_false_positive_declaration_guarded_calls.md`.

---

## Summary

The field is `static const MethodChannel? _channel = kIsWeb ? null : MethodChannel(...)`, so it is `null` on web. The method returns early with `if (_channel == null) { return null; }` before calling `_channel?.invokeMethod`. On web the call is unreachable. The rule still reports the `invokeMethod` call.

---

## Attribution Evidence

```bash
grep -rn "'avoid_platform_channel_on_web'" lib/src/rules/
# lib/src/rules/platforms/web_rules.dart:82:    'avoid_platform_channel_on_web',
```

**Rule class:** `AvoidPlatformChannelOnWebRule` (`web_rules.dart:63`), registered in `lib/saropa_lints.dart:1597`
**Diagnostic as seen in Problems panel:** `[avoid_platform_channel_on_web] MethodChannel throws MissingPluginException on web, crashing the application.` at 79:53 (source: saropa_lints)

---

## Reproducer

Standalone (needs the Flutter SDK for `package:flutter`). Real code: `lib/utils/device_home_screen_widget/device_home_screen_widget_path_utils.dart` lines 26-28 (field), 66-79 (guard and call) in the Saropa contacts app.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

abstract final class PathUtils {
  static const MethodChannel? _channel = kIsWeb ? null : MethodChannel('app/widget_paths');

  static Future<String?> containerPath() async {
    if (_channel == null) {
      return null; // on web _channel is always null, so we return here
    }

    return _channel?.invokeMethod<String>('getPath'); // LINT — but should NOT lint
  }
}

Future<void> main() async => print(await PathUtils.containerPath());
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (the call is unreachable on web) |
| **Actual** | `[avoid_platform_channel_on_web] MethodChannel throws MissingPluginException on web, crashing the application.` at 79:53 (`invokeMethod`) |

---

## AST Context

```
ClassDeclaration (PathUtils)
  └─ MethodDeclaration (containerPath)
      └─ BlockFunctionBody
          └─ Block
              ├─ IfStatement (_channel == null)      ← sibling guard, BinaryExpression condition
              └─ ReturnStatement
                  └─ MethodInvocation (_channel?.invokeMethod)   ← node reported here (methodName)
```

---

## Root Cause

`context.addMethodInvocation` (`web_rules.dart:123-139`) reports `invokeMethod` unless `_hasWebPlatformCheck(node)` (line 148) is true. `_hasWebPlatformCheck` accepts:

- an ancestor `IfStatement` whose condition mentions a `kIsWeb` getter/field (lines 150-156), but the guard here is a preceding sibling, not an ancestor;
- a preceding sibling guard through `_hasPrecedingPlatformGuard` (line 182), which accepts only `_isWebExitGuard` (a positive `kIsWeb` check) or `_isGetterExitGuard` (line 197).

`_isGetterExitGuard` requires the condition to be a `PrefixExpression` with `!` (line 199: `expr is! PrefixExpression || expr.operator.type != TokenType.BANG` returns false). The condition `_channel == null` is a `BinaryExpression`, so it is rejected even though `_mentionsWebGetter` (line 208) would find `kIsWeb` in the declaration of `_channel`.

---

## Why the code is correct

On web the field initializer yields `null`, the `== null` guard returns, and `invokeMethod` never runs. On other platforms the channel exists.

---

## Suggested Fix

In `_isGetterExitGuard` (line 197) also accept `X == null` where `X` is an identifier whose declaration mentions `kIsWeb` and the then-branch exits early (`_isEarlyExit`). Also accept the nullable-target form `X?.invokeMethod` when `X` is a field whose initializer is a `kIsWeb` conditional expression (the call is a no-op on web by construction).

---

## Fixture Gap

The fixture `example*/lib/platforms/avoid_platform_channel_on_web_fixture.dart` should include:

1. `static const MethodChannel? _c = kIsWeb ? null : MethodChannel('x');` with `if (_c == null) return null; return _c?.invokeMethod('m');` — expect NO lint.
2. Same field without the `kIsWeb` conditional and with `if (_c == null) return;` — expect LINT.
3. `if (_c != null) { _c.invokeMethod('m'); }` with the `kIsWeb` field — expect NO lint (ancestor form, already handled).

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (web_rules.dart differs from the repo source only by formatting at lines 216-218)
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/utils/device_home_screen_widget/device_home_screen_widget_path_utils.dart:79:53`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
