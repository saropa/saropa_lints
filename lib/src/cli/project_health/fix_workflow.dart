/// Dead-code "fix" workflow. Per project policy this NEVER deletes in place and
/// NEVER comments code out — it emits a reviewable `git rm` script the developer
/// inspects and runs (or not). git makes it fully reversible.
library;

/// Builds a removal script for [deadFiles] (project-relative paths), or an empty
/// string when there is nothing to remove. The script is written to disk by the
/// CLI; it is never executed automatically.
String buildRemovalScript(List<String> deadFiles) {
  if (deadFiles.isEmpty) return '';
  final buffer = StringBuffer()
    ..writeln('#!/usr/bin/env bash')
    ..writeln('# Saropa Lints — dead-file removal. REVIEW before running.')
    ..writeln(
      '# Each file was flagged as having no importers. Verify it is not',
    )
    ..writeln(
      '# an entry point, generated, or referenced via reflection first.',
    )
    ..writeln('# git keeps this reversible (git restore / git revert).')
    ..writeln('set -euo pipefail')
    ..writeln();
  for (final file in deadFiles) {
    buffer.writeln('git rm -- ${_shellQuote(file)}');
  }
  return buffer.toString();
}

/// Single-quotes a path for bash, escaping embedded single quotes.
String _shellQuote(String path) => "'${path.replaceAll("'", r"'\''")}'";
