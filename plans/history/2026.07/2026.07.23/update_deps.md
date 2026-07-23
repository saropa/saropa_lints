# Bug: Dependabot PR #271 closed without merge -- js-yaml bump

**Ref:** https://github.com/saropa/saropa_lints/pull/271
**Status:** Fixed
**Severity:** Low -- dev dependency only

## Problem

Dependabot PR to bump `js-yaml` from 4.1.1 to 4.3.0 in `extension/` was closed without merging. It had been blocked by workflow approval and a merge conflict in `analysis_options.yaml`.

## Resolution

js-yaml is a transitive dependency (via mocha `^4.1.0` spec), not a direct project dependency. The lock file already resolves to 4.3.0, so the bump occurred naturally during a subsequent `npm install`. Dependabot PR was superseded.
