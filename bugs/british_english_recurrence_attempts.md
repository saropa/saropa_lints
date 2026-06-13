# British English Keeps Shipping — Attempt History

**Status:** Open (root cause unaddressed as of 2026-06-12)

British spellings keep reaching `lib/src/rules/**` DartDoc comments and
`problemMessage`/`correctionMessage` strings despite repeated fixes. This
file exists because the same problem has been "fixed" 6 times and recurred
every time. Per the global rule (after 2+ failed attempts, document the
failures before the next try), read this before adding fix #7.

## Why it recurs (root cause)

1. **Generation-time origin.** The British spellings are written into
   comments and lint-message strings at authoring time. No config text
   reliably stops this — it is a passive instruction the author must
   remember to honor on every line.
2. **The only mechanical gate runs at publish — the very last step.**
   `scripts/publish.py` → `scripts/modules/_us_spelling.py` scans the whole
   tree only when releasing. By then the British spellings have been
   committed across many commits; the gate is a late cleanup, not a
   prevention.
3. **That gate is bypassable.** The publish spelling step offers
   `[R]etry / [I]gnore`. On 2026-06-12, 8 hits were found and `[I]gnore`
   was chosen, so they shipped anyway. A gate you can wave through is not
   a gate.

The detector itself is good (whole-word + CamelCase passes, URL/API
exemptions, cspell escape hatch). The failure is **where and when** it
runs, and that it can be skipped.

## Prior attempts (all detector/cleanup, none preventive)

| Commit | What it did | Why it did not stop recurrence |
|---|---|---|
| `576531f5` | Added the US-English spelling check to the publish pipeline | Publish-time only — too late, runs after dozens of commits land |
| `410b94fb` / `92def019` | "Apply US spelling" — manual cleanup of existing leaks | Reactive; no gate moved earlier |
| `39218d0e` | Added the spelling `retry/ignore` prompt to publish | Introduced the **bypass** that let the 2026-06-12 leak ship |
| `e9a10e96` | Skip i18n tooling in the audit | Scoping fix; gate still publish-only |
| `164dd23a` (2026-05-26) | Widened audit to CamelCase + fixed BrE leaks | Better detection, still publish-only and bypassable |
| `a738f321` | Switched a test docstring to American spelling | Reactive cleanup |
| 2026-06-12 (this task) | Fixed 8 new leaks in 5 rule files | Reactive cleanup — **the recurrence this file documents** |

## What a real fix #7 must be different about

Any next attempt MUST move enforcement **earlier than publish** and make
it **non-bypassable**. Detector tweaks and cleanups are explicitly NOT a
fix — they have been tried 6 times. Candidate mechanisms:

- **Git `pre-commit` hook** (`.githooks/pre-commit`, the repo already sets
  `core.hooksPath .githooks`): run `_us_spelling.py` on staged files and
  exit non-zero. Hard, non-interactive — catches it before it lands.
- **Claude Code `PostToolUse` hook** on `Edit|Write` in
  `.claude/settings.json`: run the scanner on the just-written file and
  feed hits straight back in-session. Catches it the moment it is typed —
  the earliest possible point and the direct answer to "config is not
  enough."
- **Remove the publish `[I]gnore` option for spelling** so the existing
  late gate at least cannot be waved through.
