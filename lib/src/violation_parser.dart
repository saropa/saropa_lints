import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/models/violation.dart';

/// Rule name to impact level mapping.
/// Generated from the rule definitions.
final Map<String, LintImpact> _ruleImpacts = _buildRuleImpactMap();

Map<String, LintImpact> _buildRuleImpactMap() {
  final map = <String, LintImpact>{};

  // Get impact from each rule instance
  for (final rule in allSaropaRules) {
    map[rule.code.name] = rule.impact;
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
    final g1 = match.group(1);
    final g2 = match.group(2);
    final g3 = match.group(3);
    final g4 = match.group(4);
    final g5 = match.group(5);
    if (g1 == null || g2 == null || g3 == null || g4 == null || g5 == null) {
      throw FormatException(
        'Violation line did not match expected format (5 groups)',
        output,
      );
    }
    final file = g1;
    final line = int.tryParse(g2) ?? 0;
    final column = int.tryParse(g3) ?? 0;
    final message = g4;
    final rule = g5;

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
