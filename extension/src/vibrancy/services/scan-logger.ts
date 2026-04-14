/**
 * Scan log accumulator for Package Vibrancy scans.
 *
 * Each scan builds up timestamped entries via `log()` / `info()` / etc.
 * On completion, `writeToFile()` persists them to the workspace's
 * `reports/` directory using an **hourly** file strategy:
 *
 *   reports/yyyymmdd/yyyymmdd_HH_pubspec_vibrancy.log
 *
 * Multiple scans within the same clock-hour append to the same file
 * (separated by a visual rule).  If the scan summary (package counts)
 * is identical to the previous entry, the write is skipped entirely
 * to avoid bloating the log with duplicate no-op results.
 */
import * as vscode from 'vscode';

type LogLevel = 'INFO' | 'CACHE' | 'API' | 'SCORE' | 'ERROR';

/** Accumulates timestamped log entries during a scan for writing to disk. */
export class ScanLogger {
    private readonly _entries: string[] = [];
    private readonly _startTime = Date.now();

    /** Append a timestamped entry. */
    log(level: LogLevel, message: string): void {
        const ts = new Date().toISOString();
        this._entries.push(`${ts}  [${level.padEnd(5)}]  ${message}`);
    }

    info(message: string): void { this.log('INFO', message); }
    error(message: string): void { this.log('ERROR', message); }
    cacheHit(key: string): void { this.log('CACHE', `HIT  ${key}`); }
    cacheMiss(key: string): void { this.log('CACHE', `MISS ${key}`); }

    apiRequest(method: string, url: string): void {
        this.log('API', `${method} ${url}`);
    }

    apiResponse(status: number, statusText: string, ms: number): void {
        this.log('API', `${status} ${statusText} (${ms}ms)`);
    }

    score(params: {
        readonly name: string; readonly total: number;
        readonly category: string; readonly rv: number;
        readonly eg: number; readonly pop: number;
        readonly pt?: number; readonly pq?: number;
    }): void {
        const { name, total, category, rv, eg, pop, pt, pq } = params;
        const ptStr = pt !== undefined ? ` pt=${pt}` : '';
        const pqStr = pq !== undefined ? ` pq=${pq}` : '';
        this.log(
            'SCORE',
            `${name} → ${total} (${category}) [rv=${rv} eg=${eg} pop=${pop}${ptStr}${pqStr}]`,
        );
    }

    /** Produce the full log content. */
    toLogContent(): string {
        return this._entries.join('\n') + '\n';
    }

    /**
     * Append to the current hour's log file:
     *   reports/yyyymmdd/yyyymmdd_HH_pubspec_vibrancy.log
     *
     * If the file already exists and its last non-empty line matches
     * the last line of this scan's output (identical summary), the
     * write is skipped — nothing changed since the previous scan.
     */
    async writeToFile(): Promise<string | null> {
        const folders = vscode.workspace.workspaceFolders;
        if (!folders || folders.length === 0) { return null; }

        const now = new Date();
        const dateDir = formatDateDir(now);
        const hour = String(now.getHours()).padStart(2, '0');
        const fileName = `${dateDir}_${hour}_pubspec_vibrancy.log`;

        const dirUri = vscode.Uri.joinPath(
            folders[0].uri, 'reports', dateDir,
        );
        await vscode.workspace.fs.createDirectory(dirUri);

        const fileUri = vscode.Uri.joinPath(dirUri, fileName);
        const newContent = this.toLogContent();

        // Skip write when results are identical to the previous scan
        // in this hour's log (avoids bloat from no-op rescans).
        // Compare only the result portion of the summary line — the
        // timestamp prefix and elapsed-ms vary between scans even
        // when the actual package scores are unchanged.
        const existing = await readFileIfExists(fileUri);
        if (existing !== null) {
            const prevSummary = extractScanSummary(lastNonEmptyLine(existing));
            const newSummary = extractScanSummary(lastNonEmptyLine(newContent));
            if (prevSummary && newSummary && prevSummary === newSummary) {
                return fileUri.fsPath;
            }
        }

        // Append with a separator so consecutive scans are readable.
        const separator = existing
            ? `\n${'─'.repeat(60)}\n\n`
            : '';
        const combined = (existing ?? '') + separator + newContent;
        await vscode.workspace.fs.writeFile(
            fileUri, Buffer.from(combined, 'utf-8'),
        );
        return fileUri.fsPath;
    }

    get elapsedMs(): number { return Date.now() - this._startTime; }
}

function formatDateDir(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}${m}${d}`;
}

/** Read a file's UTF-8 content, returning null if it doesn't exist. */
async function readFileIfExists(uri: vscode.Uri): Promise<string | null> {
    try {
        const bytes = await vscode.workspace.fs.readFile(uri);
        return Buffer.from(bytes).toString('utf-8');
    } catch {
        return null;
    }
}

/** Return the last non-empty line from a string, or null. */
export function lastNonEmptyLine(text: string): string | null {
    const lines = text.split('\n');
    for (let i = lines.length - 1; i >= 0; i--) {
        const trimmed = lines[i].trim();
        if (trimmed.length > 0) { return trimmed; }
    }
    return null;
}

/**
 * Extract the result-counts portion of a summary line, stripping
 * the volatile timestamp and elapsed-ms prefix.
 *
 * Input:  "2026-04-14T01:28:55Z  [INFO ]  Scan complete — 2290ms — vibrant:28 stable:48 ..."
 * Output: "vibrant:28 stable:48 ..."
 *
 * Returns null if the line doesn't contain a recognizable summary.
 */
export function extractScanSummary(line: string | null): string | null {
    if (!line) { return null; }

    // The summary line format is:
    //   <timestamp>  [INFO ]  Scan complete — <N>ms — <counts>
    // We want everything after the second " — ".
    const marker = 'Scan complete';
    const idx = line.indexOf(marker);
    if (idx < 0) { return null; }

    // Skip "Scan complete — NNNms — " to get to the counts.
    const afterMarker = line.substring(idx + marker.length);
    const dashParts = afterMarker.split(' — ');
    // dashParts[0] = "" (before first —), [1] = "2290ms", [2] = "vibrant:28 ..."
    return dashParts.length >= 3 ? dashParts.slice(2).join(' — ').trim() : null;
}
