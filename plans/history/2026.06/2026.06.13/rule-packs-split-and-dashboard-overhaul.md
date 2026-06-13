# Rule-pack split and Manage Rule Packs dashboard overhaul

A single rule pack named `package_specific` ("Mixed packages") bundled 19 unrelated rules — drawn from roughly fifteen different packages (app_links, image_picker, OpenAI, uuid, Envied, Google Fonts, and others) — into one ungated, opt-in bucket. A project that used none of those packages still saw a meaningless 19-rule pack, and a project that used exactly one of them had no way to enable just that one rule. The rule-packs configuration webview compounded the problem: it defaulted to a confusing "most rules first" sort, buried a "Recommended" signal mid-table under the opaque label "In pubspec", opened each pack's rule list in a modal quick-pick, rendered its type-filter dropdown with unreadable contrast in dark themes, and was shadowed by a noisy sidebar panel that listed every applicable pack as a separate "Enable the X rule pack" row.

This change splits the catch-all pack into per-package gated packs, reworks the webview, removes the redundant sidebar panel, and renames the surface to **Manage Rule Packs**.

## Finish Report (2026-06-13)

### Scope

(A) Dart lint rules / analyzer plugin and (B) the VS Code extension. No rule detection logic changed — the 19 rules were relocated verbatim across files; only their pack membership changed.

### What changed — rule packs (Dart)

Pack membership is derived from each rule file's stem (`packIdForStem` in `tool/rule_pack_audit.dart`), so a rule's pack is decided by which `*_rules.dart` file it lives in. The 19 rules in `package_specific_rules.dart` therefore all landed in one pack. The fix relocates each rule class to a per-package file:

- Twelve rules moved into existing package files: `google_sign_in_rules.dart`, `sign_in_with_apple_rules.dart`, `webview_flutter_rules.dart` (two), `device_calendar_rules.dart`, `flutter_svg_rules.dart`, `image_picker_rules.dart` (two), `url_launcher_rules.dart`, `geolocator_rules.dart`, `app_links_rules.dart`, and `firebase_rules.dart` (the analytics rule, gated by the existing `firebase_analytics` marker).
- Six new package files create six new gated packs: `openai_rules.dart` (two rules), `uuid_rules.dart`, `envied_rules.dart`, `google_fonts_rules.dart`, `flutter_keyboard_visibility_rules.dart`, and `speech_to_text_rules.dart`.
- `package_specific_rules.dart` was deleted; its barrel export was removed from `lib/src/rules/all_rules.dart` and the six new files were added.
- The OpenAI pack gates on `chat_gpt_sdk`, confirmed from the two OpenAI rules' own detection code (the error-handling rule targets the `chat_gpt_sdk` package's `OpenAI` class; the key-in-code rule matches the `sk-` secret pattern and ships in the same pack).
- `tool/generate_rule_pack_registry.dart` gained pubspec markers and UI labels for the six new packs and dropped the `package_specific` entries; the dead `package_specific_rules` special case was removed from `packIdForStem`.
- The registry was regenerated (`lib/src/config/rule_pack_codes_generated.dart` and `extension/src/rulePacks/rulePackDefinitions.ts`) and `tool/rule_pack_audit.dart` exits 0 with no warnings. The generator must be run twice after a pack-set change because its in-process `kRulePackRuleCodes` constant reflects the compiled-in (pre-edit) generated file on the first pass.

Rule registration is by class name (the `_allRuleFactories` list) and by rule-name string (`tiers.dart`), both unchanged, so moving classes between barrel-exported files required no factory or tier edits.

Migration impact: the `package_specific` pack id no longer exists. A project that listed it under `rule_packs.enabled` now has it silently ignored, turning those rules off until the specific packs are enabled. This is documented as a required action in the changelog.

### What changed — webview (extension)

`extension/src/rulePacks/rulePacksWebviewProvider.ts`, `configDashboardScript.ts`, and `configDashboardStyles.ts`:

- Default sort is now A–Z by pack name (provider initial sort and client `state.sortKey`/`sortDir`).
- The "In pubspec" column was renamed "Recommended" and moved to the first column; every header carries an explanatory `title` tooltip.
- The per-row "View" quick-pick was replaced by an inline disclosure: a toggle reveals a sibling detail row listing each rule code as a link that posts `explainRule` (validated as a snake_case id before reaching `saropaLints.explainRule`). The client script keeps each detail row adjacent to its pack row across sort and hides it in lockstep across filter.
- The type-filter `<select>` and its options were bound to `--vscode-dropdown-*` theme tokens so the options are readable in dark and high-contrast themes.
- A new "Enable all recommended packs" primary button enables every applicable pack in one click. It reuses `computeConfigSuggestions(root)` (the same applicability source the startup toast uses) so the button and the proactive detection never diverge.

### What changed — sidebar removal and rename (extension)

- The standalone `saropaLints.suggestions` view, its activity-bar badge, its config-file watcher, and the `ConfigSuggestionsTreeProvider` (`configSuggestionsTree.ts`, deleted) were removed. Proactive pack discovery now flows solely through the existing single startup notification, whose action opens the Manage Rule Packs webview. The vestigial violation-driven `SuggestionsTreeProvider` (never bound to a visible view) was unwired from `extension.ts` and `extensionCopyAsJsonCommands.ts`; the `saropaLints.suggestions.copyAsJson` command, its menu entries, its catalog entry, and its now-unused NLS keys were removed.
- The dashboard panel title, the `command.openConfigDashboard.title` NLS string, the getting-started walkthrough copy, and the Findings dashboard menu label (`en.json` `openLintsConfig` value) were renamed from "Open Lints Config" / "Lints Config" to "Manage Rule Packs". Command IDs were left unchanged to preserve keybindings and programmatic callers.

### Verification

- `dart run tool/rule_pack_audit.dart` — exit 0, no WARN, 70 packs.
- `dart test test/config/rule_pack_registry_test.dart test/config/rule_packs_config_test.dart test/config/rule_packs_pubspec_markers_test.dart test/config/rule_packs_migration_membership_test.dart test/config/rule_packs_sdk_gates_test.dart test/config/analysis_options_rule_packs_test.dart` — all pass.
- `dart test test/rules/packages/package_specific_rules_test.dart` — 38 pass (19 rule-instantiation assertions for the relocated rules + 19 fixture-existence checks). Its import was repointed from the deleted file to the sixteen files now holding those rules, keeping it runnable independent of unrelated rule files.
- `dart analyze` of the sixteen changed/new package rule files — no issues.
- Extension `tsc -p tsconfig.json --noEmit` and `tsc -p tsconfig.test.json` — clean.
- Extension mocha (views, rulePacks, configSuggestions, suggestionCounts suites) — pass.

### Test maintenance

- `test/rules/packages/package_specific_rules_test.dart` — import repointed to the sixteen relocation targets.
- `test/config/rule_packs_pubspec_markers_test.dart` — the now-dead `package_specific` exemption was removed; the invariant is now "every pack declares at least one pubspec marker".
- `extension/src/test/views/overviewTreeFlat.test.ts` and `uxLabels.test.ts` — expected sidebar view sets updated to drop the removed `saropaLints.suggestions` view.

### Localization

The rule-packs dashboard (`rulePacksWebviewProvider.ts`, `configDashboardScript.ts`) is a fully hardcoded-English surface with zero `l10n()` calls predating this change; its new strings follow that existing pattern. Localizing the new strings in isolation would be inconsistent with the surrounding hardcoded surface and would yield no translation benefit while the rest stays English — the whole-dashboard localization gap is pre-existing and out of scope here. The two catalog touches are a renamed `package.nls.json` command title and an edited `en.json` `openLintsConfig` value; neither adds, removes, or renames a key, so the translated locale catalogs still resolve every key and the publish coverage gate (`--fail-on-missing`) is unaffected. The machine-translation pipeline was deliberately not run (a value edit does not require it, and that pipeline requires explicit per-run authorization).

### Out of scope / not addressed here

Two unrelated working-tree items from other workstreams remain and are not touched by this change:

- `lib/src/rules/widget/widget_layout_constraints_rules.dart` references an undefined `_ConstraintFinitenessVisitor` (absent at HEAD), which blocks a full-package Dart compile. The rule-pack split was verified without depending on it.
- `saropaLints.enableRule` and `saropaLints.openFinding` were added to `package.json` without command-catalog entries, causing one pre-existing failure in `commandCatalogRegistry.test.ts`. The copyAsJson removal in this change keeps both sides of that catalog in sync and does not contribute to that failure.
