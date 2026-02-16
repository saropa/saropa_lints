/// Configuration for the baseline feature.
///
/// Parses baseline configuration from `analysis_options.yaml`:
/// ```yaml
/// custom_lint:
///   saropa_lints:
///     baseline:
///       file: "saropa_baseline.json"
///       date: "2025-01-15"
///       paths:
///         - "lib/legacy/"
///         - "lib/deprecated/"
///       only_impacts: [low, medium]
/// ```
library;

class BaselineConfig {
  const BaselineConfig({
    this.file,
    this.date,
    this.paths = const [],
    this.onlyImpacts = const [],
  });

  /// Creates a [BaselineConfig] from YAML configuration.
  ///
  /// Returns null if no baseline configuration is present.
  factory BaselineConfig.fromYaml(Object? yaml) {
    if (yaml == null) {
      return const BaselineConfig();
    }

    if (yaml is! Map) {
      return const BaselineConfig();
    }

    final map = yaml;

    // Parse file path
    final file = map['file'] as String?;

    // Parse date
    final dateStr = map['date'] as String?;
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    // Parse paths
    final pathsRaw = map['paths'];
    final paths = <String>[];
    if (pathsRaw is List) {
      for (final p in pathsRaw) {
        if (p is String) {
          paths.add(p);
        }
      }
    }

    // Parse only_impacts
    final impactsRaw = map['only_impacts'];
    final onlyImpacts = <String>[];
    if (impactsRaw is List) {
      for (final i in impactsRaw) {
        if (i is String) {
          onlyImpacts.add(i.toLowerCase());
        }
      }
    }

    return BaselineConfig(
      file: file,
      date: date,
      paths: paths,
      onlyImpacts: onlyImpacts,
    );
  }

  /// Path to the baseline JSON file.
  ///
  /// Example: `saropa_baseline.json`
  final String? file;

  /// Baseline date - ignore violations in code unchanged since this date.
  ///
  /// Uses git blame to determine line age.
  final DateTime? date;

  /// Path patterns to ignore.
  ///
  /// Supports glob patterns like `lib/legacy/**`.
  final List<String> paths;

  /// Only baseline violations of these impact levels.
  ///
  /// Valid values: `critical`, `high`, `medium`, `low`, `opinionated`.
  /// If empty, all impacts are baselined.
  final List<String> onlyImpacts;

  /// Whether any baseline configuration is present.
  bool get isEnabled => file != null || date != null || paths.isNotEmpty;

  /// Whether a specific impact level should be baselined.
  ///
  /// Returns true if:
  /// - [onlyImpacts] is empty (baseline all), or
  /// - [impact] is in the [onlyImpacts] list
  bool shouldBaselineImpact(String impact) {
    if (onlyImpacts.isEmpty) return true;
    return onlyImpacts.contains(impact.toLowerCase());
  }

  @override
  String toString() =>
      'BaselineConfig('
      'file: $file, '
      'date: $date, '
      'paths: $paths, '
      'onlyImpacts: $onlyImpacts)';
}
