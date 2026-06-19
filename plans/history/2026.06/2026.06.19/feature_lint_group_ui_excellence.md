# FEATURE: `ui_excellence` lint group — bundle the UX-polish rules under one toggle

**Status: Fixed** — shipped as four thematic rule packs

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

## Implemented (2026-06-19) — as rule packs, not an overlay set

Shipped as real rule packs (the dashboard-discoverable, opt-in mechanism), not
the overlay set first prototyped. An earlier draft used a tier-overlay set to
avoid the pack merge stripping members from tiers; that was reverted once it was
confirmed that package and SDK packs work exactly this way by design — pack
ownership making a rule opt-in is the intended behavior for an *optional* bar,
which the doc title calls for.

Four thematic ("quality standard") packs were added:

- `ui_excellence` (32 rules) — UX polish.
- `localization` (27) — externalize strings, locale-aware `intl` formatting, plurals/RTL.
- `documentation` (14) — public-API dartdoc completeness.
- `testing` (68) — deterministic, isolated, well-structured tests (excludes the
  logging rules that also live under `lib/src/rules/testing/` and the stylistic
  `format_test_name`).

Mechanism (mirrors `collection_compat`, the existing hand-added pack):

- Rosters live in `lib/src/tiers.dart` (THEMATIC RULE-PACK ROSTERS section) so
  they stay tier-validated; registered in `lib/src/config/rule_packs.dart`
  (`kRulePackRuleCodes` + `kRulePackPubspecMarkers`).
- `dart run tool/generate_rule_pack_registry.dart` emits them into the extension
  registry (`rulePackDefinitions.ts`); `packDomains.ts` files them under a new
  **Quality standards** domain that sorts first in the dashboard.
- Markers drive the "applicable" suggestion hint only (no dependency gate, so
  any project can enable them): `flutter` for `ui_excellence`/`documentation`,
  `intl`/`flutter_localizations` for `localization`, `test`/`flutter_test` for
  `testing`.

Tests: `test/integrity/saropa_lints_test.dart` (Thematic Rule Pack Validation —
members exist in plugin, are tier-catalogued, are NOT in the stylistic track,
`ui_excellence` size pinned); `test/config/rule_pack_registry_test.dart` (packs
registered with rosters); `extension/src/test/rulePacks/rulePackDefinitions.test.ts`
(registry + suggestion detection). Dart config + integrity suites and the
extension rulePacks tests pass; `dart run tool/rule_pack_audit.dart` exits clean.

Behavior change (see CHANGELOG **Changed**): these rules are now pack-owned, so
they are opt-in — enable the pack to turn them on. Previously tier selection
enabled them implicitly.

Created: 2026-06-19
Kind: Feature — new lint group / tier
Severity: Low (organizational; no behavior change to existing rules)

---

## Summary

Several existing rules each enforce one slice of user-facing UX quality, but they
are scattered across categories and toggled one-by-one in every downstream
`analysis_options.yaml`. Introduce a named **`ui_excellence`** group so a project
can opt into the whole "polished UI" bar with one switch, and so the bar is
discoverable as a cohesive standard rather than a dozen unrelated rule names.

This is a grouping/metadata change — the member rules already exist and keep
their current ids, messages, and fix logic.

---

## Motivation

The Saropa Contacts design system already mandates this bar (keyboard handling,
Common-widget usage, icon light/solid semantics, dismiss-on-scroll). Today each
rule is enabled individually and a new screen can silently miss one. A group
makes "enable the UX bar" a single, auditable decision and gives the rules a home
to grow into.

---

## Proposed members — confirmed-existing rules in this project

A sweep of `lib/src/rules/` (2026-06-19) found the project already ships a deep
roster of UX-polish rules across several files. These are the immediate group
membership candidates (ids verified against their `LintCode` declarations):

**Keyboard & forms** (`widget/forms_rules.dart`, `widget/dialog_snackbar_rules.dart`)
- `require_keyboard_dismiss_on_scroll` — scroll views with text fields set `keyboardDismissBehavior`.
- `require_keyboard_action_type` — text fields set `textInputAction` (Next/Done).
- `require_keyboard_type` — email/phone fields set `keyboardType`.
- `avoid_keyboard_overlap` — guard against fields hidden behind the soft keyboard.
- `avoid_multiple_autofocus` — only one `autofocus: true` per screen.
- `prefer_autovalidate_on_interaction` — don't validate on every keystroke.
- `avoid_clearing_form_on_error` — don't wipe user input on validation failure.
- `avoid_form_without_unfocus` — unfocus before processing a submit.

**Visible feedback for async / long tasks** (`widget/ui_ux_rules.dart`, `widget/dialog_snackbar_rules.dart`)
- `require_button_loading_state`, `require_submit_button_state` — async buttons show a loading state.
- `prefer_skeleton_over_spinner` — skeletons over bare spinners for content loads.
- `require_search_loading_indicator`, `require_pagination_loading_state`,
  `require_pagination_error_recovery` — search/pagination surface progress + retry.
- `require_webview_progress_indicator` — WebView shows page-load progress.
- `require_error_widget` — `Future`/`StreamBuilder` handle the error state.
- `require_empty_results_state` — search/list views render an empty state.
- `require_snackbar_duration`, `require_snackbar_action_for_undo`,
  `avoid_snackbar_queue_buildup` — well-behaved snackbars.

**Image stability** (`widget/widget_patterns_require_rules.dart`, `media/image_rules.dart`)
- `require_image_dimensions` — network images reserve space (no layout shift).
- `require_placeholder_for_network`, `require_image_error_builder` — placeholder + error fallback.
- `require_avatar_fallback` — `CircleAvatar` network image has a fallback.

**Lists & scrolling** (`widget/scroll_rules.dart`)
- `require_refresh_indicator_on_lists` — lists support pull-to-refresh.

**Dialogs / modals / adaptivity** (`widget/dialog_snackbar_rules.dart`)
- `require_dialog_barrier_dismissible`, `require_dialog_result_handling`,
  `prefer_adaptive_dialog` — predictable, platform-native dialogs.

**Number / currency formatting** (`widget/ui_ux_rules.dart`)
- `require_number_formatting_locale`, `require_currency_formatting_locale` — locale-aware formatting.

**Interaction affordance** (`widget/widget_patterns_require_rules.dart`)
- `require_hover_states` — web/desktop interactive widgets give hover feedback.
- `require_safe_area_handling` — Scaffold body respects notches/cutouts.

> Roster boundary: several of the feedback/loading rules overlap with the
> `accessibility` and `performance` concerns. The group should *reference* them,
> not claim exclusive ownership — a rule can belong to more than one semantic group
> if the mechanism allows it (see Open Question 1).

---

## Curated UX-detail backlog (triaged for lint-detectability)

A community list of "small details that build taste in Flutter" (curated by Kamran
Bekirov). Each entry below is mapped to a candidate rule id and triaged by whether
a **static lint** can actually catch it — the deciding question for this package.
Many are real polish wins but are behavioral or HTML-side and cannot be enforced
by AST analysis; those are recorded so we don't keep re-proposing them as rules.

Legend: **EXISTS** = the project already ships a rule covering this idea (add to the
group, no new code). **NET-NEW** = no current rule; would need authoring.

### Tier A — strong static candidates (a lint can reliably detect these)

| Idea | Rule id | Status | Notes |
|------|---------|--------|-------|
| Dismiss the keyboard when users scroll a form | `require_keyboard_dismiss_on_scroll` | EXISTS | `widget/forms_rules.dart`. |
| Reserve space for images so layout doesn't jump | `require_image_dimensions` | EXISTS | + `require_placeholder_for_network`, `require_image_error_builder`. |
| Format numbers for humans | `require_number_formatting_locale` | EXISTS (partial) | Covers locale; does **not** force `NumberFormat` on raw `.toString()`. Net-new `prefer_number_formatting` would close that gap. |
| Never let users see "null" | `avoid_null_in_user_text` | NET-NEW | Nullable value into `Text`/`SelectableText`/`Tooltip.message` without `?? ''`/guard. No existing rule. |
| Use tabular figures for numbers that change | `prefer_tabular_figures` | NET-NEW | Counter/timer/currency `Text` style omits `FontFeature.tabularFigures()`. |
| Autofocus pages that have one field | `require_autofocus_single_field` | NET-NEW | Inverse of the existing `avoid_multiple_autofocus`; one field + no `autofocus: true`. |

### Tier B — detectable but heuristic / higher false-positive risk

| Idea | Rule id | Status | Notes |
|------|---------|--------|-------|
| Make lists feel scrollable | `require_refresh_indicator_on_lists` | EXISTS | Pull-to-refresh angle already covered; `prefer_always_scrollable_physics` (NET-NEW) would add overscroll-physics. |
| When Android back button doesn't close your modals | `require_popscope_for_modal` | NET-NEW | Existing dialog rules cover `showDialog` ergonomics, not `PopScope` on custom overlays. |
| Load images smoothly (fade-in) | `prefer_image_fade_in` | NET-NEW | Existing image rules require placeholder/error, not `frameBuilder`/`FadeInImage`. |
| Don't clip horizontal lists with page padding | `avoid_clipped_horizontal_list` | NET-NEW | Horizontal `ListView` inside a padded parent; padding belongs on the list. |
| Don't use `SafeArea` with scrollable widgets | `avoid_safearea_around_scrollable` | NET-NEW | Reconcilable with existing `require_safe_area_handling`, not opposed: that rule accepts `MediaQuery.paddingOf` as well as `SafeArea`, and already exempts `CustomScrollView`/`NestedScrollView`. Only overlap shape is `Scaffold(body: SafeArea(child: ListView()))`; the single fix — move the inset to the scrollable's `padding` — satisfies both. The net-new rule must recommend that padding fix (not a bare "remove SafeArea") so it never contradicts the require rule. |
| Save files without permission handling | (route to `security/permission_rules.dart`) | EXISTS (adjacent) | Permission rules already live there; confirm coverage before authoring net-new. |

### Tier C — not statically lintable (design guidance, behavioral, or HTML/asset-side)

These belong in a design-system doc, not as lint rules. Recorded to close the loop.

- Update browser tab title on each page — route-to-title flow, not a single-node shape.
- Show progress while Flutter web loads — `web/index.html`, not Dart AST.
- Add link preview (Open Graph) — `web/index.html` meta tags.
- Upgrade your iOS 13 sheets to iOS 26 — platform/API-version preference, project-wide.
- Reschedule notifications when timezone or clock changes — runtime behavior.
- Precache icons so they don't pop in — depends on app lifecycle/timing.
- Make button presses feel right / Missing haptic types — semantic, not detectable.
- Disable Material tap effects — context-dependent design choice, not a defect.
- Show users your swipe actions exist — visual affordance, no AST signal.
- Make text selection match your design — theme preference.
- Scroll to top when tab is tapped again — navigation behavior.
- Fix the GoogleFonts glitch — config/runtime-fetch setting; a single `prefer_bundled_google_fonts` is possible but low value.
- Make animations feel alive with springs — aesthetic preference.
- Show changelog after update — app lifecycle behavior.

> Triage note: Tier A is the recommended first roster for `ui_excellence` once the
> existing keyboard/feedback rules land. Tier B needs fixture-driven false-positive
> tuning before inclusion. Tier C is explicitly **out of scope for lint rules** —
> link to the Saropa design system instead of authoring no-signal rules.

---

## Suggested design

- Add a `ui_excellence` group constant wherever rule groups/tiers are defined
  (`lib/src/rules/tiers.dart` or the group registry), mapping to the member rule
  ids. No new diagnostics, no fix changes.
- Member rules stay independently toggleable; the group is additive — enabling
  the group enables its members, individual `false` overrides still win.
- Default severity for the group: `info` (advisory polish), since some members
  legitimately fire on non-form scrollers / decorative surfaces.
- Document the group in `README` / `ROADMAP` so downstream projects can enable it
  by name.

---

## Open questions

1. Is there an existing group/tier mechanism to extend, or is this the first
   semantic (non-severity) group? Extend the existing inventory rather than add a
   parallel one.
2. Roster boundary: does "UI excellence" include accessibility rules
   (semantics labels, contrast, tap-target size) or stay scoped to
   form/feedback/widget-consistency? Recommend a separate `accessibility` group
   if those rules exist, cross-referenced from this one.

---

## Notes

- Downstream trigger: enabling `require_keyboard_dismiss_on_scroll` in Saropa
  Contacts (`analysis_options.yaml`, 2026-06-19) surfaced that the UX-polish
  rules are toggled piecemeal — hence this grouping request.
- No reproducer/AST section: this is a metadata/grouping feature, not a
  detection bug.

---

## Finish Report (2026-06-19)

### Summary

A request to bundle optional UX-polish rules under one toggle was delivered as
four thematic ("quality standard") rule packs — `ui_excellence`, `localization`,
`documentation`, `testing` — the first packs in the project that name a quality
standard rather than a package family or SDK version. They are discoverable in
the VS Code "Manage Rule Packs" dashboard under a new "Quality standards" domain
and enableable via `rule_packs.enabled` in `analysis_options.yaml`.

### Design decision

An initial prototype modeled the group as a tier-overlay set (a const set plus a
`semanticGroupRuleSets` registry) to avoid the rule-pack merge stripping members
from tier-derived enables. That was reverted. Inspection of `rule_packs.dart`
(`mergeRulePacksIntoEnabled` runs in authoritative mode) and verification that
package-family and SDK packs are themselves tier members confirmed the strip is
intentional: pack ownership makes a rule opt-in, which is the correct behavior
for an *optional* bar. The packs reuse the existing marker mechanism, so no
change to pack-applicability or merge logic was required.

### Changes

- `lib/src/tiers.dart` — THEMATIC RULE-PACK ROSTERS section: four curated const
  sets (`uiExcellenceRules` 32, `localizationRules` 27, `documentationRules` 14,
  `testingRules` 68). Testing roster excludes the logging rules that also live
  under `lib/src/rules/testing/` (`debug_rules.dart`) and stylistic-track rules
  (`format_test_name`, `prefer_fake_over_mock`, `prefer_test_data_builder`) —
  pack-owning a stylistic rule would strip it when the stylistic track is on.
- `lib/src/config/rule_packs.dart` — registered the four packs in
  `kRulePackRuleCodes` and `kRulePackPubspecMarkers` (markers `flutter`, `intl`/
  `flutter_localizations`, `test`/`flutter_test`; no dependency gate).
- `tool/generate_rule_pack_registry.dart` — readable labels for the four packs.
- `extension/src/rulePacks/rulePackDefinitions.ts` — regenerated (registry-only
  packs emitted with rosters/markers).
- `extension/src/rulePacks/packDomains.ts` — new `QUALITY_DOMAIN` ("Quality
  standards"), sorted first; the four pack ids mapped to it.
- Generated `lib/src/config/rule_pack_codes_generated.dart` — no content change
  (thematic packs are registry-only); reformatted to canonical style.

### Tests

- `test/integrity/saropa_lints_test.dart` — replaced the prototype's "Semantic
  Group Validation" with "Thematic Rule Pack Validation": members exist in the
  plugin, are tier-catalogued, are NOT in the stylistic track, `ui_excellence`
  size pinned.
- `test/config/rule_pack_registry_test.dart` — the four packs are registered
  with non-empty rosters and representative members.
- `extension/src/test/rulePacks/rulePackDefinitions.test.ts` — packs registered;
  `ui_excellence` suggested from a `flutter` dependency, `localization` from `intl`.

### Verification

- `dart test test/integrity/ test/config/` — 115 passing.
- `dart analyze --fatal-infos` on changed Dart files — no issues found.
- Extension `tsc -p tsconfig.test.json` clean; `rulePackDefinitions.test.js` —
  9 passing (incl. 3 new).
- `dart run tool/rule_pack_audit.dart` — exit 0 (four packs reported "registry
  only", same as SDK packs).

### Behavior change

The ~141 rules now in these packs are pack-owned and therefore opt-in: they fire
only when the pack is enabled, where tier selection previously enabled them
implicitly. Documented under CHANGELOG "Changed".

### Deferred

An `accessibility` pack was considered and not built: making accessibility rules
opt-in (off by default) conflicts with the project's EAA-compliance posture, so
those rules stay tier-default. A future `logging` pack could collect the
`debug_rules.dart` rules excluded from `testing`.
