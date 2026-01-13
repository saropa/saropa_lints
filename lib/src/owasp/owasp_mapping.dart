/// OWASP mapping utilities for compliance reporting.
///
/// Provides functions to generate compliance reports and analyze
/// OWASP coverage across lint rules.
library;

import 'owasp_category.dart';

/// Generates a compliance coverage report for OWASP Mobile Top 10.
///
/// Takes a map of rule names to their OWASP mappings and returns
/// coverage statistics for each Mobile category.
Map<OwaspMobile, List<String>> getMobileCoverage(
  Map<String, OwaspMapping> ruleMappings,
) {
  final Map<OwaspMobile, List<String>> coverage =
      <OwaspMobile, List<String>>{};

  for (final OwaspMobile category in OwaspMobile.values) {
    coverage[category] = <String>[];
  }

  for (final MapEntry<String, OwaspMapping> entry in ruleMappings.entries) {
    for (final OwaspMobile category in entry.value.mobile) {
      coverage[category]!.add(entry.key);
    }
  }

  return coverage;
}

/// Generates a compliance coverage report for OWASP Web Top 10.
///
/// Takes a map of rule names to their OWASP mappings and returns
/// coverage statistics for each Web category.
Map<OwaspWeb, List<String>> getWebCoverage(
  Map<String, OwaspMapping> ruleMappings,
) {
  final Map<OwaspWeb, List<String>> coverage = <OwaspWeb, List<String>>{};

  for (final OwaspWeb category in OwaspWeb.values) {
    coverage[category] = <String>[];
  }

  for (final MapEntry<String, OwaspMapping> entry in ruleMappings.entries) {
    for (final OwaspWeb category in entry.value.web) {
      coverage[category]!.add(entry.key);
    }
  }

  return coverage;
}

/// Returns categories with no rule coverage.
///
/// Useful for identifying gaps in security coverage.
({List<OwaspMobile> mobile, List<OwaspWeb> web}) getUncoveredCategories(
  Map<String, OwaspMapping> ruleMappings,
) {
  final Map<OwaspMobile, List<String>> mobileCoverage =
      getMobileCoverage(ruleMappings);
  final Map<OwaspWeb, List<String>> webCoverage = getWebCoverage(ruleMappings);

  return (
    mobile: mobileCoverage.entries
        .where(
          (MapEntry<OwaspMobile, List<String>> e) => e.value.isEmpty,
        )
        .map((MapEntry<OwaspMobile, List<String>> e) => e.key)
        .toList(),
    web: webCoverage.entries
        .where(
          (MapEntry<OwaspWeb, List<String>> e) => e.value.isEmpty,
        )
        .map((MapEntry<OwaspWeb, List<String>> e) => e.key)
        .toList(),
  );
}

/// Generates a markdown compliance report.
///
/// Returns a formatted markdown string showing OWASP coverage
/// for both Mobile and Web standards.
String generateComplianceReport(Map<String, OwaspMapping> ruleMappings) {
  final StringBuffer buffer = StringBuffer();

  buffer.writeln('# OWASP Compliance Report');
  buffer.writeln();

  // Mobile Top 10
  buffer.writeln('## OWASP Mobile Top 10 (2024)');
  buffer.writeln();
  buffer.writeln('| Category | Rules | Count |');
  buffer.writeln('|----------|-------|-------|');

  final Map<OwaspMobile, List<String>> mobileCoverage =
      getMobileCoverage(ruleMappings);
  for (final OwaspMobile category in OwaspMobile.values) {
    final List<String> rules = mobileCoverage[category]!;
    final String ruleList =
        rules.isEmpty ? '_No coverage_' : rules.take(3).join(', ');
    final String suffix = rules.length > 3 ? '...' : '';
    buffer.writeln(
      '| ${category.id}: ${category.name} | $ruleList$suffix | ${rules.length} |',
    );
  }

  buffer.writeln();

  // Web Top 10
  buffer.writeln('## OWASP Top 10 (2021)');
  buffer.writeln();
  buffer.writeln('| Category | Rules | Count |');
  buffer.writeln('|----------|-------|-------|');

  final Map<OwaspWeb, List<String>> webCoverage = getWebCoverage(ruleMappings);
  for (final OwaspWeb category in OwaspWeb.values) {
    final List<String> rules = webCoverage[category]!;
    final String ruleList =
        rules.isEmpty ? '_No coverage_' : rules.take(3).join(', ');
    final String suffix = rules.length > 3 ? '...' : '';
    buffer.writeln(
      '| ${category.id}: ${category.name} | $ruleList$suffix | ${rules.length} |',
    );
  }

  buffer.writeln();

  // Summary
  final int totalMobileRules = mobileCoverage.values
      .fold(0, (int sum, List<String> rules) => sum + rules.length);
  final int totalWebRules = webCoverage.values
      .fold(0, (int sum, List<String> rules) => sum + rules.length);
  final int mobileCovered =
      mobileCoverage.values.where((List<String> r) => r.isNotEmpty).length;
  final int webCovered =
      webCoverage.values.where((List<String> r) => r.isNotEmpty).length;

  buffer.writeln('## Summary');
  buffer.writeln();
  buffer.writeln('- **Mobile Top 10 Coverage**: $mobileCovered/10 categories '
      '($totalMobileRules rule mappings)');
  buffer.writeln('- **Web Top 10 Coverage**: $webCovered/10 categories '
      '($totalWebRules rule mappings)');

  return buffer.toString();
}
