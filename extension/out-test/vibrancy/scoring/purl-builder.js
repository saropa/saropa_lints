"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildPurl = buildPurl;
/** Build a Package URL (PURL) for a pub.dev package. */
function buildPurl(name, version) {
    return `pkg:pub/${encodeURIComponent(name)}@${encodeURIComponent(version)}`;
}
//# sourceMappingURL=purl-builder.js.map