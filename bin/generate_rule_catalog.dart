#!/usr/bin/env dart
/// Generates the bundled rule-metadata catalog the VS Code extension ships.
///
/// Usage: `dart run saropa_lints:generate_rule_catalog [--output <file>]`
///
/// Why this exists. Live analyzer diagnostics carry no per-rule metadata (rule
/// type, lifecycle status, security-review flag, CWE/CERT ids). The extension's
/// Issues-panel rule-type/status filters and security-hotspot review need that
/// metadata for EVERY rule, up front, without first running an export. This
/// script walks [allSaropaRules] and writes the same `ruleMetadataByRule` map an
/// analysis export would emit — but for the full rule set — to a JSON asset the
/// extension bundles under `media/`. Regenerate it whenever rule metadata
/// changes (new rule, changed ruleType/ruleStatus/tags/CWE).
library;

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart' show allSaropaRules;
import 'package:saropa_lints/src/report/violation_export.dart';

/// Default output path, relative to the package root. Lives under the
/// extension's `media/` dir, which is included in the published `.vsix`.
const String _defaultOutput = 'extension/media/rules_catalog.json';

void main(List<String> args) {
  var outputPath = _defaultOutput;
  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '--output' || args[i] == '-o') &&
        i + 1 < args.length &&
        !args[i + 1].startsWith('-')) {
      outputPath = args[++i];
    } else if (args[i] == '--help' || args[i] == '-h') {
      stdout.writeln(
        'Usage: dart run saropa_lints:generate_rule_catalog [--output <file>]',
      );
      exit(0);
    }
  }

  final rules = allSaropaRules;
  final metadata = ViolationExporter.buildRuleMetadataCatalog(rules);

  // Schema mirrors the extension's `RuleCatalog` reader: a small header plus
  // the rule -> metadata map keyed exactly as `ruleMetadataByRule` in an export
  // (so the same TS `RuleMetadataData` type deserializes both).
  final catalog = <String, Object?>{
    'schemaVersion': '1.0',
    'ruleCount': metadata.length,
    'rules': metadata,
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(catalog);
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('$encoded\n');

  stdout.writeln(
    'Wrote ${metadata.length} rules to ${file.absolute.path}',
  );
}
