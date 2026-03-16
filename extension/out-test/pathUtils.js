"use strict";
/**
 * Path helpers shared by Code Lens, Issues tree, and commands.
 * Ensures consistent normalization for comparison with violations.json paths (forward slashes).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizePath = normalizePath;
/** Normalize path to forward slashes for consistent match with violations.json file paths. */
function normalizePath(p) {
    return p.replace(/\\/g, '/');
}
//# sourceMappingURL=pathUtils.js.map