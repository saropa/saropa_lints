#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// **Rule pack registry generator (Phase 5)** — single entry point to refresh:
///
/// 1. **`lib/src/config/rule_pack_codes_generated.dart`** — `kRulePackRuleCodesGenerated`
///    and `kRulePackPubspecMarkersGenerated`, derived from `LintCode('...')` names in each
///    `*_rules.dart` under `lib/src/rules/packages/`, then [applyCompositeRulePacks].
/// 2. **`extension/src/rulePacks/rulePackDefinitions.ts`** — sidebar UI metadata
///    (`RULE_PACK_DEFINITIONS`, `isPackDetected`) so VS Code matches the analyzer.
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

import 'rule_pack_audit.dart'
    show applyCompositeRulePacks, extractFromPackagesDir;

/// Pub dependency keys for init / extension (match `rulePackDefinitions.ts`).
const Map<String, Set<String>> kPubspecMarkersByPack = {
  'auto_route': {'auto_route'},
  'bloc': {'bloc', 'flutter_bloc', 'hydrated_bloc'},
  'dio': {'dio'},
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
  'graphql': {'graphql'},
  'hive': {'hive', 'hive_flutter'},
  'isar': {'isar', 'isar_flutter_libs'},
  'package_specific': {}, // mixed; user opts in explicitly
  'provider': {'provider'},
  'qr_scanner': {'mobile_scanner', 'qr_flutter'},
  'riverpod': {'riverpod', 'flutter_riverpod', 'hooks_riverpod'},
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
  'dio': 'Dio',
  'drift': 'Drift',
  'equatable': 'Equatable',
  'firebase': 'Firebase',
  'flame': 'Flame',
  'flutter_hooks': 'Flutter Hooks',
  'geolocator': 'Geolocator',
  'get_it': 'get_it',
  'getx': 'GetX',
  'graphql': 'GraphQL',
  'hive': 'Hive',
  'isar': 'Isar',
  'package_specific': 'Mixed packages',
  'provider': 'Provider',
  'qr_scanner': 'QR / scanner',
  'riverpod': 'Riverpod',
  'rxdart': 'RxDart',
  'shared_preferences': 'shared_preferences',
  'sqflite': 'sqflite',
  'supabase': 'Supabase',
  'url_launcher': 'url_launcher',
  'workmanager': 'workmanager',
};

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

  final extracted = extractFromPackagesDir(packagesDir);
  applyCompositeRulePacks(extracted);

  final sortedPacks = extracted.keys.toList()..sort();

  final warnings = <String>[];
  for (final pack in sortedPacks) {
    if (!kPubspecMarkersByPack.containsKey(pack)) {
      warnings.add('No kPubspecMarkersByPack entry for pack: $pack');
    }
  }
  for (final pack in kPubspecMarkersByPack.keys) {
    if (!extracted.containsKey(pack)) {
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

  _writeRulePackDefinitionsTs(
    root: root,
    sortedPacks: sortedPacks,
    extracted: extracted,
  );

  for (final w in warnings) {
    print('WARN: $w');
  }
}

void _writeRulePackDefinitionsTs({
  required Directory root,
  required List<String> sortedPacks,
  required Map<String, Set<String>> extracted,
}) {
  final tsFile = File(
    '${root.path}/extension/src/rulePacks/rulePackDefinitions.ts',
  );
  final sb = StringBuffer();
  sb.writeln('/**');
  sb.writeln(' * Rule pack metadata for the Rule Packs UI.');
  sb.writeln(
    ' * GENERATED by tool/generate_rule_pack_registry.dart — do not edit.',
  );
  sb.writeln(' */');
  sb.writeln();
  sb.writeln('export interface RulePackDefinition {');
  sb.writeln('  readonly id: string;');
  sb.writeln('  readonly label: string;');
  sb.writeln('  readonly matchPubNames: readonly string[];');
  sb.writeln('  readonly ruleCodes: readonly string[];');
  sb.writeln(
    '  readonly dependencyGate?: { readonly package: string; readonly constraint: string };',
  );
  sb.writeln('}');
  sb.writeln();
  sb.writeln(
    'export const RULE_PACK_DEFINITIONS: readonly RulePackDefinition[] = [',
  );

  for (final pack in sortedPacks) {
    final label = kPackUiLabels[pack] ?? pack;
    final markers = (kPubspecMarkersByPack[pack] ?? {}).toList()..sort();
    final codes = extracted[pack]!.toList()..sort();
    final markersJs = markers.map((s) => "'$s'").join(', ');
    sb.writeln('  {');
    sb.writeln("    id: '$pack',");
    sb.writeln("    label: '${label.replaceAll("'", r"\'")}',");
    sb.writeln('    matchPubNames: [$markersJs],');
    sb.writeln('    ruleCodes: [');
    for (final c in codes) {
      sb.writeln("      '$c',");
    }
    sb.writeln('    ],');
    sb.writeln('  },');
  }

  sb.writeln('  {');
  sb.writeln("    id: 'collection_compat',");
  sb.writeln("    label: 'Collection (semver)',");
  sb.writeln("    matchPubNames: ['collection'],");
  sb.writeln(
    "    dependencyGate: { package: 'collection', constraint: '>=1.19.0' },",
  );
  sb.writeln('    ruleCodes: [');
  sb.writeln("      'avoid_collection_methods_with_unrelated_types',");
  sb.writeln('    ],');
  sb.writeln('  },');
  sb.writeln('];');
  sb.writeln();
  sb.writeln(
    '/** True if pubspec.yaml declares any of def.matchPubNames as a dependency entry. */',
  );
  sb.writeln(
    'export function isPackDetected(def: RulePackDefinition, pubspecContent: string): boolean {',
  );
  sb.writeln(
    "  return def.matchPubNames.some((n) => new RegExp(\`^\\\\s+\${n}\\\\s*:\`, 'm').test(pubspecContent));",
  );
  sb.writeln('}');

  tsFile.writeAsStringSync(sb.toString());
  print('Wrote ${tsFile.path}');
}
