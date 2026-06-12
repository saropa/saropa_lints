# Coalesced startup rule-pack suggestion nudge (Extension)

On opening a Flutter/Dart project, the VS Code extension surfaced applicable-but-disabled
rule packs through independent notification toasts that fired around activation with no
coordination between them. When two fired seconds apart, VS Code's newest-on-top stacking
pushed the earlier toast out of the visible stack and both auto-collapsed into the
notification center before they could be read. A race between the deferred activation timer
and the `pubspec.lock` watcher — both invoking the same nudge — could additionally spawn two
toasts for the same offer. The result was that a user prompted to enable one package's rules
saw a second prompt appear and both vanish before either could be acted on.

## Finish Report (2026-06-12)

### Scope
(B) VS Code extension (TypeScript under `extension/`). No Dart lint-rule, analyzer-plugin,
`example/`, or `analysis_options*.yaml` files were touched, so the Dart-rule sections of the
linter finish checklist are out of scope.

### What changed

**Single coalesced startup notification.** The per-package upgrade-pack toast was replaced by
one notification that summarizes the count of applicable suggestions and routes its "Review"
action to the existing Suggestions view. The vscode-wired module was renamed
`upgradePackNudge.ts` → `startupSuggestionNudge.ts`, its exported entry point renamed
`maybeOfferUpgradePacks` → `maybeShowStartupSuggestion`. A module-level in-flight guard
collapses any overlap between the activation timer and the `pubspec.lock` watcher to a single
toast, closing the race that produced duplicate prompts. The inline one-click "Enable" on the
old toast is intentionally dropped; enabling now happens per-pack in the Suggestions view,
which is where the actual `rule_packs` write (via the `saropaLints.enableRulePack` command)
already lives.

**The Suggestions view is now the single complete surface.** `computeConfigSuggestions`
previously excluded dependency-gated migration packs (dio_5, bloc_8, …) because pubspec.yaml
alone cannot verify a semver lower bound, which would have produced false positives on an old
major. Those packs are now folded back in via a lockfile path (`upgradePackSuggestions`) that
reads `pubspec.lock`, resolves the installed version with the existing `parseLockVersions` /
`applicableDisabledPacks` helpers, and applies the same `>=` gate the Dart plugin enforces.
The two sources are disjoint (the pubspec path excludes dependencyGate packs), so a plain
concat cannot duplicate ids. With every applicable pack now listed in one view, the activity-bar
badge on that view is the durable backstop: it persists the count after the single toast
auto-collapses, so nothing is lost.

**Badge re-count on dependency change.** Because the suggestion count now depends on
`pubspec.lock`, that file was added to the config-suggestions file-watcher glob so a
`pub upgrade` that brings a migration pack into range re-counts the badge immediately rather
than only on the next analysis.

**Localization.** Three user-facing strings were added to `extension/src/i18n/locales/en.json`
under a new `startupNudge` namespace (`message`, `review`, `dismiss`) and rendered through
`l10n()`. No developer/log strings were introduced into the catalog.

### Files changed
- `extension/src/config/configSuggestions.ts` — added `readPubspecLock`, `toPackSuggestion`,
  `upgradePackSuggestions`; merged lockfile-resolved upgrade packs into
  `computeConfigSuggestions`; updated the exclusion doc comment.
- `extension/src/rulePacks/startupSuggestionNudge.ts` — renamed from `upgradePackNudge.ts`;
  rewritten as the coalesced one-toast nudge with an in-flight race guard and a per-workspace
  surfaced-id once-gate.
- `extension/src/extension.ts` — import + three call sites repointed to
  `maybeShowStartupSuggestion`; `pubspec.lock` added to the config-suggestions watcher glob.
- `extension/src/i18n/locales/en.json` — new `startupNudge` keys.
- `extension/src/test/configSuggestions.test.ts` — three cases pinning lockfile-gated
  inclusion (resolved 5.x surfaces dio_5; 4.x does not; no lockfile does not).
- `CHANGELOG.md` — bullet under `### Changed (Extension)` in `[Unreleased]`.

### Verification
- `npm run check-types` (`tsc --noEmit`) — clean.
- `configSuggestions.test.ts` + `upgradePackNudgeLogic.test.ts` — 16 passing, 0 failing. The
  three new cases prove the dependency-gated pack appears only when the resolved lockfile
  version satisfies the gate.
- Pre-existing, unrelated full-suite failures left untouched: ten "cross-file commands" cases
  (pass in isolation; suite-ordering pollution in files not touched here) and one "languagePick"
  case (asserts zh=4%/de=100% while the committed `locale_coverage.json` reports zh=99%/de=99%;
  fails identically without any change here).

### Outstanding
- The 24 translated locale catalogs are stale for the three new `startupNudge` keys. The
  catalog regeneration is the NLLB machine-translation pipeline, a separate authorized job on
  its own cadence; it was not run here. Until it runs, the coalesced toast renders in English
  on non-English UIs.
