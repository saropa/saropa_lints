/// Pins the JSON shape of the `saropa/scanProgress` custom LSP notification
/// (WP4, `plans/PLAN_ext_ui_dart_deferred.md`). The LSP server itself
/// (`bin/lsp_server.dart`) is a JSON-RPC-over-stdio process with no test
/// harness, so `buildScanProgressNotification` is the testable seam: it is
/// the exact `params` object `_sendScanProgress` hands to `_sendNotification`.
library;

import 'package:saropa_lints/src/lsp/scan_progress_notification.dart';
import 'package:test/test.dart';

void main() {
  test('emits filesScanned/totalFiles/diagnosticsPublished/done', () {
    final payload = buildScanProgressNotification(
      filesScanned: 812,
      totalFiles: 1900,
      diagnosticsPublished: 47,
    );
    // In-progress tick: done defaults to false.
    expect(payload, <String, Object?>{
      'filesScanned': 812,
      'totalFiles': 1900,
      'diagnosticsPublished': 47,
      'done': false,
    });
  });

  test('a zero-progress "scan started" tick reports 0 scanned, real total', () {
    // _analyzeWorkspace sends this before the loop starts so the client can
    // render "0/N" immediately rather than a dead 0% with no denominator.
    final payload = buildScanProgressNotification(
      filesScanned: 0,
      totalFiles: 250,
      diagnosticsPublished: 0,
    );
    expect(payload['filesScanned'], 0);
    expect(payload['totalFiles'], 250);
    expect(payload['diagnosticsPublished'], 0);
    expect(payload['done'], isFalse);
  });

  test('terminal tick carries done: true (cancel or completion)', () {
    // A canceled scan's final tick has filesScanned < totalFiles but still
    // signals completion — without `done`, the client's engine card stays
    // stuck on "scanning" forever because the ratio never reaches 1.
    final canceled = buildScanProgressNotification(
      filesScanned: 300,
      totalFiles: 1900,
      diagnosticsPublished: 12,
      done: true,
    );
    expect(canceled['done'], isTrue);

    // A normally completed scan also sends done: true on the final tick.
    final completed = buildScanProgressNotification(
      filesScanned: 1900,
      totalFiles: 1900,
      diagnosticsPublished: 47,
      done: true,
    );
    expect(completed['done'], isTrue);
    expect(completed['filesScanned'], completed['totalFiles']);
  });
}
