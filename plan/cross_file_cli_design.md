# Cross-File Analysis CLI Tool Design

> **Last reviewed:** 2026-04-13

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
  --exclude <glob>     Reserved for future use (can repeat)
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
| `--exclude` flag parsed but not applied | `cross_file_analyzer.dart:12` — comment says "not yet applied" | Low — no user impact until advertised |
| HTML reporter string interpolation bug | `cross_file_html_reporter.dart:37` — `$u.length` should be `${u.length}`, same on line 38 for `$c.length` | Medium — HTML index page shows list object instead of count |
| Doc comment lists 3 commands, code has 4 | `bin/cross_file.dart:10` vs line 70 — `report` command missing from library doc comment | Low — cosmetic |

---

## Phase 2: Enhanced Analysis — 🔲 NOT STARTED

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
```

**Implementation approach**:
1. Use `AnalysisContextCollection` for full resolution
2. Build symbol → usage-location map across all files
3. Report symbols with no external references
4. Respect `@visibleForTesting`, `@protected`, `@override` annotations
5. Exclude entry points (main functions, exported API)

**Risk**: This is the highest-complexity command. Symbol resolution across large projects can be slow. Consider incremental analysis or file-level caching.

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

### Deliverables
- [ ] `unused-symbols` command — symbol-to-usage map, annotation-aware filtering
- [ ] `feature-deps` command — feature boundary detection, dependency matrix
- [ ] `dead-imports` command — verify gap vs native `unused_import` first
- [ ] Dependency matrix visualization (text table)
- [ ] Performance benchmarks for large projects (1000+ files)
- [x] Implement `--exclude` glob filtering in `cross_file_analyzer.dart`

---

## Phase 3: Reporting & Integration — ⚠️ MOSTLY COMPLETE

**Goal**: Rich output formats and CI/CD integration.

### HTML Reports — ✅ Done

`lib/src/cli/cross_file_html_reporter.dart` — generates `index.html`, `unused-files.html`, `circular-deps.html`.

```
dart run saropa_lints:cross_file report --output-dir reports/
```

**Improvement opportunities:**
- ~~Fix string interpolation bug (`$u.length` → `${u.length}`)~~ — Fixed
- Add CSS theming / dark mode
- Add dependency graph visualization (SVG or canvas-based)
- Add feature dependency matrix page (when Phase 2B lands)

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

### Watch Mode — 🔲 NOT STARTED

```
dart run saropa_lints:cross_file watch
```

Re-runs analysis on file changes. Requires a file watcher (e.g., `package:watcher`).

**Implementation approach:**
1. Add `package:watcher` dependency
2. Watch `lib/` directory for `.dart` file changes
3. Debounce changes (e.g., 500ms) to avoid rapid re-analysis
4. Re-run `runCrossFileAnalysis()` and display incremental diff
5. Support `--command` flag to restrict which analysis runs

**Priority**: Low — CI/CD is the primary use case, not interactive watching.

### Deliverables
- [x] HTML report generation (`cross_file_html_reporter.dart`)
- [x] Baseline integration (`cross_file_baseline.dart`)
- [x] CI-friendly exit codes (0/1/2)
- [x] GitHub Actions example workflow (`doc/cross_file_ci_example.md`)
- [ ] Watch mode — low priority, consider deferring
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
- Staleness: cache may be out of date if files changed since last CLI run
- Alternative: run CLI as a pre-build step, plugin reads the output

### Deliverables
- [x] DOT graph export (`graph` command) — `cross_file_dot_reporter.dart`, respects `--exclude` via `includedPaths`
- [ ] Unused localization detection (`unused-l10n` command)
- [ ] Duplicate code detection (`duplicates` command) — defer until others prove the pattern
- [ ] ProjectContext integration for lint rules — requires architecture decision on caching

---

## Implementation Roadmap

```
Phase 1 ████████████████████ COMPLETE
Phase 2 █░░░░░░░░░░░░░░░░░░ 17% (--exclude done, commands not started)
Phase 3 ██████████████████░░ 90% (watch mode remains)
Phase 4 █████░░░░░░░░░░░░░░ 25% (graph done, 3 remaining)
```

### Suggested Next Steps (in order)

1. ~~**Fix Phase 3 HTML bug**~~ — ✅ Done
2. ~~**Implement `--exclude` filtering**~~ — ✅ Done
3. ~~**Phase 4: `graph` command**~~ — ✅ Done
4. **Phase 2B: `feature-deps`** — medium complexity, uses existing ImportGraphCache
5. **Phase 2A: `unused-symbols`** — high complexity, needs AnalysisContextCollection
6. **Phase 2C: `dead-imports`** — validate gap vs native `unused_import` first
7. **Phase 4: `unused-l10n`** — medium complexity, Flutter-specific
8. **Phase 3: watch mode** — low priority, defer unless user demand
9. **Phase 4: `duplicates`** — high complexity, defer

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

**Status**: Not yet implemented. Currently all configuration is via CLI flags. YAML config would be added when Phase 2 commands are implemented.

### File Inventory

| File | Phase | Purpose |
|------|-------|---------|
| `bin/cross_file.dart` | 1 | CLI entry point, arg parsing, command routing |
| `lib/src/cli/cross_file_analyzer.dart` | 1 | Core analysis logic, `runCrossFileAnalysis()` |
| `lib/src/cli/cross_file_reporter.dart` | 1 | Text/JSON output, `CrossFileResult` data class |
| `lib/src/cli/cross_file_html_reporter.dart` | 3 | HTML report generation |
| `lib/src/cli/cross_file_baseline.dart` | 3 | Baseline JSON load/save/compare |
| `lib/src/cli/cross_file_dot_reporter.dart` | 4 | DOT graph export for Graphviz |
| `test/cli/cross_file_test.dart` | 1 | Unit tests (3 groups, fixture-based) |
| `test/cli/cross_file_exclude_test.dart` | 2 | `--exclude` glob filtering tests |
| `test/cli/cross_file_dot_test.dart` | 4 | DOT graph export tests |
| `test/fixtures/cross_file_fixture/` | 1 | 4-file test fixture (orphan + a→b→c→a cycle) |
| `doc/cross_file_ci_example.md` | 3 | GitHub Actions workflow template |

### References

- [DCM check-unused-code](https://dcm.dev/docs/cli/code-quality-checks/unused-code/)
- [DCM check-unused-files](https://dcm.dev/docs/cli/code-quality-checks/unused-files/)
- [Dart analyzer package](https://pub.dev/packages/analyzer)
