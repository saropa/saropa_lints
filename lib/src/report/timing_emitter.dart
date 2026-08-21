/// Flushes [RuleTimingTracker] data to disk after a profiled scan run.
///
/// **Why this exists.** The per-rule timing chain (`SaropaContext._wrapCallback`
/// -> `RuleTimingTracker.record`) has collected data for years but nothing ever
/// emitted it: `ReportWriter.writeReports()` is stubbed (its `_getIoLibrary()`
/// returns null) and has zero call sites, so every profiling run silently
/// discarded its measurements. This emitter is the missing last mile — it
/// writes the tracker's accumulated per-rule totals to a stable JSON file that
/// tooling (and the performance campaign's baseline phase) can consume.
///
/// **Where the file goes.** `<projectRoot>/reports/.saropa_lints/rule_timings.json`
/// — the same directory the plugin already uses for `violations.json` and
/// `plugin.log`, so the VS Code extension's existing report-directory watcher
/// conventions apply and users know where to look.
///
/// **Process model.** Designed for the out-of-process scan CLI (`--profile`),
/// which shares the `_wrapCallback` hot path with the in-editor plugin. The
/// in-editor plugin cannot be re-instrumented locally (the analyzer caches a
/// compiled plugin build), so the scan CLI is the only local source of
/// per-rule timing truth.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../saropa_lint_rule.dart' show RuleTimingTracker;

/// Writes the current [RuleTimingTracker] contents to
/// `<projectRoot>/reports/.saropa_lints/rule_timings.json`.
///
/// Returns the absolute path of the written file, or null when the tracker
/// holds no data (profiling was off, or no rule callbacks ran) — callers use
/// the null to warn that profiling produced nothing rather than silently
/// claiming success, which is exactly the failure mode this file exists to
/// eliminate.
///
/// [tier] and [resolved] are run metadata: a timing profile is only
/// comparable to another profile taken with the same rule set and resolution
/// mode, so the file must record how it was produced.
String? writeRuleTimingReport({
  required String projectRoot,
  String? tier,
  bool resolved = false,
  int? fileCount,
}) {
  final entries = RuleTimingTracker.sortedTimingsJson;
  if (entries.isEmpty) return null;

  // Same directory as violations.json / plugin.log so all plugin-produced
  // artifacts live in one place the user (and extension) already knows.
  final dir = Directory(
    // normalize() strips a trailing '.' segment when the CLI is invoked with
    // the default path '.', so the printed report path is clean.
    p.normalize(p.join(p.absolute(projectRoot), 'reports', '.saropa_lints')),
  );
  // recursive:true also covers a project that has never produced reports/.
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final file = File(p.join(dir.path, 'rule_timings.json'));
  // UTC timestamp (prefer_utc_for_storage): profiles are diffed across
  // machines and time zones when comparing before/after runs.
  final payload = <String, Object?>{
    'generatedUtc': DateTime.now().toUtc().toIso8601String(),
    'tier': tier,
    'resolved': resolved,
    'fileCount': fileCount,
    'ruleCount': entries.length,
    // Rules that crossed the 50 ms deferral threshold at least once — the
    // primary suspects for the per-rule remediation lane.
    'slowRules': RuleTimingTracker.slowRules.toList()..sort(),
    // Slowest-first list of {ruleName, totalMs, callCount, avgMs}.
    'timings': entries,
  };
  // Indented JSON: the file is small (one entry per rule) and humans read it
  // directly during triage, so legibility beats compactness here.
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
  return file.path;
}
