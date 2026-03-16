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
const detail_view_html_1 = require("../../../vibrancy/views/detail-view-html");
function makeResult(name, score, category = 'vibrant') {
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
        archiveSizeBytes: null,
        bloatRating: null,
        license: 'MIT',
        drift: null,
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
describe('buildDetailViewHtml', () => {
    it('should return placeholder HTML when result is null', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(null);
        assert.ok(html.includes('<!DOCTYPE html>'));
        assert.ok(html.includes('Select a package to see details'));
        assert.ok(html.includes('class="placeholder"'));
    });
    it('should return valid HTML with doctype', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });
    it('should include CSP meta tag', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('Content-Security-Policy'));
    });
    it('should show package name and score', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('<h1>http</h1>'));
        assert.ok(html.includes('>8/10<'));
    });
    it('should show category badge', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80, 'vibrant'));
        assert.ok(html.includes('class="category-badge vibrant"'));
        assert.ok(html.includes('Vibrant'));
    });
    it('should show version section', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('📦 VERSION'));
        assert.ok(html.includes('^1.0.0'));
    });
    it('should show published date', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('Published: 2025-06-01'));
    });
    it('should show license with checkmark for permissive', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('MIT ✅'));
    });
    it('should show community section', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('📊 COMMUNITY'));
        assert.ok(html.includes('⭐ 1.2k'));
        assert.ok(html.includes('📋 45 issues'));
    });
    it('should show pub points', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('140/160 pub points'));
    });
    it('should show verified publisher', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('✅ verified.dev'));
    });
    it('should show platforms section', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('📱 PLATFORMS'));
        assert.ok(html.includes('android, ios, web'));
        assert.ok(html.includes('🌐 WASM'));
    });
    it('should show links section', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('View on pub.dev'));
        assert.ok(html.includes('pub.dev/packages/http'));
        assert.ok(html.includes('Repository'));
    });
    it('should escape HTML in package names', () => {
        const result = makeResult('<script>xss</script>', 80);
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(!html.includes('<script>xss</script>'));
        assert.ok(html.includes('&lt;script&gt;'));
    });
    it('should show update section when update available', () => {
        const result = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: null,
            },
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('⬆️ UPDATE'));
        assert.ok(html.includes('(major)'));
        assert.ok(html.includes('Upgrade'));
    });
    it('should not show update section when up-to-date', () => {
        const result = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '1.0.0',
                updateStatus: 'up-to-date',
                changelog: null,
            },
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(!html.includes('⬆️ UPDATE'));
    });
    it('should show blocker info when upgrade blocked', () => {
        const result = {
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
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('Blocked by dio'));
    });
    it('should show suggestion section for unused packages', () => {
        const result = {
            ...makeResult('http', 80),
            isUnused: true,
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('💡 SUGGESTION'));
        assert.ok(html.includes('appears to be unused'));
    });
    it('should show suggestion section with replacement', () => {
        const result = {
            ...makeResult('http', 80),
            knownIssue: {
                name: 'http',
                status: 'deprecated',
                replacement: 'dio',
            },
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('💡 SUGGESTION'));
        assert.ok(html.includes('migrating to dio'));
    });
    it('should show alternatives in suggestion', () => {
        const result = {
            ...makeResult('http', 80),
            alternatives: [
                { name: 'dio', source: 'curated', score: 90, likes: 1000 },
                { name: 'chopper', source: 'discovery', score: 80, likes: 500 },
            ],
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('💡 SUGGESTION'));
        assert.ok(html.includes('Alternatives: dio, chopper'));
    });
    it('should show alerts section for known issues', () => {
        const result = {
            ...makeResult('http', 80),
            knownIssue: {
                name: 'http',
                status: 'security',
                reason: 'Critical vulnerability in TLS handling',
            },
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('🚨 ALERTS'));
        assert.ok(html.includes('security'));
        assert.ok(html.includes('Critical vulnerability'));
    });
    it('should show flagged issues in alerts', () => {
        const result = {
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
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('🚨 ALERTS'));
        assert.ok(html.includes('🚩 #123'));
        assert.ok(html.includes('Breaking change'));
    });
    it('should include collapsible section script', () => {
        const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 80));
        assert.ok(html.includes('.section-header'));
        assert.ok(html.includes('data-expanded'));
    });
    it('should include action button handlers', () => {
        const result = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: null,
            },
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(html.includes('data-action="upgrade"'));
        assert.ok(html.includes('vscode.postMessage'));
    });
    it('should handle all category styles', () => {
        for (const cat of ['vibrant', 'quiet', 'legacy-locked', 'stale', 'end-of-life']) {
            const html = (0, detail_view_html_1.buildDetailViewHtml)(makeResult('http', 50, cat));
            assert.ok(html.includes(`class="score ${cat}"`), `Missing score class for ${cat}`);
            assert.ok(html.includes(`class="category-badge ${cat}"`), `Missing badge class for ${cat}`);
        }
    });
    it('should not show empty sections', () => {
        const result = {
            ...makeResult('http', 80),
            github: null,
            pubDev: null,
            alternatives: [],
            knownIssue: null,
            platforms: null,
        };
        const html = (0, detail_view_html_1.buildDetailViewHtml)(result);
        assert.ok(!html.includes('📊 COMMUNITY'));
        assert.ok(!html.includes('💡 SUGGESTION'));
        assert.ok(!html.includes('🚨 ALERTS'));
        assert.ok(!html.includes('📱 PLATFORMS'));
    });
});
//# sourceMappingURL=detail-view-html.test.js.map