# Bug: `avoid_dynamic_type` false positives in JSON utility code

## Summary

The `avoid_dynamic_type` rule (v4) correctly exempts `Map<String, dynamic>`
as stated in its message: "Map<String, dynamic> is exempt as the canonical
Dart JSON type." However, it still flags **all other unavoidable uses of
`dynamic`** in JSON utility code where `dynamic` is the only correct type:

1. `dart:convert`'s `json.decode()` returns `dynamic` -- there is no way to
   avoid declaring a `dynamic` variable to receive it
2. JSON data can be `List<dynamic>`, `Map<String, dynamic>`, `String`, `int`,
   `double`, `bool`, or `null` -- type-checking requires `dynamic` parameters
3. Lambda parameters in `data.every((dynamic e) => ...)` need explicit `dynamic`
   type annotations to satisfy other lint rules

The rule flags **43 instances** in this project, with the majority (22+) in
`json_utils.dart` and `map_extensions.dart` -- files that exist specifically
to handle untyped JSON data.

## Severity

**False positive** -- Using `dynamic` in JSON deserialization code is not a
design flaw but a necessity imposed by `dart:convert`'s API. The rule's
exemption for `Map<String, dynamic>` acknowledges this but does not go far
enough.

## Reproduction

### Example 1: `json.decode()` return value

**File:** `lib/json/json_utils.dart`, line 44

```dart
static dynamic jsonDecodeSafe(String? jsonString) {
  // ...
  return dc.jsonDecode(jsonString);  // dart:convert returns dynamic
}
```

FLAGGED on line 44 for the `dynamic` return type. But `dart:convert`'s
`jsonDecode()` returns `dynamic` -- there is no typed alternative.

### Example 2: Intermediate JSON decode result

**File:** `lib/json/json_utils.dart`, line 186

```dart
final dynamic data = dc.json.decode(value);
if (data is! List || data.isEmpty || data[0] is! Map<String, dynamic>) {
  return null;
}
```

FLAGGED on line 186 for `final dynamic data`. The variable is immediately
type-checked on the next line. Using `Object?` instead would require
additional casts that reduce clarity.

### Example 3: Lambda parameter in JSON iteration

**File:** `lib/json/json_utils.dart`, line 191

```dart
if (!data.every((dynamic e) => e is Map<String, dynamic>)) return null;
```

FLAGGED for `(dynamic e)`. The `List` returned by `json.decode()` is
`List<dynamic>`, so the lambda parameter inherits `dynamic`. The explicit
annotation is required by other lint rules (`prefer_explicit_parameter_names`).

### Example 4: JSON conversion utilities

**File:** `lib/json/json_utils.dart`, lines 249, 268, 299, 322

```dart
static int countIterableJson(dynamic json, {String separator = ','}) { ... }
static List<String>? toStringListJson(dynamic json, {String separator = ','}) { ... }
static List<int>? toIntListJson(dynamic json) { ... }
static int? toIntJson(dynamic json) { ... }
```

All four methods accept `dynamic json` because they are designed to handle
unknown JSON values that could be `String`, `List`, `int`, `Map`, or `null`.
This is the standard pattern for JSON deserialization utilities.

### Example 5: Map extensions operating on `Map<String, dynamic>`

**File:** `lib/map/map_extensions.dart`, multiple lines

```dart
extension StringMapExtensions on Map<String, dynamic> {
  String formatMap() {
    forEach((String mapKey, dynamic mapValue) {  // FLAGGED
      if (mapValue is Map<String, dynamic>) { ... }
      else if (mapValue is List) {
        for (dynamic listItem in mapValue) {  // FLAGGED
          ...
        }
      }
    });
  }
}
```

When iterating over `Map<String, dynamic>`, the values are `dynamic` by
definition. The `forEach` callback's second parameter must be `dynamic`.

### Example 6: Nullable map extension

**File:** `lib/map/map_nullable_extensions.dart`, line 4

```dart
extension MapNullableExtensions on Map<dynamic, dynamic>? {
```

This extension intentionally works on maps with any key and value type.
Using `Object?` instead of `dynamic` would change the semantics (Object
is a type, dynamic is the absence of a type constraint).

## Full count by file

| File | `dynamic` flags | Context |
|------|----------------:|---------|
| `json/json_utils.dart` | 22 | JSON decode/encode utilities |
| `map/map_extensions.dart` | 17 | Map<String, dynamic> operations |
| `map/map_nullable_extensions.dart` | 1 | Nullable map extension |
| `list/list_extensions.dart` | 1 | MapEquality<dynamic, int> |
| `list/list_of_list_extensions.dart` | 1 | Matrix toString with dynamic elements |

## Root cause

The rule exempts `Map<String, dynamic>` type annotations but does not exempt:

1. **Variables receiving `dynamic` return values** from `dart:convert` APIs
2. **Lambda/callback parameters** that inherit `dynamic` from their container type
3. **Function parameters typed as `dynamic`** in JSON conversion utilities
4. **Loop variables** iterating over `dynamic` collections
5. **`Map<dynamic, dynamic>`** as an extension target type

## Suggested fix

**Option A (recommended): Exempt JSON-related `dynamic` usage**

Recognize that `dynamic` is unavoidable in these contexts:

1. Return type of functions wrapping `jsonDecode()`
2. Variables assigned from `jsonDecode()` or similar untyped APIs
3. Lambda parameters in callbacks on `List<dynamic>` or `Map<String, dynamic>`
4. Function parameters in JSON conversion utilities (methods that perform
   type-checking via `is` expressions)
5. Loop variables iterating over `dynamic` collections

**Option B: Exempt files/classes with JSON-related names**

If the file or class name contains "json", "Json", "JSON", "serialize",
"deserialize", or "codec", relax the rule for that scope.

**Option C: Exempt when `dynamic` is immediately type-checked**

If the `dynamic` variable is used with `is` type checks within the same
function body, it indicates intentional polymorphic handling:

```dart
final dynamic data = json.decode(value);
if (data is List) { ... }  // <-- type check makes dynamic intentional
if (data is Map) { ... }
```

**Option D: Broaden the `Map<String, dynamic>` exemption**

If `Map<String, dynamic>` is exempt, then these should also be exempt:
- `List<dynamic>` (JSON arrays from `json.decode()`)
- `dynamic` return types from functions named `*decode*` or `*parse*`
- `dynamic` parameters in functions that perform `is` type checks

## Resolution

**Fixed in v5.0.3.** Rule bumped to v5. Three new exemptions added:
1. `dynamic` as a type argument in any generic type (`List<dynamic>`, `Map<dynamic, dynamic>`, etc.)
2. `dynamic` in closure/lambda formal parameters (type dictated by container)
3. `dynamic` in for-in loop variables (type dictated by iterable)

This eliminates false positives in JSON utility code and Map extension methods where `dynamic` is imposed by the type system.

## Environment

- saropa_lints version: latest (v4 of this rule)
- Dart SDK: 3.x
- Project: saropa_dart_utils
