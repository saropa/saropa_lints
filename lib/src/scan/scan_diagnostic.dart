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
    required this.severity,
    required this.problemMessage,
    this.correctionMessage,
  });

  final String ruleName;
  final String filePath;
  final int line;
  final int column;
  final int offset;
  final int length;
  final String severity;
  final String? problemMessage;
  final String? correctionMessage;

  @override
  // Default nullable problemMessage to an empty string so the output never
  // prints the literal 'null' (avoid_nullable_interpolation).
  String toString() =>
      '$severity - ${problemMessage ?? ''} - $filePath:$line:$column - $ruleName';
}
