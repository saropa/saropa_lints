/**
 * Pure (vscode-free) logic for the upgrade-pack nudge, split out so it can be
 * unit-tested directly. The vscode wiring lives in upgradePackNudge.ts.
 */
import { RULE_PACK_DEFINITIONS, type RulePackDefinition } from './rulePackDefinitions';

/** SDK packs are surfaced separately; the upgrade nudge covers dependency gates. */
function isSdkPackId(id: string): boolean {
  return id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_');
}

/** Parse `pubspec.lock` into package name -> resolved version. */
export function parseLockVersions(lockContent: string): Map<string, string> {
  const out = new Map<string, string>();
  const lines = lockContent.split(/\r\n?|\n/);
  let inPackages = false;
  let currentPkg: string | undefined;
  for (const line of lines) {
    if (!inPackages) {
      if (line.trim() === 'packages:') inPackages = true;
      continue;
    }
    // A top-level key (no indent) ends the packages block.
    if (!line.startsWith(' ') && line.includes(':')) break;
    const pkgMatch = /^ {2}([a-zA-Z0-9_-]+):\s*$/.exec(line);
    if (pkgMatch) {
      currentPkg = pkgMatch[1];
      continue;
    }
    const verMatch = /^ {4}version:\s+"?([^"\n]+?)"?\s*$/.exec(line);
    if (verMatch && currentPkg) out.set(currentPkg, verMatch[1].trim());
  }
  return out;
}

/** Numeric x.y.z compare; missing segments treated as 0. */
export function compareSemver(a: string, b: string): number {
  const pa = a.split('.').map((x) => Number.parseInt(x, 10));
  const pb = b.split('.').map((x) => Number.parseInt(x, 10));
  const n = Math.max(pa.length, pb.length);
  for (let i = 0; i < n; i++) {
    const da = Number.isFinite(pa[i]) ? pa[i] : 0;
    const db = Number.isFinite(pb[i]) ? pb[i] : 0;
    if (da !== db) return da < db ? -1 : 1;
  }
  return 0;
}

/** True when [resolved] satisfies a `>=x.y.z` constraint. */
export function satisfiesMinConstraint(resolved: string, constraint: string): boolean {
  const min = /^>=\s*(\d+\.\d+\.\d+)/.exec(constraint.trim())?.[1];
  if (!min) return false;
  const ver = /^(\d+\.\d+\.\d+)/.exec(resolved.trim())?.[1];
  if (!ver) return false;
  return compareSemver(ver, min) >= 0;
}

/**
 * Dependency-gated packs whose gate is satisfied by the resolved lockfile
 * version and that are not already enabled. SDK packs are excluded (they have
 * their own enablement flow).
 */
export function applicableDisabledPacks(
  lockVersions: Map<string, string>,
  enabled: ReadonlySet<string>,
): RulePackDefinition[] {
  return RULE_PACK_DEFINITIONS.filter((def) => {
    const gate = def.dependencyGate;
    if (!gate || isSdkPackId(def.id)) return false;
    if (enabled.has(def.id)) return false;
    const resolved = lockVersions.get(gate.package);
    if (!resolved) return false;
    return satisfiesMinConstraint(resolved, gate.constraint);
  });
}
