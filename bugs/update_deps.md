# Bug: Dependabot PR #271 closed without merge -- js-yaml bump

**Ref:** https://github.com/saropa/saropa_lints/pull/271
**Status:** Closed (unmerged)
**Severity:** Low -- dev dependency only

## Problem

Dependabot PR to bump `js-yaml` from 4.1.1 to 4.3.0 in `extension/` was closed without merging. It had been blocked by:

1. **Workflow approval required** -- GitHub Actions workflow from Dependabot needed maintainer approval
2. **Merge conflict** in `analysis_options.yaml`

The PR is now closed. The `js-yaml` dependency remains at 4.1.1.

## Checks That Had Passed

- CodeQL: actions, java-kotlin, javascript-typescript, python -- all green
- Code scanning: no new alerts

## To Resolve

Either reopen PR #271 and resolve the conflict, or manually bump `js-yaml` in `extension/package.json` and run `npm install` in `extension/`.
