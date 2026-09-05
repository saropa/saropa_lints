# Rename "Analyzer plugin" → "Live analysis" and "Lint integration" → "Scan on save"

Users reported confusion between the sidebar's "Analyzer plugin" and "Lint integration" rows — both names sounded like the same system, when they are independent mechanisms. The rename makes the two distinguishable by describing what each does: "Live analysis" = real-time squiggles from the Dart analyzer plugin, "Scan on save" = batch scan by the extension after each file save.

## Changes

### en.json (English locale values — l10n keys unchanged)

- `dashboards.controls.analyzerPlugin`: "Analyzer plugin" → "Live analysis"
- `dashboards.controls.analyzerPluginDisabled`: "Off — scan-on-save only" → "Off — scan on save only"
- `debug.engine.analyzerPlugin`: "Analyzer Plugin" → "Live Analysis"
- `debug.engine.scanDaemon`: "Scan Daemon" → "Scan on Save"
- `settings.extension.linkNote`: "Lint integration" → "Scan on save"
- `notify.main.lintIntegrationOffCannotAnalyze`: "lint integration" → "scan on save"
- `notify.main.disabledAnalyzer`: "Lint integration" → "Scan on save"
- `notify.main.scanOnSaveBaselineDisabled`: "Lint integration" → "Scan on save"

### Command catalog (commandCatalogEntriesProject.ts)

- "Turn Off Lint Integration" → "Disable Saropa Lints" (the command disables both live analysis AND scan on save, so naming it after one subsystem was misleading)
- "Re-enable In-Process Plugin" → "Re-enable Live Analysis"

### Code comments updated

- `analyzerPluginWatch.ts` header: updated to reference "live-analysis engine state" instead of the removed sidebar row
- `sectionedSidebar.ts` view-contents comment: "Analyzer plugin" → "Live analysis"; stale "Lint integration row" reference corrected
- `setup.ts` DISABLE_BEGIN_MARKER: added DO-NOT-RENAME guard comment — the marker text is written to users' analysis_options.yaml files; changing it would orphan previously-disabled blocks
- `engineCardsHtml.ts` description comment: updated to reference "Live Analysis" name

### Concurrent architecture note

A concurrent session (sidebar reset plan P1/P3) removed both the "Lint integration" row and the `getAnalyzerPluginWarningNode()` method from the sidebar. The sidebar-row-specific l10n values renamed here (`dashboards.controls.analyzerPlugin`, `analyzerPluginDisabled`, `analyzerPluginAbsent`) are now dead code with no remaining callers. The Health Panel engine names ("Live Analysis", "Scan on Save") and notification strings remain live.

## Finish Report (2026-09-05)

The defect was user confusion between two sidebar items whose names did not distinguish the underlying mechanisms. Five English locale values, two command catalog titles, and four notification strings were updated. L10n keys were deliberately left unchanged to avoid churn in the translation pipeline. The concurrent sidebar reset plan removed the sidebar row and its backing method entirely — the Health Panel engine names and notification strings remain the primary consumers of the clearer naming. A guard comment was added to `setup.ts` to prevent the YAML disable-marker text from being renamed in future passes (it is a machine-readable sentinel already deployed to users' files).
