# `prefer_secure_random` false positive: non-security shuffling and random element selection

## Status: RESOLVED

## Summary

The `prefer_secure_random` rule (v3) fires 3 times across `saropa_dart_utils`, flagging every use of the `Random()` constructor. The flagged usages are: (1) a module-level cached `Random` instance used for picking random elements from iterables, (2) an inline `Random()` passed to `List.shuffle()` for randomizing map entry order, and (3) a utility function `CommonRandom()` that explicitly provides seeded `Random` for testing purposes.

None of these usages involve security-sensitive operations. There is no token generation, no password creation, no encryption key derivation, no nonce generation, and no session management. The diagnostic warns about "session hijacking, credential guessing, and cryptographic attacks" — none of which are possible through list shuffling or random element selection.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/iterable/iterable_extensions.dart
owner:    _generated_diagnostic_collection_name_#2
code:     prefer_secure_random
severity: 4 (warning)
message:  [prefer_secure_random] Random() uses a predictable pseudo-random
          number generator that produces reproducible sequences from a known
          seed. Tokens, passwords, encryption keys, or nonces generated with
          Random() can be predicted by attackers, enabling session hijacking,
          credential guessing, and cryptographic attacks. {v3}
          Replace Random() with Random.secure() for security-sensitive
          operations such as token generation, password creation, nonce
          generation, and cryptographic key derivation.
lines:    5:24–5:32 (Random() constructor call)
```

## Affected Source

3 violations across 3 files:

### Cached Random for random element selection

File: `lib/iterable/iterable_extensions.dart` line 5

```dart
// Module-level instance avoids allocating a new Random on every randomElement() call.
final Random _random = Random();  // ← triggers

extension GeneralIterableExtensions<T> on Iterable<T> {
  /// Returns a random element from the iterable, or null if empty.
  T? randomElement() {
    if (isEmpty) return null;
    final List<T> list = toList();
    return list[_random.nextInt(list.length)];
  }
}
```

This picks a random item from a list. The "randomness" quality is irrelevant — whether you pick element 3 or element 7 from `['apple', 'banana', 'cherry']` has no security implications.

### Inline Random for shuffling map entries

File: `lib/map/map_extensions.dart` line 25

```dart
extension MapExtensions<K, V> on Map<K, V> {
  List<MapEntry<K, V>>? getRandomListExcept({
    required int count,
    required List<K>? ignoreList,
  }) {
    final List<K> ignore = ignoreList ?? <K>[];
    final List<MapEntry<K, V>> available = entries
        .where((MapEntry<K, V> e) => !ignore.contains(e.key))
        .toList();
    if (available.isEmpty) return null;
    available.shuffle(Random());  // ← triggers
    return available.take(count).toList();
  }
}
```

This shuffles map entries to select a random subset. The shuffle order has no security implications — it is used for UI randomization (e.g., showing random suggestions).

### Explicit seeded Random utility for testing

File: `lib/random/common_random.dart` line 35

```dart
/// Creates a [Random] number generator.
///
/// Every time you reinstall your app, a `Random()` instance is initialized
/// with the same starting conditions, leading to the same sequence of
/// "random" numbers. To ensure you get a different sequence each time the
/// app runs, this function uses the current timestamp as a seed by default.
///
/// You can also provide a fixed [seed] to get a predictable sequence of
/// numbers, which is useful for testing.
// ignore: non_constant_identifier_names
Random CommonRandom([int? seed]) =>
    Random(seed ?? DateTime.now().millisecondsSinceEpoch);  // ← triggers
```

This is an explicitly designed utility for creating **predictable, seeded** `Random` instances. The function's documentation states it is "useful for testing." Replacing with `Random.secure()` would break the API because `Random.secure()` does not accept a seed parameter.

## Root Cause

The rule flags every `Random()` constructor invocation without analyzing the usage context. It applies a blanket assumption that all randomness is security-sensitive. The rule does not check:

1. **How the Random instance is used.** `_random.nextInt(list.length)` for element selection is fundamentally different from `_random.nextInt(256)` for byte generation in a token.

2. **Whether the calling context is security-related.** The rule does not inspect the enclosing function name, class name, or dartdoc for security-related keywords like "token," "password," "key," "nonce," "auth," or "session."

3. **Whether the Random is intentionally seeded.** `CommonRandom([int? seed])` explicitly provides seeded random for reproducibility. `Random.secure()` cannot be seeded, so replacing it would break the function's purpose entirely.

4. **Whether the result feeds into security-sensitive output.** The random values are used for `.shuffle()` and `.nextInt()` for list indexing — never for cryptographic operations.

## Why This Is a False Positive

1. **Shuffling lists is not a security operation.** `available.shuffle(Random())` randomizes the order of map entries for UI display purposes. An attacker who can predict the shuffle order gains nothing — the data is not secret.

2. **Random element selection is not a security operation.** `_random.nextInt(list.length)` picks an index into a collection. Whether element 0 or element 5 is chosen has no bearing on application security.

3. **`Random.secure()` cannot accept a seed.** The `CommonRandom` function's core feature is accepting an optional seed for reproducible sequences in testing. `Random.secure()` has no seed parameter, so this recommendation would break the API and eliminate the function's reason for existing.

4. **`Random.secure()` is slower and may throw.** On platforms without a cryptographically secure random source, `Random.secure()` throws an `UnsupportedError`. Using it for non-security purposes degrades performance and reliability for no benefit.

5. **The diagnostic message is misleading.** "Session hijacking, credential guessing, and cryptographic attacks" are completely inapplicable to list shuffling and random element selection. This alarming language could cause developers to add unnecessary complexity.

## Scope of Impact

This affects any Dart code using `Random()` for non-security purposes:

- **List shuffling** (`list.shuffle(Random())`)
- **Random element selection** (`list[random.nextInt(list.length)]`)
- **Random color/position generation for UI** (`Random().nextDouble() * width`)
- **Game mechanics** (dice rolls, card shuffling, procedural generation)
- **Test utilities** (seeded random for reproducible test data)
- **Sampling and statistics** (random sampling from datasets)

`Random()` is the standard Dart approach for all non-cryptographic randomness. Flagging every usage makes the rule extremely noisy with a very high false positive rate.

## Recommended Fix

### Approach A: Analyze usage context (recommended)

Only flag `Random()` when the result is used in a security-sensitive context. Check if the random output feeds into:

```dart
static const Set<String> _securityContextPatterns = <String>{
  'token',
  'password',
  'secret',
  'key',
  'nonce',
  'salt',
  'hash',
  'otp',
  'auth',
  'session',
  'credential',
  'cipher',
  'encrypt',
};

// Check enclosing function/class name and doc comments
final String? enclosingName = _getEnclosingMethodOrClassName(node);
if (enclosingName != null) {
  final String lowerName = enclosingName.toLowerCase();
  final bool isSecurityContext = _securityContextPatterns.any(
    (String p) => lowerName.contains(p),
  );
  if (!isSecurityContext) return; // Not a security-sensitive context
}
```

### Approach B: Skip when used with `.shuffle()` or `.nextInt()` for indexing

Detect common non-security usage patterns:

```dart
// Skip: list.shuffle(Random()) — shuffling is not security-sensitive
if (node.parent is ArgumentList) {
  final invocation = node.parent?.parent;
  if (invocation is MethodInvocation && invocation.methodName.name == 'shuffle') {
    return;
  }
}
```

### Approach C: Skip seeded constructors

If `Random()` is called with a seed argument, the developer has explicitly chosen predictable randomness. This is always intentional and never security-sensitive:

```dart
// Skip: Random(seed) — intentionally predictable
final ArgumentList? args = node.argumentList;
if (args != null && args.arguments.isNotEmpty) {
  return; // Seeded Random — explicitly predictable, not for security
}
```

### Approach D: Downgrade severity for non-security contexts

Instead of `warning`, use `info` when the usage does not appear to be security-related, and reserve `warning` for detected security contexts.

**Recommendation:** Combine Approaches A, B, and C. Skip seeded constructors unconditionally, skip `.shuffle()` usage unconditionally, and for other usages, check the enclosing context for security-related names. This eliminates false positives for the overwhelmingly common non-security use cases while preserving the warning for genuine security concerns.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
import 'dart:math';

// GOOD: Random used for list shuffling — not security-sensitive.
void _good_shuffleList(List<int> items) {
  items.shuffle(Random());
}

// GOOD: Random used for picking a random element — not security-sensitive.
T? _good_pickRandom<T>(List<T> items) {
  if (items.isEmpty) return null;
  return items[Random().nextInt(items.length)];
}

// GOOD: Seeded Random for testing — intentionally predictable.
Random _good_testRandom([int? seed]) {
  return Random(seed ?? DateTime.now().millisecondsSinceEpoch);
}

// GOOD: Random for UI color generation — not security-sensitive.
int _good_randomColor() {
  final r = Random();
  return (r.nextInt(256) << 16) | (r.nextInt(256) << 8) | r.nextInt(256);
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Random used for token generation — security-sensitive.
// expect_lint: prefer_secure_random
String _bad_generateToken(int length) {
  final random = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

// BAD: Random used for password generation — security-sensitive.
// expect_lint: prefer_secure_random
String _bad_generatePassword() {
  final random = Random();
  return List.generate(16, (_) => random.nextInt(256)).map((b) => b.toRadixString(16)).join();
}
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v3)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (Dart utility library)
- **Total violations:** 3 across 3 files
- **Usages:** List shuffling (`shuffle(Random())`), random element selection (`nextInt(list.length)`), seeded Random utility (`Random(seed ?? ...)`)
- **Security operations in this codebase:** None — no token generation, no password creation, no cryptographic operations

## Severity

Low-medium — warning-level diagnostic. While only 3 violations, each is a clear false positive where the `Random()` usage has zero security implications. The alarming diagnostic language about "session hijacking" and "cryptographic attacks" is disproportionate for list shuffling, which may cause unnecessary alarm or code changes that degrade performance (switching to `Random.secure()`) or break API contracts (removing seed support from `CommonRandom`).
