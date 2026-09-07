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

## Finish Report (2026-09-07)

A prior session hoisted 20 of 21 setup variables and wrapped the setup
phase in try/catch. The `vibrancyData` variable was missed — it remained
inside the try block, making it invisible to the vibrancy callback at
line 2905 (outside the try), producing a compile error (`TS2304: Cannot
find name 'vibrancyData'`).

This session completed the fix with four changes:

1. Hoisted `vibrancyData` to the declarations block above the try (same
   type `VibrancyStatusData | null`, same initial value `null`).
2. Replaced silent no-op function defaults with stub functions that log a
   console warning when called after a failed setup, making degraded
   operation visible in Extension Host output.
3. Wrapped `registerCopyAsJsonCommands` in try/catch — it accesses
   hoisted providers inline (not inside a callback), so it would throw
   immediately if setup failed.
4. Added a deferred command registration self-test (3s after activation)
   that compares declared commands in `package.json` against actually
   registered commands and logs any mismatches.

TypeScript compiles clean (`npx tsc --noEmit`). Pre-existing errors in
`audit-report-html.ts` are unrelated.
