# Task: `prefer_noun_class_names`

## Summary
- **Rule Name**: `prefer_noun_class_names`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Naming Conventions

## Problem Statement
Object-oriented design is built on the principle that classes represent things (nouns): entities, concepts, value objects, services, repositories. When a class is named with a gerund (verb + `-ing`) or an adjective form (`-able`, `-ible`), it signals a conceptual confusion: the class is named after an action or a capability rather than an entity.

For example:
- `class Parsing` should be `class Parser` — the class is not the act of parsing, it is the thing that parses.
- `class Running` should be `class Runner` — the class is not the act of running, it is the thing that runs.
- `class Configuring` should be `class Configurator` or `class Configuration`.

This naming confusion is common in codebases where developers come from languages or frameworks that encourage gerund-based naming for strategy objects or state machine nodes. While not a bug, it degrades code readability and communicability.

Note that abstract classes and mixins named with `-able` (`Comparable`, `Disposable`, `Serializable`) are an established and accepted Dart/Java convention for capability-describing mixins. These are explicitly excluded.

## Description (from ROADMAP)
Flag class declarations whose names use gerund form (ending in `-ing`) or adjective form (`-able`/`-ible`) for concrete classes, suggesting a rename to the equivalent noun/agent form (e.g., `Parser`, `Runner`, `Configurator`).

## Trigger Conditions
The rule triggers when:
1. A `ClassDeclaration` is found for a **concrete** class (not abstract, not mixin).
2. The class name ends with `ing` (gerund) — e.g., `Parsing`, `Running`, `Configuring`.
3. OR the class name ends with `able` or `ible` (adjective form) and the class is concrete (not abstract).

It does NOT trigger for:
- Abstract classes ending in `-able`/`-ible` (these are legitimate capability mixins).
- Mixin declarations (different naming conventions apply).
- Names ending in `-ing` that are established Dart/Flutter conventions (e.g., `Padding`, `Spacing` — but note these are actually nouns in English).
- Test classes.
- Generated code.
- Enum declarations.

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  if (node.abstractKeyword != null) return; // exclude abstract classes
  _checkClassName(node, reporter);
});
```

### Detection Logic

**Step 1 — Check for gerund ending (`-ing`):**

```dart
final name = node.name.lexeme;
const _ingAllowList = {
  // Common English nouns that end in -ing and are correct class names
  'Padding', 'Spacing', 'Heading', 'Billing', 'Setting',
  'Warning', 'Greeting', 'Logging', 'Encoding', 'Binding',
  'Routing', 'Mapping', 'Sorting', 'Filtering', 'Caching',
  'Loading', 'Threading', // Sometimes used as concept names
};

if (name.endsWith('ing') && !_ingAllowList.contains(name)) {
  reporter.atToken(node.name, code);
  return;
}
```

**Step 2 — Check for adjective ending (`-able`/`-ible`) on concrete classes:**

```dart
if ((name.endsWith('able') || name.endsWith('ible')) &&
    node.abstractKeyword == null) {
  reporter.atToken(node.name, code);
}
```

**Step 3 — Provide suggested rename in the problem message:**

Use a helper to suggest the agent/noun form:
- Remove `-ing` suffix and add `-er` or `-or` where applicable (heuristic only).
- Remove `-able`/`-ible` and add `-er`, `-or`, or suggest "consider renaming to a noun form".

The suggestion should appear in `correctionMessage` as guidance, not as an automated rename.

## Code Examples

### Bad (triggers rule)
```dart
// Gerund form — names an action, not an entity
class Parsing {
  String parse(String input) => input.trim();
}

class Running {
  void run() { }
}

class Configuring {
  final Map<String, String> settings = {};
}

// Concrete class with -able suffix
class Sortable {
  void sort() { }
}

class Cacheable {
  final _cache = <String, dynamic>{};
}
```

### Good (compliant)
```dart
// Noun/agent form
class Parser {
  String parse(String input) => input.trim();
}

class Runner {
  void run() { }
}

class Configurator {
  final Map<String, String> settings = {};
}

// Abstract class with -able is fine (capability mixin)
abstract class Sortable {
  void sort();
}

abstract class Cacheable {
  dynamic getFromCache(String key);
}

// Mixin with -able is fine
mixin Disposable {
  void dispose();
}
```

## Edge Cases & False Positives
- **English nouns ending in `-ing`**: Many genuine English nouns end in `-ing` and are perfectly valid class names: `Padding`, `Spacing`, `Heading`, `Warning`, `Binding`, `Routing`, `Mapping`, `Setting`, `Billing`, `Greeting`. These must be in an allowlist. Maintaining this list is a significant ongoing effort.
- **Abstract classes with `-able`**: `Comparable`, `Disposable`, `Serializable`, `Equatable` are established Dart patterns. The rule already excludes abstract classes from the `-able`/`-ible` check. Ensure `abstract class Sortable` does not trigger.
- **Mixin declarations**: `mixin Runnable` or `mixin Cacheable` are valid. Use `addMixinDeclaration` separately and exclude mixins from both checks.
- **Generated code**: `build_runner` may generate classes with gerund names. Detect generated files by presence of `// GENERATED CODE` header or `.g.dart`/`.freezed.dart` suffix.
- **Test classes**: `class TestRunning` or `class MockParsing` in test files should be excluded.
- **Domain language**: Some domains use gerund class names intentionally (e.g., a state machine where `Running` is a valid state name). The rule should be suppressable with `// ignore: prefer_noun_class_names`.
- **Third-party extension**: When subclassing a third-party class that uses gerund naming, the subclass may need to follow the same pattern for clarity. Consider checking if the class has a superclass with gerund naming.
- **`ing` allowlist completeness**: The allowlist of valid `-ing` nouns will never be complete. Accept that there will be false positives for unusual but valid noun forms, and document that `// ignore:` is available.

## Unit Tests

### Should Trigger (violations)
```dart
// Gerund forms — concrete classes
class Parsing { } // LINT
class Running { } // LINT
class Configuring { } // LINT
class Validating { } // LINT
class Caching { } // LINT — but wait, this is also a noun... see edge cases

// Concrete -able classes
class Sortable { } // LINT
class Cacheable { } // LINT
class Exportable { } // LINT
```

### Should NOT Trigger (compliant)
```dart
// Valid noun names
class Parser { } // OK
class Runner { } // OK
class Validator { } // OK
class Cache { } // OK

// Allowlisted -ing nouns
class Padding { } // OK — genuine English noun
class Setting { } // OK
class Warning { } // OK
class Binding { } // OK

// Abstract classes with -able — valid capability descriptors
abstract class Sortable { } // OK
abstract class Comparable { } // OK
mixin Disposable { } // OK — mixin

// Test classes
class RunningTest { } // OK — test context
```

## Quick Fix
No automated rename is provided because:
1. The correct rename depends on the semantics of the class (is it an `-er` agent, `-or` agent, `-tion` abstract concept, or something else?).
2. Renaming a class is a project-wide operation that affects all files.

The `correctionMessage` should guide the developer:
```
correctionMessage: 'Rename the class to a noun form. For a gerund name like "Parsing", consider "Parser". For an -able name like "Sortable" on a concrete class, consider extracting an abstract class or using the class as a mixin.'
```

## Notes & Issues
- The `-ing` allowlist is the most fragile part of this rule. Consider sourcing it from a curated word list or using a configurable option in `analysis_options.yaml`.
- The rule intentionally targets only the most obvious cases (concrete gerund classes and concrete `-able` classes). A broader heuristic covering all verb-named classes would require NLP.
- This rule pairs well with `prefer_verb_method_names` (file 2) — together they enforce a consistent noun/verb split between classes and methods.
- Consider whether `extension` declarations should also be checked. Extension names like `StringParsing` are non-standard; `StringParser` or `StringExtensions` would be better.
- Track false positive reports from early adopters and expand the allowlist accordingly. Use GitHub issues labeled `false-positive` to collect cases.
