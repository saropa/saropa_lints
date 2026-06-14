# FEATURE: Package Vibrancy — one-time dismissible nudge to bump an out-of-date `saropa_dart_utils`

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-14
Updated: 2026-06-14 (re-scoped — detection already exists; only the nudge is missing)
Area: Package Vibrancy (not a lint rule)
File: `extension/src/vibrancy/` (subsystem)
Severity: Feature request (Low) — quality-of-life nudge, no correctness impact
Source: `saropa_dart_utils` Suite Integration plan, requirement R6
(`D:\src\saropa_dart_utils\plans\SAROPA_SUITE_INTEGRATION.md`)

---

## Summary

When a project depends on an out-of-date `saropa_dart_utils`, Package Vibrancy
should show a single, dismissible "a newer `saropa_dart_utils` is available — bump
it" message, gated so it never re-nags after the user bumps or dismisses it.

This is the dependency-version mirror of the suite-discovery install nudge Drift
Advisor and Lints already ship (a project that dev-depends on a suite package but
lacks the matching extension is offered the install, once).

---

## What already exists (do NOT rebuild)

Package Vibrancy already **detects** out-of-date dependencies, including
`saropa_dart_utils` — it is a normal pub dependency and is already scanned:

- `services/pub-outdated.ts` runs `dart pub outdated --json` across every
  dependency, capturing `current` vs `latest`.
- `scoring/status-classifier.ts` (`isUpdatable`) flags any package with a newer
  version available, feeding the status-bar count and the package-tree
  "update available" badge.
- `services/freshness-watcher.ts` polls pub.dev and raises a "new version" toast.

So a project on a stale `saropa_dart_utils` **already sees it surfaced** as
updatable. This feature does NOT need new detection, does NOT need to generalize
the SDK-constraint comparator in `providers/sdk-diagnostics.ts`, and does NOT
belong in `data/known_issues.json` (that registry is for end-of-life / deprecated
packages — `saropa_dart_utils` is healthy, just behind).

---

## The only missing piece

The existing surfacing is **passive**: a badge in a list and a generic freshness
toast covering all packages at once. There is no **targeted, one-time, dismissible
prompt** specifically inviting the user to bump `saropa_dart_utils`, gated so it
fires once per workspace and never reappears.

That gated nudge — built on top of the update signal Vibrancy already computes —
is the whole of this request.

---

## Requested behavior

1. When the existing scan reports `saropa_dart_utils` as updatable (current < latest),
   raise an informational nudge: "A newer `saropa_dart_utils` (`<latest>`) is
   available — you are on `<current>`. Bump it." Read `current`/`latest` from the
   update info already on the scan result; do not add a new version lookup.
2. **Gate once** using the existing offered/dismissed pattern (the same gate the
   suite-discovery install nudge uses), keyed per workspace, so it never re-nags
   after the user bumps or dismisses.
3. Only fire when the project actually depends on `saropa_dart_utils` — which the
   existing scan already determines, since it only scans declared dependencies.

Out of scope: no auto-edit of `pubspec.yaml`, no forced upgrade, no new detection
logic. A dismissible nudge with a "don't show again" affordance, nothing more.

---

## Done when

- [ ] A project on an old `saropa_dart_utils` sees exactly one bump nudge.
- [ ] The nudge is gated once (bump or dismiss → never reappears).
- [ ] A project not depending on `saropa_dart_utils` never sees it.
- [ ] No nudge when already on the latest stable.
- [ ] The nudge reuses the existing update signal (no new pub.dev lookup added).
- [ ] `CHANGELOG.md` (Vibrancy section) records the new nudge.

---

## Environment

- saropa_lints version: 13.12.7 (the version `saropa_dart_utils` dev-depends on)
- Triggering project: any project depending on `saropa_dart_utils`
- Related: `saropa_dart_utils` R1 rule-to-remediation mapping
  (`lib/suite/rule_remediation_map.dart`) and R3 crash-coverage audit
  (`lib/suite/crash_coverage_audit.dart`) — the other built halves of the same plan.
