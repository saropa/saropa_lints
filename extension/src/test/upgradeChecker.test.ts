/**
 * Throttle bug surfaced during issue #208 follow-up: the upgrade-check
 * gate was a single 24h timer, so a brand-new saropa_lints version
 * published within 24h of a dismiss was invisible until the timer
 * elapsed. The fix is "throttle per anti-thrash window OR per newly-
 * published version" — these tests pin both halves of that promise.
 */
import * as assert from 'node:assert';
import { shouldFetchNow, shouldPromptForVersion } from '../upgrade-checker';

const MIN = 60 * 1000;
const HOUR = 60 * MIN;

describe('shouldFetchNow', () => {
  it('returns true on first run when no state has been saved', () => {
    // Cold-start: nothing has been fetched yet, so we always fetch.
    assert.strictEqual(shouldFetchNow(undefined, Date.now()), true);
  });

  it('returns false when the deadline is still in the future', () => {
    // Anti-thrash window blocks repeated fetches within the same hour
    // (the common "VS Code reloaded twice in five minutes" pattern).
    const now = Date.now();
    const saved = { nextCheckDueMs: now + 30 * MIN, lastKnownLatest: '1.0.0' };
    assert.strictEqual(shouldFetchNow(saved, now), false);
  });

  it('returns true once the deadline has elapsed', () => {
    const now = Date.now();
    const saved = { nextCheckDueMs: now - 1 * MIN, lastKnownLatest: '1.0.0' };
    assert.strictEqual(shouldFetchNow(saved, now), true);
  });

  it('returns true at the exact deadline boundary (>=, not >)', () => {
    // Boundary inclusive: at exactly the deadline, fetching is allowed.
    // Strict `>` would force users to wait one extra ms in pathological
    // cases — acceptable, but `>=` is what the implementation contracts.
    const now = Date.now();
    const saved = { nextCheckDueMs: now, lastKnownLatest: '1.0.0' };
    assert.strictEqual(shouldFetchNow(saved, now), true);
  });

  it('legacy 24h state still blocks until its (longer) deadline elapses', () => {
    // Self-healing migration: pre-fix code wrote `now + 24h`. We honour
    // it as a deadline, so legacy state degrades gracefully — one-time
    // wait of up to 24h, then the next write replaces it with 1h
    // semantics. Documented in the [shouldFetchNow] doc-comment.
    const now = Date.now();
    const legacy24h = { nextCheckDueMs: now + 23 * HOUR, lastKnownLatest: '1.0.0' };
    assert.strictEqual(shouldFetchNow(legacy24h, now), false);
    // Once the legacy 24h deadline elapses, fetching resumes.
    assert.strictEqual(shouldFetchNow(legacy24h, now + 24 * HOUR), true);
  });
});

describe('shouldPromptForVersion', () => {
  it('returns true on first run when no state has been saved', () => {
    // First time we see saropa_lints is outdated, always prompt.
    assert.strictEqual(shouldPromptForVersion(undefined, '13.4.2'), true);
  });

  it('returns false when the latest version matches lastKnownLatest', () => {
    // User already dismissed exactly this version — staying quiet about
    // it is the entire point of `lastKnownLatest`.
    const saved = { nextCheckDueMs: 0, lastKnownLatest: '13.4.2' };
    assert.strictEqual(shouldPromptForVersion(saved, '13.4.2'), false);
  });

  it('returns true when pub.dev has a newer version than the dismissed one', () => {
    // The "OR per version" half of the throttle promise — a version
    // bump on pub.dev breaks through the dismiss memory and re-prompts
    // even if the anti-thrash window says we just fetched.
    const saved = { nextCheckDueMs: 0, lastKnownLatest: '13.4.1' };
    assert.strictEqual(shouldPromptForVersion(saved, '13.4.2'), true);
  });

  it('returns true even for a downgrade scenario (latest != lastKnownLatest)', () => {
    // pub.dev rarely retracts versions, but if `latestVersion` ever
    // diverges from a dismissed value in either direction the user
    // should know about the change. We compare for inequality, not
    // strict-greater, deliberately.
    const saved = { nextCheckDueMs: 0, lastKnownLatest: '13.4.2' };
    assert.strictEqual(shouldPromptForVersion(saved, '13.4.1'), true);
  });
});
