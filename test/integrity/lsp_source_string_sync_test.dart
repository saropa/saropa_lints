import 'dart:io';

import 'package:test/test.dart';

/// Cross-language sync test: asserts that the diagnostic source string in
/// bin/lsp_server.dart matches the LSP_TEST_DIAGNOSTIC_SOURCE constant in
/// extension/src/liveDiagnosticsModel.ts.
///
/// Without this test, renaming the source on one side silently breaks the
/// filter on the other — fake diagnostics start inflating real scores with
/// no compile-time or runtime error.
void main() {
  test('lsp_server.dart source matches liveDiagnosticsModel.ts constant', () {
    // Read the Dart LSP server source — look for the 'source': '...' line.
    final dartFile = File('bin/lsp_server.dart');
    expect(
      dartFile.existsSync(),
      isTrue,
      reason: 'bin/lsp_server.dart must exist',
    );

    final dartContent = dartFile.readAsStringSync();

    // Extract the source string from the Dart file's diagnostic object.
    // Pattern: 'source': '<value>'
    final dartMatch = RegExp(
      r"'source'\s*:\s*'([^']+)'",
    ).firstMatch(dartContent);
    expect(
      dartMatch,
      isNotNull,
      reason: 'bin/lsp_server.dart must set a diagnostic source string',
    );
    final dartSource = dartMatch!.group(1)!;

    // Read the TypeScript liveDiagnosticsModel — look for the named constant.
    final tsFile = File('extension/src/liveDiagnosticsModel.ts');
    expect(
      tsFile.existsSync(),
      isTrue,
      reason: 'extension/src/liveDiagnosticsModel.ts must exist',
    );

    final tsContent = tsFile.readAsStringSync();

    // Extract the constant value from the TS file.
    // Pattern: LSP_TEST_DIAGNOSTIC_SOURCE = '<value>'
    final tsMatch = RegExp(
      r"LSP_TEST_DIAGNOSTIC_SOURCE\s*=\s*'([^']+)'",
    ).firstMatch(tsContent);
    expect(
      tsMatch,
      isNotNull,
      reason:
          'liveDiagnosticsModel.ts must export '
          'LSP_TEST_DIAGNOSTIC_SOURCE',
    );
    final tsSource = tsMatch!.group(1)!;

    // The two must match exactly — a mismatch means the filter silently
    // stops working and fake diagnostics inflate real scores.
    expect(
      dartSource,
      equals(tsSource),
      reason:
          'Dart diagnostic source must match TS filter constant. '
          'If you renamed one side, update the other.',
    );
  });
}
