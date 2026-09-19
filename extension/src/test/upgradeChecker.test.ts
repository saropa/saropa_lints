/**
 * Prompt-suppression bug surfaced during issue #208 follow-up: the upgrade
 * checker recorded `lastKnownLatest` BEFORE showing the toast, so a
 * missed/closed/collapsed notification silenced that version forever —
 * the user was never asked again until a newer release shipped. The fix
 * separates the pub.dev *fetch* throttle ([shouldFetchNow], unchanged)
 * from *prompting*: we now prompt on every activation while outdated,
 * and only an explicit "Don't ask for this version" click writes
 * `dismissedVersion` ([shouldPromptForVersion]). Legacy state written
 * under the old `lastKnownLatest` schema must NOT be treated as a
 * dismissal — these tests pin that migration.
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
    const saved = { nextCheckDueMs: now + 30 * MIN, cachedLatest: '1.0.0' };
    assert.strictEqual(shouldFetchNow(saved, now), false);
  });

  it('returns true once the deadline has elapsed', () => {
    const now = Date.now();
    const saved = { nextCheckDueMs: now - 1 * MIN, cachedLatest: '1.0.0' };
    assert.strictEqual(shouldFetchNow(saved, now), true);
  });

  it('returns true at the exact deadline boundary (>=, not >)', () => {
    // Boundary inclusive: at exactly the deadline, fetching is allowed.
    // Strict `>` would force users to wait one extra ms in pathological
    // cases — acceptable, but `>=` is what the implementation contracts.
    const now = Date.now();
    const saved = { nextCheckDueMs: now, cachedLatest: '1.0.0' };
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

  it('within the anti-thrash window, the cached latest is still usable for prompting', () => {
    // shouldFetchNow only gates the pub.dev *fetch*. checkForUpgrade does
    // not return early when this is false — it falls through and prompts
    // from `cachedLatest`. Pin both halves together so a regression that
    // makes checkForUpgrade bail out early on a false fetch gate would be
    // caught by re-deriving the same "should we skip the fetch" answer.
    const now = Date.now();
    const saved = { nextCheckDueMs: now + 30 * MIN, cachedLatest: '16.2.1' };
    assert.strictEqual(shouldFetchNow(saved, now), false);
    assert.strictEqual(shouldPromptForVersion(saved, saved.cachedLatest), true);
  });
});

describe('shouldPromptForVersion', () => {
  it('returns true on first run when no state has been saved', () => {
    // First time we see saropa_lints is outdated, always prompt.
    assert.strictEqual(shouldPromptForVersion(undefined, '13.4.2'), true);
  });

  it('returns false when the latest version matches dismissedVersion', () => {
    // User explicitly clicked "Don't ask for this version" — staying
    // quiet about exactly that version is the entire point of the field.
    const saved = { nextCheckDueMs: 0, dismissedVersion: '13.4.2' };
    assert.strictEqual(shouldPromptForVersion(saved, '13.4.2'), false);
  });

  it('returns true when pub.dev has a newer version than the dismissed one', () => {
    // A version bump on pub.dev breaks through the dismiss memory and
    // re-prompts even though an older version was dismissed.
    const saved = { nextCheckDueMs: 0, dismissedVersion: '13.4.1' };
    assert.strictEqual(shouldPromptForVersion(saved, '13.4.2'), true);
  });

  it('returns true even for a downgrade scenario (latest != dismissedVersion)', () => {
    // pub.dev rarely retracts versions, but if `latestVersion` ever
    // diverges from a dismissed value in either direction the user
    // should know about the change. We compare for inequality, not
    // strict-greater, deliberately.
    const saved = { nextCheckDueMs: 0, dismissedVersion: '13.4.2' };
    assert.strictEqual(shouldPromptForVersion(saved, '13.4.1'), true);
  });

  it('legacy state ({nextCheckDueMs, lastKnownLatest}) does NOT suppress the prompt', () => {
    // This is the regression test for the original bug: pre-fix code
    // wrote `lastKnownLatest` on every check (even just showing the
    // toast), so a missed/closed notification silenced that version
    // forever. The fixed schema only suppresses via `dismissedVersion`,
    // which legacy state never has — so it must always prompt here,
    // even though `lastKnownLatest` happens to equal `latestVersion`.
    const legacy = { nextCheckDueMs: 0, lastKnownLatest: '16.2.1' };
    assert.strictEqual(shouldPromptForVersion(legacy, '16.2.1'), true);
  });

  it('reproduces the reported case end-to-end: 15.2.12 stuck silent since 16.2.1', () => {
    // Real-world report: a project on 15.2.12 saw 16.2.1 once, the toast
    // was missed, and legacy state recorded lastKnownLatest = '16.2.1'.
    // Both halves of the check must agree the project should be prompted:
    // the fetch may or may not be due (irrelevant to prompting), and the
    // version check must not treat the legacy record as a dismissal.
    const now = Date.now();
    const legacy = { nextCheckDueMs: now - HOUR, lastKnownLatest: '16.2.1' };
    assert.strictEqual(shouldFetchNow(legacy, now), true);
    assert.strictEqual(shouldPromptForVersion(legacy, '16.2.1'), true);
  });
});
