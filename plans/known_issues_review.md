# known_issues.json manual review queue

Generated (regenerated at publish time). Checked 302 lifecycle/business-model entries against live pub.dev (13 network error(s)); 49 appear outgrown by a newer release.

Each entry needs a human read of the current reason against the package's present state before editing `known_issues.json` — this report does not edit the file.

## HIGH confidence — reason contradicted by current pub.dev data (0)

**Suggested action:** Likely safe to remove or rewrite the reason — same pattern as the 7 entries fixed 2026-08-18.

_None._

## MEDIUM confidence — lifecycle claim, package still releasing (34)

**Suggested action:** Reread the reason against the package's current state; a release doesn't disprove e.g. a specific unfixed bug, but often the underlying complaint has moved on too.

- **`agora_rtc_engine`** (end_of_life) — recorded `2025-09-16`, pub.dev latest `2026-04-14` (v6.6.3). [pub.dev](https://pub.dev/packages/agora_rtc_engine)
  - Current reason: Agora officially retired these SDK versions; calls will not connect.
- **`animations`** (caution) — recorded `2025-11-14`, pub.dev latest `2026-08-19` (v3.0.0). [pub.dev](https://pub.dev/packages/animations)
  - Current reason: Pre-Material 3 transition API; may lack predictive back gesture support.
- **`audioplayers`** (end_of_life) — recorded `2026-03-01`, pub.dev latest `2026-06-27` (v6.8.1). [pub.dev](https://pub.dev/packages/audioplayers)
  - Current reason: Fails on Apple Silicon builds.
- **`badges`** (end_of_life) — recorded `2023-08-28`, pub.dev latest `2026-04-10` (v3.2.0). [pub.dev](https://pub.dev/packages/badges)
  - Current reason: Positioning logic broken; badges render off-screen in Material 3.
- **`better_player`** (maintenance_mode) — recorded `2024-06-15`, pub.dev latest `2026-08-19` (v0.7.1). [pub.dev](https://pub.dev/packages/better_player)
  - Current reason: 
- **`camera`** (end_of_life) — recorded `2026-02-25`, pub.dev latest `2026-07-13` (v0.12.0+2). [pub.dev](https://pub.dev/packages/camera)
  - Current reason: Fails Android 14 Scoped Storage and iOS 18 hardware manifest requirements.
- **`chopper`** (end_of_life) — recorded `2025-11-25`, pub.dev latest `2026-07-15` (v8.7.0). [pub.dev](https://pub.dev/packages/chopper)
  - Current reason: Code generator fails completely on Dart 3.
- **`desktop_window`** (end_of_life) — recorded `2024-10-29`, pub.dev latest `2026-05-29` (v0.4.4). [pub.dev](https://pub.dev/packages/desktop_window)
  - Current reason: Obsolete since native Flutter desktop size support was added.
- **`file_picker`** (end_of_life) — recorded `2026-01-28`, pub.dev latest `2026-08-14` (v12.0.0). [pub.dev](https://pub.dev/packages/file_picker)
  - Current reason: Returns unreadable cache paths.
- **`flutter_cache_manager`** (end_of_life) — recorded `2024-08-13`, pub.dev latest `2026-07-21` (v3.4.2). [pub.dev](https://pub.dev/packages/flutter_cache_manager)
  - Current reason: Fails to clear disk space, leading to out-of-storage app crashes.
- **`flutter_calendar_carousel`** (end_of_life) — recorded `2025-06-06`, pub.dev latest `2026-08-09` (v3.0.0). [pub.dev](https://pub.dev/packages/flutter_calendar_carousel)
  - Current reason: Swiping physics conflicts with Flutter 3 engine updates, causing stutter.
- **`flutter_email_sender`** (caution) — recorded `2025-09-12`, pub.dev latest `2026-06-15` (v10.0.1). [pub.dev](https://pub.dev/packages/flutter_email_sender)
  - Current reason: File attachment intents may crash due to modern FileProvider security rules.
- **`flutter_local_notifications`** (end_of_life) — recorded `2026-03-05`, pub.dev latest `2026-08-08` (v22.3.0). [pub.dev](https://pub.dev/packages/flutter_local_notifications)
  - Current reason: Ignores Android 14 POST flags.
- **`flutter_local_notifications`** (end_of_life) — recorded `2026-03-05`, pub.dev latest `2026-08-08` (v22.3.0). [pub.dev](https://pub.dev/packages/flutter_local_notifications)
  - Current reason: Fails Android 14 POST_NOTIFICATIONS requirements.
- **`flutter_map`** (end_of_life) — recorded `2025-09-19`, pub.dev latest `2026-06-30` (v8.3.1). [pub.dev](https://pub.dev/packages/flutter_map)
  - Current reason: Leaflet core fundamentally broken; maps render as gray squares.
- **`flutter_modular`** (end_of_life) — recorded `2025-06-12`, pub.dev latest `2026-06-24` (v7.1.0). [pub.dev](https://pub.dev/packages/flutter_modular)
  - Current reason: Global singletons block Dart 3 compilation; deeply flawed memory management.
- **`flutter_secure_storage`** (end_of_life) — recorded `2025-12-10`, pub.dev latest `2026-08-06` (v11.0.0). [pub.dev](https://pub.dev/packages/flutter_secure_storage)
  - Current reason: (Pre-v5.0) Keychain/Keystore logic is old; data can be wiped on OS upgrades.
- **`flutter_sms_inbox`** (end_of_life) — recorded `2025-04-04`, pub.dev latest `2026-05-25` (v1.0.5). [pub.dev](https://pub.dev/packages/flutter_sms_inbox)
  - Current reason: Google Play Store explicitly bans apps using this broad SMS read permission.
- **`flutter_typeahead`** (end_of_life) — recorded `2024-02-08`, pub.dev latest `2026-04-04` (v6.0.0). [pub.dev](https://pub.dev/packages/flutter_typeahead)
  - Current reason: Overlay floats behind keyboards on modern Android 14 inset architectures.
- **`flutter_vibrate`** (end_of_life) — recorded `2016-04-20`, pub.dev latest `2026-01-14` (v1.4.0). [pub.dev](https://pub.dev/packages/flutter_vibrate)
  - Current reason: 
- **`flutter_villains`** (end_of_life) — recorded `2016-04-20`, pub.dev latest `2022-08-26` (v2.0.0). [pub.dev](https://pub.dev/packages/flutter_villains)
  - Current reason: Uses highly deprecated page transition math; causes blank screens on push.
- **`flutter_youtube_view`** (end_of_life) — recorded `2020-07-18`, pub.dev latest `2022-05-20` (v2.0.4). [pub.dev](https://pub.dev/packages/flutter_youtube_view)
  - Current reason: YouTube changed their iframe API policies; videos refuse to play.
- **`fluttertoast`** (end_of_life) — recorded `2025-09-21`, pub.dev latest `2026-07-31` (v10.0.0). [pub.dev](https://pub.dev/packages/fluttertoast)
  - Current reason: Uses deprecated overlay APIs causing context leaks and app freezes.
- **`google_fonts`** (end_of_life) — recorded `2026-02-18`, pub.dev latest `2026-07-31` (v8.2.1). [pub.dev](https://pub.dev/packages/google_fonts)
  - Current reason: Dynamic fetching blocks the main UI thread during load.
- **`graphql`** (end_of_life) — recorded `2025-10-21`, pub.dev latest `2026-03-14` (v5.2.4). [pub.dev](https://pub.dev/packages/graphql)
  - Current reason: Fails to compile on modern Flutter SDKs.
- **`i18n_extension`** (end_of_life) — recorded `2025-11-01`, pub.dev latest `2026-05-21` (v15.1.1). [pub.dev](https://pub.dev/packages/i18n_extension)
  - Current reason: String extension injections leak memory wildly on large translation sets.
- **`keyboard_actions`** (end_of_life) — recorded `2025-11-14`, pub.dev latest `2026-08-10` (v5.0.2). [pub.dev](https://pub.dev/packages/keyboard_actions)
  - Current reason: FocusNode conflicts cause the keyboard to continuously flicker open and closed.
- **`location`** (end_of_life) — recorded `2025-06-18`, pub.dev latest `2026-07-23` (v10.0.2). [pub.dev](https://pub.dev/packages/location)
  - Current reason: Fails Android 14 exact vs approximate location prompt requirements.
- **`safe_device`** (end_of_life) — recorded `2025-10-15`, pub.dev latest `2026-07-07` (v1.4.1). [pub.dev](https://pub.dev/packages/safe_device)
  - Current reason: Flagged physical Samsung/Pixel devices as emulators due to outdated hardware lists.
- **`sembast`** (end_of_life) — recorded `2025-12-17`, pub.dev latest `2026-06-26` (v3.8.9+1). [pub.dev](https://pub.dev/packages/sembast)
  - Current reason: Synchronous writes freeze the UI thread on modern devices.
- **`simple_animations`** (end_of_life) — recorded `2025-05-03`, pub.dev latest `2026-05-23` (v5.3.0). [pub.dev](https://pub.dev/packages/simple_animations)
  - Current reason: Stateless animation logic is fundamentally incompatible with Dart 3 type safety.
- **`syncfusion_flutter_calendar`** (end_of_life) — recorded `2026-03-10`, pub.dev latest `2026-08-18` (v34.2.4). [pub.dev](https://pub.dev/packages/syncfusion_flutter_calendar)
  - Current reason: Legacy commercial package; completely fails Dart 3 type checks.
- **`workmanager`** (caution) — recorded `2025-08-31`, pub.dev latest `2026-08-20` (v0.10.9). [pub.dev](https://pub.dev/packages/workmanager)
  - Current reason: May have compatibility issues with modern Android WorkManager architecture.
- **`youtube_player_iframe`** (end_of_life) — recorded `2025-08-07`, pub.dev latest `2026-05-30` (v6.0.2). [pub.dev](https://pub.dev/packages/youtube_player_iframe)
  - Current reason: YouTube blocked the old Web API; iframe renders a black screen.

## LOW confidence — business-model claim, verify terms manually (15)

**Suggested action:** Release cadence is not evidence here — check pricing/license page directly before touching the entry.

- **`agora_rtc_engine`** (freemium) — recorded `2025-09-16`, pub.dev latest `2026-04-14` (v6.6.3). [pub.dev](https://pub.dev/packages/agora_rtc_engine)
  - Current reason: Hooks into Agora's proprietary video/audio routing cloud. They offer 10,000 free minutes a month, but scaling a social or calling app on this will quickly result in massive monthly server bills.
- **`appsflyer_sdk`** (enterprise) — recorded `2025-12-30`, pub.dev latest `2026-07-27` (v6.18.1). [pub.dev](https://pub.dev/packages/appsflyer_sdk)
  - Current reason: Strictly commercial mobile attribution platform. Used for deep-linking and ad-spend tracking, but their pricing tiers are famously opaque and geared strictly toward enterprise budgets.
- **`blinkid_flutter`** (commercial) — recorded `2025-11-21`, pub.dev latest `2026-06-12` (v8000.0.0). [pub.dev](https://pub.dev/packages/blinkid_flutter)
  - Current reason: Premium, closed-source SDK wrapper. Requires a paid commercial license key from Microblink to function in production.
- **`cometchat_chat_uikit`** (paid) — recorded `2026-02-27`, pub.dev latest `2026-07-24` (v6.1.0). [pub.dev](https://pub.dev/packages/cometchat_chat_uikit)
  - Current reason: Another heavy Chat BaaS (Backend-as-a-Service). Trial-ware that demands an expensive monthly subscription for basic features like push notifications and media sharing.
- **`dart_code_metrics_annotations`** (freemium) — recorded `2025-07-04`, pub.dev latest `2026-08-18` (v1.2.0). [pub.dev](https://pub.dev/packages/dart_code_metrics_annotations)
  - Current reason: Hooks the codebase directly into a commercial, vendor-locked ecosystem (dcm.dev). Actual trial-ware / pay to play.
- **`datadog_flutter_plugin`** (paid) — recorded `2026-02-19`, pub.dev latest `2026-08-17` (v3.5.0). [pub.dev](https://pub.dev/packages/datadog_flutter_plugin)
  - Current reason: Enterprise observability and Application Performance Monitoring (APM). No permanent free tier; you pay heavily per millions of sessions logged.
- **`flutter_uxcam`** (freemium) — recorded `2026-02-27`, pub.dev latest `2026-08-14` (v2.9.1). [pub.dev](https://pub.dev/packages/flutter_uxcam)
  - Current reason: Session recording and heat-mapping tool. Generous free tier, but the cost scales incredibly steeply once you have a moderate user base.
- **`mapbox_maps_flutter`** (freemium) — recorded `2026-02-26`, pub.dev latest `2026-08-20` (v2.28.4). [pub.dev](https://pub.dev/packages/mapbox_maps_flutter)
  - Current reason: Requires an active billing account and credit card to even generate the necessary public tokens. Charges per map-load/API request after you exceed their free tier.
- **`purchases_flutter`** (freemium) — recorded `2026-03-05`, pub.dev latest `2026-08-19` (v10.9.1). [pub.dev](https://pub.dev/packages/purchases_flutter)
  - Current reason: RevenueCat's proprietary wrapper. Free up to a specific monthly revenue limit, after which they take a percentage cut of your app's earnings.
- **`scanbot_sdk`** (paid) — recorded `2025-11-03`, pub.dev latest `2026-07-22` (v9.0.1). [pub.dev](https://pub.dev/packages/scanbot_sdk)
  - Current reason: Strictly commercial enterprise SDK. Cannot be used in production without purchasing a highly expensive yearly corporate license from Scanbot.
- **`sendbird_chat_sdk`** (commercial) — recorded `2026-02-12`, pub.dev latest `2026-03-27` (v4.10.0). [pub.dev](https://pub.dev/packages/sendbird_chat_sdk)
  - Current reason: A heavy, proprietary Chat-as-a-Service SDK. Their free tier is heavily crippled (limits on MAUs and concurrent connections), forcing a rapid upgrade to very expensive paid tiers.
- **`stream_chat_flutter`** (freemium) — recorded `2026-01-28`, pub.dev latest `2026-08-14` (v10.3.0). [pub.dev](https://pub.dev/packages/stream_chat_flutter)
  - Current reason: Proprietary Chat-as-a-Service SaaS. While it has a startup tier, it is a heavily vendor-locked enterprise product that scales aggressively in cost.
- **`superwallkit_flutter`** (freemium) — recorded `2026-02-23`, pub.dev latest `2026-04-15` (v2.4.12). [pub.dev](https://pub.dev/packages/superwallkit_flutter)
  - Current reason: A paywall-as-a-service provider. Like RevenueCat, they inject themselves into your monetization flow and take a cut or charge a flat SaaS fee to manage your subscription UI.
- **`syncfusion_flutter_core`** (commercial_trap) — recorded `2026-03-10`, pub.dev latest `2026-08-18` (v34.2.4). [pub.dev](https://pub.dev/packages/syncfusion_flutter_core)
  - Current reason: Syncfusion offers a 'Community License', but it is a legal trap. The moment your company hits $1M USD in gross revenue OR has more than 5 developers, you are legally required to buy their enterprise licenses.
- **`zego_uikit_prebuilt_call`** (freemium) — recorded `2026-02-03`, pub.dev latest `2026-08-12` (v4.24.4). [pub.dev](https://pub.dev/packages/zego_uikit_prebuilt_call)
  - Current reason: Hooks the app into ZEGOCLOUD's proprietary infrastructure. Shifts from free-tier to a pay-as-you-go commercial model at scale.
