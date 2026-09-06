# Fix: "Enable all recommended packs" button detection divergence

The "Enable all recommended packs" button in the Rule Packs dashboard showed
"no applicable rule packs detected" while the dashboard table correctly displayed
87 detected packs. The button used `computeConfigSuggestions(root)` which has
early-return guards (`hasSaropaLintsDep`, `hasSaropaLintsConfigured`) that can
return empty before any pack detection runs, while the table used
`isPackDetected(def, pubspecContent)` directly on every `RULE_PACK_DEFINITIONS`
entry.

## Root cause

`_enableAllApplicablePacks()` in `rulePacksWebviewProvider.ts` called
`computeConfigSuggestions(root)` and filtered for `kind === 'pack-available'`.
That function's guard at line 223 returns `[]` when `hasSaropaLintsDep(root)` is
false, and returns only `[{kind: 'init-missing'}]` when the plugin is not
configured — neither of which passes the `pack-available` filter. Meanwhile the
dashboard table at line 817 calls `isPackDetected(def, pubspecContent)` directly,
bypassing both guards.

## Fix

Extracted `getDetectedPackIds(pubspecContent)` in `rulePackDefinitions.ts` as
the single source of truth for pack applicability. Both the dashboard table and
the "Enable all recommended" button now call this function, eliminating the
two-path divergence. Removed the now-unused `computeConfigSuggestions` import
from the webview provider (still imported by `startupSuggestionNudge.ts`).

## Trade-off acknowledged

`computeConfigSuggestions` combines four detection signals (pubspec markers, SDK
gate, lockfile-resolved upgrades, platform folders, marker files). The table only
uses the first signal (`isPackDetected`). The button now matches the table, not
the suggestions sidebar. This means packs detected only via lockfile, platform
folders, or marker files will appear in the suggestions sidebar but not in the
table or button. That divergence is pre-existing in the table and is a separate
issue from the false "no applicable packs" bug.

## Files changed

- `extension/src/rulePacks/rulePackDefinitions.ts` — added `getDetectedPackIds`
  as shared helper returning applicable pack ids from pubspec content
- `extension/src/rulePacks/rulePacksWebviewProvider.ts` — table and button both
  call `getDetectedPackIds` instead of inlining independent `isPackDetected`
  filters; removed unused `computeConfigSuggestions` import
- `CHANGELOG.md` — added fix entry and maintenance note under
  `[16.0.0-beta.7] — Unreleased`

## Finish Report (2026-09-06)

TypeScript compiles clean (`tsc --noEmit` for both production and test configs).
No existing tests affected — `_enableAllApplicablePacks` is a private method with
VS Code API dependencies not covered by unit tests. The underlying `isPackDetected`
function is tested via `rulePackDefinitions.test.ts`.

Code review (medium, 6 angles) found no correctness bugs in this change. The
removed-behavior auditor flagged the reduced detection signal count (4 → 1),
assessed as intentional alignment with the table. Hardening extracted
`getDetectedPackIds` as a shared helper so a future detection-signal addition
only needs to change one function.
