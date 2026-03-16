"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchPubOutdated = fetchPubOutdated;
exports.parsePubOutdatedJson = parsePubOutdatedJson;
const flutter_cli_1 = require("./flutter-cli");
/** Run `dart pub outdated --json` and parse the output. */
async function fetchPubOutdated(cwd) {
    const result = await (0, flutter_cli_1.runDartPubOutdated)(cwd);
    if (!result.success) {
        return { entries: [], success: false };
    }
    const entries = parsePubOutdatedJson(result.output);
    return { entries, success: true };
}
/** Extract version string from a pub outdated version object. */
function extractVersion(obj) {
    if (!obj || typeof obj !== 'object') {
        return null;
    }
    const version = obj.version;
    return typeof version === 'string' ? version : null;
}
/** Parse the JSON output of `dart pub outdated --json`. */
function parsePubOutdatedJson(jsonOutput) {
    const jsonStart = jsonOutput.indexOf('{');
    if (jsonStart < 0) {
        return [];
    }
    let parsed;
    try {
        parsed = JSON.parse(jsonOutput.substring(jsonStart));
    }
    catch {
        return [];
    }
    const packages = parsed.packages;
    if (!Array.isArray(packages)) {
        return [];
    }
    const entries = [];
    for (const pkg of packages) {
        if (!pkg || typeof pkg.package !== 'string') {
            continue;
        }
        entries.push({
            package: pkg.package,
            current: extractVersion(pkg.current),
            upgradable: extractVersion(pkg.upgradable),
            resolvable: extractVersion(pkg.resolvable),
            latest: extractVersion(pkg.latest),
        });
    }
    return entries;
}
//# sourceMappingURL=pub-outdated.js.map