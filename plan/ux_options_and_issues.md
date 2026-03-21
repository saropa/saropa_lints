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

**UX rule:** This is **only** “what appears in the Saropa activity bar,” not rule tiers or analysis. Prefer **one** entry point to edit these:

- **Recommended:** A dedicated **“Sidebar layout…”** command that opens a **single** focused UI (Quick Pick or simple webview) listing sections with checkboxes — *or* keep Overview → **Sidebar** expander but **rename** the parent to **“Activity bar sections”** and add a one-line description: *“Show or hide views here; does not change analysis or rules.”*

- **Avoid:** Duplicating the same toggles in three places without copy that explains equivalence (Settings JSON = Overview toggles).

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

1. **Rename “Config” view** (display name only or + view id if breaking change acceptable) to **Setup & triage** (or agreed label) + tooltip.
2. **Rename Overview “Sidebar” expander** → **Activity bar sections** + short description (Layer B vs C).
3. **Walkthrough + README** — Add § “Where are options?” mapping Layers A/B/C; add § Violations vs Problems (one paragraph).
4. **Violations empty state** — Copy pass for “not analyzed” vs “0 violations.”
5. **(Optional)** Single **Sidebar layout** command replacing or supplementing per-section Settings rows for discoverability.

---

## 6. Out of scope for this plan

- Package Vibrancy / Rule Packs / Drift Advisor product design (each deserves its own short “who is this for?” blurb).
- Changing analyzer pipeline or `violations.json` format.

---

## 7. Summary

| Area | User question | Answer we want them to have |
|------|----------------|----------------------------|
| **Options** | “Where do I change behavior?” | **Settings → Saropa Lints** |
| **Options** | “Where do I hide sidebar panels?” | **Activity bar sections** (Overview) **or** Settings `sidebar.show*` |
| **Options** | “Where do I change tier / triage rules?” | **Setup & triage** view (renamed Config), not “Options” |
| **Violations** | “Where do I fix lint findings?” | **Violations** view first; Problems for raw diagnostics; link between them |

This plan is intentionally incremental: rename + copy + empty states deliver most of the clarity; deeper consolidation can follow user feedback.
