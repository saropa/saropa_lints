/// Text report behind `dart run saropa_lints:baseline --explain <file>`.
///
/// Matching is done by [BaselineManager.explain], the same code that hides
/// findings during analysis; this file only loads the file's own project
/// configuration and words the result.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'baseline_activation.dart';
import 'baseline_config.dart';
import 'baseline_manager.dart';

/// Describes which baseline settings hide findings in [filePath] (absolute),
/// with [env] applied as the plugin would apply it.
Future<String> explainBaseline(String filePath, Map<String, String> env) async {
  // Per-project lookup, as in the plugin: the nearest enclosing package that
  // configures a baseline governs the file.
  BaselineManager.enablePerRoot((root) {
    final options = File(p.join(root, kBaselineConfigFileName));
    return baselineConfigFromContent(
      options.existsSync() ? options.readAsStringSync() : null,
      env,
    );
  });
  final found = await BaselineManager.explain(filePath);
  BaselineManager.reset();

  final out = StringBuffer('Baseline for $filePath\n');
  if (isBaselineSkippedByEnv(env)) {
    out.writeln('$kSkipBaselineEnvVar is set: the JSON file is ignored.');
  }
  if (found == null) {
    out.writeln(
      'No baseline applies: no enclosing package has a usable baseline: '
      'section in $kBaselineConfigFileName. Nothing is hidden.',
    );
    return out.toString().trimRight();
  }
  out
    ..writeln('Project: ${found.root ?? '<unknown>'}')
    ..writeln('Path matched against patterns: ${found.relativePath}')
    ..writeln(_impactLine(found.config))
    ..writeln(_pathsLine(found))
    ..write(_fileLines(found))
    ..writeln(_dateLine(found));
  return out.toString().trimRight();
}

/// `only_impacts` narrows every other setting, so it is reported first.
String _impactLine(BaselineConfig config) => config.onlyImpacts.isEmpty
    ? 'only_impacts: not set; the settings below apply to every severity.'
    : 'only_impacts: the settings below hide only '
          '${config.onlyImpacts.join(', ')} findings; others still show.';

/// Which `paths:` patterns cover the file.
String _pathsLine(BaselineExplanation found) {
  if (found.config.paths.isEmpty) return 'paths: not set.';
  if (found.matchedPatterns.isEmpty) return 'paths: no pattern matches.';
  return 'paths: matched ${found.matchedPatterns.join(', ')}; '
      'every finding in this file is hidden.';
}

/// The JSON entries for the file, one rule per line.
String _fileLines(BaselineExplanation found) {
  final name = found.config.file;
  if (name == null) return 'file: not set.\n';
  if (!found.fileLoaded) {
    return 'file: $name was not found or is unreadable; it hides nothing.\n';
  }
  if (found.fileEntries.isEmpty) return 'file: $name has no entry here.\n';
  final out = StringBuffer('file: $name hides these findings:\n');
  for (final rule in found.fileEntries.keys.toList()..sort()) {
    out.writeln('  $rule: line ${found.fileEntries[rule]?.join(', ')}');
  }
  return out.toString();
}

/// How many lines `date:` covers, from the same blame data analysis uses.
String _dateLine(BaselineExplanation found) {
  final date = found.config.date;
  if (date == null) return 'date: not set.';
  final day = date.toIso8601String().split('T').first;
  final old = found.oldLines;
  if (old == null) {
    return 'date: $day; git blame gave no line dates for this file.';
  }
  return 'date: $day; findings on ${old.length} line(s) last committed before '
      'it are hidden. Uncommitted lines still report.';
}
