# Analysis: Resolution of CLI Tool Parsing (PR #84 and Subsequent Refactoring)

<!-- cspell:ignore Github -->
[Github PR #84](https://github.com/saropa/saropa_lints/pull/84) (closed in favor of [PR #90](https://github.com/saropa/saropa_lints/pull/90))

**Status:** Resolved — PR #84 was closed, its fix was adopted and refactored in PR #90 (merged 2026-02-05).

## 1. Executive Summary

<!-- cspell:ignore icealive -->
The project's command-line tools (`baseline.dart`, `impact_report.dart`) were non-functional due to a regex bug. **PR #84 by [@icealive](https://github.com/icealive) correctly identified and fixed this bug**. The maintainer adopted the fix but closed PR #84 in favor of [PR #90](https://github.com/saropa/saropa_lints/pull/90), which incorporated the regex correction alongside a refactoring to eliminate the duplicated parsing logic.

Regression tests for `parseViolations()` were added in v4.12.1 to guard against future output format changes.

---

## 2. The Original Error: Incorrect Regex

The root cause of the failure was that the `_parseViolations` function, present in both `baseline.dart` and `impact_report.dart`, used an outdated regex pattern.

*   **Incorrect Pattern:** `r'^(.+?):(\d+):(\d+)\s+-\s+(\w+)\s+[-.\u2022]\s+(.+)$'`
*   **Problem:** It was designed to match hyphens (`-`) as separators. However, the `custom_lint` tool's output format had changed to use bullets (`•`).
*   **Result:** The regex never found any matches, causing the tools to incorrectly report "No issues found!"

---

## 3. The Pull Request Fix (PR #84)

PR #84 correctly diagnosed the bug and updated the regex pattern in both files.

*   **Corrected Pattern:** `r'^\s*(.+?):(\d+):(\d+)\s+•\s+(.*?)•\s+(\w+)\s+•'`
*   **Key Changes:**
    *   Replaced hyphen (`-`) separators with bullet (`•`) separators
    *   Reordered capture groups: message now comes before rule name, matching actual `custom_lint` output
    *   Added leading `\s*` to handle indented output lines
*   **Additional Fix:** Added the missing `LintImpact.opinionated` category to the `impact_report` grouping

**Note:** PR #84 was **not merged directly**. The maintainer closed it in favor of PR #90, which incorporated the fix alongside structural improvements. The contributor was credited in the v4.11.0 CHANGELOG.

---

## 4. The Structural Issue: Code Duplication

The original codebase contained identical, duplicated code in two separate files:
*   `bin/baseline.dart`
*   `bin/impact_report.dart`

The duplicated code included:
1.  The entire `_parseViolations` function.
2.  The `Violation` data class definition.

While PR #84 fixed the bug inside this duplicated code, it left the duplication itself in place. This meant any future changes to the parsing logic would need to be manually applied in two places, creating a risk of them falling out of sync.

---

## 5. The Resolution: PR #90 (Refactoring)

[PR #90](https://github.com/saropa/saropa_lints/pull/90) (commit `d573c45`, merged 2026-02-05) resolved both the bug and the duplication:

*   **`lib/src/violation_parser.dart`:** Now contains the single, authoritative `parseViolations` function with the corrected regex.
*   **`lib/src/models/violation.dart`:** Now contains the single `Violation` data model.

Both `bin/baseline.dart` and `bin/impact_report.dart` were updated to import these shared files instead of defining the logic locally.

**Net result:** -65 lines of code, single source of truth for parsing.

---

## 6. Remaining Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `custom_lint` output format may change again | Regression tests in `test/violation_parser_test.dart` validate parsing against fixture output |
| Unknown rules default to `LintImpact.medium` silently | Acceptable for third-party rules; documented in code |
| `_ruleImpacts` map instantiates all rules on first access | One-time cost, acceptable for CLI tools that run once |

---

## 7. Timeline

| Date | Event |
|------|-------|
| 2026-02-03 | @icealive opens PR #84 with regex fix |
| 2026-02-05 | Maintainer closes PR #84, opens PR #90 with fix + refactoring |
| 2026-02-05 | PR #90 merged, released in v4.11.0 |
| 2026-02-07 | Regression tests added for `parseViolations()` (v4.12.1) |
