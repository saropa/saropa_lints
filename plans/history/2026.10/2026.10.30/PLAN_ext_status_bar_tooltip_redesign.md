# Status bar tooltip redesign

**Status: Done, merged**

Code: `extension/src/extension.ts` (`buildStatusBarTooltipMarkdown`, `renderStatusBar`, `buildStatusBarTooltipLines`, `buildProcessTooltipLines`).

## Problems (from screenshot, 2026-10-30)

- Every line is its own paragraph. No grouping, no hierarchy.
- Headline says "Partly off"; the toggle link says "Analysis enabled (click to disable)". Contradiction.
- Two different diagnoses for one state: "plugin off in analysis_options.yaml" and "not set up: neither a dependency nor a plugin".
- "Click to open the version compatibility card" sits under an unrelated line.
- "18368 error(s) of 18368 finding(s)" reads as a bug when all findings are errors.
- "1 workspace issue(s)" never names the issue.
- Process lines are flat text; "RSS trend" shows a bare glyph; "0 process(es) ✓" is noise.

## Decision (owner, 2026-10-30)

Keep full detail. Better formatting only. Do not shrink or collapse the memory/process data.

## Decisions (owner, 2026-10-30, later)

- Clicking the status bar item must not toggle Lints. Today `statusBarItem.command = 'saropaLints.toggleLints'` (extension.ts `renderStatusBar`). Owner wants click to show the tooltip instead. VS Code has no API to open a status bar hover from code; click behavior is Owner chose: click opens a QuickPick menu with the same status, problems and action rows as the tooltip; the toggle is one row in it.
- Use pills wherever possible in the tooltip; each pill has its own hover title.
- Long numbers use thousands separators.

## Layout

Markdown headings, bold labels, tables for aligned numbers, one link per action. Sections in order:

1. **Status** — bold headline, one sentence cause, one fix link `[Fix: turn both on](command:...)`. Toggle link text follows the state (no "Analysis enabled" while partly off).
2. **Project** — table: Version, Tier, Vibrancy, Packages scanned, Lint score, Updates, Action items. Findings as "18,368 findings (all errors)" or "N errors · M warnings".
3. **Problems** — only when present. Bulleted, each names the issue and carries its own link (e.g. "saropa_lints not in pubspec.yaml → Open version compatibility card").
4. **Memory** — table: Saropa Lints (processes, RSS), Flutter daemons (total, orphaned), Other Dart (count, RSS, each named), Extension host (RSS, heap). RSS trend as a sparkline in a code span with a label, omitted when no history. Warning/critical hint as a bold line above the table.
5. **Actions** — links, grouped: toggle · reports (Violations, Package Dashboard, Process Health) · utility (Command Catalog, About).

## Rules

- One diagnosis per state; unify the two "not set up" messages.
- Numbers use thousands separators.
- All strings via `l10n` keys; add keys to every locale file's English fallback only (translation is the owner's pipeline).
- Links stay inside `STATUS_BAR_TRUSTED_COMMANDS`.

## Status

Design only. Implementation not dispatched.
