<!-- markdownlint-disable MD036 MD060 MD040 -->

# BUG: `avoid_hardcoded_config` — False positive in dedicated constants files

## Status: Fixed

Created: 2026-04-13
Rule: `avoid_hardcoded_config`
File: `lib/src/rules/config/config_rules.dart` (line ~52)
Severity: False positive
Rule version: v5 | Fixed in repo (Unreleased)

---

## Summary

The rule fires on URL literals declared as `static const` fields inside a dedicated constants class (`ServerConstants`). A constants file is the *fix* for hardcoded config scattered through business logic — flagging it there is counterproductive and forces `// ignore:` suppressions on correct code.

---

## Reproducer

```dart
/// Centralized server constants — the single source of truth for
/// magic strings, URLs, and version info used across the package.
class ServerConstants {
  ServerConstants._();

  static const String packageVersion = '3.2.0';

  /// jsDelivr CDN base URL for serving web assets.
  static const String cdnBaseUrl =
      'https://cdn.jsdelivr.net/gh/saropa/saropa_drift_advisor'; // LINT — but should NOT lint (false positive)

  static const String queryParamLimit = 'limit'; // OK — not a URL/port/key
}
```

**Frequency:** Always — any URL/port constant in a `*_constants.dart` file triggers it.

---

## Expected vs Actual

| | Behavior |
| --- | --- |
| **Expected** | No diagnostic — a dedicated constants class is the recommended centralization pattern |
| **Actual** | `[avoid_hardcoded_config] Hardcoded configuration value detected...` reported on `cdnBaseUrl` |

---

## AST Context

```text
CompilationUnit (server_constants.dart)
  └─ ClassDeclaration (ServerConstants)
      └─ FieldDeclaration (static const)
          └─ VariableDeclaration (cdnBaseUrl)
              └─ SimpleStringLiteral ('https://cdn.jsdelivr.net/...')  ← node reported here
```

The string literal is inside a `static const` field in a class whose sole purpose is centralizing configuration values. The rule's correction message ("Use String.fromEnvironment, dotenv, or a config service") does not apply — this constant IS the config service's backing store.

---

## Root Cause

### Hypothesis A: No exemption for constants-class context

The rule likely checks whether a string literal matches URL/port/key patterns but does not consider the enclosing declaration context. A `static const` field inside a class named `*Constants` (or in a file named `*_constants.dart`) is the centralized location the rule's own correction message recommends.

### Hypothesis B: No exemption for `static const` declarations at class level

Even without filename heuristics, a `static const String` field declaration is fundamentally different from an inline string literal in a method body. The rule does not distinguish between these contexts.

---

## Suggested Fix

Add an exemption when the string literal is the initializer of a `static const` field declaration at class level. Possible approaches (in order of precision):

1. **AST parent check**: If the `SimpleStringLiteral` is the initializer of a `VariableDeclaration` whose parent is a `FieldDeclaration` with `isStatic` and `isFinal`/`isConst` modifiers, skip it. This is the most precise — it exempts exactly the "named constant" pattern regardless of class name or file name.

2. **Filename heuristic**: If the file path matches `*_constants.dart` or `*_config.dart`, reduce severity or skip. Less precise but simpler.

3. **Class-name heuristic**: If the enclosing `ClassDeclaration` name ends with `Constants` or `Config`, skip. Middle ground.

Approach 1 is recommended because it handles constants defined anywhere (not just in conventionally named files) and avoids false negatives in config files that also contain non-constant methods.

---

## Fixture Gap

The fixture at `example*/lib/config/avoid_hardcoded_config_fixture.dart` should include:

1. **`static const String` URL in a constants class** — expect NO lint
2. **`static const int` port in a constants class** — expect NO lint
3. **Top-level `const String` URL** — expect NO lint (same reasoning — named constant)
4. **Inline URL string in a method body** — expect LINT (existing case, should still fire)
5. **`final` (non-const) field initialized with URL** — expect LINT (mutable config is the problem)

---

## Changes Made

- `AvoidHardcodedConfigRule`: skip when `VariableDeclaration` is under a `const` `VariableDeclarationList` whose parent is `TopLevelVariableDeclaration`, or `FieldDeclaration` with `isStatic` (i.e. top-level const or `static const` fields).
- Same exemption applied to `AvoidHardcodedConfigTestRule` via `_isHardcodedConfig`.
- Rule message tag bumped `{v4}` → `{v5}`; DartDoc BAD/GOOD examples adjusted.
- Fixture `example_async/lib/config/avoid_hardcoded_config_fixture.dart` expanded; `test/config_rules_test.dart` asserts marker layout.

---

## Tests Added

- `test/config_rules_test.dart` — fixture structure tests for `avoid_hardcoded_config` (two `expect_lint` sites; const centralization lines must not carry `expect_lint`).

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 10.11.1
- Dart SDK version: 3.x
- custom_lint version: (current)
- Triggering project/file: `saropa_drift_advisor/lib/src/server/server_constants.dart` line 127
