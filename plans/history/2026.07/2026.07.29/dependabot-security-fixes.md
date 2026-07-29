# Dependabot Security Fixes — extension npm dependencies

Three high-severity Dependabot alerts (#11, #12, #13) flagged vulnerable transitive dependencies in `extension/package-lock.json`. All affected packages were dev-only (build/test tooling), not shipped to end users.

## Finish Report (2026-07-29)

### Alerts Resolved

| Alert | Package | Vulnerability | Fix |
|-------|---------|---------------|-----|
| #13 | `shell-quote@1.8.4` | Quadratic DoS in `parse()` (CWE-407) | Merged Dependabot PR #278 (→ 1.10.0), then replaced parent `npm-run-all` with `npm-run-all2@8` |
| #11 | `brace-expansion@1.1.14` | Exponential DoS via non-expanding `{}` groups | Eliminated entirely — `npm-run-all2` uses `picomatch` instead of `minimatch`/`brace-expansion` |
| #12 | `brace-expansion@2.1.0` | Same vulnerability, different major line | `overrides` entry in `package.json` forces `>=2.1.3` (mocha → minimatch → brace-expansion path) |

### Changes

- **`extension/package.json`**: replaced `npm-run-all@^4.1.5` (abandoned since 2019) with `npm-run-all2@^8.0.4` (maintained fork, same CLI binaries). Added `brace-expansion: ">=2.1.3"` to `overrides`.
- **`extension/package-lock.json`**: regenerated. Net reduction of ~2000 lines (npm-run-all2 has fewer transitive dependencies).
- **`CHANGELOG.md`**: maintenance entry added under `[Unreleased]`.

### Verification

- `npm ls shell-quote` → 1.10.0 (via npm-run-all2)
- `npm ls brace-expansion` → 5.0.8 (mocha path only; npm-run-all path eliminated)
- `npm audit` → 0 high-severity alerts remaining
- `gh api repos/saropa/saropa_lints/dependabot/alerts` → 0 open alerts
- `npx npm-run-all --version` → v8.0.4 (CLI compatibility confirmed)

### Remaining Low-Severity Audit Finding

`diff@6.0.0–8.0.2` (via mocha) has a DoS vulnerability in `parsePatch`/`applyPatch` (GHSA-73rr-hh4g-fpgx). Fixable via `npm audit fix` when mocha releases a patched version. Low severity, dev-only.
