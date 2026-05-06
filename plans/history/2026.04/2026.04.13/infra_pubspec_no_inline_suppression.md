# BUG: `pubspec-validation` — No inline suppression mechanism for pubspec rules

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-13
Rule: All pubspec rules (`avoid_any_version`, `dependencies_ordering`, `prefer_caret_version_syntax`, `avoid_dependency_overrides`, `prefer_publish_to_none`, `prefer_pinned_version_syntax`, `pubspec_ordering`, `newline_before_pubspec_entry`, `prefer_commenting_pubspec_ignores`, `add_resolution_workspace`, `prefer_l10n_yaml_config`)
File: `extension/src/pubspec-validation.ts` (entire file — no suppression infrastructure exists)
Severity: Infrastructure
Rule version: All | Since: v10.11.0 | Updated: v10.12.1

---

## Summary

Pubspec validation rules have no inline suppression mechanism. Users cannot disable a specific rule for a specific line in `pubspec.yaml`. Dart analyzer rules support `// ignore: rule_name` comments, but the pubspec validator — which is a VS Code extension text scanner, not a Dart analyzer plugin — does not recognize any form of ignore directive. When a rule fires correctly in general but is wrong for a specific dependency (e.g., `analyzer: any` forced by conflicting transitive constraints), the user has no way to suppress it short of disabling the entire rule globally.

---

## Reproducer

`pubspec.yaml` in `d:\src\contacts` at line 660:

```yaml
  # https://pub.dev/packages/analyzer/changelog
  # Intentionally `any` — isar_community_generator caps at <12, saropa_lints needs ^12.
  # Pin to a range once Isar is removed and saropa_lints is re-enabled.
  analyzer: any
```

The comment above the entry explains exactly why `any` is used — two transitive dependencies impose conflicting version ceilings. The constraint is intentional and temporary. Despite the explanatory comment, `avoid_any_version` fires with no way to suppress it.

**Frequency:** Always — every pubspec rule fires unconditionally. There is no suppression path for any of them.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | A comment like `# saropa_lints:ignore avoid_any_version` on the line above (or inline) suppresses the diagnostic for that specific entry, similar to Dart's `// ignore: rule_name` |
| **Actual** | No suppression mechanism exists. The diagnostic fires unconditionally. The only workaround is to disable the entire rule globally in VS Code settings (which loses coverage for all other `any` constraints) |

---

## AST Context

Not applicable — pubspec validation is a VS Code extension diagnostic (text-based YAML line scanning), not a Dart analyzer rule. No AST involved.

The detection pipeline works as follows:

1. `update()` at line 684 receives pubspec content as a string
2. `parseDependencySections()` at line 69 extracts `DepEntry[]` per section
3. Individual `check*()` functions iterate entries and push diagnostics
4. No function inspects surrounding comments for suppression directives

---

## Root Cause

### Confirmed: No suppression infrastructure

The file has **zero** logic for recognizing or honoring inline ignore comments. Each `check*()` function directly pushes diagnostics without checking whether the flagged line (or the line above it) contains a suppression directive.

The `avoid_dependency_overrides` rule (line 287) already demonstrates a comment-checking pattern — it skips entries that have a `#` comment on the same line or the line above. However, this checks for *any* comment as a way to verify the override is documented, not as a suppression mechanism. The pattern proves the infrastructure can inspect adjacent lines for comments; it just doesn't use this capability for suppression.

### What's missing

1. **A suppression comment format** — a convention like `# saropa_lints:ignore <rule_code>` that users can place on the line above a flagged entry or inline after it.

2. **A filtering step** — either:
   - A centralized filter applied to all diagnostics after all `check*()` functions run (cleaner, avoids duplicating logic in every rule), or
   - Individual checks in each `check*()` before pushing a diagnostic (more scattered but matches the `avoid_dependency_overrides` pattern).

3. **Support for multiple rules** — a single suppression comment should be able to list multiple rule codes: `# saropa_lints:ignore avoid_any_version, dependencies_ordering`.

---

## Suggested Fix

### Approach A: Centralized post-filter (recommended)

Add a single filtering step in `update()` after all `check*()` functions run but before `this._collection.set()`. This avoids modifying every individual rule function.

**Step 1: Define the suppression comment format**

```
# saropa_lints:ignore <rule_code>[, <rule_code>, ...]
```

Recognized positions:
- **Line above** the flagged line (consistent with Dart `// ignore:` which goes on the preceding line)
- **Inline** on the same line after the YAML content (e.g., `analyzer: any # saropa_lints:ignore avoid_any_version`)

**Step 2: Add a suppression parser**

```typescript
// extension/src/pubspec-validation.ts — new function

/**
 * Extract suppressed rule codes from a comment string.
 *
 * Recognizes: `# saropa_lints:ignore rule_a, rule_b`
 * Returns an empty set if the line contains no suppression directive.
 */
function parseSuppressedRules(commentLine: string): Set<string> {
    const match = commentLine.match(
        /saropa_lints:ignore\s+(.+)/,
    );
    if (!match) { return new Set(); }
    return new Set(
        match[1].split(',').map(s => s.trim()).filter(Boolean),
    );
}
```

**Step 3: Add a centralized filter in `update()`**

After all `check*()` calls (line ~703) and before `this._collection.set(uri, diagnostics)` (line 705):

```typescript
// Filter out diagnostics suppressed by inline comments
const filtered = diagnostics.filter(diag => {
    const diagLine = diag.range.start.line;
    const code = typeof diag.code === 'string' ? diag.code : '';
    if (!code) { return true; } // keep diagnostics with no code

    // Check inline comment on the diagnostic's own line
    const sameLine = lines[diagLine] ?? '';
    if (parseSuppressedRules(sameLine).has(code)) { return false; }

    // Check comment on the line above
    if (diagLine > 0) {
        const prevLine = (lines[diagLine - 1] ?? '').trim();
        if (parseSuppressedRules(prevLine).has(code)) { return false; }
    }

    return true;
});

this._collection.set(uri, filtered);
```

**Step 4: Remove the old `this._collection.set(uri, diagnostics)` call at line 705** and replace with the filtered version above.

### Why centralized over per-rule

- **One implementation** — every current and future pubspec rule gets suppression support automatically.
- **No signature changes** — individual `check*()` functions don't need `lines` passed where they don't already have it (e.g., `checkAnyVersion`, `checkCaretSyntax`, `checkPinnedVersionSyntax`).
- **Testable in isolation** — `parseSuppressedRules` can be unit-tested independently.
- **Consistent behavior** — all rules honor the same comment format with no risk of one rule implementing it differently.

### Usage in `d:\src\contacts\pubspec.yaml`

```yaml
  # https://pub.dev/packages/analyzer/changelog
  # Intentionally `any` — isar_community_generator caps at <12, saropa_lints needs ^12.
  # Pin to a range once Isar is removed and saropa_lints is re-enabled.
  # saropa_lints:ignore avoid_any_version
  analyzer: any
```

---

## Fixture Gap

The test file at `extension/src/test/pubspec-validation.test.ts` has no suppression-related tests. The following cases are needed:

### For `parseSuppressedRules` (unit tests)

1. **Single rule** — `# saropa_lints:ignore avoid_any_version` → `{'avoid_any_version'}`
2. **Multiple rules** — `# saropa_lints:ignore avoid_any_version, dependencies_ordering` → both codes
3. **No directive** — `# This is a normal comment` → empty set
4. **Empty after ignore** — `# saropa_lints:ignore` → empty set (no rule codes)
5. **Extra whitespace** — `#   saropa_lints:ignore   avoid_any_version  ,  dependencies_ordering  ` → both codes

### For centralized filter (integration tests against each rule)

6. **`avoid_any_version` suppressed by line above** — `# saropa_lints:ignore avoid_any_version` on the line before `analyzer: any` → no diagnostic
7. **`avoid_any_version` suppressed inline** — `analyzer: any # saropa_lints:ignore avoid_any_version` → no diagnostic
8. **`avoid_any_version` NOT suppressed by wrong code** — `# saropa_lints:ignore dependencies_ordering` before `analyzer: any` → diagnostic still fires
9. **`avoid_any_version` NOT suppressed by unrelated comment** — `# This uses any intentionally` before `analyzer: any` → diagnostic still fires (only the exact `saropa_lints:ignore` format suppresses)
10. **`dependencies_ordering` suppressed** — verify suppression works for non-DepEntry rules
11. **`prefer_caret_version_syntax` suppressed** — verify suppression works for version syntax rules
12. **`pubspec_ordering` suppressed** — verify suppression works for `createLineDiag`-based rules
13. **`newline_before_pubspec_entry` suppressed** — verify suppression works for structural rules
14. **Multiple rules on one line** — `# saropa_lints:ignore avoid_any_version, prefer_caret_version_syntax` suppresses both but not others
15. **Suppression comment does not suppress unrelated rules** — `# saropa_lints:ignore avoid_any_version` on a line that also triggers `dependencies_ordering` → only `avoid_any_version` is suppressed, ordering diagnostic still fires

---

## Changes Made

- `extension/src/pubspec-validation.ts`: Added `parseSuppressedRules()` (exported) and `isSuppressed()` helper functions. Modified `update()` to filter diagnostics through the centralized suppression check before passing them to `_collection.set()`. Approach A (centralized post-filter) from the suggested fix.

---

## Tests Added

- `extension/src/test/pubspec-validation.test.ts`: 16 new tests across two `describe` blocks:
  - **`parseSuppressedRules`** (5 unit tests): single rule, multiple rules, normal comment, empty after ignore, extra whitespace
  - **`inline suppression`** (11 integration tests): line-above suppression, inline suppression, wrong code not suppressed, unrelated comment not suppressed, `prefer_caret_version_syntax` suppressed, `newline_before_pubspec_entry` suppressed via inline + before/after pair, multiple rules on one line, selective suppression (only listed rule suppressed), `pubspec_ordering` suppressed when adjacent + not suppressed when non-adjacent

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 10.12.1
- Dart SDK version: N/A (VS Code extension rule, not Dart analyzer)
- custom_lint version: N/A
- Triggering project: `d:\src\contacts` — `analyzer: any` at line 660 of `pubspec.yaml`, with an explanatory comment that the validator ignores
