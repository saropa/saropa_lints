# Plan: Cross-File CLI Baseline Integration

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 3, Deliverables

---

## Summary

Integrate the cross-file CLI with the existing baseline system so that known issues can be suppressed and only new violations fail the run. Commands: `--baseline <file>` to load baseline, `--update-baseline` to write current results as the new baseline.

## Scope

- Reuse or mirror the pattern from `bin/baseline.dart` (see ROADMAP Phase 3.2):
  - `dart run saropa_lints:cross_file unused-files --baseline cross_file_baseline.json`
  - `dart run saropa_lints:cross_file unused-files --update-baseline`
- Baseline file stores current output (e.g. list of unused files, circular chains) and is used to diff on the next run:
  - If current results match baseline (or only remove items): exit 0.
  - If current results add new violations: exit non-zero (e.g. 1).
- Format of the baseline file (JSON) should be documented and stable.

## Acceptance criteria

- [ ] `--baseline <path>` loads baseline and suppresses known issues from failure.
- [ ] `--update-baseline` writes current run results to the baseline file.
- [ ] New violations (e.g. new unused file, new cycle) cause non-zero exit when using baseline.

## Dependencies

- Cross-file analyzer and reporter; existing baseline infrastructure in the repo for reference.
