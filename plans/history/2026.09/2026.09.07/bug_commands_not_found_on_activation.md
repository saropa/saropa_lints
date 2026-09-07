# Bug: Commands not found despite extension activation

**Status:** Fixed
**Severity:** Critical — users cannot open any dashboard or initialize config
**Reported:** 2026-09-07

## Problem

These commands fail with "command not found":

- `saropaLints.openConfigDashboard`
- `saropaLints.openViolationsWideReport`
- `saropaLints.initializeConfig`

All three are registered in `package.json` and in `extension.ts` inside
one `context.subscriptions.push(...)` block. The sidebar IS visible because
VS Code renders `contributes.views` from `package.json` regardless of
whether `activate()` succeeded — so sidebar visibility does NOT prove the
activation ran to completion.

## Root cause

The `activate()` function (2400+ lines) ran ~1300 lines of completely
unguarded setup code before reaching the command registration block.
Any throw in that setup — a provider constructor, a file watcher, the LSP
client, the process monitor — aborted `activate()` entirely, skipping all
80 command registrations in the push block that followed.

## Fix

Hoisted 21 variables used by command handlers (providers, utility
functions, state) as `let` declarations above a `try/catch` that wraps the
entire setup phase. The command registration block now sits outside the
try and always executes.

When setup fails:
- All commands still register (no "command not found").
- The error is logged to Extension Host output for diagnosis.
- A command that touches a failed provider throws a meaningful runtime
  error ("cannot read property of undefined") instead of silently missing.

## Files

- `extension/src/extension.ts` — hoisted declarations, try/catch guard
