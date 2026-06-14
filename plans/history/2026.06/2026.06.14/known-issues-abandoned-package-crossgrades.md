# Known-issues dataset: abandoned-package cross-grade expansion

The Package Vibrancy scanner flags abandoned dependencies and offers a one-click
"Replace with X" pubspec fix, driven entirely by the curated
`extension/src/vibrancy/data/known_issues.json` dataset. That dataset lagged the
real population of dead-with-a-successor packages on pub.dev: the Flutter Community
`_plus` set had a remaining gap, the Community Edition database forks were only
partially represented, and dozens of packages that pub.dev itself marks
"Discontinued — replaced by X" had no entry, so projects depending on them saw no
nudge toward the maintained fork.

## Finish Report (2026-06-14)

### Scope

(B) VS Code extension data (`extension/src/vibrancy/data/known_issues.json`) and
(C) docs (`CHANGELOG.md`). No Dart lint rules, no analyzer-plugin code, and no
extension TypeScript logic changed. The replacement pipeline
(`findKnownIssue` → `VibrancyCodeActionProvider`) was already data-driven, so the
change is purely additional dataset rows.

### What changed

Forty new cross-grade entries were added to the known-issues dataset (count rose
from 464 to 504 across two passes):

**First pass — Community Edition / Plus completion (5 entries):**
- `wifi_info_flutter` → `network_info_plus` (closes the last Flutter Community Plus gap)
- `isar` → `isar_community` (previously pointed at `drift`, a full rewrite; the CE
  fork is a near-drop-in v3 continuation, mirroring the existing `hive` → `hive_ce`)
- `isar_flutter_libs` → `isar_community_flutter_libs` (native-libs companion)
- `hive_flutter` → `hive_ce_flutter` (was `status: active` with no successor)

**Second pass — broad abandoned-package sweep (35 entries):**
- Twelve packages pub.dev officially marks discontinued with an exact `replacedBy`
  pointer: the seven AngularDart packages → `ng*`, `super_enum` → `freezed`,
  `uni_links` → `app_links`, `artemis` → `ferry`,
  `pusher_client_fixed` → `pusher_client_socket`, `advance_pdf_viewer` → `pdfx`.
- Five officially discontinued with no pointer, given a researched successor or
  freeform guidance: `flutter_statusbarcolor` → `flutter_statusbarcolor_ns`,
  `firebase_dynamic_links` → `app_links` (service shut down 2025-08-25),
  `flutter_geofence` (no successor), `inject`, `observable`.
- Eighteen not formally flagged but verified three-to-seven-years stale, marked
  `end_of_life` when six-plus years or known not to build on current toolchains,
  else `caution`: e.g. `flutter_web_auth` → `flutter_web_auth_2`,
  `pdf_render` → `pdfrx`, `native_pdf_view` → `pdfx`,
  `nfc_in_flutter` → `nfc_manager`, `wifi` → `wifi_iot`,
  `esys_flutter_share` → `share_plus`, `toast` → `fluttertoast`,
  `gallery_saver` → `image_gallery_saver`, `dbcrypt` → `bcrypt`,
  `get_it_mixin` → `watch_it`.

Of the 35 second-pass entries, 31 carry a replacement that satisfies the
`isReplacementPackageName` rule (`^[a-z0-9_]+$`) and therefore surface a one-click
"Replace with X" pubspec quick-fix; three are freeform advice (framework built-ins
or multi-package guidance) shown as text; one (`flutter_geofence`) has a null
replacement and flags the package without offering a swap.

### Verification

- Every old package and every replacement target was checked against the pub.dev
  API (`/api/packages/<name>`) for existence, last-published date, and the
  authoritative `isDiscontinued` / `replacedBy` flags. All 40 replacement targets
  resolve to live packages, so no entry can write a non-existent dependency into a
  user's pubspec. Each entry's `lastUpdated` is the real published date from that
  check.
- Dataset invariants enforced by `known-issues.test.ts` were validated: JSON
  parses, 504 entries, no duplicate name+version tuples, no self-replacements,
  every entry with a replacement carries `migrationNotes`.
- `npm run check-types` (tsc `--noEmit`) passes with exit 0.
- Targeted test run of the known-issues registry plus its consumers
  (`known-issues.test.js`, `known-issues-html.test.js`,
  `code-action-provider.test.js`, `hover-provider.test.js`, `tree-items.test.js`,
  `detail-view-html.test.js`, `diagnostics.test.js`): 125 passing, 0 failing.
- No existing test pinned any of the values changed (the `isar` → `drift` mapping
  and the `hive_flutter` `active` status had no test assertions; the known-issues
  tests exercise unrelated packages).

### Notes

- The `isar` entry's replacement was repointed from `drift` to `isar_community`
  because recommending a full SQLite rewrite over a maintained drop-in fork is the
  weaker guidance; the drift/realm rewrite path is preserved in the migration
  notes, matching the existing `hive` → `hive_ce` precedent.
- The pub.dev `replacedBy` field is a mineable source — a periodic script could
  enumerate discontinued packages and propose new dataset rows automatically. That
  is a separate build and was not undertaken here.

### Disposition

No bug or plan file describes this dataset work; this report is the durable record.
The dataset edits and the CHANGELOG entry were committed (bundled into commit
`6ebbd5cc` on `main`); this report is committed separately.
