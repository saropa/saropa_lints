# Comment coverage plan: metrics + maintenance

**Relationship to workspace rules:** Day-to-day edits follow `.cursor/rules/comment-quality-default.mdc` (concise, no noise). **This plan** is the bar for **comment coverage passes** and any file explicitly brought under that work—see that rule’s section “Full documentation pass”.

**Goal:** **Exhaustive inline and API documentation** wherever this plan applies: good code comments are expected for **every variable**, **every method**, **every class**, **every enum and enum value**, **every list** (intent, ordering, mutability, invariants), **every algorithm** (inputs, outputs, complexity, edge cases), **every branch**, and **every iteration** (why the loop exists, what terminates it, what each pass assumes). The publish metric (`scripts/modules/_code_comment_metrics.py`) remains a **coarse** progress signal only; it does **not** replace human review against this bar.

**Current state:** Earlier waves (2026-04-28) added **thin** file-level notes on many paths. Treat that as **incomplete** relative to this document. Bring files up to the Part 2 standard as they are touched, or in dedicated documentation passes. Wave 1 path tables: [comment_coverage_wave1_batches_A-D.md](history/2026.04/2026.04.28/comment_coverage_wave1_batches_A-D.md).

**Non-goal:** Using “at least one comment line” or raw **comment density %** as proof of quality. Those numbers can go up while still failing this plan.

## Execution snapshot

### Next 3 (ordered)

- [ ] **DOC-01 (P0)** Create a current top-25 backfill queue from `_code_comment_metrics.py` and commit it under `plans/history/` with date stamp.
- [ ] **DOC-02 (P0)** Complete one focused backfill batch (10 files) to full Part 2 depth, including locals/branches/loops documentation coverage.
- [ ] **DOC-03 (P1)** Add a lightweight verification checklist script/report so each batch captures evidence beyond raw density.

### Working rule

During normal feature edits, upgraded comment quality for touched code is required; separate backfill passes should target high-churn/high-risk files first.

### Batch evidence requirement

Each backfill batch should record:

- Files covered
- Reviewer/checker identity
- Whether Part 2 checklist passed per file
- Any deferred comment-depth gaps with rationale

### DOC-02 batch template (copy for each run)

- Batch date:
- Files included:
- Part 2 checklist pass count:
- Deferred items (if any):
- Reviewer notes:

---

<!-- cspell:ignore docstrings -->

## What’s left to do

| Priority      | What                                                                                                                                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ongoing**   | On every change, expand comments until Part 2 is satisfied for the edited surface (not only the top of the file).                                                                                  |
| **Backfill**  | Re-open high-churn or high-risk files from prior waves and deepen comments to Part 2.                                                                                                               |
| **On demand** | Re-rank with `_code_comment_metrics.py` or publish audit to find files that are still thin; use the ranking as a **queue**, not as a definition of “done”.                                           |
| **Optional**  | Extend metrics (e.g. `///` vs `//`, docstrings for Python) or add scripts that flag **uncommented** declarations if you want tooling closer to this bar.                                            |

---

## Part 1 — How the list is produced

- **Scanner:** `scripts/modules/_code_comment_metrics.py` (same heuristics as the publish banner).
- **Roots:** `lib/`, `test/`, `bin/`, `packages/*/lib/`, `extension/src/`, `scripts/` (excludes `.g.dart`, `*_generated.dart`, and junk dirs such as `node_modules`, `.dart_tool`, `build`).
- **“Comment” for Dart/TS:** `//` and `/* … */` outside strings and (for TS) outside template literals / `${…}` bodies.
- **“Comment” for Python:** `#` tokens via `tokenize` (docstrings are **not** counted by the current metric; still add them where they carry API meaning.)
- **Example rankings (queue only):** zero-comment passes, low-density passes, largest files first—same as before. Re-run after edits to refresh ordering.

---

## Part 2 — Required documentation depth

Apply **all** of the following in Dart, TypeScript, and Python as language norms allow (`///` / `/** */` / `#` / docstrings). If a construct is self-explanatory **only** after reading five levels of callee code, it is **not** self-explanatory—document it.

### Universal

- **Every class / mixin / extension / typedef:** purpose, lifecycle, threading or isolate assumptions, and invariants.
- **Every enum and enum value:** what each value means for behavior, persistence, or wire format.
- **Every method / function / getter / setter:** contract (pre/post), parameters, return value, errors, side effects.
- **Every variable / field / parameter (including locals):** role, units, valid range, nullability intent, and why it exists if non-obvious.
- **Every list / map / collection:** ordering, uniqueness, mutability, expected size, and what keys/values represent.
- **Every algorithm:** steps or reference, complexity, edge cases, and failure modes.
- **Every branch (`if` / `switch` / `?:` / pattern guards):** why this path exists and what you expect upstream/downstream.
- **Every loop / iterator / recursion:** termination, progress, and invariants per pass.

### Tests (`test/**`, `extension/src/test/**`)

- Same depth for helpers and data builders as for product code, plus explicit **arrange / act / assert** intent where it clarifies regressions.

### Extension (`extension/src/**`)

- Commands, webviews, trees, diagnostics: document **VS Code** integration points, disposal, event ordering, and user-visible outcomes per branch.

### Scripts and `bin/**`

- Every CLI flag, exit code, and pipeline stage; every non-trivial regex or path manipulation.

---

## Part 3 — Checklist (per file or batch)

- [ ] **Classes, enums (and values), methods:** documented to Part 2.
- [ ] **Variables, parameters, collections:** documented to Part 2.
- [ ] **Algorithms, branches, loops:** documented to Part 2.
- [ ] **File-level** overview still present (what the module owns; what it deliberately does not do).
- [ ] Optional: re-run publish metrics only to confirm the file is no longer an outlier on **zero** or **near-zero** counts—not as a substitute for the checklist above.

---

## Part 4 — Completed waves (reference)

- **Wave 1 (2026-04-28):** Batches A–D — historical list of paths: [comment_coverage_wave1_batches_A-D.md](history/2026.04/2026.04.28/comment_coverage_wave1_batches_A-D.md).
- **Wave 2:** Additional thin notes; same **backfill** expectation as wave 1 unless a file already met Part 2.

---

## Follow-ups (optional)

- Extend `_code_comment_metrics` to count `///`, block docs, and Python docstrings separately from `//` / `#`.
- Add tooling (e.g. AST-based “missing doc on public member”) aligned with Part 2, not only line counts.
