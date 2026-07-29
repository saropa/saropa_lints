# Bug: Rule packs UI fails silently in the saropa_lints package itself

**Status:** Fixed
**Filed:** 2026-07-29
**Component:** VS Code extension — rule packs

## Symptoms

When the VS Code extension runs with the saropa_lints package as the workspace
(i.e. developing the plugin itself, not a consumer project), two misleading
toasts appear:

1. **"Saropa Lints: could not write analysis_options.yaml (rule_packs)."** —
   toggling any pack in the Config Dashboard.
2. **"Saropa Lints: every applicable rule pack is already enabled."** —
   clicking "Enable all applicable packs."

The user had to enable rules manually.

## Root cause

The extension assumes the workspace is a **consumer** of saropa_lints. The
saropa_lints package itself breaks both assumptions:

- **No dependency on itself.** `hasSaropaLintsDep` checks for `saropa_lints`
  in pubspec.yaml dependencies. The package's own pubspec has
  `name: saropa_lints`, not a dependency entry. So `computeConfigSuggestions`
  returns `[]`, and `_enableAllApplicablePacks` reports "already enabled" with
  zero applicable packs — a false positive.

- **No `saropa_lints:` plugin block.** The package's own
  `analysis_options.yaml` has no `plugins: saropa_lints:` mapping (the plugin
  is loaded implicitly from workspace source). `writeRulePacksEnabled` cannot
  find an anchor to insert or replace the `rule_packs` block, so it returns
  false and the generic "could not write" error fires.

## Affected code paths

| File | Function | Line |
|------|----------|------|
| `extension/src/config/configSuggestions.ts` | `computeConfigSuggestions` | 220 |
| `extension/src/pubspecReader.ts` | `hasSaropaLintsDep` / `hasPubspecDependency` | 78–98 |
| `extension/src/rulePacks/rulePackYaml.ts` | `writeRulePacksEnabled` / `insertRulePacksAfterVersion` | 91–148 |
| `extension/src/rulePacks/rulePacksWebviewProvider.ts` | `_enableAllApplicablePacks` | 1555–1612 |
| `extension/src/rulePacks/rulePacksWebviewProvider.ts` | `_handleToggle` | 1275–1305 |

## Fix options

### Option A: Detect self-package and disable rule packs UI

Add `isSelfPackage(root)` (check `name: saropa_lints` in pubspec). When true,
disable the pack toggles in the Config Dashboard and show a single clear
message: "Rule packs are not available when developing saropa_lints itself."

### Option B: Support rule packs in the self-package

Create/find the `saropa_lints:` block in analysis_options.yaml even for the
plugin's own config. This is more complex and may not be desired since the
package's own analysis_options.yaml intentionally excludes `lib/**`.

### Option C: Fix the misleading messages only

Keep the current behavior (no write for self-package) but replace the toasts:
- "could not write" → "analysis_options.yaml has no saropa_lints plugin block."
- "already enabled" → "no applicable packs found for this project."

**Recommendation:** Option A — the clearest UX. The self-package is not a
consumer and should not pretend to support consumer features.

## Repro

1. Open `d:\src\saropa_lints` in VS Code with the Saropa Lints extension active.
2. Open the Config Dashboard (Manage Rule Packs).
3. Click "Enable all applicable packs" → see false "already enabled" toast.
4. Toggle any individual pack → see "could not write" error toast.

## Finish Report (2026-07-29)

**Approach chosen:** A hybrid of Options A–C. The extension now fully supports the self-package rather than disabling the UI.

**Changes (4 files + tests):**

- **`pubspecReader.ts`** — New `isSaropaLintsPackage(root)` function checks `name: saropa_lints` in pubspec.yaml via anchored regex `^name:\s+saropa_lints\s*$`. `hasSaropaLintsDep` calls it first, so the self-package is recognized as a valid saropa_lints workspace.
- **`configSuggestions.ts`** — `hasSaropaLintsConfigured` short-circuits to `true` for the self-package, bypassing the `plugins: saropa_lints:` regex check. The plugin loads implicitly from workspace source in that case.
- **`rulePackYaml.ts`** — `insertRulePacksAfterVersion` gained two fallback branches: (1) when a bare `plugins:` key exists but no `saropa_lints:` child, insert `saropa_lints:` + `rule_packs` block under it; (2) when no `plugins:` key exists at all, append the entire `plugins:\n  saropa_lints:\n  rule_packs:\n    enabled:\n` block at end of file.
- **`rulePacksWebviewProvider.ts` + `en.json`** — `_enableAllApplicablePacks` now checks `applicableIds.length === 0` before the `toAdd.length === 0` check, surfacing a distinct "no applicable rule packs detected for this project" message instead of the misleading "already enabled."

**Tests added (7 new, 25 total in suite):**

- `rulePackYaml.test.ts`: `writeRulePacksEnabled creates plugins block when no saropa_lints key exists`, `writeRulePacksEnabled inserts under existing plugins key without saropa_lints`.
- `configSuggestions.test.ts`: `treats self-package as configured without a plugin block`.
- `isSaropaLintsPackage` suite (4 tests): true for self-package, false for consumer, false for missing pubspec, false for `saropa_lints_something`.

**Known limitation:** `isSaropaLintsPackage` and `hasPubspecDependency` each read `pubspec.yaml` independently, causing a double read in the common consumer-project case. Low impact (small file, cached by OS), flagged for future consolidation.

**l10n:** One new `en.json` key (`noApplicablePacksDetected`). Non-English locale catalogs require regeneration before publish.
