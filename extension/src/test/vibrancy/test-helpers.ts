import { VibrancyResult, VibrancyCategory, DependencySection } from '../../vibrancy/types';

export interface MakeResultOptions {
    readonly name?: string;
    readonly version?: string;
    readonly score?: number;
    readonly category?: VibrancyCategory;
    readonly section?: DependencySection;
}

export function makeMinimalResult(options: MakeResultOptions = {}): VibrancyResult {
    const {
        name = 'test_pkg',
        version = '1.0.0',
        score = 75,
        category = 'vibrant',
        section = 'dependencies',
    } = options;

    return {
        package: {
            name,
            version,
            constraint: `^${version}`,
            source: 'hosted',
            isDirect: true,
            section,
        },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 60,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false,
        platforms: null,
        verifiedPublisher: false,
        wasmReady: null,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    };
}
