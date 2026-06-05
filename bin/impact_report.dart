#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Backward-compatible alias for `severity_report`.
///
/// The tool was renamed from `impact_report` to `severity_report` on
/// 2026-06-05 after the `LintImpact` 5-bucket taxonomy collapsed into the
/// analyzer's 3-level severity model (error / warning / info), making the
/// "impact" name misleading. This forwarder keeps existing
/// `dart run saropa_lints:impact_report` invocations (CI scripts, docs,
/// muscle memory) working unchanged. New callers should use
/// `dart run saropa_lints:severity_report`.
library;

import 'severity_report.dart' as severity_report;

Future<void> main(List<String> args) => severity_report.main(args);
