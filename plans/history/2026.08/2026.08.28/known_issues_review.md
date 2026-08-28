# known_issues.json review — completed 2026-08-28

## Summary

Checked 51 flagged entries (36 MEDIUM, 15 LOW confidence) against live pub.dev data.

**Key finding:** Most MEDIUM-confidence entries were already version-scoped (`appliesToMaxVersion`) — the review script compared `lastUpdated` against pub.dev latest without accounting for version constraints. Those entries are correct and warn only about old package versions.

## Changes made

| Package | Change | Reason |
|---------|--------|--------|
| flutter_calendar_carousel | Added `appliesToMaxVersion: "3.0.0"` | v3.0.0 ground-up rewrite fixed swiping stutter; v2.4.2 added basic Flutter 3 support but didn't fix physics |
| keyboard_actions | Added `appliesToMaxVersion: "4.2.2"` | v5.0.0 architectural rewrite fixed FocusNode flicker; v4.2.2 was the last pre-rewrite release |
| workmanager | `caution` → `active` | v0.10.8+ explicitly fixed Android 16 WorkManager compat |
| flutter_email_sender | `caution` → `active` | FileProvider attachment issues fixed across v2–v10 |
| flutter_vibrate | Added missing `reason`, `end_of_life` → `caution` | Package works but is redundant vs native HapticFeedback |
| better_player | `maintenance_mode` → `active` | Resumed active development with v1.0.0 federated rewrite |

## No change needed (already correct)

**Version-scoped entries** (12): file_picker, flutter_local_notifications (×2), simple_animations, syncfusion_flutter_calendar, flutter_typeahead, chopper, youtube_player_iframe (×2), flutter_map, location, flutter_secure_storage

**Still valid entries** (8): camera, desktop_window, flutter_sms_inbox, flutter_villains, flutter_youtube_view, i18n_extension, safe_device, sembast

**Unclear — left as-is** (10): agora_rtc_engine, animations, audioplayers, badges, flutter_cache_manager, flutter_downloader, flutter_modular, fluttertoast, google_fonts, graphql, shimmer

**LOW confidence (business model) — all 15 confirmed still valid.**

## Finish Report (2026-08-28)

The publish-time review script flagged 51 `known_issues.json` entries as potentially stale by comparing each entry's `lastUpdated` against the package's latest pub.dev release. Investigation revealed most flagged entries already carried `appliesToMaxVersion` constraints scoping them to old package versions — the script did not account for version scoping, producing false positives.

Six entries required actual changes: two lifecycle entries (flutter_calendar_carousel, keyboard_actions) gained version-scope constraints after confirming their issues were fixed in newer major releases; two caution entries (workmanager, flutter_email_sender) were upgraded to active after verifying the cautioned behaviors were explicitly fixed; one entry (flutter_vibrate) had a missing `reason` field filled in and status corrected from end_of_life to caution; one entry (better_player) was updated from stale maintenance_mode to active after confirming resumed development. All 15 business-model entries were confirmed still accurate. Ten lifecycle entries remain unclear and were left as-is pending deeper source-level verification.
