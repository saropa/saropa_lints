# BUG: `avoid_hardcoded_api_urls` — fires on URLs already extracted to named config constants

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-26
Rule: `avoid_hardcoded_api_urls`
File: `lib/src/rules/network/api_network_rules.dart` (line ~131, pattern ~164, guard ~176)
Severity: False positive
Rule version: v6 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule reports `[avoid_hardcoded_api_urls]` on URL string literals that are
**already extracted to a named configuration constant** — the exact remediation
the rule's correction message demands ("Extract the URL to a configuration
constant"). It matches the raw literal text via regex and never checks whether
the literal *is* the right-hand side of a `const` / `static const` declaration,
a const collection entry, or an environment-config enum value. Its only escape
hatch is a filename substring check (`config` / `constants`), which misses the
common case of a config file named `env_*` or a service that holds its endpoint
in a `static const _baseUrl`.

Result: code that follows the rule's own GOOD pattern is flagged, forcing
downstream `// ignore:` workarounds on the centralized-config files that are the
correct home for these URLs.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_hardcoded_api_urls'" lib/src/rules/
lib/src/rules/network/api_network_rules.dart:148:    'avoid_hardcoded_api_urls',

# Negative — not defined in the sibling drift_advisor repo
$ grep -rln "avoid_hardcoded_api_urls" ../saropa_drift_advisor/
../saropa_drift_advisor/analysis_options.yaml   # config only, consumes saropa_lints; no rule definition
```

**Emitter registration:** `lib/src/rules/network/api_network_rules.dart:148`
**Rule class:** `AvoidHardcodedApiUrlsRule` — registered in `lib/saropa_lints.dart:892`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (`_generated_diagnostic_collection_name_#3`)

---

## Reproducer

All three shapes below put the URL in the centralized configuration location the
rule wants, yet each is flagged. (Real call sites are in the Saropa Contacts app;
structure preserved.)

```dart
// Shape 1 — environment-config enum (file: lib/env/env_type_enum.dart).
// This file IS the ApiConfig; every endpoint lives here as an enum default.
enum EnvType {
  SystemUrlAPI(
    defaultValue: 'https://api.saropa.com',     // LINT — but this is the config constant
    valueType: EnvValueType.string,
  );
}

// Shape 2 — service holds its fixed third-party endpoint in a named const.
abstract final class WikimediaBirthdayService {
  // Already extracted to a named static const — the rule's own GOOD pattern.
  static const String _baseUrl =
      'https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/births'; // LINT — should be OK
}

// Shape 3 — const map of fixed third-party service base URLs.
const Map<int, String> _avatarUrlUnseededMap = <int, String>{
  0: 'https://api.dicebear.com/9.x/lorelei/png?seed=', // LINT — centralized const map = config
};
```

**Frequency:** Always — any string literal containing an `api.` host (or a `/api`
path under a known TLD) is flagged regardless of its declaration context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the literal is the value of a named config constant / const-collection entry / env-config enum default, i.e. already extracted |
| **Actual** | `[avoid_hardcoded_api_urls] Hardcoded API URLs prevent switching…` reported on the literal |

---

## AST Context

The flagged node is a `SimpleStringLiteral`, but its ancestor chain shows it is
already a configuration constant, not an inline URL at an HTTP call site:

```
# Shape 2 (the clearest case)
ClassDeclaration (WikimediaBirthdayService)
  └─ FieldDeclaration  [static const]
      └─ VariableDeclaration (_baseUrl)
          └─ SimpleStringLiteral ('https://api.wikimedia.org/...')  ← reported here

# Shape 1
EnumDeclaration (EnvType)
  └─ EnumConstantDeclaration (SystemUrlAPI)
      └─ ... named argument `defaultValue:`
          └─ SimpleStringLiteral ('https://api.saropa.com')  ← reported here

# Shape 3
TopLevelVariableDeclaration  [const]
  └─ SetOrMapLiteral
      └─ MapLiteralEntry (value)
          └─ SimpleStringLiteral ('https://api.dicebear.com/...')  ← reported here
```

In every case the literal's enclosing declaration is `const` / `static const` —
the structural signal that it has already been extracted.

---

## Root Cause

The rule (lines 169–185) only guards on file path and then regex-matches the
literal text:

```dart
// Skip config files
final String path = context.filePath;
if (path.contains('config') || path.contains('constants')) return;

context.addSimpleStringLiteral((SimpleStringLiteral node) {
  final String value = node.value;
  if (_apiUrlPattern.hasMatch(value)) {
    reporter.atNode(node);
  }
});
```

### Hypothesis A: declaration context is never inspected

The rule reports on the bare literal without walking up to ask "is this the RHS
of a named constant?". The whole point of the rule is to push URLs *into* named
config constants — so a literal whose parent is a `const`/`static const`
`VariableDeclaration` (or a `const` collection entry, or an enum default
argument) has already satisfied the rule and should be exempt. This is the
primary mechanism.

### Hypothesis B: the filename exemption is too narrow

The `path.contains('config') || path.contains('constants')` guard is the only
exemption. A dedicated environment-config file named `env/env_type_enum.dart`
(Shape 1) contains neither substring, so it is not exempt even though it is
precisely the centralized config the rule wants. Broadening the filename guard
alone (e.g. add `env`) would fix Shape 1 but not Shapes 2 and 3, which live in
service/util files — Hypothesis A is the general fix.

---

## Suggested Fix

Prefer Hypothesis A (covers all three shapes). Before reporting, walk the
literal's ancestors and return early when the literal is already a config
constant:

- Parent is a `VariableDeclaration` whose declaration list is `const` or
  `static const` (covers Shape 2's `static const _baseUrl` and Shape 3's
  top-level `const` map — the map literal's entry value sits under a const
  `TopLevelVariableDeclaration`).
- Literal is an element/value of a `const` collection literal
  (`ListLiteral` / `SetOrMapLiteral` with `const` keyword or in a const context).
- Literal is the argument to a named parameter of an `EnumConstantDeclaration`
  / const constructor invocation (covers Shape 1's enum `defaultValue:`).

A lighter complementary fix: extend the filename guard to also skip files whose
name signals a config/env/endpoint registry (`env`, `endpoints`, `_urls`,
`api_config`). This is cheaper but only addresses Shape 1.

The rule should still fire on the genuine target: a URL literal passed inline to
`Uri.parse(...)` / `http.get(...)` at a call site, where it is NOT bound to a
named constant.

---

## Fixture Gap

The fixture at `example*/lib/api_network/avoid_hardcoded_api_urls_fixture.dart`
should include:

1. **`static const String baseUrl = 'https://api.example.com';`** — expect NO lint
   (already extracted to a named constant).
2. **`const Map<int,String> m = {0: 'https://api.example.com/x'};`** — expect NO lint
   (const collection entry).
3. **Enum constant with `defaultValue: 'https://api.example.com'`** — expect NO lint
   (env-config enum default).
4. **`await http.get(Uri.parse('https://api.example.com/users'));`** — expect LINT
   (genuine inline hardcoded URL at a call site — the real target).
5. **`final url = 'https://api.example.com';` (non-const local)** — expect LINT
   (mutable/non-const local is not "extracted to a config constant").

---

## Changes Made

Implemented Hypothesis A (covers all three shapes) in
`lib/src/rules/network/api_network_rules.dart`:

- Added `AvoidHardcodedApiUrlsRule._isAlreadyExtractedToConstant(node)`. It
  walks the literal's ancestors and returns early (no diagnostic) when the
  literal is bound to a constant: a `const` / `static const`
  `VariableDeclarationList` (Shape 2's `static const _baseUrl`, Shape 3's
  top-level `const` map), a `const` `TypedLiteral`, a `const`
  `InstanceCreationExpression`, or an `EnumConstantDeclaration` (Shape 1's
  enum `defaultValue:`, whose constructor is implicitly const). The walk stops
  at the nearest `FunctionBody` so inline call-site URLs are still flagged.
- `runWithReporter` now calls the guard before `reporter.atNode`.
- Bumped rule message tag `{v6}` → `{v7}` and updated the doc-comment rule
  version (`v5` → `v7`) with a one-line note on the new exemption.

The narrow filename guard (`config` / `constants`) is retained as a cheap
pre-filter; the ancestor walk is the general fix.

---

## Tests Added

`example/lib/api_network/avoid_hardcoded_api_urls_fixture.dart` extended with
the five cases from the bug:

1. `static const String baseUrl = '...'` — NO lint (already extracted).
2. `const Map<int,String> { 0: '...' }` — NO lint (const collection entry).
3. enum constant `defaultValue: '...'` — NO lint (env-config enum default).
4. inline `http.get(Uri.parse('https://api.example.com/users'))` — LINT.
5. mutable `final url = 'https://api.example.com'` — LINT.

Verified with the scan CLI against a scratch reproducer: `avoid_hardcoded_api_urls`
fires only on cases 4 and 5; the three const shapes are exempt.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: rule v6 (native analyzer plugin)
- Dart SDK version: (Saropa Contacts toolchain)
- custom_lint version: n/a — native `analysis_server_plugin`
- Triggering project/file: Saropa Contacts —
  `lib/env/env_type_enum.dart` (lines 173, 245, 258),
  `lib/service/wikimedia/wikimedia_birthday_service.dart` (line 25),
  `lib/utils/primitive/generate_random/contact_parts/random_avatar_utils.dart` (lines 177–182)

---

## Finish Report (2026-06-26)

`avoid_hardcoded_api_urls` regex-matched any string literal containing an
`api.` host or `/api` path and reported it without inspecting the literal's
declaration context. The rule's own remediation — extract the URL to a named
configuration constant — was therefore flagged as a violation, forcing
`// ignore:` workarounds on the centralized-config files that are the correct
home for these endpoints. The only exemption was a filename substring check
(`config` / `constants`), which missed config files named otherwise and any
service or util holding its endpoint in a `static const`.

### Resolution

Hypothesis A from the report was implemented in
`AvoidHardcodedApiUrlsRule.runWithReporter`
(`lib/src/rules/network/api_network_rules.dart`). A new ancestor-walk guard,
`_isAlreadyExtractedToConstant`, returns early when the literal is bound to a
constant: a `const` / `static const` `VariableDeclarationList`, a `const`
`TypedLiteral`, a `const` `InstanceCreationExpression`, or an
`EnumConstantDeclaration` (enum constructor arguments are implicitly const).
The walk halts at the nearest `FunctionBody`, so a URL reached only through
executable code (an inline `Uri.parse('https://api...')` at a call site)
remains flagged. The filename guard is retained as a cheap pre-filter; the
ancestor walk is the general fix and covers all three reported shapes
(static-const field, const collection entry, env-config enum default).

The rule message tag was bumped `{v6}` → `{v7}` and the doc-comment rule
version `v5` → `v7`.

### Verification

- `dart test test/rules/network/api_network_rules_test.dart` — 81 passed.
- `dart test test/integrity/api_network_fixture_expect_lint_contract_test.dart`
  — 25 passed.
- Scan CLI against a scratch reproducer of all five shapes: the rule fires only
  on the inline call-site literal and the mutable non-const local; the three
  const shapes produce no diagnostic.

### Files changed

- `lib/src/rules/network/api_network_rules.dart` — guard + version bumps.
- `example/lib/api_network/avoid_hardcoded_api_urls_fixture.dart` — added the
  three exempt (NO-lint) shapes and a second BAD case (mutable local).
- `CHANGELOG.md` — `[Unreleased]` Fixed entry.
