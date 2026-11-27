# `dart analyze <parent folder>` reports plugin findings for only one of two packages

Status: Fixed 2026-11-27 (in-repo part). The parent-folder `dart analyze` gap is upstream in the Dart analysis server and cannot be fixed here; it is documented as a known limit. The related in-repo flaw (scan CLI, scan daemon and LSP server using one package's baseline for every package) is fixed. Upstream issue drafted below; not posted.

## Finish report (2026-11-27)

**Cause (SDK, confirmed from source).** `pkg/analysis_server/lib/src/plugin/notification_manager.dart` keeps a single `bool pluginStatusAnalyzing` for all plugin isolates; each `plugin.status` notification overwrites it. `legacy_analysis_server.dart` `_performOnIdleActions` reports `isAnalyzing = serverStatusAnalyzing || isPluginAnalyzing || !pluginManager.initializedCompleter.isCompleted`, and `initializedCompleter` completes on the first status notification from any isolate. `pkg/dartdev/lib/src/analysis_server.dart` completes `analysisFinished` on the first `server.status` `isAnalyzing: false` and has no plugin-specific wait. So when the first package's isolate reports "not analyzing" and the server is idle, `dart analyze` exits, even if the second package's isolate has not yet sent its first status. The control-plugin runs below (3 s delay reproduces it with no saropa code) match this exactly. saropa_lints' `start()` is synchronous; the extra startup time is isolate load plus registering 2350+ rules, which can be reduced but not made race-free from the plugin side.

**In-repo flaw fixed.** `_loadBaselineConfig` in `lib/src/native/config_loader.dart` turned on per-package baseline lookup (`BaselineManager.enablePerRoot`) only when the in-server plugin had started. The scan CLI, scan daemon and LSP server never start the plugin but reload config once per process from the first analyzed file's package (`SaropaContext._ensureConfigLoadedFromProjectRoot`), so one package's baseline governed every file. Per-root lookup is now on for every caller. Accepted lists were already per root on all paths (`filterAcceptedByNearestRoot`).

**Tests.** New `test/baseline/baseline_cli_roots_test.dart` (failed before the fix: second package's `paths:` baseline not applied; passes after). `test/baseline/baseline_reload_and_explain_test.dart` adjusted: it re-initialized the manager directly after a loader reload, which per-root mode now overrides, so it calls `resetConfig()` first; its subject (blame answers survive) is unchanged. Ran `test/baseline/`, `test/accepted/reporter_multi_root_test.dart`, `test/native/config_loader_project_root_test.dart`.

**Docs.** `doc/guides/configuration.md` "Folders with several packages" states the limit and the per-package workaround.

**Unverified.** No `dart analyze` or scan run was made in this pass against `D:\tmp\accepted_check\live` copies after the fix. Other first-package-only settings on the scan/LSP paths (enabled rules, severity overrides, rule packs and the rest listed under "Config latch") remain as described below. Live editor behaviour (step 30) not run.

## Setup

`D:\tmp\accepted_check\live\` holds two packages, `one` and `two`. The parent folder has no `pubspec.yaml` and no `analysis_options.yaml`. Both packages turn on the plugin from `D:/src/saropa_lints` with `avoid_catch_all` and `avoid_print_error`, and both have the same `lib\g.dart`.

- `one`: `saropa_accepted.yaml` accepts `avoid_catch_all` with `max: 1`.
- `two`: `analysis_options_custom.yaml` names `saropa_baseline.json`, which hides `avoid_print_error`.

## Observed

`dart analyze D:\tmp\accepted_check\live` (exit 2): `3 issues found.`, all in `one\`:

- `one\lib\g.dart:6` `avoid_print_error`
- `one\lib\g.dart:13` `avoid_catch_all`
- `one\lib\g.dart:14` `avoid_print_error`

`dart analyze D:\tmp\accepted_check\live\two` (exit 2): `2 issues found.`, `avoid_catch_all` on lines 5 and 13.

## Expected

5 issues from the parent-folder run: the 3 above plus the 2 in `two`.

## Diagnosis (evidence)

All runs used Dart 3.14.0 stable on Windows, analysis_server_plugin 0.3.26 and analyzer 14.7.0. Copies are under `D:\tmp\parent_diag`, and an instrumented copy of the package is in `D:\tmp\saropa_diag_pkg`.

1. **Order decides which package reports.** I renamed the packages to `a_two` and `z_one`. The parent run then reported only `a_two` (2 issues, with its baseline applied correctly) and nothing for `z_one`. The package that sorts first always reports; the second never does.
2. **The server starts one plugin isolate per package.** A trace from the instrumented copy showed two plugin isolates. Each one ran `register()` and `start()`, about 48 s apart, because each gets its own entrypoint compile under `.plugin_manager`. Only the first isolate ever had `registerNodeProcessors` called, and only for `one\lib\g.dart`. The second isolate never had `registerNodeProcessors` called for any file. The trace point was the first line of the method, before the `isDisabled` check. So no saropa_lints code ever ran on `two`'s files.
3. **The CLI exits before the second isolate does any work.** In one traced run the second isolate finished `start()` at 02:34:38.45, the first isolate analyzed `one` at 02:34:38.88, and `dart analyze` exited at 02:34:39.09. That left 0.64 s. Nothing more appeared in the trace afterwards.
4. **A minimal control plugin shows the same failure, so the cause is not saropa_lints.** The control is `D:\tmp\min_plugin`: one `AnalysisRule` that reports every catch clause, with no saropa code. On the same two-package layout (`D:\tmp\min_parent`):
   - With a synchronous `start()`, both isolates analyze their own package and `dart analyze` reports 4 issues. This held with `registerWarningRule`, with `registerLintRule` plus `diagnostics:`, and with the plugin as a dev dependency.
   - With `start()` changed to `await Future.delayed(Duration(seconds: 3))`, the parent run reports **2 issues, only `one`**. The second isolate logged `REGISTER` and `START` but no `registerNodeProcessors` before the CLI exited.
   - So `dart analyze` drops the results of any plugin isolate that is not ready within a short window after the server's own analysis finishes. saropa_lints hits this window without any delay: its second isolate needs more than 0.64 s from `start()` to a first analysis.
5. **The config latch does not cause this.** `SaropaContext._configReloadAttempted` and `PluginLogger.setProjectRoot` are static, so they are per isolate, and the server gives each package its own isolate. In the swapped run `a_two` loaded its own config (`Config loaded from …/a_two`, baseline applied). The missing package fails because no rule ever runs on its files.

## Config latch (separate, latent)

The latch only matters when **one** analysis context root holds several packages, such as a pub workspace (`resolution: workspace`) or a nested package with no `analysis_options.yaml`. Then one isolate serves files from several pubspec roots. In that case:

- Baseline already works per root (`BaselineManager.enablePerRoot`), and so do accepted lists (`AcceptedFindingsRuntime.match` by nearest root).
- Everything else `_loadFromRoot` sets follows the first package's files only:
  - `SaropaLintRule.enabledRules`, `disabledRules` and `severityOverrides`
  - rule packs and the runtime tier cap
  - lane, memory mode, shed rules and max RSS
  - banned_usage, always_specify_parameter_names, max_declarations and avoid_ignoring_return_values config
  - output and max_issues
  - log level and diagnostic statistics
  - `PluginLogger`'s log root and the report config snapshot

Making those per root means a root-keyed config object looked up for each file in `_wrapCallback`, plus changing every rule and helper that reads those statics. That is an engine redesign touching many files, so it was not attempted in this pass. Not reproduced: no multi-package single-context fixture was run.

## Unverified

- Whether the live editor (step 30) shows the same gap. A long-lived server should let the late isolate publish eventually, but this was not run.
- (Resolved: SDK source read; see the finish report at the top.) The exact rule `dart analyze` uses to decide when to stop waiting for plugin results.

## Draft upstream issue (dart-lang/sdk, area-devexp / analyzer plugins) — NOT POSTED

**Title:** `dart analyze <dir>` drops diagnostics from a plugin isolate that is slow to start when `<dir>` contains several context roots

**Body:**

With analyzer plugins (analysis_server_plugin), `dart analyze` on a folder that contains two packages starts one plugin isolate per package. If the second isolate takes a little longer to become ready, `dart analyze` prints only the first package's plugin diagnostics and exits 0/2 as if the second package had none.

Dart SDK 3.14.0 (stable), Windows x64, analysis_server_plugin 0.3.26, analyzer 14.7.0.

Repro:

1. A plugin package `min_plugin` with `lib/main.dart`:

```dart
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

final plugin = MinPlugin();

class MinPlugin extends Plugin {
  @override
  String get name => 'min_plugin';

  @override
  Future<void> start() async {
    // Stands in for a plugin whose isolate takes a moment to get ready.
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(CatchRule());
  }
}

class CatchRule extends AnalysisRule {
  static const LintCode code = LintCode('min_catch', 'Catch clause found.');
  CatchRule() : super(name: 'min_catch', description: 'Reports catch clauses.');

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addCatchClause(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);
  final AnalysisRule rule;
  @override
  void visitCatchClause(CatchClause node) => rule.reportAtNode(node);
}
```

2. A folder `parent/` (no pubspec, no analysis_options) with packages `one/` and `two/`. Each has a `pubspec.yaml`, an `analysis_options.yaml` with `plugins: min_plugin: path: <path to min_plugin>`, and the same `lib/g.dart` containing two `try { } catch (e) { }` blocks.
3. Run `dart analyze parent`.

Expected: 4 issues (2 in `one`, 2 in `two`).

Actual: 2 issues, only in `one`. Isolate tracing shows that the second plugin isolate runs `register()` and starts `start()`, but `dart analyze` exits before that isolate's `registerNodeProcessors` is ever called. Without the delay in `start()`, both packages report correctly. `dart analyze parent/two` alone always reports its 2 issues.

A real plugin with many rules (saropa_lints) hits this with no artificial delay: the second package's plugin diagnostics are always missing from a parent-folder run, and which package is missing depends only on directory order.

`dart analyze` should wait for every plugin isolate's analysis results for every context root before it reports and exits.

## Finish Report (2026-11-27)

Superseded by the finish report at the top of this file (the SDK cause was later confirmed from source, and the scan/LSP baseline flaw was fixed). Remaining: the upstream issue is not posted (owner action).
