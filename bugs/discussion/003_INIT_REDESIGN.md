# Init Redesign: Extension-Driven, Data-Driven Triage

**Status**: Proposed  
**Priority**: High  
**Impact**: User adoption, retention, upgrade experience

**Principle:** No init command line. The **VS Code extension** is the primary way to set up and configure saropa_lints. Triage is data-driven and happens in the extension UI.

---

## Problem

### The Old World (CLI init)

The previous init wizard asked users to make decisions before they had information:

1. Pick a tier without knowing what issues exist in their project
2. Walk through stylistic rule categories one by one (up to 143 prompts)
3. Get hit with potentially thousands of violations after all that effort

That led to overwhelm, no visibility into what matters for *their* project, and desire to uninstall rather than configure. No manageable upgrade path when new versions add rules.

### The Custom Config File

`analysis_options_custom.yaml` is 272 lines, mostly a wall of stylistic rules with full descriptions in YAML comments. It lists 170+ stylistic rules, platform settings, package settings, and overrides. Users are expected to read and manually toggle — nobody does. It's unworkable.

The custom config also duplicates what can be inferred:

- **Packages** can be auto-detected from `pubspec.yaml`
- **Platforms** can be auto-detected from `pubspec.yaml` (Flutter) or inferred
- **Stylistic rules** should go through the same triage as other rules
- **Rule overrides** are the only thing that genuinely needs a user-editable file

---

## Design Principles

1. **Extension-first.** Setup, analysis, and triage happen in the extension. Users do not run `dart run saropa_lints:init` (or any init CLI). The extension owns the experience.
2. **Analyze first, then decide.** Data drives decisions: run analysis, get per-rule counts, then present triage in the UI.
3. **Same triage model.** Critical rules always on; zero-issue rules auto-enabled; remaining rules grouped by volume (e.g. Group A/B/C/D) with group-level or per-rule choices; stylistic rules triaged separately and opt-in.

---

## Where Things Live

| Concern | Where it lives |
|--------|-----------------|
| **Running analysis** | Extension: "Run analysis" (Overview, Issues empty state, command palette). Under the hood: invokes Dart analyzer + plugin; plugin writes `reports/.saropa_lints/violations.json` (Violation Export API). |
| **Per-rule issue counts** | From `violations.json` (or extended export): rule → count. Used for triage and for "N issues" in UI. |
| **Triage UI** | Extension: Overview/Dashboard + Config view. No terminal wizard. |
| **Writing config** | Extension writes `analysis_options.yaml` (and minimal `analysis_options_custom.yaml` if needed). No requirement to shell out to an init command for normal flow. |
| **Platform/package detection** | Extension (or a small headless library/script the extension calls) reads `pubspec.yaml` and sets platform/package context. No manual config for these. |
| **User overrides** | Minimal `analysis_options_custom.yaml`: only explicit rule overrides (rule_name: true/false). Optional override UI in Config view. |

So: **no init command line**. The extension runs analysis, reads violation data, and drives triage and config writing. CLI init is deprecated or removed; the extension is the only supported path for setup and triage.

---

## Data Flow

1. **Enable Saropa Lints** (extension): ensure `pubspec.yaml` has `saropa_lints` and `analysis_options.yaml` references the plugin (one-click setup).
2. **Run analysis** (extension): user clicks "Run analysis"; extension triggers Dart analysis (e.g. run `dart analyze` or rely on Dart extension); plugin produces `violations.json`.
3. **Load triage data**: extension reads `violations.json` and (if needed) rule metadata (tier, category, impact, stylistic flag). Compute per-rule counts.
4. **Present triage** in extension UI (Overview + Config):
   - Critical: always on; show count and link to Issues (filter by critical).
   - Zero-issue rules: auto-enabled; show "N rules already passing, enabled."
   - Rules with issues: grouped by volume (e.g. 1–5, 6–20, 21–100, 100+). In Config (or a dedicated Triage view): group-level Enable all / Disable all, optional "Review list" for smaller groups with per-rule toggles.
   - Stylistic: same grouping, separate section; opt-in; "Disable all stylistic?" option.
5. **Apply decisions**: extension writes `analysis_options.yaml` (diagnostics: rule → true/false). User overrides in `analysis_options_custom.yaml` are preserved and merged.
6. **Subsequent runs**: extension can compare current counts to last run (e.g. from workspace state or `reports/.saropa_lints/history.json`), show "N fixed", "M new", and suggest re-triaging rules that dropped to zero or moved groups.

---

## Extension UX (aligned with Cohesion / WOW plan)

- **Overview / Dashboard**: Key number (e.g. total or critical), primary CTA "Run analysis" or "View N issues", links to Summary / Config / Logs. After triage: show "N rules enabled, M issues to address" and link to Issues.
- **Config view**: Not read-only. Tier row → quick pick to set tier and apply (if tier still used as a shortcut); **Rule toggles** driven by triage: show groups (e.g. "Group A: 34 rules, 87 issues") with [Enable all] [Disable all] [Review]. Optional per-rule list for "Review". Stylistic section with same pattern and "Disable all stylistic?"
- **No terminal wizard**: All choices in extension UI. No `dart run saropa_lints` for init.
- **Status / progress**: Shown in Overview and Summary (e.g. "Last run: 2 min ago", "Down from 120 → 98"). No separate CLI status command required; extension is the status surface.

---

## Triage Logic (unchanged from original design, applied in extension)

- **Critical rules** (essential tier, security, crash, memory): always enabled; show counts and link to Issues.
- **Auto-enable zero-issue rules**: Rules with 0 issues in current analysis → set to `true`; they catch future violations.
- **Bulk triage by volume**: Remaining rules grouped by issue count (e.g. A: 1–5, B: 6–20, C: 21–100, D: 100+). User makes group-level Enable all / Disable all; for smaller groups, optional "Review list" with per-rule toggles.
- **Stylistic**: Same grouping, separate section; opt-in; option to disable all stylistic.
- **Re-run behavior**: New rules in new version → triage like above. Disabled rules that now have 0 issues → offer to auto-enable. User overrides (from custom config) preserved.

---

## Configuration Output

- **analysis_options.yaml**: Plugins + `saropa_lints` block. Under `diagnostics`, rules are `true` or `false`. Written by the extension after triage (and after any tier preset if used).
- **analysis_options_custom.yaml**: Minimal. Only explicit user overrides (rule_name: true/false). Optional: platform overrides if auto-detection is wrong. No long list of stylistic rules; stylistic goes through triage and into main analysis_options.

Platform and package detection (from `pubspec.yaml`) are used to filter which rules apply; results can be shown in Config ("Detected: Riverpod, Flutter") with optional overrides in custom config.

---

## Eliminating the Old Custom Config

| Old content | New approach |
|------------|----------------|
| Analysis settings (e.g. max_issues) | In `analysis_options.yaml` under `saropa_lints:`; extension can offer a setting. |
| Platform settings | Auto-detected from `pubspec.yaml`; override in minimal custom config if needed. |
| Package settings | Auto-detected from `pubspec.yaml`; no config needed. |
| Stylistic rules (170+ lines) | Triage in extension; output goes to `analysis_options.yaml` diagnostics. |
| Rule overrides | Minimal `analysis_options_custom.yaml` or Config view overrides. |

Migration: If an existing `analysis_options_custom.yaml` is present, extension (or a one-time migration) reads explicit overrides, keeps them, and rewrites the file to the minimal format; optionally back up as `.bak`.

---

## CLI and Backend

- **Init CLI**: **Removed or deprecated.** Extension is the only supported way to do setup and triage. If we keep a headless "apply triage" for scripts/CI, it should be an implementation detail (e.g. library or a non-interactive script that reads violations + decisions and writes YAML), not the main user-facing init.
- **Analysis**: Still performed by Dart analyzer + saropa_lints plugin. Extension triggers analysis (via Dart extension or `dart analyze`) and consumes `violations.json`.
- **Status**: No separate CLI status command; extension Overview and Summary provide status and progress.

---

## What Gets Preserved vs Removed

| Area | Change |
|------|--------|
| Tier selection prompt (CLI) | **Removed.** Replaced by extension triage UI (and optional tier quick pick in Config). |
| Per-rule stylistic walkthrough (CLI) | **Removed.** Replaced by bulk stylistic triage in extension. |
| `dart run saropa_lints:init` | **Removed.** Extension only. |
| `dart run saropa_lints` (default init) | **Removed.** No interactive init in CLI. |
| Tier presets (e.g. recommended.yaml) | **Optional.** Can remain for "zero-config" include; extension may set tier or write diagnostics directly. |
| Platform/package manual config | **Replaced** by auto-detection; override in minimal custom config or Config view. |
| analysis_options_custom.yaml (long form) | **Replaced** by minimal overrides-only file. |
| Data-driven triage (critical, zero-issue, groups, stylistic) | **Preserved** and implemented in extension UI. |
| User rule overrides | **Preserved** in minimal custom config and/or Config view. |
| Post-write validation | Preserved (extension or backend can validate after writing). |
| Dry-run / reset | If needed, as extension actions (e.g. "Reset triage" or "Preview changes") rather than CLI flags. |

---

## Implementation Notes

1. **Violation export**: Ensure `violations.json` (or equivalent) provides enough to compute per-rule counts and link to severity/impact. Add category/stylistic in export or bundle rule metadata in extension.
2. **Extension writes YAML**: Extension must be able to write `analysis_options.yaml` (and optionally `analysis_options_custom.yaml`) with the same structure the plugin expects. No dependency on init CLI for this.
3. **Modularization**: Any remaining "triage engine" (grouping, default decisions, merge with overrides) can live in a Dart library or a small Node/TS helper used by the extension; the extension owns UI and orchestration.
4. **First-run**: After "Enable", extension can offer "Run analysis" → then "Here are your issues" and "Configure rules" (triage) so the flow is: Enable → Run analysis → Triage in Config/Overview → ongoing use.

---

## Success Criteria

- Users never need to run an init command; the extension is the single place for setup and triage.
- "Run analysis" and "Configure rules" (triage) are clear in the extension (Overview + Config).
- Triage is data-driven: critical always on, zero-issue auto-enabled, rest by volume groups and stylistic opt-in.
- analysis_options (and minimal custom overrides) are written by the extension; behavior matches VSCODE_EXTENSION_COHESION_WOW_PLAN (one-click setup, init from UI, config actions in place).

---

## References

- **Extension design and cohesion:** [VSCODE_EXTENSION_COHESION_WOW_PLAN.md](VSCODE_EXTENSION_COHESION_WOW_PLAN.md)
- **Violation export:** VIOLATION_EXPORT_API.md (if present)
- **Issues tree and views:** Extension plan for Issues tree by severity and structure
