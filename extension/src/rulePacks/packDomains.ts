/**
 * Domain taxonomy for ecosystem rule packs — UI grouping only.
 *
 * The pack registry ({@link rulePackDefinitions}) is generated and intentionally
 * carries no domain field: domains are an editorial grouping for the "All
 * packages" section of the Config dashboard, not a property of the rules. Keeping
 * the map here (hand-maintained) rather than in the generated file means a
 * regeneration never clobbers it.
 *
 * SDK migration packs (`dart_sdk_*` / `flutter_sdk_*`) are grouped programmatically
 * via {@link isSdkPackId} into one domain, so they are absent from {@link PACK_DOMAIN_BY_ID}.
 * Any package pack not listed falls back to {@link OTHER_DOMAIN}, so a newly
 * generated pack still appears (in "Other") instead of vanishing — add it here to
 * file it under the right domain.
 */

/** Domain shown for SDK version-migration packs. */
export const SDK_DOMAIN = 'SDK migrations';
/**
 * Domain for platform packs (ios, android, web, …). These are recommended from
 * the project's embedder folders, not a pubspec dependency, so they sort near
 * the top with the curated standards rather than among package domains.
 */
export const PLATFORM_DOMAIN = 'Platforms';
/** Fallback domain for any package pack not yet assigned below. */
export const OTHER_DOMAIN = 'Other';
/**
 * Domain for thematic "quality standard" packs (ui_excellence, localization,
 * documentation, testing) — cross-cutting bars not tied to a package or SDK.
 * Sorts first so these curated standards lead the "All packages" section.
 */
export const QUALITY_DOMAIN = 'Quality standards';

/**
 * Display order for domains in the "All packages" section. Domains absent from a
 * project still render in this order; `SDK migrations` and `Other` sort last so
 * the curated package domains lead.
 */
export const PACK_DOMAIN_ORDER: readonly string[] = [
  QUALITY_DOMAIN,
  PLATFORM_DOMAIN,
  'State management',
  'Networking & APIs',
  'Storage & persistence',
  'Navigation & deep links',
  'Media & graphics',
  'Device & platform',
  'Identity & sharing',
  'Utilities & config',
  SDK_DOMAIN,
  OTHER_DOMAIN,
];

/** Pack id → domain label. Versioned companions (`dio_5`) share their base domain. */
const PACK_DOMAIN_BY_ID: Readonly<Record<string, string>> = {
  // Quality standards (thematic, cross-cutting bars)
  ui_excellence: QUALITY_DOMAIN,
  localization: QUALITY_DOMAIN,
  documentation: QUALITY_DOMAIN,
  testing: QUALITY_DOMAIN,

  // Platform packs (recommended from embedder folders)
  ios: PLATFORM_DOMAIN,
  android: PLATFORM_DOMAIN,
  web: PLATFORM_DOMAIN,
  windows: PLATFORM_DOMAIN,
  macos: PLATFORM_DOMAIN,
  linux: PLATFORM_DOMAIN,

  // State management
  bloc: 'State management',
  bloc_8: 'State management',
  riverpod: 'State management',
  riverpod_2: 'State management',
  riverpod_3: 'State management',
  provider: 'State management',
  getx: 'State management',
  get_it: 'State management',
  flutter_hooks: 'State management',
  rxdart: 'State management',
  equatable: 'State management',

  // Networking & APIs
  dio: 'Networking & APIs',
  dio_5: 'Networking & APIs',
  http: 'Networking & APIs',
  graphql: 'Networking & APIs',
  supabase: 'Networking & APIs',
  firebase: 'Networking & APIs',
  connectivity_plus: 'Networking & APIs',
  connectivity_plus_6: 'Networking & APIs',
  openai: 'Networking & APIs',

  // Storage & persistence
  drift: 'Storage & persistence',
  hive: 'Storage & persistence',
  isar: 'Storage & persistence',
  sqflite: 'Storage & persistence',
  shared_preferences: 'Storage & persistence',

  // Navigation & deep links
  auto_route: 'Navigation & deep links',
  go_router_6: 'Navigation & deep links',
  app_links: 'Navigation & deep links',
  app_links_6: 'Navigation & deep links',
  receive_sharing_intent: 'Navigation & deep links',
  url_launcher: 'Navigation & deep links',
  webview_flutter: 'Navigation & deep links',

  // Media & graphics
  cached_network_image: 'Media & graphics',
  flutter_svg: 'Media & graphics',
  flutter_svg_2: 'Media & graphics',
  lottie: 'Media & graphics',
  flutter_animate: 'Media & graphics',
  audioplayers: 'Media & graphics',
  youtube_player_flutter: 'Media & graphics',
  flutter_map: 'Media & graphics',
  google_maps_flutter: 'Media & graphics',
  image_picker: 'Media & graphics',
  file_picker: 'Media & graphics',
  file_picker_10: 'Media & graphics',
  file_picker_12: 'Media & graphics',
  qr_scanner: 'Media & graphics',
  flame: 'Media & graphics',

  // Device & platform
  geolocator: 'Device & platform',
  geocoding: 'Device & platform',
  sensors_plus: 'Device & platform',
  sensors_plus_4: 'Device & platform',
  device_calendar: 'Device & platform',
  permission_handler: 'Device & platform',
  local_auth: 'Device & platform',
  local_auth_3: 'Device & platform',
  home_widget: 'Device & platform',
  quick_actions: 'Device & platform',
  workmanager: 'Device & platform',
  speech_to_text: 'Device & platform',
  flutter_keyboard_visibility: 'Device & platform',
  awesome_notifications: 'Device & platform',

  // Identity & sharing
  sign_in_with_apple: 'Identity & sharing',
  google_sign_in: 'Identity & sharing',
  google_sign_in_7: 'Identity & sharing',
  share_plus: 'Identity & sharing',
  share_plus_11: 'Identity & sharing',
  in_app_review: 'Identity & sharing',

  // Utilities & config
  uuid: 'Utilities & config',
  envied: 'Utilities & config',
  google_fonts: 'Utilities & config',
  collection_compat: 'Utilities & config',
};

/** True for the Dart/Flutter SDK version-migration packs. */
function isSdkPackId(id: string): boolean {
  return id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_');
}

/**
 * Resolve a pack's display domain. SDK packs collapse into one domain; any
 * unmapped package pack falls back to {@link OTHER_DOMAIN} so nothing is hidden.
 */
export function packDomainForId(id: string): string {
  if (isSdkPackId(id)) return SDK_DOMAIN;
  return PACK_DOMAIN_BY_ID[id] ?? OTHER_DOMAIN;
}
