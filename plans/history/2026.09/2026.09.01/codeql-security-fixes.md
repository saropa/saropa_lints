# CodeQL Security Fixes — 13 Alerts

GitHub code scanning flagged 13 CodeQL alerts on the `main` branch. All 13 were triaged and resolved.

## Finish Report (2026-09-01)

### Defect Summary

GitHub's CodeQL scanner identified 13 security findings across workflow configurations, Markdown rendering, HTML-to-markdown conversion, and URL validation code in the VS Code extension.

### Changes

**Workflow permissions (#1, #2):**
- `.github/workflows/project-vibrancy.yml` and `diagnostic-baseline-strict.yml` — added `permissions: contents: read` to enforce least-privilege GitHub Actions tokens.

**Incomplete Markdown escaping (#14–18):**
- `extension/src/views/issuesTreeItemBuilder.ts` — replaced five `.replace(/]/g, '\\]')` and `.replace(/`/g, '\\`')` calls with a comprehensive `escapeMarkdown()` helper that escapes all Markdown special characters (`\ ` * _ { } [ ] ( ) # + - . ! | ~`), preventing Markdown injection in issue-tree tooltips.

**Incomplete URL substring sanitization (#12):**
- `extension/src/vibrancy/services/github-api.ts` — added `isGitHubUrl()` helper that validates the hostname via `new URL().hostname.endsWith('github.com')` instead of a substring match.
- `extension/src/vibrancy/extension-activation.ts` — replaced `.includes('github.com')` guard with `isGitHubUrl()`.

**HTML stripping and double-unescape (#3–5):**
- `extension/src/vibrancy/services/pubdev-changelog.ts` — replaced single-pass `/<[^>]+>/g` tag strip with `stripHtmlTags()` that loops until no angle brackets remain (handles malformed/nested tags). Entity decoding now runs AFTER tag stripping via `decodeHtmlEntities()`, preventing double-unescape of `&amp;lt;` sequences.

**Test file false positives (#11, #13):**
- `extension/src/test/views/snapshots/snapshot-harness.ts` — added `lgtm[js/bad-tag-filter]` suppression comment for the test-normalizer regex (not a security sanitizer).
- `extension/src/test/vibrancy/views/package-detail-html.test.ts` — rewrote assertion to avoid substring URL check pattern.

**Test assertion update:**
- `extension/src/test/views/issuesTree.test.ts` — updated tooltip assertion to match escaped underscores from `escapeMarkdown()`.

### Verification

- TypeScript compilation: clean (`npx tsc --noEmit` — 0 errors).
- 35 non-VS-Code-dependent tests: all passing.
- VS Code extension host tests (issuesTree): audited by inspection (require extension host, pre-existing environment limitation).
