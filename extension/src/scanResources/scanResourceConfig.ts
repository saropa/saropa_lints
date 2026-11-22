/**
 * Reads the scan resource settings from VS Code configuration. The only
 * module in this folder (besides the UI) that touches `vscode`; all logic
 * lives in the pure modules next to it.
 */
import * as vscode from 'vscode';
import {
  normalizeScanResourceSettings,
  type ScanResourceSettings,
} from './scanResourceSettings';

/** Current settings, read fresh each call so changes apply without a reload. */
export function readScanResourceSettings(): ScanResourceSettings {
  const cfg = vscode.workspace.getConfiguration('saropaLints');
  return normalizeScanResourceSettings({
    profile: cfg.get<unknown>('scan.performanceProfile'),
    maxWorkers: cfg.get<unknown>('scan.maxWorkers'),
    maxMemoryMb: cfg.get<unknown>('scan.maxMemoryMb'),
    lowPriority: cfg.get<unknown>('scan.lowPriority'),
    baselineMode: cfg.get<unknown>('scanOnSave.baselineMode'),
    notifyOnPressure: cfg.get<unknown>('scan.notifyOnPressure'),
  });
}
