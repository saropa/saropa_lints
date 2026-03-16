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
exports.generateSbom = generateSbom;
exports.serializeSbom = serializeSbom;
const crypto = __importStar(require("crypto"));
const purl_builder_1 = require("../scoring/purl-builder");
/** Build a CycloneDX 1.5 SBOM from scan results. */
function generateSbom(results, meta) {
    return {
        bomFormat: 'CycloneDX',
        specVersion: '1.5',
        serialNumber: `urn:uuid:${crypto.randomUUID()}`,
        version: 1,
        metadata: {
            timestamp: new Date().toISOString(),
            component: {
                type: 'application',
                name: meta.projectName,
                version: meta.projectVersion,
            },
            tools: [{
                    vendor: 'Saropa',
                    name: 'Package Vibrancy',
                    version: meta.extensionVersion,
                }],
        },
        components: results.map(buildComponent),
    };
}
function buildComponent(result) {
    const licenses = result.license
        ? [{ license: { id: result.license } }] : [];
    return {
        type: 'library',
        name: result.package.name,
        version: result.package.version,
        purl: (0, purl_builder_1.buildPurl)(result.package.name, result.package.version),
        licenses,
        publisher: result.pubDev?.publisher ?? '',
        properties: [
            { name: 'vibrancy:score', value: String(result.score) },
            { name: 'vibrancy:category', value: result.category },
        ],
    };
}
/** Serialize a CycloneDX BOM to formatted JSON. */
function serializeSbom(bom) {
    return JSON.stringify(bom, null, 2) + '\n';
}
//# sourceMappingURL=sbom-generator.js.map