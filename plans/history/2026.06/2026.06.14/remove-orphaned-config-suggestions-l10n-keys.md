# Remove orphaned configSuggestions localization keys (Extension)

Three keys under the `configSuggestions` namespace in the extension's English catalog
(`extension/src/i18n/locales/en.json`) — `packAvailable`, `initMissing`, and `badgeTooltip` —
had no remaining reader. They were written for the standalone Suggestions sidebar tree, which
the 2026-06-13 Manage Rule Packs overhaul deleted along with its `ConfigSuggestionsTreeProvider`.
The keys survived that deletion as dead catalog entries.

## Finish Report (2026-06-14)

### Scope
(B) VS Code extension — localization catalog only. No Dart lint-rule, analyzer-plugin,
`example/`, or `analysis_options*.yaml` files were touched.

### What changed
`extension/src/i18n/locales/en.json` — deleted the `configSuggestions.packAvailable`
(`title` + `detail`), `configSuggestions.initMissing` (`title` + `detail`), and
`configSuggestions.badgeTooltip` entries. The two surviving keys in the namespace,
`configSuggestions.enabledToast` and `configSuggestions.enableFailed`, are retained: both are
read by the `saropaLints.enableRulePack` command in `extension/src/extension.ts`, which the
Manage Rule Packs webview still invokes.

A matching one-line entry was added to the CHANGELOG `[Unreleased]` Maintenance block.

### Why
A catalog key with no consumer is dead weight: it cannot be reached by any `l10n()` call, yet
it remains in the translation pipeline's source set. Removing it keeps the catalog aligned with
the code that actually renders strings after the Suggestions tree was retired.

### Verification
- `node -e "JSON.parse(...en.json)"` — the catalog remains valid JSON after the deletion.
- `npm run check-types` (`tsc --noEmit`, 8 GB heap) — clean.
- Grep of `extension/src` (excluding `locales/`) confirms zero references to
  `configSuggestions.packAvailable`, `configSuggestions.initMissing`, or
  `configSuggestions.badgeTooltip`.
- Grep of `extension/src/test` confirms no test pins any of the removed keys.

### Translated catalogs
The 24 translated locale files still carry these three keys as harmless extras. The runtime
resolver (`extension/src/i18n/runtime.ts`) only looks up keys requested by code, so unreferenced
extras are inert. The publish coverage gate (`generate_locales.py --fail-on-missing`) flags keys
MISSING from a translated catalog, never extras; removing keys from the English source shrinks
the required set, so every translated catalog remains a superset and the gate stays at zero
missing. No catalog regeneration was required, and the machine-translation pipeline was not run.
