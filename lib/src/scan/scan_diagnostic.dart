/// Diagnostic result from the standalone scan command.
library;

/// A single lint diagnostic found during scanning.
class ScanDiagnostic {
  const ScanDiagnostic({
    required this.ruleName,
    required this.filePath,
    required this.line,
    required this.column,
    required this.offset,
    required this.length,
    required this.endLine,
    required this.endColumn,
    required this.severity,
    required this.problemMessage,
    this.correctionMessage,
    this.impact,
  });

  final String ruleName;
  final String filePath;

  /// 1-based start line.
  final int line;

  /// 1-based start column.
  final int column;
  final int offset;
  final int length;

  /// 1-based end line (inclusive).
  final int endLine;

  /// 1-based end column (exclusive — one past the last highlighted character).
  final int endColumn;
  final String severity;
  final String? problemMessage;
  final String? correctionMessage;

  /// Rule-declared impact level (error, warning, info), independent of the
  /// analyzer severity. Null for non-saropa diagnostics that have no impact.
  final String? impact;

  @override
  // Default nullable problemMessage to an empty string so the output never
  // prints the literal 'null' (avoid_nullable_interpolation).
  String toString() =>
      '$severity - ${problemMessage ?? ''} - $filePath:$line:$column - $ruleName';
}
