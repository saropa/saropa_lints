"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchDepGraph = fetchDepGraph;
exports.parseDepGraphJson = parseDepGraphJson;
exports.buildReverseDeps = buildReverseDeps;
const flutter_cli_1 = require("./flutter-cli");
/** Run `dart pub deps --json` and parse the output. */
async function fetchDepGraph(cwd) {
    const result = await (0, flutter_cli_1.runDartPubDeps)(cwd);
    if (!result.success) {
        return { root: '', packages: [], success: false };
    }
    return { ...parseDepGraphJson(result.output), success: true };
}
/** Parse the JSON output of `dart pub deps --json`. */
function parseDepGraphJson(jsonOutput) {
    const jsonStart = jsonOutput.indexOf('{');
    if (jsonStart < 0) {
        return { root: '', packages: [] };
    }
    let parsed;
    try {
        parsed = JSON.parse(jsonOutput.substring(jsonStart));
    }
    catch {
        return { root: '', packages: [] };
    }
    const root = typeof parsed.root === 'string' ? parsed.root : '';
    const rawPackages = parsed.packages;
    if (!Array.isArray(rawPackages)) {
        return { root, packages: [] };
    }
    const packages = [];
    for (const pkg of rawPackages) {
        if (!pkg || typeof pkg.name !== 'string') {
            continue;
        }
        packages.push({
            name: pkg.name,
            version: typeof pkg.version === 'string' ? pkg.version : '',
            kind: typeof pkg.kind === 'string' ? pkg.kind : '',
            dependencies: Array.isArray(pkg.dependencies)
                ? pkg.dependencies.filter((d) => typeof d === 'string')
                : [],
        });
    }
    return { root, packages };
}
/**
 * Build a reverse-dependency map: for each package, who depends on it?
 * Key = dependency name, Value = list of packages that depend on it.
 */
function buildReverseDeps(packages) {
    const reverse = new Map();
    for (const pkg of packages) {
        for (const dep of pkg.dependencies) {
            let edges = reverse.get(dep);
            if (!edges) {
                edges = [];
                reverse.set(dep, edges);
            }
            edges.push({ dependentPackage: pkg.name });
        }
    }
    return reverse;
}
//# sourceMappingURL=dep-graph.js.map