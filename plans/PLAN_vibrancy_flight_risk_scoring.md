# PLAN — Project Vibrancy: flight-risk predictive scoring (Phase 5)

**Created:** 2026-06-24
**Split from:** `TODO_vibrancy_residual_surfaces.md` §5.1 (parent TODO archived to `history/2026.06/2026.06.24/`)
**Source plan:** `history/2026.04/2026.04.28/project_vibrancy_report.md` (§ Phase 5 — Flight-Risk)
**Subsystem:** `lib/src/cli/project_vibrancy.dart` (collectors + score) + `extension/src/vibrancy/` (surface)
**Status:** OPEN — RESEARCH-GATED. No production code until the scoring model is validated.

---

## What it is

Flight-risk is a predictive composite answering: *which functions are most likely to cause an incident
if the original author leaves or the code is touched in a hurry?* `grep` confirms no `flightRisk`
surface exists today. Unlike the five primary signals (age, coverage, usage, complexity, documentation),
this one **must be validated before shipping** — a high-wow, low-accuracy score erodes trust in the whole
report.

## Why it is gated (do not skip to building)

1. **Gated on the documentation collector** (now shipped). Without it, flight-risk would flag every old
   complex function equally, ignoring that some are old-because-stable-and-well-documented — a noisy
   panic list users dismiss. The doc signal is the specific factor that separates risky from merely old.
2. **Gated on validation.** The formula below is a *candidate*, not a spec. Shipping it unvalidated is
   the failure this gate exists to prevent.

## Candidate model (to validate, NOT to ship as-is)

```
flight_risk = (age_factor × complexity_factor × churn_factor × lone_author_factor)
              × (1 − documentation_factor)
```

- `age_factor` — function age (already collected via git blame), normalized 0–1.
- `complexity_factor` — cyclomatic complexity (already collected), normalized 0–1.
- `churn_factor` — distinct commits touching the function in the last N days. High churn = unstable.
  **Not yet collected** — needs a per-function commit-count collector over `git log`.
- `lone_author_factor` — 1.0 for a single author, dropping toward 0 as author count rises (bus-factor
  proxy). **Not yet collected** — needs distinct-author counting per function. This is a cross-file /
  history signal; per the source plan's cache rule it must NOT be cached under a per-file blob SHA.
- `documentation_factor` — documentation score (already collected), normalized 0–1. The point of the
  doc signal: well-documented code is materially less risky even when other factors are high.

## Research deliverables (the gate — all required before any production code)

1. **Predictive validation.** Assemble a corpus of real incidents (commits that caused production bugs)
   and test: does a high flight-risk score identify the offending function better than a naive baseline
   (e.g. age-alone, or complexity-alone)? Deliverable: a comparison report with the prediction-quality
   numbers. If it does not beat the baseline, the feature does not ship.
2. **Multiplicative vs weighted-sum decision.** Multiplication punishes any single low factor heavily,
   which may be too severe (one well-documented factor shouldn't necessarily dominate). Decide and
   justify with the corpus data.
3. **Surface decision.** Tree column, flag, or its own view? Source-plan lean: **own view** — too fuzzy
   to be a binary flag, too noisy for a primary column. Confirm against how the validated score
   distributes.
4. **Auditability.** Document the final formula in code comments AND in this plan, so a user can see
   *why* the tool called their function risky. A black-box risk score is not acceptable.

## New collectors this needs (only after the gate passes)

- **Churn collector:** per-function distinct-commit count over a configurable window (`git log -L` per
  function range, or a line-range attribution pass). New, cross-history.
- **Author-count collector:** distinct authors per function (bus-factor). New, cross-history; inherits
  the tree-SHA cache discipline, not per-file blob SHA.

Age, complexity, and documentation factors reuse existing collectors — no new collection for those.

## Sequence

1. **Research spike (no production code):** build the incident corpus, prototype the score offline
   (scratch script in `d:\tmp\`, not the project tree), run the baseline comparison, decide
   multiplicative-vs-sum and the surface. Output: a findings section appended to this plan.
2. **Gate review:** does the validated score beat the naive baseline? If no → stop, record the negative
   result here, leave OPEN. If yes → proceed.
3. **Build (post-gate):** churn + author collectors, the score, and the chosen surface — each phased and
   sign-off-gated like any feature.

## Blast radius

Two new history-walking collectors + a new score + a new UI surface. Multi-part feature. The research
spike is cheap and self-contained; everything past the gate needs explicit go-ahead. Do not begin the
build phase on the strength of the candidate formula alone — the validation report is the precondition.
