#!/usr/bin/env dart
// CLI tool — print() is the standard mechanism for command-line output; both
// the SDK rule (avoid_print) and the saropa_lints v3 rule (avoid_print_in_release)
// fire here as false positives because this script never runs in a release app.
// ignore_for_file: avoid_print, avoid_print_in_release

/// **Rule pack registry audit** — verifies that every `LintCode` name under
/// `lib/src/rules/packages/*_rules.dart` is reflected in the merged
/// [kRulePackRuleCodes] map from `package:saropa_lints/src/config/rule_packs.dart`.
///
/// **Why this exists:** `kRulePackRuleCodes` is mostly codegen (`rule_pack_codes_generated.dart`)
/// plus manual merges (`collection_compat`). Without a check, package rules can ship without
/// being reachable via `rule_packs.enabled`.
///
/// **Composite packs:** Some codes are declared in one file (e.g. `drift_rules.dart`) but
/// must be enabled with multiple pack ids. [kCompositeRulePackIds] adds those codes to the
/// extracted set for each listed pack before comparison — keep this in sync with
/// `tool/generate_rule_pack_registry.dart`, which calls [applyCompositeRulePacks] the same way.
///
/// **Usage:** From repo root: `dart run tool/rule_pack_audit.dart`
/// **`--emit-dart`** — print a sorted map snippet for emergency copy-paste (prefer the generator).
library;

import 'dart:io';

import 'package:saropa_lints/src/config/rule_packs.dart';
import '../lib/src/string_slice_utils.dart';

final RegExp _lintCodeName = RegExp(
  r"LintCode\s*\(\s*'([a-z0-9_]+)'",
  multiLine: true,
);

/// Rules that belong to multiple packs (defined in one `*_rules.dart` file only).
const Map<String, List<String>> kCompositeRulePackIds = {
  'avoid_isar_import_with_drift': ['drift', 'isar'],
};

/// Returns a new map with composite-pack codes layered on top of [extracted].
///
/// Returns rather than mutates so callers keep the input map intact (avoids
/// the avoid_parameter_mutation lint and makes the dataflow obvious at the
/// call site: `final result = applyCompositeRulePacks(extracted);`).
Map<String, Set<String>> applyCompositeRulePacks(
  Map<String, Set<String>> extracted,
) {
  final result = {
    for (final entry in extracted.entries)
      entry.key: Set<String>.from(entry.value),
  };
  for (final entry in kCompositeRulePackIds.entries) {
    final rule = entry.key;
    for (final pack in entry.value) {
      result.putIfAbsent(pack, () => <String>{}).add(rule);
    }
  }
  return result;
}

/// Rules RELOCATED out of their file-derived pack into a semver-gated pack.
///
/// A version-gated migration must NOT ship in the ungated base pack, or the
/// gate is meaningless: enabling the base pack would re-add the rule regardless
/// of version. Example: `Notifier` / `NotifierProvider` only exist in
/// riverpod >= 2.0.0, so `prefer_notifier_over_state` belongs only in the gated
/// `riverpod_2` pack — a riverpod 1.x project must never be told to adopt an API
/// that does not exist there. Unlike [kCompositeRulePackIds] (which adds a code
/// to extra packs), this MOVES the code so the source pack no longer owns it.
const Map<String, ({String fromPack, String toPack})>
kRelocatedRulePackCodes = {
  'prefer_notifier_over_state': (fromPack: 'riverpod', toPack: 'riverpod_2'),
  // dio 5.0 removed DioError → DioException; gated to the dio_5 pack.
  'avoid_dio_error': (fromPack: 'dio', toPack: 'dio_5'),
  // bloc 8.0 removed mapEventToState → on<Event>; gated to the bloc_8 pack.
  'avoid_bloc_map_event_to_state': (fromPack: 'bloc', toPack: 'bloc_8'),
  // riverpod 3.0 deprecated StateNotifier(Provider); gated to riverpod_3.
  'avoid_riverpod_state_notifier': (fromPack: 'riverpod', toPack: 'riverpod_3'),
  // share_plus 11.0 deprecated static Share.* → SharePlus.instance.share.
  'prefer_shareplus_instance': (
    fromPack: 'share_plus',
    toPack: 'share_plus_11',
  ),
  // sensors_plus 4.0 deprecated the bare event-stream getters → *EventStream().
  'prefer_sensors_event_stream': (
    fromPack: 'sensors_plus',
    toPack: 'sensors_plus_4',
  ),
  // flutter_svg 2.0 deprecated color/colorBlendMode → colorFilter.
  'prefer_svg_color_filter': (fromPack: 'flutter_svg', toPack: 'flutter_svg_2'),
  // file_picker 10.0 deprecated allowCompression → compressionQuality.
  'file_picker_deprecated_allow_compression': (
    fromPack: 'file_picker',
    toPack: 'file_picker_10',
  ),
  // file_picker 12.0 deprecated withData / withReadStream / allowMultiple.
  'file_picker_deprecated_with_data': (
    fromPack: 'file_picker',
    toPack: 'file_picker_12',
  ),
  'file_picker_deprecated_with_read_stream': (
    fromPack: 'file_picker',
    toPack: 'file_picker_12',
  ),
  'file_picker_deprecated_allow_multiple': (
    fromPack: 'file_picker',
    toPack: 'file_picker_12',
  ),
  // connectivity_plus 6.0 changed checkConnectivity() to List<ConnectivityResult>.
  'avoid_pre_v6_single_connectivity_result': (
    fromPack: 'connectivity_plus',
    toPack: 'connectivity_plus_6',
  ),
  // google_sign_in 7.0 removed the GoogleSignIn() ctor / signIn().
  'avoid_pre_v7_google_sign_in': (
    fromPack: 'google_sign_in',
    toPack: 'google_sign_in_7',
  ),
  // local_auth 3.0 removed AuthenticationOptions / useErrorDialogs, renamed
  // stickyAuth, changed the thrown exception type.
  'local_auth_deprecated_options_class': (
    fromPack: 'local_auth',
    toPack: 'local_auth_3',
  ),
  'local_auth_use_error_dialogs_removed': (
    fromPack: 'local_auth',
    toPack: 'local_auth_3',
  ),
  'local_auth_sticky_auth_renamed': (
    fromPack: 'local_auth',
    toPack: 'local_auth_3',
  ),
  'local_auth_platform_exception_catch': (
    fromPack: 'local_auth',
    toPack: 'local_auth_3',
  ),
  // app_links 6.0 removed getInitialAppLink / getLatestAppLink and the
  // allUriLinkStream / allStringLinkStream getters.
  'app_links_use_get_initial_link': (
    fromPack: 'app_links',
    toPack: 'app_links_6',
  ),
  'app_links_use_get_latest_link': (
    fromPack: 'app_links',
    toPack: 'app_links_6',
  ),
  'app_links_use_uri_link_stream': (
    fromPack: 'app_links',
    toPack: 'app_links_6',
  ),
};

/// Returns a new map with [kRelocatedRulePackCodes] applied: each code is
/// removed from its `fromPack` and added to its `toPack`.
///
/// Both the generator and the audit run this after [applyCompositeRulePacks] so
/// the generated registry and the consistency check agree on ownership.
Map<String, Set<String>> applyRelocatedRulePacks(
  Map<String, Set<String>> extracted,
) {
  final result = {
    for (final entry in extracted.entries)
      entry.key: Set<String>.from(entry.value),
  };
  for (final entry in kRelocatedRulePackCodes.entries) {
    final code = entry.key;
    result[entry.value.fromPack]?.remove(code);
    result.putIfAbsent(entry.value.toPack, () => <String>{}).add(code);
  }
  return result;
}

/// `{stem}_rules.dart` → pack id (e.g. dio_rules → dio).
String packIdForStem(String stem) {
  if (stem.endsWith('_rules')) {
    return stem.prefix(stem.length - '_rules'.length);
  }
  return stem;
}

Map<String, Set<String>> extractFromPackagesDir(Directory dir) {
  final out = <String, Set<String>>{};
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    // Fix: avoid_unsafe_collection_methods — lastOrNull + continue guards
    // against URIs with no path segments rather than throwing StateError.
    final name = entity.uri.pathSegments.lastOrNull;
    if (name == null) continue;
    if (!name.endsWith('_rules.dart')) continue;
    final stem = name.replaceAll('.dart', '');
    final pack = packIdForStem(stem);
    final text = entity.readAsStringSync();
    final ids = _lintCodeName.allMatches(text).map((m) => m.group(1)!).toSet();
    out.putIfAbsent(pack, () => <String>{}).addAll(ids);
  }
  return out;
}

void main(List<String> args) {
  final emitDart = args.contains('--emit-dart');
  final root = Directory.current;
  final packagesDir = Directory('${root.path}/lib/src/rules/packages');
  if (!packagesDir.existsSync()) {
    stderr.writeln('Missing lib/src/rules/packages');
    exitCode = 2;

    return;
  }

  final extracted = applyRelocatedRulePacks(
    applyCompositeRulePacks(extractFromPackagesDir(packagesDir)),
  );
  final sortedPacks = extracted.keys.toList()..sort();

  var mismatch = false;
  for (final pack in sortedPacks) {
    final fileCodes = extracted[pack]!;
    final regCodes = kRulePackRuleCodes[pack];
    if (regCodes == null) {
      print('PACK $pack: ${fileCodes.length} rules in file, NOT IN REGISTRY');
      mismatch = true;
      continue;
    }
    final missing = fileCodes.difference(regCodes);
    final extra = regCodes.difference(fileCodes);
    if (missing.isEmpty && extra.isEmpty) {
      print('PACK $pack: OK (${fileCodes.length})');
      continue;
    }
    mismatch = true;
    print('PACK $pack: file=${fileCodes.length} registry=${regCodes.length}');
    if (missing.isNotEmpty) {
      print(
        '  missing in registry (${missing.length}): ${missing.toList()..sort()}',
      );
    }
    if (extra.isNotEmpty) {
      print('  extra in registry (${extra.length}): ${extra.toList()..sort()}');
    }
  }

  // Registry packs not tied to a single file (semver / cross-cutting)
  const synthetic = {'collection_compat'};
  for (final regId in kRulePackRuleCodes.keys) {
    if (extracted.containsKey(regId) || synthetic.contains(regId)) continue;
    print('REGISTRY ONLY (no packages file): $regId');
  }

  if (emitDart) {
    print(
      '\n// --- suggested kRulePackRuleCodes entries (merge manually) ---\n',
    );
    for (final pack in sortedPacks) {
      final codes = extracted[pack]!.toList()..sort();
      print("  '$pack': {");
      for (final c in codes) {
        print("    '$c',");
      }
      print('  },');
    }
  }

  if (mismatch) {
    stderr.writeln(
      '\nAudit: mismatches found. Expand kRulePackRuleCodes or fix extraction.',
    );
    exitCode = 1;
  }
}
