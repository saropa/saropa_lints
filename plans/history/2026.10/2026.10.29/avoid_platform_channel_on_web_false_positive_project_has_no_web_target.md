# BUG: `avoid_platform_channel_on_web` — flags channel invocations in a project that has no web platform

**Status: Open**

Created: 2026-10-29
Rule: `avoid_platform_channel_on_web`
File: `lib/src/rules/platforms/web_rules.dart` (line ~123-138)
Severity: False positive
Rule version: v4 | Since: v2.0.0 | Updated: 17.0.1-beta.3 (project pins 17.0.1-beta.2)

---

## Summary

The rule reports every `invokeMethod` on a `MethodChannel` field that has no `kIsWeb` guard. The project has only `android/` and `ios/` platform folders (no `web/`). The code can never run on web, so the rule's premise (web build crashes) does not apply.

---

## Attribution Evidence

```bash
grep -rn "'avoid_platform_channel_on_web'" lib/src/rules/
# lib/src/rules/platforms/web_rules.dart:82:    'avoid_platform_channel_on_web',
```

**Emitter registration:** `lib/saropa_lints.dart:1597` (`AvoidPlatformChannelOnWebRule.new`)
**Rule class:** `AvoidPlatformChannelOnWebRule` (`web_rules.dart:63`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

Related, different pattern (channel declaration, already handled): `plans/history/2026.10/2026.10.28/avoid_platform_channel_on_web_false_positive_declaration_guarded_calls.md`.

---

## Reproducer

Copied from `/Users/craighathaway/Documents/src/contacts/lib/service/native_phone/ringtone_picker_service.dart:12-24`. Compiles standalone with `flutter` SDK imports only:

```dart
import 'package:flutter/services.dart';

abstract final class RingtonePickerService {
  static const MethodChannel _channel = MethodChannel('app/ringtone_picker');

  static Future<String?> pick({String? existingUri}) async {
    // LINT — but should NOT lint: project has no web/ folder, Android-only feature.
    final String? uri = await _channel.invokeMethod<String>('pick', <String, Object?>{
      'existingUri': existingUri,
    });
    return uri;
  }
}
```

**Frequency:** Always, for every unguarded `invokeMethod` on a field channel, in a project without a web target.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the project does not support web |
| **Actual** | `[avoid_platform_channel_on_web] MethodChannel throws MissingPluginException on web, crashing the application. {v4}` |

Positions reported:

- `lib/service/native_phone/ringtone_picker_service.dart` 20:40-20:52
- `lib/service/intent/contact_insert_intent_service.dart` 138:57-138:69
- `lib/service/native_device_settings/device_settings_channel.dart` 64:22-64:34 and 116:42-116:54

---

## AST Context

```
ClassDeclaration (RingtonePickerService)
  └─ MethodDeclaration (pick)
      └─ BlockFunctionBody
          └─ VariableDeclarationStatement (uri)
              └─ AwaitExpression
                  └─ MethodInvocation (.invokeMethod)   <- methodName reported here
                      └─ target: SimpleIdentifier (_channel), element = FieldElement
```

---

## Root Cause

`web_rules.dart`:

- Line 123-124: the invocation handler accepts `invokeMethod`, `invokeListMethod`, `invokeMapMethod`.
- Line 128-132: target type must be `MethodChannel`, `EventChannel` or `BasicMessageChannel`.
- Line 134: a local-variable target is skipped.
- Line 137: `_hasWebPlatformCheck(node)` finds no `kIsWeb` in an enclosing `if`, ternary or preceding early-return guard, so the rule reports.

Nothing tests whether web is a supported platform of the analyzed package (no `web/` directory, no `flutter: platforms` web entry, no `kIsWeb` anywhere in the project).

---

## Why the code is correct

The project ships to Android and iOS only. The directories `android/` and `ios/` exist; `web/` does not. The channels call native Kotlin and Swift handlers. `device_settings_channel.dart` also catches `MissingPluginException`.

---

## All affected project locations

- `lib/service/native_phone/ringtone_picker_service.dart:20`
- `lib/service/intent/contact_insert_intent_service.dart:138`
- `lib/service/native_device_settings/device_settings_channel.dart:64`
- `lib/service/native_device_settings/device_settings_channel.dart:116`

---

## Suggested Fix

At rule start, resolve the project root (`ProjectContext.findProjectRoot(context.filePath)`). If `<root>/web/index.html` does not exist, return early for the whole rule. Cache the answer per root.

---

## Fixture Gap

The fixture `example/lib/platforms/avoid_platform_channel_on_web_fixture.dart` should include:

1. Field channel invoked with no guard, in a package with a `web/` folder — expect LINT
2. Same code in a package without a `web/` folder — expect NO lint
3. Invocation behind `if (kIsWeb) return;` — expect NO lint

---

## Environment

- saropa_lints: 17.0.1-beta.2 (project pubspec.lock); rule source read at 17.0.1-beta.3
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Project: contacts (Flutter), platforms android and ios only

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
