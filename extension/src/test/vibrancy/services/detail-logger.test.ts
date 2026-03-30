import * as assert from 'assert';
import * as sinon from 'sinon';
import { DetailLogger, DETAIL_CHANNEL_NAME } from '../../../vibrancy/services/detail-logger';
import { VibrancyResult } from '../../../vibrancy/types';

function makeResult(
    name: string,
    score: number,
    category: VibrancyResult['category'] = 'vibrant',
): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: {
            name,
            latestVersion: '1.0.0',
            publishedDate: '2025-06-01T00:00:00Z',
            repositoryUrl: 'https://github.com/example/pkg',
            isDiscontinued: false,
            isUnlisted: false,
            pubPoints: 140,
            publisher: 'verified.dev',
            license: null,
            description: null,
            topics: [],
        },
        github: {
            stars: 1234,
            openIssues: 45,
            closedIssuesLast90d: 10,
            mergedPrsLast90d: 5,
            avgCommentsPerIssue: 2.5,
            daysSinceLastUpdate: 3,
            daysSinceLastClose: 7,
            flaggedIssues: [],
            license: null,
        },
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 30,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: 512000,
        bloatRating: null,
        license: 'MIT',
        isUnused: false,
        platforms: ['android', 'ios', 'web'],
        verifiedPublisher: true,
        wasmReady: true,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    };
}

function createMockChannel(): { appendLine: sinon.SinonStub; show: sinon.SinonStub; clear: sinon.SinonStub } {
    return {
        appendLine: sinon.stub(),
        show: sinon.stub(),
        clear: sinon.stub(),
    };
}

describe('DetailLogger', () => {
    it('should export correct channel name', () => {
        assert.strictEqual(DETAIL_CHANNEL_NAME, 'Vibrancy Details');
    });

    describe('logPackage', () => {
        it('should log package name and score', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('http'));
            assert.ok(output.includes('8/10'));
            assert.ok(output.includes('Vibrant'));
        });

        it('should log version info', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('Version: ^1.0.0'));
        });

        it('should log published date', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('Published: 2025-06-01'));
        });

        it('should log license', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('License: MIT'));
        });

        it('should log size', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('Size:'));
            assert.ok(output.includes('MB'));
        });

        it('should log community info', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('📊 Community'));
            assert.ok(output.includes('Stars: 1234'));
            assert.ok(output.includes('Open issues: 45'));
        });

        it('should log platforms', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('Platforms: android, ios, web'));
        });

        it('should include timestamp', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result = makeResult('http', 80);

            logger.logPackage(result);

            const firstLine = channel.appendLine.firstCall.args[0];
            assert.ok(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/.test(firstLine));
        });

        it('should log update info when available', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    updateStatus: 'major',
                    changelog: null,
                },
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('→ 2.0.0 available (major)'));
        });

        it('should log blocker info when blocked', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                blocker: {
                    blockedPackage: 'http',
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    blockerPackage: 'dio',
                    blockerVibrancyScore: 60,
                    blockerCategory: 'quiet',
                },
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    updateStatus: 'major',
                    changelog: null,
                },
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('⚠️ Upgrade Blocked'));
            assert.ok(output.includes('Blocked by dio'));
        });

        it('should log suggestion for unused packages', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                isUnused: true,
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('💡 Suggestion'));
            assert.ok(output.includes('appears to be unused'));
        });

        it('should log suggestion with replacement', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                knownIssue: {
                    name: 'http',
                    status: 'deprecated',
                    replacement: 'dio',
                },
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('💡 Suggestion'));
            assert.ok(output.includes('migrating to dio'));
        });

        it('should log alternatives', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                alternatives: [
                    { name: 'dio', source: 'curated', score: 90, likes: 1000 },
                    { name: 'chopper', source: 'discovery', score: 80, likes: 500 },
                ],
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('Alternatives: dio, chopper'));
        });

        it('should log alerts for known issues', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                knownIssue: {
                    name: 'http',
                    status: 'security',
                    reason: 'Critical vulnerability found',
                },
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('🚨 Alerts'));
            assert.ok(output.includes('security'));
            assert.ok(output.includes('Critical vulnerability'));
        });

        it('should log flagged issues', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                github: {
                    stars: 1000,
                    openIssues: 10,
                    closedIssuesLast90d: 5,
                    mergedPrsLast90d: 3,
                    avgCommentsPerIssue: 2,
                    daysSinceLastUpdate: 5,
                    daysSinceLastClose: 10,
                    flaggedIssues: [
                        {
                            number: 123,
                            title: 'Breaking change in v2',
                            url: 'https://github.com/example/issues/123',
                            matchedSignals: ['breaking'],
                            commentCount: 15,
                        },
                    ],
                    license: null,
                },
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('🚨 Alerts'));
            assert.ok(output.includes('#123'));
            assert.ok(output.includes('Breaking change'));
        });
    });

    describe('logAllPackages', () => {
        it('should log header with package count', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const results = [
                makeResult('http', 80),
                makeResult('bloc', 60, 'quiet'),
            ];

            logger.logAllPackages(results);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('SCAN RESULTS'));
            assert.ok(output.includes('2 packages'));
        });

        it('should log all packages', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const results = [
                makeResult('http', 80),
                makeResult('bloc', 60, 'quiet'),
            ];

            logger.logAllPackages(results);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('http'));
            assert.ok(output.includes('bloc'));
        });

        it('should not log anything for empty results', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);

            logger.logAllPackages([]);

            assert.strictEqual(channel.appendLine.callCount, 0);
        });
    });

    describe('show', () => {
        it('should call show on channel', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);

            logger.show();

            assert.ok(channel.show.calledOnce);
            assert.ok(channel.show.calledWith(true));
        });
    });

    describe('clear', () => {
        it('should call clear on channel', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);

            logger.clear();

            assert.ok(channel.clear.calledOnce);
        });
    });

    describe('text wrapping', () => {
        it('should wrap long suggestion text', () => {
            const channel = createMockChannel();
            const logger = new DetailLogger(channel as unknown as import('vscode').OutputChannel);
            const result: VibrancyResult = {
                ...makeResult('http', 80),
                knownIssue: {
                    name: 'http',
                    status: 'deprecated',
                    migrationNotes: 'This is a very long migration note that should be wrapped across multiple lines when logged to the output channel because it exceeds the maximum width.',
                },
            };

            logger.logPackage(result);

            const output = channel.appendLine.getCalls().map(c => c.args[0]).join('\n');
            assert.ok(output.includes('💡 Suggestion'));
            assert.ok(output.includes('migration note'));
        });
    });
});
