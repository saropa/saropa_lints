# BUG: Status bar shows CRITICAL RED for healthy memory (47M)

**Status: Fixed** (2026-09-05, unreleased)

Created: 2026-09-05
Rule: N/A (infrastructure — VS Code extension status bar)
File: `extension/src/extension.ts` lines 1118–1178
Severity: High (misleading alarm, user investigates a non-problem)

---

## Summary

The memory status bar item shows `🔴 47M` on a red/error background, implying
47M RSS is a critical problem. 47M is completely healthy — the thresholds are
4 GB (warning) and 6 GB (critical). The red display is caused by one of two
unrelated triggers leaking into the wrong visual.

---

## Root Cause (two independent bugs)

### Bug A: Orphan-triggered Critical displays RSS instead of orphan count

`classifyHealth()` in `processMonitor.ts:39` returns `HealthLevel.Critical`
when orphaned daemons >= 4, regardless of RSS. But the status bar text at
`extension.ts:1125–1130` always shows the RSS value:

```typescript
const size = systemHealthSnapshot.saropaProcessCount > 0
  ? formatBytes(systemHealthSnapshot.saropaRssBytes)   // "47M"
  : formatBytes(systemHealthSnapshot.totalRssBytes);
text = systemHealthLevel === HealthLevel.Critical
  ? l10n('systemHealth.statusBar.critical', { size })  // "🔴 47M"
  : l10n('systemHealth.statusBar.warning', { size });
```

Result: user sees `🔴 47M` and reasonably concludes 47M is the crisis. The
actual trigger (orphaned daemons) is buried in the tooltip.

### Bug B: Any `memPressureSuffix` forces red background

`extension.ts:1175`:

```typescript
memoryStatusBarItem.backgroundColor = memPressureSuffix || systemHealthLevel === HealthLevel.Critical
  ? new vscode.ThemeColor('statusBarItem.errorBackground')
  : new vscode.ThemeColor('statusBarItem.warningBackground');
```

`memPressureSuffix` is a truthy string for ALL pressure bands — including
info-level shed (`⚡ 3 expensive rules shed`, shed level 1). Every band gets
error-red, even informational ones that should use the default or warning
background.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | 47M RSS → status bar hidden (healthy). Orphan-triggered Critical → text mentions orphans. Info-level shed → non-red background. |
| **Actual** | 47M RSS → `🔴 47M` on red background. Info-level shed → red background. User sees a critical alarm for a non-problem. |

---

## Suggested Fix

1. **Bug A:** When `systemHealthLevel` is driven by orphans (RSS below warning
   threshold), show orphan count in the status bar text, not RSS. Add l10n
   keys like `systemHealth.statusBar.criticalOrphans` /
   `systemHealth.statusBar.warningOrphans`.

2. **Bug B:** Map each pressure band to a severity level and set the background
   accordingly: `hardTripped` and `shedLevel >= 3` → error, `shedLevel >= 2`
   and `softLimitTripped` → warning, `shedLevel 1` → default (no colored
   background, or info-level).

---

## Related

- `bugs/infra_extension_shows_stale_memory_state_when_plugin_disabled.md` —
  stale `memory_state.json` is a third path to a false red display.
- `bugs/analysis_rss_valve_is_measuring_the_wrong_thing.md` — the plugin-side
  valve that produces the pressure state also mismeasures.

---

## Environment

- saropa_lints extension: v16.0.0-beta.4
- VS Code: current stable
- Platform: Windows 11
- Observed RSS: 47M (well below 4 GB warning threshold)

---

## Fix (2026-09-05)

- **Bug A:** `classifyHealth()` is now a thin wrapper over `assessHealth()`,
  which returns `{ level, trigger, orphanCount }` (`HealthTrigger.Memory` /
  `Orphans`). `ProcessMonitor`'s snapshot listener carries the assessment, and
  the new pure `systemHealthStatusBarText()` renders
  `systemHealth.statusBar.criticalOrphans` / `warningOrphans` for orphan
  triggers, so an orphan-driven Critical never shows a memory figure. Memory
  triggers now show the machine-wide total that was actually compared against
  the threshold; the saropa-only RSS stays in the tooltip.
- **Bug B:** each entry in the `PRESSURE_BANDS` table carries a
  `PressureSeverity` (`error` / `warning` / `info`). `pressureBackgroundColorId()`
  maps hard-limit and shed level 3 to `statusBarItem.errorBackground`, shed
  level 2 and soft-pressure-without-shedding to
  `statusBarItem.warningBackground`, and shed level 1 to no background at all.

Regression tests: `extension/src/test/systemHealth/statusBarSeverity.test.ts`.
Runtime rendering (status bar colors in light and dark themes) is unverified —
no Extension Development Host was available.

---

## Finish Report (2026-09-05)

### Defect

The memory status bar rendered a red critical badge beside a small, healthy
memory figure. Two independent causes, plus a third found during the fix.
Health classification returns Critical on orphaned daemon count independent of
memory, but the badge always rendered a memory figure, so the number shown had
no relationship to the condition that tripped. Separately, any non-empty
pressure state forced the error background, including informational bands such
as a light rule shed. The third cause: the warning and critical thresholds are
compared against machine-wide memory, while the badge rendered the smaller
plugin-only figure, so even a genuine memory trip displayed a number that did
not match what tripped it.

### Changes

Health classification now returns an assessment carrying the level, the trigger
that produced it, and the orphan count, rather than a bare level. Memory is
evaluated before orphans at each level so the reported trigger always matches
the figure a badge would show. The snapshot listener carries that assessment, so
the status bar never re-derives the reason. Orphan-triggered states render an
orphan count and never emit a memory figure; memory-triggered states render the
same machine-wide total the threshold compared against. The plugin-only
breakdown remains in the tooltip.

Each pressure band carries an explicit severity. Hard-limit and the highest shed
level map to the error background, the middle shed level and soft pressure
without shedding map to warning, and the lightest shed level to no background at
all. The colour decision is a pure function over the band table, so the colour
cannot drift from the wording.

### Verification

Both TypeScript projects typecheck clean. A regression suite pins the
orphan-triggered text containing a count and not a byte figure, a memory trigger
still rendering bytes, memory winning when both conditions trip, and the full
band-to-colour map including the lightest shed level resolving to no background.

Runtime rendering was not observed. Because this change is about colour, it
needs review in both light and dark themes before it can be considered done.

### Not addressed

Stale pressure state is still rendered without any freshness or plugin-liveness
check, so a state written by a previously running plugin can still drive the
display. That remains open in
`bugs/infra_extension_shows_stale_memory_state_when_plugin_disabled.md`.
