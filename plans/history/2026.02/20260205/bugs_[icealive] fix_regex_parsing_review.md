# Review: Fix CLI Tools Regex Parsing (PR #84)

**Status:** ⚠️ **Changes Requested** (Blocking Compilation Error)

## 📊 Summary
I have verified the diffs (29 lines changed: +19 additions, -10 deletions). The regex updates correctly match the new `custom_lint` output format (`file:line:col • description • rule_name`), fixing the parsing issue in both `baseline.dart` and `impact_report.dart`.

However, there is a **blocking logic error** in `bin/impact_report.dart` that will prevent the script from running.

---

## 🛑 Critical Issues (Blocking)

### 1. Undefined Variable `criticalCount`
**File:** `bin/impact_report.dart` (Lines 142+)

The code attempts to use `criticalCount` in an `if` condition, but this variable is **never defined**. The preceding lines define `highCount`, `mediumCount`, `lowCount`, and `opinionatedCount`, but `criticalCount` is missing.

**Current Code:**

```dart
  final highCount = byImpact[LintImpact.high]!.length;
  // ... (other counts defined)

  // ❌ ERROR: 'criticalCount' is undefined here.
  if (criticalCount > 0) {
    print('CRITICAL: $criticalCount (fix immediately!)');
  }
```

**Required Fix:**
You must define the variable before using it. 
*If `LintImpact.critical` exists in your enum:*
```dart
  final criticalCount = byImpact[LintImpact.critical]?.length ?? 0;
```
*If `critical` does not exist (and this was a copy-paste error for `high`), simply update the condition:*
```dart
  if (highCount > 0) { ... }
```

---

## 🔍 Code Analysis

### Regex Correctness
The new regex pattern correctly handles the `custom_lint` format:
* **Pattern:** `r'^\s*(.+?):(\d+):(\d+)\s+•\s+(.*?)•\s+(\w+)\s+•'`
* **Fixes:**
    * Matches the bullet (`•`) separator.
    * Correctly swaps the capture groups: Group 4 is now `description`, and Group 5 is `rule_name`.

---

## 💡 Recommendations

### Refactor for Robustness
The `_parseViolations` logic is now duplicated exactly in `bin/baseline.dart` and `bin/impact_report.dart`. I recommend extracting this logic to a shared utility file (e.g., `lib/src/utils.dart`) to prevent the two tools from falling out of sync in the future.
