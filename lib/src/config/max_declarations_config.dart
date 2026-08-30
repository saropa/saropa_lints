/// Configuration for [PreferSingleDeclarationPerFileRule] and sealed hierarchy
/// size guidance.
///
/// Loaded from `analysis_options_custom.yaml`. Two settings:
///
/// ```yaml
/// max_declarations_per_file: 3     # default 1
/// max_sealed_hierarchy_lines: 200  # default 0 (disabled)
/// ```
library;

/// How many top-level class/enum/mixin declarations a single file may contain
/// before [PreferSingleDeclarationPerFileRule] fires. Excludes sealed-hierarchy
/// subtypes, private classes, and static-only utility namespaces (those are
/// always exempt regardless of this threshold).
///
/// Default: 1 (original behavior — one major declaration per file).
int maxDeclarationsPerFile = 1;

/// When a file contains a sealed class hierarchy AND exceeds this many lines,
/// the rule fires with a suggestion to use `part`/`part of` to split the
/// subtypes into separate files while keeping them in the same library.
///
/// Default: 0 (disabled — sealed hierarchies are never flagged for size).
/// Set to e.g. 200 to get a nudge when sealed hierarchy files grow large.
int maxSealedHierarchyLines = 0;

/// Parse declaration config from custom config content.
/// Called from config_loader during plugin start.
void loadMaxDeclarationsConfig(String? content) {
  // Reset to defaults each reload so removed config reverts cleanly
  maxDeclarationsPerFile = 1;
  maxSealedHierarchyLines = 0;
  if (content == null || content.trim().isEmpty) return;

  final declMatch = RegExp(
    r'^max_declarations_per_file:\s*(\d+)',
    multiLine: true,
  ).firstMatch(content);
  if (declMatch != null) {
    final parsed = int.tryParse(declMatch.group(1)!);
    // Floor at 1 — a threshold of 0 would flag every file
    if (parsed != null && parsed >= 1) {
      maxDeclarationsPerFile = parsed;
    }
  }

  final sealedMatch = RegExp(
    r'^max_sealed_hierarchy_lines:\s*(\d+)',
    multiLine: true,
  ).firstMatch(content);
  if (sealedMatch != null) {
    final parsed = int.tryParse(sealedMatch.group(1)!);
    // 0 = disabled; any positive value is a threshold
    if (parsed != null && parsed >= 0) {
      maxSealedHierarchyLines = parsed;
    }
  }
}
