# `avoid_unmarked_public_class` false positive: static utility classes

## Status: OPEN

## Summary

The `avoid_unmarked_public_class` rule (v3) fires on static utility classes in `saropa_dart_utils`, including classes with **private constructors** (`ClassName._()`) that already prevent instantiation and extension, and classes with **only static members** that have no extensible instance API. The rule demands adding a Dart 3.0 class modifier (`base`, `final`, `interface`, or `sealed`), but for static-only utility classes — especially those with private constructors — the modifier is redundant. For a published Dart utility package where all flagged classes are static namespaces, the rule generates noise without identifying any actual API stability risk.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/datetime/date_time_utils.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_unmarked_public_class
severity: 2 (info)
message:  [avoid_unmarked_public_class] Public class lacks an explicit class
          modifier. Dart 3.0 introduced class modifiers (base, final, interface,
          sealed). For API stability, public classes should declare their
          inheritance intent. {v3}
          Add base, final, interface, or sealed modifier (Dart 3.0+). Verify
          the change works correctly with existing tests and add coverage for
          the new behavior.
line:     0
```

## Affected Source

The rule fires on utility classes across the `saropa_dart_utils` package. All flagged classes share the same pattern: static-only methods with a private constructor that prevents instantiation and extension.

### Pattern 1: Static utility class with private constructor

File: `lib/base64/base64_utils.dart` line 17

```dart
class Base64Utils {
  const Base64Utils._(); // Private constructor — cannot be instantiated or extended

  static String? compressText(String? value) { ... }
  static String? decompressText(String? compressedBase64) { ... }
}
```

Additional examples following the same pattern: `JsonUtils` (`lib/json/json_utils.dart:29`), `HtmlUtils` (`lib/html/html_utils.dart:67`), `MonthUtils` (`lib/datetime/date_constants.dart:74`), `UrlUtils` (`lib/url/url_extensions.dart:144`).

### Full list of affected classes

| File | Line | Class | Private Constructor |
|------|------|-------|-------------------|
| `lib/base64/base64_utils.dart` | 17 | `Base64Utils` | Yes (`const Base64Utils._()`) |
| `lib/datetime/date_constants.dart` | 62 | `DateConstants` | No (static fields only) |
| `lib/datetime/date_constants.dart` | 74 | `MonthUtils` | Yes (`const MonthUtils._()`) |
| `lib/datetime/date_constants.dart` | 120 | `WeekdayUtils` | Yes (`const WeekdayUtils._()`) |
| `lib/datetime/date_constants.dart` | 155 | `SerialDateUtils` | Yes (`const SerialDateUtils._()`) |
| `lib/datetime/date_time_utils.dart` | 9 | `DateTimeUtils` | No (all static methods) |
| `lib/datetime/time_emoji_utils.dart` | 4 | `TimeEmojiUtils` | No (static methods + constants) |
| `lib/gesture/swipe_properties.dart` | 79 | `Swipe` | No (data class with `const` constructor) |
| `lib/gesture/swipe_properties.dart` | 196 | `GestureUtils` | No (static methods) |
| `lib/html/html_utils.dart` | 67 | `HtmlUtils` | Yes (`const HtmlUtils._()`) |
| `lib/int/int_utils.dart` | 20 | `IntUtils` | No (static methods) |
| `lib/json/json_utils.dart` | 20 | `JsonIterablesUtils` | No (static methods with generic) |
| `lib/json/json_utils.dart` | 29 | `JsonUtils` | Yes (`const JsonUtils._()`) |
| `lib/url/url_extensions.dart` | 144 | `UrlUtils` | Yes (`const UrlUtils._()`) |

## Root Cause

The rule checks all `ClassDeclaration` nodes for the presence of a Dart 3.0 class modifier (`base`, `final`, `interface`, `sealed`). It does not check whether:

1. The class has a **private constructor** (preventing instantiation and extension)
2. The class contains **only static members** (no instance API to protect)
3. The class is a **utility namespace** (common Dart pattern for grouping static methods)

The rule treats all unmodified public classes identically, regardless of whether they have any extensible surface area.

### Why private constructors already prevent extension

In Dart, a class with only private constructors (`ClassName._()`) cannot be:

- **Instantiated** by external code — the constructor is inaccessible
- **Extended** — subclasses must call a super constructor, and no public constructor exists
- **Implemented** — while technically possible with `implements`, it is meaningless for a static-only class

Adding `final class` to `Base64Utils` or `JsonUtils` does not change any runtime behavior or API contract. The private constructor already communicates "this class is not meant to be extended."

## Why This Is a False Positive

1. **Private constructor already guards against extension** — `const Base64Utils._()` prevents any consumer from extending or instantiating the class. Adding `final` is redundant.

2. **Static-only classes have no extensible API** — These classes contain only `static` methods. There are no instance members to protect with a class modifier. The modifier adds no safety.

3. **Redundant modifier adds noise** — For a published package with 15+ utility classes, adding `final` to each one clutters the code without providing any benefit. The private constructor is already the standard Dart idiom for "do not extend."

4. **The rule does not distinguish class purposes** — It treats a data class like `Swipe` (which has a public constructor and instance fields) the same as a static namespace like `JsonUtils` (which has only static methods and a private constructor). These have fundamentally different extension concerns.

5. **`abstract final class` would be more appropriate** — For static-only utility classes, the Dart team recommends `abstract final class` (prevents instantiation and extension). But the rule just says "add a modifier" without distinguishing which modifier is appropriate for which class shape.

6. **API compatibility concern** — Adding `final` to public classes in a published package is technically a **breaking change** under semver, because it prevents consumers who may have been extending the class (even if they shouldn't have been). This requires a major version bump.

## Scope of Impact

Any Dart project using the static-utility-class-with-private-constructor pattern will trigger this rule. This is an extremely common pattern:

```dart
// Standard Dart utility class pattern — used everywhere
class MyUtils {
  const MyUtils._();
  static String helper() => 'help';
}
```

Examples of well-known packages using this pattern without class modifiers:
- `path` package — `path.Context` class
- `http` package — `http.Client` (abstract, but utility classes are not)
- Flutter SDK — many utility classes predate Dart 3.0

## Recommended Fix

### Approach A: Skip classes with only private constructors (recommended)

If a class has one or more constructors and ALL of them are private (named with `_` prefix), the class already communicates "do not extend." Skip it:

```dart
context.addClassDeclaration((ClassDeclaration node) {
  // Skip classes that already have a modifier
  if (node.abstractKeyword != null || node.sealedKeyword != null ||
      node.baseKeyword != null || node.finalKeyword != null ||
      node.interfaceKeyword != null) {
    return;
  }

  // Skip classes with only private constructors — already guarded
  final List<ConstructorDeclaration> constructors = node.members
      .whereType<ConstructorDeclaration>()
      .toList();
  if (constructors.isNotEmpty &&
      constructors.every((ConstructorDeclaration c) =>
          c.name?.lexeme.startsWith('_') ?? false)) {
    return;  // All constructors are private — extension is prevented
  }

  reporter.atToken(node.name, code);
});
```

### Approach B: Skip static-only classes

If every member of a class is `static` (plus an optional private constructor), the class is a namespace, not an extensible type:

```dart
final bool isStaticOnly = node.members.every((ClassMember m) {
  if (m is ConstructorDeclaration) return true; // constructors are fine
  if (m is MethodDeclaration) return m.isStatic;
  if (m is FieldDeclaration) return m.isStatic;
  return false;
});
if (isStaticOnly) return;
```

### Approach C: Differentiate the diagnostic by class shape

Instead of one generic message, provide class-shape-specific guidance:

- For static-only classes: suggest `abstract final class` (prevents both instantiation and extension)
- For data classes with public constructors: suggest `final class`
- For classes intended to be extended: suggest `base class`

**Recommendation:** Approach A is the simplest and most precise. Private constructors are a clear signal that extension is already prevented. Approach B adds additional precision for classes without private constructors that are still static-only.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Private constructor prevents extension — modifier is redundant.
class _good_Base64Utils {
  const _good_Base64Utils._();
  static String? compress(String? value) => value;
}

// GOOD: Private constructor + all static members.
class _good_JsonUtils {
  const _good_JsonUtils._();
  static Map<String, dynamic>? decode(String? json) => null;
  static bool isValid(String? json) => false;
}

// GOOD: Already has a modifier.
final class _good_FinalUtils {
  const _good_FinalUtils._();
  static String helper() => 'help';
}

// GOOD: Abstract final — recommended for static-only classes.
abstract final class _good_AbstractFinalUtils {
  static String helper() => 'help';
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Public class with public constructor — no modifier, extensible.
// expect_lint: avoid_unmarked_public_class
class _bad_OpenClass {
  final String name;
  _bad_OpenClass(this.name);
  String greet() => 'Hello, $name';
}

// BAD: Public class with default constructor — no modifier, extensible.
// expect_lint: avoid_unmarked_public_class
class _bad_DataModel {
  final int id;
  final String title;
  _bad_DataModel({required this.id, required this.title});
}
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v3)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (published Dart utility package)
- **Trigger file:** `lib/datetime/date_time_utils.dart` (and 14+ other files)
- **Trigger class pattern:** Static utility classes with private constructors
- **Violation count in project:** 1 recorded in violations.json (likely more pending full scan)
- **Package version:** 1.0.6 on pub.dev

## Severity

Low — info-level diagnostic. The false positive recommends adding a class modifier that is redundant when a private constructor already prevents extension. The impact is primarily noise: in a utility package like `saropa_dart_utils` with 15+ utility classes, every class triggers this rule, drowning out more actionable diagnostics. For published packages, following the advice requires a major version bump (adding `final` is a breaking change under semver), which is disproportionate to the zero-risk scenario of static-only classes with private constructors.
