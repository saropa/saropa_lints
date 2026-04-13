# Deferred: Cross-File Dart Analysis Rules

> **Last reviewed:** 2026-04-13

## Why these rules cannot be implemented

The analyzer plugin runs rules **one Dart file at a time**. Each rule receives the AST for a single file and reports diagnostics for that file. It cannot:

- Analyze two Dart files together (e.g., check if a provider in file A is consumed in file B)
- Query "all call sites" for a function across the project
- Verify that a test file exists for a given source file
- Track data flow across method/file boundaries

### Existing cross-file infrastructure

A **CLI tool** already exists (`dart run saropa_lints:cross_file`) that builds a project-wide import graph via `ImportGraphCache`. It supports `unused-files`, `circular-deps`, and `import-stats` commands. However:

- CLI output is **terminal/JSON only** — no IDE PROBLEMS panel integration
- CLI results do **not** appear as squiggles in the editor
- CLI does **not** provide quick fixes
- The extension does **not** yet surface CLI results in its sidebar views

### What would unblock these rules

1. **Extension UI integration**: Surface `cross_file` CLI results in extension sidebar views (unused files, circular deps). This is buildable today — moderate effort.
2. **Analyzer API change**: If the Dart analysis server or `custom_lint` exposed a multi-file analysis phase, rules could query cross-file state. No timeline for this.
3. **Symbol-level CLI**: Extend the CLI to detect unused symbols, not just unused files. Requires `AnalysisContextCollection` for full type resolution — high effort.

---

## Provider / State Management (4 rules)

| Rule | Severity | What it needs |
|------|----------|---------------|
| `avoid_provider_circular_dependency` | ERROR | Track Provider dependencies across files to detect cycles. [#2](https://github.com/saropa/saropa_lints/issues/2) |
| `avoid_riverpod_circular_provider` | ERROR | Track `ref.watch()` and `ref.read()` calls across provider files. [#1](https://github.com/saropa/saropa_lints/issues/1) |
| `require_riverpod_test_override` | INFO | Test overrides may be in setup files separate from test files. |
| `require_go_router_deep_link_test` | INFO | Routes defined in one file, tests in another. |

## Project-Wide / Coverage / Barrel (3 rules)

| Rule | Severity | What it needs |
|------|----------|---------------|
| `require_test_coverage_threshold` | INFO | Coverage is computed project-wide; single-file AST cannot enforce threshold. |
| `require_test_golden_threshold` | INFO | Golden file count and usage span multiple files. |
| `require_barrel_files` | INFO | Detecting multiple individual imports across files to suggest barrel exports. |

## Bloc Event / State (2 rules)

| Rule | Severity | What it needs |
|------|----------|---------------|
| `require_riverpod_override_in_tests` | INFO | Test overrides may be in setup files, not test files. |
| `require_bloc_test_coverage` | INFO | Test coverage requires analyzing test file contents. |

## Unused / Dead Code (4 rules)

| Rule | Severity | What it needs |
|------|----------|---------------|
| `require_e2e_coverage` | INFO | Test coverage is cross-file. |
| `avoid_never_passed_parameters` | INFO | Must analyze all call sites for a function. |
| `require_missing_test_files` | INFO | Must check if a test file exists for each source file. |
| `require_temp_file_cleanup` | INFO | Delete call may be in a separate function or file. |

## Architecture / DI (4 rules)

| Rule | Severity | What it needs |
|------|----------|---------------|
| `avoid_getit_unregistered_access` | INFO | Registration may be in a separate file from usage. |
| `require_crash_reporting` | INFO | Crash reporting setup is centralized, usage is distributed. |
| `prefer_layer_separation` | INFO | Architecture analysis requires cross-file import analysis. |
| `require_di_module_separation` | INFO | DI module boundaries require cross-file analysis. |

## Package-Specific Cross-File (7 rules)

| Rule | Severity | Package | What it needs |
|------|----------|---------|---------------|
| `require_supabase_auth_state_listener` | INFO | supabase_flutter | Auth listener may be set up in a different file. |
| `require_workmanager_unique_name` | INFO | workmanager | Must compare task names across all files. |
| `require_iap_restore_handling` | INFO | in_app_purchase | Restore handling may be in a separate class. |
| `handle_bloc_event_subclasses` | INFO | bloc | Bloc event class hierarchy spans multiple files. |
| `require_timezone_initialization` | INFO | timezone | `initializeTimeZones()` may be in main.dart, not the file using timezone. |
| `avoid_envied_secrets_in_repo` | ERROR | envied | Must read `.gitignore` to verify `.env` exclusion. |
| `prefer_correct_screenshots` | INFO | — | Screenshot references, tests, and assets span files. |

## Misc (2 rules)

| Rule | Severity | What it needs |
|------|----------|---------------|
| `prefer_intent_filter_export` | INFO | Android intent-filter export requires manifest + Dart usage analysis. |
| `require_resource_tracker` | INFO | Resource tracking is context-dependent across files. |

**Total: 26 rules**
