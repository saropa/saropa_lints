/**
 * Security-hotspot triage state persisted in `vscode.Memento` (workspace scope).
 *
 * Fingerprints stable strings from rule + location + message so review badges
 * survive tree refreshes without re-running analysis. Callers distinguish
 * hotspot-shaped violations via metadata and tags before reading or writing state.
 */
import * as vscode from 'vscode';
import { RuleMetadataData, Violation } from './violationsReader';

/** User triage outcome shown in the Issues tree and hotspot quick-picks. */
export type SecurityHotspotReviewState = 'open' | 'reviewed-safe' | 'reviewed-fixed';

/** On-disk / memento JSON shape; version gate allows future migrations. */
interface StoredSecurityHotspotReviewState {
  readonly version: 1;
  /** Fingerprint → review state map; grows unbounded with unique violations. */
  readonly byFingerprint: Record<string, SecurityHotspotReviewState>;
}

/** Workspace-state key shared by all read/write paths in this module. */
const STORAGE_KEY = 'saropaLints.securityHotspotReviewState';

/** Sentinel when memento is empty or schema mismatches (treated as no reviews). */
const EMPTY_STATE: StoredSecurityHotspotReviewState = {
  version: 1,
  byFingerprint: {},
};

/** True when rule metadata or violation snapshot marks a security hotspot / review item. */
export function isSecurityHotspotViolation(
  violation: Violation,
  metadataByRule?: Record<string, RuleMetadataData>,
): boolean {
  const snapshot = metadataByRule?.[violation.rule];
  const ruleType = snapshot?.ruleType ?? violation.metadata?.ruleType;
  if (ruleType === 'securityHotspot') {
    return true;
  }
  const requiresReview = snapshot?.requiresReview ?? violation.metadata?.requiresReview;
  if (requiresReview === true) {
    return true;
  }
  const tags = snapshot?.tags ?? violation.metadata?.tags ?? [];
  return tags.includes('review-required');
}

/** Initial UI state before any user action; prefers metadata defaults then `open`. */
export function defaultSecurityHotspotReviewState(
  violation: Violation,
  metadataByRule?: Record<string, RuleMetadataData>,
): SecurityHotspotReviewState {
  const raw = metadataByRule?.[violation.rule]?.defaultReviewState
    ?? violation.metadata?.defaultReviewState;
  if (raw === 'reviewed-safe' || raw === 'reviewed-fixed') {
    return raw;
  }
  return 'open';
}

/** Stable key for memento storage; order-sensitive—do not reorder segments lightly. */
export function hotspotFingerprint(violation: Violation): string {
  return [
    violation.rule ?? '',
    violation.file ?? '',
    String(violation.line ?? 0),
    (violation.message ?? '').trim(),
  ].join('|');
}

/** Thin wrapper over `workspaceState` get/update with fingerprint indirection. */
export class SecurityHotspotReviewStateService {
  constructor(private readonly workspaceState: vscode.Memento) {}

  /** Returns persisted state only; does not apply metadata defaults. */
  get(violation: Violation): SecurityHotspotReviewState | undefined {
    const stored = this.read();
    return stored.byFingerprint[hotspotFingerprint(violation)];
  }

  /** Merges into existing map and awaits memento write (triggers storage IO). */
  async set(violation: Violation, state: SecurityHotspotReviewState): Promise<void> {
    const stored = this.read();
    await this.workspaceState.update(STORAGE_KEY, {
      version: 1,
      byFingerprint: {
        ...stored.byFingerprint,
        [hotspotFingerprint(violation)]: state,
      },
    } satisfies StoredSecurityHotspotReviewState);
  }

  /** Union of explicit memento value and `defaultSecurityHotspotReviewState`. */
  getEffective(
    violation: Violation,
    metadataByRule?: Record<string, RuleMetadataData>,
  ): SecurityHotspotReviewState {
    return this.get(violation) ?? defaultSecurityHotspotReviewState(violation, metadataByRule);
  }

  /** Validates version and object shape before trusting memento contents. */
  private read(): StoredSecurityHotspotReviewState {
    const raw = this.workspaceState.get<StoredSecurityHotspotReviewState>(STORAGE_KEY);
    if (!raw || raw.version !== 1 || !raw.byFingerprint || typeof raw.byFingerprint !== 'object') {
      return EMPTY_STATE;
    }
    return raw;
  }
}

/** Aggregate counts for badges / progress in the Issues view hotspot section. */
export interface SecurityHotspotReviewCounts {
  readonly total: number;
  readonly open: number;
  readonly reviewedSafe: number;
  readonly reviewedFixed: number;
}

/** Single pass over violations; skips non-hotspots; uses effective state per row. */
export function countSecurityHotspotReviewStates(
  violations: readonly Violation[],
  metadataByRule: Record<string, RuleMetadataData> | undefined,
  service: Pick<SecurityHotspotReviewStateService, 'getEffective'>,
): SecurityHotspotReviewCounts {
  let total = 0;
  let open = 0;
  let reviewedSafe = 0;
  let reviewedFixed = 0;

  for (const violation of violations) {
    if (!isSecurityHotspotViolation(violation, metadataByRule)) {
      continue;
    }
    total += 1;
    const state = service.getEffective(violation, metadataByRule);
    if (state === 'reviewed-safe') {
      reviewedSafe += 1;
    } else if (state === 'reviewed-fixed') {
      reviewedFixed += 1;
    } else {
      open += 1;
    }
  }

  return { total, open, reviewedSafe, reviewedFixed };
}
