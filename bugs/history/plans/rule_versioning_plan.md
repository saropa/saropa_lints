# Rule Versioning Plan — RESOLVED

## Resolution

Implemented and verified. 1719 rules across 95 files versioned with `{vN}` tags and `/// Since:` provenance lines. Scripts: `scripts/historical/version_rules.py` + `scripts/modules/_rule_version_history.py`. Reports: `reports/rule_versions.json`, `reports/rule_versions_summary.txt`. 1 known gap: `prefer_debugPrint` has no changelog/git history (shows `Since: unknown`).

## Goal

Add a **rule version number** (`{v1}`, `{v2}`, etc.) and **build provenance** (created/updated version) to every lint rule (~1700 rules). The version number tracks how many times a rule has been meaningfully modified.

---

## Data Sources

| Source | Location | Content |
|--------|----------|---------|
| CHANGELOG.md | `./CHANGELOG.md` | Versions 4.10.0 – 4.14.0 (537 lines) |
| CHANGELOG_ARCHIVE.md | `./CHANGELOG_ARCHIVE.md` | Versions 0.1.0 – 4.9.0 (4749 lines) |
| Git history | 576 commits | Full diff history per rule name |

---

## Deliverables

### 1. Python script: `scripts/historical/version_rules.py`

**Phase 1 — Extract all rule names from Dart source**
- Reuse the LintCode parser from `_extract_rule_messages.py`
- Scan `lib/src/rules/**/*_rules.dart` (72 files, including `packages/` and `platforms/`)
- For each rule, extract: `name`, `problemMessage`, source file path, line number
- Output: dict keyed by rule name

**Phase 2 — Scan changelogs for rule mentions**
- Parse both `CHANGELOG.md` and `CHANGELOG_ARCHIVE.md`
- For each version section (`## [X.Y.Z]`), extract all backtick-quoted rule names (`` `rule_name` ``)
- Also detect rule names mentioned without backticks (bare `avoid_xxx`, `prefer_xxx`, `require_xxx` patterns)
- Classify each mention by section: `Added`, `Changed`, `Fixed`, `Deprecated`, `Removed`
- Record: `{rule_name: [{version, section, context_snippet}]}`
- The **earliest `Added` mention** = created_version
- The **latest mention of any kind** = last_updated_version (if different from created)

**Phase 3 — Scan git history for rule mentions**
- For each rule name, run: `git log --oneline --all -S "rule_name" -- "*.dart" "*.md"`
- Parse commit hashes and messages
- Map commits to build versions by cross-referencing `Release vX.Y.Z` commits
- Each unique commit that mentions the rule in its diff = one modification event
- Deduplicate with changelog findings (same version = same event)
- **Performance**: ~1700 rules × `git log -S` = potentially slow. Mitigations:
  - Batch by running `git log -S` only on `lib/src/rules/` and changelogs separately
  - Cache results in `reports/rule_version_cache.json`
  - Add `--skip-git` flag for fast reruns using cached data
  - Estimate: ~30-60 min for full git scan (1700 × ~1-2s each)

**Phase 4 — Compute rule versions**
- For each rule, count distinct modification events (unique build versions where the rule was touched)
- Version = number of distinct build versions where the rule appeared in changelog OR git diff
- `v1` = rule was created and never modified
- `v2` = created + 1 modification
- `vN` = created + (N-1) modifications
- Store: `{rule_name: {version: N, created: "X.Y.Z", updated: "X.Y.Z", events: [...]}}`

**Phase 5 — Update Dart source files**
- For each rule, modify the `problemMessage` string to append ` {vN}` at the end
- Example before:
  ```
  problemMessage: '[avoid_logging_sensitive_data] Logging sensitive data... trust.',
  ```
- Example after:
  ```
  problemMessage: '[avoid_logging_sensitive_data] Logging sensitive data... trust. {v3}',
  ```
- Also update the DartDoc header to add provenance:
  ```dart
  /// Warns when sensitive data might be logged.
  ///
  /// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
  ```
- **Safety**: Write a backup of each file before modifying, or rely on git for rollback
- **Validation**: After all edits, re-extract all rules and verify every rule has exactly one `{vN}` suffix

### 2. Output report: `reports/rule_versions.json`

Full JSON with every rule's version history for auditing:
```json
{
  "avoid_logging_sensitive_data": {
    "rule_version": 3,
    "created_in": "1.1.9",
    "last_updated_in": "4.13.0",
    "source_file": "security_rules.dart",
    "events": [
      {"version": "1.1.9", "type": "Added", "source": "changelog"},
      {"version": "4.8.6", "type": "Changed", "source": "changelog"},
      {"version": "4.13.0", "type": "Fixed", "source": "git"}
    ]
  }
}
```

### 3. Output report: `reports/rule_versions_summary.txt`

Human-readable summary:
```
Rule Versioning Summary
=======================
Total rules:     1716
v1 (unchanged):  1200 (69.9%)
v2:               300 (17.5%)
v3-v4:            150 (8.7%)
v5+:               66 (3.8%)

Top 10 most-modified rules:
  avoid_empty_setstate          v8  (created 2.0.0, updated 4.13.0)
  require_change_notifier_dispose v7  (created 1.1.9, updated 4.8.6)
  ...
```

---

## Script Architecture

```
scripts/
  historical/version_rules.py   # Main entry point
  modules/
    _rule_version_history.py    # Phase 1-4: extraction + git scan + version computation
```

### CLI interface

```
python scripts/historical/version_rules.py [OPTIONS]

Options:
  --dry-run         Show what would change without modifying files
  --skip-git        Use cached git data (fast rerun)
  --report-only     Generate reports without modifying Dart files
  --verbose         Show progress for each rule
  --cache-file PATH Override cache file location (default: reports/rule_version_cache.json)
```

---

## Implementation Steps

### Step 1: Create `scripts/modules/_rule_version_history.py`

Functions:
- `extract_all_rule_names() -> dict[str, RuleInfo]`
  - Reuse LintCode parsing from `_extract_rule_messages.py`
  - Scan all `*_rules.dart` in `lib/src/rules/` recursively
- `scan_changelogs() -> dict[str, list[ChangelogMention]]`
  - Parse version headers, section headers, rule name mentions
  - Handle both backtick-quoted and bare rule names
- `scan_git_history(rule_names, cache_path) -> dict[str, list[GitMention]]`
  - Run `git log -S` for each rule
  - Map commits to release versions
  - Cache results to JSON
- `compute_versions(changelog_data, git_data) -> dict[str, VersionInfo]`
  - Merge changelog + git events
  - Deduplicate by build version
  - Compute version number

### Step 2: Create `scripts/historical/version_rules.py`

Main entry point:
- Parse CLI args
- Call phase 1-4 functions
- Generate JSON + text reports
- If not `--dry-run` or `--report-only`:
  - Phase 5: modify Dart files
  - Validate results

### Step 3: Modify Dart files (Phase 5 detail)

For each rule file:
1. Read file content
2. Find each `problemMessage:` block
3. Parse the existing string (handling multiline `'...' '...'` concatenation)
4. Append ` {vN}` before the closing quote
5. Find the class DartDoc (`///` block above `class XxxRule`)
6. Insert `/// Since: vX.Y.Z | Updated: vA.B.C | Rule version: vN` line after the first `///` line
7. Write file back

**String format handling:**
- Single-quoted strings: `'...'` — most common
- Multi-line concatenation: `'line1' 'line2'` — append to last segment
- String with escaped quotes: `'don\'t'` — handle escapes

---

## Edge Cases

| Case | Handling |
|------|----------|
| Rule in git but not changelog | Count git events only; created_in = earliest git version |
| Rule in changelog but not git | Use changelog data (may be pre-git or squashed) |
| Rule renamed | Track as new rule (old name gets no updates) |
| Rule deleted then re-added | Count all events across both lives |
| Rule with no history | Default to `v1`, `created_in = "unknown"` |
| Multiline problemMessage | Parse full string across continuation lines |
| Release commits without version tag | Map via `Release vX.Y.Z` commit messages |

---

## Commit-to-Version Mapping Strategy

Build a lookup table from git history:
```python
# Find all release commits
git log --oneline --all --grep="Release v"
# Result: {commit_hash: "4.13.0", ...}

# For each non-release commit, find the next release after it
# This gives us the version that commit shipped in
```

This lets us map any commit hash → build version.

---

## Validation

After Phase 5:
1. Re-run `_extract_rule_messages.py` to get all problemMessages
2. Verify every message ends with ` {vN}` where N >= 1
3. Verify no message has duplicate version tags
4. Verify the existing `[rule_name]` prefix is intact
5. Run `dart analyze` to ensure no syntax errors introduced
6. Count: total rules, version distribution, rules without history

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Git scan takes too long | Cache results; `--skip-git` for reruns |
| Regex misparses Dart strings | Test on 5 rule files first; validate round-trip |
| Version tag breaks existing tests | Run `/test` after modification |
| problemMessage length check breaks | Ensure `{vN}` doesn't push below char minimum (it adds chars, so safe) |
| DartDoc insertion breaks formatting | Match existing indentation; insert after first `///` line |

---

## Estimated Timeline

| Phase | Effort |
|-------|--------|
| Phase 1: Extract rule names | Script: ~30 min |
| Phase 2: Changelog scan | Script: ~45 min |
| Phase 3: Git history scan | Script: ~1 hr; Execution: ~30-60 min |
| Phase 4: Version computation | Script: ~30 min |
| Phase 5: Dart file modification | Script: ~1 hr |
| Testing & validation | ~30 min |
| **Total** | **~4-5 hrs script development** |
