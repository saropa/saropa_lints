# js-yaml GHSA-5p4m-2wfm-xmqj remediation

GitHub Dependabot flagged `js-yaml` 4.3.0 (transitive dev dependency of `mocha`, via `extension/package-lock.json`) for GHSA-5p4m-2wfm-xmqj, a high-severity vulnerability affecting versions `>= 4.0.0 < 4.3.1`. Suggested update #285 recommended upgrading to `~> 4.3.1`.

## Resolution

Ran `npm update js-yaml` in `extension/`, bumping the resolved dependency from 4.3.0 to 4.3.1 in `extension/package-lock.json`. `js-yaml` is a dev-only transitive dependency pulled in by `mocha`'s toolchain — no extension source code, build output, or user-facing behavior depends on it directly.

## Verification

Confirmed `extension/package-lock.json` resolves `node_modules/js-yaml` to version `4.3.1`, which is outside the affected range.
