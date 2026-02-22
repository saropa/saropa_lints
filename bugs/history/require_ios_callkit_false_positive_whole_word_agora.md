# `require_ios_callkit_integration` false positive: "Agora" as a whole word in non-VoIP context

## Status: RESOLVED

## Summary

The `require_ios_callkit_integration` rule (v4) fires on the string literal
`'Ancient Agora of Athens'` in a static landmark data file. The word "Agora"
here refers to the ancient Greek marketplace, not the Agora VoIP SDK. The v4
word-boundary fix (from the previous "Zagora" bug) correctly prevents
**substring** false positives, but cannot distinguish the **whole word**
"Agora" used in a non-VoIP context from the VoIP SDK name.

## Diagnostic Output

```
resource: /D:/src/contacts/lib/data/country/country_capital_city_data.dart
owner:    _generated_diagnostic_collection_name_#2
code:     require_ios_callkit_integration
severity: 4 (hint)
message:  [require_ios_callkit_integration] VoIP call handling detected.
          iOS requires CallKit integration for native call UI. Without CallKit,
          incoming calls will not appear on the lock screen, call audio routing
          will fail, and Apple will reject your app from the App Store during
          review. {v4}
line:     1420, columns 9–34
```

## Affected Source

File: `lib/data/country/country_capital_city_data.dart` line 1420

```dart
majorLandmarks: const <String>[
  'Acropolis and Parthenon',
  'Plaka District',
  'National Archaeological Museum',
  'Ancient Agora of Athens',           // ← falsely flagged
],
```

This is a `const <String>[]` list inside a `CountryCityModel` constructor for
Athens. It is pure static geographical data — no VoIP, telephony, or call
handling anywhere in the file.

## Root Cause

The v4 fix replaced `String.contains()` with word-boundary regex:

```dart
// ios_rules.dart line 4885–4896
static final List<RegExp> _voipRegexes = [
  'voip',
  'incoming_call',
  'outgoing_call',
  'call_state',
  'WebRTC',
  'Twilio',
  'Agora',          // ← the problematic pattern
  'Vonage',
]
    .map((p) => RegExp('\\b${RegExp.escape(p)}\\b', caseSensitive: false))
    .toList();
```

The regex `\bAgora\b` correctly rejects "Zagora" (no word boundary before
"agora"), but **matches** "Ancient **Agora** of Athens" because "Agora" stands
as a complete word here. The word-boundary approach solved the substring
problem but introduced a new class of false positives: the word "Agora" used
in its original Greek meaning (marketplace/gathering place).

"Agora" is a common word in:
- Historical/archaeological contexts (Ancient Agora, Roman Agora)
- Place names worldwide (Agora, Greece; numerous streets and squares)
- General English vocabulary (agora = public gathering space)

## Relationship to Previous Bug

This is a **distinct issue** from the resolved bug at
`bugs/history/require_ios_callkit_false_positive_substring_match.md`. That bug
was about substring matching ("Zagora" containing "agora"). This bug is about
whole-word matching where the word has legitimate non-VoIP meanings.

| Bug | Pattern | Example | Match Type |
|-----|---------|---------|------------|
| Previous (resolved) | `agora` inside `Zagora` | `'Stara Zagora'` | Substring |
| **This (new)** | `Agora` as standalone word | `'Ancient Agora of Athens'` | Whole word |

## Why String Matching Is Fundamentally Wrong

The current approach (v1 → v4) has tried progressively refined string matching:

| Version | Method | Problem |
|---------|--------|---------|
| v1–v3 | `String.contains()` | Substring false positives ("Zagora") |
| v4 | `\b` word-boundary regex | Whole-word false positives ("Ancient Agora of Athens") |
| Next? | Prose heuristics? | Still guessing — will break on edge cases |

**String literals are the wrong signal.** A VoIP SDK reference is not
`'Agora'` in a string — it's `import 'package:agora_rtc_engine/...'` in the
import directives, or `AgoraRtcEngine(...)` as a class instantiation, or
`Twilio.voice.call(...)` as a method invocation. The rule has access to all
of these via the analyzer AST, but chooses to scan the weakest signal (string
content) instead.

## Recommended Fix: Import-Based Detection

The `custom_lint` framework provides `context.registry.addImportDirective()`
— already used by 25+ rules in this codebase (e.g., `ios_rules.dart:4379`
for App Clip size warnings). Replace string scanning with import detection:

### Step 1: Define VoIP package imports (the strong signal)

```dart
/// Known VoIP/telephony package URIs.
///
/// These are the actual packages that require CallKit integration.
/// Matching on imports is deterministic — no false positives from
/// unrelated strings.
static const List<String> _voipPackages = [
  'agora_rtc_engine',
  'agora_rtm',
  'flutter_webrtc',
  'twilio_voice',
  'twilio_programmable_video',
  'vonage_client_sdk',
  'flutter_voip_push_notification',
  'connectycube_flutter_call_kit',
  'sip_ua',
  'flutter_pjsip',
  'janus_client',
  'livekit_client',
  'stream_video_flutter',
];
```

### Step 2: Match against import URIs

```dart
@override
void runWithReporter(
  CustomLintResolver resolver,
  SaropaDiagnosticReporter reporter,
  CustomLintContext context,
) {
  final String fileSource = resolver.source.contents.data;

  // Already integrated — nothing to warn about
  if (fileSource.contains('CallKit') ||
      fileSource.contains('flutter_callkit') ||
      fileSource.contains('CXProvider')) {
    return;
  }

  bool hasReported = false;

  context.registry.addImportDirective((ImportDirective node) {
    if (hasReported) return;

    final String? uri = node.uri.stringValue;
    if (uri == null) return;

    // Check if the import references a known VoIP package
    for (final String package in _voipPackages) {
      if (uri.contains(package)) {
        reporter.atNode(node, code);
        hasReported = true;
        return;
      }
    }
  });
}
```

### Why this is better

| Criterion | String matching (current) | Import matching (proposed) |
|-----------|--------------------------|---------------------------|
| False positives | High — any string containing "Agora", "Twilio", etc. | Zero — only triggers on actual package imports |
| False negatives | High — misses SDK usage without string literals | Low — any VoIP SDK must be imported before use |
| Maintenance | Fragile — new edge cases with each fix | Stable — add new package names as SDKs emerge |
| Scope | Per-string-literal scanning | Per-import-directive scanning |
| Performance | Regex on every string literal in every file | Simple string comparison on import URIs only |
| Correctness | Heuristic (guessing intent from content) | Deterministic (matching declared dependencies) |

### Step 3: Optional — keep a narrow string check as secondary signal

If you want to catch files that reference VoIP concepts without importing an
SDK directly (e.g., a config file with `'voip'` protocol strings), keep a
small set of **unambiguous technical terms** as a fallback:

```dart
/// Narrow technical terms that are unambiguous VoIP signals.
///
/// These are NOT brand names (which have non-VoIP meanings), only
/// protocol/API terms that exclusively indicate VoIP intent.
static const List<String> _unambiguousVoipTerms = [
  'voip',
  'incoming_call',
  'outgoing_call',
  'call_state',
];
```

Remove `'Agora'`, `'Twilio'`, `'Vonage'`, and `'WebRTC'` from string
scanning entirely — these brand/technology names are too ambiguous as bare
strings, and the import check already covers their actual SDK usage.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Whole-word "Agora" in natural language — not a VoIP reference.
void _good881() {
  const landmark = 'Ancient Agora of Athens';
  const landmarks = ['Roman Agora', 'Agora of Thessaloniki'];
  const description = 'The agora was the center of public life';
}

// GOOD: Brand names in non-VoIP context.
void _good882() {
  const company = 'Twilio SendGrid'; // Email API, not VoIP
  const article = 'Vonage acquired by Ericsson';
}
```

### New BAD cases (SHOULD trigger — import-based)

```dart
// BAD: Importing a VoIP SDK without CallKit.
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// BAD: Importing WebRTC without CallKit.
import 'package:flutter_webrtc/flutter_webrtc.dart';
```

### Existing cases to keep

```dart
// BAD: Unambiguous VoIP term in a string.
void _bad880() {
  // expect_lint: require_ios_callkit_integration
  const protocol = 'voip';
}

// GOOD: Substring "agora" inside "Zagora".
void _good880() {
  const city = 'Zagora';
  const city2 = 'Stara Zagora';
}
```

## Environment

- **saropa_lints version:** 4.14.5 (rule version v4)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\contacts`
- **Trigger file:** `lib/data/country/country_capital_city_data.dart:1420`
- **String literal:** `'Ancient Agora of Athens'`
- **Matched pattern:** `\bAgora\b` (case-insensitive)

## Severity

Low — hint-level diagnostic, single occurrence in the trigger project. However,
the same false positive will affect any project with geographical, historical,
or architectural data containing the word "Agora".
