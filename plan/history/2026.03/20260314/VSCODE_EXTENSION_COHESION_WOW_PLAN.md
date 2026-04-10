# VS Code Extension — Cohesion & WOW Plan

**Status: Plan — not yet implemented.**

Canonical Cursor plan: `vscode_extension_cohesion_and_wow_e4f5a6b7.plan.md` (in `.cursor/plans`).

**Context:** MVP implemented (Issues tree, Summary, Config, Logs, Suggestions, Overview). Extension feels disjointed and lacks standout features. This plan addresses cohesion first, then adds high-impact "WOW" features. It **builds on** the Issues tree (see §1 below); cohesion and WOW must not regress or contradict that plan.

---

## 0. Extension design principles & context

**Goal:** The extension is the **primary way** to use saropa_lints. If the extension doesn't replace the init process from the user's perspective, we have failed. The Dart analyzer + saropa_lints plugin remain the execution plane for linting; the extension owns setup, config, and UX.

**Success criteria:** Master on/off switch; when on, extension has set up project (pubspec + analysis_options) and user never runs `dart run saropa_lints:init` manually; init and analysis from the extension UI; package (README, pub.dev) promotes the extension; Cursor compatible; dual publishing (Open VSX + VS Code Marketplace).

**Data sources:** Primary: `reports/.saropa_lints/violations.json` (Violation Export API — config, summary, violations). Config: `analysis_options.yaml`, `analysis_options_custom.yaml`. Logs: `reports/YYYYMMDD/*_analysis_violations_*.log`, `*_dart_test*.log`. Rule metadata: extension can ship rule→tier/category/impact (e.g. from package or generated JSON). Gaps: category not in export (add or bundle in extension); trends = extension-only store (e.g. `reports/.saropa_lints/history.json` or workspace state).

**Architecture:** Extension provides views, commands, state; reads/writes workspace files. Workspace holds violations.json (read), analysis_options (r/w). Dart analyzer + plugin produce diagnostics and violations.json. Activation: workspace with Dart/pubspec; when enabled, extension ensures pubspec and analysis_options set up. Refreshing: file watcher on violations.json; debounced refresh; manual Refresh and Run analysis.

**Constraints:** VS Code API only; no dependency on Dart/Flutter extension for engine. analysis_options behavior must stay compatible with `dart run saropa_lints:init` for users who don't use the extension. Engines: `^1.74.0` (Cursor-safe). Config prefix: `saropaLints.*`. Publish: vsce + Open VSX; package.json has repository, license, displayName, publisher, icon, .vscodeignore.

**MVP scope (implemented):** Master on/off; one-click setup (pubspec + analysis_options, init from UI); Issues (tree by severity → path, filters, suppressions); Overview, Summary, Config, Logs, Suggestions; progress indicators for long-running commands; debounced refresh on violations.json; custom icon (activity bar + marketplace). Package README promotes extension; publish script supports vsce + Open VSX. **Publish script unified (2026-03-14):** Package and extension are published from `scripts/publish.py`; extension version synced with package; option 6 = extension-only package/publish. Trends view and full config toggles deferred to later phases.

---

## 1. Issues tree (prerequisite — implemented)

The **Issues** view behavior and scale strategy are defined by the Cursor plan **Issues tree by severity and structure** (`issues_tree_by_severity_and_structure_bacbd1ef.plan.md` in `.cursor/plans`). This cohesion/WOW plan assumes that plan is implemented and preserves it.

### 1.1 What the Issues tree plan defines (must be preserved)

- **Structure:** Root → **Severity** (Error | Warning | Info, with counts) → **folder path tree** → **file** → **violations** (capped per file, e.g. 100) + single **overflow** node (“and N more…”).
- **Scale (65k+):** Single parse; index `severity → path → violations[]`; tree nodes O(folders + files); cap violation children per file; no 65k tree items.
- **Filters:** Text (file path, rule, message); type: severity (Error/Warning/Info), impact (Critical/High/Medium/Low/Opinionated), rule multi-select. Applied when building index / getChildren. View message “Showing X of Y” when active.
- **Suppressions (persisted):** Hide folder, file, rule, rule-in-file, severity, impact via context menu; stored in workspace state (or file); “Clear suppressions” in toolbar. Applied in same pipeline as filters.
- **UX/UI:** ThemeIcon per node type; labels with counts; tooltips (full message + correction on violations); loading / no-data / no-match empty states; accessibility (accessibilityInformation); context menus (Hide…, Copy path, Copy message); “Clear filters” / “Clear suppressions” in view title.
- **Files:** `extension/src/views/issuesTree.ts`, `extension/src/suppressionsStore.ts`, `extension/package.json` (filter/suppression commands and menus).

### 1.2 Implementation record (2026-03-14)

Delivered: Tree structure (root → Error/Warning/Info → folder path tree → file → violations capped; overflow "and N more…"). Filters: text (path, rule, message), type (severity + impact), rule multi-select; view message "Showing X of Y". Suppressions: hide folder/file/rule/rule-in-file/severity/impact; persisted in workspace state; "Clear suppressions" in toolbar. Setting: `saropaLints.issuesPageSize` (1–1000, default 100). Context menus: Hide…, Copy path, Copy message. Fixes: root-level folder path prefix; severity/impact suppressions in filtered index.

Files changed: `extension/src/suppressionsStore.ts` (new), `extension/src/violationsReader.ts` (optional `correction` on Violation), `extension/src/views/issuesTree.ts` (rewritten), `extension/src/extension.ts`, `extension/package.json`, `CHANGELOG.md`, `extension/README.md`.

**Cohesion and WOW work must not change** the above structure, scale behavior, filter/suppression semantics, or UX expectations for the Issues view unless explicitly extending them (e.g. W7 “Focus mode: Only this file” adds a mode on top of the existing tree).

### 1.3 Cohesion / WOW implementation record (2026-03-14)

- **C4 (Summary → Issues):** "Total violations" row is clickable; opens Issues view and clears filters so all issues are shown. Command: `saropaLints.focusIssues`.
- **W1 (Apply fix from Issues tree):** Context menu "Apply fix" on a violation invokes `vscode.executeCodeActionProvider` for that file/line (QuickFix kind); prefers code action matching the violation's rule, then applies edit/command. Progress notification "Applying fix…" shown while running. Diagnostic code matching supports string, number, and `{ value }` forms.
- **W2 (Code Lens):** Dart files with violations show a Code Lens at line 0: "Saropa Lints: N issues — Show in Saropa". Command `saropaLints.focusIssuesForFile(filePath)` filters the Issues view to that file. Code Lenses invalidate when `violations.json` changes.
- **W3 (Rule doc in hover/tree):** Violation tooltips include **Rule:** `ruleName` and a [More](ROADMAP) link. Optional short descriptions via `ruleMetadata.ts` (currently link-only).
- **W4 (Problems → Saropa Lints):** Context menu on the Problems view ("Saropa Lints: Show in Saropa Lints") runs `saropaLints.focusIssuesForActiveFile`, which filters Issues to the active editor's file.

---

## 2. Why it feels disjointed

### 2.1 No single home or narrative
- Five tabs (Issues, Summary, Config, Logs, Suggestions) with no default "landing" or story.
- User must know where to go; there is no "start here" or "what just happened" moment.
- Summary and Config are flat lists; they don't guide the next step or link to other views.

### 2.2 Welcome and empty states are uneven
- **Issues** has proper welcome (off / no analysis) and placeholders (no data, no match).
- **Summary, Config, Logs, Suggestions** have no welcome; they show "No violations file", raw config rows, or generic lists.
- Empty Summary doesn't say "Run analysis" with a button; empty Suggestions only shows "Enable" when off.

### 2.3 Status bar doesn't match expectation
- Clicking the status bar runs **Refresh**, not "open Saropa view" or "run analysis".
- Users expect status bar to open the relevant experience or trigger the main action.

### 2.4 Suggestions don't deep-link
- "Fix N critical" runs **Run Analysis** again instead of opening Issues filtered by critical impact.
- No "Show in Issues" or "Focus on this file" from Summary or Suggestions.

### 2.5 Config is read-only and passive
- Config view lists settings and commands but doesn't let you change tier or enabled state in place.
- No inline tier picker or "Change tier" that runs init and refreshes.

### 2.6 No connection to the editor
- No Code Lens ("3 Saropa issues in this file"), no "Show this file in Saropa Lints" from Problems.
- Violations open the file at line (good) but there's no "Apply fix" from the tree; user must use editor quick fix.

### 2.7 Trends deferred
- No history or progress over time, so no sense of "getting better" or "regression".

---

## 3. Cohesion fixes (do first)

Goal: One clear mental model, consistent empty states, and status bar / suggestions that do the right thing.

| # | Change | Notes |
|---|--------|--------|
| C1 | **Dashboard / Home tab** | New first view "Overview" (or rename Issues to be second): one pane with key number (e.g. total or critical), one primary CTA ("Run analysis" or "View N issues"), and short links to Summary / Config / Logs. Optional: "Last run: 2 min ago". |
| C2 | **Status bar → open view** | Clicking status bar: **Focus Saropa Lints** (reveal sidebar and focus Issues, or Overview). Keep "Run analysis" in view toolbar and command palette. Option: secondary action (e.g. long-press or right-click) for "Run analysis". |
| C3 | **Suggestions deep-link** | "Fix N critical" → open Issues with filter "impact: critical" (and reveal Issues view). "Address high-impact" → filter by high. "Fix errors" → filter by severity error. Add "Show in Issues" where it makes sense. |
| C4 | **Summary → Issues** | Make "Total violations" (and optionally "By severity" / "By impact" rows) clickable: open Issues view and apply the matching filter (e.g. click "By impact" → filter by impact). |
| C5 | **Welcome / empty on every view** | Summary: when no data, show same style as Issues ("No analysis yet" + [Run Analysis]). Config: when disabled, show "Enable Saropa Lints" + [Enable]. Logs: "No reports yet" + [Run Analysis]. Suggestions: already has Enable; when enabled and no data, "Run analysis to get suggestions". |
| C6 | **Config actions in place** | In Config view: "Tier" row → click opens quick pick to set tier and run init (same as Set Tier command). "Enabled" → toggle or "Enable / Disable" command. So the view is the control surface, not just a list. |
| C7 | **Single "Run analysis" entry point** | Ensure one obvious place: Overview/Dashboard primary button, Issues empty state, and command palette. After run, auto-focus Issues (or Overview) and show a brief "Analysis complete" message so the user sees the result. |

---

## 4. WOW features (prioritized)

Features that make the extension feel indispensable and memorable.

### Tier 1 — High impact, feasible soon

| # | Feature | Description | Why WOW |
|----|---------|-------------|---------|
| W1 | **Apply fix from Issues tree** | Context menu (and optional toolbar) on a violation: "Apply fix". Extension invokes the Dart analyzer's code action for that rule/location (e.g. via `vscode.executeCodeActionProvider`) so the user fixes without opening the file first. | One-click fix from the list; no need to open file to use quick fix. |
| W2 | **Code Lens: "N issues in this file"** | In Dart files, show a Code Lens above the first line (or near the top): "Saropa Lints: N issues — Show in Saropa". Click focuses Saropa Lints Issues view filtered to this file (or scrolls to this file in the tree). | Editor and extension feel connected; one click from code to Issues. |
| W3 | **Rule doc in hover / tree** | Violation tooltip (and optional inline in tree): include rule name + short "why it matters" (from rule doc or bundled rule metadata). Optional: "More" link to rule doc or ROADMAP. | Transforms "noisy rule name" into "I understand what to do". |
| W4 | **"Focus on this file" from Problems** | In the built-in Problems view, for diagnostics from the Dart analyzer (saropa_lints): context menu "Show in Saropa Lints" → focus Saropa Issues and filter (or select) that file. | Connects IDE Problems and Saropa Issues. |

### Tier 2 — Strong differentiators

| # | Feature | Description | Why WOW |
|----|---------|-------------|---------|
| W5 | **Trends / mini history** | Persist last K run summaries (e.g. total, by severity) in workspace state or `reports/.saropa_lints/history.json`. Overview or Summary shows: "Last 5 runs" mini sparkline or "Down from 120 → 98". | Sense of progress; catches regressions. |
| W6 | **Celebration / progress** | When total violations drop (compare to last run or baseline): brief non-intrusive message "You fixed N issues" or badge "−12". When critical hits 0: "No critical issues". | Positive reinforcement. |
| W7 | **Focus mode: "Only this file"** | In Issues view: context menu on file "Show only this file" (or a toggle) so the tree collapses to one file's violations. Toolbar "Show all" to reset. | Reduces noise when working on one file. |
| W8 | **Quick tier switch in status bar** | Status bar not only "Saropa Lints: On" but optional segment or menu: "Tier: recommended" → click to change tier (quick pick) and re-run init. | Config without opening Config view. |

### Tier 3 — Polish and scale

| # | Feature | Description | Why WOW |
|----|---------|-------------|---------|
| W9 | **Onboarding / first-run** | After "Enable", short sequence: "Run analysis?" → run → "Here are your issues" (focus Issues) → "You can filter by severity or apply fixes from the tree." Optional: one-time tips in empty states. | New users get a clear path. |
| W10 | **Bulk actions** | In Issues: "Fix all auto-fixable in this file" / "in this folder" (invoke code actions in batch where supported). Or "Suppress rule in this file" that inserts ignore (if project allows). | Power users can clean up quickly. |
| W11 | **Rule category / impact in tree** | Optional grouping or filter: by rule category (async, security, etc.) or by impact, so "show me all critical" is one click. Partially there (filter by impact); expose as preset chips or a "Group by: Severity \| File \| Impact \| Rule". | Matches design doc "group by impact, rule, file". |
| W12 | **Logs parsed / hints** | Logs view: for known log types, show parsed line "Analysis: 3 errors, 12 warnings" or "Test X failed" with "Open log" and optional "Run analysis again". | Logs become actionable. |

---

## 5. Phasing

### Phase A — Cohesion (1–2 sprints)
- C1 (Overview/Dashboard), C2 (status bar), C5 (welcome/empty), C7 (single Run analysis + focus).
- Then C3 (suggestions deep-link), C4 (Summary → Issues), C6 (Config in-place actions).

**Outcome:** Feels like one product with a clear entry point and consistent behavior.

### Phase B — WOW Tier 1 (1–2 sprints)
- W1 (Apply fix from tree), W2 (Code Lens), W3 (rule doc in hover).
- Then W4 (Problems → Saropa Lints).

**Outcome:** Extension is the obvious place to see and fix Saropa issues without leaving the flow.

### Phase C — WOW Tier 2 (1 sprint)
- W5 (trends/mini history), W6 (celebration), W7 (focus mode), W8 (tier in status bar).

**Outcome:** Progress visible; power users can focus and tweak tier quickly.

### Phase D — Polish (ongoing)
- W9 (onboarding), W10 (bulk actions), W11 (group by impact/rule), W12 (log hints).

---

## 6. Success criteria

- **Cohesion:** A new user can Enable → Run analysis → see results in one place and understand "what to do next" without reading docs.
- **Status bar:** One click opens the Saropa experience (view focused); Run analysis is easy from the view.
- **WOW:** At least two "I didn't expect that" moments: e.g. "Apply fix from tree" and "Code Lens → Show in Saropa" or "Trends sparkline".
- **No regression:** Existing behavior (filters, suppressions, scale) preserved; performance and Cursor compatibility maintained.

---

## 7. Open questions

1. **Overview vs Dashboard name:** "Overview" vs "Home" vs keep "Issues" as first and add a compact "Summary" header inside Issues (count + Run analysis)?
2. **Apply fix from tree:** Depends on Dart extension exposing code actions by location; need to verify `executeCodeActionProvider` with range + file and that saropa_lints fixes are returned.
3. **History storage:** Workspace state (simple, per-machine) vs `reports/.saropa_lints/history.json` (shareable, survives reinstall). Start with workspace state for Phase B/C.
4. **Code Lens:** May need to depend on Dart extension or use a simple "N issues" from violations.json; filter-by-file in Issues requires passing context (file path) when focusing the view.
5. **Category in export vs. in extension:** Add `ruleCategory` (and maybe `ruleTier`) to violations.json, or keep export minimal and bundle rule→category map in the extension?
6. **Config ownership:** Should the extension ever write analysis_options.yaml directly, or always go through `saropa_lints:init`?
7. **Naming:** "Saropa Lints" vs. "Saropa Lints Companion" to make clear it's an add-on to the package.

---

## 8. References

- **Issues tree (full plan):** Cursor plan `issues_tree_by_severity_and_structure_bacbd1ef.plan.md` (in `.cursor/plans`). Defines Issues view structure, scale, filters, suppressions, and UX; see §1 above.
- **Violation export:** `VIOLATION_EXPORT_API.md`
- **Extension source:** `extension/src/`
