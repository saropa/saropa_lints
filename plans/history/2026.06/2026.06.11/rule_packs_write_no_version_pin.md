# Fix: "Enable upgrade lints" nudge failed on configs without a plugin `version:` pin

**Trigger (user report, verbatim):** "this very project is raising an upgrade toast then showing this error — Saropa Lints: could not write analysis_options.yaml (rule_packs)."

The saropa_lints package's own `analysis_options.yaml` deliberately omits the `version:` pin under `plugins.saropa_lints:` (the plugin loads from workspace source, not pub.dev). The upgrade-pack nudge's YAML writer could only anchor a new `rule_packs` block on a `version:` line directly under `saropa_lints:`, so with no version line it found no anchor, returned `false`, and surfaced the error toast.

## Finish Report (2026-06-11)

### 1. Critical Note


### 2. Scope
**(B) VS Code extension (TypeScript).** Touches `extension/src/rulePacks/rulePackYaml.ts` (writer logic), `extension/src/test/rulePacks/rulePackYaml.test.ts` (regression test), and root `CHANGELOG.md`. No Dart lint-rule / analyzer-plugin (A) code and no docs/scripts-only (C) work beyond the changelog.

### 3. Deep Review
- **Logic & Safety:** `insertRulePacksAfterVersion` now tries the `version:` anchor first (preferred — matches `saropa_lints:init` consumer output), then falls back to the `saropa_lints:` mapping key. The fallback regex `^[ \t]*saropa_lints:[ \t]*\n` (multiline) cannot match the `#`-prefixed `saropa_lints:init` comment lines: a comment line starts with `#`, and the regex requires the key at the line's leading indent followed by end-of-line, not `:init`. First match in the real config is the `  saropa_lints:` plugin key (line 99). The `include: package:saropa_lints/tiers/...` line contains `saropa_lints/` (slash), not `saropa_lints:` (colon), so it never matches. Returns `null` only when there is genuinely no `saropa_lints:` mapping — the correct failure path.
- **Architecture & Adherence:** Single-function change; reuses the existing `content.replace` insertion pattern. Block body indentation (4-space `rule_packs:` under the 2-space `saropa_lints:` key) is correct YAML nesting. No new utilities or duplication introduced.
- **Linter-Specific Integrity:** SKIPPED [B-NOT-IN-SCOPE] — extension TypeScript, not a Dart lint rule; no `tiers.dart` / `LintImpact` involvement.
- **Performance:** Two short regex executions on a single file read already performed by the writer. No added I/O.
- **Documentation Quality:** Added a verbose WHY comment block explaining the preferred-vs-fallback anchor strategy, the exact failure mode it fixes (the user-visible toast string), and why the comment lines cannot false-match.

### 4. Testing Validation
**A. Existing-test audit (mandatory):** Grepped `extension/src/test` for `insertRulePacksAfterVersion`, `writeRulePacksEnabled`, `rulePackYaml`, and the toast string. Only `extension/src/test/rulePacks/rulePackYaml.test.ts` references the changed symbols. Read it in full — no existing assertion pins the no-version behavior, and the `version:`-present cases (`writeRulePacksEnabled normalizes legacy migration_packs to rule_packs`) still hold because the preferred `version:` anchor path is unchanged. No assertion broke.
**B. New test:** Added `writeRulePacksEnabled inserts block when version pin is absent` — writes a config with no `version:` key (including the `saropa_lints:init` comment line as a false-match guard), asserts the write returns `true`, the `rule_packs:` block is inserted, the existing `diagnostics:` survives, and the round-trip parse returns `['riverpod', 'drift']`.
**Run:** `node node_modules/mocha/bin/mocha "out-test/test/rulePacks/rulePackYaml.test.js" --timeout 10000` → **9 passing.** Type-check: `npx tsc --noEmit -p ./` (in `extension/`) → exit 0.
Note: the sibling `rulePacksWebviewProvider.test.js` fails to load with a pre-existing `MODULE_NOT_FOUND` on a build-output path (`out-test/rulePacks/rulePacksWebviewProvider.js`); unrelated to this change (that file was not touched).

### 5. Extension l10n Validation
No `en.json` key and no `package.nls.json` source key changed. No user-facing string was added or edited — the error toast (`'Saropa Lints: could not write analysis_options.yaml (rule_packs).'`) already existed in `upgradePackNudge.ts` and `rulePacksWebviewProvider.ts` and was not modified. Catalog regeneration not triggered; coverage gate unaffected (0 missing unchanged).

### 6. Project Maintenance & Tracking
- CHANGELOG: entry added under `### Fixed (Extension)` in `[Unreleased]`.
- README verified — no updates needed (rule/doc counts unchanged).
- `pubspec` / `package.json` — not a release or dependency change; untouched.
- ROADMAP — no lint rule added or completed; untouched.
- guides reviewed — nothing user-facing in `doc/guides/` affected.
- No bug archive — task did not close a `bugs/*.md` file (none described this symptom).

### 7. Persist Finish Report
Finish report saved: plans/history/2026.06/2026.06.11/rule_packs_write_no_version_pin.md

### 9. Commit & Finalization
Fix code, regression test, and changelog entry were committed in `19959bed` (bundled by a concurrent session). This finish-report file is committed as a follow-up. No outstanding work.

**Files (committed in 19959bed):**
- `extension/src/rulePacks/rulePackYaml.ts` — `insertRulePacksAfterVersion` fallback anchor
- `extension/src/test/rulePacks/rulePackYaml.test.ts` — no-version regression test
- `CHANGELOG.md` — Fixed (Extension) entry

**Core logic diff:** `insertRulePacksAfterVersion(content, blockBody)` — was: single `version:`-anchored regex, return `null` on no match. Now: try `version:` anchor first; on miss, anchor on `^[ \t]*saropa_lints:[ \t]*\n` and insert the block as that mapping's first child; return `null` only if no `saropa_lints:` key exists.
