# `prefer_compute_for_heavy_work` false positive: pure Dart library flagged for UI thread blocking

## Status: OPEN

## Summary

The `prefer_compute_for_heavy_work` rule (v5) fires 14 times across `saropa_dart_utils`, flagging `utf8.encode`, `gzip.encode`, `gzip.decode`, `base64.encode`, `base64.decode`, `utf8.decode`, `jsonDecode`, `jsonEncode`, and `json.decode` calls. The diagnostic warns about "blocking the rendering pipeline, freezing animations, dropping frames" and recommends using `compute()` or `Isolate.run()`.

However, `saropa_dart_utils` is a **pure Dart utility library**. It has no UI thread, no rendering pipeline, no animations, and no touch input to block. The `compute()` function is from `package:flutter/foundation.dart` and while the package does import Flutter, the library itself provides synchronous utility methods that consumers call from whatever execution context they choose. Wrapping every encode/decode in an isolate would break the synchronous API contract and add massive unnecessary complexity.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/base64/base64_utils.dart
owner:    _generated_diagnostic_collection_name_#2
code:     prefer_compute_for_heavy_work
severity: 2 (info)
message:  [prefer_compute_for_heavy_work] Heavy computation such as encryption,
          compression, or parsing runs synchronously on the main UI thread.
          This blocks the rendering pipeline, freezing animations, dropping
          frames, and making the app unresponsive to touch input for the
          duration of the operation. On lower-end devices, this delay is
          especially pronounced and triggers ANR warnings on Android. {v5}
          Move heavy work to a separate isolate using compute() or
          Isolate.run(). This keeps the UI responsive and prevents dropped
          frames or slow user interactions, especially on lower-end devices.
lines:    43:42–43:57 (utf8.encode call)
```

## Affected Source

14 violations across 3 files:

### Base64 compression/decompression

File: `lib/base64/base64_utils.dart` lines 43–46, 81–84

```dart
static String? compressText(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  try {
    final List<int> encodedJson = utf8.encode(value);      // ← triggers (line 43)
    final List<int> gzipJson = io.gzip.encode(encodedJson); // ← triggers (line 44)

    return base64.encode(gzipJson);                         // ← triggers (line 46)
  } on Object catch (e, stackTrace) {
    debugPrint('Base64Utils.compressText failed: $e\n$stackTrace');
    return null;
  }
}

static String? decompressText(String? compressedBase64) {
  if (compressedBase64 == null || compressedBase64.isEmpty) {
    return null;
  }

  try {
    final Uint8List decodedBase64 = base64.decode(compressedBase64); // ← triggers (line 81)
    final List<int> decodedGzip = io.gzip.decode(decodedBase64);     // ← triggers (line 82)

    return utf8.decode(decodedGzip);                                  // ← triggers (line 84)
  } on Object catch (e, stackTrace) {
    debugPrint('Base64Utils.decompressText failed: $e\n$stackTrace');
    return null;
  }
}
```

### JSON parsing and encoding

File: `lib/json/json_utils.dart` lines 25, 46, 81, 116, 118, 125, 141

```dart
// JsonIterablesUtils — line 25
static String jsonEncode<T>(Iterable<T> iterable) => dc.jsonEncode(iterable.toList()); // ← triggers

// JsonUtils.jsonDecodeSafe — line 46
return dc.jsonDecode(jsonString);  // ← triggers

// JsonUtils.isJson (testDecode path) — line 81
return dc.jsonDecode(value) != null;  // ← triggers

// JsonUtils.tryJsonDecodeListMap — line 125
final dynamic data = dc.json.decode(value);  // ← triggers

// JsonUtils.tryJsonDecodeList — line 141
final dynamic data = dc.json.decode(value);  // ← triggers
```

### Hex regex compilation

File: `lib/hex/hex_utils.dart` line 7

```dart
final RegExp _hexRegex = RegExp(r'^[0-9a-fA-F]+$');  // ← triggers (overlaps with avoid_static_state)
```

## Root Cause

The rule pattern-matches on function/method names associated with "heavy computation" categories. It likely checks for calls matching patterns like:

```
utf8.encode, utf8.decode        → categorized as "encoding"
gzip.encode, gzip.decode        → categorized as "compression"
base64.encode, base64.decode    → categorized as "encoding"
jsonDecode, json.decode         → categorized as "parsing"
jsonEncode, json.encode         → categorized as "encoding"
RegExp(...)                     → categorized as "parsing" (regex compilation)
```

The rule does not check:

1. **Whether the package is a library or an application.** Libraries provide utility functions — they do not control the execution context. The _consumer_ of the library decides whether to run these on the main isolate or in `compute()`.

2. **Whether the code is reachable from a UI build path.** These are static utility methods called explicitly. They are not invoked from `build()`, `initState()`, or any widget lifecycle.

3. **The expected data size.** `utf8.encode(value)` on a short string (typical for these utilities) completes in microseconds. The rule treats all encode/decode calls identically regardless of expected payload size.

4. **Whether `compute()` is even available.** While this package does depend on Flutter, the `compute()` recommendation assumes these methods would be called from a Flutter app context. Making library utility methods async would fundamentally change the API and break all consumers.

## Why This Is a False Positive

1. **Library code has no UI thread.** A utility library provides functions — it does not own a rendering pipeline. The diagnostic about "freezing animations" and "dropping frames" is inapplicable to library code that has no animations or frames.

2. **`compute()` would break the API contract.** `compressText` returns `String?` synchronously. Wrapping it in `compute()` would change it to `Future<String?>`, breaking every existing call site. Library consumers who need async execution can wrap the call themselves.

3. **The operations are trivially fast for typical inputs.** `utf8.encode` on a string, `jsonDecode` on a small JSON payload, and `RegExp` compilation are sub-millisecond operations. The rule cannot assess data size and applies a blanket warning.

4. **The diagnostic message is misleading.** References to "ANR warnings on Android," "touch input responsiveness," and "lower-end devices" are only relevant to Flutter application code running on the main isolate, not to library utility methods.

5. **Double-counting with `avoid_static_state`.** The `RegExp` compilation at `hex_utils.dart:7` is flagged by both this rule and `avoid_static_state`, producing two diagnostics for the same harmless pattern.

## Scope of Impact

This affects any Dart library (not just Flutter apps) that performs:

- **JSON parsing** with `dart:convert` (`jsonDecode`, `jsonEncode`, `json.decode`, `json.encode`)
- **Base64 encoding/decoding** (`base64.encode`, `base64.decode`)
- **UTF-8 encoding/decoding** (`utf8.encode`, `utf8.decode`)
- **Gzip compression/decompression** (`gzip.encode`, `gzip.decode`)
- **RegExp compilation** (`RegExp(...)`)

These are fundamental `dart:convert` and `dart:io` operations used in virtually every Dart library that handles data serialization.

## Recommended Fix

### Approach A: Skip non-Flutter packages (recommended)

Check `pubspec.yaml` for a Flutter SDK dependency. If the package does not depend on Flutter (or is explicitly a library package), skip the rule entirely:

```dart
// Before running the rule
if (!context.pubspec.dependsOnFlutter) {
  return; // Pure Dart library — no UI thread to protect
}
```

For packages like `saropa_dart_utils` that depend on Flutter but are still library packages (not apps), check `pubspec.yaml` for a `flutter.plugin` or app entry point.

### Approach B: Only flag code reachable from widget build paths

Instead of flagging all encode/decode calls globally, only flag them when they appear inside (or are called from) widget lifecycle methods:

```dart
// Only flag when inside build(), initState(), didUpdateWidget(), etc.
final AstNode? enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
if (enclosingMethod != null) {
  final String methodName = enclosingMethod.name.lexeme;
  if (!_widgetLifecycleMethods.contains(methodName)) {
    return; // Not in a widget lifecycle — consumer controls execution context
  }
}
```

### Approach C: Add a package-level configuration to disable UI-thread rules

Allow packages to declare themselves as libraries in `analysis_options.yaml`:

```yaml
saropa_lints:
  package_type: library  # Disables UI-thread rules like prefer_compute_for_heavy_work
```

### Approach D: Require a minimum estimated complexity threshold

Only flag operations that are likely to be expensive based on heuristics:

- `gzip.encode`/`gzip.decode` — potentially expensive, keep the warning
- `utf8.encode`/`utf8.decode` — trivially fast, skip
- `jsonDecode` on a variable — unknown size, warn only in widget lifecycle
- `RegExp(...)` — one-time cost, skip

**Recommendation:** Approach A is the simplest and most impactful. Libraries should never be warned about UI thread blocking because they do not own a UI thread. The consuming application decides execution context.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Library utility method performing JSON decode — no UI thread.
class _good_JsonHelper {
  static Map<String, dynamic>? parse(String json) {
    return jsonDecode(json) as Map<String, dynamic>?;
  }
}

// GOOD: Library utility performing Base64 encode — consumer controls context.
class _good_Encoder {
  static String encode(String input) {
    final bytes = utf8.encode(input);
    return base64.encode(bytes);
  }
}

// GOOD: Library utility performing gzip — synchronous API by design.
class _good_Compressor {
  static List<int> compress(List<int> data) {
    return gzip.encode(data);
  }
}
```

### Existing BAD cases (should still trigger in Flutter app code)

```dart
// BAD: JSON decode inside a widget's build method — blocks UI.
// expect_lint: prefer_compute_for_heavy_work
class _bad_HeavyBuildState extends State<_bad_HeavyBuild> {
  @override
  Widget build(BuildContext context) {
    final data = jsonDecode(hugeJsonString);  // Blocks rendering
    return Text(data.toString());
  }
}
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v5)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (Dart utility library published on pub.dev)
- **Total violations:** 14 across 3 files
- **Highest concentration:** `lib/base64/base64_utils.dart` (6 violations — every encode/decode call)
- **Operations flagged:** `utf8.encode`, `utf8.decode`, `gzip.encode`, `gzip.decode`, `base64.encode`, `base64.decode`, `jsonDecode`, `json.decode`, `jsonEncode`, `RegExp(...)`
- **Package type:** Library (provides utilities, does not own a UI thread or application lifecycle)
- **pubspec.yaml:** Has `flutter: sdk: flutter` dependency but is a library, not an app

## Severity

Low — info-level diagnostic. However, the 14 violations across core utility files create significant noise. The diagnostic message about "freezing animations" and "ANR warnings on Android" is misleading when applied to synchronous library utility methods, which erodes developer confidence in the linter's relevance. Following the advice would require converting synchronous methods to async, breaking the library's API contract and all downstream consumers.
