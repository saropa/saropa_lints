#!/usr/bin/env dart
// ignore_for_file: avoid_print

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

void applyCompositeRulePacks(Map<String, Set<String>> extracted) {
  for (final entry in kCompositeRulePackIds.entries) {
    final rule = entry.key;
    for (final pack in entry.value) {
      extracted.putIfAbsent(pack, () => <String>{}).add(rule);
    }
  }
}

/// `{stem}_rules.dart` → pack id (e.g. dio_rules → dio).
String packIdForStem(String stem) {
  if (stem == 'package_specific_rules') return 'package_specific';
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

  final extracted = extractFromPackagesDir(packagesDir);
  applyCompositeRulePacks(extracted);
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
