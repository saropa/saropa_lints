# BUG: `depend_on_referenced_packages` — saropa rule shadows identically-named Dart SDK lint, causing double-reporting

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Rule: `depend_on_referenced_packages`
File: `lib/src/rules/config/config_rules.dart` (line 1258, class `DependOnReferencedPackagesRule`)
Severity: High — inflates every downstream issue count by up to 2× on projects that enable both the SDK lint (via `package:lints/core.yaml`, `package:flutter_lints/flutter.yaml`, or a manual `linter: rules:` block) and the saropa_lints tier that enables this rule.
Rule version: v1 | Since: unknown | Updated: unknown

---

## Summary

`saropa_lints` defines its own rule class `DependOnReferencedPackagesRule` with the LintCode string `'depend_on_referenced_packages'` — **the same rule ID as the Dart SDK's built-in lint `depend_on_referenced_packages`** (shipped in `package:lints/core.yaml`, included transitively by `package:lints/recommended.yaml` and `package:flutter_lints/flutter.yaml`). When a project enables both (the normal configuration — saropa_lints is a plugin, not a replacement for SDK lints), every qualifying `package:foo/foo.dart` import triggers **two independent diagnostics with the same code**: one from the analyzer core, one from the custom_lint plugin. Every downstream count — Problems panel, `violations.json`, `reports/<date>/*_saropa_lint_report.log` — is inflated.

Observed on `saropa-contacts` at `recommended` tier: 22,695 reported violations for this rule ([reports/20260424/20260424_093112_saropa_lint_report.log](../../contacts/reports/20260424/20260424_093112_saropa_lint_report.log) line 28), accounting for 96.8% of the 23,434-issue total. A spot check of flagged imports in [lib/components/primitive/animation/common_inkwell.dart](../../contacts/lib/components/primitive/animation/common_inkwell.dart) finds `package:flutter/material.dart` (declared in pubspec) and `package:saropa/...` (the project's own package) — both cases the rule's own logic explicitly skips — which further suggests either over-firing **or** 1:1 shadowing with the SDK lint whose messages surface under the same rule ID.

---

## Attribution Evidence

```bash
# Positive — the rule IS defined in saropa_lints
grep -rn "'depend_on_referenced_packages'" lib/src/rules/
# lib/src/rules/config/config_rules.dart:1274:    'depend_on_referenced_packages',
```

**Emitter registration:** `lib/src/rules/config/config_rules.dart:1258` (`DependOnReferencedPackagesRule extends SaropaLintRule`).
**LintCode string:** `lib/src/rules/config/config_rules.dart:1274` — `LintCode('depend_on_referenced_packages', ...)` — identical to the SDK lint ID.
**Rule class:** `DependOnReferencedPackagesRule` — registered via the standard saropa_lints rule-factory list.
**Diagnostic `source` / `owner` in Problems panel:** `saropa_lints` (when the custom_lint plugin emits it) or `dart` (when the SDK analyzer emits it). Same rule ID, two owners.

**Downstream consumer evidence:** the project under test enables BOTH sources:
- [contacts/analysis_options.yaml:122](../../contacts/analysis_options.yaml#L122) — `depend_on_referenced_packages: true` under `linter: rules:` (this is the SDK lint, enabled as part of the manually-flattened `core.yaml` block documented above it in the same file)
- [contacts/analysis_options.yaml:576](../../contacts/analysis_options.yaml#L576) — `depend_on_referenced_packages: true` under `plugins: saropa_lints:` (this is the saropa rule)

Both are the normal, expected configuration path — nothing in the project is "misconfigured". Both are enabled because saropa_lints' `recommended` tier includes the rule AND `package:lints/core.yaml` includes it.

---

## Reproducer

Any project that (a) includes one of `package:lints/core.yaml`, `package:lints/recommended.yaml`, or `package:flutter_lints/flutter.yaml` (either via `include:` or via a manually-flattened rules list) AND (b) enables the `saropa_lints` tier that activates `depend_on_referenced_packages`:

1. Create a minimal Flutter project. Add `flutter_lints` and `saropa_lints` as dev dependencies.
2. In `analysis_options.yaml`:

   ```yaml
   include: package:flutter_lints/flutter.yaml    # transitively enables SDK's depend_on_referenced_packages
   plugins:
     saropa_lints:
       version: "12.3.4"
       rules:
         depend_on_referenced_packages: true      # enables saropa's copy
   ```

3. Add a Dart file that imports a transitive-only package (one that is pulled in by a direct dependency but is not itself listed in `pubspec.yaml`):

   ```dart
   // example: http is pulled in by some transitive dep but not declared directly
   import 'package:http/http.dart';   // expect ONE diagnostic, observe TWO
   ```

4. Run `dart analyze` (or `flutter analyze`). Observe two diagnostics on the same line with the same rule code — one owned by the SDK analyzer, one owned by the `saropa_lints` custom_lint plugin.

5. Alternatively, load `reports/<date>/<ts>_saropa_lint_report.log` or `reports/.saropa_lints/violations.json` after an extension `Run Analysis` — count is inflated by the sum of both sources.

**Frequency:** Always, when both enablement paths are active. On `saropa-contacts` this is the default configuration — the user had no opt-in choice.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Exactly one diagnostic per qualifying import — either the SDK lint (preferred, since the user already opted into `flutter_lints` / `lints`) OR saropa's version, never both. The saropa rule should either use a distinct name (e.g. `saropa_depend_on_referenced_packages`) or detect at registration time that the SDK lint is enabled and skip its own registration. |
| **Actual** | Two diagnostics per import when both are enabled. Every downstream count (Problems panel, `violations.json`, report logs, health score) is inflated by up to 2×. The `TOP RULES` table in the analysis report shows the rule at position 1 with 22,695 firings on saropa-contacts, which is at most half the real figure and likely includes separate over-firing on legitimately-declared imports (see "Secondary concern" below). |

---

## AST Context

Not AST-specific — the bug is at rule-registration time, not inside the rule's detection logic. The detection logic itself ([config_rules.dart:1285-1316](lib/src/rules/config/config_rules.dart#L1285-L1316)) is written correctly:

```
ImportDirective
  └─ node.uri.stringValue ("package:foo/foo.dart")
      └─ extract "foo"
          └─ if foo == ownPackage → skip
          └─ if hasDependency(filePath, "foo") → skip
          └─ else → reporter.atNode(node)
```

The collision is structural: the `LintCode` literal string `'depend_on_referenced_packages'` at `config_rules.dart:1274` is identical to the SDK lint registered by `package:linter/src/rules/depend_on_referenced_packages.dart`. Two independent emitters, one ID.

---

## Root Cause

### Primary — name collision

`LintCode('depend_on_referenced_packages', …)` at [config_rules.dart:1274](lib/src/rules/config/config_rules.dart#L1274) reuses the Dart SDK's built-in rule ID without namespacing. The analyzer and `custom_lint` use `LintCode.name` as the rule identifier, so two diagnostics bearing the same `name` but emitted from different plugins are two distinct reports as far as VS Code's Problems panel and the `custom_lint` reporter are concerned. There is no central de-duplication; both appear.

saropa_lints cannot override or replace the SDK lint through this mechanism — they coexist. The original intent of re-implementing the rule (richer correction text, higher `LintImpact`, inclusion in tier grouping) is legitimate, but the ID sharing is the bug.

### Secondary — over-firing confirmed, root cause identified and fixed

Investigated after the user reported that 23,000 warnings were still showing even after the rename. The rename was insufficient: saropa's rule was flagging **every** `package:` import, including declared direct dependencies like `package:flutter/material.dart` and `package:provider/provider.dart`. The rule's own skip-when-declared guard (`if (ProjectContext.hasDependency(context.filePath, packageName)) return;`) was falling through to the "not declared" branch on every call, because `ProjectContext.hasDependency(...)` was returning `false` for every query on every project.

Root cause is in the pubspec parser at [project_context_project_file.dart:257](../lib/src/project_context_project_file.dart#L257):

```dart
// BROKEN (as shipped):
final depMatches = RegExp(r'^\s+(\w+):').allMatches(content);
```

The regex is missing `multiLine: true`. Without it, `^` anchors only at position 0 of the input string, so `allMatches` can return at most one hit — and pubspec.yaml always starts with `name:` at column 0 (no leading whitespace), so the regex matches **zero** lines. `_ProjectInfo.dependencies` is an empty `Set<String>` on every project. Verified with a one-shot probe: given a synthetic pubspec with 5 declared deps, the broken regex returned `[]`; with `multiLine: true` added it returned `[flutter, sdk, http, provider, test]`. Same probe against `saropa_lints/pubspec.yaml` — 0 entries before, 27 entries after.

**Impact extends far beyond this one rule.** Every other rule in the plugin that gates itself on `hasDependency(...)` — `flutter_hooks`, `riverpod`, `bloc`, `supabase`, `firebase`, and others — was silently reading `dependencies = {}` and producing wrong output (either over-firing or under-firing depending on whether the rule uses it as an inclusion or exclusion check). The existing `ProjectContext` tests in [defensive_coding_test.dart](../test/defensive_coding_test.dart) only covered null/empty defensive cases — there was no positive test that `hasDependency` returned `true` for a package that really was declared, which is exactly why this has been broken undetected.

---

## Suggested Fix

Primary — rename the saropa rule to a unique ID:

```dart
// BEFORE (lib/src/rules/config/config_rules.dart:1273-1279):
static const LintCode _code = LintCode(
  'depend_on_referenced_packages',
  '[depend_on_referenced_packages] Imported package is not listed in pubspec.yaml dependencies. ...',
  correctionMessage: 'Add the missing package to dependencies ...',
  severity: DiagnosticSeverity.WARNING,
);

// AFTER:
static const LintCode _code = LintCode(
  'saropa_depend_on_referenced_packages',
  '[saropa_depend_on_referenced_packages] Imported package is not listed in pubspec.yaml dependencies. ...',
  correctionMessage: 'Add the missing package to dependencies ...',
  severity: DiagnosticSeverity.WARNING,
);
```

Plus a migration note in `CHANGELOG.md` documenting the rename so existing `// ignore: depend_on_referenced_packages` comments in user projects still suppress the SDK lint (unchanged) and users who want to also suppress saropa's version add `// ignore: saropa_depend_on_referenced_packages`.

Alternative — detect-and-skip registration:

At rule-list assembly time, inspect the effective SDK lint set. If `depend_on_referenced_packages` is enabled by the SDK analyzer, omit saropa's copy from the registered-rule list. This preserves the user-visible rule name but couples saropa_lints to SDK lint introspection, which may be fragile across analyzer versions. Rename is simpler and more predictable.

### Tier file update

Whichever approach: update any tier file that lists this rule under the old name (`lib/src/tiers.dart` and any seed configs in `lib/src/config/`) to the new name.

### Documentation

Update the rule's entry in any generated rule catalog / README table / `lib/src/all_rules.dart` registration to reflect the new name. Search for uses of the rule ID string to catch stale references:

```bash
grep -rn "'depend_on_referenced_packages'" lib/ test/ example_packages/ README.md CHANGELOG.md
```

---

## Fixture Gap

`example*/lib/config/depend_on_referenced_packages_fixture.dart` (if it exists, rename alongside the rule; if not, add one) should cover:

1. **Own-package import** — `import 'package:<ownPkg>/foo.dart';` — expect NO lint (skipped by ownName check).
2. **Declared direct dependency** — `import 'package:http/http.dart';` where `http` is in `dependencies:` — expect NO lint.
3. **Undeclared transitive dependency** — `import 'package:collection/collection.dart';` where `collection` is pulled in by another dep but not listed — expect LINT.
4. **`dev_dependencies` usage in test file** — `import 'package:mockito/mockito.dart';` where `mockito` is in `dev_dependencies:` and the file is under `test/` — expect NO lint.
5. **`dev_dependencies` usage in `lib/` file** — same import from a `lib/` file — expect LINT (dev deps are not shippable).
6. **Dart SDK import** — `import 'dart:async';` — expect NO lint (skipped by the `package:` prefix check).

---

## Changes Made

Two fixes applied. Rename alone would have been insufficient — the rule was over-firing on every import regardless of whether it was declared, because the shared pubspec parser was silently returning an empty dependency set.

**Fix 1 — pubspec dependency parser (the real source of the 23k warnings):**

- [lib/src/project_context_project_file.dart:257](../lib/src/project_context_project_file.dart#L257) — added `multiLine: true` to the dep-extraction regex. `RegExp(r'^\s+(\w+):').allMatches(content)` → `RegExp(r'^\s+(\w+):', multiLine: true).allMatches(content)`. An inline block comment spells out the failure mode, the scope of affected rules (everything that uses `hasDependency`), and the saropa-contacts blast radius, so a future reader cannot strip the flag during "cleanup" without reading history. Verified empirically: the broken form returns 0 matches on any real pubspec; the fixed form returns the full dep+dev-dep set.

**Fix 2 — collision rename (the primary approach from "Suggested Fix"):**

SDK lint `depend_on_referenced_packages` is left untouched and continues to fire on its own.

- [lib/src/rules/config/config_rules.dart](../lib/src/rules/config/config_rules.dart) — `DependOnReferencedPackagesRule._code` renamed from `'depend_on_referenced_packages'` → `'saropa_depend_on_referenced_packages'`. Problem-message `[prefix]` tag updated to match. Inline block comment above the `LintCode` explains the collision and points back to this bug report. The rule class name (`DependOnReferencedPackagesRule`) is unchanged — only the user-visible lint ID changed, so `lib/saropa_lints.dart` `_allRuleFactories` and all other `DependOnReferencedPackagesRule.new` references continue to work without edits.
- [lib/src/tiers.dart](../lib/src/tiers.dart) — `essentialRules` entry `'depend_on_referenced_packages'` renamed to `'saropa_depend_on_referenced_packages'`, with a comment cross-referencing this bug report. No other tier contained this rule.
- [CHANGELOG.md](../CHANGELOG.md) — `[Unreleased]` opener line appended with a one-sentence migration note; new `### Fixed` entry documents the rename, why it was needed (SDK collision), the concrete downstream counts it distorted (22,695 on saropa-contacts, 96.8% of backlog), and how users who were suppressing the rule should migrate their `// ignore:` comments.

### Classification downstream

- [lib/src/report/report_synthesis.dart](../lib/src/report/report_synthesis.dart) `_dartLintsRuleNames` still contains `'depend_on_referenced_packages'` — that entry is deliberately kept because it now unambiguously refers to the **SDK** lint. The renamed saropa rule will be classified as `RuleSource.saropa` through the existing `saropaRuleNames` registration path without further changes.
- [scripts/modules/_rule_version_history.py](../scripts/modules/_rule_version_history.py) skip-list entry for `depend_on_referenced_packages` is likewise kept (the heuristic is excluding the SDK name from rule-name extraction). The new `saropa_depend_on_referenced_packages` name is a valid saropa rule and will be picked up by that script automatically.

### Not changed

- No fixture file exists under `example*/lib/config/depend_on_referenced_packages_fixture.dart`; the unit tests in `test/config_rules_test.dart` are the only coverage. "Fixture Gap" below remains an open follow-up — the rename itself does not require one to close this bug, and the existing tests continue to exercise the rule end-to-end through `custom_lint`.

---

## Tests Added

- [test/config_rules_test.dart](../test/config_rules_test.dart) — `DependOnReferencedPackagesRule` unit test updated to assert `rule.code.lowerCaseName == 'saropa_depend_on_referenced_packages'` and that the problem message contains `[saropa_depend_on_referenced_packages]`. Inline comment records *why* the identifier is namespaced, so a future reader doesn't revert the name under the impression that `saropa_` is gratuitous. The sibling `group('depend_on_referenced_packages', …)` placeholder fixture block is renamed to `group('saropa_depend_on_referenced_packages', …)` to match.
- [test/defensive_coding_test.dart](../test/defensive_coding_test.dart) — **two new positive regression tests** for the pubspec parser. The first asserts `ProjectContext.hasDependency(<abs>/pubspec.yaml, 'analyzer')` / `'path'` / `'test'` all return `true` against this repo's own pubspec (which declares those packages), plus a sanity-check that an arbitrary string returns `false`. The second asserts `ProjectContext.getPackageName(root)` returns `'saropa_lints'`. These directly target the silent empty-set failure mode — the existing tests in this file only covered null/empty defensive cases, which is exactly why the broken regex slipped past every test run historically. The test uses `'${Directory.current.path}/pubspec.yaml'` because `findProjectRoot` walks up from a file path and needs something with a parent chain; a bare relative `'pubspec.yaml'` has no parent to traverse.

The collision itself is structurally prevented by the rename — two `LintCode.name` strings are now different constants, which cannot regress silently: any future attempt to reintroduce the old name would immediately break both the unit test's `lowerCaseName` assertion and the problem-message `[prefix]` assertion.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: `^12.3.4` (per `CHANGELOG.md` top entry)
- Dart SDK: project-dependent (reproduced against a Flutter 3.x project)
- custom_lint: whatever the plugin declares in its own pubspec
- Triggering project: `d:/src/contacts` (saropa-contacts) — `analysis_options.yaml` enables both the SDK lint (line 122) and the saropa rule (line 576); both are part of the `recommended` tier's default output.

---

## Related

- [infra_analysis_report_insufficient_for_large_backlogs.md](infra_analysis_report_insufficient_for_large_backlogs.md) — the 23k-issue triage report; the top-concentration callout it proposes is dominated entirely by *this* rule's inflated count, so fixing this bug will change the numbers that report surfaces.
