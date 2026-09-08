# PLAN — Rename package-specific rule IDs to package-first (`isar_avoid_cached_stream` vs `avoid_cached_isar_stream`)

Status: PLAN ONLY — not started. No code, tests, or docs have been touched by this plan.

## Goal

For every rule whose `LintCode` id currently buries the package/library name mid-string after a
verb prefix (`avoid_cached_isar_stream`), move the package name to the front
(`isar_avoid_cached_stream`), matching the convention already used by newer package rule sets
(`app_links_avoid_get_initial_link_string`, `flutter_map_...`, `local_auth_...`, etc.).

## Scope — confirmed by research (2026-09-08)

- 2,385 rule ids total; 1,036 are package-specific (`lib/src/rules/packages/*.dart`, 58 files).
- The codebase is **already inconsistent**: some packs (app_links, audioplayers, awesome_notifications,
  flutter_animate, flutter_map, home_widget, file_picker, geocoding, local_auth, lottie,
  permission_handler, quick_actions, in_app_review, device_calendar_plus, …) are already 100%
  package-first and need **zero** work. The large, old packs are 0% package-first and carry the
  bulk of the work: bloc (110 rules), riverpod (82), firebase (72), drift (66), provider (56),
  hive (52), getx (48), isar (44), equatable (30), dio (30), shared_preferences (24), plus the
  remaining smaller packages.
- Generic/core rules (~1,349, e.g. `avoid_print`, `prefer_const_constructors`) are **out of scope** —
  there is no package name to move.

## Why this is a big change, not a mechanical find/replace

The rule id string is duplicated in multiple places per rule, and several of those places are
either generated (must be regenerated, never hand-edited) or hand-maintained lists that a rename
script would still need to touch:

1. **Source of truth** — `lib/src/rules/packages/<pack>.dart`: the `LintCode('rule_id', ...)`
   constructor call AND the `[rule_id]` prefix required at the start of every `problemMessage`
   (enforced by an integrity test). Class name conventionally renamed too, though not mechanically
   required.
2. **`lib/src/tiers.dart`** — ~3,348 quoted rule-id references across the 6 tier `Set<String>`s.
3. **`lib/tiers/*.yaml`** (essential/recommended/professional/comprehensive/pedantic) — published,
   pub.dev-shipped presets that consumers `include:` directly. **User-facing.**
4. **`lib/src/scan/rule_category_map.dart`** — GENERATED via `scripts/gen_category_map.py`; needs
   regeneration, not hand-editing.
5. **`lib/src/config/rule_pack_codes_generated.dart`** — GENERATED via
   `tool/generate_rule_pack_registry.dart`; needs regeneration.
6. **`extension/media/rules_catalog.json`** — GENERATED dashboard data (39k+ lines); needs
   regeneration.
7. **`extension/src/rulePacks/rulePackDefinitions.ts`** and **`ruleTierDefinitions.ts`** —
   **hand-maintained** TS arrays of rule ids per pack/tier. Every renamed id must be manually
   updated here — the extension's Config Dashboard (the screen the bug reports above are about)
   reads directly from these files.
8. **Test fixtures** — 3,160 `// expect_lint: rule_id` occurrences across 1,848 files in
   `test/rules/packages/*_test.dart` and `example_packages/lib/**/*.dart`. Many fixture *filenames*
   also encode the rule id (`avoid_cached_isar_stream_fixture.dart`) and would need renaming too.
9. **Docs** — `CONTRIBUTING.md`'s "Rule Naming Conventions" section documents the current
   verb-first scheme and needs rewriting/superseding; `doc/guides/packages/using_with_isar.md`
   and similar package guides reference specific rule ids in prose.
10. **`ROADMAP.md` / `CHANGELOG.md`** — historical entries reference old rule ids; not worth
    editing retroactively, but any still-`Unreleased` changelog entries that reference a renamed
    rule id need updating.

## Back-compat — confirmed mechanism, confirmed gap

- `SaropaLintRule.configAliases` (`lib/src/saropa_lint_rule.dart`) lets a renamed rule keep
  answering to its old id in `analysis_options*.yaml` (`diagnostics:` enable/disable and
  `severityOverrides`). This is proven, documented, and already used for ~20 other renames
  (e.g. `avoid_getter_prefix` → `prefer_no_getter_prefix`, with a `Formerly: avoid_getter_prefix`
  note in the class doc comment, the `[rule_name]` message body, and a `CHANGELOG_ARCHIVE.md`
  entry). This is the pattern to reuse for every renamed rule.
- **Confirmed gap to verify before implementation**: `configAliases` only resolves YAML config
  keys. Whether `// ignore: rule_id` comments in user source code, and `banned_usage`-style rule-id
  references, also resolve through the alias table needs to be confirmed in the engine before
  claiming full back-compat — if not, a renamed rule silently stops being suppressible by an
  existing `// ignore:` comment in a user's codebase until they update it.

## Recommended approach (for whoever implements this later)

1. **Tooling first**: write a rename script (Python, per this repo's "durable scripts = Python"
   convention) that, given an old→new id mapping, mechanically updates items 1–3, 7, and 8 above,
   then triggers regeneration of items 4–6, rather than hand-editing 2,385 call sites.
2. **Batch by pack, not all at once**: rename one package (e.g. isar, 44 rules) end to end —
   source, tiers, YAML presets, extension TS lists, fixtures, regenerate generated files, run the
   full test suite, confirm `configAliases` round-trips both enable/disable AND `// ignore:`
   comments — before moving to the next pack. 10+ packs × ~2,300 touched call sites total means a
   single all-at-once PR would be unreviewable and unrevert-able if something breaks a generated
   file's consistency check.
3. **Use `scripts/check_rule_name.py`** for every new id before writing it anywhere, per existing
   convention — it has already caught collisions with core Dart/Flutter lint names 3 times in 3
   days on unrelated new-rule work.
4. **Every renamed rule gets `configAliases => const <String>['<old_id>']`**, a `Formerly:
   <old_id>` note in the class doc comment and `[new_id]` message, and a `CHANGELOG_ARCHIVE.md`
   entry — matching the `avoid_getter_prefix` precedent exactly.
5. **Rewrite `CONTRIBUTING.md`'s "Rule Naming Conventions"** section once the scheme is finalized,
   so new rules are authored package-first from the start rather than needing this sweep again for
   rules added after this migration starts.
6. **Decide up front** whether generic/core rules' `avoid_`/`prefer_`/`require_`/`no_` convention
   stays as-is (recommended — there is no package name to move for the majority of the ruleset,
   and mixing two schemes with a clear boundary — "does this rule mention `matchPubNames`?" — is
   simpler to reason about than a wholesale scheme change).

## Open questions for the user before implementation starts

- Confirm scope: package rules only (1,036), or should some already-package-first packs get a
  pass/audit too for naming consistency (verb placement after the package prefix, e.g.
  `isar_avoid_cached_stream` vs `isar_cached_stream_avoid` — not addressed by this research)?
- Confirm the `// ignore:` / `banned_usage` alias-resolution gap (see Back-compat section) before
  committing to "renames are safe for existing users" as a premise.
- Confirm whether this should ship as one coordinated release (all packs renamed together, one
  version bump, one CHANGELOG entry) or trickle out pack-by-pack across several releases.
