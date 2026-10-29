# BUG: `require_speech_stop_on_dispose` — flags a `SpeechToText` field when `dispose()` cancels it through a private helper method

**Status: Open**

Created: 2026-10-29
Rule: `require_speech_stop_on_dispose`
File: `lib/src/rules/packages/speech_to_text_rules.dart` (line ~51; check at 86-135)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`dispose()` calls `unawaited(_cancelEngine())`. `_cancelEngine()` (declared in an extension on the State class, in a `part` file) calls `await _speech.cancel()`. The microphone is released. The rule only searches the `dispose` body text for `_speech.stop(` / `_speech.cancel(` and reports the field.

---

## Attribution Evidence

```bash
grep -rn "'require_speech_stop_on_dispose'" lib/src/rules/
# lib/src/rules/packages/speech_to_text_rules.dart:70:    'require_speech_stop_on_dispose',
```

**Rule class:** `RequireSpeechStopOnDisposeRule` (`speech_to_text_rules.dart:51`), registered in `lib/saropa_lints.dart:1776`
**Diagnostic as seen in Problems panel:** `[require_speech_stop_on_dispose] A SpeechToText recognizer that is not stopped in dispose keeps the microphone active...` at 170:27 (source: saropa_lints)

---

## Reproducer

Standalone (needs a Flutter project with `speech_to_text`). Real code: `lib/components/primitive/text/common_voice_mic_button.dart` lines 159-253 and `common_voice_mic_button_owner.dart` lines 77-89 in the Saropa contacts app.

```dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class Mic extends StatefulWidget {
  const Mic({super.key});

  @override
  State<Mic> createState() => _MicState();
}

class _MicState extends State<Mic> {
  final SpeechToText _speech = SpeechToText(); // LINT — but should NOT lint

  @override
  void dispose() {
    _cancelEngine(); // cancels the engine through a private helper
    super.dispose();
  }

  Future<void> _cancelEngine() async {
    try {
      await _speech.cancel();
    } on Object catch (error) {
      debugPrint('$error');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() => runApp(const MaterialApp(home: Mic()));
```

**Frequency:** Always when the stop/cancel is in a helper called from `dispose()`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (the engine is canceled during dispose) |
| **Actual** | `[require_speech_stop_on_dispose]` at the field declarator `_speech` (170:27) |

---

## AST Context

```
ClassDeclaration (_MicState extends State<Mic>)
  ├─ FieldDeclaration
  │   └─ VariableDeclaration (_speech)            ← node reported here (reporter.atNode(variable), line 128)
  ├─ MethodDeclaration (dispose)
  │   └─ BlockFunctionBody
  │       └─ ExpressionStatement
  │           └─ MethodInvocation (_cancelEngine)   ← no `_speech.` target, so no match
  └─ MethodDeclaration (_cancelEngine)
      └─ MethodInvocation (_speech.cancel)         ← the real cleanup, outside dispose
```

---

## Root Cause

`runWithReporter` (`speech_to_text_rules.dart:86`) collects `SpeechToText` fields (lines 96-106), finds the `dispose` method (lines 111-118), and computes

```dart
isStopped = disposeMethod != null &&
    (isFieldCleanedUp(name, 'stop', disposeMethod.body) ||
     isFieldCleanedUp(name, 'cancel', disposeMethod.body));   // lines 120-123
```

`isFieldCleanedUp` (`lib/src/target_matcher_utils.dart:180`) matches the regex `field\s*(?:\?\.|\.)\s*method\s*\(` on `body.toSource()`, plus cascade sections. It never follows a call from `dispose()` to a private method of the same class. In the real code the helper is also declared in an `extension` in a `part` file, so a same-class lookup would not find it either.

---

## Why the code is correct

`dispose()` runs `_cancelEngine()`, which marks the guard and awaits `_speech.cancel()`. The helper wraps the call in try/catch because it is unawaited in `dispose`, where a plugin throw must not become an unhandled async error. Inlining `_speech.cancel()` into `dispose()` would drop the guard step.

---

## Suggested Fix

When no direct call is found, resolve each unqualified or `this.` method invocation in `dispose()` (and its `super`-less callees, depth 2) to its declaration in the class or in an extension on the class, and apply `isFieldCleanedUp` to that body. Use the resolved element (`MethodInvocation.methodName.element`) to find the declaration across `part` files.

---

## Fixture Gap

1. `dispose() { _stopAll(); }` with `_stopAll() { _speech.stop(); }` in the same class — expect NO lint.
2. Same with the helper in an `extension on _State` — expect NO lint.
3. `dispose() { _noop(); }` where the helper never touches `_speech` — expect LINT.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/components/primitive/text/common_voice_mic_button.dart:170:27`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
