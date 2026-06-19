# FEATURE: `ui_excellence` lint group — bundle the UX-polish rules under one toggle

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

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

## Proposed members (existing rules — verify exact ids in `lib/src/rules/`)

Candidate seed set, all already defined:

1. `require_keyboard_dismiss_on_scroll` — scroll views specify `keyboardDismissBehavior`.
2. `require_keyboard_action_type` — text fields specify `textInputAction` (Next/Done).
3. `require_notification_for_long_tasks` — async work surfaces visible feedback.
4. Common-widget / design-system rules (icon light-vs-solid semantics, prefer
   `Common*` over raw Flutter widgets, prefer adaptive icon sizing) — whichever
   already exist under the `widget` category.

The final roster is a curation decision; start with the keyboard/feedback rules
above and add design-system rules as they stabilize.

---

## Curated UX-detail backlog (triaged for lint-detectability)

A community list of "small details that build taste in Flutter" (curated by Kamran
Bekirov). Each entry below is mapped to a candidate rule id and triaged by whether
a **static lint** can actually catch it — the deciding question for this package.
Many are real polish wins but are behavioral or HTML-side and cannot be enforced
by AST analysis; those are recorded so we don't keep re-proposing them as rules.

### Tier A — strong static candidates (a lint can reliably detect these)

| Idea | Candidate rule id | Detection sketch |
|------|-------------------|------------------|
| Never let users see "null" | `avoid_null_in_user_text` | Nullable value interpolated/passed into `Text`/`SelectableText`/`Tooltip.message` without `?? ''`/null guard. |
| Don't use `SafeArea` with scrollable widgets | `avoid_safearea_around_scrollable` | `SafeArea` whose child is a `ListView`/`GridView`/`CustomScrollView`/`SingleChildScrollView`; recommend bottom padding on the scrollable instead. |
| Dismiss the keyboard when users scroll a form | `require_keyboard_dismiss_on_scroll` *(exists)* | Scrollable in a form context missing `keyboardDismissBehavior`. |
| Autofocus pages that have one field | `require_autofocus_single_field` | A route/screen with exactly one `TextField`/`TextFormField` and no `autofocus: true`. |
| Reserve space for images so layout doesn't jump | `require_image_dimensions` | `Image.*`/`FadeInImage` without `width`/`height` and not wrapped in `AspectRatio`/`SizedBox`. |
| Use tabular figures for numbers that change | `prefer_tabular_figures` | Counters/timers/currency `Text` whose style omits `FontFeature.tabularFigures()`. (Heuristic on identifier/format context.) |
| Format numbers for humans | `prefer_number_formatting` | Raw `int`/`double`/`.toString()` of a numeric passed to `Text` without `NumberFormat`/`intl`. |

### Tier B — detectable but heuristic / higher false-positive risk

| Idea | Candidate rule id | Detection sketch |
|------|-------------------|------------------|
| Don't clip horizontal lists with page padding | `avoid_clipped_horizontal_list` | Horizontal `ListView` inside a `Padding`/padded parent; padding belongs on the list's `padding`, not the ancestor. |
| Make lists feel scrollable | `prefer_always_scrollable_physics` | Short `ListView`/`GridView` likely to be non-scrollable; suggest `AlwaysScrollableScrollPhysics` where pull-to-refresh/overscroll matters. |
| When Android back button doesn't close your modals | `require_popscope_for_modal` | Custom modal/overlay state without `PopScope`/`onPopInvoked` handling. |
| Load images smoothly | `prefer_image_fade_in` | Network `Image` without `frameBuilder`/`FadeInImage`/placeholder. |
| Save files without permission handling | (route to existing security/permission rules) | File-write APIs gated behind unnecessary runtime-permission calls on platforms that don't need them. |

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
