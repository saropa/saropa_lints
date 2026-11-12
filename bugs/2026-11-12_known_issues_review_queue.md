# known_issues.json manual review queue

Generated (regenerated at publish time). Checked 248 lifecycle/business-model entries against live pub.dev (0 network error(s)); 1 appear outgrown by a newer release (14 entries skipped because a person already verified their reason recently or since the latest release).

Each entry needs a human read of the current reason against the package's present state before editing `known_issues.json` — this report does not edit the file.

## HIGH confidence — reason contradicted by current pub.dev data (0)

**Suggested action:** Likely safe to remove or rewrite the reason — same pattern as the 7 entries fixed 2026-08-18.

_None._

## MEDIUM confidence — lifecycle claim, package still releasing (0)

**Suggested action:** Reread the reason against the package's current state; a release doesn't disprove e.g. a specific unfixed bug, but often the underlying complaint has moved on too.

_None._

## LOW confidence — business-model claim, verify terms manually (1)

**Suggested action:** Release cadence is not evidence here — check pricing/license page directly before touching the entry.

- **`sendbird_chat_sdk`** (commercial) — recorded `2026-09-10`, pub.dev latest `2026-11-11` (v4.10.5). [pub.dev](https://pub.dev/packages/sendbird_chat_sdk)
  - Current reason: A heavy, proprietary Chat-as-a-Service SDK. Their free tier is heavily crippled (limits on MAUs and concurrent connections), forcing a rapid upgrade to very expensive paid tiers.
