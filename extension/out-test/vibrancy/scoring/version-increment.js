"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifyIncrement = classifyIncrement;
exports.incrementMatchesFilter = incrementMatchesFilter;
exports.filterByIncrement = filterByIncrement;
exports.formatIncrement = formatIncrement;
const semver = __importStar(require("semver"));
/**
 * Classify the increment type between two semver versions.
 * Returns 'none' if versions are equal or cannot be parsed.
 */
function classifyIncrement(from, to) {
    const fromParsed = semver.parse(from);
    const toParsed = semver.parse(to);
    if (!fromParsed || !toParsed) {
        return 'none';
    }
    if (semver.eq(fromParsed, toParsed)) {
        return 'none';
    }
    if (!semver.gt(toParsed, fromParsed)) {
        return 'none';
    }
    if (toParsed.major > fromParsed.major) {
        return 'major';
    }
    if (toParsed.minor > fromParsed.minor) {
        return 'minor';
    }
    if (toParsed.patch > fromParsed.patch) {
        return 'patch';
    }
    if (toParsed.prerelease.length > 0 || fromParsed.prerelease.length > 0) {
        return 'prerelease';
    }
    return 'none';
}
/**
 * Check if an increment type passes a filter.
 * - 'all': Include all increment types
 * - 'major': Only major increments
 * - 'minor': Minor or major increments
 * - 'patch': Only patch increments
 */
function incrementMatchesFilter(increment, filter) {
    if (increment === 'none') {
        return false;
    }
    switch (filter) {
        case 'all':
            return true;
        case 'major':
            return increment === 'major';
        case 'minor':
            return increment === 'minor' || increment === 'major';
        case 'patch':
            return increment === 'patch';
    }
}
/**
 * Filter vibrancy results by increment type.
 * Only includes packages that:
 * - Have update info with a different latest version
 * - Match the specified increment filter
 */
function filterByIncrement(packages, filter) {
    return packages.filter(pkg => {
        const updateInfo = pkg.updateInfo;
        if (!updateInfo) {
            return false;
        }
        if (updateInfo.updateStatus === 'up-to-date') {
            return false;
        }
        const increment = classifyIncrement(updateInfo.currentVersion, updateInfo.latestVersion);
        return incrementMatchesFilter(increment, filter);
    });
}
/** Format version increment for display. */
function formatIncrement(increment) {
    switch (increment) {
        case 'major':
            return 'major';
        case 'minor':
            return 'minor';
        case 'patch':
            return 'patch';
        case 'prerelease':
            return 'prerelease';
        case 'none':
            return 'up-to-date';
    }
}
//# sourceMappingURL=version-increment.js.map