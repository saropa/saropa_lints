# known_issues.json manual review queue

Generated (regenerated at publish time). Checked 248 lifecycle/business-model entries against live pub.dev (0 network error(s)); 2 appear outgrown by a newer release (12 business-model entries skipped from the outgrown list as verified within the last 183 days).

Each entry needs a human read of the current reason against the package's present state before editing `known_issues.json` — this report does not edit the file.

## HIGH confidence — reason contradicted by current pub.dev data (0)

**Suggested action:** Likely safe to remove or rewrite the reason — same pattern as the 7 entries fixed 2026-08-18.

_None._

## MEDIUM confidence — lifecycle claim, package still releasing (2)

**Suggested action:** Reread the reason against the package's current state; a release doesn't disprove e.g. a specific unfixed bug, but often the underlying complaint has moved on too.

- **`flutter_sticky_header`** (caution) — recorded `2025-05-21`, pub.dev latest `2026-11-03` (v0.11.0). [pub.dev](https://pub.dev/packages/flutter_sticky_header)
  - Current reason: Open issue reports scroll performance lag on recent Flutter versions (letsar/flutter_sticky_header issue 111); the changelog notes no fix.
- **`google_api_availability`** (maintenance_mode) — recorded `2025-02-25`, pub.dev latest `2026-11-05` (v5.1.0). [pub.dev](https://pub.dev/packages/google_api_availability)
  - Current reason: Releases are limited to SDK-constraint and build updates; Android-only since 5.0.0, which removed iOS support.

## LOW confidence — business-model claim, verify terms manually (0)

**Suggested action:** Release cadence is not evidence here — check pricing/license page directly before touching the entry.

_None._
