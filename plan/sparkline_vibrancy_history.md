# Sparkline Vibrancy History

## Goal

Persist vibrancy scan history per-package so the report can render inline sparkline trend indicators showing how each package's health score has changed over time.

## Data Model

### Storage location

`.saropa/vibrancy-history.json` in the workspace root (gitignored).

### Schema

```json
{
  "schemaVersion": 1,
  "snapshots": [
    {
      "timestamp": "2026-04-17T14:30:00Z",
      "extensionVersion": "12.0.1",
      "packages": {
        "provider": { "version": "6.1.2", "score": 82, "category": "vibrant", "grade": "A" },
        "http": { "version": "1.2.0", "score": 45, "category": "stable", "grade": "B" }
      }
    }
  ]
}
```

### Append rules

- On each completed scan, compare the new results to the most recent snapshot.
- **Only append** if at least one package changed version, was added, or was removed.
- Cap history at 50 snapshots. Drop the oldest when the limit is exceeded.
- Never overwrite or merge snapshots; each is immutable once written.

## Write path

1. After `runScan()` completes and `latestResults` is populated, call `appendVibrancySnapshot(results)`.
2. Read the existing history file (create if missing).
3. Build a new snapshot from `latestResults`.
4. Diff against `snapshots[snapshots.length - 1]` — skip write if packages + versions are identical.
5. Append and write atomically (write to `.tmp`, rename).

### New file

`extension/src/vibrancy/services/vibrancy-history.ts`

```typescript
export interface HistorySnapshot {
    readonly timestamp: string;
    readonly extensionVersion: string;
    readonly packages: Record<string, PackageSnapshot>;
}

export interface PackageSnapshot {
    readonly version: string;
    readonly score: number;
    readonly category: string;
    readonly grade: string;
}

export interface VibrancyHistory {
    readonly schemaVersion: number;
    readonly snapshots: HistorySnapshot[];
}
```

Key functions:
- `readHistory(workspaceRoot: string): Promise<VibrancyHistory>`
- `appendSnapshot(workspaceRoot: string, results: VibrancyResult[], extensionVersion: string): Promise<boolean>`
- `getPackageTrend(history: VibrancyHistory, packageName: string): number[]` — returns score array for sparkline

## Read path (sparkline rendering)

1. On report build, load history and pass trend arrays into `ReportOptions`.
2. In `buildRow()`, render an inline SVG sparkline in the score/category cell.
3. Sparkline: 40x16px, polyline, color matches the current category grade.

### SVG sparkline helper

```typescript
function buildSparklineSvg(scores: number[], color: string): string {
    if (scores.length < 2) { return ''; }
    const w = 40, h = 16;
    const step = w / (scores.length - 1);
    const points = scores.map((s, i) =>
        `${(i * step).toFixed(1)},${(h - (s / 100) * h).toFixed(1)}`
    ).join(' ');
    return `<svg width="${w}" height="${h}" class="sparkline">
        <polyline points="${points}" fill="none" stroke="${color}" stroke-width="1.5"/>
    </svg>`;
}
```

## Gitignore

Add `.saropa/` to the project's `.gitignore` template or document that users should gitignore it. The history file contains no secrets but is workspace-local state.

## Testing

- Unit test `appendSnapshot` with: empty history, identical scan (no-op), changed version (appends), cap at 50.
- Unit test `getPackageTrend` with: missing package, single snapshot, multiple snapshots.
- Unit test sparkline SVG rendering.

## Migration

- If `schemaVersion` does not match, discard and start fresh (v1 is the first version, no migration needed yet).

## Future extensions

- Trend arrow (up/down/flat) in tree items based on last 3 snapshots.
- Score delta column in report: "+2" or "-5" since previous snapshot.
- Full history view: timeline chart showing all packages over time.
