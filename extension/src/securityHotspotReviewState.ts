import * as vscode from 'vscode';
import { RuleMetadataData, Violation } from './violationsReader';

/** Memento-backed review state (open / safe / fixed) for security-hotspot fingerprints. */

export type SecurityHotspotReviewState = 'open' | 'reviewed-safe' | 'reviewed-fixed';

interface StoredSecurityHotspotReviewState {
  readonly version: 1;
  readonly byFingerprint: Record<string, SecurityHotspotReviewState>;
}

const STORAGE_KEY = 'saropaLints.securityHotspotReviewState';

const EMPTY_STATE: StoredSecurityHotspotReviewState = {
  version: 1,
  byFingerprint: {},
};

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

export function hotspotFingerprint(violation: Violation): string {
  return [
    violation.rule ?? '',
    violation.file ?? '',
    String(violation.line ?? 0),
    (violation.message ?? '').trim(),
  ].join('|');
}

export class SecurityHotspotReviewStateService {
  constructor(private readonly workspaceState: vscode.Memento) {}

  get(violation: Violation): SecurityHotspotReviewState | undefined {
    const stored = this.read();
    return stored.byFingerprint[hotspotFingerprint(violation)];
  }

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

  getEffective(
    violation: Violation,
    metadataByRule?: Record<string, RuleMetadataData>,
  ): SecurityHotspotReviewState {
    return this.get(violation) ?? defaultSecurityHotspotReviewState(violation, metadataByRule);
  }

  private read(): StoredSecurityHotspotReviewState {
    const raw = this.workspaceState.get<StoredSecurityHotspotReviewState>(STORAGE_KEY);
    if (!raw || raw.version !== 1 || !raw.byFingerprint || typeof raw.byFingerprint !== 'object') {
      return EMPTY_STATE;
    }
    return raw;
  }
}

export interface SecurityHotspotReviewCounts {
  readonly total: number;
  readonly open: number;
  readonly reviewedSafe: number;
  readonly reviewedFixed: number;
}

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
