# Cross-File Analysis CLI Tool Roadmap

Plan for building DCM-style cross-file analysis capabilities as a standalone CLI tool.

## Rationale

The `custom_lint` framework and native analyzer plugins both operate per-file, making certain analyses impossible:
- Unused code/file detection (requires project-wide usage graph)
- Circular dependency detection (requires import graph)
- Cross-feature dependency analysis (requires module boundaries)

DCM solves this with standalone CLI commands. We can do the same, leveraging existing infrastructure.

## Scope & Limitations

**What CLI provides:**
- Terminal output for CI/CD pipelines
- JSON/HTML reports for documentation
- Exit codes for build gates
- Cross-file analysis that per-file tools cannot do

**What CLI does NOT provide:**
- IDE "PROBLEMS" panel integration
- Real-time squiggles in editor
- Quick fixes
- On-save feedback

```
┌─────────────────────────────────────────────────────────────┐
│                    Reporting Comparison                     │
├─────────────────┬──────────────┬──────────────┬────────────┤
│ Output          │ Current      │ Native       │ CLI        │
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

**Use CLI for:**
- CI/CD pipeline enforcement
- Batch analysis reports
- Cross-file checks (unused files, circular deps)
- Periodic audits

**Use Native/Current for:**
- Real-time IDE feedback
- Developer experience during coding

## Existing Infrastructure

| Component | Location | Ready |
|-----------|----------|-------|
| ImportGraphCache | `lib/src/project_context.dart:3145-3383` | Yes |
| SemanticTokenCache | `lib/src/project_context.dart:3585-3720` | Yes |
| CLI framework | `bin/saropa_lints.dart` | Yes |
| Argument parsing | `bin/init.dart` pattern | Yes |
| Baseline system | `bin/baseline.dart` | Yes |
| AnalysisReporter | `lib/src/report/analysis_reporter.dart` | Yes |

## Phase 1: Foundation (MVP)

**Goal**: Basic cross-file analysis with text/JSON output

### 1.1 Create CLI Entry Point

Create `bin/cross_file.dart`:

```
dart run saropa_lints:cross_file [command] [options]

Commands:
  unused-files     Find files not imported by any other file
  circular-deps    Detect circular import chains
  import-stats     Show import graph statistics

Options:
  --path <dir>     Project directory (default: current)
  --output <fmt>   Output format: text, json (default: text)
  --exclude <glob> Exclude patterns (can repeat)
```

### 1.2 Implement Commands

| Command | Implementation | Leverages |
|---------|---------------|-----------|
| `unused-files` | Build import graph, find files with no importers | `ImportGraphCache.getImporters()` |
| `circular-deps` | Scan all files for circular chains | `ImportGraphCache.detectCircularImports()` |
| `import-stats` | Aggregate graph statistics | `ImportGraphCache.getStats()` |

### 1.3 Output Formats

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
  ]
}
```

### 1.4 Register Executable

Add to `pubspec.yaml`:
```yaml
executables:
  cross_file: cross_file
```

### Deliverables
- [ ] `bin/cross_file.dart` - CLI entry point
- [ ] `lib/src/cli/cross_file_analyzer.dart` - Analysis logic
- [ ] `lib/src/cli/cross_file_reporter.dart` - Output formatting
- [ ] Unit tests for each command
- [ ] Update README with usage

---

## Phase 2: Enhanced Analysis

**Goal**: Deeper analysis with symbol-level tracking

### 2.1 Unused Symbols Detection

Detect public symbols not used outside their defining file:
- Classes
- Top-level functions
- Top-level variables
- Extensions
- Typedefs
- Mixins
- Enums

**Implementation**:
1. Use `AnalysisContextCollection` for full resolution
2. Build symbol → usage location map
3. Report symbols with no external references
4. Respect `@visibleForTesting`, `@protected` annotations

```
dart run saropa_lints:cross_file unused-symbols [options]

Options:
  --include-private    Include private symbols (default: false)
  --exclude-public-api Exclude package public API (default: false)
  --exclude-overrides  Exclude overridden members (default: true)
```

### 2.2 Cross-Feature Dependencies

For projects using feature-based architecture (`lib/features/*/`):

```
dart run saropa_lints:cross_file feature-deps [options]

Options:
  --features-path <glob>  Feature directory pattern (default: lib/features/*)
  --show-matrix           Show dependency matrix
  --fail-on-violation     Exit 1 if cross-feature imports found
```

Output:
```
Feature Dependencies:

  auth -> (none)
  home -> auth
  profile -> auth, home  [VIOLATION: home]
  settings -> auth

Violations (1):
  lib/features/profile/profile_page.dart imports lib/features/home/home_model.dart
```

### 2.3 Dead Import Detection

Find imports that are declared but no symbols from them are used:

```
dart run saropa_lints:cross_file dead-imports [options]
```

### Deliverables
- [ ] `unused-symbols` command
- [ ] `feature-deps` command
- [ ] `dead-imports` command
- [ ] Dependency matrix visualization (text)
- [ ] Performance optimization for large projects

---

## Phase 3: Reporting & Integration

**Goal**: Rich output formats and CI/CD integration

### 3.1 HTML Reports

```
dart run saropa_lints:cross_file report --output html --output-dir reports/
```

Generates:
- `reports/index.html` - Summary dashboard
- `reports/unused-files.html` - Detailed unused files list
- `reports/circular-deps.html` - Dependency graph visualization
- `reports/feature-matrix.html` - Feature dependency matrix

### 3.2 Baseline Support

Integrate with existing baseline system:

```
dart run saropa_lints:cross_file unused-files --baseline cross_file_baseline.json
dart run saropa_lints:cross_file unused-files --update-baseline
```

Suppresses known issues, fails only on new violations.

### 3.3 CI/CD Integration

Exit codes:
- `0` - No issues found
- `1` - Issues found
- `2` - Configuration error

GitHub Actions example:
```yaml
- name: Cross-file analysis
  run: dart run saropa_lints:cross_file unused-files --fail-on-violation
```

### 3.4 Watch Mode

```
dart run saropa_lints:cross_file watch
```

Re-runs analysis on file changes, useful during development.

### Deliverables
- [ ] HTML report generation
- [ ] Baseline integration
- [ ] CI-friendly exit codes
- [ ] Watch mode
- [ ] GitHub Actions example workflow

---

## Phase 4: Advanced Features

**Goal**: Parity with DCM advanced features

### 4.1 Code Duplication Detection

```
dart run saropa_lints:cross_file duplicates [options]

Options:
  --min-lines <n>      Minimum lines to consider (default: 5)
  --min-tokens <n>     Minimum tokens to consider (default: 50)
  --ignore-comments    Ignore comment differences
```

**Implementation**: AST-based comparison using normalized token streams.

### 4.2 Unused Localization Keys

For projects using ARB files:

```
dart run saropa_lints:cross_file unused-l10n [options]

Options:
  --arb-dir <path>     ARB directory (default: lib/l10n)
```

### 4.3 Dependency Graph Export

```
dart run saropa_lints:cross_file graph --output dot > deps.dot
dot -Tpng deps.dot -o deps.png
```

Exports import graph in DOT format for visualization with Graphviz.

### 4.4 Integration with Lint Rules

Expose cross-file data to lint rules via `ProjectContext`:

```dart
// In a lint rule
final crossFile = ProjectContext.of(context).crossFileAnalysis;
if (crossFile.isSymbolUnused(node.name)) {
  reporter.atNode(node, code);
}
```

### Deliverables
- [ ] Duplicate code detection
- [ ] Unused localization detection
- [ ] DOT graph export
- [ ] ProjectContext integration for lint rules

---

## Technical Considerations

### Performance

| Concern | Mitigation |
|---------|------------|
| Large projects (1000+ files) | Use `ImportGraphCache` (regex-based, fast) |
| Symbol resolution | Lazy `AnalysisContextCollection`, only when needed |
| Repeated runs | Cache results with file modification timestamps |
| Memory | Stream results, don't hold full AST in memory |

### Exclusions

Default exclusions (configurable):
- `build/`
- `.dart_tool/`
- Generated files (`*.g.dart`, `*.freezed.dart`)
- Test files (for `unused-symbols` in lib/)

### Configuration

Support `analysis_options.yaml` integration:

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

---

## References

- [DCM check-unused-code](https://dcm.dev/docs/cli/code-quality-checks/unused-code/)
- [DCM check-unused-files](https://dcm.dev/docs/cli/code-quality-checks/unused-files/)
- [Dart analyzer package](https://pub.dev/packages/analyzer)
- [AnalysisContextCollection](https://pub.dev/documentation/analyzer/latest/)

---

_Last updated: 2026-01-28_
