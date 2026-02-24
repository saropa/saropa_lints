# Bug: `avoid_medium_length_files` counts dartdoc comments toward file length

## Summary

The `avoid_medium_length_files` rule (v4) counts all lines equally, including
dartdoc comments (`///`), code comments (`//`), and blank lines. This causes
files that are well-structured with comprehensive documentation to be flagged
as "too long" even when the actual code is well under the threshold.

This directly conflicts with Dart best practices and the project's own lint
rules that **require** dartdoc on every public method. Adding required
documentation should not trigger file length warnings.

## Severity

**False positive** -- Files are flagged for exceeding 300 lines when their
actual code content is far below that threshold. The excess lines are
mandatory documentation.

## Reproduction

### Example 1: `lib/list/list_extensions.dart` (367 total lines)

Line breakdown:
| Type | Lines | % |
|------|------:|---:|
| Dartdoc (`///`) | 209 | 55% |
| Comments (`//`) | 24 | 6% |
| Blank lines | 31 | 8% |
| **Actual code** | **115** | **30%** |

**Only 115 lines of code.** Without dartdoc, this file would be ~158 lines --
well under the 300-line threshold.

### Example 2: `lib/string/string_case_extensions.dart` (425 total lines)

Line breakdown:
| Type | Lines | % |
|------|------:|---:|
| Dartdoc (`///`) | 241 | 57% |
| Comments (`//`) | 29 | 7% |
| Blank lines | 39 | 9% |
| **Actual code** | **116** | **27%** |

**Only 116 lines of code.** Without dartdoc, this file would be ~184 lines --
well under the 300-line threshold.

### Lint output

```
line 1:1 • [avoid_medium_length_files] File exceeds 300 lines. Files beyond
this threshold often contain multiple responsibilities, which makes navigation
harder and increases merge conflict risk in team development. {v4}
```

## Root cause

The rule counts total lines in the file without distinguishing between
executable code and documentation. The 300-line threshold is applied to the
raw line count, which includes:

- Dartdoc comments (`///`) -- required by the project's own documentation rules
- Inline comments (`//`) -- important for code maintainability
- Blank lines -- used for readability between methods

## Impact

This creates a **direct conflict** between two lint goals:
1. `require_return_documentation` / dartdoc requirements say: "document every
   public method with examples"
2. `avoid_medium_length_files` says: "keep files under 300 lines"

Developers cannot satisfy both rules simultaneously for files with more than
~10 public methods, since each method's dartdoc typically adds 8-15 lines.

A well-documented extension with 12 methods could easily have:
- 12 methods x 10 lines dartdoc = 120 lines of documentation
- 12 methods x 8 lines code = 96 lines of code
- 12 blank separator lines = 12 lines
- Total: 228 lines of non-code + 96 lines of code = 324 lines (FLAGGED)

## Suggested fix

**Option A (recommended): Count only non-comment, non-blank lines**

Apply the 300-line threshold to executable code lines only. This is the most
accurate measure of file complexity.

```
Effective lines = total lines - dartdoc lines - comment lines - blank lines
```

**Option B: Increase threshold for documentation-heavy files**

If a file has >40% documentation lines, apply a higher threshold (e.g., 500
lines). This acknowledges that well-documented files will naturally be longer.

**Option C: Separate thresholds**

Provide two thresholds in the rule configuration:
- `max_total_lines: 500` (including documentation)
- `max_code_lines: 200` (excluding documentation and blanks)

**Option D: Offer an exemption comment**

Allow a file-level ignore comment like:
```dart
// ignore_for_file: avoid_medium_length_files -- documentation-heavy
```
(This already works, but the rule should acknowledge documentation as a valid
reason for larger files in its diagnostic message.)

## Resolution

**Fixed in v5.0.3.** All 8 file length rules now count only code lines (lines containing at least one non-comment token). Blank lines and lines with only comments (`//`, `///`, `/* */`) are excluded. Problem messages updated to say "code lines (comments and blank lines excluded)".

## Environment

- saropa_lints version: latest (v4 of this rule)
- Dart SDK: 3.x
- Project: saropa_dart_utils
