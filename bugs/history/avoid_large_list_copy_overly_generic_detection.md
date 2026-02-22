# Stylistic concern: `avoid_large_list_copy` — flags all `.toList()` / `List.from()` regardless of context

## Summary

The `avoid_large_list_copy` rule flags every use of `.toList()` and `List.from()` with a warning about "doubling memory consumption for large collections." The rule cannot determine whether the collection is actually large, whether the copy is necessary for correctness, or whether the code path even handles large data. This produces **19 violations** where most or all are either required for correctness or operate on small, bounded collections.

## Scale of impact

| File | Count | Context |
|------|------:|---------|
| `lib/json/json_utils.dart` | 5 | JSON deserialization — `List.from()` is the idiomatic Dart pattern for type-safe list casting |
| `lib/list/list_extensions.dart` | 3 | List utility methods — `.toList()` is required to return a new list (not a lazy iterable) |
| `lib/map/map_extensions.dart` | 3 | Map utility methods — `.toList()` needed for shuffling/random access |
| `lib/string/string_case_extensions.dart` | 3 | String operations — `.toList()` on character lists (bounded by string length) |
| `lib/list/unique_list_extensions.dart` | 2 | Deduplication — must materialize to return a concrete list |
| `lib/list/list_of_list_extensions.dart` | 2 | Nested list operations |
| `lib/bool/bool_iterable_extensions.dart` | 1 | Boolean list reversal — `.toList()` on a mapped iterable |

## What gets flagged

### Case 1: `.toList()` IS the return value — copy is required

```dart
// bool_iterable_extensions.dart:98
List<bool> get reverse => map((bool b) => !b).toList();
//                                            ^^^^^^^^ FLAGGED
```

The function's return type is `List<bool>`, not `Iterable<bool>`. The `.toList()` is not optional — it materializes a lazy `map()` result into the concrete type the caller expects. Removing it would change the API contract.

### Case 2: `List.from()` for type-safe casting from JSON

```dart
// json_utils.dart:128
return List<Map<String, dynamic>>.from(data);
//     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ FLAGGED
```

`data` is a `List<dynamic>` from `jsonDecode()`. `List<Map<String, dynamic>>.from(data)` is the standard Dart idiom for creating a type-safe list from an untyped source. There is no lazy alternative — the type cast must happen eagerly to validate each element.

### Case 3: `.toList()` for `.shuffle()` — List is required

```dart
// map_extensions.dart:23-26
final eligibleKeys = keys.where((K k) => !ignoreList.contains(k)).toList();
//                                                                ^^^^^^^^ FLAGGED
eligibleKeys.shuffle(random);
```

`.shuffle()` requires a `List`, not an `Iterable`. The `.toList()` is a prerequisite for the next operation. The rule does not check what operations follow.

### Case 4: `.toList()` on bounded string characters

```dart
// string_case_extensions.dart:108
final words = input.split(RegExp(r'\s+')).toList();
//                                        ^^^^^^^^ FLAGGED
```

String splitting produces a list bounded by the length of the input string. For a typical string (tens to hundreds of characters), this is a trivially small list. The rule's warning about "doubling memory consumption" and "garbage collection pauses that freeze the UI" is alarmist for a list of 5-10 string fragments.

### Case 5: `.toList()` to return a concrete list from `.where()`

```dart
// string_extensions.dart:457
return lines.where((String s) => s.trim().isNotEmpty).toList();
//                                                    ^^^^^^^^ FLAGGED
```

The function returns `List<String>`. The `.where()` produces an `Iterable`. The `.toList()` is structurally required.

## The core problem

The rule flags ALL instances of `.toList()` and `List.from()` based solely on their syntactic presence, without considering:

1. **Is the copy required?** — When the return type is `List<T>`, `.toList()` is not optional
2. **Is a mutable list needed?** — `.shuffle()`, `.sort()`, `.add()` require a `List`, not an `Iterable`
3. **Is the input bounded?** — String characters, JSON fields, and enum values are inherently small
4. **Is `List.from()` being used for type casting?** — This is the standard Dart pattern for safely casting `List<dynamic>` to `List<T>`
5. **Is there a lazy alternative?** — For many of these cases, there simply isn't one

## Suggested improvements

### Option A: Only flag when a lazy alternative exists

Do not flag `.toList()` when:
- The result is returned from a function with a `List<T>` return type
- The result is immediately passed to a method that requires `List` (`.shuffle()`, `.sort()`, `.add()`, `.insert()`, `.[]=`)
- The result is assigned to a variable typed as `List<T>`

Only flag when the result is:
- Used only for iteration (`.forEach()`, `for-in`, `.map()`, `.where()`)
- Passed to a function that accepts `Iterable<T>`
- Immediately discarded (`.toList()` with no assignment)

### Option B: Exempt `List.from()` for type casting

`List<T>.from(dynamicList)` is a type-casting pattern, not a gratuitous copy. When the source list is `List<dynamic>`, there is no lazy alternative that produces `List<T>`. Exempt this pattern:
```dart
// Should NOT be flagged — type casting, not copying
List<String>.from(dynamicData)
List<Map<String, dynamic>>.from(jsonArray)
```

### Option C: Exempt small/bounded sources

Do not flag `.toList()` when the source is:
- `.split()` on a String (bounded by string length)
- `.entries` / `.keys` / `.values` on a Map (bounded by map size, typically small)
- `.map()` / `.where()` on a known-small collection
- A `characters` iterable (bounded by string length)

### Option D: Require minimum collection size context

Only flag when the code shows evidence of potentially large data:
- Loop/recursion context
- Stream processing
- Database query results
- File I/O results
- Paginated API responses

## What should still be flagged

```dart
// Genuinely wasteful — .toList() immediately followed by lazy operation
final list = items.where((x) => x.isValid).toList();
return list.map((x) => x.name);  // Should have stayed lazy

// Repeated copying in a loop
for (final batch in batches) {
  allItems = [...allItems, ...batch.toList()];  // Quadratic allocation
}
```

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **Rule version:** v3
- **saropa_lints version:** (current)
- **Project:** saropa_dart_utils — 19 violations across 7 files
---

## Resolution

**Fixed in v5.0.0 (rule v4).** `List<T>.from()` with explicit type arguments (type-casting pattern) is now exempt — there is no lazy alternative for type casts. `.toList()` is now exempt when structurally required: returned from a function, assigned to a variable, or used in an assignment expression.
