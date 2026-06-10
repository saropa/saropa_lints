#!/usr/bin/env dart
// CLI tool — print() is the standard mechanism for command-line output; both
// the SDK rule (avoid_print) and the saropa_lints v3 rule (avoid_print_in_release)
// fire here as false positives because this script never runs in a release app.
// ignore_for_file: avoid_print, avoid_print_in_release

/// **Rule pack registry generator (Phase 5)** — single entry point to refresh:
///
/// 1. **`lib/src/config/rule_pack_codes_generated.dart`** — `kRulePackRuleCodesGenerated`
///    and `kRulePackPubspecMarkersGenerated`, derived from `LintCode('...')` names in each
///    `*_rules.dart` under `lib/src/rules/packages/`, then [applyCompositeRulePacks].
/// 2. **`extension/src/rulePacks/rulePackDefinitions.ts`** — sidebar UI metadata
///    (`RULE_PACK_DEFINITIONS`, `isPackDetected`) aligned to [kRulePackRuleCodes] /
///    [kRulePackPubspecMarkers] / SDK + dependency gates in `rule_packs.dart` (not only
///    `lib/src/rules/packages/` extraction).
///
/// **[kPubspecMarkersByPack]** must contain exactly one entry per extracted pack id
/// (empty set allowed for `package_specific`). The script prints WARN lines for mismatches
/// but still writes files — fix warnings before committing.
///
/// **`collection_compat`** is appended after generated packs (semver gate + rule list);
/// keep constraint text aligned with [kRulePackDependencyGates] in `rule_packs.dart`.
///
/// Run from repo root: `dart run tool/generate_rule_pack_registry.dart`
library;

import 'dart:io';

import 'package:saropa_lints/src/config/rule_packs.dart' as packs;

import 'rule_pack_audit.dart'
    show
        applyCompositeRulePacks,
        applyRelocatedRulePacks,
        extractFromPackagesDir;

/// Pub dependency keys for init / extension (match `rulePackDefinitions.ts`).
const Map<String, Set<String>> kPubspecMarkersByPack = {
  'auto_route': {'auto_route'},
  'bloc': {'bloc', 'flutter_bloc', 'hydrated_bloc'},
  // Semver-gated companion to `bloc` (gate bloc >= 8.0.0 in kRulePackDependencyGates).
  'bloc_8': {'bloc', 'flutter_bloc', 'hydrated_bloc'},
  'dio': {'dio'},
  // Semver-gated companion to `dio` (gate dio >= 5.0.0 in kRulePackDependencyGates).
  'dio_5': {'dio'},
  'drift': {'drift', 'drift_dev'},
  'equatable': {'equatable'},
  'firebase': {
    'firebase_core',
    'firebase_auth',
    'cloud_firestore',
    'firebase_messaging',
    'firebase_storage',
    'firebase_analytics',
  },
  'flame': {'flame'},
  'flutter_hooks': {'flutter_hooks'},
  'geolocator': {'geolocator'},
  'get_it': {'get_it'},
  'getx': {'get', 'getx'},
  // go_router migration pack; the whole pack is gated on go_router >= 6.0.0
  // (kRulePackDependencyGates), so the versioned pack id needs no relocation.
  'go_router_6': {'go_router'},
  'graphql': {'graphql'},
  'hive': {'hive', 'hive_flutter'},
  'isar': {'isar', 'isar_flutter_libs'},
  'package_specific': {}, // mixed; user opts in explicitly
  'provider': {'provider'},
  'qr_scanner': {'mobile_scanner', 'qr_flutter'},
  'riverpod': {'riverpod', 'flutter_riverpod', 'hooks_riverpod'},
  // Semver-gated companion to `riverpod`: same dependency family, but the
  // dependency gate (riverpod >= 2.0.0) in kRulePackDependencyGates restricts it
  // to projects where the Notifier API exists. See kRelocatedRulePackCodes.
  'riverpod_2': {'riverpod', 'flutter_riverpod', 'hooks_riverpod'},
  // Semver-gated companion (riverpod >= 3.0.0): StateNotifier legacy migration.
  'riverpod_3': {'riverpod', 'flutter_riverpod', 'hooks_riverpod'},
  'rxdart': {'rxdart'},
  'shared_preferences': {'shared_preferences'},
  'sqflite': {'sqflite'},
  'supabase': {'supabase', 'supabase_flutter'},
  'url_launcher': {'url_launcher'},
  'workmanager': {'workmanager'},
};

const Map<String, String> kPackUiLabels = {
  'auto_route': 'Auto Route',
  'bloc': 'Bloc',
  'bloc_8': 'Bloc 8.x',
  'dio': 'Dio',
  'dio_5': 'Dio 5.x',
  'drift': 'Drift',
  'equatable': 'Equatable',
  'firebase': 'Firebase',
  'flame': 'Flame',
  'flutter_hooks': 'Flutter Hooks',
  'geolocator': 'Geolocator',
  'get_it': 'get_it',
  'getx': 'GetX',
  'go_router_6': 'go_router 6.x',
  'graphql': 'GraphQL',
  'hive': 'Hive',
  'isar': 'Isar',
  'package_specific': 'Mixed packages',
  'provider': 'Provider',
  'qr_scanner': 'QR / scanner',
  'riverpod': 'Riverpod',
  'riverpod_2': 'Riverpod 2.x',
  'riverpod_3': 'Riverpod 3.x',
  'rxdart': 'RxDart',
  'shared_preferences': 'shared_preferences',
  'sqflite': 'sqflite',
  'supabase': 'Supabase',
  'url_launcher': 'url_launcher',
  'workmanager': 'workmanager',
};

String _uiLabelForPackId(String pack) {
  final mapped = kPackUiLabels[pack];
  if (mapped != null) return mapped;

  const dartPrefix = 'dart_sdk_';
  if (pack.startsWith(dartPrefix)) {
    final tail = pack.split(dartPrefix).skip(1).join('').replaceAll('_', '.');
    return 'Dart SDK $tail';
  }
  const flutterPrefix = 'flutter_sdk_';
  if (pack.startsWith(flutterPrefix)) {
    final tail = pack
        .split(flutterPrefix)
        .skip(1)
        .join('')
        .replaceAll('_', '.');
    return 'Flutter SDK $tail';
  }

  return pack;
}

String _dartSetLiteral(Set<String> codes) {
  final sorted = codes.toList()..sort();
  final buf = StringBuffer();
  for (final c in sorted) {
    buf.writeln("    '$c',");
  }
  return buf.toString();
}

void main() {
  final root = Directory.current;
  final packagesDir = Directory('${root.path}/lib/src/rules/packages');
  final outFile = File(
    '${root.path}/lib/src/config/rule_pack_codes_generated.dart',
  );

  final extracted = applyRelocatedRulePacks(
    applyCompositeRulePacks(extractFromPackagesDir(packagesDir)),
  );

  final sortedPacks = extracted.keys.toList()..sort();

  final registryOnlyPacks = packs.kRulePackRuleCodes.keys
      .where((id) => !extracted.containsKey(id))
      .toSet();

  final warnings = <String>[];
  for (final pack in sortedPacks) {
    if (!kPubspecMarkersByPack.containsKey(pack)) {
      warnings.add('No kPubspecMarkersByPack entry for pack: $pack');
    }
  }
  for (final pack in kPubspecMarkersByPack.keys) {
    if (!extracted.containsKey(pack) && !registryOnlyPacks.contains(pack)) {
      warnings.add('kPubspecMarkersByPack has unused pack: $pack');
    }
  }

  final buf = StringBuffer();
  buf.writeln("// GENERATED FILE — do not edit by hand.");
  buf.writeln("// Run: dart run tool/generate_rule_pack_registry.dart");
  buf.writeln('// ignore_for_file: always_specify_types');
  buf.writeln();
  buf.writeln(
    '/// Rule codes per pack, extracted from lib/src/rules/packages/.',
  );
  buf.writeln('const Map<String, Set<String>> kRulePackRuleCodesGenerated = {');
  for (final pack in sortedPacks) {
    buf.writeln("  '$pack': {");
    buf.write(_dartSetLiteral(extracted[pack]!));
    buf.writeln('  },');
  }
  buf.writeln('};');
  buf.writeln();

  buf.writeln(
    '/// Pubspec markers for generated packs (keep extension rulePackDefinitions in sync).',
  );
  buf.writeln(
    'const Map<String, Set<String>> kRulePackPubspecMarkersGenerated = {',
  );
  for (final pack in sortedPacks) {
    final markers = kPubspecMarkersByPack[pack] ?? {};
    if (markers.isEmpty) {
      buf.writeln("  '$pack': {},");
      continue;
    }
    final m = markers.toList()..sort();
    buf.write("  '$pack': {");
    buf.writeAll(m.map((s) => "'$s'"), ', ');
    buf.writeln('},');
  }
  buf.writeln('};');

  outFile.writeAsStringSync(buf.toString());
  print('Wrote ${outFile.path} (${sortedPacks.length} packs)');

  _writeRulePackDefinitionsTs(root: root);

  for (final w in warnings) {
    print('WARN: $w');
  }
}

void _writeRulePackDefinitionsTs({required Directory root}) {
  final sortedAllPackIds = packs.kRulePackRuleCodes.keys.toList()..sort();

  final tsFile = File(
    '${root.path}/extension/src/rulePacks/rulePackDefinitions.ts',
  );
  final sb = StringBuffer();
  sb.writeln('/**');
  sb.writeln(
    ' * Rule pack metadata for the VS Code Rule Packs sidebar and pack detection.',
  );
  sb.writeln(' *');
  sb.writeln(
    ' * Each entry ties pubspec dependency names to the lint codes that belong to that',
  );
  sb.writeln(
    ' * ecosystem pack. Optional gates hide a pack until SDK or dependency constraints',
  );
  sb.writeln(' * match the user project (see isPackDetected).');
  sb.writeln(' *');
  sb.writeln(
    ' * GENERATED by tool/generate_rule_pack_registry.dart — do not edit by hand.',
  );
  sb.writeln(' */');
  sb.writeln();
  sb.writeln(
    '/** One selectable pack: stable id, human label, markers, rules, optional gates. */',
  );
  sb.writeln('export interface RulePackDefinition {');
  sb.writeln(
    '  /** Pack id; matches Dart registry keys in kRulePackRuleCodesGenerated. */',
  );
  sb.writeln('  readonly id: string;');
  sb.writeln('  /** Sidebar display name (title case from pack id). */');
  sb.writeln('  readonly label: string;');
  sb.writeln(
    '  /** Pub package names whose presence in pubspec implies this pack may apply. */',
  );
  sb.writeln('  readonly matchPubNames: readonly string[];');
  sb.writeln(
    '  /** Lint rule codes enabled when this pack is on (subset of saropa_lints rules). */',
  );
  sb.writeln('  readonly ruleCodes: readonly string[];');
  sb.writeln(
    '  /** If set, pack is gated until this direct dependency satisfies the semver constraint. */',
  );
  sb.writeln(
    '  readonly dependencyGate?: { readonly package: string; readonly constraint: string };',
  );
  sb.writeln(
    '  /** If set, pack is gated until environment[sdkKey] lower bound satisfies constraint. */',
  );
  sb.writeln(
    '  readonly sdkGate?: { readonly sdkKey: string; readonly constraint: string };',
  );
  sb.writeln('}');
  sb.writeln();
  sb.writeln(
    'export const RULE_PACK_DEFINITIONS: readonly RulePackDefinition[] = [',
  );

  for (final pack in sortedAllPackIds) {
    final label = _uiLabelForPackId(pack);
    final markers =
        (packs.kRulePackPubspecMarkers[pack] ?? const <String>{}).toList()
          ..sort();
    final codes = (packs.kRulePackRuleCodes[pack] ?? const <String>{}).toList()
      ..sort();
    final markersJs = markers.map((s) => "'$s'").join(', ');
    final depGate = packs.kRulePackDependencyGates[pack];
    final sdkGate = packs.kRulePackSdkGates[pack];
    sb.writeln('  {');
    sb.writeln("    id: '$pack',");
    sb.writeln("    label: '${label.replaceAll("'", r"\'")}',");
    sb.writeln('    matchPubNames: [$markersJs],');
    sb.writeln('    ruleCodes: [');
    for (final c in codes) {
      sb.writeln("      '$c',");
    }
    sb.writeln('    ],');
    if (depGate != null) {
      sb.writeln(
        "    dependencyGate: { package: '${depGate.dependency.replaceAll("'", r"\'")}', constraint: '${depGate.constraint.replaceAll("'", r"\'")}' },",
      );
    }
    if (sdkGate != null) {
      sb.writeln(
        "    sdkGate: { sdkKey: '${sdkGate.sdkKey.replaceAll("'", r"\'")}', constraint: '${sdkGate.constraint.replaceAll("'", r"\'")}' },",
      );
    }
    sb.writeln('  },');
  }

  sb.writeln('];');
  sb.writeln();
  sb.writeln(
    '/** Lexicographic numeric segment compare for x.y.z strings (not full semver). */',
  );
  sb.writeln('function _compareSemver(a: string, b: string): number {');
  sb.writeln('  const pa = a.split(".").map((x) => Number.parseInt(x, 10));');
  sb.writeln('  const pb = b.split(".").map((x) => Number.parseInt(x, 10));');
  sb.writeln('  const n = Math.max(pa.length, pb.length);');
  sb.writeln('  for (let i = 0; i < n; i++) {');
  sb.writeln('    const da = Number.isFinite(pa[i]) ? pa[i] : 0;');
  sb.writeln('    const db = Number.isFinite(pb[i]) ? pb[i] : 0;');
  sb.writeln('    if (da !== db) return da < db ? -1 : 1;');
  sb.writeln('  }');
  sb.writeln('  return 0;');
  sb.writeln('}');
  sb.writeln();
  sb.writeln(
    '/** Parse environment block for sdkKey and return a x.y.z lower bound if inferable. */',
  );
  sb.writeln(
    'function _parseSdkLowerBoundFromPubspec(pubspecYamlContent: string, sdkKey: string): string | null {',
  );
  sb.writeln(
    "  const envMatch = /^environment:\\s*\\n((?:[ \\t]+.*\\n)+)/m.exec(pubspecYamlContent);",
  );
  sb.writeln('  if (!envMatch) return null;');
  sb.writeln('  const envBlock = envMatch[1] ?? "";');
  sb.writeln('  for (const line of envBlock.split("\\n")) {');
  sb.writeln('    const trimmed = line.trimStart();');
  sb.writeln("    if (!trimmed.startsWith(sdkKey + ':')) continue;");
  sb.writeln("    const raw = trimmed.slice(sdkKey.length + 1).trim();");
  sb.writeln(
    "    const rawConstraint = raw.replace(/^['\"]/, '').replace(/['\"]\\s*\$/, '');",
  );
  sb.writeln(
    '    if (!rawConstraint || rawConstraint.length === 0 || rawConstraint === "any") return null;',
  );
  sb.writeln(
    '    const geMatch = />=\\s*(\\d+\\.\\d+\\.\\d+)/.exec(rawConstraint);',
  );
  sb.writeln(
    '    const lower = geMatch?.[1] ?? (rawConstraint.startsWith("^") ? rawConstraint.slice(1).trim() : rawConstraint);',
  );
  sb.writeln('    const semver = /^\\d+\\.\\d+\\.\\d+/.exec(lower)?.[0];');
  sb.writeln('    if (semver) return semver;');
  sb.writeln('  }');
  sb.writeln('  return null;');
  sb.writeln('}');
  sb.writeln();
  sb.writeln(
    '/** True when constraint is >= style and parsed min is <= lowerBound (semver compare). */',
  );
  sb.writeln(
    'function _constraintAllowsLowerBound(constraint: string, lowerBound: string): boolean {',
  );
  sb.writeln('  const c = constraint.trim();');
  sb.writeln('  if (c.startsWith(">=")) {');
  sb.writeln('    const min = /^>=\\s*(\\d+\\.\\d+\\.\\d+)/.exec(c)?.[1];');
  sb.writeln('    if (!min) return false;');
  sb.writeln('    return _compareSemver(lowerBound, min) >= 0;');
  sb.writeln('  }');
  sb.writeln('  return false;');
  sb.writeln('}');
  sb.writeln();
  sb.writeln(
    '/** True when pubspec markers / environment gates suggest the pack applies. */',
  );
  sb.writeln(
    'export function isPackDetected(def: RulePackDefinition, pubspecContent: string): boolean {',
  );
  sb.writeln('  if (def.sdkGate) {');
  sb.writeln(
    '    const lower = _parseSdkLowerBoundFromPubspec(pubspecContent, def.sdkGate.sdkKey);',
  );
  sb.writeln('    if (!lower) return false;');
  sb.writeln(
    '    return _constraintAllowsLowerBound(def.sdkGate.constraint, lower);',
  );
  sb.writeln('  }');
  sb.writeln(
    "  return def.matchPubNames.some((n) => new RegExp('^\\\\s+' + n + '\\\\s*:', 'm').test(pubspecContent));",
  );
  sb.writeln('}');

  tsFile.writeAsStringSync(sb.toString());
  print('Wrote ${tsFile.path}');
}
