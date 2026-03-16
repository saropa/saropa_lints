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
const comparison_html_1 = require("../../../vibrancy/views/comparison-html");
const comparison_ranker_1 = require("../../../vibrancy/scoring/comparison-ranker");
function makePackage(overrides) {
    return {
        name: 'test-pkg',
        vibrancyScore: 75,
        category: 'vibrant',
        latestVersion: '1.0.0',
        publishedDate: '2026-01-15',
        publisher: null,
        pubPoints: 100,
        stars: 500,
        openIssues: 10,
        archiveSizeBytes: 100_000,
        bloatRating: 3,
        license: 'MIT',
        platforms: ['android', 'ios', 'web'],
        inProject: false,
        ...overrides,
    };
}
function makeRankedComparison(packages, recommendation = 'Test recommendation', winners = []) {
    return {
        packages,
        winners,
        recommendation,
    };
}
describe('buildComparisonHtml', () => {
    it('should return valid HTML with doctype', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'http' }),
            makePackage({ name: 'dio' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });
    it('should include CSP meta tag', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'http' }),
            makePackage({ name: 'dio' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('Content-Security-Policy'));
    });
    it('should show message for empty packages', () => {
        const ranked = makeRankedComparison([]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('No packages selected'));
    });
    it('should display package names as links', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'http' }),
            makePackage({ name: 'dio' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('pub.dev/packages/http'));
        assert.ok(html.includes('pub.dev/packages/dio'));
        assert.ok(html.includes('>http<'));
        assert.ok(html.includes('>dio<'));
    });
    it('should display recommendation', () => {
        const ranked = makeRankedComparison([makePackage({ name: 'http' }), makePackage({ name: 'dio' })], '**http** leads in 3 dimensions.');
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('class="recommendation"'));
        assert.ok(html.includes('http'));
    });
    it('should show vibrancy score row', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'http', vibrancyScore: 92 }),
            makePackage({ name: 'dio', vibrancyScore: 88 }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('Vibrancy Score'));
        assert.ok(html.includes('92/100'));
        assert.ok(html.includes('88/100'));
    });
    it('should show category with emoji', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'good', category: 'vibrant' }),
            makePackage({ name: 'bad', category: 'end-of-life' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('🟢'));
        assert.ok(html.includes('🔴'));
        assert.ok(html.includes('Vibrant'));
        assert.ok(html.includes('End of Life'));
    });
    it('should show publisher with verified badge', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'official', publisher: 'dart.dev' }),
            makePackage({ name: 'community', publisher: null }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('dart.dev'));
        assert.ok(html.includes('✓'));
        assert.ok(html.includes('unverified'));
    });
    it('should show archive size formatted', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'small', archiveSizeBytes: 50_000 }),
            makePackage({ name: 'large', archiveSizeBytes: 5_000_000 }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('Archive Size'));
        assert.ok(html.includes('0.05 MB') || html.includes('<0.01 MB'));
        assert.ok(html.includes('4.8 MB') || html.includes('4.77 MB'));
    });
    it('should show In This Project row', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'used', inProject: true }),
            makePackage({ name: 'candidate', inProject: false }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('In This Project'));
        assert.ok(html.includes('✅ Yes'));
        assert.ok(html.includes('❌ No'));
    });
    it('should show Add to Project button for external packages', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'existing', inProject: true }),
            makePackage({ name: 'candidate', inProject: false, latestVersion: '2.0.0' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('Add to Project'));
        assert.ok(html.includes('data-package="candidate"'));
        assert.ok(html.includes('data-version="2.0.0"'));
    });
    it('should not show Add button for in-project packages', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'existing', inProject: true }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(!html.includes('data-package="existing"'));
    });
    it('should show In Project badge for in-project packages', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'existing', inProject: true }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('class="in-project"'));
        assert.ok(html.includes('In Project'));
    });
    it('should escape HTML in package names', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: '<script>alert(1)</script>' }),
            makePackage({ name: 'normal' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(!html.includes('<script>alert(1)</script>'));
        assert.ok(html.includes('&lt;script&gt;'));
    });
    it('should handle null vibrancy score', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'known', vibrancyScore: 80 }),
            makePackage({ name: 'unknown', vibrancyScore: null }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('80/100'));
        assert.ok(html.includes('—') || html.includes('&mdash;'));
    });
    it('should handle null stars', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'has-gh', stars: 1500 }),
            makePackage({ name: 'no-gh', stars: null }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('1,500'));
    });
    it('should show platforms', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'mobile', platforms: ['android', 'ios'] }),
            makePackage({ name: 'all', platforms: [] }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('android'));
        assert.ok(html.includes('ios'));
        assert.ok(html.includes('All'));
    });
    it('should handle 3 packages', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'http' }),
            makePackage({ name: 'dio' }),
            makePackage({ name: 'chopper' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('>http<'));
        assert.ok(html.includes('>dio<'));
        assert.ok(html.includes('>chopper<'));
    });
    it('should apply winner class to best value', () => {
        const packages = [
            makePackage({ name: 'better', vibrancyScore: 95 }),
            makePackage({ name: 'worse', vibrancyScore: 60 }),
        ];
        const ranked = (0, comparison_ranker_1.rankPackages)(packages);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('class="winner'));
    });
    it('should show bloat rating', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'light', bloatRating: 2 }),
            makePackage({ name: 'heavy', bloatRating: 8 }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('Bloat Rating'));
        assert.ok(html.includes('2/10'));
        assert.ok(html.includes('8/10'));
    });
    it('should show license', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'mit', license: 'MIT' }),
            makePackage({ name: 'bsd', license: 'BSD-3-Clause' }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('License'));
        assert.ok(html.includes('MIT'));
        assert.ok(html.includes('BSD-3-Clause'));
    });
    it('should include script for Add to Project functionality', () => {
        const ranked = makeRankedComparison([
            makePackage({ name: 'http', inProject: false }),
            makePackage({ name: 'dio', inProject: false }),
        ]);
        const html = (0, comparison_html_1.buildComparisonHtml)(ranked);
        assert.ok(html.includes('acquireVsCodeApi'));
        assert.ok(html.includes('postMessage'));
        assert.ok(html.includes('addPackage'));
    });
});
//# sourceMappingURL=comparison-html.test.js.map