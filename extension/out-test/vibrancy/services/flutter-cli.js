"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runDartPubOutdated = runDartPubOutdated;
exports.runDartPubDeps = runDartPubDeps;
exports.runPubGet = runPubGet;
exports.runFlutterTest = runFlutterTest;
const child_process_1 = require("child_process");
function runFlutterCommand(args, cwd, timeout) {
    return new Promise((resolve) => {
        (0, child_process_1.execFile)('flutter', args, { encoding: 'utf-8', timeout, cwd }, (err, stdout, stderr) => {
            resolve({
                success: !err,
                output: (stdout || '') + (stderr || ''),
            });
        });
    });
}
function runDartCommand(args, cwd, timeout) {
    return new Promise((resolve) => {
        (0, child_process_1.execFile)('dart', args, { encoding: 'utf-8', timeout, cwd }, (err, stdout, stderr) => {
            resolve({
                success: !err,
                output: (stdout || '') + (stderr || ''),
            });
        });
    });
}
/** Run `dart pub outdated --json` in the given directory. */
function runDartPubOutdated(cwd) {
    return runDartCommand(['pub', 'outdated', '--json'], cwd, 120_000);
}
/** Run `dart pub deps --json` in the given directory. */
function runDartPubDeps(cwd) {
    return runDartCommand(['pub', 'deps', '--json'], cwd, 60_000);
}
/** Run `flutter pub get` in the given directory. */
function runPubGet(cwd) {
    return runFlutterCommand(['pub', 'get'], cwd, 60_000);
}
/** Run `flutter test` in the given directory. */
function runFlutterTest(cwd) {
    return runFlutterCommand(['test'], cwd, 300_000);
}
//# sourceMappingURL=flutter-cli.js.map