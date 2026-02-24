# Bug: `avoid_medium_length_files` counts dartdoc and comments toward file length

## Summary

The `avoid_medium_length_files` rule (v4) counts **all** lines equally — dartdoc
comments (`///`), code comments (`//`), blank lines, and executable code. This
causes well-documented files to be flagged as "too long" even when the actual
code is well under the 300-line threshold.

This creates a direct, irreconcilable conflict with Dart best practices and the
project's own lint rules that **require** dartdoc on every public method.

## Severity

**False positive** — files are flagged for exceeding 300 lines when their actual
executable code is far below that threshold. The excess lines are mandatory
documentation that the linter itself requires.

## Reproduction

### Example: `lib/string/string_case_extensions.dart` (425 total lines)

This file contains a single extension (`StringCaseExtensions`) with 14 public
members. Every public member has comprehensive dartdoc with examples, as
required by project conventions and saropa_lints documentation rules.

#### Line-by-line breakdown

| Type | Lines | % of file |
|------|------:|----------:|
| Dartdoc (`///`) | 241 | 57% |
| Comments (`//`) | 29 | 7% |
| Blank lines | 39 | 9% |
| **Executable code** | **116** | **27%** |
| **Total** | **425** | **100%** |

**Only 116 lines of executable code** — 61% under the 300-line threshold.

Without any documentation, this file would be ~155 lines — roughly half the
threshold.

#### Detailed per-method analysis

| Method | Dartdoc lines | Code lines | Dartdoc:Code ratio |
|--------|-------------:|----------:|---------:|
| `isAllLetterLowerCase` | 17 | 1 | 17:1 |
| `isAnyCaseLetter` | 19 | 1 | 19:1 |
| `isAllLetterUpperCase` | 17 | 1 | 17:1 |
| `capitalizeWords` | 19 | 10 | 1.9:1 |
| `lowerCaseFirstChar` | 13 | 1 | 13:1 |
| `upperCaseFirstChar` | 13 | 1 | 13:1 |
| `titleCase` | 13 | 1 | 13:1 |
| `toUpperLatinOnly` | 19 | 20 | 0.95:1 |
| `capitalize` | 18 | 8 | 2.25:1 |
| `upperCaseLettersOnly` | 18 | 10 | 1.8:1 |
| `findCapitalizedWords` | 18 | 5 | 3.6:1 |
| `insertSpaceBetweenCapitalized` | 19 | 10 | 1.9:1 |
| `splitCapitalized` | 19 | 6 | 3.2:1 |
| `unCapitalizedWords` | 18 | 3 | 6:1 |
| **Totals** | **240** | **78** | **3:1** |

The remaining code lines (116 - 78 = 38) are imports, regex declarations, blank
separators, and the extension declaration itself.

### Lint output

```
lib/string/string_case_extensions.dart:1 • [avoid_medium_length_files]
File exceeds 300 lines. Files beyond this threshold often contain multiple
responsibilities, which makes navigation harder and increases merge conflict
risk in team development. {v4}
```

### Previous example: `lib/list/list_extensions.dart` (367 total lines)

| Type | Lines | % |
|------|------:|---:|
| Dartdoc (`///`) | 209 | 55% |
| Comments (`//`) | 24 | 6% |
| Blank lines | 31 | 8% |
| **Executable code** | **115** | **30%** |

**Only 115 lines of code** — also well under the threshold.

## Root cause

The rule counts total lines in the file without distinguishing between
executable code and documentation. The 300-line threshold is applied to the
raw line count regardless of content type.

## Why this is a conflict, not a trade-off

The project's own lint configuration requires:
1. **Dartdoc on every public member** (`public_member_api_docs` / documentation rules)
2. **Example code in dartdoc** (best practice, encouraged by `require_return_documentation`)
3. **Files under 300 lines** (`avoid_medium_length_files`)

For a well-documented extension with 14 members, these rules are **mathematically
incompatible**:

```
14 members x 17 avg dartdoc lines = 238 lines of documentation
14 members x  8 avg code lines   =  92 lines of code
14 blank separators + 4 boilerplate = 18 lines
Total: 348 lines → FLAGGED

But only 92 lines are code.
```

Any file with more than ~10 documented public members will exceed 300 total
lines even if the code is under 150 lines.

## Suggested fix

**Option A (recommended): Count only code lines**

Apply the 300-line threshold to executable code lines only. Lines containing
only comments (`//`, `///`, `/* */`) or whitespace should be excluded.

```
Effective lines = total lines - dartdoc lines - comment lines - blank lines
```

**Option B: Separate configurable thresholds**

```yaml
avoid_medium_length_files:
  max_total_lines: 500     # including documentation
  max_code_lines: 200      # excluding documentation and blanks
```

**Option C: Auto-adjust for documentation density**

If a file has >40% documentation lines, apply a higher threshold (e.g., 1.5x
or 2x the base threshold). This acknowledges that well-documented files will
naturally be longer.

## Note on prior fix

A previous version of this bug was marked as "Fixed in v5.0.3" (the rule was
updated to count only code lines). However, the rule is still firing on
`string_case_extensions.dart` with the current version, suggesting the fix may
not be deployed or may not be working as intended.

## Resolution

**Fixed.** The file length rules (8 rules) already counted only code lines via
token-walking in `_countCodeLines()`. The `avoid_long_functions` rule still used
`body.toSource()` with raw newline counting, which included comments. Fixed by
extracting a shared `_countCodeLinesInTokenRange()` helper and using it in both
file-level and function-level counting. Rule bumped to v5.

The "still firing" report was likely due to the consumer project not updating to
the version that included the file-level fix.

## Environment

- saropa_lints version: current (rule version v4)
- Dart SDK: 3.x
- Project: saropa_dart_utils
- File: `lib/string/string_case_extensions.dart` (425 lines, 116 code)
