# BUG: `avoid_mixed_environments` — false positive on substring matches of "release" / "test" in unrelated identifiers

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_mixed_environments`
File: `lib/src/rules/config/config_rules.dart` (line ~320)
Severity: False positive
Rule version: v4 | Since: v4.1.6 | Updated: v4.13.0

---

## Summary

The rule's prod/dev indicator regexes substring-match without word
boundaries, so `release` matches inside `release_notes` and `test`
matches inside `latest`. A config class that has nothing to do with
environment separation (a bundled release-notes catalog) is flagged as
"mixing production and development configuration". Expected: no
diagnostic — neither `release_notes` nor `latest` denotes a release-mode
or test-mode environment.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_mixed_environments'" lib/src/rules/
lib/src/rules/config/config_rules.dart:313:    'avoid_mixed_environments',

# Negative — NOT a rule definition in the sibling drift-advisor repo
$ grep -rn "'avoid_mixed_environments'" ../saropa_drift_advisor/lib/ ../saropa_drift_advisor/extension/
# 0 matches (the only hit in that repo is its analysis_options.yaml config reference)
```

**Emitter registration:** `lib/src/rules/config/config_rules.dart:312` (`AvoidMixedEnvironmentsRule`, class at line 293)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

Minimal — a config class whose identifiers merely *contain* the
substrings `release` and `test`:

```dart
abstract final class ReleaseNotesConfig {
  const ReleaseNotesConfig._();

  // "release_notes" contains "release" → matches _prodPattern.
  static const String assetPath =
      'assets/data/release_notes/release_notes.json'; // LINT (false positive — reported here)

  // "Latest" contains "test" → matches _devPattern.
  static const int expectedLatestBuildNumber = 2026020101; // contributes the dev flag
  static const int expectedLatestBuildItemCount = 25;
}
```

Both indicators trip → the rule reports the first "prod" member
(`assetPath`). No production-vs-development environment configuration
exists in this class.

**Frequency:** Always, for any `*Config` / `*Settings` / `*Environment`
class containing both an identifier with the substring `release` (e.g.
`release_notes`, `prerelease`) and one with `test`/`dev`/`local` (e.g.
`latest`, `developer`, `localeName`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `release_notes` / `latest` are not environment indicators |
| **Actual** | `[avoid_mixed_environments] Mixing production and development configuration …` reported at the `assetPath` field |

---

## AST Context

```
ClassDeclaration (ReleaseNotesConfig)   ← name contains "config", so checked
  ├─ FieldDeclaration (assetPath)        ← _prodPattern matches "release" in value → firstProdMember, REPORTED here
  ├─ FieldDeclaration (expectedLatestBuildNumber)  ← _devPattern matches "test" in name "Latest"
  └─ FieldDeclaration (expectedLatestBuildItemCount)
```

---

## Root Cause

`lib/src/rules/config/config_rules.dart:320-328`:

```dart
static final RegExp _prodPattern = RegExp(
  r'(prod|production|live|release)',
  caseSensitive: false,
);

static final RegExp _devPattern = RegExp(
  r'(dev|development|debug|staging|test|local|localhost)',
  caseSensitive: false,
);
```

Neither pattern is anchored to word boundaries, so `hasMatch` succeeds on
any substring occurrence:

- `release` ⊂ `release_notes` (and `prerelease`, `releaseDate`, …)
- `test` ⊂ `latest` (and `greatest`, `contest`, `attestation`, …)
- `dev` ⊂ `developer`, `device`, `deviation`
- `live` ⊂ `delivery`, `oliveColor`
- `local` ⊂ `locale`, `localizedName`

These are extremely common English fragments. The matcher in
`runWithReporter` (lines 365-379) checks `_prodPattern.hasMatch(source)`
/ `_prodPattern.hasMatch(varName)` with no tokenization, so any class
named `*Config`/`*Settings`/`*Environment` that happens to contain one
fragment from each list is flagged.

The intended signal is whole-word environment identifiers
(`prod`, `production`, `live`, `release`, `dev`, `staging`, `test`,
`local`), not arbitrary substrings.

---

## Suggested Fix

Anchor both regexes with word boundaries that treat `_`, camelCase, and
the start/end of the identifier as separators. A simple, low-risk change
is to require a non-alphabetic boundary on each side:

```dart
// (?<![A-Za-z]) and (?![A-Za-z]) so the token must be a standalone word,
// not a substring of a larger identifier. "release_notes" no longer
// matches "release"; "latest" no longer matches "test".
static final RegExp _prodPattern = RegExp(
  r'(?<![A-Za-z])(prod|production|live|release)(?![A-Za-z])',
  caseSensitive: false,
);

static final RegExp _devPattern = RegExp(
  r'(?<![A-Za-z])(dev|development|debug|staging|test|local|localhost)(?![A-Za-z])',
  caseSensitive: false,
);
```

Note: a bare `\b` does NOT fix the `_` case — `_` is a word character, so
`\brelease\b` still matches `release_notes`. The lookaround on
`[A-Za-z]` correctly treats `_` and digits as separators while still
catching `apiUrlProd`, `prodApiKey`, `debug_mode`, `isRelease`, etc.

Consider also restricting value matches (`init.toSource()`) to
identifier-like tokens rather than scanning string-literal *contents* —
an asset path or URL that merely contains the word "release" in a folder
name is not an environment indicator. At minimum the word-boundary fix
removes the substring class of false positives.

---

## Fixture Gap

The fixture at
`example/lib/config/avoid_mixed_environments_fixture.dart` should add
NO-lint cases proving substrings are not treated as environment tokens:

1. **`ReleaseNotesConfig` with `assetPath` (`release_notes`) + `expectedLatestBuildNumber` (`latest`)** — expect NO lint
2. **A `*Config` with `latestVersion` + `releaseDate` fields** — expect NO lint
3. **A `*Settings` with `developerName` + a `liveDelivery` field** — expect NO lint (`dev` ⊂ developer, `live` ⊂ delivery)
4. Keep an existing positive case (`apiUrlProd` + `debugFlag`) — expect LINT — to prove the boundary fix does not weaken true detection

---

## Environment

- saropa_lints version: 13.12.2
- Triggering project/file: `saropa` (Contacts) — `lib/data/release_notes/release_notes_config.dart:40`
