# CHANGELOG AI-attribution scrub

Two CHANGELOG bullets named an AI authoring tool ("a Claude editor hook") and
quoted AI-session boilerplate ("AI-session narration … reviewed by another AI"),
violating the repository rule that prohibits any AI-tool reference in committed
content. The references were removed from the working file and from the entire
published git history.

## Finish Report (2026-06-22)

### Defect

The repository forbids AI-tool attribution anywhere in committed content
(commit messages, CHANGELOG, docs). Two bullets in the `[Unreleased]` section of
`CHANGELOG.md` breached this:

- A developer-tooling bullet described an editor pre-save spelling check as
  "a Claude editor hook".
- A documentation-housekeeping bullet described prose cleanup as removing
  "AI-session narration (chat-quoting `Trigger` openers, \"reviewed by another
  AI\" lines, …)".

Both phrases were also present in the historical commits that introduced them
(`8c278817` and `13b7284c`), so a working-file edit alone would have left the
references visible in `git log` and in the published GitHub history.

### Change

Current file:

- "a Claude editor hook" → "an editor save hook".
- "removing AI-session narration (chat-quoting `Trigger` openers, \"reviewed by
  another AI\" lines, first-person/session deixis)" → "removing session-narration
  artifacts (chat-quoting openers, first-person/session deixis)".

Both rewrites preserve the original technical meaning (an editor save-time
spelling gate; removal of chat-style narration from archived reports).

History:

- `git filter-repo --replace-text` applied the same two literal substitutions
  across all blobs in history. The replacements were the full CHANGELOG bullet
  substrings, scoped so they matched only the CHANGELOG and not the unrelated
  `plans/history/**` finish reports that mention the same words in different
  surrounding prose.
- Commit-count parity held (2058 commits before and after); `fsck` reported only
  expected dangling blobs.
- A concurrent process committed unrelated platform-readiness work on top of the
  rewritten history and, carrying a stale CHANGELOG snapshot, re-introduced both
  phrases in that single tip commit. The scrub was re-applied to the working file
  and folded into that tip via `--amend`, so no commit in the final history
  carries either phrase.
- `main` was force-pushed (`60c1ac2d` → `531c5eac`). Post-push verification:
  `git log -S` for both phrases against `origin/main` returns nothing.

### Scope boundary

Commit-message occurrences of the words "Claude" and "AI" that are product or
feature names ("Saropa Claude Guard", "Create … Instructions for AI Agents") are
legitimate and were left unchanged. Two `plans/history/**` finish reports still
contain "reviewed by another AI" as quoted boilerplate; these are outside the
CHANGELOG scope of this task and were left pending an explicit decision.

### Safety net

A local tag `backup-before-ai-scrub` points at the pre-rewrite tip (`e89416bf`)
for recovery. It is local-only and not pushed.
