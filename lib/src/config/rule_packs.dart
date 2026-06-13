// ignore_for_file: always_specify_types

/// Rule pack ids → rule codes enabled when the pack is listed under
/// `plugins.saropa_lints.rule_packs.enabled` in analysis_options.yaml.
///
/// **Config merge order:** The native plugin loads severity overrides and
/// `diagnostics:` first; then [mergeRulePacksIntoEnabled] merges pack rule codes
/// into [SaropaLintRule.enabledRules]. Codes in [SaropaLintRule.disabledRules]
/// (explicit `false`) are skipped so user opt-out wins over pack opt-in.
///
/// **Semver gates:** Packs listed in [kRulePackDependencyGates] only merge when
/// [mergeRulePacksIntoEnabled] receives a [resolvedVersions] map and the
/// resolved version of [RulePackDependencyGate.dependency] satisfies
/// [RulePackDependencyGate.constraint]. If the lockfile is missing or the
/// dependency is absent, gated packs do not merge (conservative).
///
/// **VS Code / extension:** Regenerate `extension/src/rulePacks/rulePackDefinitions.ts`
/// with `dart run tool/generate_rule_pack_registry.dart` after changing package rules.
///
/// **Maintainers (generated registry):** Rule codes for each package family are emitted
/// into `rule_pack_codes_generated.dart` from `lib/src/rules/packages/*_rules.dart`.
/// A rule that must appear in more than one pack (but lives in a single `*_rules.dart`
/// file) is listed in `kCompositeRulePackIds` in `tool/rule_pack_audit.dart`; the same
/// tool applies that map when auditing. Run `dart run tool/rule_pack_audit.dart` after
/// registry or package-rule edits to catch drift before CI.
///
/// **Overlapping rules across packs:** [mergeRulePacksIntoEnabled] returns
/// only codes newly added to [enabled]. Re-merge subtracts that set before
/// applying the next pack list; if two enabled packs share a rule and it is
/// removed from one pack only, toggling YAML may require an analyzer restart
/// for a correct effective set. Prefer disjoint pack membership.
library;

import 'dart:developer' as developer;

import 'package:pub_semver/pub_semver.dart';

import 'package:saropa_lints/src/config/rule_pack_codes_generated.dart';

/// Optional semver gate: pack merges only when [dependency] resolves to a
/// version allowed by [constraint] (pub semver syntax, e.g. `>=1.19.0`).
class RulePackDependencyGate {
  const RulePackDependencyGate({
    required this.dependency,
    required this.constraint,
  });

  final String dependency;
  final String constraint;
}

/// Optional SDK gate: pack is considered only when the pubspec `environment`
/// constraint for [sdkKey] (e.g. `sdk` or `flutter`) satisfies [constraint].
class RulePackSdkGate {
  const RulePackSdkGate({required this.sdkKey, required this.constraint});

  final String sdkKey;
  final String constraint;
}

/// Packs that require a resolved lockfile version (Phase 3 resolver).
const Map<String, RulePackDependencyGate> kRulePackDependencyGates = {
  // Example semver-gated pack: rules apply only when package `collection`
  // resolves to >=1.19.0 (matches common migration guidance for collection APIs).
  'collection_compat': RulePackDependencyGate(
    dependency: 'collection',
    constraint: '>=1.19.0',
  ),
  // The Notifier / NotifierProvider API (the migration target of
  // prefer_notifier_over_state) only exists in riverpod >= 2.0.0. flutter_riverpod
  // and hooks_riverpod 2.x both resolve riverpod 2.x in the lockfile, so gating on
  // the core `riverpod` version covers every riverpod flavor. On riverpod 1.x the
  // rule is suppressed because its recommended replacement is unavailable.
  'riverpod_2': RulePackDependencyGate(
    dependency: 'riverpod',
    constraint: '>=2.0.0',
  ),
  // dio 5.0.0 removed `DioError` in favor of `DioException`. avoid_dio_error
  // flags the removed type; it is relocated out of the base `dio` pack so a
  // dio 4.x project (where DioError is still valid) never sees it.
  'dio_5': RulePackDependencyGate(dependency: 'dio', constraint: '>=5.0.0'),
  // bloc 8.0.0 removed the `mapEventToState` override in favor of `on<Event>`
  // handlers. avoid_bloc_map_event_to_state is relocated out of the base `bloc`
  // pack so bloc 7.x projects (where the override is valid) never see it.
  'bloc_8': RulePackDependencyGate(dependency: 'bloc', constraint: '>=8.0.0'),
  // riverpod 3.0.0 deprecated StateNotifier/StateNotifierProvider (moved to
  // legacy.dart). avoid_riverpod_state_notifier is relocated out of the base
  // `riverpod` pack so 1.x/2.x projects keep those first-class types.
  'riverpod_3': RulePackDependencyGate(
    dependency: 'riverpod',
    constraint: '>=3.0.0',
  ),
  // go_router 6.0.0 changed the redirect callback signature. The entire
  // go_router_6 pack (its rule file is go_router_6_rules.dart) is a migration
  // pack, so the whole pack is gated rather than relocating a single rule.
  'go_router_6': RulePackDependencyGate(
    dependency: 'go_router',
    constraint: '>=6.0.0',
  ),
  // share_plus 11.0.0 deprecated the static Share.* methods in favor of the
  // instance SharePlus.instance.share(ShareParams(...)) API (still compiles).
  // prefer_shareplus_instance is relocated out of the base share_plus pack.
  'share_plus_11': RulePackDependencyGate(
    dependency: 'share_plus',
    constraint: '>=11.0.0',
  ),
  // sensors_plus 4.0.0 deprecated the bare event-stream getters in favor of the
  // *EventStream() functions (still compiles). prefer_sensors_event_stream is
  // relocated out of the base sensors_plus pack.
  'sensors_plus_4': RulePackDependencyGate(
    dependency: 'sensors_plus',
    constraint: '>=4.0.0',
  ),
  // flutter_svg 2.0.0 deprecated color/colorBlendMode in favor of colorFilter
  // (still compiles). prefer_svg_color_filter is relocated out of the base
  // flutter_svg pack.
  'flutter_svg_2': RulePackDependencyGate(
    dependency: 'flutter_svg',
    constraint: '>=2.0.0',
  ),
  // file_picker 10.0.0 deprecated allowCompression in favor of
  // compressionQuality. Relocated out of the base file_picker pack.
  'file_picker_10': RulePackDependencyGate(
    dependency: 'file_picker',
    constraint: '>=10.0.0',
  ),
  // file_picker 12.0.0 deprecated withData / withReadStream / allowMultiple.
  // Relocated out of the base file_picker pack. The -0 lower bound includes
  // 12.0.0 pre-release builds.
  'file_picker_12': RulePackDependencyGate(
    dependency: 'file_picker',
    constraint: '>=12.0.0-0',
  ),
  // PRE-UPGRADE (`<`) gates — flag valid old-major code that breaks on the bump.
  // The old API is removed in the new major, so on the new version dart analyze
  // already errors and a `>=` pack would find nothing. Gate on the OLD major.
  //
  // connectivity_plus 6.0.0 changed checkConnectivity()/onConnectivityChanged
  // to return List<ConnectivityResult>. Flag single-value handling on 5.x.
  'connectivity_plus_6': RulePackDependencyGate(
    dependency: 'connectivity_plus',
    constraint: '<6.0.0',
  ),
  // google_sign_in 7.0.0 removed the GoogleSignIn() constructor / signIn().
  // Flag the removed v6 API on projects still on 6.x.
  'google_sign_in_7': RulePackDependencyGate(
    dependency: 'google_sign_in',
    constraint: '<7.0.0',
  ),
  // google_sign_in v7 usage-correctness rules reference APIs that only exist on
  // v7 (authenticate, GoogleSignInException, ...). Gate the base pack >= 7.0.0
  // so these never fire on a 6.x project where those symbols do not exist.
  'google_sign_in': RulePackDependencyGate(
    dependency: 'google_sign_in',
    constraint: '>=7.0.0',
  ),
  // webview_flutter 4.0.0 removed the monolithic WebView widget. The whole
  // pack (its single pre-v4 migration rule) is gated < 4.0.0 — flag v3 code
  // that breaks on the v4 bump.
  'webview_flutter': RulePackDependencyGate(
    dependency: 'webview_flutter',
    constraint: '<4.0.0',
  ),
  // local_auth 3.0.0 removed AuthenticationOptions / useErrorDialogs, renamed
  // stickyAuth, and changed the thrown exception type. Flag 2.x code that
  // breaks on the 3.0 bump.
  'local_auth_3': RulePackDependencyGate(
    dependency: 'local_auth',
    constraint: '<3.0.0',
  ),
  // app_links 6.0.0 removed getInitialAppLink / getLatestAppLink and the
  // allUriLinkStream / allStringLinkStream getters. Flag 5.x code that breaks
  // on the 6.0 bump.
  'app_links_6': RulePackDependencyGate(
    dependency: 'app_links',
    constraint: '<6.0.0',
  ),
};

/// Packs that require pubspec `environment` SDK constraints (Phase 6).
const Map<String, RulePackSdkGate> kRulePackSdkGates = {
  // Dart 3.2 js_interop return/signature migrations.
  'dart_sdk_3_2': RulePackSdkGate(sdkKey: 'sdk', constraint: '>=3.2.0'),
  // Dart 3.4 migration surface.
  'dart_sdk_3_4': RulePackSdkGate(sdkKey: 'sdk', constraint: '>=3.4.0'),
  // Flutter 3.0 migration surface.
  'flutter_sdk_3_0': RulePackSdkGate(sdkKey: 'flutter', constraint: '>=3.0.0'),
  // Flutter 3.10 removal migrations.
  'flutter_sdk_3_10': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.10.0',
  ),
  // Flutter 3.16 migration surface.
  'flutter_sdk_3_16': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.16.0',
  ),
  // Flutter 3.18 migration surface.
  'flutter_sdk_3_18': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.18.0',
  ),
  // Flutter 3.19 migration surface (deprecations removed after 3.19).
  'flutter_sdk_3_19': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.19.0',
  ),
  // Flutter 3.22 migration surface.
  'flutter_sdk_3_22': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.22.0',
  ),
  // Flutter 3.7 migration surface.
  'flutter_sdk_3_7': RulePackSdkGate(sdkKey: 'flutter', constraint: '>=3.7.0'),
  // Flutter 3.28 migration surface.
  'flutter_sdk_3_28': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.28.0',
  ),
  // Flutter 3.24 migration surface.
  'flutter_sdk_3_24': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.24.0',
  ),
  // Flutter 3.29 migration surface.
  'flutter_sdk_3_29': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.29.0',
  ),
  // Flutter 3.32 migration surface.
  'flutter_sdk_3_32': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.32.0',
  ),
  // Flutter 3.35 migration surface.
  'flutter_sdk_3_35': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.35.0',
  ),
  // Flutter 3.38 migration surface.
  'flutter_sdk_3_38': RulePackSdkGate(
    sdkKey: 'flutter',
    constraint: '>=3.38.0',
  ),
};

/// Returns true when [packId] has no gate, or [resolvedVersions] satisfies the gate.
bool packPassesDependencyGate(
  String packId,
  Map<String, String>? resolvedVersions,
) {
  final gate = kRulePackDependencyGates[packId];
  if (gate == null) return true;
  if (resolvedVersions == null || resolvedVersions.isEmpty) return false;
  final raw = resolvedVersions[gate.dependency];
  if (raw == null || raw.isEmpty) return false;
  try {
    final version = Version.parse(raw);
    final constraint = VersionConstraint.parse(gate.constraint);
    return constraint.allows(version);
  } on Object catch (e, st) {
    // Fix: avoid_swallowing_exceptions — invalid semver strings disable the
    // gate (treated as not-applicable), but we log for visibility.
    developer.log(
      'matchesRulePackGate: semver parse failed for ${gate.dependency}',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

Version? _parseSdkLowerBoundFromPubspec(
  String pubspecYamlContent,
  String sdkKey,
) {
  final envMatch = RegExp(
    r'^environment:\s*\n((?:[ \t]+.*\n)+)',
    multiLine: true,
  ).firstMatch(pubspecYamlContent);
  if (envMatch == null) return null;
  final envBlock = envMatch.group(1) ?? '';
  final sdkMatch = RegExp(
    '^\\s+${RegExp.escape(sdkKey)}:\\s*[\'"]?([^\'"\\n]+)[\'"]?\\s*\$',
    multiLine: true,
  ).firstMatch(envBlock);
  final rawConstraint = sdkMatch?.group(1)?.trim();
  if (rawConstraint == null ||
      rawConstraint.isEmpty ||
      rawConstraint == 'any') {
    return null;
  }
  final geMatch = RegExp(r'>=\s*(\d+\.\d+\.\d+)').firstMatch(rawConstraint);
  final lower =
      geMatch?.group(1) ??
      (rawConstraint.startsWith('^')
          ? rawConstraint.replaceFirst('^', '').trim()
          : rawConstraint);
  final semver = RegExp(r'^\d+\.\d+\.\d+').firstMatch(lower)?.group(0);
  if (semver == null) return null;
  try {
    return Version.parse(semver);
  } on Object {
    return null;
  }
}

bool packPassesSdkGate(String packId, String pubspecYamlContent) {
  final gate = kRulePackSdkGates[packId];
  if (gate == null) return true;
  final lowerBound = _parseSdkLowerBoundFromPubspec(
    pubspecYamlContent,
    gate.sdkKey,
  );
  if (lowerBound == null) return false;
  try {
    final constraint = VersionConstraint.parse(gate.constraint);
    return constraint.allows(lowerBound);
  } on Object catch (e, st) {
    developer.log(
      'packPassesSdkGate: semver parse failed for ${gate.sdkKey}',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

/// Returns rule codes for [packId], or empty if unknown.
Set<String> ruleCodesForPack(String packId) {
  final codes = kRulePackRuleCodes[packId];
  return codes == null ? <String>{} : Set<String>.from(codes);
}

/// All rule codes owned by any rule pack.
Set<String> allRulePackCodes() {
  final out = <String>{};
  for (final codes in kRulePackRuleCodes.values) {
    out.addAll(codes);
  }
  return out;
}

/// All known pack ids.
Set<String> get knownRulePackIds => kRulePackRuleCodes.keys.toSet();

/// `pubspec.yaml` dependency keys (any line `  name:`) that suggest a pack.
/// Keys match [kRulePackRuleCodes]. Every pack declares at least one marker.
const Map<String, Set<String>> kRulePackPubspecMarkers = {
  ...kRulePackPubspecMarkersGenerated,
  // SDK packs are primarily gated by `environment` constraints.
  'dart_sdk_3_2': {'environment'},
  'dart_sdk_3_4': {'environment'},
  'flutter_sdk_3_0': {'environment'},
  'flutter_sdk_3_10': {'environment'},
  'flutter_sdk_3_16': {'environment'},
  'flutter_sdk_3_18': {'environment'},
  'flutter_sdk_3_19': {'environment'},
  'flutter_sdk_3_22': {'environment'},
  'flutter_sdk_3_7': {'environment'},
  'flutter_sdk_3_28': {'environment'},
  'flutter_sdk_3_24': {'environment'},
  'flutter_sdk_3_29': {'environment'},
  'flutter_sdk_3_32': {'environment'},
  'flutter_sdk_3_35': {'environment'},
  'flutter_sdk_3_38': {'environment'},
  'collection_compat': {'collection'},
};

/// True when [pubspecYamlContent] declares any [kRulePackPubspecMarkers] entry.
bool isRulePackSuggestedByPubspec(String packId, String pubspecYamlContent) {
  // SDK packs are suggested from `environment` constraints instead of dependency markers.
  if (kRulePackSdkGates.containsKey(packId)) {
    return packPassesSdkGate(packId, pubspecYamlContent);
  }
  final markers = kRulePackPubspecMarkers[packId];
  if (markers == null) return false;
  for (final name in markers) {
    // Fix: avoid_missing_interpolation — interpolate the raw-string segments
    // into one literal instead of + concatenation for clarity and consistency.
    final re = RegExp(
      r'^\s+'
      '${RegExp.escape(name)}'
      r'\s*:',
      multiLine: true,
    );
    if (re.hasMatch(pubspecYamlContent)) return true;
  }
  return false;
}

/// Suggested by pubspec and semver gate passes (or pack has no gate).
bool isRulePackApplicable(
  String packId,
  String pubspecYamlContent,
  Map<String, String>? lockVersions,
) {
  if (!isRulePackSuggestedByPubspec(packId, pubspecYamlContent)) return false;
  if (!packPassesSdkGate(packId, pubspecYamlContent)) return false;
  return packPassesDependencyGate(packId, lockVersions);
}

/// Adds rule codes from [packIds] into [enabled], skipping any code whose
/// lowercase name appears in [disabled] (diagnostics/severity disables).
///
/// Skips packs that fail [packPassesDependencyGate] when a gate exists.
///
/// Returns the set of rule codes added from packs (for subtract-before-remerge).
Set<String> mergeRulePacksIntoEnabled(
  Set<String> enabled,
  Set<String>? disabled,
  Iterable<String> packIds, {
  Map<String, String>? resolvedVersions,
}) {
  // Authoritative pack mode: pack-owned rules are removed from tier-derived
  // enables first, then only enabled packs re-add their owned rules.
  enabled.removeAll(allRulePackCodes());

  final contributed = <String>{};
  final disabledLc = <String>{
    for (final d in disabled ?? const <String>{}) d.toLowerCase(),
  };
  for (final packId in packIds) {
    if (!packPassesDependencyGate(packId, resolvedVersions)) continue;
    for (final code in ruleCodesForPack(packId)) {
      if (disabledLc.contains(code.toLowerCase())) continue;
      if (enabled.add(code)) contributed.add(code);
    }
  }
  return contributed;
}

/// Canonical registry: pack id → rule codes (generated from `lib/src/rules/packages/`).
const Map<String, Set<String>> kRulePackRuleCodes = {
  ...kRulePackRuleCodesGenerated,
  'dart_sdk_3_2': {
    'avoid_removed_js_number_to_dart',
    'avoid_legacy_jsboolean_return_assumptions',
    'prefer_string_for_typeof_equals',
    'prefer_int_for_jsarray_with_length',
  },
  'dart_sdk_3_4': {
    'avoid_deprecated_file_system_delete_event_is_directory',
    'avoid_deprecated_list_constructor',
    'avoid_removed_proxy_annotation',
    'avoid_removed_provisional_annotation',
    'avoid_deprecated_expires_getter',
    'avoid_removed_cast_error',
    'avoid_removed_fall_through_error',
    'avoid_removed_abstract_class_instantiation_error',
    'avoid_removed_cyclic_initialization_error',
    'avoid_removed_nosuchmethoderror_default_constructor',
    'avoid_removed_bidirectional_iterator',
    'avoid_removed_deferred_library',
    'avoid_deprecated_has_next_iterator',
    'avoid_removed_max_user_tags_constant',
    'avoid_removed_dart_developer_metrics',
    'avoid_deprecated_network_interface_list_supported',
    'avoid_removed_null_thrown_error',
  },
  'flutter_sdk_3_0': {'avoid_removed_render_object_element_methods'},
  'flutter_sdk_3_7': {
    'avoid_deprecated_use_inherited_media_query',
    'prefer_scrollbar_theme_of',
    'avoid_deprecated_animated_list_typedefs',
  },
  'flutter_sdk_3_10': {
    'avoid_removed_appbar_backwards_compatibility',
    'avoid_deprecated_flutter_test_window',
  },
  'flutter_sdk_3_16': {
    'avoid_deprecated_use_material3_copy_with',
    'prefer_utf8_encode',
  },
  'flutter_sdk_3_18': {'prefer_key_event'},
  'flutter_sdk_3_19': {
    'prefer_platform_menu_bar_child',
    'prefer_keepalive_dispose',
    'prefer_context_menu_builder',
    'prefer_pan_axis',
  },
  'flutter_sdk_3_22': {'prefer_m3_text_theme'},
  'flutter_sdk_3_24': {
    'prefer_overflow_bar_over_button_bar',
    'prefer_iterable_cast',
  },
  'flutter_sdk_3_28': {'prefer_button_style_icon_alignment'},
  'flutter_sdk_3_29': {'avoid_deprecated_on_surface_destroyed'},
  'flutter_sdk_3_32': {
    'prefer_tabbar_theme_indicator_color',
    'prefer_dropdown_menu_item_button_opacity_animation',
  },
  'flutter_sdk_3_35': {
    'prefer_dropdown_initial_value',
    'prefer_on_pop_with_result',
  },
  'flutter_sdk_3_38': {'avoid_asset_manifest_json'},
  'collection_compat': {'avoid_collection_methods_with_unrelated_types'},
};
