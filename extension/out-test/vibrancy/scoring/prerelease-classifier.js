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
exports.isPrerelease = isPrerelease;
exports.getPrereleaseTag = getPrereleaseTag;
exports.findLatestPrerelease = findLatestPrerelease;
exports.findLatestStable = findLatestStable;
exports.filterByTags = filterByTags;
exports.isPrereleaseNewerThanStable = isPrereleaseNewerThanStable;
exports.getPrereleaseTier = getPrereleaseTier;
exports.formatPrereleaseTag = formatPrereleaseTag;
exports.extractPrereleaseInfo = extractPrereleaseInfo;
const semver = __importStar(require("semver"));
/** Check if a version string contains a prerelease suffix. */
function isPrerelease(version) {
    const parsed = semver.parse(version);
    if (!parsed) {
        return false;
    }
    return parsed.prerelease.length > 0;
}
/** Extract the prerelease tag from a version (e.g., 'dev', 'beta', 'rc'). */
function getPrereleaseTag(version) {
    const parsed = semver.parse(version);
    if (!parsed || parsed.prerelease.length === 0) {
        return null;
    }
    const first = parsed.prerelease[0];
    if (typeof first === 'string') {
        return first.toLowerCase();
    }
    return null;
}
/** Find the latest prerelease version from a list of versions. */
function findLatestPrerelease(versions) {
    const prereleases = versions.filter(isPrerelease);
    if (prereleases.length === 0) {
        return null;
    }
    return prereleases.reduce((latest, current) => {
        if (!latest) {
            return current;
        }
        return semver.gt(current, latest) ? current : latest;
    }, prereleases[0]);
}
/** Find the latest stable version from a list of versions. */
function findLatestStable(versions) {
    const stable = versions.filter(v => !isPrerelease(v));
    if (stable.length === 0) {
        return null;
    }
    return stable.reduce((latest, current) => {
        if (!latest) {
            return current;
        }
        return semver.gt(current, latest) ? current : latest;
    }, stable[0]);
}
/** Filter prerelease versions by allowed tags. */
function filterByTags(versions, tags) {
    if (tags.length === 0) {
        return versions;
    }
    const lowerTags = new Set(tags.map(t => t.toLowerCase()));
    return versions.filter(v => {
        const tag = getPrereleaseTag(v);
        return tag !== null && lowerTags.has(tag);
    });
}
/**
 * Check if a prerelease is newer than the latest stable.
 * Returns true only if the prerelease version is strictly greater.
 */
function isPrereleaseNewerThanStable(prereleaseVersion, stableVersion) {
    return semver.gt(prereleaseVersion, stableVersion);
}
/** Get the maturity tier of a prerelease tag. */
function getPrereleaseTier(tag) {
    if (!tag) {
        return 'other';
    }
    const lower = tag.toLowerCase();
    if (lower === 'alpha') {
        return 'alpha';
    }
    if (lower === 'dev') {
        return 'dev';
    }
    if (lower === 'beta') {
        return 'beta';
    }
    if (lower === 'rc' || lower.startsWith('rc')) {
        return 'rc';
    }
    if (lower.includes('nullsafety')) {
        return 'beta';
    }
    return 'other';
}
/** Format a prerelease tag for display. */
function formatPrereleaseTag(tag) {
    if (!tag) {
        return 'prerelease';
    }
    const tier = getPrereleaseTier(tag);
    switch (tier) {
        case 'alpha': return 'Alpha';
        case 'dev': return 'Dev';
        case 'beta': return 'Beta';
        case 'rc': return 'RC';
        default: return tag;
    }
}
function extractPrereleaseInfo(versions) {
    const validVersions = versions.filter(v => semver.valid(v));
    const latestStable = findLatestStable(validVersions);
    const latestPrerelease = findLatestPrerelease(validVersions);
    const prereleaseTag = latestPrerelease
        ? getPrereleaseTag(latestPrerelease) : null;
    const hasNewerPrerelease = latestStable && latestPrerelease
        ? isPrereleaseNewerThanStable(latestPrerelease, latestStable)
        : latestPrerelease !== null && latestStable === null;
    return {
        latestStable,
        latestPrerelease: hasNewerPrerelease ? latestPrerelease : null,
        prereleaseTag: hasNewerPrerelease ? prereleaseTag : null,
        hasNewerPrerelease,
    };
}
//# sourceMappingURL=prerelease-classifier.js.map