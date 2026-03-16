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
const assert = __importStar(require("assert"));
const sbom_generator_1 = require("../../../vibrancy/services/sbom-generator");
function makeResult(name, overrides = {}) {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score: 85,
        category: 'vibrant',
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 60,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
        ...overrides,
    };
}
const META = {
    projectName: 'my_app',
    projectVersion: '1.0.0',
    extensionVersion: '0.1.2',
};
describe('sbom-generator', () => {
    describe('generateSbom', () => {
        it('should set bomFormat to CycloneDX', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.strictEqual(bom.bomFormat, 'CycloneDX');
        });
        it('should set specVersion to 1.5', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.strictEqual(bom.specVersion, '1.5');
        });
        it('should generate a urn:uuid serial number', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.ok(bom.serialNumber.startsWith('urn:uuid:'));
            assert.strictEqual(bom.serialNumber.length, 45);
        });
        it('should include project metadata', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.strictEqual(bom.metadata.component.name, 'my_app');
            assert.strictEqual(bom.metadata.component.version, '1.0.0');
            assert.strictEqual(bom.metadata.component.type, 'application');
        });
        it('should include tool metadata', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.strictEqual(bom.metadata.tools[0].vendor, 'Saropa');
            assert.strictEqual(bom.metadata.tools[0].name, 'Package Vibrancy');
            assert.strictEqual(bom.metadata.tools[0].version, '0.1.2');
        });
        it('should include ISO timestamp', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.ok(bom.metadata.timestamp.includes('T'));
        });
        it('should return empty components for no results', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            assert.strictEqual(bom.components.length, 0);
        });
        it('should map results to components', () => {
            const results = [makeResult('http'), makeResult('path')];
            const bom = (0, sbom_generator_1.generateSbom)(results, META);
            assert.strictEqual(bom.components.length, 2);
            assert.strictEqual(bom.components[0].name, 'http');
            assert.strictEqual(bom.components[1].name, 'path');
        });
        it('should set PURL for each component', () => {
            const bom = (0, sbom_generator_1.generateSbom)([makeResult('http')], META);
            assert.strictEqual(bom.components[0].purl, 'pkg:pub/http@1.0.0');
        });
        it('should include license when present', () => {
            const results = [makeResult('http', { license: 'BSD-3-Clause' })];
            const bom = (0, sbom_generator_1.generateSbom)(results, META);
            assert.strictEqual(bom.components[0].licenses.length, 1);
            assert.strictEqual(bom.components[0].licenses[0].license.id, 'BSD-3-Clause');
        });
        it('should set empty licenses when none available', () => {
            const bom = (0, sbom_generator_1.generateSbom)([makeResult('http')], META);
            assert.strictEqual(bom.components[0].licenses.length, 0);
        });
        it('should include vibrancy score property', () => {
            const results = [makeResult('http', { score: 92 })];
            const bom = (0, sbom_generator_1.generateSbom)(results, META);
            const props = bom.components[0].properties;
            const scoreProp = props.find(p => p.name === 'vibrancy:score');
            assert.strictEqual(scoreProp?.value, '92');
        });
        it('should include vibrancy category property', () => {
            const results = [makeResult('http', { category: 'quiet' })];
            const bom = (0, sbom_generator_1.generateSbom)(results, META);
            const props = bom.components[0].properties;
            const catProp = props.find(p => p.name === 'vibrancy:category');
            assert.strictEqual(catProp?.value, 'quiet');
        });
        it('should include publisher when available', () => {
            const results = [makeResult('http', {
                    pubDev: {
                        name: 'http', latestVersion: '1.2.0',
                        publishedDate: '2024-01-01', repositoryUrl: null,
                        isDiscontinued: false, isUnlisted: false,
                        pubPoints: 130, publisher: 'dart.dev',
                        license: 'BSD-3-Clause',
                        description: null,
                        topics: [],
                    },
                })];
            const bom = (0, sbom_generator_1.generateSbom)(results, META);
            assert.strictEqual(bom.components[0].publisher, 'dart.dev');
        });
    });
    describe('serializeSbom', () => {
        it('should produce valid JSON', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            const json = (0, sbom_generator_1.serializeSbom)(bom);
            const parsed = JSON.parse(json);
            assert.strictEqual(parsed.bomFormat, 'CycloneDX');
        });
        it('should end with newline', () => {
            const bom = (0, sbom_generator_1.generateSbom)([], META);
            const json = (0, sbom_generator_1.serializeSbom)(bom);
            assert.ok(json.endsWith('\n'));
        });
    });
});
//# sourceMappingURL=sbom-generator.test.js.map