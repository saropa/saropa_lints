# Plan: GitHub Actions Example for Cross-File CLI

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 3, Deliverables

---

## Summary

Provide a GitHub Actions example workflow that runs the cross-file CLI (e.g. `unused-files`) and fails the job when violations are found. This enables users to add the same check to their CI with minimal setup.

## Scope

- Add an example workflow file (e.g. in `doc/` or `.github/workflows/` as an example, or in README as a snippet) that:
  - Checks out the repo and sets up Dart.
  - Runs `dart run saropa_lints:cross_file unused-files --fail-on-violation` (or equivalent; exact flag from ROADMAP Phase 3.3).
  - Optionally runs `circular-deps` as well.
- Document that users can copy the snippet into their own `.github/workflows/` and adjust path/excludes as needed.

## Acceptance criteria

- [ ] Example workflow is runnable (or clearly marked as template) and documented.
- [ ] Running the workflow with no violations exits 0; with violations exits 1 (or documented behavior).
- [ ] README or doc links to or embeds the example.

## Dependencies

- Cross-file CLI with `unused-files` (and optionally `circular-deps`) and CI-friendly exit codes.
