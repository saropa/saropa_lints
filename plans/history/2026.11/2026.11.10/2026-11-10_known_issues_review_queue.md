# known_issues.json manual review queue

Generated 2026-11-10. Checked 248 lifecycle/business-model entries against live pub.dev (0 network error(s)); 3 appear outgrown by a newer release (11 business-model entries skipped from the outgrown list as verified within the last 183 days).

Each entry needs a human read of the current reason against the package's present state before editing `known_issues.json` — this report does not edit the file.

## HIGH confidence — reason contradicted by current pub.dev data (0)

**Suggested action:** Likely safe to remove or rewrite the reason — same pattern as the 7 entries fixed 2026-08-18.

_None._

## MEDIUM confidence — lifecycle claim, package still releasing (2)

**Suggested action:** Reread the reason against the package's current state; a release doesn't disprove e.g. a specific unfixed bug, but often the underlying complaint has moved on too.

- **`flutter_sticky_header`** (caution) — recorded `2025-05-21`, pub.dev latest `2026-11-03` (v0.11.0). [pub.dev](https://pub.dev/packages/flutter_sticky_header)
  - Current reason: May conflict with Flutter's modern sliver scroll physics; potential jank reported.
- **`google_api_availability`** (maintenance_mode) — recorded `2025-02-25`, pub.dev latest `2026-11-05` (v5.1.0). [pub.dev](https://pub.dev/packages/google_api_availability)
  - Current reason: Obsolete detection methods return false negatives on modern devices.

## LOW confidence — business-model claim, verify terms manually (1)

**Suggested action:** Release cadence is not evidence here — check pricing/license page directly before touching the entry.

- **`blinkid_flutter`** (commercial) — recorded `2026-09-09`, pub.dev latest `2026-11-04` (v8002.0.0). [pub.dev](https://pub.dev/packages/blinkid_flutter)
  - Current reason: Premium, closed-source SDK wrapper. Requires a paid commercial license key from Microblink to function in production.
