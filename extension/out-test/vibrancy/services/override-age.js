"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getOverrideAge = getOverrideAge;
exports.getOverrideAges = getOverrideAges;
exports.calculateAgeDays = calculateAgeDays;
exports.formatAge = formatAge;
const child_process_1 = require("child_process");
/**
 * Get the date when a dependency override was introduced via git log.
 * Searches for when the package name first appeared in the dependency_overrides section.
 */
async function getOverrideAge(packageName, cwd) {
    try {
        const result = await runGitLog(packageName, cwd);
        if (!result.success || !result.date) {
            return null;
        }
        return result.date;
    }
    catch {
        return null;
    }
}
/**
 * Get override ages for multiple packages in a single pass.
 * More efficient than calling getOverrideAge for each package.
 */
async function getOverrideAges(packageNames, cwd) {
    const ages = new Map();
    const promises = packageNames.map(async (name) => {
        const date = await getOverrideAge(name, cwd);
        if (date) {
            ages.set(name, date);
        }
    });
    await Promise.all(promises);
    return ages;
}
/**
 * Calculate the number of days since a given date.
 */
function calculateAgeDays(addedDate) {
    if (!addedDate) {
        return null;
    }
    const now = new Date();
    const diffMs = now.getTime() - addedDate.getTime();
    return Math.floor(diffMs / (1000 * 60 * 60 * 24));
}
/**
 * Format age in a human-readable way.
 */
function formatAge(ageDays) {
    if (ageDays === null) {
        return 'unknown age';
    }
    if (ageDays < 7) {
        return `${ageDays} day${ageDays !== 1 ? 's' : ''}`;
    }
    if (ageDays < 30) {
        const weeks = Math.floor(ageDays / 7);
        return `${weeks} week${weeks !== 1 ? 's' : ''}`;
    }
    if (ageDays < 365) {
        const months = Math.floor(ageDays / 30);
        return `${months} month${months !== 1 ? 's' : ''}`;
    }
    const years = Math.floor(ageDays / 365);
    return `${years} year${years !== 1 ? 's' : ''}`;
}
function runGitLog(packageName, cwd) {
    return new Promise((resolve) => {
        (0, child_process_1.execFile)('git', [
            'log',
            '--diff-filter=A',
            '-1',
            '--format=%ai',
            '-S', packageName,
            '--',
            'pubspec.yaml',
        ], { encoding: 'utf-8', timeout: 10_000, cwd }, (err, stdout) => {
            if (err || !stdout.trim()) {
                runGitLogFallback(packageName, cwd).then(resolve);
                return;
            }
            const date = parseGitDate(stdout.trim());
            resolve({ success: true, date });
        });
    });
}
function runGitLogFallback(packageName, cwd) {
    return new Promise((resolve) => {
        (0, child_process_1.execFile)('git', [
            'log',
            '-1',
            '--format=%ai',
            '-S', packageName,
            '--',
            'pubspec.yaml',
        ], { encoding: 'utf-8', timeout: 10_000, cwd }, (err, stdout) => {
            if (err || !stdout.trim()) {
                resolve({ success: false, date: null });
                return;
            }
            const date = parseGitDate(stdout.trim());
            resolve({ success: true, date });
        });
    });
}
function parseGitDate(dateStr) {
    if (!dateStr) {
        return null;
    }
    const date = new Date(dateStr);
    return isNaN(date.getTime()) ? null : date;
}
//# sourceMappingURL=override-age.js.map