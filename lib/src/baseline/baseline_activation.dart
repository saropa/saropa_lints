/// Where and how a baseline is switched on, shared by the `baseline` CLI
/// (which writes the activation) and the config loader (which reads it).
///
/// Keeping both sides here is the fix for a mismatch where the CLI inserted
/// `baseline:` indented under `plugins: saropa_lints:` in
/// `analysis_options.yaml` while the loader only reads a top-level
/// `baseline:` key in `analysis_options_custom.yaml`, so a generated
/// baseline was never activated.
library;

/// File that holds the `baseline:` section. The loader reads it from the
/// project root; the CLI writes it there.
const String kBaselineConfigFileName = 'analysis_options_custom.yaml';

/// Environment variable that makes the plugin skip loading the baseline.
///
/// The `baseline` CLI sets it on the `dart analyze` run it spawns. Without
/// it, an already-active baseline hides its own findings from that run, so
/// regenerating (or `--update`) would drop every still-present entry and
/// the next analysis would show them all again.
const String kSkipBaselineEnvVar = 'SAROPA_LINTS_SKIP_BASELINE';

/// Top-level `baseline:` key, as the loader matches it.
final RegExp _topLevelBaselineKey = RegExp(r'^baseline:\s*$', multiLine: true);

/// Indented `baseline:` key, which is where older CLI versions wrote the
/// activation (inside the plugin block of `analysis_options.yaml`).
final RegExp _nestedBaselineKey = RegExp(
  r'^[ \t]+baseline:\s*$',
  multiLine: true,
);

/// True when [env] asks the plugin to skip the baseline. Any non-empty
/// value other than `0` / `false` counts, so `=1` and `=true` both work.
bool isBaselineSkippedByEnv(Map<String, String> env) {
  final value = env[kSkipBaselineEnvVar]?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value != '0' && value != 'false';
}

/// Returns [existing] custom-options text with a top-level `baseline:`
/// section naming [baselinePath] appended, or null when a top-level
/// `baseline:` key is already there (the user's own config wins; a second
/// key would be a YAML duplicate). [existing] may be empty for a new file.
String? addBaselineActivation(String existing, String baselinePath) {
  // CRLF normalized only for the check; the appended text matches the
  // file's own line ending so a Windows-edited file stays consistent.
  if (_topLevelBaselineKey.hasMatch(existing.replaceAll('\r\n', '\n'))) {
    return null;
  }
  final eol = existing.contains('\r\n') ? '\r\n' : '\n';
  final sep = existing.isEmpty || existing.endsWith('\n') ? '' : eol;
  // Quoted so a path with spaces or `#` stays one scalar. Forward slashes
  // because the loader's line parser strips quotes but not escapes, so a
  // Windows backslash path would otherwise need YAML escaping it ignores.
  final quoted = baselinePath.replaceAll('\\', '/');
  return '$existing${sep}baseline:$eol  file: "$quoted"$eol';
}

/// True when [analysisOptions] still carries an indented `baseline:` key
/// left by an older CLI run. The loader never read it, so the CLI tells the
/// user it can be removed rather than leaving two conflicting settings.
bool hasLegacyNestedBaseline(String analysisOptions) =>
    _nestedBaselineKey.hasMatch(analysisOptions.replaceAll('\r\n', '\n'));
