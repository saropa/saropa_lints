# Extension translation status screen

Status: deferred, low priority. Not started.

## Goal

Show per-locale translation coverage inside the VS Code extension, so users and the maintainer see how complete each language is without opening the README or running a script.

## What exists already

- Data: `extension/src/i18n/locale_coverage.json` (`locales.<code>.coveragePct`, `.missing`, plus `generated`). Written by `extension/scripts/i18n/generate_locales.py` on every audit/translate run.
- Reader: `extension/src/i18n/languagePick.ts` imports the JSON and badges locales below 100% in the language picker.
- Terminal/README rendering: `extension/scripts/i18n/coverage_report.py` (table, bars, overall percentage). Logic to mirror, not to duplicate: sort lowest first, English excluded from the overall mean.

## Proposed scope

1. A read-only view (Health Panel section or webview) listing each locale with percentage, bar, untranslated count, and overall percentage, sourced from the same JSON.
2. Keep one source of truth: import `locale_coverage.json`; do not re-measure in TS.
3. All user-facing strings through `l10n()` with keys in `en.json`. Locale names via `Intl.DisplayNames`, not a hand-written map.
4. A button to switch language that reuses the existing language-picker command.

## Out of scope

- Triggering translation from the UI (machine translation is user-run only).
- Per-string drill-down.

## Open decisions

- Placement: new Health Panel card vs standalone webview vs section in the existing language picker.
- Whether the data is bundled at build time (current model, goes stale until next publish) or read from the workspace at runtime (maintainer-only usefulness).

## Verification required

Per `.claude/rules/extension-verification.md`: fresh `npm run compile`, F5 in the Extension Development Host, screenshot saved to `bugs/` in light and dark themes and at ~380px width, covering populated, missing-JSON, and all-100% states. Until then report as unverified.

## No-regen note

Adding `en.json` keys makes locale catalogs stale; regeneration is a publish-time gate and the user's call.
