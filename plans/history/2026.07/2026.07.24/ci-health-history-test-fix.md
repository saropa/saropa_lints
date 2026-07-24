# CI: health_history_test shallow-clone failure

The `health_history_test` ("builds well-formed trajectory points from git tags") hard-asserted `expect(points, isNotEmpty)`, which fails on CI because GitHub Actions' shallow checkout does not include git tags. The test ran despite a `startsWith('Release v')` skip guard on the test job — the guard did not fire for the v14.3.8 release push (root cause of that non-skip is unconfirmed; may be a GitHub Actions expression-evaluation edge case).

## Finish Report (2026-07-24)

### Changes

| File | Change |
|------|--------|
| `test/project_health/health_history_test.dart` | Restored `expect(points, isNotEmpty)` hard assertion — CI now does a full clone so tags are always present. |
| `.github/workflows/ci.yml` | Changed test job checkout to `fetch-depth: 0` (full clone) so git tags and history are available for `health_history_test`. |
| `CHANGELOG.md` | Added `[Unreleased]` maintenance entry. |

### Verification

- All 4 tests in `health_history_test.dart` pass locally (tags present → test exercises the full assertion path).
- CI will confirm the fix on push.

### Residual

- The `if: !startsWith(...)` guard on the test job did not skip the `Release v14.3.8` push as intended. This is a separate issue — the test resilience fix makes it non-blocking regardless.
