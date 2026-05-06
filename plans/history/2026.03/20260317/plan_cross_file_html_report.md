# Plan: Cross-File HTML Report Generation

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 3, Deliverables

---

## Summary

Add HTML report generation for cross-file analysis. Users run something like `dart run saropa_lints:cross_file report --output html --output-dir reports/` and get a summary dashboard and detailed pages for unused files, circular deps, and (if implemented) feature matrix.

## Scope

- Extend the cross_file CLI (or add a `report` command) with:
  - `--output html` and `--output-dir <path>`.
  - Generate:
    - `reports/index.html` — summary dashboard.
    - `reports/unused-files.html` — detailed unused files list.
    - `reports/circular-deps.html` — dependency graph visualization (or list).
    - Optionally `reports/feature-matrix.html` when feature-deps exists.
- HTML should be self-contained or use minimal assets for portability.

## Acceptance criteria

- [ ] CLI can produce HTML output into a specified directory.
- [ ] Index page summarizes counts and links to detail pages.
- [ ] Unused files and circular deps are human-readable in the report.

## Dependencies

- Cross-file analyzer and reporter (Phase 1). Optional: Phase 2 feature-deps for feature matrix page.
