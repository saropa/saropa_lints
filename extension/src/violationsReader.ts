/**
 * Read reports/.saropa_lints/violations.json and expose summary + violations.
 */

import * as path from 'path';
import * as fs from 'fs';

export interface Violation {
  file: string;
  line: number;
  rule: string;
  message: string;
  severity?: string;
  impact?: string;
  correction?: string;
}

export interface BySeverity {
  error?: number;
  warning?: number;
  info?: number;
}

export interface ByImpact {
  critical?: number;
  high?: number;
  medium?: number;
  low?: number;
  opinionated?: number;
}

export interface ViolationsData {
  violations: Violation[];
  summary?: {
    totalViolations?: number;
    filesAnalyzed?: number;
    filesWithIssues?: number;
    bySeverity?: BySeverity;
    byImpact?: ByImpact;
  };
  config?: {
    tier?: string;
    enabledRuleCount?: number;
  };
}

export function getViolationsPath(workspaceRoot: string): string {
  return path.join(workspaceRoot, 'reports', '.saropa_lints', 'violations.json');
}

export function readViolations(workspaceRoot: string): ViolationsData | null {
  const p = getViolationsPath(workspaceRoot);
  if (!fs.existsSync(p)) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(p, 'utf-8'));
    return {
      violations: Array.isArray(raw.violations) ? raw.violations : [],
      summary: raw.summary ?? undefined,
      config: raw.config ?? undefined,
    };
  } catch {
    return null;
  }
}

export function hasViolations(workspaceRoot: string): boolean {
  const data = readViolations(workspaceRoot);
  if (!data) return false;
  return (data.summary?.totalViolations ?? data.violations.length) > 0;
}
