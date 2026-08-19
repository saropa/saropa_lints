# Rule Count Correction (2100+ → 2332)

The package's advertised rule count had drifted stale across marketing and documentation surfaces — several files still said "2100+" or an intermediate "2134"/"2057", while the actual tier registry (`lib/src/tiers.dart`) defines 2332 rules (2109 across the five progressive tiers + 223 opt-in stylistic rules).

## Finish Report (2026-08-19)

**Verification:** Counted directly from `lib/src/tiers.dart` via a temporary script (`getRulesForTier('pedantic')` union'd with `stylisticRules`), run inside the package so `package:saropa_lints` resolved correctly. Result: essential 331, full tiered set (pedantic) 2109, stylistic 223, all-defined 2332 — matching a manually reported tier-distribution breakdown exactly.

**Files corrected:**
- `CHANGELOG.md` — top marketing line ("2100+" → "2300+").
- `pubspec.yaml` — pub.dev-facing package description ("2134" → "2332").
- `README.md` — badge, architecture-overview line, and closing pitch (all "2134" → "2332").
- `doc/guides/using_with_riverpod.md`, `migration_from_vga.md`, `migration_from_dcm.md` — comparison-table rule counts ("2100+" → "2300+").
- `plans/guides/PERFORMANCE.md` — two references to "instantiating all 2100+ rules" ("2100+" → "2300+").
- `lib/saropa_lints.dart` — two doc comments referencing "all 2100+ rules"; also corrected a stale "253" essential-tier figure to the current 331.
- `extension/media/walkthrough-about-saropa.md` — developer-ecosystem table entry ("2134" → "2332").
- `extension/package.nls.json` (English source) — `extension.description` and `viewsWelcome.banner.contents` ("2100+" → "2300+").
- `extension/src/i18n/locales/en.json` (English source) — `setupPrompt` string ("2100+" → "2300+").
- `extension/src/vibrancy/data/known_issues.json` — DCM migration note's comparison figures ("2057 custom lint rules and 132 quick fixes" → "2332 custom lint rules and 254 quick fixes").

**Left unchanged (deliberately):** `doc/guides/migration_from_solid_lints.md:77` ("Pedantic (2100+ rules)") — this refers specifically to the Pedantic tier total (2109), which still rounds to "2100+" and remains accurate; it was not conflating the tiered count with the full 2332 figure that includes opt-in stylistic rules.

**Translation catalogs — deliberately not regenerated.** The English-source edits above (`package.nls.json`, `en.json`) leave the 27 translated locale catalogs stale for these 3 keys. Per the user's global hard-stop on machine-translation pipelines, the regeneration command (`py -3 extension\scripts\generate_translations.py`) was handed over rather than run; the user explicitly chose "Commit English only" and deferred the regen to a separate, explicit run.

**Unrelated pre-existing/concurrent dirty state noted, not touched or committed:** `extension/package.json` (version bump), `extension/package.nls.ar.json`, `extension/package.nls.bn.json`, `extension/src/i18n/locale_coverage.json`, and 13 locale files (`ar`, `bn`, `de`, `es`, `fa`, `fil`, `fr`, `he`, `hi`, `id`, `it`, `ja`, `ko`) showing a fresh coverage-audit timestamp. No hook in `.claude/settings.json` auto-triggers the translation script on file save, so this activity's origin is unexplained; it was left untouched pending the user's own follow-up.
