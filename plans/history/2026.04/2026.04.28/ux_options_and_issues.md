# UX plan: Options vs Violations (Saropa Lints extension)

This document steps back from implementation details and defines a coherent mental model, then lists concrete UX directions to reduce confusion.

---

## 1. Why it feels confusing today

| Problem | What users hit |
|--------|----------------|
| **Two “config” concepts** | **Settings** (JSON / Settings UI) for `saropaLints.*`, vs **Config** sidebar view for tier/triage/init — same word, different jobs. |
| **Options in three places** | Per-section **sidebar toggles** (Overview → Sidebar), **Settings → Sidebar**, and sometimes **view-specific settings** (e.g. Drift Advisor, Package Vibrancy). Unclear which is “source of truth.” |
| **Too many sidebar sections** | 12+ views in one activity bar container; names overlap (Summary vs Violations vs Config vs Rule Packs). |
| **Conditional visibility** | Some views only appear when `enabled`, when violations exist, when Package Vibrancy has run, when Drift server connects — hard to predict. |
| **Violations vs Problems** | Dart analyzer populates **Problems**; Saropa **Violations** reads `violations.json`. Users need a clear path: “where do I fix lint findings?” |

---

## 2. Guiding principles

1. **One primary job per surface** — Don’t mix “layout of the sidebar” with “lint configuration” with “triaging violations” in the same mental bucket.
2. **Violations (lint findings) are the main task** — After setup, the default story is: see findings → fix → re-run analysis. Everything else is supporting.
3. **Progressive disclosure** — Defaults hide advanced tools; power users opt in via Settings or an explicit “More tools” area.
4. **Same names as VS Code** — Prefer “Settings” for persisted flags; use a distinct label (not “Config”) for the **triage / tier / init** view if we rename.

---

## 3. (a) Options — proposed information architecture

Split **options** into three layers so users know where to look:

### Layer A — Master & analysis (Settings: `saropaLints.*`)

| Intent | Examples | Notes |
|--------|-----------|--------|
| **On/off & analysis behavior** | `enabled`, `tier`, `runAnalysisAfterConfigChange`, `runAnalysisOpenEditorsOnly`, `issuesPageSize` | Documented in README; **single place** for “how Saropa behaves.” |
| **Editor integration** | Inline annotations, code lens, check for updates | Same Settings surface. |

**UX rule:** All **behavioral** options live here. Users who open **Settings** find the full list (grouped by subheadings).

### Layer B — Sidebar layout (“Which panels appear?”)

| Intent | Examples | Notes |
|--------|-----------|--------|
| **Visibility of activity bar sections** | `saropaLints.sidebar.show*` | Mirrors VS Code’s native “hide view” but **named and portable** across machines if synced. |

**UX rule:** This is **only** “what appears in the Saropa activity bar,” not rule tiers or analysis.

- **Primary (canonical):** Overview → **Activity bar sections** (renamed from Sidebar) is the main place to manage visibility.
- **Secondary (advanced mirror):** Settings `saropaLints.sidebar.show*` remains available for JSON/workspace-sync users, but should be treated as an implementation detail.
- **Copy requirement:** Add one-line help text in both surfaces clarifying they edit the same underlying state.
- **Avoid:** Presenting multiple equivalent controls as peers without naming the canonical path.

### Layer C — Project lint setup & triage (today’s “Config” view)

| Intent | Examples | Notes |
|--------|-----------|--------|
| **What tier / what’s enabled / triage** | Tier, triage groups, open `analysis_options`, init, run analysis | This is **project configuration**, not global Options. |

**UX rule:** Rename in the UI to something unambiguous, e.g. **“Setup & triage”** or **“Rules & setup”**, and use the subtitle/tooltip: *“Tier, overrides, and rule groups for this workspace.”*

**Optional consolidation:** Move the most common actions (**Run analysis**, **Open analysis options**) into a **compact header** on **Violations** so users don’t need to discover Config first.

---

## 4. (b) Violations view — proposed UX story

### Primary user story

> “I want to see what’s wrong, jump to code, understand the rule, and clear or filter noise — without fighting two different panels.”

### Proposed hierarchy

1. **Violations** = **default home** for Saropa-driven work after `enabled` + first analysis.
   - Tree: group by severity / file / impact / rule (already supported).
   - Toolbar: group, filter, refresh, clear filters — **keep**; ensure icon tooltips state the *current* mode (“Grouped by: File”).
2. **Problems** = analyzer truth; Saropa should **bridge**, not duplicate without explanation.
   - Existing: “Show in Saropa Lints” from Problems — **keep prominent** in docs and consider a **default keybinding hint** in walkthrough.
3. **Summary / File Risk / Security** = **secondary lenses** on the *same* violation set — not separate “sources of truth.”

**UX copy rule:** In walkthrough and Overview, one sentence: *“**Violations** reads the latest analysis report; **Problems** shows analyzer diagnostics. Use Violations for grouping, filters, and Saropa actions.”*

### Reduce cognitive load

| Idea | Rationale |
|------|-----------|
| **Badge / empty state** | When `violations.json` is missing: Violations shows one clear CTA: **Run analysis** (not a blank tree). |
| **“No violations” state** | Distinct from “not analyzed yet” — different message and icon. |
| **Filter persistence** | Document whether filters reset on analysis (today’s behavior) or persist; pick one and state it in tooltip. |

### Future (optional)

- **Unified entry:** Command **“Saropa Lints: Focus Violations View”** as the **single** recommended command in palette docs for “show me lint findings.”
- **Onboarding:** First-run after enable: toast or walkthrough step that opens **Violations** and points to **Group by** and **Explain rule**.

---

## 5. Recommended implementation order (product)

1. **Rename “Config” view** (display name only) to **Setup & triage** (or agreed label) + tooltip.
2. **Rename Overview “Sidebar” expander** → **Activity bar sections** + short description (Layer B vs C).
3. **Define canonical language in copy** — In Overview/README/Walkthrough, explicitly state “Activity bar sections is the default place to manage visibility; Settings is an advanced mirror.”
4. **Walkthrough + README** — Add § “Where are options?” mapping Layers A/B/C; add § Violations vs Problems (one paragraph).
5. **Violations empty state** — Copy pass for “not analyzed” vs “0 violations.”
6. **(Optional, later)** Single **Sidebar layout** command only if discoverability remains poor after the rename/copy pass.

---

## 6. Decision defaults (this phase)

- **Sidebar visibility source of truth (UX):** `Activity bar sections` is the canonical entry point.
- **Settings role:** Keep `saropaLints.sidebar.show*` for advanced usage, but de-emphasize in user-facing guidance.
- **Rename safety:** Do not change view ids or command ids in this phase.
- **Scope control:** Ship naming + copy + empty states first, then reassess with user feedback.

### Success criteria (ship-now, no telemetry required)

- **Naming consistency:** No user-facing primary UX labels use ambiguous `Config` wording for the renamed surface; the standalone view label is **Setup & triage**.
- **Canonical path clarity:** User-facing copy states that **Overview -> Activity bar sections** is the default place to show/hide sections; Settings `sidebar.show*` is treated as an advanced mirror.
- **Violations state clarity:** Empty states are explicitly distinct:
  - **Not analyzed yet:** prompts to **Run analysis**.
  - **No violations:** shows an **all clear** state.
- **Regression protection:** Automated tests assert the key labels and view registrations (rename + Activity bar sections wording), and extension tests pass.

### Manual QA checklist (same-day)

- Open the extension sidebar and confirm the view title reads **Setup & triage** (not Config).
- Open **Overview & options** and confirm the section label reads **Activity bar sections**.
- In Settings, confirm the group label and descriptions reflect the canonical/default path language.
- Verify `viewsWelcome` and Violations tree empty states show different copy for:
  - no analysis report yet
  - no violations found
- Run extension unit tests and confirm they pass after these UX changes.

---

## 7. Out of scope for this plan

- Package Vibrancy / Rule Packs / Drift Advisor product design (each deserves its own short “who is this for?” blurb).
- Changing analyzer pipeline or `violations.json` format.

---

## 8. Summary

| Area | User question | Answer we want them to have |
|------|----------------|----------------------------|
| **Options** | “Where do I change behavior?” | **Settings → Saropa Lints** |
| **Options** | “Where do I hide sidebar panels?” | **Activity bar sections** (Overview) as default; Settings `sidebar.show*` is advanced mirror |
| **Options** | “Where do I change tier / triage rules?” | **Setup & triage** view (renamed Config), not “Options” |
| **Violations** | “Where do I fix lint findings?” | **Violations** view first; Problems for raw diagnostics; link between them |

This plan is intentionally incremental: rename + copy + empty states deliver most of the clarity; deeper consolidation can follow user feedback.
