# CI and analyzer fixes (March 2026)

**Status:** Resolved.

## Summary

GitHub CI was failing repeatedly due to:

1. **Workflow:** `ref: ${{ github.head_ref }}` is empty on `push` events, so checkout could be wrong; format-and-push ran on every push to `main`, causing extra runs and possible permission failures.
2. **Analyzer:** Several rules referenced static `RegExp` or helpers inside AST callbacks; the analyzer treated those as undefined in that scope, so `dart analyze --fatal-infos` and test load failed.

## Fixes applied

- **`.github/workflows/ci.yml`:** Use `ref: ${{ github.head_ref || github.ref }}`; run "Commit formatting changes" only when `github.event_name == 'pull_request'`.
- **Rule files:** Where the analyzer could not see static members in callbacks, regexes/helpers were moved to local variables or inlined in `runWithReporter` (e.g. `architecture_rules.dart`, `bloc_rules.dart`, `supabase_rules.dart`, `url_launcher_rules.dart`, `equatable_rules.dart`, `package_specific_rules.dart`). `error_handling_rules.dart`: brace style for linter. `bloc_rules.dart`: use `isFieldCleanedUp` from `target_matcher_utils` for dispose checks.

No new bug report was opened; this file records the resolution.
