# Stylistic concern: `avoid_dynamic_type` — does not account for JSON/serialization context

## Summary

The `avoid_dynamic_type` rule flags all uses of `dynamic` regardless of context, producing **72 violations** concentrated entirely in `json_utils.dart`. In JSON deserialization code, `dynamic` is not a type-safety shortcut — it is the **only correct type** for values returned by `dart:convert`'s `jsonDecode()`, which has a return type of `dynamic`. The rule lacks the ability to distinguish between lazy use of `dynamic` (genuinely problematic) and inherently untyped data flowing from JSON boundaries.

## Scale of impact

All 72 violations are in a single file:

| File                       | Count |
| -------------------------- | ----: |
| `lib/json/json_utils.dart` |    72 |

## What gets flagged

### `json.decode()` returns `dynamic` — unavoidable

```dart
// json_utils.dart:41 — return type FLAGGED
static dynamic jsonDecodeSafe(String? jsonString) {
  // ...
  return dc.jsonDecode(jsonString);  // jsonDecode returns dynamic
}
```

`dart:convert`'s `jsonDecode()` signature is:

```dart
dynamic jsonDecode(String source, {Object? Function(Object?, Object?)? reviver});
```

The function returns `dynamic`. Wrapping it in `Object?` would require callers to cast immediately, adding boilerplate without improving safety. The `dynamic` propagation is intentional — it allows downstream code to use `is` checks for progressive narrowing.

### `Map<String, dynamic>` — Dart's JSON map type

```dart
// json_utils.dart:33 — Map value type FLAGGED
static Map<String, dynamic>? jsonDecodeToMap(String? jsonString) {
  // ...
  final dynamic decoded = jsonDecodeSafe(jsonString);
  //    ^^^^^^^ FLAGGED
  if (decoded == null) return null;
  return MapUtils.toMapStringDynamic(decoded);
}
```

`Map<String, dynamic>` is the **canonical Dart type for JSON objects**. It is used throughout:

- Flutter's `jsonDecode()` returns it
- Every JSON serialization package (json_serializable, freezed, built_value) uses it
- All Firebase/Firestore APIs accept and return it
- Every `fromJson` factory constructor accepts it

Flagging `Map<String, dynamic>` in JSON utilities is like flagging `String` in string utilities.

### Type-narrowing patterns — `dynamic` is the input being narrowed

```dart
// json_utils.dart:122-128
static List<Map<String, dynamic>>? tryJsonDecodeListMap(String? value) {
  if (value == null || !isJson(value)) return null;
  try {
    final dynamic data = dc.json.decode(value);
    //    ^^^^^^^ FLAGGED — but this IS dynamic from jsonDecode
    if (data is! List || data.isEmpty || data[0] is! Map<String, dynamic>) return null;
    //                                                            ^^^^^^^ FLAGGED
    if (!data.every((dynamic e) => e is Map<String, dynamic>)) return null;
    //               ^^^^^^^ FLAGGED     ^^^^^^^ FLAGGED
    return List<Map<String, dynamic>>.from(data);
    //                      ^^^^^^^ FLAGGED
  } on Object catch (e, stackTrace) { ... }
}
```

This function takes untyped JSON, validates its structure with `is` checks, and returns a safely-typed result. Every `dynamic` here is either:

1. The return value of `jsonDecode()` (inherently dynamic)
2. A lambda parameter iterating over an untyped list (must be `dynamic`)
3. `Map<String, dynamic>` — the standard JSON map type

The code is doing exactly what `avoid_dynamic_type` wants: **narrowing untyped data into typed data**. But the rule flags every intermediate step.

### Function parameters that accept JSON data

```dart
// json_utils.dart:161
static int countIterableJson(dynamic json, {String separator = ','}) {
  //                         ^^^^^^^ FLAGGED
  if (json == null) return 0;
  if (json is Iterable) return json.length;
  if (json is String) { ... }

  return 0;
}
```

This function accepts a value that could be a JSON array, a comma-separated string, or null. `dynamic` is the correct type — using `Object?` would be semantically identical but less idiomatic for JSON-accepting APIs.

## Why `Object?` is not a practical alternative

The rule suggests replacing `dynamic` with `Object?`. In JSON code, this creates problems:

1. **`jsonDecode()` returns `dynamic`, not `Object?`** — assigning to `Object?` requires an explicit cast or loses the ability to call methods without casting
2. **Map indexing**: `Map<String, Object?>` means every value access requires a cast: `(map['key'] as String?)` instead of `map['key'] as String?` (which already works with dynamic)
3. **Collection operations**: `List<Object?>` requires `.cast<Map<String, dynamic>>()` instead of `List<Map<String, dynamic>>.from(data)`
4. **No safety improvement**: Both `dynamic` and `Object?` require runtime type checks for JSON data. The compiler cannot statically verify JSON structure either way. The `is` checks are the real safety mechanism, not the declared type.

## Suggested improvements

### Option A: Exempt JSON-related `dynamic` usages (recommended)

Do not flag `dynamic` when it appears in:

1. Return types or variables assigned from `jsonDecode()` / `json.decode()`
2. `Map<String, dynamic>` — the canonical JSON map type
3. Lambda parameters in collection operations on untyped lists (`data.every((dynamic e) => ...)`)
4. Parameters of functions whose name contains `json`, `Json`, `JSON`, `fromMap`, `toMap`

### Option B: Exempt files matching JSON patterns

Suppress the rule entirely for files matching:

- `*_json*.dart`
- `*json_*.dart`
- `*serialization*.dart`
- `*_model.dart` (often contain fromJson/toJson)

### Option C: Allow `Map<String, dynamic>` globally

At minimum, do not flag `Map<String, dynamic>` anywhere. This type is so pervasive in Dart JSON handling that flagging it creates noise in any project that touches JSON, which is nearly every Flutter project.

### Option D: Downgrade severity for `dynamic` in type arguments

Distinguish between:

- `dynamic x = ...` (variable typed as dynamic — worth flagging)
- `Map<String, dynamic>` (type argument — standard idiom, should not flag)
- `List<dynamic>` from jsonDecode (unavoidable, should not flag)

## What should still be flagged

Uses of `dynamic` in non-serialization code remain valid warnings:

- `dynamic result = someCalculation();` — should use a specific type
- Function parameters typed as `dynamic` when a concrete type is known
- `dynamic` in widget code, state management, or business logic

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **Rule version:** v3
- **saropa_lints version:** (current)
- **Project:** saropa_dart_utils — 72 violations, all in `json_utils.dart`

---

## Resolution

**Fixed in v5.0.0 (rule v4).** Added `_isMapValueType()` exemption: `dynamic` is no longer flagged when it appears as the value type argument of `Map<String, dynamic>`, the canonical Dart JSON type. Other uses of `dynamic` (variables, parameters, `List<dynamic>`) remain flagged.
