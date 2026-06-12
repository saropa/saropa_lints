# Finish-report voice cleanup + published-history phrase scrub

The `/finish` skill persisted its finish-report `.md` files in a first-person
AI-session-transcript voice — `Trigger` openers that quoted the chat prompts,
the boilerplate line "This work will be reviewed by another AI.", and
session-relative deixis ("mine", "this commit", "this finish pass", "the user
asked"). These read as AI self-narration rather than documentation a later
maintainer can use. In saropa_lints, 58 archived report documents under `plans/`
carried that voice. The defect originates in the shared generator
(`~/.claude/skills/finish/SKILL.md`), so it reproduced on every `/finish` run.

## Finish Report (2026-06-12)

### Scope
**(C)** docs/scripts + git-history maintenance. No Dart lint rules, `lib/`,
`test/`, `example/`, or `analysis_options*.yaml` touched.

### What changed

1. **Generator fixed (`~/.claude/skills/finish/SKILL.md`, outside this repo).**
   Section 7 (both DEFAULT and LINTER variants) gained a **Voice** block that
   mandates third-person record voice for the persisted file: lead with what the
   artifact does; do not quote or paraphrase the chat; bar session-deixis
   ("mine", "this commit", "this turn", "this finish pass", "the explicit
   mandate", "when challenged", "the user asked/wanted/said", first-person
   I/we/my); reference work by *what* changed, never *who/what* produced it; keep
   the "reviewed by another AI" note a chat-time statement that never enters the
   file. Section 7B's persisted-intro instruction changed from "the user's
   request verbatim" to "the problem objectively stated … NOT the chat request
   quoted." This corrects all future `/finish` runs in every project.

2. **58 archived report documents under `plans/` rewritten** into third-person
   record voice (commit `88765a5a`). Every `Trigger`/chat-recap opener was
   replaced with an objective problem statement, the "reviewed by another AI"
   boilerplate removed, and inline deixis rephrased. The rewrite was voice-only:
   all code blocks, file paths, line numbers, counts, tables, commit hashes,
   `Status:` lines, and `## Finish Report` headings were preserved verbatim. Net
   churn −216/+146 lines. Residual narration markers across `plans/`: 0 (the only
   remaining `'reviewed by another AI'` string is a CHANGELOG bullet that
   describes the cleanup).

3. **Published history scrubbed of the phrase and force-pushed**
   (`origin/main` `efbe398a` → `13b7284c`). `git-filter-repo` stripped
   "This work will be reviewed by another AI." (and the `Reviewed by another AI` /
   `it will be reviewed by another AI` variants) from every `.md` blob across all
   1937 commits and from the one commit message that carried it. Commit
   attribution was already absent from `origin/main` (no `Co-Authored-By` /
   `🤖 Generated with` trailers ever reached the remote), so the rewrite removed
   only the narration phrase. Older history and most of the 291 tags are
   untouched; four recent tags (v13.12.1, v13.12.2, v13.12.3, v13.12.5) moved.

4. **CHANGELOG** — Maintenance entry under `[13.13.0]` recording the report-doc
   voice rewrite (documentation housekeeping, not shipped to pub.dev).

### Verification

- Integrity of the history rewrite, checked against a pre-rewrite backup bundle
  (`d:/tmp/history_backup_2026-06-11/saropa_lints-ALL-prerewrite.bundle`):
  rewritten HEAD tree **byte-identical** to pre-rewrite (0 files differ);
  commit count **1937 = 1937** (none dropped); **291 tags** preserved; pickaxe
  for the phrase across all history returns **0**. The `AssertionError` printed
  by filter-repo was in commit-map metadata only (a known edge case in repos with
  prior rewrites) and did not affect the rewrite, as the four checks confirm.
- Force-push succeeded; `main == origin/main == 13b7284c`; published history
  pickaxe for the phrase: 0 commits.
- Test audit (Section 4): the only `test/` references to the rewritten documents
  are dartdoc comments citing report **paths** (e.g.
  `/// Bug: plans/history/2026.06/2026.06.01/...md`); the reports were not
  renamed, so the references stay valid. No test pins report content. The rewrite
  commit changed only `.md` files, so no Dart assertion is affected.

### Deep review
- **Logic & safety:** no code changed; the risk surface was content integrity of
  the report docs and the history rewrite, both verified above.
- **Linter-specific integrity:** SKIPPED [C-NOT-IN-SCOPE] — no rules, tiers,
  `LintImpact`, or fixtures changed.
- **Architecture & adherence:** the rewrite preserved each document's structure;
  only prose voice changed.

### Maintenance
- README verified — no rule/doc-count change.
- `pubspec` / `pubspec.lock` — unchanged (no dependency or release change).
- guides reviewed.
- Roadmap — no completed lint entries to remove.
- No bug archive — task did not close a `bugs/*.md` file in this repo.

### Outstanding
None in saropa_lints. The two sibling repos that share the `/finish` skill are
explicitly out of scope for this task.

Finish report saved: plans/history/2026.06/2026.06.12/finish-skill-voice-record-cleanup.md
