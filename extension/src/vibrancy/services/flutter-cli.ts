import { execFile } from 'child_process';

/** Result of a Flutter CLI command execution. */
export interface CommandResult {
    readonly success: boolean;
    readonly output: string;
}

function runFlutterCommand(
    args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    return new Promise((resolve) => {
        execFile(
            'flutter', args,
            { encoding: 'utf-8', timeout, cwd },
            (err, stdout, stderr) => {
                resolve({
                    success: !err,
                    output: (stdout || '') + (stderr || ''),
                });
            },
        );
    });
}

function runDartCommand(
    args: string[], cwd: string, timeout: number,
): Promise<CommandResult> {
    return new Promise((resolve) => {
        execFile(
            'dart', args,
            { encoding: 'utf-8', timeout, cwd },
            (err, stdout, stderr) => {
                resolve({
                    success: !err,
                    output: (stdout || '') + (stderr || ''),
                });
            },
        );
    });
}

/** Run `dart pub outdated --json` in the given directory. */
export function runDartPubOutdated(cwd: string): Promise<CommandResult> {
    return runDartCommand(['pub', 'outdated', '--json'], cwd, 120_000);
}

/** Run `dart pub deps --json` in the given directory. */
export function runDartPubDeps(cwd: string): Promise<CommandResult> {
    return runDartCommand(['pub', 'deps', '--json'], cwd, 60_000);
}

/** Run `flutter pub get` in the given directory. */
export function runPubGet(cwd: string): Promise<CommandResult> {
    return runFlutterCommand(['pub', 'get'], cwd, 60_000);
}

/** Run `flutter test` in the given directory. */
export function runFlutterTest(cwd: string): Promise<CommandResult> {
    return runFlutterCommand(['test'], cwd, 300_000);
}
