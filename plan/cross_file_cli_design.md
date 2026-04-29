# Cross-File Analysis CLI Tool Design

> **Last reviewed:** 2026-04-28

## Rationale

The analyzer plugin runs per-file, making certain analyses impossible:
- Unused code/file detection (requires project-wide usage graph)
- Circular dependency detection (requires import graph)
- Cross-feature dependency analysis (requires module boundaries)

A standalone CLI tool fills this gap. DCM does the same thing.

## Scope

**What CLI provides:**
- Terminal output for CI/CD pipelines
- JSON/HTML reports for documentation
- Exit codes for build gates
- Cross-file analysis that per-file tools cannot do

**What CLI does NOT provide:**
- IDE PROBLEMS panel integration
- Real-time squiggles in editor
- Quick fixes
- On-save feedback

```
┌─────────────────────────────────────────────────────────────┐
│                    Reporting Comparison                     │
├─────────────────┬──────────────┬──────────────┬────────────┤
│ Output          │ Plugin       │ Native       │ CLI        │
├─────────────────┼──────────────┼──────────────┼────────────┤
│ IDE PROBLEMS    │ Yes          │ Yes (faster) │ No         │
│ Editor squiggles│ Yes          │ Yes (faster) │ No         │
│ Quick fixes     │ Yes          │ Yes          │ No         │
│ Terminal        │ Yes          │ Yes          │ Yes        │
│ JSON reports    │ No           │ No           │ Yes        │
│ HTML reports    │ No           │ No           │ Yes        │
│ CI exit codes   │ Yes          │ Yes          │ Yes        │
└─────────────────┴──────────────┴──────────────┴────────────┘
```

## Existing Infrastructure

| Component | Location | Status |
|-----------|----------|--------|
| ImportGraphCache | `lib/src/project_context_import_location.dart` | ✅ Ready — has `getImporters()`, `detectCircularImports()`, `getStats()`, `getFilePaths()`, `buildFromDirectory()` |
| SemanticTokenCache | `lib/src/project_context_semantic_compilation.dart` | ✅ Ready |
| CLI framework | `bin/saropa_lints.dart` | ✅ Ready |
| Argument parsing | `bin/init.dart` → `bin/init_runner.dart` | ✅ Ready |
| Baseline system | `bin/baseline.dart` | ✅ Ready |
| AnalysisReporter | `lib/src/report/analysis_reporter.dart` | ✅ Ready |

---

## Phase 1: Foundation (MVP) — ✅ COMPLETE

**Goal**: Basic cross-file analysis with text/JSON output.

### CLI Entry Point

`bin/cross_file.dart`:

```
dart run saropa_lints:cross_file [command] [options]

Commands:
  unused-files     Find files not imported by any other file
  circular-deps    Detect circular import chains
  import-stats     Show import graph statistics
  report           Write HTML report (use --output-dir)

Options:
  --path <dir>         Project directory (default: current)
  --output <fmt>       Output format: text, json (default: text)
  --output-dir <path>  For report: directory for HTML output (default: reports)
  --baseline <file>    Load baseline JSON; exit 0 only if no new violations
  --update-baseline    Write current results to baseline file
  --exclude <glob>     Exclude matching paths from results (can repeat)
  -h, --help           Show this help
```

### Commands

| Command | Implementation | Leverages |
|---------|---------------|-----------|
| `unused-files` | Build import graph, find files with no importers | `ImportGraphCache.getImporters()` |
| `circular-deps` | Scan all files for circular chains, deduplicate | `ImportGraphCache.detectCircularImports()` |
| `import-stats` | Aggregate graph statistics (fileCount, totalImports) | `ImportGraphCache.getStats()` |
| `report` | Generate multi-page HTML report | HTML reporter |

### Output Formats

**Text output** (default):
```
Unused Files (3 found):
  lib/src/deprecated/old_helper.dart
  lib/src/utils/unused_util.dart
  lib/src/features/dead_feature.dart

Circular Dependencies (1 found):
  lib/src/a.dart -> lib/src/b.dart -> lib/src/c.dart -> lib/src/a.dart
```

**JSON output** (`--output json`):
```json
{
  "unusedFiles": ["lib/src/deprecated/old_helper.dart"],
  "circularDependencies": [
    ["lib/src/a.dart", "lib/src/b.dart", "lib/src/c.dart", "lib/src/a.dart"]
  ],
  "stats": { "fileCount": 42, "totalImports": 128 }
}
```

### Deliverables
- [x] `bin/cross_file.dart` — CLI entry point with arg parsing, exit codes, help text
- [x] `lib/src/cli/cross_file_analyzer.dart` — `runCrossFileAnalysis()` builds graph and returns `CrossFileResult`
- [x] `lib/src/cli/cross_file_reporter.dart` — `CrossFileReporter.report()` with text/JSON, `CrossFileResult` data class
- [x] Unit tests (`test/cli/cross_file_test.dart`) — 3 groups: analyzer shape, reporter formats, fixture behavior (orphan + cycle)
- [x] Test fixture (`test/fixtures/cross_file_fixture/`) — 4 files: orphan.dart, a→b→c→a cycle
- [x] README updated with cross_file usage and examples

### Known Issues

| Issue | Location | Severity |
|-------|----------|----------|
| ~~`--exclude` not applied~~ | — | Resolved — see Phase 2 deliverables |
| ~~HTML `$u.length` interpolation~~ | — | Resolved — see Phase 3 deliverables |
| Library doc comment may lag commands | `bin/cross_file.dart` top-of-file list vs `--help` | Low — prefer `--help` as source of truth |

---

## Phase 2: Enhanced Analysis — ⚠️ PARTIALLY COMPLETE

**Goal**: Deeper analysis with symbol-level tracking.

**Prerequisite**: Phase 2 commands require `AnalysisContextCollection` for full semantic resolution, which is heavier than the regex-based `ImportGraphCache`. Consider whether `SemanticTokenCache` already provides enough data or if a new resolver is needed.

### 2A. Unused Symbols Detection

Detect public symbols not used outside their defining file:
- Classes, top-level functions, variables, extensions, typedefs, mixins, enums

```
dart run saropa_lints:cross_file unused-symbols [options]

Options:
  --include-private    Include private symbols (default: false)
  --exclude-public-api Exclude package public API (default: false)
  --exclude-overrides  Exclude overridden members (default: true)
  --heuristic-unused-symbols  Regex-only mode (skip analyzer resolution)
```

**Implementation approach**:
1. Use `AnalysisContextCollection` for full resolution
2. Build symbol → usage-location map across all files
3. Report symbols with no external references
4. Respect `@visibleForTesting`, `@protected`, `@override` annotations
5. Exclude entry points (main functions, exported API)

**Risk**: This is the highest-complexity command. Symbol resolution across large projects can be slow. Consider incremental analysis or file-level caching.

**Status**: Top-level `unused-symbols` uses analyzer resolution (`AnalysisContextCollection`) with regex heuristic fallback and `--heuristic-unused-symbols` for the legacy path; `--include-private` / `--exclude-public-api` and annotation-aware retention for `@visibleForTesting`/`@protected`/`@override` apply to both. Method-level unused members remain future work.

### 2B. Cross-Feature Dependencies

For projects using feature-based architecture (`lib/features/*/`):

```
dart run saropa_lints:cross_file feature-deps [options]

Options:
  --features-path <glob>  Feature directory pattern (default: lib/features/*)
  --show-matrix           Show dependency matrix
  --fail-on-violation     Exit 1 if cross-feature imports found
```

**Implementation approach**:
1. Identify feature directories from glob pattern
2. Use `ImportGraphCache` to find imports crossing feature boundaries
3. Build adjacency matrix (feature → feature)
4. Report violations: feature A importing directly from feature B internals

**Status**: ✅ Implemented via `feature-deps` output (`featureDependencies`, `crossFeatureImports`).

### 2C. Dead Import Detection

Find imports that are declared but no symbols from them are used:

```
dart run saropa_lints:cross_file dead-imports [options]
```

**Implementation approach**:
1. For each file, enumerate imported URIs
2. Resolve which symbols from each import are actually referenced
3. Report imports with zero referenced symbols
4. Handle `show`/`hide` combinators, re-exports, deferred imports

**Note**: `dart analyze` already reports `unused_import` for single files. This command adds value only if it catches cases the native analyzer misses (e.g., transitive re-exports). Validate the gap before implementing.

**Status**: ⚠️ First pass implemented as `dead-imports` (relative-import heuristic with `as`/`show`/`hide`, local re-export awareness, and deferred `loadLibrary()` handling). Analyzer-backed semantic resolution remains future work.

### Deliverables
- [x] `unused-symbols` command — first pass top-level symbol-to-usage map
- [x] `feature-deps` command — feature boundary detection, dependency matrix
- [x] `dead-imports` command — first pass for likely dead relative imports
- [x] Dependency matrix visualization (text table)
- [x] Performance benchmark harness for large projects (`tool/cross_file_benchmark.dart`)
- [x] Implement `--exclude` glob filtering in `cross_file_analyzer.dart`

---

## Phase 3: Reporting & Integration — ⚠️ MOSTLY COMPLETE

**Goal**: Rich output formats and CI/CD integration.

### HTML Reports — ✅ Done

`lib/src/cli/cross_file_html_reporter.dart` (+ `cross_file_html_reporter_part.dart`) — generates `report.css` (shared light/dark variables), `index.html`, `unused-files.html`, `missing-mirror-tests.html`, `circular-deps.html`, and `feature-deps.html` (adjacency, matrix, cross-feature edges).

```
dart run saropa_lints:cross_file report --output-dir reports/
```

**Improvement opportunities:**
- ~~Fix string interpolation bug (`$u.length` → `${u.length}`)~~ — Fixed
- ~~Light/dark~~ — `report.css` uses `prefers-color-scheme: dark` and shared CSS variables
- ~~Feature dependency matrix in HTML~~ — `feature-deps.html` included in the report bundle
- Add dependency graph visualization (SVG or canvas-based)

### Baseline Support — ✅ Done

`lib/src/cli/cross_file_baseline.dart` — JSON-based baseline with version, timestamp, diff detection.

```
dart run saropa_lints:cross_file unused-files --update-baseline
dart run saropa_lints:cross_file unused-files --baseline cross_file_baseline.json
```

Suppresses known issues, fails only on new violations. Uses set difference for unused files and cycle-key comparison for circular deps.

### CI/CD Integration — ✅ Done

Exit codes: `0` = no issues, `1` = issues found, `2` = configuration error.

### GitHub Actions Example — ✅ Done

`doc/cross_file_ci_example.md` — complete workflow template.

### Watch Mode — ⚠️ FIRST PASS IMPLEMENTED

```
dart run saropa_lints:cross_file watch
```

Re-runs analysis on file changes.

**Implementation approach:**
1. Watch project files (`lib/`, `test/`) for `.dart` changes
2. Debounce changes to avoid rapid re-analysis storms
3. Re-run `runCrossFileAnalysis()` and print refreshed output
4. Support `--command` flag to restrict which analysis runs
5. Add incremental diff presentation in a later iteration

**Priority**: Low — CI/CD is the primary use case, not interactive watching.

**Status**: ⚠️ First pass implemented as `watch` command with debounced reruns, `--command` support, and incremental added/resolved diff summaries; richer progress UI remains future work.

### Deliverables
- [x] HTML report generation (`cross_file_html_reporter.dart`)
- [x] Baseline integration (`cross_file_baseline.dart`)
- [x] CI-friendly exit codes (0/1/2)
- [x] GitHub Actions example workflow (`doc/cross_file_ci_example.md`)
- [x] Watch mode — first pass (`watch` + `--command` + `--watch-debounce-ms`)
- [x] Fix HTML reporter string interpolation bug

---

## Phase 4: Advanced Features — ⚠️ PARTIALLY COMPLETE

**Goal**: Parity with DCM advanced features.

### Planned Commands

| Command | Description | Implementation | Status |
|---------|-------------|----------------|--------|
| `graph` | DOT format dependency graph export | Convert ImportGraphCache to DOT syntax | ✅ Done |
| `unused-l10n` | Unused localization keys | Compare ARB keys against Dart usage | 🔲 Not started |
| `duplicates` | Code duplication detection | AST-based comparison using normalized token streams | 🔲 Not started |

**Acceptance criteria (draft):**
- **`unused-l10n`:** Inputs from `l10n.yaml` / `pubspec` `flutter: generate` as applicable; compare ARB key set to `S` / `AppLocalizations` usage in `lib/`; respect exclude globs; document false positives (dynamic keys, codegen-only references).
- **`duplicates`:** Configurable min token count / similarity threshold; report file pairs with line ranges; performance budget for large packages (or opt-in path filter).

### Priority Assessment

1. ~~**`graph` (DOT export)**~~ — ✅ Implemented. Exports DOT digraph with relative-path labels, respects `--exclude`.
2. **`unused-l10n`** — medium complexity, high value for Flutter projects. Only relevant if project uses ARB-based l10n.
3. **`duplicates`** — highest complexity, lowest immediate value. AST normalization and similarity detection is a significant undertaking. Consider whether this belongs in the CLI or as a separate tool.

### ProjectContext Integration

Expose cross-file data to per-file lint rules:

```dart
final crossFile = ProjectContext.of(context).crossFileAnalysis;
if (crossFile.isSymbolUnused(node.name)) {
  reporter.atNode(node, code);
}
```

**Challenge**: The plugin runs per-file in the analyzer server process. Cross-file data would need to be pre-computed and cached, then loaded by the plugin at startup. This is architecturally different from Phase 1–3 (standalone CLI). Consider:
- Pre-compute cross-file results and write to a cache file
- Plugin reads cache file on init
- Staleness: cache may be out of date if files changed since last CLI run — **invalidation** options: content hash or mtime of included Dart files, CLI/package version in the cache header, or "cache ignored if older than X minutes" (last resort)
- Alternative: run CLI as a pre-build step, plugin reads the output

### Deliverables
- [x] DOT graph export (`graph` command) — `cross_file_dot_reporter.dart`, respects `--exclude` via `includedPaths`
- [ ] Unused localization detection (`unused-l10n` command)
- [ ] Duplicate code detection (`duplicates` command) — defer until others prove the pattern
- [ ] ProjectContext integration for lint rules — requires architecture decision on caching

---

## Phase 5: VS Code Extension Integration — ✅ COMPLETE

**Goal**: Expose all cross-file CLI commands through the VS Code extension so users can actually discover and use them.

**Why this is critical**: CLI-only features are hard to discover. The extension surfaces the cross-file CLI as named commands (unused files, cycles, stats, feature deps, dead imports, unused symbols, DOT graph, HTML report) so users do not have to memorize `dart run` invocations. This phase is **complete**; the tables below document the intended mapping and patterns.

### Existing Extension Patterns to Follow

The extension already has established patterns for CLI execution and report generation:

1. **CLI execution**: `runInWorkspace()` in `extension/src/setup.ts` uses `spawnSync` with `shell: true`, UTF-8 encoding, logs to output channel, returns `{ ok, stdout, stderr }`
2. **Report generation**: `exportOwaspReport` writes to `reports/.saropa_lints/`, then opens the file in the editor via `vscode.workspace.openTextDocument()` + `vscode.window.showTextDocument()`
3. **Command registration**: Declared in `extension/package.json` under `contributes.commands`, handlers registered in `extension/src/extension.ts` via `vscode.commands.registerCommand()`
4. **Error handling**: Check `getProjectRoot()` first, show error message if no workspace. Check for prerequisite data before proceeding.

### 5A. Core Commands — wrap each CLI command as a VS Code command

| Extension command | CLI subcommand | Output handling |
|-------------------|----------------|-----------------|
| `saropaLints.crossFile.unusedFiles` | `unused-files` | Output channel; status bar from parsed JSON (count) |
| `saropaLints.crossFile.circularDeps` | `circular-deps` | Output channel; status bar (chain count) |
| `saropaLints.crossFile.importStats` | `import-stats` | Output channel; status bar (file / edge counts) |
| `saropaLints.crossFile.featureDeps` | `feature-deps` | Output channel; status bar (features / cross-feature imports) |
| `saropaLints.crossFile.deadImports` | `dead-imports` | Output channel; status bar (likely dead import count) |
| `saropaLints.crossFile.unusedSymbols` | `unused-symbols` | Output channel; status bar (symbol count) |
| `saropaLints.crossFile.graph` | `graph --output-dir <dir>` | DOT under `reports/.saropa_lints/cross_file/`, open in editor |
| `saropaLints.crossFile.report` | `report --output-dir <dir>` | HTML under `reports/.saropa_lints/cross_file/`, open in browser or editor |

**Implementation approach** for each command:
1. Get workspace root via `getProjectRoot()` (bail if none)
2. Build args: `['run', 'saropa_lints:cross_file', '--path', root, '--output', 'json', '<subcommand>', ...]`
3. Call `runInWorkspace(root, 'dart', args)`
4. For JSON-output commands: parse stdout for status bar; full JSON still in output channel
5. For `graph` / `report`: pass `--output-dir`, then open generated file(s) as above

### 5B. Package.json registration

All eight `saropaLints.crossFile.*` commands are registered in `extension/package.json` under `contributes.commands` (with titles, icons, and `enablement`). The snippet below is **representative**; use `package.json` as the source of truth for exact titles and any future additions.

```json
{ "command": "saropaLints.crossFile.unusedFiles", "title": "Saropa Lints: Cross-File — Find Unused Files" },
{ "command": "saropaLints.crossFile.circularDeps", "title": "Saropa Lints: Cross-File — Detect Circular Dependencies" },
{ "command": "saropaLints.crossFile.importStats", "title": "Saropa Lints: Cross-File — Show Import Statistics" },
{ "command": "saropaLints.crossFile.featureDeps", "title": "Saropa Lints: Cross-File — Show Feature Dependencies" },
{ "command": "saropaLints.crossFile.unusedSymbols", "title": "Saropa Lints: Cross-File — Find Unused Symbols" },
{ "command": "saropaLints.crossFile.deadImports", "title": "Saropa Lints: Cross-File — Find Dead Imports" },
{ "command": "saropaLints.crossFile.graph", "title": "Saropa Lints: Cross-File — Export Import Graph (DOT)" },
{ "command": "saropaLints.crossFile.report", "title": "Saropa Lints: Cross-File — Generate HTML Report" }
```

Also add to command palette / catalog filtering so they appear when a Dart workspace is open (see discoverability plan).

### 5C. Handler Implementation

Create `extension/src/cross-file-commands.ts` with:

```typescript
// registerCrossFileCommands(context: vscode.ExtensionContext)
//
// Registers all cross-file analysis commands. Called from extension.ts activate().
// Each handler follows the same pattern:
//   1. getProjectRoot() — bail if no workspace
//   2. Build args for `dart run saropa_lints:cross_file <command>`
//   3. runInWorkspace() — execute CLI
//   4. Display results (output channel, status bar, or open generated file)
```

**Commands that use JSON for summaries** (CLI invoked with `--output json`): `unused-files`, `circular-deps`, `import-stats`, `feature-deps`, `dead-imports`, `unused-symbols` — stdout is parsed for counts/messages; output channel still shows full output from `runInWorkspace`.

**Commands that produce files** (`graph`, `report`):
- Pass `--output-dir` pointing to `reports/.saropa_lints/`
- On success: open generated file in editor (DOT) or show "Open in browser?" prompt (HTML)
- On failure: show error message with stderr

### 5D. Discoverability

Cross-file commands must be discoverable, not buried in a 115+ command palette. This is part of a broader extension-wide discoverability problem — see [plan/extension_command_discoverability.md](extension_command_discoverability.md) for the full design.

Cross-file-specific requirements from that plan:
- **Command catalog**: cross-file commands appear under a "Cross-File Analysis" category in the searchable command catalog webview
- **Walkthrough**: new step covering cross-file analysis added to the Getting Started walkthrough
- **Enablement over hiding**: cross-file commands use `enablement` (disabled + tooltip) not `when` (hidden)

### 5E. JSON output mode for structured results

The extension runs the CLI with `--output json` for the six subcommands in 5A that need programmatic summaries. Handlers parse stdout into a small `CrossFileSummary` (counts, key arrays) for the status bar; the raw JSON remains visible in the output channel. A future tree view could reuse the same parse step instead of scraping text.

### 5F. Future: Cross-File Tree View

Not in scope for Phase 5, but worth noting: a dedicated tree view (`saropaLints.crossFile` view container) could display:
- Unused files as a collapsible list (click to open file)
- Circular dependency chains as nested items
- Import stats as key-value pairs

This would follow the same pattern as `saropaLints.todosAndHacks` or `saropaLints.packageVibrancy` tree views.

### Deliverables

- [x] `extension/src/cross-file-commands.ts` — handler implementations for all cross-file subcommands (JSON summaries + `graph` / `report` file open)
- [x] `extension/package.json` — command registrations and walkthrough; see 5B for the eight `saropaLints.crossFile.*` commands
- [x] `extension/src/extension.ts` — call `registerCrossFileCommands(context)` from `activate()`
- [x] Walkthrough step for cross-file analysis (package.json + `media/walkthrough-cross-file.md`)
- [x] Output routing — text results to output channel, file results opened in editor
- [x] Status bar feedback — summary message after each command completes
- [x] Error handling — no workspace, missing `saropa_lints` dependency, non-zero exit code
- [x] Register cross-file commands in the command catalog registry (see [extension_command_discoverability.md](extension_command_discoverability.md))

### Known Risks

| Risk | Mitigation |
|------|------------|
| CLI not installed in user's project | Check if `saropa_lints` is in pubspec.yaml dependencies before running; show actionable error if missing |
| Long-running analysis blocks UI | `spawnSync` is synchronous — consider switching to `spawn` (async) with progress indicator for large projects |
| DOT file has no default viewer | Show info message suggesting Graphviz extension or paste into an online viewer |
| `--output-dir` path differences on Windows | Use `path.join()` consistently; the CLI already handles this but verify |

---

## Implementation Roadmap

```
Phase 1 ████████████████████ COMPLETE
Phase 2 ██████████████░░░░░░ 70% (`--exclude` + `feature-deps` + semantic top-level `unused-symbols` + first-pass `dead-imports`)
Phase 3 ███████████████████░ 95% (watch: first pass done; optional UI polish)
Phase 4 █████░░░░░░░░░░░░░░ 25% (graph done, 3 remaining)
Phase 5 ████████████████████ 100% (extension integration complete)
```

### Suggested next steps (in order)

1. ~~**Fix Phase 3 HTML bug**~~ — ✅ Done
2. ~~**Implement `--exclude` filtering**~~ — ✅ Done
3. ~~**Phase 4: `graph` command**~~ — ✅ Done
4. ~~**Phase 2A follow-up** — upgrade `unused-symbols` to semantic resolver (`AnalysisContextCollection`) with annotation-aware filtering~~ — ✅ Done for top-level declarations (heuristic fallback + `--heuristic-unused-symbols`)
5. **Phase 2C follow-up** — semantic `dead-imports` (re-export + deferred support + analyzer-backed symbol resolution)
6. **Phase 4: `unused-l10n`** — medium complexity, Flutter-specific; see acceptance criteria above
7. **Phase 3: watch mode** — low priority: optional richer progress UI and tuning unless user demand
8. **Phase 4: `duplicates`** — high complexity, defer; see acceptance criteria above
9. **Phase 4: ProjectContext integration** — only after cache format and invalidation story is decided

---

## Technical Considerations

### Performance

| Concern | Mitigation |
|---------|------------|
| Large projects (1000+ files) | Use `ImportGraphCache` (regex-based, fast) for Phase 1/3/4 graph commands |
| Symbol resolution (Phase 2) | Lazy `AnalysisContextCollection`, only when needed |
| Repeated runs | Cache results with file modification timestamps |
| Memory | Stream results, don't hold full AST in memory |
| Watch mode | Debounce file changes, re-analyze only changed subgraph |

### Default Exclusions

- `build/`, `.dart_tool/`
- Generated files (`*.g.dart`, `*.freezed.dart`)
- Test files (for `unused-symbols` in lib/)

### Monorepos and multiple packages

`--path` is a **single** project root (one `pubspec.yaml` context). In a monorepo with several Dart packages, run the CLI (or extension) **per package** that should be analyzed, or add explicit support later (workspace manifest, aggregating multiple `ImportGraphCache` runs). Do not assume one run spans sibling packages unless that is implemented and documented.

### Configuration

Support `analysis_options.yaml` integration (future):

```yaml
cross_file:
  exclude:
    - "**/*.g.dart"
    - "lib/generated/**"
  features_path: "lib/features/*"
  unused_symbols:
    exclude_public_api: true
    exclude_overrides: true
```

**Status**: Not yet implemented. Phase 2 CLI subcommands already exist; a future `cross_file` block in `analysis_options.yaml` (or a dedicated file) would mirror common flags so CI and local runs stay aligned without long repeated command lines.

### File Inventory

| File | Phase | Purpose |
|------|-------|---------|
| `bin/cross_file.dart` | 1 | CLI entry point, arg parsing, command routing |
| `lib/src/cli/cross_file_analyzer.dart` | 1 | Core analysis logic, `runCrossFileAnalysis()` |
| `lib/src/cli/cross_file_unused_symbols_semantic.dart` | 2 | Analyzer-backed unused top-level symbol detection |
| `lib/src/cli/cross_file_reporter.dart` | 1 | Text/JSON output, `CrossFileResult` data class |
| `lib/src/cli/cross_file_html_reporter.dart` (+ part) | 3 | HTML report + `report.css`; feature matrix page |
| `lib/src/cli/cross_file_baseline.dart` | 3 | Baseline JSON load/save/compare |
| `lib/src/cli/cross_file_dot_reporter.dart` | 4 | DOT graph export for Graphviz |
| `test/cli/cross_file_test.dart` | 1 | Unit tests (3 groups, fixture-based) |
| `test/cli/cross_file_exclude_test.dart` | 2 | `--exclude` glob filtering tests |
| `test/cli/cross_file_dot_test.dart` | 4 | DOT graph export tests |
| `test/fixtures/cross_file_fixture/` | 1 | 4-file test fixture (orphan + a→b→c→a cycle) |
| `doc/cross_file_ci_example.md` | 3 | GitHub Actions workflow template |
| `extension/src/cross-file-commands.ts` | 5 | VS Code command handlers (eight commands: six JSON + graph + report) |
| `extension/package.json` | 5 | `saropaLints.crossFile.*` command registrations (eight commands) |
| `extension/src/extension.ts` | 5 | `registerCrossFileCommands()` call from `activate()` |

### References

- [DCM check-unused-code](https://dcm.dev/docs/cli/code-quality-checks/unused-code/)
- [DCM check-unused-files](https://dcm.dev/docs/cli/code-quality-checks/unused-files/)
- [Dart analyzer package](https://pub.dev/packages/analyzer)
