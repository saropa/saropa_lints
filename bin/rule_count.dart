#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/COMMENT_COVERAGE_PLAN.md`.
library;

// CLI tool to report the current rule counts per tier.
//
// Usage:
//   dart run saropa_lints:rule_count
//   dart run saropa_lints:rule_count --format json
//   dart run saropa_lints:rule_count --help
//
// Single source of truth for "how many rules does saropa_lints have" —
// counts are computed live from `lib/src/tiers.dart` set unions, the same
// sets the plugin and `getRulesForTier` use, so this can never drift from
// what actually ships (unlike the hand-typed "2100+" strings in docs/
// marketing copy that this CLI was added to stop from going stale again).
import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();

    return;
  }

  final format = _readOption(args, '--format') ?? 'text';

  final counts = <String, int>{
    'essential': essentialRules.length,
    'recommended': getRulesForTier('recommended').length,
    'professional': getRulesForTier('professional').length,
    'comprehensive': getRulesForTier('comprehensive').length,
    'pedantic': getRulesForTier('pedantic').length,
    'stylistic': stylisticRules.length,
    'total': getAllDefinedRules().length,
  };

  if (format == 'json') {
    print(const JsonEncoder.withIndent('  ').convert(counts));

    return;
  }

  stdout.writeln('saropa_lints rule counts (computed from lib/src/tiers.dart):');
  stdout.writeln('  Essential:      ${counts['essential']}');
  stdout.writeln('  Recommended:    ${counts['recommended']}');
  stdout.writeln('  Professional:   ${counts['professional']}');
  stdout.writeln('  Comprehensive:  ${counts['comprehensive']}');
  stdout.writeln('  Pedantic:       ${counts['pedantic']} (all tiered rules)');
  stdout.writeln('  Stylistic:      ${counts['stylistic']} (opt-in, not part of any tier)');
  stdout.writeln('  Total defined:  ${counts['total']} (pedantic + stylistic)');
}

String? _readOption(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }

  return args[index + 1];
}

void _printUsage() {
  stdout.writeln('''
Usage: dart run saropa_lints:rule_count [options]

Reports the current rule counts per tier, computed live from
lib/src/tiers.dart so the number can never go stale in docs/marketing copy.

Options:
  --format <text|json>  Output format (default: text)
  --help, -h             Show this help message
''');
}
