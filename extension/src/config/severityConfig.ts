/**
 * Reads the `saropaLints.severity.*` toggle settings and maps them to
 * VS Code DiagnosticSeverity values — lets users bulk-suppress an entire
 * severity level (e.g. turn off all hints) from VS Code settings instead
 * of hiding 13,000 issues one at a time.
 */
import * as vscode from 'vscode';

/** VS Code setting keys for each severity toggle. */
const SEVERITY_SETTINGS = {
  error: 'saropaLints.severity.error',
  warning: 'saropaLints.severity.warning',
  info: 'saropaLints.severity.info',
  hint: 'saropaLints.severity.hint',
} as const;

/**
 * Returns the set of DiagnosticSeverity values currently enabled in
 * user/workspace settings. All four are on by default.
 */
export function getEnabledSeverities(): Set<vscode.DiagnosticSeverity> {
  const cfg = vscode.workspace.getConfiguration();
  const enabled = new Set<vscode.DiagnosticSeverity>();
  // Each toggle defaults to true — a missing or true value enables that severity.
  if (cfg.get<boolean>(SEVERITY_SETTINGS.error, true)) {
    enabled.add(vscode.DiagnosticSeverity.Error);
  }
  if (cfg.get<boolean>(SEVERITY_SETTINGS.warning, true)) {
    enabled.add(vscode.DiagnosticSeverity.Warning);
  }
  if (cfg.get<boolean>(SEVERITY_SETTINGS.info, true)) {
    enabled.add(vscode.DiagnosticSeverity.Information);
  }
  if (cfg.get<boolean>(SEVERITY_SETTINGS.hint, true)) {
    enabled.add(vscode.DiagnosticSeverity.Hint);
  }
  return enabled;
}

/**
 * Returns true when the given DiagnosticSeverity is enabled in settings.
 * Avoids allocating a Set for single-diagnostic checks.
 */
export function isSeverityEnabled(severity: vscode.DiagnosticSeverity): boolean {
  const cfg = vscode.workspace.getConfiguration();
  switch (severity) {
    case vscode.DiagnosticSeverity.Error:
      return cfg.get<boolean>(SEVERITY_SETTINGS.error, true) !== false;
    case vscode.DiagnosticSeverity.Warning:
      return cfg.get<boolean>(SEVERITY_SETTINGS.warning, true) !== false;
    case vscode.DiagnosticSeverity.Information:
      return cfg.get<boolean>(SEVERITY_SETTINGS.info, true) !== false;
    case vscode.DiagnosticSeverity.Hint:
      return cfg.get<boolean>(SEVERITY_SETTINGS.hint, true) !== false;
    default:
      return true;
  }
}

/**
 * Returns true when the configuration change event affects any of the
 * four severity toggle settings — callers use this to know when to
 * re-filter diagnostics.
 */
export function affectsSeveritySettings(e: vscode.ConfigurationChangeEvent): boolean {
  return (
    e.affectsConfiguration(SEVERITY_SETTINGS.error) ||
    e.affectsConfiguration(SEVERITY_SETTINGS.warning) ||
    e.affectsConfiguration(SEVERITY_SETTINGS.info) ||
    e.affectsConfiguration(SEVERITY_SETTINGS.hint)
  );
}

/**
 * Maps the Issues tree's string-based severity vocabulary ('error',
 * 'warning', 'info') to the set of strings whose corresponding
 * DiagnosticSeverity is currently enabled. Used to initialize the
 * tree's `severitiesToShow` from settings on startup.
 */
export function getEnabledSeverityStrings(): Set<string> {
  const cfg = vscode.workspace.getConfiguration();
  const enabled = new Set<string>();
  // The Issues tree uses 'error'/'warning'/'info' — there is no 'hint'
  // bucket in the tree, so the hint toggle only affects the Problems panel.
  if (cfg.get<boolean>(SEVERITY_SETTINGS.error, true)) enabled.add('error');
  if (cfg.get<boolean>(SEVERITY_SETTINGS.warning, true)) enabled.add('warning');
  if (cfg.get<boolean>(SEVERITY_SETTINGS.info, true)) enabled.add('info');
  return enabled;
}

/**
 * Returns how many of the 4 severity toggles are currently enabled.
 * Used for the sidebar section badge (e.g. "Severity Filters (3/4)").
 */
export function getEnabledSeverityCount(): number {
  return getEnabledSeverities().size;
}
