# Saropa Lints — sidebar & affordance inventory

> **ARCHIVED 2026-07-16.** Snapshot of 2026-05-04; every count below is stale
> (manifest at archive time: 166 commands, 5 views, 41 palette entries, and the
> `copyAsJson` family is down to 4 — `suggestions.copyAsJson` and its provider
> were removed). The doc's refresh expectation was not being honored and all
> data is regenerable from `extension/package.json` + `sectionedSidebar.ts`, so
> the hand-maintained copy was closed rather than refreshed. The one durable
> decision — the copyAsJson tree providers are intentionally constructed but
> never registered as views — now lives as a comment at their construction site
> in `extension/src/extension.ts`.

**Activity-bar view slots** in `package.json` → `contributes.views.saropaLints` are **six** in the current manifest (banner + Editor dashboards + Actions + Status + Settings + Help). The product surface also includes **154 contributed commands**; menu wiring is now minimal (most commands are reached via tree leaves, the command palette, or the dashboards).

## Snapshot metadata

- **Type:** Inventory/reference (not an execution plan)
- **Last audited:** 2026-05-04
- **Refresh trigger:** Any `extension/package.json` command/view/menu change
- **Refresh expectation:** update counts + status notes in one commit with audit date

Counts below are from `extension/package.json` and `extension/src/views/sectionedSidebar.ts` (post-`b1ec4ffd` orphan-removal commit, audited 2026-05-04). They move when menus change.

| Bucket | Count | Notes |
|--------|-------|-------|
| `saropaLints.*` contributed **commands** | **154** | Declarations in the `contributes.commands` array |
| Menu `when` clauses referencing **`view == …`** | **3** | `editorDashboards`, `actions`, and the markers panel |
| **`view/title`** rows (all Saropa sidebar views) | **2** | Refresh on `editorDashboards`, Run analysis on `actions` |
| **`view/item/context`** rows | **1** | `focusIssuesForActiveFile` on the markers panel |
| `editor/title` rows | **2** | Package Vibrancy CodeLens toggles on `pubspec.yaml` |
| `editor/context` rows | **1** | `packageVibrancy.sortDependencies` on `pubspec.yaml` |
| `commandPalette` entries | **39** | Mostly visibility/enablement gates for palette entries (was 40 before `b1ec4ffd`) |
| **Editor dashboards** tree **leaves** | **6** | See `buildEditorDashboardItems` in [sectionedSidebar.ts](../extension/src/views/sectionedSidebar.ts) (added "Saropa Project Map" 2026-05-25, renamed from "Project Map" 2026-05-26) |
| Editor **HTML** dashboard buttons | **Not counted here** | Each dashboard is its own bundle |

---

## Activity-bar **view sections** (one row per `views.saropaLints` entry)

All six views are flat `TreeDataProvider`s built by `createSidebarSectionProviders` in [sectionedSidebar.ts](../extension/src/views/sectionedSidebar.ts).

| View id | Label | Type | `when` gate |
|---------|-------|------|-------------|
| `saropaLints.banner` | Saropa Lints | tree (welcome) | `saropaLints.needsBanner \|\| !saropaLints.isDartProject` |
| `saropaLints.editorDashboards` | Editor dashboards | tree (flat) | `saropaLints.isDartProject` |
| `saropaLints.actions` | Actions | tree (flat) | `saropaLints.isDartProject` |
| `saropaLints.status` | Status | tree (flat) | `saropaLints.isDartProject && saropaLints.hasViolations` |
| `saropaLints.settings` | Settings | tree (flat) | `saropaLints.isDartProject` |
| `saropaLints.help` | Help | tree (flat) | `saropaLints.isDartProject` |

The earlier per-concern trees (`overview`, `fileRisk`, `summary`, `suppressions`, `suggestions`, `securityPosture`, `todosAndHacks`, and the legacy `issues` activity-bar tree) are gone. Their data now lives in the **Findings Dashboard** editor tab and the **Settings** panel (which also absorbed the standalone Triage view). Package Vibrancy, Drift, and the command catalog remain commands / editor tabs / CodeLens, not separate `views.saropaLints` slots.

---

## Editor dashboards — tree shape

`buildEditorDashboardItems` returns **six leaves** (no nested groups, flat list):

1. **Lints Config** → `saropaLints.openConfigDashboard`
2. **Package Dashboard** → `saropaLints.packageVibrancy.showReport`
3. **Code Health Dashboard** → `saropaLints.openProjectVibrancyReport`
4. **Saropa Project Map** → `saropaLints.openProjectHealthDashboard`
5. **Findings Dashboard** → `saropaLints.openViolationsWideReport`
6. **Command Catalog** → `saropaLints.showCommandCatalog`

Run analysis, walkthrough, about, pub.dev, and Create AI agent instructions live under **Actions** / **Help**, not under Editor dashboards.

---

## Why not literally everything on HTML dashboards?

- **Findings Dashboard** filters and grouping operate in the editor-tab webview state machine; keeping parity with any future sidebar state would mean **duplicating or proxying** logic (large change, easy drift).
- **Other surfaces** (Package Vibrancy CodeLens, Drift, command catalog) have their own providers; they were intentionally not folded back into a sidebar tree.
- **Cross-links** between dashboards (HTML buttons) remain for **navigation** between editor tabs, not to replace every tree.

---

## Violations / Findings affordances

The legacy `saropaLints.issues` activity-bar tree is removed; palette, status bar, the **Findings Dashboard**, and the new **Status** + **Actions** sidebar sections carry run/focus/filter/help actions instead.

---

## Palette-only `*.copyAsJson` family — flagged, not actioned

The remaining JSON-export commands — `saropaLints.issues.copyAsJson`, `saropaLints.summary.copyAsJson`, `saropaLints.securityPosture.copyAsJson`, `saropaLints.fileRisk.copyAsJson`, `saropaLints.suggestions.copyAsJson` — **do** have runtime handlers in [extension/src/extensionCopyAsJsonCommands.ts](../extension/src/extensionCopyAsJsonCommands.ts), so they are not dead.

But: their backing tree providers (`IssuesTreeProvider`, `SummaryTreeProvider`, `SecurityPostureTreeProvider`, `FileRiskTreeProvider`, `SuggestionsTreeProvider`) are constructed in [extension/src/extension.ts:282-308](../extension/src/extension.ts#L282-L308) and **never registered as VS Code tree views** (only the six section providers in `sectionedSidebar.ts` get `vscode.window.registerTreeDataProvider` calls). The trees live in memory as data sources for the Findings Dashboard and the JSON export — users invoke them from the palette without ever seeing a corresponding sidebar tree.

**Status:** flagged, not actioned. This is a product call (palette-only JSON export still works for the Findings Dashboard data), not a dead-code call. The two genuinely dead `copyAsJson` commands (`config`, `overview`) without handlers were removed in [`b1ec4ffd`](../CHANGELOG.md); these five remain by design until/unless a product decision says otherwise.
