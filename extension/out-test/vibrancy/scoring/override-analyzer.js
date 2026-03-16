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
exports.formatAge = void 0;
exports.analyzeOverrides = analyzeOverrides;
exports.isOldOverride = isOldOverride;
exports.groupByStatus = groupByStatus;
const override_age_1 = require("../services/override-age");
Object.defineProperty(exports, "formatAge", { enumerable: true, get: function () { return override_age_1.formatAge; } });
const semver = __importStar(require("semver"));
/**
 * Analyze each override to determine if it's active (resolving a real conflict)
 * or stale (no longer needed).
 *
 * Pure function — no I/O.
 */
function analyzeOverrides(overrides, deps, depGraph, ages) {
    const depMap = new Map(deps.map(d => [d.name, d]));
    const graphMap = new Map(depGraph.map(p => [p.name, p]));
    return overrides.map(entry => {
        const addedDate = ages.get(entry.name) ?? null;
        const ageDays = (0, override_age_1.calculateAgeDays)(addedDate);
        if (entry.isPathDep || entry.isGitDep) {
            return {
                entry,
                status: 'active',
                blocker: entry.isPathDep ? 'local path override' : 'git override',
                addedDate,
                ageDays,
            };
        }
        const conflict = findConflict(entry, depMap, graphMap);
        return {
            entry,
            status: conflict ? 'active' : 'stale',
            blocker: conflict,
            addedDate,
            ageDays,
        };
    });
}
/**
 * Find which package (if any) constrains the overridden package to a conflicting range.
 * Returns the name of the blocking package or null if no conflict exists.
 */
function findConflict(override, deps, depGraph) {
    const overriddenVersion = cleanVersion(override.version);
    if (!overriddenVersion) {
        return null;
    }
    const parsed = semver.coerce(overriddenVersion);
    if (!parsed) {
        return null;
    }
    for (const [, pkg] of depGraph) {
        if (pkg.name === override.name) {
            continue;
        }
        if (!pkg.dependencies.includes(override.name)) {
            continue;
        }
        const dep = deps.get(pkg.name);
        if (!dep) {
            continue;
        }
        const constraint = findTransitiveConstraint(pkg.name, override.name, depGraph);
        if (constraint && !satisfiesConstraint(parsed.version, constraint)) {
            return pkg.name;
        }
    }
    const directDep = deps.get(override.name);
    if (directDep && directDep.isDirect) {
        const constraint = directDep.constraint;
        if (constraint && !satisfiesConstraint(parsed.version, constraint)) {
            return 'direct constraint';
        }
    }
    return null;
}
/**
 * Find the version constraint a package applies to a dependency.
 * This is a heuristic since we don't have full constraint info in the dep graph.
 */
function findTransitiveConstraint(_parentName, _depName, _depGraph) {
    return null;
}
/**
 * Check if a version satisfies a constraint.
 * Handles common constraint formats: ^1.0.0, >=1.0.0, <2.0.0, etc.
 */
function satisfiesConstraint(version, constraint) {
    try {
        const cleaned = constraint.replace(/["']/g, '').trim();
        if (cleaned === 'any') {
            return true;
        }
        const range = semver.validRange(cleaned);
        if (!range) {
            return true;
        }
        return semver.satisfies(version, range);
    }
    catch {
        return true;
    }
}
/**
 * Clean a version string by removing quotes and whitespace.
 */
function cleanVersion(version) {
    return version.replace(/["']/g, '').trim();
}
/**
 * Check if an override is considered "old" (over a certain threshold).
 * Default threshold is 180 days (6 months).
 */
function isOldOverride(analysis, thresholdDays = 180) {
    return analysis.ageDays !== null && analysis.ageDays > thresholdDays;
}
/**
 * Group analyses by status for easier UI rendering.
 */
function groupByStatus(analyses) {
    const active = [];
    const stale = [];
    for (const a of analyses) {
        if (a.status === 'active') {
            active.push(a);
        }
        else {
            stale.push(a);
        }
    }
    return { active, stale };
}
//# sourceMappingURL=override-analyzer.js.map