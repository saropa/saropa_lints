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
        readonly pt?: number;
    }): void {
        const { name, total, category, rv, eg, pop, pt } = params;
        const ptStr = pt !== undefined ? ` pt=${pt}` : '';
        this.log(
            'SCORE',
            `${name} → ${total} (${category}) [rv=${rv} eg=${eg} pop=${pop}${ptStr}]`,
        );
    }

    /** Produce the full log content. */
    toLogContent(): string {
        return this._entries.join('\n') + '\n';
    }

    /** Write accumulated log to reports/yyyymmdd/yyyymmdd_HHmmss_pubspec_vibrancy.log. */
    async writeToFile(): Promise<string | null> {
        const folders = vscode.workspace.workspaceFolders;
        if (!folders || folders.length === 0) { return null; }

        const now = new Date();
        const dateDir = formatDateDir(now);
        const fileName = `${dateDir}_${formatTime(now)}_pubspec_vibrancy.log`;

        const dirUri = vscode.Uri.joinPath(
            folders[0].uri, 'reports', dateDir,
        );
        await vscode.workspace.fs.createDirectory(dirUri);

        const fileUri = vscode.Uri.joinPath(dirUri, fileName);
        await vscode.workspace.fs.writeFile(
            fileUri, Buffer.from(this.toLogContent(), 'utf-8'),
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

function formatTime(date: Date): string {
    const h = String(date.getHours()).padStart(2, '0');
    const min = String(date.getMinutes()).padStart(2, '0');
    const s = String(date.getSeconds()).padStart(2, '0');
    return `${h}${min}${s}`;
}
