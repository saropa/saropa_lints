# Saropa Lints — sidebar & affordance inventory

**Activity-bar view slots** in `package.json` → `contributes.views.saropaLints` are **nine** in the current manifest (hub + Overview + optional violation-adjacent trees + TODOs). The product surface also includes **~100 contributed commands**, **`view/title` toolbar bindings**, **`view/item/context` rows**, **HTML dashboard buttons**, etc.; counts below are approximate and drift with releases.

Counts below are from `extension/package.json` / code (`rg`/hand audit, Apr 2026). They move when menus change.

| Bucket | Approx. count | Notes |
|--------|----------------|-------|
| `saropaLints.*` contributed **commands** | **100** | `rg '"command": "saropaLints'` in `package.json` |
| Menu `when` clauses referencing **`view == …`** | **53** | Title bars, context menus, etc. |
| **`view/title`** rows (all Saropa sidebar views) | **~32** | Overview refresh, Package Vibrancy toolbar block, Drift, TODOs, … |
| **`view/item/context`** rows | **~30+** | Violations alone is 10+; File Risk, Package Vibrancy, … |
| **Findings Dashboard** / editor HTML command rows | **varies** | Buttons and “More commands” rows change with dashboards; re-count when editing HTML providers. |
| **Dashboard hub** tree **leaves** | **5** | Single **Editor dashboards** group (`DASHBOARD_HUB_LEAF_COUNT` in `dashboardHubSidebarProvider.ts`): Lints Config, Package Dashboard, Code Health Dashboard, Findings Dashboard, Command Catalog. |
| Editor **HTML** buttons (cross-nav + triage + issues glance, …) | **Not counted here** | Each dashboard is its own bundle |

---

## Activity-bar **view sections** (one row per `views.saropaLints` entry)

| View id | Label | Type | Default / gate |
|---------|-------|------|----------------|
| `saropaLints.dashboardHub` | Dashboards | **tree** (one collapsible group) | Always on in Dart workspace |
| `saropaLints.overview` | Overview & options | tree | `sidebar.showOverview` |
| `saropaLints.fileRisk` | File Risk | tree | opt-in + has violations |
| `saropaLints.summary` | Summary | tree | opt-in + has violations |
| `saropaLints.suppressions` | Suppressions | tree | opt-in + has violations |
| `saropaLints.suggestions` | Suggestions | tree | opt-in + has violations |
| `saropaLints.securityPosture` | Security Posture | tree | opt-in + has violations |
| `saropaLints.todosAndHacks` | TODOs & Hacks | tree | opt-in |

Package Vibrancy, Findings, Drift, and the command catalog are **commands / editor tabs / CodeLens**, not additional `contributes.views.saropaLints` slots in current `package.json`. The former **Violations** activity-bar tree (`saropaLints.issues`) and **command-catalog sidebar** webview are gone — see CHANGELOG [Unreleased].

---

## Dashboard hub — **tree view** shape

The hub is a **native `TreeDataProvider`** (not a webview). Root shows **one expandable group** — **Editor dashboards** — with five command rows (config dashboard, package dashboard, code health dashboard, Findings Dashboard, command catalog). Run analysis, walkthrough, about, pub.dev, and **Create AI agent instructions** are **not** duplicated here; they live under **Overview & options** (Help & resources / Settings).

So you get **one disclosure triangle + nested rows**, not a flat list of buttons only.

---

## Why not literally everything on HTML dashboards?

- **Findings Dashboard** filters and grouping operate in the editor-tab webview state machine; keeping parity with any future sidebar state would mean **duplicating or proxying** logic (large change, easy drift).
- **Other sidebars** (Package Vibrancy list, Drift, TODOs) have **their own** providers and **view/title** toolbars; they were not part of the “move Violations title icons” pass.
- **Cross-links** between dashboards (HTML buttons) remain for **navigation** between editor tabs, not to replace every tree.

---

## Violations / Findings affordances

The **`saropaLints.issues`** activity-bar tree is removed; palette, status bar, **Findings Dashboard**, and **Overview** carry run/focus/filter/help actions instead (see CHANGELOG [Unreleased] extension notes).
