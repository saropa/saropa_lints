"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.detectDartVersion = detectDartVersion;
exports.detectFlutterVersion = detectFlutterVersion;
const child_process_1 = require("child_process");
/** Run a command and return stdout, or empty string on failure. */
function runCommand(cmd, args, timeout) {
    return new Promise((resolve) => {
        (0, child_process_1.execFile)(cmd, args, { encoding: 'utf-8', timeout }, (err, stdout, stderr) => {
            resolve(err ? (stderr || '') : (stdout || stderr || ''));
        });
    });
}
/** Detect locally installed Dart SDK version. */
async function detectDartVersion() {
    try {
        const output = await runCommand('dart', ['--version'], 5000);
        const match = output.match(/Dart SDK version:\s*(\S+)/);
        return match?.[1] ?? 'unknown';
    }
    catch {
        return 'unknown';
    }
}
/** Detect locally installed Flutter SDK version. */
async function detectFlutterVersion() {
    try {
        const output = await runCommand('flutter', ['--version'], 10000);
        const match = output.match(/Flutter\s+(\S+)/);
        return match?.[1] ?? 'unknown';
    }
    catch {
        return 'unknown';
    }
}
//# sourceMappingURL=sdk-detector.js.map