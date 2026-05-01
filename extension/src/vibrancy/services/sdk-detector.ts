import { execFile } from 'child_process';

// Windows installs dart/flutter as .bat shims. Node 18.20+/20.12+/22+ refuses
// to spawn .bat/.cmd without shell:true (CVE-2024-27980 mitigation), and even
// before that, execFile bypasses PATHEXT so plain "dart" returns ENOENT.
// Routing through cmd.exe via shell:true on Windows fixes both. Args here are
// hardcoded ('--version'); no injection surface.
const USE_SHELL = process.platform === 'win32';

/** Run a command and return stdout, or empty string on failure. */
function runCommand(cmd: string, args: string[], timeout: number): Promise<string> {
    return new Promise((resolve) => {
        execFile(cmd, args, { encoding: 'utf-8', timeout, shell: USE_SHELL }, (err, stdout, stderr) => {
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
