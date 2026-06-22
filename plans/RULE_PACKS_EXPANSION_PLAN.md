# Rule Packs Expansion Plan

Status: Draft (planning)
Owner: TBD
Date: 2026-06-22

## Problem

Today the Rule Packs webview surfaces **90 packs** that cover only three things:
package ecosystems, SDK version migrations, and four "quality standard" packs
(`ui_excellence`, `localization`, `documentation`, `testing`). Everything else —
the bulk of the ~2,300 rules — is reachable only by raising the **tier** dial.

Tier distribution (rule counts, from `lib/src/tiers.dart`):

| Tier | Adds | Cumulative |
|---|---|---|
| Essential | 329 | 329 |
| Recommended | 714 | 1,043 |
| **Professional** | **974** | **2,017** |
| Comprehensive | 211 | 2,228 |
| Pedantic | 16 | 2,244 |
| Stylistic (opt-in) | 247 | — |

The largest buried bucket is **Professional (974 rules)**. Raising the tier dumps
all of them at once (noisy), so users don't — and those rules never surface.

Packs are a **tier-independent** axis: enabling a pack turns on its rules
regardless of tier (the webview states this: "Pack-owned rules are off unless
that pack is enabled. Tiers control broad baselines."). Packs are therefore the
correct mechanism to surface rules by **relevance** — your platform, your
packages, your concern — instead of by severity.

## Decided model (2026-06-22): additive packs + exclusive version groups

User's rule: **a rule is valid if it is in an enabled tier OR an enabled pack.**
Tiers are the minimum floor; packs supplement, they do not contradict. So the
default effective set is `tier_floor ∪ (rules of enabled packs)`.

**One carve-out — version groups.** Some rules apply only to a specific package
major (e.g. `avoid_dio_error` applies to dio 5, not dio 4). For these, the
package forms an **exclusive group**: the user picks one version (dio 4 / dio 5 /
none), and **the group choice wins over the tier** — a version rule for an
unselected version stays off even if a tier lists it. The selected version's
pack carries every rule still valid for that version (dio 5 includes the
still-valid dio 4 rules plus its own). Non-version rules stay purely additive.

Why the carve-out is required: measured overlap (2026-06-22) shows **75 of 94
version-gated migration rule codes also live in a tier**, so pure tier∪packs
would fire version-specific rules on the wrong major.

UI: version groups render with the existing `pickOne` radio mechanism already
used for conflicting stylistic rules (`_buildStylisticGroup` in
`rulePacksWebviewProvider.ts`), shown as their own section; selecting one version
visually reflects the others turning off.

**Current merge contradicts this.** `mergeRulePacksIntoEnabled`
(`lib/src/config/rule_packs.dart`) runs `enabled.removeAll(allRulePackCodes())`
then re-adds only enabled packs — fully subtractive. Overlap that this wrongly
strips: 509 of 601 package-pack codes and all 141 thematic-pack codes are in
tiers. Left intact for now (shipping behavior); Phase 0 replaces it.

Behavior change to accept: a non-version rule in both a tier and a package pack
fires from the tier floor even when that package pack is not enabled.

## Goals

1. **Platform packs** — surface the existing per-platform rule sets as packs,
   auto-detected from embedder folders.
2. **Theme packs** — one pack per concern (security, accessibility, performance,
   …), mapping to the existing source-tree domains.
3. **Tag-based membership** — model packs as queries over rule tags so a single
   rule can belong to many packs (overlap is expected and allowed). This enables
   compliance packs, profile bundles, and intent packs without re-tagging.
4. **Richer recommendation** — recommend packs from detected project features:
   folders, marker files, and pubspec sections, not just dependency names.

Overlap is a feature, not a bug: the same lint legitimately appears in its
platform pack, its theme pack, and any compliance/profile pack that includes it.

## Current architecture (what exists)

- **Pack registry**: `extension/src/rulePacks/rulePackDefinitions.ts` — GENERATED
  by `tool/generate_rule_pack_registry.dart`. Do not hand-edit; change the
  generator and its Dart source-of-truth.
- **Domain grouping (UI only)**: `extension/src/rulePacks/packDomains.ts` —
  hand-maintained editorial map; not a property of rules.
- **Webview**: `extension/src/rulePacks/rulePacksWebviewProvider.ts` — per-pack
  enable checkboxes; domain accordions are display-only (no domain-level toggle).
- **Platform rule sets ALREADY EXIST** in `lib/src/tiers.dart`:
  `iosPlatformRules` (83), `androidPlatformRules` (13), `macosPlatformRules` (15),
  `webPlatformRules` (11), `windowsPlatformRules` (5), `linuxPlatformRules` (5),
  plus `_applePlatformRules`, `_desktopPlatformRules`, `platformRuleSets`, and
  `getRulesDisabledByPlatforms()` — but these are used SUBTRACTIVELY (disable
  rules for absent platforms), not surfaced as selectable packs.
- **Platform detection ALREADY EXISTS**: `detectEmbedderPlatforms()` in
  `extension/src/pubspecReader.ts` scans for `ios/`, `android/`, `web/`,
  `windows/`, `macos/`, `linux/` folders. The webview shows a read-only
  "Target platforms: Yes/No" table (`_buildPlatformsBlock`).
- **Recommendation engine**: `extension/src/config/configSuggestions.ts` —
  `computeConfigSuggestions(root)` is the single source. Today it keys off
  pubspec dependency names (`isPackDetected` via `matchPubNames` + `sdkGate`)
  and lockfile-resolved versions (`dependencyGate`). It reads NO folders, marker
  files, or pubspec sections. Drives the coalesced startup nudge
  (`startupSuggestionNudge.ts`) and the "Enable all recommended packs" button.

## Source-tree domains (theme-pack source)

The rule source is already organized by concern under `lib/src/rules/`:
`architecture`, `codegen`, `code_quality`, `commerce`, `config`, `core`, `data`,
`flow`, `hardware`, `media`, `network`, `resources`, `security`, `stylistic`,
`testing`, `ui`, `widget` (plus `packages/`, `platforms/`). Theme packs map
nearly 1:1 to these directories.

## Pack axes (the grouping model)

A rule carries tags on several independent axes; every pack/bundle is a query
over those tags. Overlap is automatic.

### Axis 1 — Platform (auto-detected; rule sets exist)
`ios`, `android`, `web`, `windows`, `macos`, `linux`.

### Axis 2 — Theme / concern (maps to source dirs)
security, accessibility, performance, async-concurrency, error-handling,
resource-disposal, state-management, navigation-routing, forms-input, theming,
internationalization, architecture-di, data-integrity, documentation,
testing-debug, code-quality-complexity.

### Axis 3 — Compliance / standard (cross-cutting, overlap-heavy)
- **OWASP Mobile Top 10** — mapping currently lives as dartdoc prose
  (`/// **OWASP:** M5:...`); generator must parse those into a structured tag.
- **WCAG accessibility** — overlaps the a11y theme pack.
- **Privacy & data protection** — PII-in-logs, secure storage, permission
  justification.
- **App Store / Play Store submission readiness** — usage descriptions,
  store-listing rules, review-prompt rules (submission blockers).
- **Release / production hardening** — no debug prints, no hardcoded secrets,
  release-mode gating.

### Axis 4 — App-profile bundles (a bundle = a set of packs)
fintech/commerce, regulated/enterprise, games, offline-first/data-heavy,
maps-location.

### Axis 5 — Intent / workflow
CI blocker gate (ERROR-severity only), pre-release audit, strict starter,
migration assistant (partly exists as `*_6` / `dart_sdk_*` packs).

## Detection signals for recommendation

Extend `RulePackDefinition` with an optional `detect` block and gather a
`ProjectSignals` struct once per scan.

```ts
interface PackDetect {
  folders?: readonly string[];        // e.g. ['ios'], ['test', 'integration_test']
  files?: readonly string[];          // globs, e.g. ['**/*.g.dart'], ['.github/workflows/*.yml']
  pubspecSections?: readonly string[];// e.g. ['flutter.assets'], ['flutter.generate']
  // existing: matchPubNames, dependencyGate, sdkGate
}
```

Signal sources:
- **Folders** → platform packs (reuse `detectEmbedderPlatforms`), `test/` →
  testing, `l10n/` → i18n, `assets/` → media.
- **Marker files** → `google-services.json` / `GoogleService-Info.plist` →
  firebase; `*.g.dart` / `*.freezed.dart` → codegen/freezed; `.github/workflows/*`
  → CI blocker gate; `Podfile`, `build.gradle`.
- **pubspec sections** → `flutter: generate: true` → i18n; `flutter: assets:` →
  media; payment deps → commerce/fintech profile.

`computeConfigSuggestions` reads `ProjectSignals` once and runs every pack
through a unified `detectPack(def, signals)`; the existing pubspec/lockfile paths
become two signal sources among several. No parallel detector.

## Phases

### Phase 0 — Additive merge + version groups (prerequisite)
- Replace the `removeAll(allRulePackCodes())` strip. New effective set:
  `tier_floor ∪ enabled-pack rules`, then for each **version group** remove the
  rules of every non-selected version in that group (group choice wins over
  tier). Preserve the `disabled` (explicit `false`) opt-out as the override.
- Define version groups as data (the generator emits which packs belong to one
  exclusive group, e.g. `dio` → {dio4, dio5}). Today this is base pack + gated
  `_5`/`_6` add-ons; restructure so each version is a selectable member.
- Webview: render version groups via the existing `pickOne` radio path.
- Re-check the incremental subtract-before-remerge path for correctness.
- Tests: (a) a tier rule stays on when a non-version pack containing it is off;
  (b) selecting dio 4 keeps a dio-5-only rule off even though a tier lists it;
  (c) selecting dio 5 enables both still-valid dio-4 rules and dio-5 rules;
  (d) a rule in two enabled packs counts once.

### Phase 1 — Platform packs
- Add platform packs to the generator's Dart source-of-truth, ruleCodes drawn
  from the existing `platformRuleSets` in `tiers.dart` (single source of truth —
  do not duplicate the rule lists).
- Add a `detect.folders` signal; auto-recommend a platform pack when its embedder
  folder is present.
- Add a `Platforms` domain to `packDomains.ts` and `PACK_DOMAIN_ORDER`.
- Decide interaction with `getRulesDisabledByPlatforms()` (subtractive) so a
  platform pack (additive) and the platform-disable path do not contradict.

### Phase 2 — Theme packs
- Tag rules by source-dir domain (generator reads the file path) → emit one theme
  pack per domain.
- Add theme packs to the registry + a `Themes` domain grouping.

### Phase 3 — Tag-based membership
- Introduce a rule-tag model (platform / theme / compliance / severity) the
  generator emits.
- Reframe every pack as a tag query; OWASP tag parsed from dartdoc.
- Enables Axes 3-5 with no further rule edits.

### Phase 4 — Recommendation widening
- Extend `RulePackDefinition.detect` and `ProjectSignals`.
- Widen `computeConfigSuggestions` to consume folders / marker files / pubspec
  sections via `detectPack`.
- Surface compliance/profile/intent recommendations through the existing
  coalesced nudge + "Enable all recommended packs".

## Open decisions

1. **Overlap accounting** — when a rule is in N enabled packs, the pack-rule
   count and "enabled rules" stat must de-dup. Confirm the YAML writer / count
   logic handles a rule owned by multiple enabled packs.
2. **Bundle representation** — are Axis-4 profile bundles first-class packs
   (a pack whose members are packs) or a separate "presets" concept in the UI?
3. **Generated vs hand-maintained** — packDomains is hand-maintained today;
   confirm whether new domains stay hand-maintained or move into the generator.
4. **Tier vs pack precedence** — when a pack enables a Professional-tier rule on
   a project set to Essential, confirm the pack wins (expected) and document it.

## Non-goals

- No new lint rules. This plan only re-surfaces existing rules.
- No translation/MT runs (new i18n keys for pack labels are added normally; the
  MT pipeline stays on its own cadence).
