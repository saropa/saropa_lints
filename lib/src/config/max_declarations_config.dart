/// Configuration for [PreferSingleDeclarationPerFileRule].
///
/// Loaded from `analysis_options_custom.yaml` under `max_declarations_per_file:`.
/// Default is 1 (flag any file with more than one major top-level declaration).
/// Set higher to allow small co-located data classes without triggering the lint.
///
/// ```yaml
/// max_declarations_per_file: 3
/// ```
library;

/// How many top-level class/enum/mixin declarations a single file may contain
/// before [PreferSingleDeclarationPerFileRule] fires. Excludes sealed-hierarchy
/// subtypes, private classes, and static-only utility namespaces (those are
/// always exempt regardless of this threshold).
///
/// Default: 1 (original behavior — one major declaration per file).
int maxDeclarationsPerFile = 1;

/// Parse `max_declarations_per_file:` from custom config content.
/// Called from config_loader during plugin start.
void loadMaxDeclarationsConfig(String? content) {
  // Reset to default each reload so removed config reverts to 1
  maxDeclarationsPerFile = 1;
  if (content == null || content.trim().isEmpty) return;

  final match = RegExp(
    r'^max_declarations_per_file:\s*(\d+)',
    multiLine: true,
  ).firstMatch(content);
  if (match == null) return;

  final parsed = int.tryParse(match.group(1)!);
  // Floor at 1 — a threshold of 0 would flag every file
  if (parsed != null && parsed >= 1) {
    maxDeclarationsPerFile = parsed;
  }
}
