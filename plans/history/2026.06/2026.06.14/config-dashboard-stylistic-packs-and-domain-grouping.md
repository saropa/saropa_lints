# Config dashboard: stylistic-rule discoverability and domain grouping

The Config dashboard (Manage Rule Packs) exposed only the ecosystem packs as one
flat, fully-expanded table of ~86 rows, and offered no way to reach the ~220
stylistic (opinionated) rules at all — those rules are off in every tier,
including pedantic, and were previously reachable only through the Dart setup
wizard. A user opening the dashboard saw a long wall of toggles with no relevance
ordering and no path to the opinionated rules, and once those rules surfaced there
was no in-screen signal for whether a given rule or group was safe or noisy to
enable. The change adds a dedicated stylistic section, reorganizes the ecosystem
packs by relevance and domain, and surfaces decision-support descriptions so a
user can decide what to turn on without drilling into each rule.

## Finish Report (2026-06-14)

### Scope

(B) VS Code extension — TypeScript under `extension/src/rulePacks/` and
`extension/src/i18n/locales/en.json`, plus one Dart generator tool
(`tool/generate_rule_pack_registry.dart`) that emits a generated TypeScript
registry. No analyzer-plugin rules, tiers, or `LintImpact` assignments changed.

### What changed

**Stylistic rules are now a generated registry.** `tool/generate_rule_pack_registry.dart`
gained `_writeStylisticPackDefinitionsTs`, which reads `stylisticRuleCategories`
from `lib/src/init/stylistic_rulesets.dart` — the same source the setup wizard
uses — and emits `extension/src/rulePacks/stylisticPackDefinitions.ts`
(`STYLISTIC_PACK_DEFINITIONS`). Each category becomes a pack with a stable
snake_case id, a clean label, and a `selectionMode` of `'pickOne'` for the
"(conflicting - choose one)" categories or `'multi'` for the rest. Generating
from the existing source keeps the dashboard and the wizard in sync on the next
regeneration rather than duplicating the grouping. The registry carries no
pubspec or SDK gates because stylistic rules are pure opt-ins, not
dependency-driven.

**A "Style & opinions" section was added to the dashboard.** `rulePacksWebviewProvider.ts`
builds a collapsed accordion below the packs. Conflicting groups render as
pick-one radio sets with a "None" option and a left accent bar, so two
contradictory rules can never be enabled at once; multi groups render as
independent checkbox toggles with per-group enable-all / disable-all. Enabling a
rule writes a `rule: true` entry to the RULE OVERRIDES section via
`writeRuleOverrides`; disabling removes the override via `removeRuleOverrides`,
returning the rule to its off-by-default state instead of pinning it `false`.
The section's enabled state is derived from `readRuleOverrides` (entries set to
`true`) carried on `DashboardContext.enabledStylistic`. Three postMessage
handlers (`toggleRule`, `selectStylistic`, `stylisticBulk`) validate the rule
name as a snake_case id and confirm group membership before any config write,
because the message payload is untrusted.

**The ecosystem packs are split by relevance and grouped by domain.** The former
single table became two accordions: "For your project" (packs whose dependency
or SDK gate matches the pubspec) opens by default; "All packages" is collapsed
and sub-grouped into nine editorial domains via the hand-maintained
`packDomains.ts` (State management, Networking & APIs, Storage & persistence,
Navigation & deep links, Media & graphics, Device & platform, Identity & sharing,
Utilities & config, and SDK migrations). The domain map is intentionally separate
from the generated pack registry so a regeneration never clobbers it, and any
unmapped pack falls back to an "Other" domain so nothing is hidden (current
coverage: all 86 packs mapped, zero in "Other"). Detected packs in the flat list
carry a domain chip beside the name; domain accordions carry the domain in the
header instead.

**Decision-support descriptions were added.** Each multi-select stylistic group
and each ecosystem domain shows a one-line description sourced from
`extension/src/i18n/locales/en.json` (`stylistic.desc.*`, `packs.domainDesc.*`),
including the noisiness warnings for Ordering, Naming, and Formatting so a
reformat-everything group is distinguishable from a quiet one before it is
enabled. Descriptions render only when the key resolves (the empty "Other"
catch-all has none). Conflicting pick-one pairs carry no description because the
two rule names are self-evident.

**The dashboard client script was made multi-table aware.** `configDashboardScript.ts`
now iterates every `tbody.packs-tbody` for filtering and sorts within each table
independently, so detected and all-packages groups stay separate. When a filter
is active, the ancestor `<details>` chain of any surviving row is opened so a
search never hides matches behind a collapsed domain group. The chart bar-click
handler opens the matching pack's containing accordion before scrolling to it.
New wiring covers stylistic toggles, pick-one radios (including the clear-all
"None"), bulk buttons, and a local stylistic search.

### Verification

- `npx tsc --noEmit` (extension check-types): 0 errors.
- `node esbuild.js` (production-shape bundle): clean.
- `npx tsc -p tsconfig.test.json` then mocha on `out-test/test/rulePacks/**`
  with the vscode mock preloaded: 38 passing.
- Generated client script parsed via `new Function(...)`: valid (no
  template-literal escaping defects).
- All 12 stylistic-group descriptions and 9 real domain descriptions resolve
  through `l10n` with English fallback; the "Other" domain intentionally has none.
- `dart analyze` on `tool/generate_rule_pack_registry.dart`: no issues.
- Existing test audit: `test/rulePacks/rulePacksWebviewProvider.test.ts` imports
  only pure helper functions whose signatures were unchanged; `_buildPackRow`
  gained a defaulted optional parameter (backward compatible); no test pinned the
  removed single `packs-tbody` id (grep confirmed). All 38 rulePacks tests pass.

### Outstanding

- Translated locale catalogs (`extension/src/i18n/locales/<lang>.json`) are stale
  for the new `stylistic.*` / `packs.*` keys. Regenerating them requires the
  machine-translation pipeline, which is under a standing prohibition and needs
  explicit per-run authorization naming the command; it was not run. At runtime
  `l10n` falls back to English for the missing keys, so no string renders blank;
  the publish coverage gate would flag the gap until the catalogs are regenerated.
- Individual ecosystem packs (e.g. `dio` vs `dio_5`) have no bespoke per-pack
  purpose line; they rely on the package name, the domain description and chip,
  the expandable rule list, and Rule Explain. Domain-level context was chosen over
  86 hand-authored pack blurbs.
