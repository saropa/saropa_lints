# Project Health: Adaptive Huge-Workspace Auto-Defaults

**Severity**: UX polish — large-workspace ergonomics
**Date deferred**: 2026-05-26
**Status**: Deferred — not built; revisit when a real large-workspace user hits unusable defaults
**Parent plan**: [../PROJECT_HEALTH_DASHBOARD_PLAN.md](../PROJECT_HEALTH_DASHBOARD_PLAN.md)

---

## Goal

On extension launch, count workspace files; above a configurable threshold,
auto-enable aggregate-first mode, defer the heaviest sections (git, semantic
dead-code) to explicit user action, and show an explanatory banner so the user
understands why the defaults differ.

Banner copy (from the parent plan):

> Large workspace (48,000 files) — showing folder rollups. Expand to drill in;
> enable git metrics in settings.

## Why it was deferred

The data engine and scaling discipline are already in place: bounded memory,
NDJSON streaming, top-N + folder rollups by default, `--no-git` /
`--no-coverage` / `--no-deadweight` section toggles, and a content-hash cache
for warm rescans. A user on a 50k-file monorepo already has every lever to
get a usable scan; this item only **auto-pulls** those levers based on file
count.

No user has reported hitting unusable defaults on a huge project, so building
the auto-trigger now would be speculative tuning. The thresholds, defaults,
and banner copy should be designed against a real failure case, not invented.

## Trigger to un-defer

- A user reports the dashboard hanging, OOMing, or rendering unusably on a
  large workspace with the current defaults, OR
- A benchmark on a representative monorepo (10k+ Dart files) confirms the
  default mode is meaningfully worse than aggregate-first, AND
- The threshold value can be set from measured behavior rather than guessed.

## Design sketch (when un-deferred)

- Count workspace Dart files in the extension before spawning the CLI scan.
- Above the threshold:
  - Pass flags that select aggregate-first mode (folder rollups, deferred git
    + semantic dead-code, deeper treemap drill-down on demand).
  - Render the banner above the dashboard with: file count, what's deferred,
    and a single-click action to re-run with full metrics.
  - Persist the user's choice ("I want full metrics on this workspace") so the
    banner is offered once, not nagging — gated like the global UX rule
    requires.
- Default-off opt-out setting for users who want the full scan regardless.
- Acceptance: synthetic 50k-file project opens with aggregate-first defaults
  and an explanatory banner; full-metrics re-run is one click; the offer never
  reappears after the user dismisses it; small workspaces (<threshold) see no
  banner and no behavior change.

## Risks

- **Wrong threshold.** Picked from intuition rather than data, it either fires
  for projects that are fine or fails to fire for projects that aren't. The
  un-defer trigger above requires a measured threshold, not a guessed one.
- **Banner fatigue.** Must obey the global "offer once, gate on done /
  dismissed" rule — never re-prompt unsolicited.
- **Silently changing what the user sees.** A scan that hides sections by
  default is dishonest if the user can't tell what's missing. The banner must
  name exactly what was deferred, not vague language like "some metrics".
