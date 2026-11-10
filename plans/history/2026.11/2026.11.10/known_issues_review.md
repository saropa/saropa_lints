# known_issues.json review — business-model entries, 2026-11-10

## Summary

The publish-time queue (`plans/known_issues_review.md`) flagged 11 LOW-confidence business-model entries because each package had a newer pub.dev release. A release is not evidence against a pricing claim, so each entry was checked against the vendor's official pricing or license page.

**Verdict:** all 11 reasons need a rewrite. None should be removed. Two have a status that no longer fits (`appsflyer_sdk`, `cometchat_chat_uikit`), and two more have a debatable status (`syncfusion_flutter_core`, `datadog_flutter_plugin`). Most reasons also carry opinion stated as fact ("famously opaque", "legal trap", "highly expensive", "scales aggressively"). The rewrites were applied per the owner decisions below.

**Recurring noise:** the report re-flags every business-model entry whenever the package publishes any release (`_known_issues_review_report.py` line 93 sends all non-lifecycle statuses to LOW, and the outgrown test compares only `lastUpdated`). The entry's `as_of` verification date is ignored, so confirmed entries return at every publish. The August review confirmed 15 such entries, and most of these 11 came back.

## Per-entry findings

| Package | Status now | Verdict | Corrected fact (source) |
|---|---|---|---|
| appsflyer_sdk | enterprise | Rewrite; status → freemium | Free Zero tier (12,000 conversions in year one), Growth pay-as-you-go at $0.07 per conversion, Enterprise custom. Prices are public. (appsflyer.com/pricing) |
| cometchat_chat_uikit | paid | Rewrite; status → freemium | Free-forever Build plan up to 100 users, including push and media sharing. Basic $239/mo, Advanced $359/mo (annual). (cometchat.com/pricing) |
| datadog_flutter_plugin | paid | Rewrite (scope to RUM) | Account-level free plan exists (5 hosts) but covers infrastructure only. Mobile RUM is paid per session with no free allowance found. Per-session rate unconfirmed. (datadoghq.com/pricing) |
| flutter_uxcam | freemium | Minor rewrite | Vendor page shows only a free trial and session-based custom quotes. A free plan is reported by third parties with conflicting caps (3,000 vs 10,000 sessions). (uxcam.com/pricing) |
| mapbox_maps_flutter | freemium | Rewrite | Mobile SDKs are free to 25,000 MAU, then $4.00 per 1,000 MAU (falling with volume). Billing is per MAU, not per map load. Card-free sign-up gives a limited token; a card is needed for full free tier and production. (mapbox.com/pricing, docs.mapbox.com/accounts/guides/signup) |
| purchases_flutter | freemium | Rewrite | Free up to $2,500 monthly tracked revenue, then 1% of tracked revenue. (revenuecat.com/pricing) |
| scanbot_sdk | paid | Minor rewrite | Annual license, custom quote from about $2,500. Not free for production. 7-day trial. (scanbot.io/pricing) |
| stream_chat_flutter | freemium | Rewrite | Free plan to 1,000 MAU, free Maker plan for teams under 5 people and $10k monthly revenue. Paid from $399/mo (annual). (getstream.io/chat/pricing) |
| superwallkit_flutter | freemium | Rewrite | Free up to $10k/mo in paywall-attributed revenue, then 1% of that revenue. No flat fee. (superwall.com/pricing) |
| syncfusion_flutter_core | commercial_trap | Rewrite; status debatable | Community License requires ALL of: under $1M annual gross revenue, 5 or fewer developers, 10 or fewer employees, never over $3M outside capital. The entry says "OR" and omits two limits. (syncfusion.com/products/communitylicense) |
| zego_uikit_prebuilt_call | freemium | Minor rewrite | One-time 10,000 free minutes at sign-up, then video $3.99 and voice $0.99 per 1,000 participant minutes. (zegocloud.com/pricing) |

**Replacements:** none of the suggested replacements is discontinued. Several are loose fits, not like-for-like: `firebase_analytics` for attribution, `flutter_webrtc` for a hosted call UI kit, and "Custom WebSockets / Firebase RTDB" for chat.

## Owner decisions

1. **Rewrite all 11 entries** (owner, 2026-11-10; recommended option). Correct facts per the table, remove opinion wording, change `appsflyer_sdk` enterprise → freemium and `cometchat_chat_uikit` paid → freemium. Keep `syncfusion_flutter_core` as `commercial_trap` and `datadog_flutter_plugin` as `paid`. Set `as_of` to 2026-11-10.
2. **Report skips business-model entries verified under 6 months ago** (owner, 2026-11-10; recommended option). A LOW-tier (business-model) entry whose `as_of` is less than 6 months before the run date is not listed. Lifecycle entries are unchanged.
3. **The skip uses a new human-only date, `reasonVerified`, not `as_of`** (owner, 2026-11-10; recommended option). Reason: review found `scripts/dev/pubdev_snapshot.py` refreshes `as_of` on every entry with an ok pub.dev snapshot, without anyone reading the reason, so an `as_of` gate would hide unchecked claims (AppsFlyer's wrong claim carried a September `as_of`). `reasonVerified` is optional, set only after a person checks the reason, and never written by scripts. The 11 entries above get `reasonVerified: 2026-11-10`.

## Review notes

- Kept: the `appsflyer_sdk` migrationNotes change (it recommended Firebase Dynamic Links, which Google shut down in 2025).
- Out of scope, left as is: opinion wording in `migrationNotes` of other fields ("Massive rewrite") and the `commercial_trap` label (owner chose to keep it).
