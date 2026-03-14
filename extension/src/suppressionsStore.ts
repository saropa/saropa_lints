/**
 * Persist and load view suppressions (hidden folders, files, rules) for the Issues tree.
 * Stored in workspace state so they survive reload.
 */

import * as vscode from 'vscode';

const KEY = 'saropaLints.suppressions';

export interface Suppressions {
  hiddenFolders: string[];
  hiddenFiles: string[];
  hiddenRules: string[];
  /** file path -> rule names to hide in that file only */
  hiddenRuleInFile: Record<string, string[]>;
  hiddenSeverities: string[];
  hiddenImpacts: string[];
}

export const DEFAULT_SUPPRESSIONS: Suppressions = {
  hiddenFolders: [],
  hiddenFiles: [],
  hiddenRules: [],
  hiddenRuleInFile: {},
  hiddenSeverities: [],
  hiddenImpacts: [],
};

export function loadSuppressions(workspaceState: vscode.Memento): Suppressions {
  const raw = workspaceState.get<unknown>(KEY);
  if (!raw || typeof raw !== 'object') return { ...DEFAULT_SUPPRESSIONS };
  const o = raw as Record<string, unknown>;
  return {
    hiddenFolders: Array.isArray(o.hiddenFolders) ? (o.hiddenFolders as string[]) : [],
    hiddenFiles: Array.isArray(o.hiddenFiles) ? (o.hiddenFiles as string[]) : [],
    hiddenRules: Array.isArray(o.hiddenRules) ? (o.hiddenRules as string[]) : [],
    hiddenRuleInFile:
      o.hiddenRuleInFile && typeof o.hiddenRuleInFile === 'object' && !Array.isArray(o.hiddenRuleInFile)
        ? (o.hiddenRuleInFile as Record<string, string[]>)
        : {},
    hiddenSeverities: Array.isArray(o.hiddenSeverities) ? (o.hiddenSeverities as string[]) : [],
    hiddenImpacts: Array.isArray(o.hiddenImpacts) ? (o.hiddenImpacts as string[]) : [],
  };
}

export function saveSuppressions(workspaceState: vscode.Memento, s: Suppressions): void {
  void workspaceState.update(KEY, s);
}

export function addHiddenFolder(s: Suppressions, folderPath: string): Suppressions {
  const normalized = folderPath.replace(/\\/g, '/').replace(/\/$/, '') || '/';
  if (s.hiddenFolders.includes(normalized)) return s;
  return { ...s, hiddenFolders: [...s.hiddenFolders, normalized].sort() };
}

export function addHiddenFile(s: Suppressions, filePath: string): Suppressions {
  const normalized = filePath.replace(/\\/g, '/');
  if (s.hiddenFiles.includes(normalized)) return s;
  return { ...s, hiddenFiles: [...s.hiddenFiles, normalized].sort() };
}

export function addHiddenRule(s: Suppressions, rule: string): Suppressions {
  if (s.hiddenRules.includes(rule)) return s;
  return { ...s, hiddenRules: [...s.hiddenRules, rule].sort() };
}

export function addHiddenRuleInFile(s: Suppressions, filePath: string, rule: string): Suppressions {
  const normalized = filePath.replace(/\\/g, '/');
  const existing = s.hiddenRuleInFile[normalized] ?? [];
  if (existing.includes(rule)) return s;
  return {
    ...s,
    hiddenRuleInFile: { ...s.hiddenRuleInFile, [normalized]: [...existing, rule].sort() },
  };
}

export function addHiddenSeverity(s: Suppressions, severity: string): Suppressions {
  if (s.hiddenSeverities.includes(severity)) return s;
  return { ...s, hiddenSeverities: [...s.hiddenSeverities, severity] };
}

export function addHiddenImpact(s: Suppressions, impact: string): Suppressions {
  if (s.hiddenImpacts.includes(impact)) return s;
  return { ...s, hiddenImpacts: [...s.hiddenImpacts, impact] };
}

export function clearSuppressions(): Suppressions {
  return { ...DEFAULT_SUPPRESSIONS };
}

/** True if file path is hidden by folder prefix or file/glob suppression. Globs match full path. */
export function isPathHidden(s: Suppressions, filePath: string): boolean {
  const normalized = filePath.replace(/\\/g, '/');
  for (const folder of s.hiddenFolders) {
    if (folder === '/' && normalized.length > 0) continue;
    if (normalized === folder || normalized.startsWith(folder + '/')) return true;
  }
  if (s.hiddenFiles.includes(normalized)) return true;
  for (const pattern of s.hiddenFiles) {
    if (pattern.includes('*') && simpleGlobMatch(pattern, normalized)) return true;
  }
  return false;
}

/** True if rule is hidden globally or in this file. */
export function isRuleHidden(s: Suppressions, filePath: string, rule: string): boolean {
  if (s.hiddenRules.includes(rule)) return true;
  const normalized = filePath.replace(/\\/g, '/');
  const fileRules = s.hiddenRuleInFile[normalized];
  return Array.isArray(fileRules) && fileRules.includes(rule);
}

function simpleGlobMatch(pattern: string, path: string): boolean {
  const parts = pattern.split('*');
  if (parts.length === 1) return path === pattern;
  let remaining = path;
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i];
    if (p === '') continue;
    const idx = remaining.indexOf(p);
    if (idx < 0) return false;
    remaining = remaining.slice(idx + p.length);
  }
  return true;
}
