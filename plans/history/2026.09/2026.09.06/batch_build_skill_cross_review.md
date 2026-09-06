# Batch Build Skill — Cross-Review Phase Addition

The `/batch-build` skill (v1.0.0) relied on self-review: each implementation
agent reviewed its own code in step 6 of its prompt. Session 2026-09-06 proved
this ineffective — the `prefer_publish_to_none` implementation agent missed two
regex bugs (`\s*` crossing newlines, `\S` matching `#` comments) that a separate
`/finish` review agent caught.

## Finish Report (2026-09-06)

### Root cause

Self-review is structurally weaker than independent review. An agent that just
wrote code has the same mental model and blind spots when reviewing it. The
orchestrator's Phase 2 "code review" was also shallow — it said "verify
behavioral tests exist, no obvious logic bugs" while simultaneously saying
"do NOT do the agents' work." These two instructions contradict each other.

### Changes (v1.0.0 → v2.0.0)

1. **Added Phase 2 — Cross-Review.** N review agents launch in parallel, each
   reviewing a DIFFERENT build agent's output. Assignment rotates: item N's
   reviewer reviews item (N+1 mod count). No agent reviews its own work.

2. **Added Review Agent Prompt.** Structured adversarial review covering logic
   bugs, regex patterns, edge cases, false positives/negatives, test coverage
   gaps, and registration correctness. Includes specific regex gotchas learned
   from this session (`\s` vs `[ \t]`, `\S` vs `[^\s#]`).

3. **Removed self-review step** from the build agent prompt. The build agent
   now implements, tests, and reports — review is the review agent's job.

4. **Restructured phases:** Build → Cross-Review → Merge → Finish Report →
   Reflection Gate (was: Build → Merge → Finish Report → Reflection Gate).

5. **Updated quality gates** to require all critical review findings fixed
   before commit.

6. **Single-item fallback.** With only 1 spec, the skill still launches a
   review agent — a fresh agent with no shared blind spots, preserving the
   cross-review property.

7. **False-positive triage guidance.** Orchestrator instructions now require
   reading each finding and verifying it has concrete evidence before acting.
   Findings without a specific failing input are noise — skip with a reason.

8. **Lightweight smoke check** retained in build agent prompt (step 6) — tests
   pass, size limits met, comments present. Not a logic review; just catches
   compile errors before handoff.

9. **Explicit test file paths** passed to review agents so they can run tests
   without guessing paths.

### Evidence

Two regex bugs found by independent review, missed by self-review:
- `_publishToAny` regex used `\s*` which matches `\n`, causing cross-line false
  matches (`homepage:\nrepository: url` read as "homepage present")
- Field regexes used `\S` which matches `#`, causing commented-out values
  (`publish_to: # decide later`) to read as "has publish_to"

Both were fixed by changing `\s*` → `[ \t]*` and `\S` → `[^\s#]` in
`pubspec_constraint_parser.dart`, with 16 new tests added to cover the
corrected behavior.
