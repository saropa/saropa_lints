# Bug: `prefer_sentence_case_comments` false positive on identifier-name comments

**Status:** Fixed
**Rule:** `prefer_sentence_case_comments` (v5)
**Severity:** False positive — flags valid code that should not trigger
**Plugin version:** saropa_lints v8.0.9+

## Resolution

Fixed in v5 of the rule. Three changes:

1. **Short-comment threshold**: Comments of 1-2 words are now skipped (treated as annotation labels). A new relaxed variant (`prefer_sentence_case_comments_relaxed`) skips 1-4 words.

2. **Tightened code-reference pattern**: The `_codeReferencePattern` was matching ALL lowercase words followed by a space (e.g., `calculate `), silently suppressing most multi-word violations. Now only matches camelCase (`userId`) and snake_case (`user_id`) identifiers.

3. **Shared base class**: Both rule variants share `_SentenceCaseCommentsBase` with all regex patterns and check logic. Only the word threshold and lint code differ.

## Original problem

The rule flagged inline identifier-name annotations like `// magnifyingGlass` and `// gear` as needing sentence-case capitalization, even though these are camelCase identifiers used as cross-reference labels in icon mapping files.
