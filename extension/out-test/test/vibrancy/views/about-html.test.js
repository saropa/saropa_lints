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
const about_html_1 = require("../../../vibrancy/views/about-html");
describe('buildAboutHtml', () => {
    it('should return valid HTML with doctype', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.2.3');
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });
    it('should display the version', () => {
        const html = (0, about_html_1.buildAboutHtml)('0.1.1');
        assert.ok(html.includes('v0.1.1'));
    });
    it('should include marketplace link', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('marketplace.visualstudio.com/items?itemName=saropa.saropa-package-vibrancy'));
    });
    it('should include GitHub link', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('github.com/saropa/saropa-package-vibrancy'));
    });
    it('should include CSP meta tag', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('Content-Security-Policy'));
    });
    it('should include extension name', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('Saropa Package Vibrancy'));
    });
    it('should include About Saropa section', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('About Saropa'));
        assert.ok(html.includes('Built for Resilience'));
    });
    it('should include consumer applications', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('Saropa Contacts'));
        assert.ok(html.includes('kykto.com'));
    });
    it('should include developer ecosystem', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('saropa_lints'));
        assert.ok(html.includes('saropa_dart_utils'));
        assert.ok(html.includes('Log Capture'));
        assert.ok(html.includes('Claude Guard'));
    });
    it('should include connect links', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('github.com/saropa'));
        assert.ok(html.includes('medium.com'));
        assert.ok(html.includes('bsky.app'));
        assert.ok(html.includes('linkedin.com'));
    });
    it('should include company profile', () => {
        const html = (0, about_html_1.buildAboutHtml)('1.0.0');
        assert.ok(html.includes('Saropa Pty Limited'));
        assert.ok(html.includes('2010'));
        assert.ok(html.includes('Victoria, Australia'));
    });
});
//# sourceMappingURL=about-html.test.js.map