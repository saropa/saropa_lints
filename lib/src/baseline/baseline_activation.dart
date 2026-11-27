/// Where and how a baseline is switched on, shared by the `baseline` CLI
/// (which writes the activation) and the config loader (which reads it).
///
/// Keeping both sides here is the fix for a mismatch where the CLI inserted
/// `baseline:` indented under `plugins: saropa_lints:` in
/// `analysis_options.yaml` while the loader only reads a top-level
/// `baseline:` key in `analysis_options_custom.yaml`, so a generated
/// baseline was never activated.
library;

import 'baseline_config.dart';
import 'baseline_section_parser.dart';

/// File that holds the `baseline:` section. The loader reads it from the
/// project root; the CLI writes it there.
const String kBaselineConfigFileName = 'analysis_options_custom.yaml';

/// Environment variable that makes the plugin skip the baseline JSON file
/// (`date:` and `paths:` still apply).
///
/// The `baseline` CLI sets it on the `dart analyze` run it spawns. Without
/// it, an already-active baseline hides its own findings from that run, so
/// regenerating (or `--update`) would drop every still-present entry and
/// the next analysis would show them all again.
const String kSkipBaselineEnvVar = 'SAROPA_LINTS_SKIP_BASELINE';

/// Indented `baseline:` key, which is where older CLI versions wrote the
/// activation (inside the plugin block of `analysis_options.yaml`).
final RegExp _nestedBaselineKey = RegExp(
  r'^[ \t]+baseline:\s*$',
  multiLine: true,
);

/// True when [env] asks the plugin to skip the baseline file. Any non-empty
/// value other than `0` / `false` counts, so `=1` and `=true` both work.
bool isBaselineSkippedByEnv(Map<String, String> env) {
  final value = env[kSkipBaselineEnvVar]?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value != '0' && value != 'false';
}

/// The part of [config] in force under [env]. The skip variable removes the
/// JSON file only: dropping `date:` / `paths:` too would make regeneration
/// copy every finding they already cover into the JSON.
BaselineConfig baselineConfigForEnv(
  BaselineConfig config,
  Map<String, String> env,
) => isBaselineSkippedByEnv(env) ? config.withoutFile() : config;

/// The baseline in force for custom-options [content] under [env], or null
/// for none. One entry point for the config loader and `baseline --explain`,
/// so the CLI cannot disagree with what analysis loads.
BaselineConfig? baselineConfigFromContent(
  String? content,
  Map<String, String> env,
) {
  if (content == null) return null;
  final header = kBaselineSectionHeader.firstMatch(content);
  if (header == null) return null;
  final configured = BaselineConfig.fromYaml(
    parseBaselineSection(content, header.end),
  );
  final config = baselineConfigForEnv(configured, env);
  return config.isEnabled ? config : null;
}

/// How [planBaselineActivation] makes the custom options reference the
/// baseline file.
enum BaselineActivationKind {
  /// No top-level `baseline:` section existed; one was appended.
  appended,

  /// A `baseline:` section existed without `file:`; the key was added.
  fileAdded,

  /// A `baseline:` section named a different file; `file:` was changed.
  fileReplaced,

  /// The section already names this file; nothing to write.
  alreadyActive,
}

/// Result of [planBaselineActivation]: the new file text (null when nothing
/// changes) plus the `file:` lines involved, so the CLI can show them.
class BaselineActivation {
  const BaselineActivation(
    this.kind,
    this.text, {
    required this.fileLine,
    this.previousFileLine,
  });

  /// What was done to the custom options.
  final BaselineActivationKind kind;

  /// Full new content to write, or null for [BaselineActivationKind.alreadyActive].
  final String? text;

  /// The `file:` line (trimmed) now in effect.
  final String fileLine;

  /// The replaced `file:` line (trimmed), for [BaselineActivationKind.fileReplaced].
  final String? previousFileLine;
}

/// `file:` key line inside the section; group 1 is the indent, 2 the value.
final RegExp _fileKeyLine = RegExp(r'^([ \t]+)file:\s*(.*)$');

/// First indented, non-blank line of a section; group 1 is its indent.
final RegExp _childLine = RegExp(r'^([ \t]+)\S');

/// Plans the edit that makes [existing] custom-options text activate
/// [baselinePath]. [existing] may be empty for a new file.
///
/// Why not leave an existing section alone: a `baseline:` section holding
/// only `date:` / `paths:`, or naming another JSON file, used to be kept as
/// is, so the JSON this run just wrote was never referenced and the CLI's
/// "Done" was false. The section's other keys and comments are preserved;
/// only the `file:` line is added or changed.
BaselineActivation planBaselineActivation(
  String existing,
  String baselinePath,
) {
  // Quoted so a path with spaces or `#` stays one scalar. Forward slashes
  // because the loader's line parser strips quotes but not escapes, so a
  // Windows backslash path would otherwise need YAML escaping it ignores.
  final quoted = baselinePath.replaceAll('\\', '/');
  final eol = existing.contains('\r\n') ? '\r\n' : '\n';
  // Lines without their `\r`, so matching ignores CRLF; [eol] restores it.
  final lines = existing.replaceAll('\r\n', '\n').split('\n');
  final header = lines.indexWhere((l) => kBaselineSectionHeader.hasMatch(l));
  if (header == -1) {
    final sep = existing.isEmpty || existing.endsWith('\n') ? '' : eol;
    final line = 'file: "$quoted"';
    return BaselineActivation(
      BaselineActivationKind.appended,
      '$existing${sep}baseline:$eol  $line$eol',
      fileLine: line,
    );
  }
  return _editSection(lines, header, quoted, eol);
}

/// Adds or rewrites the `file:` line of the section whose header is at
/// [header] in [lines]. Split from [planBaselineActivation] for length.
BaselineActivation _editSection(
  List<String> lines,
  int header,
  String quoted,
  String eol,
) {
  final end = _sectionEnd(lines, header);
  var indent = '  ';
  for (var i = header + 1; i < end; i++) {
    final match = _fileKeyLine.firstMatch(lines[i]);
    if (match == null) continue;
    final current = unquoteYamlScalar(stripYamlComment(match.group(2) ?? ''));
    final line = 'file: "$quoted"';
    if (_samePath(current, quoted)) {
      return BaselineActivation(
        BaselineActivationKind.alreadyActive,
        null,
        fileLine: lines[i].trim(),
      );
    }
    final previous = lines[i].trim();
    lines[i] = '${match.group(1)}$line';
    return BaselineActivation(
      BaselineActivationKind.fileReplaced,
      lines.join(eol),
      fileLine: line,
      previousFileLine: previous,
    );
  }
  // No `file:` key: match the indent of the section's first child line.
  for (var i = header + 1; i < end; i++) {
    final child = _childLine.firstMatch(lines[i]);
    if (child != null && !lines[i].trimLeft().startsWith('#')) {
      indent = child.group(1)!;
      break;
    }
  }
  final line = 'file: "$quoted"';
  lines.insert(header + 1, '$indent$line');
  return BaselineActivation(
    BaselineActivationKind.fileAdded,
    lines.join(eol),
    fileLine: line,
  );
}

/// Index just past the last line of the section headed at [header]: the
/// first later line that is non-blank, not a comment and not indented.
int _sectionEnd(List<String> lines, int header) {
  for (var i = header + 1; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) return i;
  }
  return lines.length;
}

/// Path equality as the loader sees it: slashes unified, `./` dropped.
bool _samePath(String a, String b) {
  String norm(String s) {
    final v = s.replaceAll('\\', '/');
    return v.startsWith('./') ? v.substring(2) : v;
  }

  return norm(a) == norm(b);
}

/// Returns [existing] with the baseline activated for [baselinePath], or
/// null when the custom options already name that file. Thin wrapper over
/// [planBaselineActivation] for callers that only need the text.
String? addBaselineActivation(String existing, String baselinePath) =>
    planBaselineActivation(existing, baselinePath).text;

/// One-line, user-facing description of [activation] for the CLI, naming
/// [fileName] and showing the `file:` line(s) involved.
String describeBaselineActivation(
  BaselineActivation activation,
  String fileName,
) {
  return switch (activation.kind) {
    BaselineActivationKind.appended =>
      'Added a baseline: section to $fileName (${activation.fileLine})',
    BaselineActivationKind.fileAdded =>
      'Added "${activation.fileLine}" to the existing baseline: section '
          'in $fileName',
    BaselineActivationKind.fileReplaced =>
      'Changed the baseline file in $fileName: '
          '"${activation.previousFileLine}" is now "${activation.fileLine}"',
    BaselineActivationKind.alreadyActive =>
      'Note: $fileName already references this baseline '
          '(${activation.fileLine})',
  };
}

/// True when [analysisOptions] still carries an indented `baseline:` key
/// left by an older CLI run. The loader never read it, so the CLI tells the
/// user it can be removed rather than leaving two conflicting settings.
bool hasLegacyNestedBaseline(String analysisOptions) =>
    _nestedBaselineKey.hasMatch(analysisOptions.replaceAll('\r\n', '\n'));
