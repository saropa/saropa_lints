# Bug: `prefer_sentence_case_comments` false positive on continuation lines

**Status:** FIXED in v8.0.10 (rule v6, relaxed rule v2)

## Summary

`prefer_sentence_case_comments` flagged the second and subsequent lines of
multi-line `//` comments that continued a sentence from the previous line.
The rule treated each `//` line independently instead of recognizing that
consecutive `//` lines form a single logical comment block.

100% false positive rate in saropa_drift_viewer (7/7 violations).

## Fix

Added `_isContinuationLine` detection to the shared `_SentenceCaseCommentsBase`
class. A `//` comment line is now recognized as a continuation when:

1. The previous token is a `//` comment (not `///` or `/*`)
2. Both are on consecutive lines
3. The previous comment text is non-empty (blank `//` = paragraph break)
4. The previous comment does not end with sentence-ending punctuation (`.!?`)

Colons are intentionally excluded from sentence-ending punctuation because they
introduce lists or elaborations.
