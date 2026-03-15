# What to build: Extension, Init Redesign, and Log Capture

**Purpose:** Single prioritized list of work to make the extension-driven experience complete, integrated, and genuinely differentiated. Supersedes the previous separate plans (cohesion/WOW, init redesign). Source material: [003_INIT_REDESIGN.md](003_INIT_REDESIGN.md), [log_capture_integration.md](log_capture_integration.md).

**Already done:** Violation export (`violations.json`), Issues tree (structure, filters, suppressions), Summary/Config/Logs/Suggestions/Overview views, one-click setup, file watcher, C4 (Summary → Issues), W1 (Apply fix from tree), W2 (Code Lens), W3 (rule doc in tooltip), W4 (Problems → Show in Saropa), F1–F4 (foundation), W5 (trends), W6 (celebration), W7 (focus mode), W8 (tier in status bar), H1–H3 + H5 (Health Score in Overview + status bar + history + score persistence), C1–C7 (all cohesion items), D1 (Security Posture view), D3 (inline annotations), D11 (focus mode = W7), I1 (Triage UI in Config), I2 (Apply triage → write YAML), I3 (Minimal custom config), I5 (First-run flow), I4 (Deprecate CLI init).

**Implementation records (done 2026-03-14):**
- **W5 (Trends):** `runHistory.ts` persists last 20 snapshots in workspace state; Overview shows "Trends" row with last 5 totals arrow-separated.
- **W6 (Celebration):** Celebration messages on violation decrease; "↓ N fewer issues" in Overview; "No critical issues" notification when critical hits 0.
- **W7 (Focus mode):** `focusedFile` filter in IssuesTreeProvider, context menu "Show only this file" on file nodes, toolbar "Show all files".
- **W8 (Tier in status bar):** Second status bar item showing tier, click to change. Status bar logic consolidated into `updateAllStatusBars()`.
- **W1 (Apply fix):** Context menu on violations in Issues tree invokes `vscode.executeCodeActionProvider`; prefers matching rule; progress notification.
- **W2 (Code Lens):** Dart files show "Saropa Lints: N issues — Show in Saropa" at line 0; invalidates on violations.json change.
- **W3 (Rule doc):** Violation tooltips include rule name + [More](ROADMAP) link via `ruleMetadata.ts`.
- **W4 (Problems → Saropa):** Context menu "Show in Saropa Lints" runs `focusIssuesForActiveFile`.
- **H1–H3 (Health Score):** `healthScore.ts` computes 0–100 score from impact-weighted violation density with exponential decay. Score shown in Overview as primary item with delta ("Health: 78 ▲4 from last run"). Status bar shows "Saropa: 78 ▲4" with color bands (green/yellow/red background via `statusBarItem.backgroundColor`). Score persisted in `RunSnapshot.score` via `runHistory.ts`. Shared `findPreviousScore()` in `runHistory.ts`. Celebration messages include score delta.
- **C5 (Welcome/empty states):** All six tree providers return `[]` when disabled or when no violations data exists, so VS Code's native `viewsWelcome` content renders with centered text and clickable command buttons ("Enable Saropa Lints", "Run Analysis"). Replaces flat placeholder tree items. Issues tree keeps a "No violations found" item for the 0-violations case (to avoid misleading "No analysis results yet" from viewsWelcome).
- **C7 (Single Run Analysis + focus):** After `runAnalysis` succeeds, Overview is focused (instead of Issues) to show the Health Score delta. Completion notification includes score ("Analysis complete. Score: 78"). `debouncedRefresh` now calls `updateContext()` to keep viewsWelcome when-clauses current when violations.json appears via file watcher.
- **C1 (Overview as home):** Overview shows "Last run: X min ago" from most recent history timestamp (via `formatTimeAgo()`) and a "Run Analysis" CTA button between trends/celebration and view links.
- **C2 (Status bar → open view):** Already working — `statusBarItem.command = 'saropaLints.focusView'` → `saropaLints.overview.focus`. Marked done.
- **C3 (Suggestions with score impact):** `estimateScoreWithout(data, impact)` in `healthScore.ts` projects the score with a given impact level zeroed out. Critical and high suggestions show "estimated +X points" as description. Falls back to "Show in Issues" when score can't be computed.
- **C6 (Config as control surface):** `initializeConfig` checks `runAnalysisAfterConfigChange` and auto-runs analysis. `setTier` runs analysis inside `runSetTier()` in `setup.ts` (under the same progress notification), then focuses Overview to show score delta. Views and status bars refresh after.
- **D1 (Security Posture view):** `securityPostureTree.ts` — OWASP Top 10 coverage matrix with two collapsible groups (Mobile Top 10, Web Top 10). Each category row shows violation count + distinct rule count from `Violation.owasp` data. Click filters Issues to mapped rules via `focusIssuesForOwasp` command (rule-hide filter). `OwaspData` interface added to `violationsReader.ts`. `buildCounts()` result cached per refresh cycle. Zero-violation categories show green pass icon.
- **D3 (Inline annotations):** `inlineAnnotations.ts` — Error Lens style line-end decorations. One `TextEditorDecorationType` per severity (error/warning/info) for VS Code performance. First violation per line per severity; message truncated to 80 chars with rule name. Violations cache (`getCachedViolations`) avoids disk I/O on editor switch; invalidated via `invalidateAnnotationCache()` in `refreshAll`. Toggle via `saropaLints.inlineAnnotations` setting and `toggleInlineAnnotations` command. Decoration types disposed on extension deactivation.
- **I1 (Triage UI in Config):** `triageTree.ts` — discriminated union node types (ConfigSettingNode, TriageGroupNode, TriageRuleNode, TriageInfoNode). `buildTriageData()` computes all triage groups from `ViolationsData`: critical rules (flame icon, any rule with critical-impact violations), volume bands A–D (1–5, 6–20, 21–100, 100+), zero-issue count (auto-enabled), stylistic (opt-in, paintcan icon). Critical and stylistic rules filtered out of volume grouping to avoid double-counting. `buildRuleImpactMap()` in `triageUtils.ts` does single O(n) scan of violations for per-rule impact breakdown. `estimateScoreForRuleRemoval()` in `healthScore.ts` projects score if group's violations were fixed. Each group description shows "N rules, M issues, est. +X pts". Expand groups to see individual rules sorted by issue count. Click group/rule → `focusIssuesForRules` command filters Issues view. `configTree.ts` refactored from flat `ConfigItem` to `TreeDataProvider<ConfigTreeNode>` with collapsible triage groups. `focusIssuesForRules` and `focusIssuesForOwasp` consolidated into shared handler (handles both TreeItem click and context menu invocation).
- **I2 (Apply triage → write YAML):** `configWriter.ts` — reads/writes RULE OVERRIDES section of `analysis_options_custom.yaml`. `writeRuleOverrides()` adds `rule_name: false` entries; `removeRuleOverrides()` deletes entries (revert to tier default). Both scope changes to the RULE OVERRIDES section only (won't modify stylistic or platform sections). Context menus "Disable rule(s)" and "Enable rule(s)" on `triageGroup` and `triageRule` nodes. After write: `runInitializeConfig()` regenerates `analysis_options.yaml` from tier + overrides, then auto-analyzes if setting is on. Config view shows "N rules disabled by override" info node. Confirmation dialog for groups >5 rules. `setup.ts` gets optional `title` param for custom progress messages.
- **I3 (Minimal custom config):** `custom_overrides_core.dart` — `migrateToMinimalFormat()` detects old bloated format (has `# STYLISTIC RULES` section), extracts `max_issues`/`output` values, platform settings, and enabled stylistic rules, backs up as `.bak`, rewrites to minimal (~40 lines). `createCustomOverridesFile()` now uses `buildMinimalConfig()` (analysis settings + platforms + rule overrides only). `init_runner.dart` — removed `ensurePlatformsSetting`, `ensurePackagesSetting`, `ensureStylisticRulesSection` calls; packages always auto-detected from pubspec via `detectProjectPackages()`. Migration is one-time and idempotent (skips if no STYLISTIC section found).
- **I5 (First-run flow):** `extension.ts` — enable handler now reads violations.json after `runEnable()`, records history snapshot, focuses Overview view, and shows score-aware notification with action buttons ("View Issues" / "Configure Rules"). Three cases: score available → "Your project scores X/100. [qualifier]"; violations but no score → "Found N issues"; no data → "Run analysis to see your health score". `setup.ts` — removed generic `showInformationMessage` (notification now handled by enable handler where score data is available).
- **I4 (Deprecate CLI init):** `init_runner.dart` — deprecation notice added; `promptForTier()` call removed (defaults to 'recommended' when no `--tier` flag). `init_post_write.dart` — all 3 `stdin` prompts removed: V4 ignore conversion (now `--fix-ignores` flag only), stylistic walkthrough (removed entirely), "Run analysis?" (removed, prints hint instead). `tier_ui.dart` — help text updated to reflect headless-only mode. Command still works for extension (`--tier X --no-stylistic --target DIR`) and CI.

---

## The integration thesis

The current plan has good parts that don't talk to each other. The rewrite is organized around one idea: **every feature both consumes and enriches the same data pipeline**, so each piece makes the others more valuable.

```
violations.json (source of truth)
    │
    ├─► Health Score (computed)
    │       ├─► Status bar ("Score: 78 ▲4")
    │       ├─► Overview (score + delta + primary CTA)
    │       ├─► Code Lens ("Health: 84 | 3 issues — Show in Saropa")
    │       ├─► Celebration ("Score up! 74 → 78")
    │       └─► Log Capture bug reports ("Project health: 78 at time of crash")
    │
    ├─► Per-rule counts + impact (already in export)
    │       ├─► Triage UI (I1) ──► Config writes (I2) ──► re-analysis ──► updated score
    │       ├─► Suggestions deep-link ("Fix 4 critical → +6 points")
    │       └─► File Risk view (which files have the most critical density)
    │
    ├─► OWASP mappings (already on every violation)
    │       ├─► Security Posture view ("M9: 4 violations, M3: 2")
    │       ├─► OWASP Compliance export (for audits, app store submissions)
    │       └─► Log Capture ("crash file has OWASP M9 violations")
    │
    ├─► Issues tree (existing, enriched)
    │       ├─► Inline annotations (Error Lens style — violation text on the line)
    │       ├─► Fix Impact Preview ("resolves 1 critical, score +2")
    │       └─► Bulk fix with impact summary ("fixed 12 issues, score 74 → 81")
    │
    └─► History (persisted runs)
            ├─► Trends in Overview ("last 5 runs" sparkline)
            ├─► Regression detection ("3 new critical since last run")
            └─► Score trajectory ("62 → 71 → 78 over 2 weeks")
```

The **Health Score** is the integration point. It:
- Is computed from violations.json (Foundation)
- Updates when triage decisions change rules (Init Redesign)
- Appears in Overview, status bar, Code Lens (Cohesion)
- Drives celebration and trends (WOW)
- Can be included in Log Capture bug reports
- Gives developers a number to share: *"Our Saropa score went from 62 to 78 this sprint"*

The **OWASP data** is the unique asset. No other Dart linter maps violations to OWASP categories. This makes Saropa the tool of choice for teams that care about security posture — and it's data you already have.

---

## 1. Foundation (done)

| # | Item | Notes |
|---|------|-------|
| F1 | **Extension writes analysis_options** | *(done)* Init run non-interactively via `--no-stylistic` and `--target`; shared `buildInitArgs()`. |
| F2 | **Per-rule counts for triage** | *(done)* `violationsReader` exposes `summary.issuesByRule`; `triageUtils.groupRulesByVolume()`. |
| F3 | **Rule metadata for triage** | *(done)* Export `config.stylisticRuleNames`; extension `partitionStylistic()`. |
| F4 | **Platform/package detection** | *(done)* `pubspecReader.ts`; Config view "Detected" row. |

---

## 2. Health Score (new foundation — unlocks integration)

Compute a single 0–100 score from violations.json. This becomes the number that ties everything together.

| # | Item | Description | Feeds into |
|---|------|-------------|------------|
| H1 | **Score computation** | *(done)* `healthScore.ts`: impact-weighted density with exponential decay. Constants at top for tuning. | Every view, status bar, celebration, Log Capture |
| H2 | **Score in Overview** | *(done)* Overview shows "Health: 78" with delta ("▲4 from last run") as primary item. | C1 (Overview as home) |
| H3 | **Score in status bar** | *(done)* Status bar shows "Saropa: 78 ▲4". Color bands: green (80+), yellow (50–79), red (<50). | C2 (status bar → open view) |
| H4 | **Score in Code Lens** | Per-file: "Saropa: 3 issues (2 critical) — Show in Saropa". Optional file-level health indicator. | W2 (Code Lens, already done — extend it) |
| H5 | **Score history** | *(done)* Score persisted in `RunSnapshot.score` via `runHistory.ts`. `findPreviousScore()` shared helper. | W5 (trends), celebration, Overview |

**Why this matters:** CodeScene built a business around "Code Health" — a single score with proven correlation to defect rates. Sourcery does function-level quality scores (0–100%). Neither exists for Dart. Saropa's score has a richer input signal (impact levels, OWASP, 2050+ rules) than either.

---

## 3. Cohesion (single product, clear path)

These make the extension feel like one product. The Health Score enriches each one.

| # | Item | Description | Integration |
|---|------|-------------|-------------|
| C1 | **Overview as home** | *(done)* Health Score primary, "Last run: X ago", Run Analysis CTA, links to other views. | Score from H2; trends from H5 |
| C2 | **Status bar → open view** | *(done)* Click status bar → `focusView` → `overview.focus`. Score shown in status bar (H3). | Score from H3 |
| C5 | **Welcome/empty on every view** | *(done)* All views return `[]` for disabled/no-data; VS Code viewsWelcome renders native buttons. | — |
| C7 | **Single Run analysis + focus** | *(done)* After run: focus Overview (shows score delta), notification includes score. File-watcher refreshes update context. | Score delta from H1 |
| C3 | **Suggestions deep-link with impact** | *(done)* "Fix N critical → estimated +X points" via `estimateScoreWithout()`. Filters Issues by impact on click. | Score estimation from H1 |
| C4 | *(done)* | Summary "Total violations" clickable → Issues, clear filters. | — |
| C6 | **Config as control surface** | *(done)* Set tier and init auto-run analysis when `runAnalysisAfterConfigChange` is on. Score delta visible after re-analysis. | Triage (I1), score update (H1) |

---

## 4. Init Redesign in the extension (no CLI init)

Triage and config live in the extension. Triage decisions directly affect the Health Score — users see the impact of their choices.

| # | Item | Description | Integration |
|---|------|-------------|-------------|
| I1 | **Triage UI in Config** | *(done)* Critical + volume A–D + stylistic groups in Config view with score estimation. Click → filter Issues. `triageTree.ts`, extended `triageUtils.ts` + `healthScore.ts`. | Per-rule counts (F2), score estimation (H1) |
| I2 | **Apply triage → write YAML** | *(done)* `configWriter.ts` writes RULE OVERRIDES to custom YAML; re-init + re-analyze → score delta. Context menus disable/enable on triage nodes. | Config writes → re-analysis → H1 score |
| I3 | **Minimal custom config** | *(done)* Custom file reduced from ~420 lines to ~40. Removed STYLISTIC (→ RULE OVERRIDES) and PACKAGE (→ auto-detect from pubspec) sections. One-time migration with `.bak` backup. `custom_overrides_core.dart`, `init_runner.dart`. | — |
| I4 | **Deprecate/remove init CLI** | No user-facing `dart run saropa_lints:init`. Optional headless variant for CI. | — |
| I5 | **First-run flow** | Enable → "Run analysis?" → run → show score + "Here are your issues" + "Configure rules" (triage). The score gives immediate context: "Your project scores 34/100 — let's improve that." | Score (H1), triage (I1) |

---

## 5. Differentiators (research-driven WOW)

These replace the generic W5–W12 with features backed by what actually differentiates top extensions. Each one leverages the data pipeline — they're not standalone gimmicks.

### Tier 1 — Only Saropa does this (for Dart)

| # | Item | Description | Why it's different | Integration |
|---|------|-------------|-------------------|-------------|
| D1 | **Security Posture view** | *(done)* OWASP coverage matrix: Mobile Top 10 + Web Top 10, each with 10 category rows showing violation count + rule count. Click filters Issues to mapped rules via `focusIssuesForOwasp`. Green pass icon for zero-violation categories. `securityPostureTree.ts`. | **No other Dart linter maps to OWASP.** Enterprise/regulated teams need this. | OWASP data from violations.json |
| D2 | **OWASP Compliance export** | Command: "Export Security Report" → generates markdown/HTML summary of OWASP coverage, violation counts by category, gap analysis. Useful for audits, app store submissions, team reviews. | Unique to Saropa. No Dart tool generates this. | OWASP data + score (H1) |
| D3 | **Inline annotations** (Error Lens style) | *(done)* `inlineAnnotations.ts`: one `TextEditorDecorationType` per severity (error/warning/info). First violation per line per severity, message truncated to 80 chars with rule name. Toggle via `saropaLints.inlineAnnotations` setting and `toggleInlineAnnotations` command. Refreshes on violations.json change via `updateAnnotationsForAllEditors()` in `refreshAll`. | Error Lens has 14M+ installs — #1 most-loved code quality UX pattern. | violations.json file/line data |
| D4 | **Fix Impact Preview** | Before applying a fix (from Issues tree or inline): "This resolves 1 critical violation. Estimated score: 78 → 80." After fix: "Score updated: 80 ▲2". | CodeScene shows health delta in real-time. Saropa can do the same for fixes. Turns "fix lint" into "improve score". | Score estimation (H1), fix (W1 done) |

### Tier 2 — Strong differentiators

| # | Item | Description | Why it's different | Integration |
|---|------|-------------|-------------------|-------------|
| D5 | **Score-driven trends** | Overview: sparkline of last K scores with timestamps. "62 → 71 → 78 over 2 weeks." Regression alert: "Score dropped 78 → 72 — 3 new critical violations in auth_service.dart." | CodeScene tracks code health over time but requires a server. This is local-only, zero setup. | Score history (H5) |
| D6 | **File Risk heatmap** | In explorer sidebar or dedicated view: files color-coded by critical/high violation density. "These 5 files have 60% of your critical issues." Click → filter Issues to that file. | Unique way to answer "where should I focus?" without reading the Issues tree. | issuesByFile + impact from violations.json |
| D7 | **Bulk fix with impact summary** | "Fix all auto-fixable in this file" → runs, then: "Fixed 12 issues. Score: 74 → 81 ▲7." Optional: "Fix all auto-fixable in project" with confirmation. | Bulk fix exists elsewhere; score-integrated bulk fix does not. | Score (H1), Code Actions API |
| D8 | **Score-driven celebration** | When score crosses a threshold (e.g. 50→60, 80→90): brief non-intrusive celebration. "Score reached 80 — great work!" When critical hits 0: "Zero critical issues." When score drops: no shaming, just "3 new issues in auth_service.dart — view." | Positive reinforcement tied to a meaningful number, not just "you fixed N issues." | Score history (H5), thresholds |

### Tier 3 — Polish

| # | Item | Description | Integration |
|---|------|-------------|-------------|
| D9 | **Onboarding with score** | First-run: Enable → analyze → "Your project scores 34/100" → "Here's what we found" → "Configure rules to improve" → triage. Score gives immediate anchor. | Score (H1), first-run (I5) |
| D10 | **Group by in Issues** | Preset chips: "Group by: Severity \| File \| Impact \| Rule \| OWASP category". OWASP grouping is unique. | OWASP data, Issues tree |
| D11 | **Focus mode** | *(done — W7)* Issues view: "Show only this file" context menu; "Show all" to reset. | Issues tree (existing) |
| D12 | **Logs parsed / hints** | Logs view: parsed "Analysis: 3 errors, 12 warnings" or "Test X failed" with "Open log" and "Run analysis again". | — |

### Already done (WOW Tier 1 from previous plan)

| # | Item | Status |
|---|------|--------|
| W1 | Apply fix from Issues tree | *(done)* |
| W2 | Code Lens: "N issues — Show in Saropa" | *(done)* — extend with score in H4 |
| W3 | Rule doc in hover/tree tooltip | *(done)* |
| W4 | "Show in Saropa Lints" from Problems | *(done)* |

---

## 6. Log Capture (shared data, not shared code)

The integration is the file contract — violations.json is read by both the extension and Log Capture. The Health Score and OWASP data make this richer.

| # | Item | Owner | Description | Integration |
|---|------|-------|-------------|-------------|
| L1 | **Staleness message** | Log Capture | "Run analysis in Saropa Lints to refresh" for extension users. | — |
| L2 | **Extension README line** | Extension | One sentence: violations.json is also used by Saropa Log Capture for bug report correlation. | — |
| L3 | **Health Score in bug reports** | Log Capture | "Project health: 78/100 at time of crash." One line that gives context to any bug report. | Score (H1) — Log Capture reads from violations.json or a small companion file |
| L4 | **OWASP in bug reports** | Log Capture | "Crash file has 2 OWASP M9 violations (insecure data storage)." Connects runtime errors to security posture. | OWASP data from violations.json |

---

## 7. Suggested order of work

The order follows the data pipeline: build the score first, then the features that consume it.

1. ~~**Health Score (H1–H3):**~~ *(done)* Score computation, Overview, status bar. H5 (score persistence) also done.
2. ~~**Cohesion (C1–C7):**~~ *(done)* Overview as home, status bar, welcome states, single Run analysis, suggestions with score impact, config as control surface.
3. ~~**Security Posture (D1):**~~ *(done)* OWASP coverage matrix — Mobile + Web Top 10.
4. ~~**Inline annotations (D3):**~~ *(done)* Error Lens style line-end decorations with toggle.
5. ~~**Init in extension (I1–I5):**~~ *(done)* Triage UI, apply triage, minimal custom config, first-run flow, deprecate CLI.
6. **Fix Impact Preview (D4) + Bulk fix (D7):** Score-aware fixing. Turns "fix lint" into "improve score." **← next**
7. **Trends + celebration (D5, D8):** Score sparkline, regression alerts, threshold celebrations. (Basic W5/W6 done; D5/D8 extend with score-driven features.)
8. **Score in Code Lens (H4):** Extend existing Code Lens with per-file score or critical count.
9. **OWASP export (D2), File Risk (D6):** Compliance report and heatmap — polish differentiators.
10. **Remaining polish (D9, D10, D12):** Onboarding, group-by, log hints. (D11 done.)
11. **Log Capture (L1–L4):** When touching those codebases.

---

## 8. Definition of "complete" and "better"

- **Complete:** User never runs init CLI; extension is the single place for setup and triage. Cohesion C1–C7 done. Extension writes analysis_options and minimal custom config. Triage is data-driven with rule groups and stylistic opt-in. **Health Score visible in Overview and status bar.**

- **Better:** Plus inline annotations (D3), Security Posture view (D1), score-driven trends and celebration (D5, D8), Fix Impact Preview (D4), OWASP Compliance export (D2). Log Capture shows score and OWASP context in bug reports (L3, L4).

- **Best:** All of the above plus File Risk heatmap (D6), bulk fix with impact summary (D7), OWASP grouping in Issues (D10), onboarding with score (D9).

---

## 9. Competitive positioning

| Feature | ESLint | SonarQube IDE | CodeScene | Sourcery | **Saropa Lints** |
|---------|--------|---------------|-----------|----------|-------------------|
| Squiggles + Problems | Yes | Yes | Yes | Yes | Yes |
| Quick fixes | Yes | AI CodeFix | AI refactor | AI suggestions | Yes (2050+ rules) |
| Code Health Score | No | No (server only) | Yes | Per-function | **Yes (project + file)** |
| OWASP mapping | No | Server only | No | No | **Yes (every violation)** |
| Security Posture view | No | Server only | No | No | **Yes** |
| Inline annotations | Via Error Lens | No | No | No | **Yes (built-in)** |
| Score-driven triage | No | No | No | No | **Yes** |
| Fix Impact Preview | No | No | Health delta | No | **Yes (score delta)** |
| Trends (local, no server) | No | No | No | No | **Yes** |
| Runtime correlation | No | No | No | No | **Yes (via Log Capture)** |

---

## 10. References

- [003_INIT_REDESIGN.md](003_INIT_REDESIGN.md) — Extension-driven init, triage, no CLI.
- [log_capture_integration.md](log_capture_integration.md) — violations.json contract and extension integration.
- VIOLATION_EXPORT_API.md — violations.json schema.

### Research sources (informing differentiator choices)

- **CodeScene VS Code** — Code Health scoring with delta tracking, AI-powered refactoring (ACE), real-time code health monitor
- **Sourcery** — Function quality scores (0–100%) with sub-scores (complexity, working memory, method length), AI chat, PR reviews
- **SonarQube for IDE** (4.2M installs) — AI CodeFix, connected mode for team settings, educational "coding tutor" framing
- **Error Lens** (14M+ installs) — Inline annotations directly on the line; the single most-loved code quality UX pattern
- **Version Lens** — Inline version annotations, vulnerability detection via OSV.dev with red squiggles
