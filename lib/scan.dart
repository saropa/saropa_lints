/// Programmatic scan API for saropa_lints.
///
/// Use this when you want to run a scan from code (e.g. from another
/// package or script) without invoking the CLI. The types and functions
/// here are part of the public API and follow semver.
///
/// Example:
/// ```dart
/// import 'package:saropa_lints/scan.dart';
///
/// void main() {
///   final runner = ScanRunner(
///     targetPath: '/path/to/project',
///     tier: 'recommended',           // optional: override config with a tier
///     dartFiles: ['lib/main.dart'],   // optional: scan only these files
///     messageSink: (msg) => log(msg), // optional: redirect/suppress output
///   );
///   final diagnostics = runner.run();
///   if (diagnostics != null) {
///     // process diagnostics or serialize with scanDiagnosticsToJson(diagnostics)
///   }
/// }
/// ```
library;

export 'src/scan/scan_config.dart' show ScanConfig, loadScanConfig;
export 'src/scan/scan_diagnostic.dart' show ScanDiagnostic;
export 'src/scan/scan_runner.dart' show ScanMessageSink, ScanRunner;
export 'src/scan/scan_json.dart' show scanDiagnosticsToJson, scanDiagnosticsToJsonString;
