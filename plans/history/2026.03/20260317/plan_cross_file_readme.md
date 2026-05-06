# Plan: Update README with Cross-File CLI Usage

**Status:** Planned (⭐ next in line)  
**ROADMAP:** [Part 3: Cross-File Analysis CLI Tool](../../ROADMAP.md) — Phase 1, Deliverables

---

## Summary

Update the project README (and any other user-facing docs) to document how to run the cross-file analysis CLI: commands, options, and example usage.

## Scope

- In `README.md` (or linked doc):
  - Add a short section for **Cross-file analysis** (or "CLI: cross_file").
  - Document: `dart run saropa_lints:cross_file [command] [options]`.
  - List commands: `unused-files`, `circular-deps`, `import-stats` with one-line descriptions.
  - Document main options: `--path`, `--output` (text/json), `--exclude`.
  - Include 1–2 example invocations (e.g. run in project root, output JSON to file).
- Ensure existing "Usage" or "CLI" structure is preserved; link to ROADMAP Part 3 for full scope.

## Acceptance criteria

- [ ] README (or linked doc) describes how to run the cross_file CLI and what each command does.
- [ ] At least one copy-pasteable example is provided.
- [ ] `dart analyze` and project docs remain consistent.

## Dependencies

- CLI and commands implemented so that documented usage is accurate.
