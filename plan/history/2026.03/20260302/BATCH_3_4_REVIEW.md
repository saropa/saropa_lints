# Batch 3 & 4 roadmap rules — review summary

**Date:** 2026-03-02  
**Scope:** All code and doc changes for batch 3 (19 rules) and batch 4 (20 rules) from REMAINING_ROADMAP_RULES.md.

## 1. Logic, race conditions, recursion

- **All new rules are stubs:** `runWithReporter(SaropaDiagnosticReporter, SaropaContext)` is empty (no AST visits, no shared state).
- **No logic issues:** No branching, no I/O, no async.
- **No race conditions:** No mutable shared state; analyzer invokes rules per file.
- **No recursion risk:** No recursive AST traversal in added code.

## 2. Duplication and shared logic

- **One class per rule** in the appropriate `*_rules.dart` file; no duplicated logic.
- **No shared logic to extract:** Stubs share the same pattern (LintCode + impact/cost + empty runWithReporter) which is the existing project convention for placeholder rules.

## 3. Performance

- **Stub rules are no-ops:** Empty `runWithReporter` returns immediately. No performance risk.
- **Spinners/shimmers/parallelism:** N/A — this is a static analysis lint package; no UI or background processing in the changed files.

## 4. Project compliance

- **Rule shape:** Each rule extends `SaropaLintRule`, has `static const LintCode _code` (name, problemMessage, correctionMessage, severity: INFO), `LintImpact.low`, `RuleCost.low` (or medium where applicable). Matches existing roadmap stubs.
- **Registration:** All 39 rules (batch 3 + batch 4) are in `lib/saropa_lints.dart` `_allRuleFactories` and in `lib/src/tiers.dart` `professionalOnlyRules`. Rule names match `LintCode.name`.
- **Exports:** Rules are in files already exported from `lib/src/rules/all_rules.dart`; no change needed.
- **Docs:** CHANGELOG.md [Unreleased] has entries for batch 3 and batch 4. REMAINING_ROADMAP_RULES.md updated (implemented count 106; to-do tables trimmed). ROADMAP.md is auto-synced by publish script; no edit required for these checklist rules.

## 5. Unit tests and fixtures

- **Policy (UNIT_TEST_COVERAGE.md, CONTRIBUTING.md):** No fixture or behavioral test for a rule until it is implemented and the BAD example actually triggers the lint. Stub fixtures are prohibited.
- **These rules are placeholders:** No detection logic yet, so no fixtures or new unit tests added. Compliant with project policy.

## 6. Code comments and clarity

- **Section headers:** Each rule has `// =============================================================================` and `// rule_name` above the class; consistent with rest of codebase.
- **LintCode messages:** problemMessage and correctionMessage are short and actionable. No further comments required for stubs.

## 7. Linter and analyze

- **dart analyze lib:** Passes (No issues found). Linter diagnostics reported in `lib/saropa_lints.dart` (avoid_global_state, avoid_synchronous_file_io, etc.) are pre-existing and unrelated to the new rule classes in `*_rules.dart`.

## 8. Bug reports

- **bugs/ and bugs/history:** Only BUG report present is `bugs/history/rule_bugs/BUG_REPORT_Element_metadata_MetadataImpl_not_Iterable_analyzer_9.md`. No bug report in `bugs/` root to move or update. No action.

## 9. Improvements / code smells

- **No blocking issues.** Optional later improvement: add one-line DartDoc to some stubs (e.g. "Suggests setting WebView user agent for compatibility.") for consistency with some older rules; many existing roadmap stubs omit DartDoc, so not required for this commit.

## 10. Files changed (for commit)

**Rules (batch 3 + 4):**  
test_rules, image_rules, dependency_injection_rules, json_datetime_rules, permission_rules, packages/provider_rules, internationalization_rules, packages/sqflite_rules, async_rules, security_auth_storage_rules, context_rules, navigation_rules, code_quality_avoid_rules, structure_rules, memory_management_rules, error_handling_rules, packages/isar_rules, accessibility_rules, ui_ux_rules.  
**Cleanup:** packages/firebase_rules (removed duplicate RequireFirebaseCompositeIndexRule stub).  
**Registration:** lib/saropa_lints.dart, lib/src/tiers.dart.  
**Docs:** CHANGELOG.md, bugs/REMAINING_ROADMAP_RULES.md.

**Conclusion:** No remaining issues; safe to commit.
