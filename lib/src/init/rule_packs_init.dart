/// Init CLI: list applicable rule packs, merge `--enable-pack` ids.
library;

import 'dart:io';

import 'package:saropa_lints/src/config/pubspec_lock_resolver.dart';
import 'package:saropa_lints/src/config/rule_packs.dart';

import 'display.dart';
import 'log_writer.dart';

/// Sorted unique pack ids for YAML: existing in file ∪ [extra].
List<String> mergeRulePackIdsForInit(
  List<String> existingFromYaml,
  List<String> extraFromCli,
) {
  final out = <String>{...existingFromYaml, ...extraFromCli};
  final list = out.toList()..sort();
  return list;
}

/// Print rule pack table (pubspec + lockfile + applicability).
void printRulePacksInitSummary({required String targetDir}) {
  final sep = Platform.pathSeparator;
  final pubspecFile = File('$targetDir${sep}pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    log.terminal(
      '${InitColors.dim}No pubspec.yaml — skipping rule pack list.${InitColors.reset}',
    );
    return;
  }
  String pubspecContent;
  try {
    pubspecContent = pubspecFile.readAsStringSync();
  } catch (_) {
    log.terminal(
      '${InitColors.yellow}Could not read pubspec.yaml — skipping rule pack list.${InitColors.reset}',
    );
    return;
  }

  final lock = readResolvedPackageVersions(targetDir);
  final ids = knownRulePackIds.toList()..sort();

  log.terminal('');
  log.terminal('${InitColors.bold}Rule packs (optional)${InitColors.reset}');
  log.terminal(
    '${InitColors.dim}Enable stacks via VS Code Rule Packs or:${InitColors.reset}',
  );
  log.terminal(
    '${InitColors.dim}  dart run saropa_lints:init --tier <tier> --enable-pack <id>${InitColors.reset}',
  );
  log.terminal('');
  log.terminal(
    '  ${InitColors.bold}${'Pack'.padRight(20)} In pubspec  Semver gate  Applicable${InitColors.reset}',
  );
  log.terminal('  ${'─' * 72}');

  for (final id in ids) {
    final inPub = isRulePackSuggestedByPubspec(id, pubspecContent);
    final gate = kRulePackDependencyGates[id];
    final semverCol = gate == null
        ? '${InitColors.dim}—${InitColors.reset}'
        : lock == null
        ? '${InitColors.yellow}no lockfile${InitColors.reset}'
        : packPassesDependencyGate(id, lock)
        ? '${InitColors.green}ok${InitColors.reset}'
        : '${InitColors.yellow}blocked${InitColors.reset}';
    final app = isRulePackApplicable(id, pubspecContent, lock);
    final pubCol = inPub
        ? '${InitColors.green}yes${InitColors.reset}'
        : '${InitColors.dim}no${InitColors.reset}';
    final appCol = app
        ? '${InitColors.green}yes${InitColors.reset}'
        : '${InitColors.dim}no${InitColors.reset}';
    log.terminal(
      '  ${id.padRight(20)} $pubCol        $semverCol    $appCol',
    );
  }
  log.terminal('');
}
