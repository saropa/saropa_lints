/**
 * Machine-capacity snapshot and pressure classification for scans.
 *
 * Mirrors `lib/src/scan/scan_pressure.dart` so the extension and the Dart scan
 * process agree on what "tight" means: both leave ~10% of RAM (bounded to
 * 512–2048 MB) for the rest of the machine, call free memory under twice that
 * reserve "high", and under the reserve itself "critical".
 *
 * Pure apart from {@link readMachineSnapshot}, so every decision is
 * unit-testable without a real machine.
 */
import * as os from 'node:os';

export type PressureLevel = 'ok' | 'high' | 'critical';

export interface MachineSnapshot {
  /** Total physical memory in MB. */
  readonly totalMb: number;
  /** Memory available for new work in MB (OS "available", not just "free"). */
  readonly freeMb: number;
  /** Logical CPU count. */
  readonly cores: number;
}

export interface MachinePressure {
  readonly level: PressureLevel;
  readonly freeMb: number;
  readonly reserveMb: number;
}

/** Reads the current machine snapshot. Never throws. */
export function readMachineSnapshot(): MachineSnapshot {
  let cores = 1;
  try {
    cores = Math.max(1, os.cpus().length);
  } catch {
    cores = 1;
  }
  return {
    totalMb: Math.round(os.totalmem() / (1024 * 1024)),
    freeMb: Math.round(os.freemem() / (1024 * 1024)),
    cores,
  };
}

/** 10% of RAM, bounded to 512..2048 MB; 768 when the total is unknown. */
export function defaultReserveMb(totalMb: number | undefined): number {
  if (totalMb === undefined || !Number.isFinite(totalMb) || totalMb <= 0) return 768;
  const tenth = Math.floor(totalMb / 10);
  return Math.min(2048, Math.max(512, tenth));
}

/** Classifies a snapshot: critical below the reserve, high below twice it. */
export function classifyMachinePressure(
  snapshot: MachineSnapshot,
  reserveMb: number = defaultReserveMb(snapshot.totalMb),
): MachinePressure {
  let level: PressureLevel = 'ok';
  if (snapshot.freeMb < reserveMb) level = 'critical';
  else if (snapshot.freeMb < reserveMb * 2) level = 'high';
  return { level, freeMb: snapshot.freeMb, reserveMb };
}
