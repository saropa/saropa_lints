import * as vscode from 'vscode';
import * as crypto from 'crypto';
import { VibrancyResult } from '../types';
import { ParsedDeps } from '../scan-helpers';
import { ReportMetadata } from './report-exporter';

/**
 * Startup-scan skip-gate.
 *
 * On VS Code restart the package vibrancy scan triggers an unconditional
 * progress notification, even when nothing has changed since the last
 * scan ran in this workspace.  This module persists a small fingerprint
 * of the last successful scan so the next startup can rehydrate the
 * results silently when:
 *
 *   1. `pubspec.lock` bytes are unchanged (no `pub get` since last scan), AND
 *   2. The relevant scan-config inputs are unchanged (weights, allowlist,
 *      repo overrides, publisher trust bonus), AND
 *   3. The last scan completed within the user-configured skip TTL.
 *
 * If any condition fails — or the persisted blob is missing, malformed,
 * or written by an older schema — the gate falls back to a normal scan.
 *
 * The fingerprint lives in workspaceState (per-workspace, not synced)
 * because pubspec.lock is workspace-scoped and rehydrated results would
 * be misleading in a different workspace.
 */

/**
 * Schema version for the persisted fingerprint.  Bump whenever the
 * shape of `VibrancyResult`, `ParsedDeps`, or `ReportMetadata` changes
 * in a way that would break deserialised consumers.  Any mismatch
 * forces a fresh scan on the next startup.
 */
export const FINGERPRINT_SCHEMA_VERSION = 1;

/** workspaceState key holding the most recent successful scan fingerprint. */
export const FINGERPRINT_STATE_KEY = 'spv.lastScan';

/**
 * The persisted snapshot.  Kept intentionally small: just enough for
 * `publishResults(...)` to repaint the tree, codelens and diagnostics
 * without re-running any network or AST work.
 *
 * `depGraphSummary` is left as `unknown` here to avoid pulling the
 * `DepGraphSummary` type — we only ever round-trip it via JSON.
 */
export interface LastScanFingerprint {
    /** Schema version of this blob; mismatch forces rescan. */
    readonly schemaVersion: number;
    /** sha256 of pubspec.lock bytes at the time of the scan. */
    readonly lockHash: string;
    /** sha256 over scan-config inputs that affect results. */
    readonly configHash: string;
    /** Wall-clock ms since epoch when the scan completed. */
    readonly timestamp: number;
    /** Snapshot of `latestResults` for rehydration. */
    readonly results: VibrancyResult[];
    /** Snapshot of `lastParsedDeps` (yaml URI is re-derived on load). */
    readonly parsedDeps: SerialisedParsedDeps;
    /** Snapshot of `lastScanMeta` for the report exporter. */
    readonly scanMeta: ReportMetadata;
    /** JSON-safe snapshot of the dep-graph summary; opaque here. */
    readonly depGraphSummary: unknown | null;
}

/** ParsedDeps with the URI flattened to a string for JSON storage. */
export interface SerialisedParsedDeps {
    readonly deps: ParsedDeps['deps'];
    readonly yamlUriString: string;
    readonly yamlContent: string;
}

/**
 * Inputs that influence scan output but live in user settings, not in
 * `pubspec.lock`.  Hashing these means the gate invalidates whenever
 * the user retunes scoring or allowlist — no listener required.
 */
export interface ConfigFingerprintInputs {
    readonly weights: Readonly<Record<string, number>>;
    readonly allowlist: readonly string[];
    readonly repoOverrides: Readonly<Record<string, string>>;
    readonly publisherTrustBonus: number;
}

/** Compute a stable sha256 of a Buffer / Uint8Array. */
export function hashBytes(bytes: Uint8Array): string {
    return crypto.createHash('sha256').update(bytes).digest('hex');
}

/**
 * Compute a stable sha256 over the scan-config inputs.  Sorts keys at
 * every nesting level so the hash is insensitive to JSON property
 * order returned by VS Code's settings parser.
 */
export function hashConfig(inputs: ConfigFingerprintInputs): string {
    return crypto.createHash('sha256').update(canonicalStringify(inputs)).digest('hex');
}

/**
 * Recursively serialise a value with deterministic key ordering.  Used
 * instead of JSON.stringify's replacer-array trick, which only filters
 * top-level keys and would silently drop nested fields like
 * `weights.a`, producing incorrect hash collisions.
 */
function canonicalStringify(value: unknown): string {
    if (value === null || typeof value !== 'object') {
        return JSON.stringify(value);
    }
    if (Array.isArray(value)) {
        return '[' + value.map(canonicalStringify).join(',') + ']';
    }
    const keys = Object.keys(value as Record<string, unknown>).sort();
    const entries = keys.map(k => {
        const v = (value as Record<string, unknown>)[k];
        return JSON.stringify(k) + ':' + canonicalStringify(v);
    });
    return '{' + entries.join(',') + '}';
}

/**
 * Read the pubspec.lock bytes and return their sha256.  Returns null
 * when the file cannot be read so the caller can fall back to a fresh
 * scan rather than crashing.
 */
export async function computeLockHash(lockUri: vscode.Uri): Promise<string | null> {
    try {
        const bytes = await vscode.workspace.fs.readFile(lockUri);
        return hashBytes(bytes);
    } catch {
        return null;
    }
}

/**
 * Load and validate the persisted fingerprint.  Returns null on any
 * shape / schema mismatch so the caller treats it as a cache miss.
 */
export function loadFingerprint(
    state: vscode.Memento,
): LastScanFingerprint | null {
    const raw = state.get<unknown>(FINGERPRINT_STATE_KEY);
    if (!raw || typeof raw !== 'object') { return null; }
    const fp = raw as Partial<LastScanFingerprint>;

    // Cheap shape gate before trusting the rest of the blob.
    if (fp.schemaVersion !== FINGERPRINT_SCHEMA_VERSION) { return null; }
    if (typeof fp.lockHash !== 'string') { return null; }
    if (typeof fp.configHash !== 'string') { return null; }
    if (typeof fp.timestamp !== 'number') { return null; }
    if (!Array.isArray(fp.results)) { return null; }
    if (!fp.parsedDeps || typeof fp.parsedDeps !== 'object') { return null; }
    if (!fp.scanMeta || typeof fp.scanMeta !== 'object') { return null; }

    return fp as LastScanFingerprint;
}

/** Persist a fingerprint.  Errors are swallowed (best-effort cache). */
export async function saveFingerprint(
    state: vscode.Memento,
    fingerprint: LastScanFingerprint,
): Promise<void> {
    try {
        await state.update(FINGERPRINT_STATE_KEY, fingerprint);
    } catch {
        // Persisting the fingerprint is purely an optimisation;
        // failure must never abort or surface to the user.
    }
}

/** Wipe the persisted fingerprint.  Used by the clear-cache command. */
export async function clearFingerprint(
    state: vscode.Memento,
): Promise<void> {
    try {
        await state.update(FINGERPRINT_STATE_KEY, undefined);
    } catch {
        // Same best-effort posture as saveFingerprint.
    }
}

/**
 * True when the fingerprint matches the current workspace state and
 * is still within the configured skip window.  A `skipTtlMinutes` of
 * 0 disables the gate entirely (always return false → always scan).
 */
export function isFingerprintFresh(
    fp: LastScanFingerprint,
    currentLockHash: string,
    currentConfigHash: string,
    skipTtlMinutes: number,
    now: number = Date.now(),
): boolean {
    if (skipTtlMinutes <= 0) { return false; }
    if (fp.lockHash !== currentLockHash) { return false; }
    if (fp.configHash !== currentConfigHash) { return false; }
    const ageMs = now - fp.timestamp;
    if (ageMs < 0) { return false; } // clock-skew safety
    return ageMs < skipTtlMinutes * 60 * 1000;
}

/** Convert ParsedDeps -> SerialisedParsedDeps (URI -> string). */
export function serialiseParsedDeps(parsed: ParsedDeps): SerialisedParsedDeps {
    return {
        deps: parsed.deps,
        yamlUriString: parsed.yamlUri.toString(),
        yamlContent: parsed.yamlContent,
    };
}

/** Convert SerialisedParsedDeps back into a live ParsedDeps. */
export function rehydrateParsedDeps(s: SerialisedParsedDeps): ParsedDeps {
    return {
        deps: s.deps,
        yamlUri: vscode.Uri.parse(s.yamlUriString),
        yamlContent: s.yamlContent,
    };
}
