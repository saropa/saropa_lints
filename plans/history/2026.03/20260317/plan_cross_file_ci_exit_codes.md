# Plan: Cross-File CLI CI-Friendly Exit Codes

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 3, Deliverables

---

## Summary

Define and implement CI-friendly exit codes for the cross-file CLI so that CI/CD pipelines can gate on success/failure. ROADMAP specifies: 0 = no issues, 1 = issues found, 2 = configuration error.

## Scope

- Ensure `bin/cross_file.dart` (and any entry points) exit with:
  - **0** — No issues found (e.g. no unused files, no circular deps when that is the command).
  - **1** — Issues found (e.g. unused files or circular dependencies reported).
  - **2** — Configuration or usage error (e.g. invalid path, invalid option, missing command).
- Document exit codes in CLI `--help` and in README/Phase 3 docs.

## Acceptance criteria

- [ ] Exit 0 when the requested check finds no issues.
- [ ] Exit 1 when the requested check finds one or more issues.
- [ ] Exit 2 when the run cannot proceed due to bad args or config.
- [ ] Documented in help and user docs.

## Dependencies

- CLI entry point and command implementations that can distinguish “issues” vs “no issues” vs “error”.
