/// Live progress + cooperative pause/cancel sink for [runSizeScan] (Project
/// Map / Project Health's `--progress` streaming mode, WP1 of
/// `plans/PLAN_ext_ui_dart_deferred.md`).
///
/// Deliberately duplicates `ProjectScanProgress` from
/// `lib/src/cli/project_vibrancy.dart` (the Code Health scan's identical
/// class) rather than importing it: the two CLIs are independent work
/// packages that concurrent agents may edit at the same time, and the plan's
/// contract is only to MIRROR the event schema exactly (same `event` /
/// `phase` / `done` / `total` / `file` keys), not to share the type. Keeping
/// them as separate, structurally-identical classes means an edit to one
/// scan's progress plumbing can never conflict with or accidentally break
/// the other's.
library;

/// Progress sink handed to `runSizeScan` when the CLI is invoked with
/// `--progress`. `onEvent` streams one NDJSON-ready event map per call (the
/// CLI's `bin/project_health.dart` serializes each to a line on stderr —
/// stdout stays reserved for the final report). `gate` is awaited before each
/// file the scan measures, giving `--control <path>` a cooperative point to
/// pause (block until resumed) or cancel (throw) the scan.
class ProjectScanProgress {
  ProjectScanProgress({required this.onEvent, required this.gate});

  /// Receives one progress event map per call (`meta` / `phase` / `tick` /
  /// `done`). Same event shape as project_vibrancy's `--progress` so the
  /// extension's existing NDJSON parser (`VibrancyScanEvent` /
  /// `tryParseEvent`) can be reused for this CLI without a second parser.
  final void Function(Map<String, Object?> event) onEvent;

  /// Awaited before each file is measured. Resolves instantly while running,
  /// suspends while paused, and throws when the control file requests
  /// `cancel` — the CLI's `main()` catches that and exits clean with no
  /// partial report on stdout.
  final Future<void> Function() gate;
}
