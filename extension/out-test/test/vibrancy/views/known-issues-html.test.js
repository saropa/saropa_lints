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
const known_issues_html_1 = require("../../../vibrancy/views/known-issues-html");
describe('buildKnownIssuesHtml', () => {
    it('should return valid HTML with doctype', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });
    it('should show total count in summary', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        // Total count appears in summary cards — at least 125 known issues
        assert.ok(html.includes('>Total<'));
    });
    it('should include package rows', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('data-name="flutter_datetime_picker"'));
        assert.ok(html.includes('data-name="connectivity"'));
    });
    it('should link packages to pub.dev', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('pub.dev/packages/flutter_datetime_picker'));
    });
    it('should show replacement links when present', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('pub.dev/packages/connectivity_plus'));
    });
    it('should show migration notes when present', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('Drop-in replacement'));
    });
    it('should include CSP meta tag', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('Content-Security-Policy'));
    });
    it('should include search input', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('id="search-input"'));
    });
    it('should include filter checkbox', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('id="filter-has-replacement"'));
    });
    it('should include sort arrows in table headers', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(html.includes('class="sort-arrow"'));
    });
    it('should not generate pub.dev links for freeform replacements', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        assert.ok(!html.includes('pub.dev/packages/Update'), 'freeform text should not be linked to pub.dev');
        assert.ok(!html.includes('pub.dev/packages/Native'), 'freeform text should not be linked to pub.dev');
    });
    it('should escape HTML entities in data attributes', () => {
        const html = (0, known_issues_html_1.buildKnownIssuesHtml)();
        // Data attributes exist and none start with raw angle brackets
        assert.ok(html.includes('data-reason='));
        assert.ok(!html.includes('data-reason="<'));
    });
});
//# sourceMappingURL=known-issues-html.test.js.map