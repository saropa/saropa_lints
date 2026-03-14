# What to build: Extension, Init Redesign, and Log Capture

**Purpose:** Single prioritized list of work to make the extension-driven experience complete and better. Draws from [003_INIT_REDESIGN.md](003_INIT_REDESIGN.md), [VSCODE_EXTENSION_COHESION_WOW_PLAN.md](VSCODE_EXTENSION_COHESION_WOW_PLAN.md), and [log_capture_integration.md](log_capture_integration.md).

**Already done:** Violation export (`violations.json`), Issues tree (structure, filters, suppressions), Summary/Config/Logs/Suggestions/Overview views, one-click setup, file watcher, C4 (Summary → Issues), W1 (Apply fix from tree).

**F1–F4 implemented (foundation):** Extension runs init with `--no-stylistic` and `--target` for non-interactive config write (F1). Violations reader exposes `issuesByRule`, `enabledRuleNames`, `stylisticRuleNames`; `triageUtils.ts` provides `groupRulesByVolume()` and `partitionStylistic()` (F2, F3). Export adds `config.stylisticRuleNames`. Config view shows **Detected** from `pubspecReader.ts` (F4). See CHANGELOG Unreleased and extension README.

---

## 1. Foundation (required for “complete”)

These unblock or underpin the rest.

| # | Item | Source | Notes |
|---|------|--------|--------|
| F1 | **Extension writes analysis_options** | Init Redesign | *(done)* Init run non-interactively via `--no-stylistic` and `--target`; shared `buildInitArgs()`. |
| F2 | **Per-rule counts for triage** | Init Redesign | *(done)* `violationsReader` exposes `summary.issuesByRule`; `triageUtils.groupRulesByVolume()`. |
| F3 | **Rule metadata for triage** | Init Redesign § Implementation | *(done)* Export `config.stylisticRuleNames`; extension `partitionStylistic()`. |
| F4 | **Platform/package detection** | Init Redesign | *(done)* `pubspecReader.ts`; Config view “Detected” row. |

---

## 2. Cohesion (do first — single product, clear path)

From Cohesion plan Phase A; makes the extension feel like one product.

| # | Item | Description |
|---|------|-------------|
| C1 | **Overview as home** | First view: key number (total or critical), primary CTA (“Run analysis” or “View N issues”), links to Summary/Config/Logs. Optional “Last run: 2 min ago”. |
| C2 | **Status bar → open view** | Clicking status bar: **Focus Saropa Lints** (reveal sidebar, focus Issues or Overview). “Run analysis” stays in toolbar and command palette; optional secondary on status bar. |
| C5 | **Welcome/empty on every view** | Summary: “No analysis yet” + [Run Analysis]. Config: when disabled, “Enable Saropa Lints” + [Enable]. Logs: “No reports yet” + [Run Analysis]. Suggestions: when enabled and no data, “Run analysis to get suggestions”. |
| C7 | **Single Run analysis + focus** | One obvious entry point (Overview, Issues empty state, palette). After run, auto-focus Issues or Overview + brief “Analysis complete”. |
| C3 | **Suggestions deep-link** | “Fix N critical” → open Issues with filter impact: critical; “Address high-impact” → filter high; “Fix errors” → severity error. “Show in Issues” where it fits. |
| C4 | *(done)* | Summary “Total violations” clickable → Issues, clear filters. |
| C6 | **Config actions in place** | Config: “Tier” row → click opens quick pick, set tier and run init. “Enabled” → toggle or Enable/Disable. Config is the control surface. |

---

## 3. Init Redesign in the extension (no CLI init)

Triage and config live in the extension; no `dart run saropa_lints:init`.

| # | Item | Description |
|---|------|-------------|
| I1 | **Triage UI in Config (and Overview)** | Data-driven: Critical always on + link to Issues; zero-issue rules auto-enabled; rest grouped by volume (e.g. A: 1–5, B: 6–20, C: 21–100, D: 100+) with [Enable all] [Disable all] [Review]. Stylistic: separate section, opt-in, “Disable all stylistic?”. |
| I2 | **Apply triage → write YAML** | After user choices, extension writes `analysis_options.yaml` (diagnostics: rule → true/false). Preserve/merge user overrides from minimal `analysis_options_custom.yaml`. |
| I3 | **Minimal custom config** | Only explicit overrides (rule_name: true/false). Migration: if existing long custom config, read overrides, rewrite to minimal, optionally backup as `.bak`. |
| I4 | **Deprecate/remove init CLI** | No user-facing `dart run saropa_lints:init`. Optional: headless “apply triage” for scripts/CI (library or non-interactive script reading violations + decisions, writing YAML). |
| I5 | **First-run flow** | After Enable: “Run analysis?” → run → “Here are your issues” + “Configure rules” (triage). Enable → Run analysis → Triage in Config/Overview → ongoing use. |

---

## 4. WOW Tier 1 (high impact)

| # | Item | Description |
|---|------|-------------|
| W1 | *(done)* | Apply fix from Issues tree. |
| W2 | **Code Lens** | In Dart files: “Saropa Lints: N issues — Show in Saropa”. Click focuses Issues filtered to that file. |
| W3 | **Rule doc in hover/tree** | Violation tooltip: rule name + short “why it matters” (from rule doc or bundled metadata). Optional “More” link. |
| W4 | **“Show in Saropa Lints” from Problems** | For saropa_lints diagnostics in Problems view: context menu → focus Saropa Issues and filter/select that file. |

---

## 5. WOW Tier 2 (differentiators)

| # | Item | Description |
|---|------|-------------|
| W5 | **Trends / mini history** | Persist last K run summaries (workspace state or `reports/.saropa_lints/history.json`). Overview/Summary: “Last 5 runs” or “Down from 120 → 98”. |
| W6 | **Celebration / progress** | When violations drop: “You fixed N issues” or “−12”. When critical hits 0: “No critical issues”. |
| W7 | **Focus mode: Only this file** | Issues view: context menu on file “Show only this file”; toolbar “Show all” to reset. |
| W8 | **Tier in status bar** | Status bar segment “Tier: recommended” → click to change tier (quick pick) and re-run init. |

---

## 6. WOW Tier 3 (polish)

| # | Item | Description |
|---|------|-------------|
| W9 | **Onboarding** | After Enable: short sequence Run analysis → “Here are your issues” → tip about filter/apply fix. Optional one-time tips in empty states. |
| W10 | **Bulk actions** | Issues: “Fix all auto-fixable in this file/folder”; optional “Suppress rule in this file” (if project allows). |
| W11 | **Group by in Issues** | Preset chips or “Group by: Severity | File | Impact | Rule”. |
| W12 | **Logs parsed / hints** | Logs view: parsed “Analysis: 3 errors, 12 warnings” or “Test X failed” with “Open log” and optional “Run analysis again”. |

---

## 7. Log Capture (optional, consumer side)

Nothing new to build on Saropa Lints for Log Capture; integration is the existing file contract. Optional improvements:

| # | Item | Owner | Description |
|---|------|--------|-------------|
| L1 | **Staleness message** | Log Capture | When lint data is stale: “Run analysis in Saropa Lints to refresh” (in addition to or instead of “Run `dart run custom_lint`”) for extension users. |
| L2 | **Extension README line** | Extension | One sentence: violations.json is also used by Saropa Log Capture for bug report correlation. |

---

## 8. Suggested order of work

1. **Foundation:** F1 (extension writes YAML), F2 (use issuesByRule), F3 (rule metadata), F4 (platform/package detection).  
2. **Cohesion:** C1, C2, C5, C7 then C3, C6.  
3. **Init in extension:** I1 (triage UI), I2 (apply → write YAML), I3 (minimal custom), I5 (first-run), then I4 (remove/deprecate CLI).  
4. **WOW:** Tier 1 (W2, W3, W4), then Tier 2 (W5–W8), then Tier 3 (W9–W12) as capacity allows.  
5. **Log Capture:** L1, L2 when touching those codebases.

---

## 9. Definition of “complete”

- **Complete:** User never runs init CLI; extension is the single place for setup and triage (Enable → Run analysis → Triage in Config/Overview); cohesion C1–C7 done; extension writes analysis_options and minimal custom config; triage is data-driven with rule groups and stylistic opt-in.  
- **Better:** Plus WOW Tier 1 (Code Lens, rule doc, Problems → Saropa) and Tier 2 (trends, celebration, focus mode, tier in status bar); optional Log Capture messaging (L1, L2).

---

## 10. References

- [003_INIT_REDESIGN.md](003_INIT_REDESIGN.md) — Extension-driven init, triage, no CLI.
- [VSCODE_EXTENSION_COHESION_WOW_PLAN.md](VSCODE_EXTENSION_COHESION_WOW_PLAN.md) — Cohesion and WOW phasing.
- [log_capture_integration.md](log_capture_integration.md) — violations.json contract and extension integration.
- VIOLATION_EXPORT_API.md — violations.json schema.
