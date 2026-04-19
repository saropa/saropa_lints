import '../register-vscode-mock';
import * as assert from 'assert';
import { MockMemento } from '../vscode-mock';
import {
    FINGERPRINT_SCHEMA_VERSION,
    FINGERPRINT_STATE_KEY,
    LastScanFingerprint,
    clearFingerprint,
    hashBytes,
    hashConfig,
    isFingerprintFresh,
    loadFingerprint,
    rehydrateParsedDeps,
    saveFingerprint,
    serialiseParsedDeps,
} from '../../../vibrancy/services/startup-gate';
import { ParsedDeps } from '../../../vibrancy/scan-helpers';

/**
 * Build a minimally-valid fingerprint blob for tests.  Fields are kept
 * small so failures point at the gate logic, not at fixture noise.
 */
function makeFingerprint(overrides: Partial<LastScanFingerprint> = {}): LastScanFingerprint {
    return {
        schemaVersion: FINGERPRINT_SCHEMA_VERSION,
        lockHash: 'lock-hash-aaa',
        configHash: 'config-hash-bbb',
        timestamp: Date.now(),
        results: [],
        parsedDeps: {
            deps: [],
            yamlUriString: 'file:///workspace/pubspec.yaml',
            yamlContent: 'name: test\n',
        },
        scanMeta: {
            flutterVersion: 'unknown',
            dartVersion: 'unknown',
            executionTimeMs: 0,
        },
        depGraphSummary: null,
        ...overrides,
    };
}

describe('startup-gate', () => {
    describe('hashBytes', () => {
        it('produces a stable sha256 hex string for identical input', () => {
            const a = hashBytes(Buffer.from('hello'));
            const b = hashBytes(Buffer.from('hello'));
            assert.strictEqual(a, b);
            assert.match(a, /^[0-9a-f]{64}$/);
        });

        it('produces a different hash for different input', () => {
            const a = hashBytes(Buffer.from('hello'));
            const b = hashBytes(Buffer.from('hello!'));
            assert.notStrictEqual(a, b);
        });
    });

    describe('hashConfig', () => {
        it('produces the same hash regardless of key insertion order', () => {
            const a = hashConfig({
                weights: { a: 1, b: 2 },
                allowlist: ['x', 'y'],
                repoOverrides: { foo: 'bar' },
                publisherTrustBonus: 15,
            });
            const b = hashConfig({
                publisherTrustBonus: 15,
                repoOverrides: { foo: 'bar' },
                allowlist: ['x', 'y'],
                weights: { a: 1, b: 2 },
            });
            assert.strictEqual(a, b);
        });

        it('changes when any input changes', () => {
            const base = hashConfig({
                weights: { a: 1 }, allowlist: [], repoOverrides: {},
                publisherTrustBonus: 15,
            });
            const changed = hashConfig({
                weights: { a: 2 }, allowlist: [], repoOverrides: {},
                publisherTrustBonus: 15,
            });
            assert.notStrictEqual(base, changed);
        });
    });

    describe('isFingerprintFresh', () => {
        const fp = makeFingerprint({
            timestamp: 1_000_000,
            lockHash: 'L',
            configHash: 'C',
        });

        it('returns true when lock + config match and within TTL', () => {
            const now = 1_000_000 + 30 * 60 * 1000; // 30 min later
            assert.strictEqual(isFingerprintFresh(fp, 'L', 'C', 60, now), true);
        });

        it('returns false when lock hash differs', () => {
            assert.strictEqual(isFingerprintFresh(fp, 'OTHER', 'C', 60, 1_000_000), false);
        });

        it('returns false when config hash differs', () => {
            assert.strictEqual(isFingerprintFresh(fp, 'L', 'OTHER', 60, 1_000_000), false);
        });

        it('returns false when older than TTL', () => {
            const now = 1_000_000 + 61 * 60 * 1000;
            assert.strictEqual(isFingerprintFresh(fp, 'L', 'C', 60, now), false);
        });

        it('returns false when TTL is zero (gate disabled)', () => {
            assert.strictEqual(isFingerprintFresh(fp, 'L', 'C', 0, 1_000_000), false);
        });

        it('returns false when clock skew makes age negative', () => {
            // Persisted timestamp is in the future (e.g. system clock changed).
            const now = 1_000_000 - 5 * 60 * 1000;
            assert.strictEqual(isFingerprintFresh(fp, 'L', 'C', 60, now), false);
        });
    });

    describe('loadFingerprint / saveFingerprint / clearFingerprint', () => {
        let memento: MockMemento;

        beforeEach(() => {
            memento = new MockMemento();
        });

        it('returns null when nothing has been persisted', () => {
            assert.strictEqual(loadFingerprint(memento as any), null);
        });

        it('round-trips a valid fingerprint via save then load', async () => {
            const fp = makeFingerprint();
            await saveFingerprint(memento as any, fp);
            const loaded = loadFingerprint(memento as any);
            assert.deepStrictEqual(loaded, fp);
        });

        it('returns null when the persisted blob has the wrong schema version', async () => {
            await memento.update(FINGERPRINT_STATE_KEY, {
                ...makeFingerprint(),
                schemaVersion: FINGERPRINT_SCHEMA_VERSION + 999,
            });
            assert.strictEqual(loadFingerprint(memento as any), null);
        });

        it('returns null when the persisted blob is malformed (missing fields)', async () => {
            // Simulate a partially-corrupted blob — the validator should
            // refuse it rather than letting publishResults crash later.
            await memento.update(FINGERPRINT_STATE_KEY, {
                schemaVersion: FINGERPRINT_SCHEMA_VERSION,
                lockHash: 'L',
                // configHash missing on purpose
                timestamp: 1,
                results: [],
                parsedDeps: { deps: [], yamlUriString: 'x', yamlContent: '' },
                scanMeta: {},
            });
            assert.strictEqual(loadFingerprint(memento as any), null);
        });

        it('returns null when the persisted value is not an object', async () => {
            await memento.update(FINGERPRINT_STATE_KEY, 'not-an-object');
            assert.strictEqual(loadFingerprint(memento as any), null);
        });

        it('clearFingerprint removes the persisted blob', async () => {
            await saveFingerprint(memento as any, makeFingerprint());
            assert.notStrictEqual(loadFingerprint(memento as any), null);
            await clearFingerprint(memento as any);
            assert.strictEqual(loadFingerprint(memento as any), null);
        });
    });

    describe('serialiseParsedDeps / rehydrateParsedDeps', () => {
        it('round-trips a ParsedDeps via serialise then rehydrate', () => {
            // Use a minimal mock URI so we don't need real vscode.Uri here —
            // toString() and parse() are exercised via the import.
            const original: ParsedDeps = {
                deps: [],
                yamlUri: { toString: () => 'file:///w/pubspec.yaml' } as any,
                yamlContent: 'name: example\n',
            };
            const serialised = serialiseParsedDeps(original);
            assert.strictEqual(serialised.yamlUriString, 'file:///w/pubspec.yaml');
            assert.strictEqual(serialised.yamlContent, 'name: example\n');

            const rehydrated = rehydrateParsedDeps(serialised);
            assert.strictEqual(rehydrated.yamlUri.toString(), 'file:///w/pubspec.yaml');
            assert.strictEqual(rehydrated.yamlContent, 'name: example\n');
        });
    });
});
