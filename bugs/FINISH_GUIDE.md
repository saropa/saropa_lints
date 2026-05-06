# FINISH GUIDE

## CRITICAL NOTE
This work may be reviewed by another AI. Finalization must be **explicit, auditable, and scope-true** — without forcing a rigid paste format.

## Purpose
Use this checklist when closing an implementation task and preparing handoff.
Why: finish discipline prevents partial closures and undocumented residual risk.

## Agent Execution Authority
- Execute autonomously: review → improve code → run checks → commit.
- Do not pause for intermediate approval unless blocked by ambiguity, conflicting requirements, or destructive-risk decisions.
- Commit is explicitly authorized when the task request references this guide.
- Do not push unless explicitly requested.

## Mandatory rule (content, not format)
Each topic in the numbered sections below must be **addressed in the completion report** or explicitly marked:

`SKIPPED [Reason Code] - <one-line reason tied to scope>`

Use reason codes from **Reason Codes** below.

---

## Completion report (required when the user references this guide)

Deliver this structure in your **final message** (prose and bullets — not a blank form to copy-paste):

### 1) Work completed
- What was implemented or fixed (concrete, tied to the request).
- Key files or areas touched (enough for a reviewer to orient).

### 2) Work still to do
- **`none`** if the scoped request is fully satisfied, **or**
- A short list of **follow-ups / debt / optional improvements** outside scope.

### 3) Verification (correctness)
State explicitly:
- **Scope:** `(A)` Dart lint / plugin stack, or `(C)` docs/scripts/tooling — and that changed files match.
- **Tests / checks:** What you ran (e.g. `dart test`, `npm test` in `extension/`), and **pass/fail**.
- **Maintenance:** **`CHANGELOG.md`** — if the change is **user-visible** (anything a pub.dev user or VS Code / Marketplace user would notice: behavior, UI copy, settings, commands, extension packaging), you **must** add bullets under **`## [Unreleased]`** in the **same task** before calling the work finished; do **not** leave that as a follow-up or claim `SKIPPED [NO-USER-VISIBLE-CHANGE]` when users would see a difference. Say **CHANGELOG updated** with section, or **`SKIPPED [NO-USER-VISIBLE-CHANGE]`** only when truly infra-only with no shipped artifact impact. **README** / **pubspec** per section 4.
- **Residual risk:** None, or one line (e.g. “not exercised on Windows”).

### 4) Done confirmation
One short paragraph: **why** the result is correct and complete **for the requested scope**, or **what is blocked** and what the user must decide.

### 5) Product / UX choices (when applicable)
- If shipped behavior depends on a **tradeoff users care about** (e.g. **User vs Workspace** settings, default on/off, destructive data loss), **ask the user directly in the same thread** with plain language and clear options — do **not** bury the only prompt in repo Markdown, and do **not** use reason codes like `BLOCKED-NEEDS-USER-DECISION` in place of an actual question to the user.
- After the user answers, put the outcome in **Work completed** or **Done confirmation**; update **CHANGELOG** / in-scope **README** when that answer **documents or changes** shipped behavior.

That replaces any requirement to paste a fixed markdown skeleton. Write it so a human or reviewer AI can audit without re-reading the whole chat.

---

## Validation gate (before you call the task finished)

- [ ] Completion report includes **Work completed**, **Work still to do**, **Verification**, and **Done confirmation**.
- [ ] Scope `(A)` or `(C)` is stated and matches changed files.
- [ ] Every intentional gap uses `SKIPPED [Reason Code] - …` with a valid code.
- [ ] Tests/checks run are named; outcome is stated.
- [ ] Changed-file list is scope-clean (no unrelated edits bundled in).
- [ ] **`CHANGELOG.md`:** if the task shipped **user-visible** Dart or extension behavior, **`## [Unreleased]`** has new bullets (correct subsection); never append to a released **`## [x.y.z]`** — **treating CHANGELOG as optional follow-up is wrong** for user-facing work.

---

## Progress reporting
Progress updates are mandatory when work spans multiple steps.

Minimum checkpoints:
- Start (what you will do first)
- Before edits (what files/approach)
- Before validation/test commands
- Before commit
- Final completion report (above)

Keep each checkpoint to 1–2 lines: current action + next action.

---

## Reason Codes
- `A-LINT-OR-PLUGIN-SCOPE`
- `C-DOCS-OR-SCRIPTS-SCOPE`
- `NO-CODE-CHANGES`
- `NO-USER-VISIBLE-CHANGE`
- `NO-DEPENDENCY-OR-RELEASE-CHANGE`
- `NO-RELATED-BUG-REPORT`
- `UNCHANGED-STACK`
- `BLOCKED-NEEDS-USER-DECISION`

---

## 1) Scope confirmation
- Declare scope as `(A)` Dart lint rules / analyzer plugin (`lib/`, Dart `test/`, `example/`, `analysis_options*.yaml`) or `(C)` docs/scripts/tooling only.
- Confirm all changed files belong to that scope.
- Confirm commit policy for this task (single vs multiple logical commits, message style if specified).

## 2) Deep review confirmation
For code-changed files only, confirm:
- Logic & safety (logic/race/recursion).
- Architecture consistency and utility reuse.
- **If (A) — Linter-specific integrity:**
  - Lints in correct files; overrides for performance; heuristics vs `CONTRIBUTING.md`.
  - `tiers.dart` / `LintImpact` / quick fixes when applicable.
- Performance risks.
- Documentation where logic is non-obvious.
- If refactor opportunities exceed scope: note in **Work still to do**, do not expand scope silently.

## 3) Testing confirmation
- Tests added/updated in the matching stack when behavior changes.
- Before/after behavior explicit for lint rules (incl. false-positive guards).
- Examples/template updated when lint behavior changes (`example/`, `example/analysis_options_template.yaml`).

## 4) Maintenance confirmation
- **`CHANGELOG.md` (non-negotiable for user-visible work):** Any change a **pub.dev** or **VS Code / Marketplace** user would notice (rules behavior, extension UI, settings keys, commands, default behavior) **must** be documented under **`## [Unreleased]`** before the task is closed — **in the same commit series as the code**, not deferred. Follow section rules:
  - Never append to an already released `## [x.y.z]`.
  - Use `## [Unreleased]` unless you are explicitly cutting that release (then move entries per publish flow).
  - Align with `pubspec.yaml` / `extension/package.json` version headers before editing released sections.
  - Agents: **do not** mark CHANGELOG `SKIPPED [NO-USER-VISIBLE-CHANGE]` for extension UX, picker behavior, or new/changed settings — that code is **always** user-visible.
- `README` only when product facts/counts change.
- `pubspec` / lock only for dependency or release work.
- Tracking docs / roadmap / bugs when applicable.

## 5) Commit & handoff
- Tests passed before commit (or document failure/blocker).
- Commit only task files.
- In the completion report: commits (hash + subject), changed paths, plans/bug paths touched, core summary.

---

## Appendix: Structured checklist (optional)

If a reviewer **requests** a fixed checklist, you may use this block. It is **not** the default handoff format.

```md
### Scope
- (A|C): ...
- Files: ...

### Checklist
- Deep review: ...
- Tests: ...
- CHANGELOG: ...

### Commits
- ...
```
