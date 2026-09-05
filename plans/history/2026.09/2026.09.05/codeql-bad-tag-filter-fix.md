# Fix CodeQL js/bad-tag-filter alerts in test infrastructure

Two CodeQL security scanning alerts (#21 and #22) flagged HTML tag-matching regexes
in extension test files. Both are false positives in the security sense — the code is
snapshot normalization and assertion counting, not security sanitization — but the
regexes were technically incomplete and the fixes are costless.

## Finish Report (2026-09-05)

### Defect

GitHub CodeQL alert #21 (`snapshot-harness.ts:52`): the `</script>` and `</style>`
closing-tag patterns did not allow optional whitespace or attributes before `>`, so
`</script >` and `</script foo="bar">` would not match. Alert #22
(`projectMapShell.test.ts:87`): the `<script>` count regex lacked the `i` flag, so
`<SCRIPT>` would not match.

### Fix

- `snapshot-harness.ts`: changed closing-tag patterns from `\s*>` to `[^>]*>` in both
  the script and style strip regexes, handling whitespace AND attributes in closing
  tags. The `gi` flags were already present.
- `projectMapShell.test.ts`: added the `i` flag to the `/<script>/g` regex used for
  counting inline script tags.
- `projectVibrancyReportHtml.test.ts`: added `i` flag and `[^>]*>` closing-tag
  pattern in the `extractRowData` helper's script-tag regex (hardening — not yet
  flagged by CodeQL but identical pattern to #21).

### Hardening

- Upgraded all closing-tag patterns from `\s*>` to `[^>]*>` after confirming that
  browsers accept `</script foo="bar">` as a valid end tag (per CodeQL docs).
- Filed pre-existing `commandCatalogRegistry.test.ts` failure as
  `bugs/commandCatalogRegistry_test_failure_preexisting.md`.
- Added `scripts/check_html_tag_regex.py` CI script that scans all extension
  TypeScript files for HTML tag regexes missing case-insensitive flags or
  attribute-tolerant closing tags, catching future violations before they reach
  GitHub's CodeQL scanner.

### Impact

Test infrastructure only. No runtime behavior change. No new dependencies.

### Verification

- Both `tsc --noEmit` typechecks pass (main and test configs).
- `projectMapShell.test.ts` suite: 11 passing, 0 failing.
- `projectVibrancyReportHtml.test.ts` suite: 23 passing, 0 failing.
- The snapshot harness is consumed by snapshot tests; the regex change is strictly
  more permissive (accepts a superset of inputs), so no existing snapshots break.
- `check_html_tag_regex.py` reports 0 violations on the current codebase.
- Verified the script detects known-bad patterns (missing `i` flag, bare `>`
  closing tags) and does not false-positive on the fixed patterns or on HTML
  template literals.
