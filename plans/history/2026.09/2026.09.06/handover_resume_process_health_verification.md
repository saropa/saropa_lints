# Handover Resume — Process Health Sparkline & Leak Detection Verification

Resumed handover `20260906_1530_process_health_sparkline_leak` to verify prior
session's committed work and diagnose a pre-commit hook staging contamination
issue. Hardening pass applied after reflection gate.

## Findings

### Pre-commit hook staging contamination (diagnosed, no fix needed)

Commit `afd96958` included 7 files from other sessions alongside the intended
process health changes. Root cause: those files were already staged in the
working tree when the commit ran. The pre-commit hook (`.githooks/pre-commit`)
further contributed by auto-staging `lib/src/scan/rule_category_map.dart` after
detecting `lib/src/tiers.dart` (staged from another session) as a changed tier
file.

The hook's behavior is correct — it regenerates generated index files when their
source files are staged. The contamination originated from multi-session staging
overlap, not from the hook itself. Prevention: always use explicit `git add
<files>` and verify `git diff --cached --name-only` before committing.

### Code verification (all passing)

- `npx tsc --noEmit -p .` — clean (0 errors)
- `npx tsc -p tsconfig.test.json` — clean (0 errors)
- `npx mocha 'out-test/test/systemHealth/**/*.test.js'` — 84/84 passing (45ms)

### Pending manual verification (requires Extension Development Host)

Three visual verification tasks remain from the handover, all requiring F5:

1. Tooltip rendering — 3-section layout, sparkline after 2+ polls, trend arrow
   after 5+, both light/dark themes, narrow viewport (~380px)
2. Leak detection notification — after 10+ polls with monotonically rising RSS,
   confirm informational toast fires exactly once
3. Checkmark/trend conflict — Rising trend + Healthy status should suppress the
   ✓ icon

Test procedure: set `saropaLints.systemHealth.warningThresholdGB` to `0.001`,
launch F5, observe over ~10 minutes, restore the setting.

## Finish Report (2026-09-06)

### Hardening changes

**Dead command fix (`processMonitor.ts:285`):** The leak detection toast's "Open
Health Panel" button called `saropaLints.showHealthPanel`, a command that was
never registered. The registered command is `saropaLints.showProcessHealth`.
Fixed the command ID — clicking the button now opens the correct panel.

**Process classification constants (`processQuery.ts`):** Hardcoded process
marker strings (`flutter_tools.snapshot`, `saropa_lints:scan_daemon`,
`language-server`, etc.) were duplicated across `isDaemonProcess`,
`isSaropaProcess`, `isScanDaemonProcess`, `isAnalysisServerProcess`, and
`processLabel`. Extracted to 8 named constants so all callsites match on a
single source of truth. If the Dart SDK or saropa_lints renames a binary,
one constant update propagates everywhere.

**Partition exhaustiveness tests (`statusBarSeverity.test.ts`):** Added 6 tests
verifying that the three tooltip process categories (saropa, daemon, other) are
mutually exclusive. Covers: scan daemon is saropa but not daemon, CLI scan is
saropa but not daemon, Flutter daemon is daemon but not saropa, analysis server
is neither, unrelated dart process is neither, empty command line matches
nothing. Suite total: 84 tests.

### Verification

Both typechecks clean. 84/84 mocha tests passing. Code review (low) found zero
issues in the changed files. The pre-commit hook staging contamination was
diagnosed as a multi-session overlap issue requiring no hook modification.
