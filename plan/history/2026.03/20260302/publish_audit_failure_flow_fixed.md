# Publish script: audit failure flow fixed

## Summary

When the pre-publish audit failed (e.g. tier integrity, duplicate rules, missing prefix, spelling), the script offered "Run DX message improver? [y/N]". The DX improver only fixes message quality (vague language, length, consequence); it does not fix missing `[rule_name]` prefix, tier assignments, or duplicates. Users who chose "y" saw "No DX improvements to apply" and then the script exited without fixing anything.

## Resolution

- **Prefix:** The script now auto-fixes missing `[rule_name]` prefix when that is one of the blocking issues: it runs `fix_missing_prefix()` once, re-runs the audit, and continues if the audit passes.
- **No prompt:** The "Run DX message improver?" prompt was removed. For non-fixable blocking issues (tier, duplicates, spelling, .contains() baseline), the script exits immediately with a single message: fix the issues marked with ✗ above and re-run.
- **Return value:** `run_pre_publish_audits()` now returns `(bool, audit_result)` on failure so the caller can detect `rules_missing_prefix` and run the prefix fix.

## Files changed

- `scripts/modules/_audit_checks.py`: added `fix_missing_prefix()`.
- `scripts/modules/_publish_steps.py`: return `(False, audit_result)` / `(True, None)`.
- `scripts/publish.py`: audit loop uses prefix fix only; single exit message; removed DX improver prompt.
- `lib/src/tiers.dart`: duplicate tier entries removed (rules in single tier) so audit passes.

## Related

- CHANGELOG.md: entry under ### Fixed for publish script (audit failure).
