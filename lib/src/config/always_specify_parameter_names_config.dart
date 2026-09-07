// ignore_for_file: depend_on_referenced_packages -- imports the package's own
// public entrypoint style used by sibling config files (banned_usage_config.dart)

/// User-configurable allowlist additions for `always_specify_parameter_names`.
///
/// Populated from `analysis_options_custom.yaml` under
/// `always_specify_parameter_names: allowlist:`. Lets a project add its own
/// idiomatic positional-pair constructors (e.g. a custom `Coordinate(lat, lng)`)
/// without a code change — the built-in allowlist only covers dart:ui/dart:math.
/// Loaded once at plugin start via [loadAlwaysSpecifyParameterNamesConfig] from
/// config_loader, mirroring [loadBannedUsageConfig]'s line-based parsing style.
/// Rule reads [userAllowlistedConstructors] at run time; no race because
/// analysis is single-threaded per plugin.
///
/// **Config format:** Parsing is line-based and does not support full YAML;
/// each entry must use `- class_name: '...'` followed by `library_uri: '...'`
/// and `max_args: N` on subsequent indented lines.
library;

import '../rules/code_quality/always_specify_parameter_names_helpers.dart'
    show AllowlistedConstructor;

/// User-configured allowlist additions. Set by
/// [loadAlwaysSpecifyParameterNamesConfig]. Empty by default (no-op) so a
/// project that never adds this section sees no behavior change.
List<AllowlistedConstructor> userAllowlistedConstructors = [];

/// Parse `always_specify_parameter_names: allowlist:` section from content
/// and populate [userAllowlistedConstructors]. Called from config_loader
/// during plugin start.
///
/// Expects format:
/// ```yaml
/// always_specify_parameter_names:
///   allowlist:
///     - class_name: 'Coordinate'
///       library_uri: 'package:my_app/models.dart'
///       max_args: 2
/// ```
void loadAlwaysSpecifyParameterNamesConfig(String? content) {
  userAllowlistedConstructors = [];
  if (content == null || content.trim().isEmpty) return;

  final sectionMatch = RegExp(
    r'^always_specify_parameter_names:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return;

  final afterSection = content.substring(sectionMatch.end);
  final allowlistMatch = RegExp(
    r'^\s+allowlist:\s*$',
    multiLine: true,
  ).firstMatch(afterSection);
  if (allowlistMatch == null) return;

  final lines = afterSection.substring(allowlistMatch.end).split('\n');
  String? currentClass;
  String? currentLibrary;
  int? currentMaxArgs;

  final classPattern = RegExp(
    '^\\s*-\\s*class_name:\\s*["\']?([^"\'\\s]+)["\']?\\s*\$',
  );
  final libraryPattern = RegExp(
    '^\\s+library_uri:\\s*["\']?([^"\'\\s]+)["\']?\\s*\$',
  );
  final maxArgsPattern = RegExp(r'^\s+max_args:\s*(\d+)\s*$');

  // Emits the entry accumulated so far, once all three fields are known.
  void flush() {
    if (currentClass != null &&
        currentLibrary != null &&
        currentMaxArgs != null) {
      userAllowlistedConstructors.add((
        className: currentClass,
        libraryUri: currentLibrary,
        maxArgs: currentMaxArgs,
      ));
    }
  }

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final classMatch = classPattern.firstMatch(line);
    if (classMatch != null) {
      // A new `- class_name:` line starts the next entry — flush the
      // previous one first (mirrors loadBannedUsageConfig's entry boundary).
      flush();
      currentClass = classMatch.group(1);
      currentLibrary = null;
      currentMaxArgs = null;
      continue;
    }
    final libMatch = libraryPattern.firstMatch(line);
    if (libMatch != null && currentClass != null) {
      currentLibrary = libMatch.group(1);
      continue;
    }
    final maxArgsMatch = maxArgsPattern.firstMatch(line);
    if (maxArgsMatch != null && currentClass != null) {
      // ignore: saropa_lints/avoid_null_assertion -- sole capture group is (\d+), non-null on match
      currentMaxArgs = int.tryParse(maxArgsMatch.group(1)!);
    }
  }
  flush();
}
