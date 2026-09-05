/**
 * Owns the lifetime of the one scan daemon per window: lazy spawn on first
 * scan, crash detection with exponential respawn backoff, and teardown on
 * config change or extension deactivation. The controller talks only to
 * this manager; `ScanDaemonClient` handles the wire protocol.
 *
 * Backoff matters because a daemon that dies during startup (broken SDK,
 * bad tier, target project missing pubspec) would otherwise be respawned
 * on every save, each attempt burning a full analyzer warmup.
 */
import { ScanDaemonClient } from './scanDaemonClient';
import { resolveExcludeLane, resetLivenessCache } from '../config/laneConfig';
import { l10n } from '../i18n/runtime';
import type { ScanOnSaveResult } from './scanOnSaveRunner';

export const RESPAWN_BACKOFF_BASE_MS = 1_000;
export const RESPAWN_BACKOFF_MAX_MS = 30_000;

/** Exponential backoff: 1s, 2s, 4s … capped at 30s. Zero failures → no wait. */
export function respawnBackoffMs(consecutiveFailures: number): number {
  if (consecutiveFailures <= 0) return 0;
  return Math.min(RESPAWN_BACKOFF_MAX_MS, RESPAWN_BACKOFF_BASE_MS * 2 ** (consecutiveFailures - 1));
}

export class ScanDaemonManager {
  /** The one live daemon client, or undefined between spawns. */
  private _client: ScanDaemonClient | undefined;
  /** Project root the current client was spawned for (spawn-arg identity). */
  private _clientRoot: string | undefined;
  /** Tier the current client was spawned with — a tier change invalidates it. */
  private _clientTier: string | undefined;
  /** Consecutive unexpected exits since the last successful scan; drives backoff. */
  private _consecutiveFailures = 0;
  /** Epoch ms before which _ensureClient refuses to respawn (backoff window). */
  private _blockedUntilEpochMs = 0;

  /** True while the daemon exists but has not answered its first request. */
  get isWarming(): boolean {
    return this._client?.isWarming ?? false;
  }

  /** True when a daemon process is alive (spawned and not yet exited). */
  get isAlive(): boolean {
    return this._client?.isAlive ?? false;
  }

  /** True when the manager is refusing to respawn (backoff window active). */
  get isInBackoff(): boolean {
    return Date.now() < this._blockedUntilEpochMs;
  }

  /**
   * Scans [files] via the daemon, spawning or respawning it as needed.
   * Never rejects; failures settle with `payload: null` + `errorMessage`.
   */
  async scan(root: string, files: readonly string[], tier: string): Promise<ScanOnSaveResult> {
    const client = this._ensureClient(root, tier);
    if (!client) {
      return {
        payload: null,
        exitCode: -1,
        errorMessage: l10n('notify.commands.scanOnSaveDaemonBackoff'),
      };
    }
    // Two-lane de-duplication. resolveExcludeLane returns 'light' ONLY when
    // the project configures the light lane AND the in-process plugin is
    // verifiably reporting; any doubt means scan everything, so a finding can
    // never fall between the two lanes (see config/laneConfig.ts).
    const result = await client.scan(files, resolveExcludeLane(root));
    if (result.payload) this._consecutiveFailures = 0;
    return result;
  }

  /**
   * Lists the project's Dart files via the daemon (spawning/respawning as
   * needed), for the baseline scan to chunk before issuing per-chunk `scan`
   * calls. Null on daemon-down/backoff, matching {@link scan}'s never-reject
   * contract.
   */
  async listFiles(root: string, tier: string): Promise<string[] | null> {
    const client = this._ensureClient(root, tier);
    if (!client) return null;
    return client.listFiles();
  }

  /** Drops the current daemon (config change / disable); next save respawns fresh. */
  restart(): void {
    // A restart follows a config change, which may have flipped the lane or
    // enabled/disabled the plugin — the cached liveness verdict describes the
    // old configuration and must not decide the next scan's exclusion.
    resetLivenessCache();
    this._dropClient();
  }

  dispose(): void {
    this._dropClient();
  }

  private _dropClient(): void {
    this._client?.dispose();
    this._client = undefined;
  }

  private _ensureClient(root: string, tier: string): ScanDaemonClient | undefined {
    const current = this._client;
    if (current?.isAlive && this._clientRoot === root && this._clientTier === tier) {
      return current;
    }
    if (Date.now() < this._blockedUntilEpochMs) return undefined;
    this._dropClient();
    const client = new ScanDaemonClient(root, tier, () => this._onUnexpectedExit());
    client.start();
    this._client = client;
    this._clientRoot = root;
    this._clientTier = tier;
    return client;
  }

  private _onUnexpectedExit(): void {
    this._consecutiveFailures += 1;
    this._blockedUntilEpochMs = Date.now() + respawnBackoffMs(this._consecutiveFailures);
    this._client = undefined;
  }
}
