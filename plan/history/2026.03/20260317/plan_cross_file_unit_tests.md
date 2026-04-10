# Plan: Cross-File CLI Unit Tests

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 1, Deliverables

---

## Summary

Add unit tests for each cross-file CLI command: `unused-files`, `circular-deps`, and `import-stats`. Tests should run against fixture projects or in-memory graphs and assert on exit codes and output (text and/or JSON).

## Scope

- Tests under `test/` (e.g. `test/cli/cross_file_*_test.dart` or equivalent):
  - **unused-files:** fixture with at least one file that is never imported; expect it in output; expect 0 exit when no unused files (or documented behavior).
  - **circular-deps:** fixture with a known cycle (e.g. a → b → c → a); expect cycle in output; expect 0 exit when no cycles (or documented behavior).
  - **import-stats:** fixture with known number of files/imports; expect stats in output (exact or range).
- Optionally test `--output json` parsing and structure.
- Tests should not rely on the full repo; use small fixture directories or mocked graph data.

## Acceptance criteria

- [ ] Each command has at least one test that verifies meaningful output and success/failure exit code where applicable.
- [ ] Tests pass with `dart test`.
- [ ] Fixtures are under `test/` or a dedicated fixture path and excluded from analysis if needed.

## Dependencies

- CLI entry point, analyzer, and reporter implemented so that commands can be invoked from tests.
