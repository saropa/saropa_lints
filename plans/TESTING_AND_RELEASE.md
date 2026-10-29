# Testing and release

## Version sync rule

The saropa_lints package (pub.dev) and the VS Code extension (Marketplace and Open VSX) always carry the same major.minor version. They may differ only in the patch (last) digit. Never map versions with an odd/even minor scheme and never change the major or minor between them. A beta is published first as a pre-release, then the stable release follows with the same major.minor; the Marketplace forbids reusing a version and requires a release version above the pre-release it follows, so the patch digit is the only room for a beta. Decided 2026-10-28 (plans/PLAN_analyzer_12_to_13_14_upgrade.md, decision 16). The publish script's version mapping (scripts/modules/_utils.py extension_version_for) is being changed to match; until it lands the script still uses the old odd/even mapping.

## Publish test scope

`scripts/publish.py` tests only the delta: uncommitted (staged and unstaged) changes, mapped to their test files, with `-x slow`. Earlier commits are not re-tested because they were tested when merged, so a clean tree prints "No uncommitted changes to test" and skips `dart test`. A broad-impact change (tiers, all_rules, plugin entry point) runs just the integrity and config test directories. The full fast suite runs only with `--full-tests` (env `SAROPA_FULL_TESTS=1`).
