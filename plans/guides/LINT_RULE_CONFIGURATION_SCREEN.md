# Spec: Lint Rule Configuration Screen

Status: Draft
Last updated: 2026-06-22
Owner: extension UI
Scope: VS Code extension webview that lets a user configure which `saropa_lints`
rules run in their workspace.

This spec describes the existing **Config Dashboard** (editor-tab title
"Saropa Lints: Manage Rule Packs") as the source of truth for behavior, plus the
constraints any change to it must hold. Implementation lives in
[rulePacksWebviewProvider.ts](../../extension/src/rulePacks/rulePacksWebviewProvider.ts),
[configWriter.ts](../../extension/src/configWriter.ts), and
[rulePackYaml.ts](../../extension/src/rulePacks/rulePackYaml.ts).

---

## 1. Purpose

Give the user one screen to control the **effective rule set** for their project
without hand-editing YAML. The screen reads and writes the same files the Dart
analyzer consumes, so what the user sees equals what the analyzer runs.

The effective rule set is the union of three independent configuration zones,
applied in order:

1. **Tier** — a broad baseline (Essential → Pedantic). Sets the default
   on/off state for tier-owned rules.
2. **Rule packs** — package- and SDK-migration domains. A pack's rules are OFF
   unless that pack is explicitly enabled, regardless of tier.
3. **Per-rule overrides** — individual rules forced on or off, layered on top of
   the tier + pack baseline. This zone also carries the **stylistic** opt-ins
   (rules that belong to no tier and are only ever active via an explicit
   `rule: true`).

Precedence (last wins): tier baseline → pack contributions → per-rule override.
A `true` override in the custom file re-enables a rule the tier or a pack would
otherwise leave off; a `false` override removes a rule from the effective set.

---

## 2. Terminology (plain meaning first)

- **Tier** — one of five named baselines that decide how many rules are on by
  default. The five, increasing in strictness:
  `essential`, `recommended`, `professional`, `comprehensive`, `pedantic`.
  Stored as a VS Code setting, not in YAML (see §4).
- **Rule pack** — a named bundle of rule codes scoped to a package or SDK
  migration (e.g. a Riverpod pack, a "Dart SDK removed APIs" pack). Defined in
  [rulePackDefinitions.ts](../../extension/src/rulePacks/rulePackDefinitions.ts).
  Each pack has `id`, `label`, and `ruleCodes[]`.
- **Detected pack** — a pack whose pubspec gate is satisfied: the dependency or
  SDK constraint the pack targets is present in this workspace's `pubspec.yaml`.
  Detection is advisory — it does not enable the pack, it only highlights which
  packs are relevant.
- **Enabled pack** — a pack id listed under
  `plugins.saropa_lints.rule_packs.enabled` in `analysis_options.yaml`.
- **SDK pack** — a pack whose id starts with `dart_sdk_` or `flutter_sdk_`. Each
  is classified `breaking` (contains `avoid_removed_*` rules) or `deprecation`.
- **Stylistic rule** — an opinionated rule that sits in no tier. Off everywhere
  unless turned on via a `true` override. Some stylistic rules form mutually
  exclusive groups (pick-one); the rest are independent toggles.
- **Override** — an entry in the `# RULE OVERRIDES` section of
  `analysis_options_custom.yaml`: `rule_name: true|false`.

---

## 3. Configuration model — what the screen edits

| Zone | UI control | Persisted to | Mechanism |
|------|-----------|--------------|-----------|
| Tier | Segmented radio control (`role="radiogroup"`) | VS Code setting `saropaLints.tier` | `_handleSetTier` |
| Rule packs | Per-row toggle in the pack table | `analysis_options.yaml` → `plugins.saropa_lints.rule_packs.enabled` | `writeRulePacksEnabled` |
| Per-rule disable | "Disabled rules" section (re-enable to remove) | `analysis_options_custom.yaml` → `# RULE OVERRIDES` | `writeRuleOverrides` / `removeRuleOverrides` |
| Stylistic opt-in | "Style & opinions" toggles + pick-one radios | `analysis_options_custom.yaml` → `# RULE OVERRIDES` (`rule: true`) | `writeRuleOverrides` / `removeRuleOverrides` |

Invariants:

- The screen only ever edits the **RULE OVERRIDES** section of the custom file
  and the **rule_packs** block of the main file. It must not touch any other
  section (platform/package config, diagnostics written by the Dart plugin,
  user comments). The write functions are section-scoped by marker and must stay
  that way.
- `analysis_options_custom.yaml` is treated as machine-owned: it carries a "do
  not edit manually" banner pointing back to the extension. The "Disabled rules"
  section is the only graphical path to review and undo what is in it.
- Disabling a stylistic rule = **removing** its override (back to the off
  default), not writing `rule: false`. Writing `false` is reserved for disabling
  a rule the tier/pack would otherwise turn on.

---

## 4. Data sources

Read once per render into a single `DashboardContext` (one I/O pass, consistent
snapshot across all sections):

| Input | Source | Notes |
|-------|--------|-------|
| `pubspec.yaml` | workspace root | drives pack detection; absence → empty-state body |
| Current tier | `saropaLints.tier` setting (default `recommended`) | not in YAML |
| Enabled pack ids | `analysis_options.yaml` `rule_packs.enabled` | legacy alias `migration_packs` is read, normalized away on write |
| Disabled rules | `analysis_options.yaml` `diagnostics:` (`false`) ∪ custom `RULE OVERRIDES` (`false`) | custom `true` re-enables and wins |
| Stylistic opt-ins | custom `RULE OVERRIDES` entries set `true` | complete set of stylistic activations |
| Last-analysis timestamp | `violations.json` `timestamp` | drives freshness label |
| Suppressions snapshot | `violations.json` totals (filtered by disabled) | read-only strip |

Refresh triggers: explicit `refresh()` call, save of `analysis_options.yaml`,
and the disabled-rules cache invalidates on save of either YAML file or after any
override write.

---

## 5. Screen layout (top → bottom)

Density-first ordering. The panel opens in the editor area (`ViewColumn.One`),
not the sidebar, so the table stays usable.

1. **Header** (`dash-hero`) — title with a `?` help-icon (methodology in its
   `title`), a single muted **status line** (`Tier · packs enabled · detected ·
   applicable SDK migrations · last analysis <relative>`), and a **coverage
   gauge** on the right (enabled ÷ detected, HSL red→amber→green, rendered even
   at 0%).
2. **KPI strip** — three keyboard-reachable cards: *Packs enabled* (with
   progress bar; click filters table to enabled), *Applicable SDK migrations*
   (click filters to applicable SDK packs), *Enabled rules* (static count, packs
   only — tier rules excluded).
3. **Tier section** — the segmented radio control. Clicking a tier posts
   `setTier`; the active tier is labeled "(current)".
4. **Toolbar** — dashboard commands incl. *Copy config* (emits paste-ready YAML
   snippet via `buildConfigSnippetYaml`).
5. **Filter strip** (`#filter-strip`, hidden by default) — populated by the
   client script when filter state diverges from defaults.
6. **Pack table** — primary control. One row per pack: label, rule count,
   detected badge, enable toggle, expandable rule-code list. Clicking a rule
   code posts `explainRule` (validated as snake_case) → opens its explanation.
7. **Style & opinions** (stylistic) — collapsed by default. Conflicting groups
   render as pick-one radios (`selectStylistic`, `''` clears the group);
   independent rules as toggles (`toggleRule`); bulk enable/disable per group
   (`stylisticBulk`).

   **Version groups (open).** Packages with version companions
   (`dio` + `dio_5`, `riverpod` + `riverpod_2` + `riverpod_3`, …) must render as a
   single exclusive radio set per package — pick one version or none — rather than
   separate companion toggles, reusing the same pick-one markup. Groups derive from
   `kRulePackDependencyGates` (`lib/src/config/rule_packs.dart`): companions sharing
   a `dependency` plus the same-named base pack form one group; default selection is
   the resolved lockfile version. The YAML writer enforces ≤1 companion per group in
   `rule_packs.enabled`. This is the manual-override layer only — version
   *correctness* already lands from the lockfile via `staleVersionGatedCodes`, so a
   companion the lockfile contradicts renders inactive ("not on this version") and is
   not counted as active. Full plan:
   [RULE_PACKS_VERSION_GROUP_UI_PLAN.md](../history/2026.06/2026.06.24/RULE_PACKS_VERSION_GROUP_UI_PLAN.md).
8. **Disabled rules** — lists every currently-disabled rule; re-enabling removes
   the override. Sits directly under the pack table because both edit the same
   effective set.
9. **Chart section** — pack coverage chart/donut; **omitted entirely** when no
   pack is enabled or detected (an all-gray chart is decoration, not data).
10. **Diagnostics** — bottom-band reference (suppressions snapshot strip, target
    platforms, docs links).

---

## 6. Interactions (webview → host messages)

| Message | Payload | Handler | Effect |
|---------|---------|---------|--------|
| `toggle` | `packId`, `enabled` | `_handleToggle` | add/remove pack in `rule_packs.enabled` |
| `setTier` | `tier` | `_handleSetTier` | write `saropaLints.tier` setting |
| `toggleRule` | `rule`, `enabled` | `_handleToggleRule` | enable → `rule: true`; disable → remove override |
| `selectStylistic` | `packId` (group), `rule` | `_handleSelectStylistic` | pick-one within group; `''` clears |
| `stylisticBulk` | `packId` (group), `enabled` | `_handleStylisticBulk` | enable/disable all in group |
| `explainRule` | `rule` (validated `^[a-z][a-z0-9_]*$`) | command | open rule explanation panel |
| `command` | `id` | `_runDashboardCommand` | run a toolbar/dashboard command |
| `refresh` | — | `refresh` | rebuild HTML |

Security: every identifier arriving over `postMessage` is untrusted. Rule names
forwarded to a command must be validated as snake_case lint ids before use (the
`explainRule` path already does this); any new message that forwards a
user-supplied string to a command MUST do the same.

Write-then-refresh is intentional and must not create a recursive refresh loop:
YAML is written synchronously, then refresh re-reads. The save listener and the
post-write refresh are the same path; guard against re-entrancy if extending.

---

## 7. States

- **No workspace folder** → body: "Open a workspace folder."
- **No `pubspec.yaml`** → body: "No pubspec.yaml in workspace."
- **No `analysis_options.yaml`** → pack writes return `false` (cannot anchor the
  `rule_packs` block). The screen must surface this as an actionable failure, not
  a silent no-op. `writeRulePacksEnabled` only creates the block when a
  `saropa_lints:` mapping already exists (after a `version:` pin preferentially,
  else as the mapping's first child).
- **Nothing enabled / detected** → gauge still renders at its zero state; the
  coverage chart is omitted.
- **Stale `violations.json`** → freshness label degrades (`just now` → `Nm` →
  `Nh` → `Nd` → `Nw` → `never run`). Disabled rules are filtered out of the
  suppressions snapshot so re-enabling later does not under-count.

---

## 8. Accessibility

- Tier control is a true `role="radiogroup"` of `role="radio"` buttons with
  roving `tabindex` and `aria-checked`. No inert spans that look interactive but
  do nothing (the prior bait-and-switch is explicitly disallowed).
- KPI cards are real `<button>`s, keyboard-reachable, with descriptive `title`.
- Coverage gauge is `role="img"` with an `aria-label` stating the percentage in
  words.
- Every interactive control carries an accessible name; icons that act (help `?`)
  carry `aria-label`.

---

## 9. Internationalization

User-facing strings route through `l10n('namespace.key')` from
[i18n/runtime](../../extension/src/i18n/runtime.ts) and live in
[en.json](../../extension/src/i18n/locales/en.json). Per
[.claude/rules/i18n.md](../../.claude/rules/i18n.md): no hardcoded display text,
parameter interpolation (not concatenation), and the Saropa brand is never
translated. CSS, `class`/`id`/`style`, URLs, command ids, and rule codes are
exempt. New keys are added in the same change and the locale catalogs
regenerated before shipping.

Note: several status-line and tooltip strings in the current implementation are
still inline English literals. Routing them through `l10n()` is required work for
any edit that touches those lines (write-time rule), not a separate follow-up.

---

## 10. Non-goals

- Editing the diagnostics section the Dart plugin owns.
- Running or scheduling analysis (the screen reflects the last run; it does not
  trigger one).
- Authoring or translating new locale values for other languages (separate
  pipeline, separate cadence).
- A second configuration surface — the sidebar config tree and this dashboard
  read the same model; they must not diverge.

---

## 11. Open questions / gaps

1. **Missing `analysis_options.yaml`** — current behavior returns `false` on
   pack write. Should the screen offer a one-click "create analysis_options.yaml
   with the saropa_lints block"? (Aligns with `dart run saropa_lints:init`.)
2. **Inline English strings** — status line, gauge tooltip, KPI titles, and
   help text are not yet in `en.json`. Track which keys are needed.
3. **Tier vs. pack overlap surfacing** — the screen states packs are an overlay
   on the tier baseline, but does not show, for a given rule, *why* it is on
   (tier vs pack vs override). A per-rule provenance view is a candidate.
4. **Override visibility for `false` on tier rules** — the disabled-rules
   section lists them, but there is no affordance to see what a rule *would* do
   if re-enabled beyond the explain panel.
5. **Version-group control not yet built** — companion packs still render as
   independent toggles; the exclusive radio grouping (§5 item 7) is open work
   tracked in
   [RULE_PACKS_VERSION_GROUP_UI_PLAN.md](../history/2026.06/2026.06.24/RULE_PACKS_VERSION_GROUP_UI_PLAN.md).
