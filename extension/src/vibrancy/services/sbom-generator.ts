import * as crypto from 'crypto';
import { VibrancyResult } from '../types';
import { buildPurl } from '../scoring/purl-builder';

export interface SbomMetadata {
    readonly projectName: string;
    readonly projectVersion: string;
    readonly extensionVersion: string;
}

export interface CycloneDxBom {
    readonly bomFormat: 'CycloneDX';
    readonly specVersion: '1.5';
    readonly serialNumber: string;
    readonly version: 1;
    readonly metadata: {
        readonly timestamp: string;
        readonly component: {
            readonly type: 'application';
            readonly name: string;
            readonly version: string;
        };
        readonly tools: readonly {
            readonly vendor: string;
            readonly name: string;
            readonly version: string;
        }[];
    };
    readonly components: readonly CycloneDxComponent[];
}

interface CycloneDxComponent {
    readonly type: 'library';
    readonly name: string;
    readonly version: string;
    readonly purl: string;
    readonly licenses: readonly { license: { id: string } }[];
    readonly publisher: string;
    readonly properties: readonly { name: string; value: string }[];
}

/** Build a CycloneDX 1.5 SBOM from scan results. */
export function generateSbom(
    results: readonly VibrancyResult[],
    meta: SbomMetadata,
): CycloneDxBom {
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

function buildComponent(result: VibrancyResult): CycloneDxComponent {
    const licenses = result.license
        ? [{ license: { id: result.license } }] : [];
    return {
        type: 'library',
        name: result.package.name,
        version: result.package.version,
        purl: buildPurl(result.package.name, result.package.version),
        licenses,
        publisher: result.pubDev?.publisher ?? '',
        properties: [
            { name: 'vibrancy:score', value: String(result.score) },
            { name: 'vibrancy:category', value: result.category },
        ],
    };
}

/** Serialize a CycloneDX BOM to formatted JSON. */
export function serializeSbom(bom: CycloneDxBom): string {
    return JSON.stringify(bom, null, 2) + '\n';
}
