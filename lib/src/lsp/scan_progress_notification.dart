/// Payload builder for the `saropa/scanProgress` custom LSP notification
/// (WP4, `plans/PLAN_ext_ui_dart_deferred.md`).
///
/// Pulled out of `bin/lsp_server.dart` as a pure function (no stdio, no
/// server state) purely so its JSON shape can be unit-tested directly — the
/// server itself is a JSON-RPC-over-stdio process with no test harness, so a
/// notification's exact keys would otherwise be unverifiable except by
/// running the whole process and parsing its stdout.
library;

/// Builds the `params` object for one `saropa/scanProgress` notification.
/// `filesScanned`/`totalFiles` let the Health Panel's engine card render
/// "scanning N/M files"; `diagnosticsPublished` is the running count so far
/// (files already analyzed even before the scan completes still contribute
/// real diagnostics the Problems panel shows).
///
/// [done] signals whether the scan has terminated (completed OR canceled).
/// Without it, a canceled scan's final tick has `filesScanned < totalFiles`,
/// so the client-side `scanning` flag never clears and the engine card shows
/// "scanning 300/1900" indefinitely while the server is idle. The client
/// tolerates a missing field (older servers) by falling back to the ratio.
Map<String, Object?> buildScanProgressNotification({
  required int filesScanned,
  required int totalFiles,
  required int diagnosticsPublished,
  bool done = false,
}) {
  return <String, Object?>{
    'filesScanned': filesScanned,
    'totalFiles': totalFiles,
    'diagnosticsPublished': diagnosticsPublished,
    'done': done,
  };
}
