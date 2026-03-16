import { execFile } from 'child_process';

/** Run a command and return stdout, or empty string on failure. */
function runCommand(cmd: string, args: string[], timeout: number): Promise<string> {
    return new Promise((resolve) => {
        execFile(cmd, args, { encoding: 'utf-8', timeout }, (err, stdout, stderr) => {
            resolve(err ? (stderr || '') : (stdout || stderr || ''));
        });
    });
}

/** Detect locally installed Dart SDK version. */
export async function detectDartVersion(): Promise<string> {
    try {
        const output = await runCommand('dart', ['--version'], 5000);
        const match = output.match(/Dart SDK version:\s*(\S+)/);
        return match?.[1] ?? 'unknown';
    } catch {
        return 'unknown';
    }
}

/** Detect locally installed Flutter SDK version. */
export async function detectFlutterVersion(): Promise<string> {
    try {
        const output = await runCommand('flutter', ['--version'], 10000);
        const match = output.match(/Flutter\s+(\S+)/);
        return match?.[1] ?? 'unknown';
    } catch {
        return 'unknown';
    }
}
