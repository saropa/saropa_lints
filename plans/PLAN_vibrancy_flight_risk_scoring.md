# PLAN — Project Vibrancy: flight-risk predictive scoring (Phase 5)

**Created:** 2026-06-24
**Split from:** `TODO_vibrancy_residual_surfaces.md` §5.1 (parent TODO archived to `history/2026.06/2026.06.24/`)
**Source plan:** `history/2026.04/2026.04.28/project_vibrancy_report.md` (§ Phase 5 — Flight-Risk)
**Subsystem:** `lib/src/cli/project_vibrancy.dart` (collectors + score) + `extension/src/vibrancy/` (surface)
**Status:** OPEN — RESEARCH-GATED. No production code until the scoring model is validated.
Gate attempted 2026-07-16 (twice: initial + hardened instrument): the candidate formula FAILED
the baseline comparison on the in-repo incident corpus — under the hardened instrument it is
statistically significantly WORSE than complexity-alone (p ≈ 0.046, n = 29). Negative result
recorded; the gate remains unpassed. The validated residue (recency+complexity) shipped
separately as the `fresh_code` vibrancy flag — a threshold flag on existing signals, not the
gated composite score.

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

---

## Findings — research spike, gate attempt 1 (2026-07-16)

**Verdict: the candidate formula does NOT beat the naive baselines. Gate FAILED on this corpus.
Feature stays unbuilt; plan stays OPEN.**

### Method

- **Corpus:** `fix` commits since 2026-01-01 touching `lib/src/rules/*.dart` in this repo, treated
  as incidents. The offending function is the function containing the first changed pre-fix line.
  292 candidate commits; commits touching >5 rule files (mass sweeps) excluded; 30 sampled evenly
  across the period; **16 scored** (14 skipped — changed line fell outside a parseable function,
  e.g. `LintCode` field declarations or doc comments).
- **Scoring:** at each incident's PARENT commit, the offending function was ranked against every
  function (span ≥5 lines) in the offending file plus a seeded random sample of 40 other rule
  files — pools of ~1,030–1,730 functions per incident.
- **Factors (all 0–1):** age = median blame line age /365d; complexity = decision-point count /20;
  churn = distinct blame commits in span authored within 90 days /5; lone-author = 1/distinct
  authors in span; documentation = contiguous `///` lines above declaration /5.
- **Metric:** percentile rank (midrank ties) of the offending function under each score; aggregated
  as median percentile and top-decile hit count. Higher = better prediction.
- **Instrument:** scratch script `d:\tmp\flight_risk_spike.py` (per the plan's no-production-code
  mandate); raw per-incident rows in `d:\tmp\flight_risk_results.json`.

### Prediction (written before the run)

Composite would beat age-alone clearly but be marginal against complexity-alone, because two
factors are confounded on this corpus: the repo is effectively single-author (lone-author ≈
constant 1.0) and rule files are uniformly documented (doc factor compressed). Expected medians:
composite 60–75th percentile, complexity-alone 60–70th, age-alone ≈50th.

### Results (n = 16 incidents)

| Score | Median percentile | Mean | Top-decile hits |
|---|---|---|---|
| Candidate composite (multiplicative) | 59.4 | 56.1 | 0 |
| Composite (equal-weight sum) | 63.3 | 59.0 | 4 |
| **Complexity-alone (baseline)** | **67.5** | **62.9** | **4** |
| Churn-alone (hotspot-SOTA proxy) | 65.2 | 59.9 | 4 |
| Age-alone (baseline) | 25.5 | 26.8 | 0 |

### What the numbers say

1. **The multiplicative composite is the WORST predictive form tested** (59.4 median, zero
   top-decile hits) — worse than complexity-alone, churn-alone, and its own weighted-sum variant.
   The plan's stated concern about multiplication ("punishes any single low factor heavily") is
   confirmed: offending functions in RECENT code get a near-zero age factor that drags the whole
   product down regardless of how complex or churned they are (e.g. incident `08769351`: sum
   percentile 100.0, multiplicative 86.2, age 1.4).
2. **The age factor is directionally WRONG on this corpus.** Age-alone median 25.5 means offending
   functions are markedly YOUNGER than the pool — incidents live in recently written/edited code,
   the opposite of the "old code is risky" assumption baked into `age_factor`. Multiplying by age
   actively subtracts predictive power.
3. **Complexity-alone — the naive baseline the composite must beat — is the best predictor
   tested** (67.5 median). Churn-alone is second. A composite that loses to its own ingredient
   fails the plan's gate by definition.
4. **Two factors were non-discriminating as predicted:** lone-author ≈ constant (single-author
   repo) and documentation compressed (rules are uniformly doc-commented). Neither confirmed nor
   refuted as signals — this corpus cannot test them.

### Corpus limitations (why this is a corpus-scoped negative, not a universal one)

- Incidents are lint-rule bug fixes in THIS repo, not production incidents in a consumer app.
  Rule bugs are usually born-broken (bug present since the rule was written), which mechanically
  favors young code and penalizes the age factor — a consumer-app corpus with regression-style
  incidents could behave differently.
- Single-author history makes the bus-factor signal untestable here.
- Instrument approximations: regex function parser (no AST), keyword-count complexity,
  blame-visible churn (history overwritten by later edits is invisible), and file-sampled pools.

### Gate decision (per Sequence step 2)

The validated score does not beat the naive baseline → **stop; do not build**. Recorded here per
the plan's own rule. Conditions under which the gate may be re-attempted:

1. A **multi-author, consumer-project incident corpus** (e.g. Saropa Contacts regressions with
   identifiable offending functions) — the only way to test lone-author and documentation factors
   and to remove the born-broken age confound.
2. A **re-specified candidate formula**: drop or invert the age factor (recency, not age, predicted
   incidents here) and use a weighted-sum form — multiplication is disqualified by result 1 above.
   Per the failed-attempts convention, any re-attempt must be mechanistically different: same
   formula + same corpus is not a valid attempt 2.

Until then: no churn collector, no author-count collector, no score, no UI surface.

---

## Finish Report (2026-07-16)

The research spike (Sequence step 1) and gate review (step 2) were executed; the build phase
(step 3) was not entered because the gate failed. No production code was written — the
instrument was a scratch script outside the project tree per the plan's mandate.

**What was done:**
- Incident corpus mined from this repo's git history: 292 candidate `fix` commits touching
  `lib/src/rules/`, filtered and sampled to 30, of which 16 yielded a locatable offending
  function. Corpus definition, skip reasons, and limitations recorded in the Findings section.
- Candidate formula prototyped offline (`d:\tmp\flight_risk_spike.py`) with all five factors
  computed per function from `git show`/`git blame` at each incident's parent commit; the
  offending function ranked against pools of ~1,030–1,730 functions per incident.
- Baseline comparison run: the multiplicative candidate (59.4 median percentile, 0 top-decile
  hits) lost to complexity-alone (67.5, 4 hits), churn-alone (65.2, 4), and its own
  weighted-sum variant (63.3, 4). Full table and per-incident rows in the Findings section
  and `d:\tmp\flight_risk_results.json`.
- Gate deliverable 2 (multiplicative vs weighted-sum) is decided by the data: multiplication
  is disqualified — a near-zero age factor on young offenders zeroes the product. Deliverable 3
  (surface) is moot while the gate is unpassed.
- Negative result recorded in this plan's Findings section with explicit re-attempt conditions
  (multi-author consumer-project corpus; re-specified weighted-sum formula with the age factor
  dropped or inverted to recency). The research-frontier skill's Frontier 3 entry and the
  CHANGELOG Maintenance section were updated in the same change.

**Outcome:** gate FAILED on this corpus; plan remains OPEN — RESEARCH-GATED. No churn
collector, no author-count collector, no score, no UI surface may be built until a
mechanistically different gate attempt passes.

---

## Findings — hardened instrument re-run (gate attempt 1b, 2026-07-16)

**Verdict: the gate failure is CONFIRMED and now statistically significant. The candidate
composite is significantly WORSE than complexity-alone (Wilcoxon signed-rank z = −2.0,
p ≈ 0.046, n = 29). Separately, the recency+complexity pair validated well enough to ship as
the `fresh_code` flag (see below) — it is the equal-best predictor tested, not a composite.**

### What was hardened (each answers a weakness recorded in attempt 1's reflection)

1. **Corpus definition:** only `fix(rules...)` commits qualify (rule-behavior fixes by repo
   convention), dropping refactor-adjacent `fix:` commits — 47 qualifying, 30 sampled, 29 scored
   (one skip: changed lines outside parseable functions; v1 skipped 14 of 30).
2. **Offender location:** all hunks in all changed files are mapped; the offending function is
   the one containing the most changed pre-fix lines (v1 used only the first hunk).
3. **Parser:** comments and string-literal contents stripped before declaration matching and
   brace counting.
4. **Complexity:** aligned with the production `_ComplexityVisitor` term set
   (if/for/while/do/case/catch, `&&`/`||`, ternary proxy).
5. **Churn:** max of blame-surviving span churn AND file-level `git log` commit count in the
   window walked from the parent — overwritten history can no longer hide churn.
6. **Pool:** 100 sampled rule files + changed files per incident (~2,600–2,900 functions ranked
   per incident, ~2.5× v1).
7. **Significance:** paired Wilcoxon signed-rank (tie-corrected normal approximation).

### Results (n = 29; percentile rank of the offending function, higher = better)

| Score | Median | Mean | Top-decile hits |
|---|---|---|---|
| fresh (recency + complexity, equal-weight sum) | **80.4** | 66.4 | 9 |
| fresh (recency × complexity) | 67.9 | 65.3 | 9 |
| Recency-alone (1 − age) | 66.1 | 62.4 | 9 |
| **Complexity-alone (baseline to beat)** | 65.3 | 64.2 | 9 |
| Churn-alone | 54.5 | 48.6 | 0 |
| Candidate composite (equal-weight sum) | 43.1 | 47.2 | 7 |
| Candidate composite (multiplicative) | 38.6 | 42.3 | 5 |
| Age-alone | 33.9 | 37.6 | 2 |

Significance (paired, two-sided): composite-multiplicative vs complexity-alone z = −2.0,
p ≈ 0.046 (composite significantly worse); recency vs complexity p ≈ 0.71; fresh-multiplicative
vs complexity p ≈ 0.48 (indistinguishable). Instrument: `d:\tmp\flight_risk_spike_v2.py`,
raw rows in `d:\tmp\flight_risk_results_v2.json`.

### What changed vs attempt 1 and why

- The composite got WORSE under the better instrument (median 59.4 → 38.6). Attempt 1's
  looser corpus and first-hunk offender location had flattered it; with the offending function
  located by majority-of-changed-lines and refactor commits excluded, the age factor's wrong
  direction dominates.
- Churn-alone dropped (65.2 → 54.5): v1's blame-only churn partly measured recency, not
  instability. With the dual estimate, churn adds little on this corpus.
- The age factor is confirmed directionally wrong (median 33.9 — offending functions are young).

### The shippable residue: the `fresh_code` flag

The recency+complexity pair — both signals already collected by the vibrancy CLI — is the
equal-best predictor tested (most top-decile hits, highest medians) and requires no new
history-walking collectors. It shipped 2026-07-16 as the `fresh_code` flag
(`computeFreshCodeFlag` in `lib/src/cli/project_vibrancy_coverage_quality.dart`: median blame
age ≤ 90 days AND cyclomatic complexity > 10), with the honest claim recorded in its doc
comment: as good as the best naive baseline, not proven better (p ≈ 0.48 at n = 29). This is a
threshold FLAG on two existing validated signals, not the gated composite SCORE — the gate
above still bans the flight-risk composite, its new collectors, and any numeric risk score.

The same run fixed a latent production defect found while wiring the flag: the vibrancy age
score's decay formula (`e * -days / 365`, clamped) evaluated to 0 for every function with git
history; it now computes the intended `exp(-days/365)` (see `ageScoreFromDays`).
