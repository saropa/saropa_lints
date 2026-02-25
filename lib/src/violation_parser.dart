import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/models/violation.dart';

/// Rule name to impact level mapping.
/// Generated from the rule definitions.
final Map<String, LintImpact> _ruleImpacts = _buildRuleImpactMap();

Map<String, LintImpact> _buildRuleImpactMap() {
  final map = <String, LintImpact>{};

  // Get impact from each rule instance
  for (final rule in allSaropaRules) {
    map[rule.code.lowerCaseName] = rule.impact;
  }

  return map;
}

/// Parse lint analysis output into violations.
List<Violation> parseViolations(String output) {
  final violations = <Violation>[];

  final pattern = RegExp(
    r'^\s*(.+?):(\d+):(\d+)\s+•\s+(.*?)•\s+(\w+)\s+•',
    multiLine: true,
  );

  for (final match in pattern.allMatches(output)) {
    final file = match.group(1)!;
    final line = int.tryParse(match.group(2)!) ?? 0;
    final column = int.tryParse(match.group(3)!) ?? 0;
    final message = match.group(4)!;
    final rule = match.group(5)!;

    // Look up impact for this rule
    final impact = _ruleImpacts[rule] ?? LintImpact.medium;

    violations.add(
      Violation(
        file: file,
        line: line,
        column: column,
        rule: rule,
        message: message,
        impact: impact,
      ),
    );
  }

  return violations;
}
