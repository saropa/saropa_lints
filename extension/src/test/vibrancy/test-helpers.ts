/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import { VibrancyResult, VibrancyCategory, DependencySection } from '../../vibrancy/types';

/** Shared minimal VibrancyResult builders for vibrancy unit tests. */

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
        codeSizeBytes: null,
        folderBreakdown: null,
        maintainerQuality: null,
        maintainerQualityBonus: 0,
        bloatRating: null,
        license: null,
        isUnused: false,
        fileUsages: [],
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
        versionGap: null,
        overrideGap: null,
        replacementComplexity: null,
        likes: null,
        downloadCount30Days: null,
        reverseDependencyCount: null,
        readme: null,
    };
}
