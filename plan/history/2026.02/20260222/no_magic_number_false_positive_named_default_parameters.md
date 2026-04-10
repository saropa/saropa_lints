# Bug: `no_magic_number` false positive on numeric literals used as named default parameter values

## Resolution

**Fixed.** `_isDefaultParameterValue` checks if the literal parent is `DefaultFormalParameter` and skips it. Parameter names provide self-documenting context.


## Summary

The `no_magic_number` rule incorrectly flags numeric literals used as default
values for **named parameters** in method/function signatures. Named parameters
provide self-documenting context through their name — the parameter name itself
explains what the number means, making it not a "magic number" by any reasonable
definition.

## Severity

**False positive** -- the rule's advice to "Extract the number to a named
constant" is counterproductive when the number already has a descriptive name
via the parameter. Extracting `3` to `static const int kDefaultObscureLength = 3`
when the parameter is already named `obscureLength` adds indirection without
improving clarity.

## Reproduction

### Minimal example 1: Default obscure length

```dart
extension StringExtensions on String {
  /// Returns an obscured version of this string.
  ///
  /// The output length varies by ±[obscureLength] characters.
  // FLAGGED at `3`: no_magic_number
  //   "Unexplained numeric literal makes the code harder to understand"
  String? obscureText({String char = '•', int obscureLength = 3}) {
    //                                                        ^
    //                                         Named parameter explains the 3
    if (isEmpty) return null;
    final int seed = DateTime.now().microsecondsSinceEpoch;
    final int extra = (seed % (2 * obscureLength + 1)) - obscureLength;
    final int finalLength = length + extra;
    return char * (finalLength > 0 ? finalLength : 1);
  }
}
```

### Minimal example 2: Default min length

```dart
extension StringExtensions on String {
  /// Returns a truncated version with ellipsis.
  // FLAGGED at `5`: no_magic_number
  //   "Unexplained numeric literal makes the code harder to understand"
  String trimWithEllipsis({int minLength = 5}) {
    //                                    ^
    //                      Named parameter explains the 5
    if (length < minLength) return ellipsis;
    if (length < (minLength * 2) + 2) {
      return substringSafe(0, minLength) + ellipsis;
    }
    return substringSafe(0, minLength) + ellipsis +
        substringSafe(length - minLength);
  }
}
```

### Why these are NOT magic numbers

A "magic number" is an **unexplained** numeric literal whose purpose is unclear
from context. The canonical examples are:

```dart
if (retries > 3) { ... }         // Magic: what does 3 mean?
sleep(Duration(seconds: 30));     // Magic: why 30?
final buffer = List.filled(1024, 0); // Magic: why 1024?
```

But default parameter values with descriptive names are self-documenting:

```dart
void retry({int maxAttempts = 3}) { ... }    // NOT magic: name explains it
void sleep({int timeoutSeconds = 30}) { ... } // NOT magic: name explains it
void allocate({int bufferSize = 1024}) { ... } // NOT magic: name explains it
```

The parameter name `obscureLength = 3` tells you: "the obscure length defaults
to 3." The parameter name `minLength = 5` tells you: "the minimum length
defaults to 5." No additional constant is needed.

### Lint output

```
line 1077 col 63 • [no_magic_number] Unexplained numeric literal makes
the code harder to understand, maintain, and update consistently. When the
same value appears in multiple locations, a typo in one creates a subtle
bug. Readers cannot determine whether the number represents a timeout, a
threshold, a count, or an index without surrounding context. {v7}
```

### All affected locations (2 instances)

| File | Line | Value | Parameter name | Purpose |
|------|------|-------|----------------|---------|
| `lib/string/string_extensions.dart` | 1077 | `3` | `obscureLength` | Default jitter range for text obscuring |
| `lib/string/string_extensions.dart` | 1087 | `5` | `minLength` | Default minimum character count to show |

## Root cause

The rule flags all numeric literals that are not `0`, `1`, or `-1` (common
exemptions) without checking whether the literal appears in a **default
parameter value** context. In a default parameter, the parameter name itself
serves as the "named constant" that the rule is trying to enforce.

### AST context

```
// Magic number (no name context):
MethodInvocation: sleep(Duration(seconds: 30))
  └─ IntegerLiteral: 30     ← no nearby name explains "30"

// Named default parameter (has name context):
FormalParameterList
  └─ DefaultFormalParameter
       ├─ SimpleFormalParameter
       │    ├─ type: int
       │    └─ name: obscureLength    ← name explains the number
       └─ defaultValue: IntegerLiteral: 3
```

The rule needs to check if the `IntegerLiteral` node's parent is a
`DefaultFormalParameter`. If so, the parameter name provides the required
context, and the literal should not be flagged.

## Suggested fix

Skip numeric literals that appear as default values for named or optional
parameters:

```dart
void checkIntegerLiteral(IntegerLiteral node) {
  // Skip well-known values
  final value = node.value;
  if (value == 0 || value == 1 || value == -1) return;

  // Skip default parameter values -- the parameter name provides context
  final parent = node.parent;
  if (parent is DefaultFormalParameter) {
    return; // Do not flag: `{int paramName = 42}` is self-documenting
  }

  // Also skip: constructor initializer with named parameter
  // e.g., `const Duration(seconds: 30)` where the parameter name explains it
  if (parent is NamedExpression) {
    return; // Do not flag: named argument provides context
  }

  // ... existing magic number detection logic
}
```

### Optional: Also skip named arguments

The same principle applies to named arguments at call sites:

```dart
// Not magic: the parameter name `timeout` explains what 30 means
http.get(url, timeout: Duration(seconds: 30));
```

However, this is a broader change and could be a separate enhancement.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Named parameter with default value
void fetch({int maxRetries = 3}) {}

// Optional positional parameter with default
void paginate([int pageSize = 20]) {}

// Named parameter in extension method
extension on String {
  String pad({int width = 10}) => padLeft(width);
}

// Constructor named parameter
class Config {
  const Config({this.timeout = 30});
  final int timeout;
}

// Multiple named parameters with defaults
void process({
  int batchSize = 100,
  int maxConcurrency = 4,
  int retryDelay = 500,
}) {}

// Should STILL flag (true positives, no change):

// Bare numeric literal in expression
if (items.length > 42) {}  // FLAGGED: what is 42?

// Numeric literal in arithmetic
final result = value * 1024;  // FLAGGED: what is 1024?

// Numeric literal in positional argument without name context
sleep(Duration(milliseconds: 500));  // Debatable (named arg provides context)

// Numeric literal assigned to untyped variable
final x = 7;  // FLAGGED: what is 7?
```

## Impact

Default parameter values are one of the most common places for numeric literals
in Dart APIs. Any method with a named or optional parameter that has a numeric
default will be flagged:

- `Widget build({double opacity = 0.8})`
- `List<T> paginate({int pageSize = 25})`
- `Future<T> retry({int maxAttempts = 3, int delayMs = 1000})`
- `String truncate({int maxLength = 100})`

These are all self-documenting through the parameter name and should not
require extracting a constant. Forcing developers to write
`static const int kDefaultPageSize = 25` and then `{int pageSize = kDefaultPageSize}`
adds boilerplate without improving readability.
