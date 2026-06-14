# FEATURE: Package Vibrancy — one-time bump nudge for an out-of-date `saropa_dart_utils`

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-14
Area: Package Vibrancy (not a lint rule)
File: `extension/src/vibrancy/` (subsystem); version-gap detection at
`extension/src/vibrancy/providers/sdk-diagnostics.ts`; curated package registry at
`extension/src/vibrancy/data/known_issues.json`
Severity: Feature request (Low) — quality-of-life nudge, no correctness impact
Source: `saropa_dart_utils` Suite Integration plan, requirement R6
(`D:\src\saropa_dart_utils\plans\SAROPA_SUITE_INTEGRATION.md`)

---

## Summary

When a project depends on an out-of-date `saropa_dart_utils`, Package Vibrancy
should surface a single, gated "a newer `saropa_dart_utils` is available — bump it"
nudge. This is the dependency-version mirror of the suite-discovery install nudge
Drift Advisor and Lints already ship (a project that dev-depends on a suite package
but lacks the matching extension is offered the install, once). Today no such
version nudge exists for the suite's own pub packages.

This is the `saropa_dart_utils`-side R6. That package owns no extension and no IDE
surface, so the nudge cannot live there — it rides Package Vibrancy, which already
owns the workspace `pubspec.yaml` scan and a "behind latest" comparison.

---

## Why it belongs in Package Vibrancy (attribution)

Package Vibrancy is a `saropa_lints` extension subsystem, and the version-gap
machinery it would extend already lives here — so the work is "apply an existing
mechanism to one more package," not "build a new capability."

```bash
# Subsystem registration
grep -rn "Package Vibrancy" extension/src/extension.ts
# extension/src/extension.ts:1907: // Package Vibrancy subsystem — registers its own views, commands, and providers

# "Behind latest" version-gap detection already exists (currently SDK/Flutter-scoped)
grep -rn "behind latest\|latestVersion\|up-to-date" extension/src/vibrancy/providers/sdk-diagnostics.ts
# sdk-diagnostics.ts:43: /** Don't show "behind latest" when SDK minimum is already at or above this. */
# sdk-diagnostics.ts:74:  if (!isGreaterThan(latest, min)) { return 'up-to-date'; }

# Curated per-package registry exists (status/replacement/migrationNotes per package)
grep -rn "\"name\"" extension/src/vibrancy/data/known_issues.json | head -3
```

**Current gap:** `saropa_dart_utils` is absent from `known_issues.json`, and the
"behind latest" comparison in `sdk-diagnostics.ts` targets the Dart/Flutter SDK
constraints, not arbitrary pub dependencies. So neither path nudges on a stale
`saropa_dart_utils` today.

```bash
grep -rn "saropa_dart_utils" extension/src/vibrancy/
# (no matches — the package is not tracked by Package Vibrancy)
```

---

## Requested behavior

1. Track `saropa_dart_utils` as a Vibrancy-watched package. When the workspace
   `pubspec.yaml` pins a version older than the latest stable, raise an
   informational nudge: "A newer `saropa_dart_utils` (`<latest>`) is available —
   you are on `<current>`. Bump it."
2. **Gate once** using the existing offered/dismissed pattern (the same gate the
   suite-discovery install nudge uses), keyed per workspace, so it never re-nags
   after the user bumps or dismisses.
3. Only fire when the project actually depends on `saropa_dart_utils` (read from
   `pubspec.yaml`), exactly as the install nudge only fires when the matching
   suite package is present — never on unrelated projects.

Out of scope: no auto-edit of `pubspec.yaml`, no forced upgrade. A nudge with a
"don't show again" affordance, nothing more.

---

## Design notes / open question for the maintainer

- The cleanest reuse depends on which mechanism Vibrancy prefers for the
  "outdated, but healthy" case:
  - **Reuse the "behind latest" comparator** (`sdk-diagnostics.ts`) generalized
    from SDK constraints to a named pub dependency — most direct, but requires a
    source of "latest stable" for the package (pub.dev query or a pinned table).
  - **Extend `known_issues.json`** — but its schema models `end_of_life` /
    deprecated packages with a `replacement`, which `saropa_dart_utils` is NOT.
    A stale-but-healthy package needs a different status (e.g. `outdated`) or a
    separate registry, so this path likely needs a small schema addition.
- Recommendation: generalize the "behind latest" comparator rather than overload
  the end-of-life registry, so a healthy-but-stale package is not mislabeled as a
  known issue. The maintainer owns this call.

---

## Done when

- [ ] A project on an old `saropa_dart_utils` sees exactly one bump nudge.
- [ ] The nudge is gated once (bump or dismiss → never reappears).
- [ ] A project not depending on `saropa_dart_utils` never sees it.
- [ ] No nudge when already on the latest stable.
- [ ] `CHANGELOG.md` (Vibrancy section) records the new watched package.

---

## Environment

- saropa_lints version: 13.12.7 (the version `saropa_dart_utils` dev-depends on)
- Triggering project: any project depending on `saropa_dart_utils`
- Related: `saropa_dart_utils` R1 rule-to-remediation mapping
  (`lib/suite/rule_remediation_map.dart`) and R3 crash-coverage audit
  (`lib/suite/crash_coverage_audit.dart`) — the other built halves of the same plan.
