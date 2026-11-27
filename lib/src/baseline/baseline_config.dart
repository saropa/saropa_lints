/// Configuration for the baseline feature.
///
/// Loaded by `config_loader` from the top-level `baseline:` key of
/// `analysis_options_custom.yaml` (parsed by `baseline_section_parser.dart`);
/// [BaselineManager] uses it to decide which violations to suppress
/// (file/path/date).
///
/// ```yaml
/// baseline:
///   file: "saropa_baseline.json"
///   date: "2025-01-15"
///   paths:
///     - "lib/legacy/"
///     - "lib/deprecated/"
///   only_impacts: [info]
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

    // Parse file path (defensive: trim and reject empty)
    final fileRaw = map['file'];
    final file = fileRaw is String && fileRaw.trim().isNotEmpty
        ? fileRaw.trim()
        : null;

    // Parse date
    final dateStr = map['date'] as String?;
    DateTime? date;
    if (dateStr != null && dateStr.trim().isNotEmpty) {
      date = DateTime.tryParse(dateStr.trim());
    }

    // Parse paths (defensive: only non-empty strings)
    final pathsRaw = map['paths'];
    final paths = <String>[];
    if (pathsRaw is List) {
      for (final p in pathsRaw) {
        if (p is String && p.trim().isNotEmpty) {
          paths.add(p.trim());
        }
      }
    }

    // Parse only_impacts (defensive: only non-empty strings). Legacy
    // five-bucket names map onto the three severities rules now report, so
    // `[low, medium]` keeps meaning what it meant; see [_legacyImpacts].
    final impactsRaw = map['only_impacts'];
    final onlyImpacts = <String>[];
    if (impactsRaw is List) {
      for (final i in impactsRaw) {
        if (i is String && i.trim().isNotEmpty) {
          final name = i.trim().toLowerCase();
          final mapped = _legacyImpacts[name] ?? name;
          if (!onlyImpacts.contains(mapped)) onlyImpacts.add(mapped);
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

  /// Pre-collapse impact names and the severity each became
  /// (`critical -> error`, `high`/`medium -> warning`,
  /// `low`/`opinionated -> info`).
  ///
  /// Why: rules report `LintImpact.name` (`error` / `warning` / `info`), so
  /// an unmapped `only_impacts: [low, medium]` would match nothing and
  /// silently baseline nothing. That was invisible while the line parser
  /// read every inline list as a plain string (and so as "no filter"); once
  /// inline lists parse, the documented legacy values must keep working.
  static const Map<String, String> _legacyImpacts = <String, String>{
    'critical': 'error',
    'high': 'warning',
    'medium': 'warning',
    'low': 'info',
    'opinionated': 'info',
  };

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
  /// Valid values: `error`, `warning`, `info` (legacy `critical`, `high`,
  /// `medium`, `low`, `opinionated` are mapped onto them when parsed).
  /// If empty, all impacts are baselined.
  final List<String> onlyImpacts;

  /// This config with the file-based part removed; `date`, `paths` and
  /// `only_impacts` are kept.
  ///
  /// Used while the `baseline` CLI regenerates the JSON: the JSON must not
  /// hide the findings being recorded, but findings already covered by
  /// `date:` / `paths:` must stay out of it, or editing those keys later
  /// would no longer un-baseline them.
  BaselineConfig withoutFile() =>
      BaselineConfig(date: date, paths: paths, onlyImpacts: onlyImpacts);

  /// Whether any baseline configuration is present.
  bool get isEnabled => file != null || date != null || paths.isNotEmpty;

  /// Whether a specific impact level should be baselined.
  ///
  /// Returns true if:
  /// - [onlyImpacts] is empty (baseline all), or
  /// - [impact] is in the [onlyImpacts] list
  /// Returns false if [impact] is null or empty.
  bool shouldBaselineImpact(String? impact) {
    if (impact == null || impact.isEmpty) return false;
    if (onlyImpacts.isEmpty) return true;
    return onlyImpacts.contains(impact.toLowerCase());
  }

  @override
  // Default nullable fields to '<unset>' so toString() never prints the
  // literal 'null' (avoid_nullable_interpolation).
  String toString() =>
      'BaselineConfig('
      'file: ${file ?? '<unset>'}, '
      'date: ${date ?? '<unset>'}, '
      'paths: $paths, '
      'onlyImpacts: $onlyImpacts)';
}
