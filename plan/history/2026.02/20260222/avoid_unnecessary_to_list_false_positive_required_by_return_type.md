# Bug: `avoid_unnecessary_to_list` / `avoid_large_list_copy` false positive when `.toList()` is required by return type or downstream API

## Resolution

**Fixed.** Both `AvoidUnnecessaryToListRule` and `AvoidLargeListCopyRule` now skip `.toList()` when used in return statements, expression function bodies, method chains, assignments, and argument positions.


## Summary

The `avoid_unnecessary_to_list` and `avoid_large_list_copy` rules incorrectly
flag `.toList()` calls when the conversion is **required** because:

1. The enclosing method's return type is `List<T>` (not `Iterable<T>`), or
2. The result is passed to a downstream method that operates on `List<T>`
   (e.g., a `List<T>` extension method)

The lint suggests removing `.toList()` and using lazy iterables instead, but
doing so would either cause a compile-time type error or make the downstream
method call unavailable.

## Severity

**False positive** -- the lint's advice to "Remove .toList()" would cause a
compile-time error. The `.toList()` is structurally required, not optional.

## Reproduction

### Minimal example 1: Required by return type

```dart
extension BoolIterableExtensions on Iterable<bool> {
  /// Returns a new list with all boolean values flipped.
  // FLAGGED: avoid_unnecessary_to_list (col 49)
  // FLAGGED: avoid_large_list_copy (col 49)
  List<bool> get reverse => map((bool b) => !b).toList();
}
```

The getter's return type is `List<bool>`. `map()` returns `Iterable<bool>`.
Without `.toList()`, the code does not compile:

```dart
// ERROR: A value of type 'Iterable<bool>' can't be returned from a
//        getter with return type 'List<bool>'
List<bool> get reverse => map((bool b) => !b);
```

### Minimal example 2: Required by downstream List extension

```dart
extension StringExtensions on String {
  List<String>? words() {
    if (isEmpty) return null;
    return split(' ')
        .map((String word) => word.nullIfEmpty())
        .whereType<String>()
        // FLAGGED: avoid_unnecessary_to_list
        .toList()            // Required because nullIfEmpty() is on List<T>
        .nullIfEmpty();      // ← This is a List<T> extension method
  }
}
```

`nullIfEmpty()` is an extension on `List<T>?`, not on `Iterable<T>?`.
Without `.toList()`, the method is not available:

```dart
// ERROR: The method 'nullIfEmpty' isn't defined for 'Iterable<String>'
return split(' ').map(...).whereType<String>().nullIfEmpty();
```

### Minimal example 3: Required by method return type

```dart
extension StringExtensions on String {
  List<String> splitCapitalizedUnicode({
    bool splitBySpace = false,
  }) {
    // ...
    return intermediateSplit
        .expand((String part) => part.split(RegExp(r'\s+')))
        .where((String s) => s.isNotEmpty)
        // FLAGGED: avoid_unnecessary_to_list
        .toList();  // Required: method returns List<String>, not Iterable<String>
  }
}
```

### Lint output

```
line 98 col 49 • [avoid_unnecessary_to_list] .toList() may be
unnecessary here. Lazy iterables are more efficient. Calling .toList()
after .map(), .where(), .take(), etc. creates an intermediate list that
may not be needed. {v3}

line 98 col 49 • [avoid_large_list_copy] List.from() and toList()
allocate a new list and copy every element, doubling memory consumption.
{v3}
```

### All affected locations (3 instances)

| File | Line | Context | Why `.toList()` is required |
|------|------|---------|---------------------------|
| `lib/bool/bool_iterable_extensions.dart` | 98 | `reverse` getter | Return type is `List<bool>`, not `Iterable<bool>` |
| `lib/string/string_extensions.dart` | 467 | `splitCapitalizedUnicode` | Return type is `List<String>`, not `Iterable<String>` |
| `lib/string/string_extensions.dart` | 560 | `words()` | Downstream `.nullIfEmpty()` is a `List` extension |

## Root cause

Both rules check for `.toList()` calls after iterable operations (`map`,
`where`, `expand`, `whereType`, etc.) and assume the list conversion is
unnecessary. They do not check:

1. **Whether the enclosing method/function's return type requires `List<T>`.**
   If the return type is `List<T>`, the `.toList()` conversion is mandatory.

2. **Whether the result of `.toList()` is passed to a `List`-specific API.**
   Many extension methods and APIs are defined on `List<T>` but not on
   `Iterable<T>`. If the next method in the chain requires `List<T>`,
   the conversion is necessary.

3. **Whether the result is stored in a `List<T>` variable.** If the variable
   type is `List<T>`, the conversion is required for type safety.

## Suggested fix

### Check 1: Return type context

If the `.toList()` expression is the direct return value (or part of a return
expression), check the enclosing function's return type:

```dart
void checkToList(MethodInvocation node) {
  // Find the enclosing return context
  final returnType = getEnclosingReturnType(node);
  if (returnType != null && isListType(returnType)) {
    return; // .toList() is required by return type -- do not flag
  }
}
```

### Check 2: Downstream API context

If the result of `.toList()` is used in a method chain, check whether the
next method is defined on `List<T>` but not on `Iterable<T>`:

```dart
// Check if the toList() result has a method call on it
final parent = node.parent;
if (parent is MethodInvocation && parent.target == node) {
  final method = parent.methodName.staticElement;
  // If the method is defined on List but not Iterable, toList() is required
  if (method != null && isListOnlyMethod(method)) {
    return; // Do not flag
  }
}
```

### Check 3: Variable assignment context

If the result is assigned to a variable of type `List<T>`:

```dart
final parent = node.parent;
if (parent is VariableDeclaration) {
  final declaredType = parent.declaredElement?.type;
  if (declaredType != null && isListType(declaredType)) {
    return; // Do not flag
  }
}
```

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Return type requires List
List<int> getEvens(List<int> nums) {
  return nums.where((int n) => n.isEven).toList();  // Required
}

// Downstream method requires List
extension ListExt<T> on List<T> {
  List<T>? nullIfEmpty() => isEmpty ? null : this;
}
List<String>? process(String s) {
  return s.split(' ').where((e) => e.isNotEmpty).toList().nullIfEmpty();
}

// Variable type requires List
void example() {
  List<int> evens = numbers.where((n) => n.isEven).toList();
}

// Passed to function expecting List parameter
void consume(List<String> items) { }
void example2() {
  consume(words.map((w) => w.trim()).toList());
}

// Should STILL flag (true positives, no change):

// Result used as Iterable (forEach, for-in)
void example3() {
  numbers.where((n) => n > 0).toList().forEach(print);  // FLAGGED
  for (final n in numbers.where((n) => n > 0).toList()) { }  // FLAGGED
}

// Result discarded
void example4() {
  numbers.map((n) => n * 2).toList();  // FLAGGED: result unused
}

// Return type is Iterable
Iterable<int> example5() {
  return numbers.where((n) => n > 0).toList();  // FLAGGED
}
```

## Impact

The `.toList()` conversion is required whenever:
- A method returns `List<T>` (very common in Dart APIs)
- The result is passed to a `List`-specific method (common with extension methods)
- The result is stored in a `List<T>` typed variable
- The result is passed as a `List<T>` argument

These are among the most common uses of `.toList()`. The current rule would
flag a large percentage of legitimate `.toList()` calls in any codebase that
uses `List<T>` return types (which is the Dart convention).
