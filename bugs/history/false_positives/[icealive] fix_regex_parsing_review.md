# Analysis: Resolution of CLI Tool Parsing (PR #84 and Subsequent Refactoring)

[Github PR #84](https://github.com/saropa/saropa_lints/pull/84)

**Status:** ✅ **Complete & Approved**

## 1. Executive Summary

The project's command-line tools (`baseline.dart`, `impact_report.dart`) were non-functional due to a regex bug. **PR #84 correctly fixed this bug**, but in doing so, highlighted a pre-existing structural issue: the parsing logic was duplicated across both tool files.

This structural issue has now been **fully resolved** by refactoring the duplicated code into shared, single-purpose files, resulting in a more robust and maintainable codebase.

---

## 2. The Original Error: Incorrect Regex

The root cause of the failure was that the `_parseViolations` function, present in both `baseline.dart` and `impact_report.dart`, used an outdated regex pattern.

*   **Incorrect Pattern:** `r'^(.+?):(\d+):(\d+)\s+-\s+(\w+)\s+[-.\u2022]\s+(.+)$'`
*   **Problem:** It was designed to match hyphens (`-`) as separators. However, the `custom_lint` tool's output format had changed to use bullets (`•`).
*   **Result:** The regex never found any matches, causing the tools to incorrectly report "No issues found!"

---

## 3. The Pull Request Fix (PR #84)

PR #84 successfully fixed the immediate bug by updating the regex pattern in both files.

*   **Corrected Pattern:** `r'^\s*(.+?):(\d+):(\d+)\s+•\s+(.*?)•\s+(\w+)\s+•'`
*   **Action:** The author correctly identified the format change and updated the pattern to match the bullet separators and capture the correct data groups.
*   **Outcome:** This made the tools functional again.

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

## 5. The Final Resolution: Refactoring

The current codebase has addressed the code duplication issue by moving the shared logic into dedicated files.

*   **`lib/src/violation_parser.dart`:** Now contains the single, authoritative `parseViolations` function.
*   **`lib/src/models/violation.dart`:** Now contains the single `Violation` data model.

Both `bin/baseline.dart` and `bin/impact_report.dart` have been updated to `import` these new files instead of defining the logic locally.

**Conclusion:** The initial bug is fixed, and the underlying structural problem of code duplication has been resolved through proper refactoring. The code is now correct, maintainable, and follows best practices.