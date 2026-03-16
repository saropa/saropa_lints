import * as assert from 'assert';
import { buildAboutHtml } from '../../../vibrancy/views/about-html';

describe('buildAboutHtml', () => {
    it('should return valid HTML with doctype', () => {
        const html = buildAboutHtml('1.2.3');
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });

    it('should display the version', () => {
        const html = buildAboutHtml('0.1.1');
        assert.ok(html.includes('v0.1.1'));
    });

    it('should include marketplace link', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes(
            'marketplace.visualstudio.com/items?itemName=saropa.saropa-package-vibrancy',
        ));
    });

    it('should include GitHub link', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes(
            'github.com/saropa/saropa-package-vibrancy',
        ));
    });

    it('should include CSP meta tag', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('Content-Security-Policy'));
    });

    it('should include extension name', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('Saropa Package Vibrancy'));
    });

    it('should include About Saropa section', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('About Saropa'));
        assert.ok(html.includes('Built for Resilience'));
    });

    it('should include consumer applications', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('Saropa Contacts'));
        assert.ok(html.includes('kykto.com'));
    });

    it('should include developer ecosystem', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('saropa_lints'));
        assert.ok(html.includes('saropa_dart_utils'));
        assert.ok(html.includes('Log Capture'));
        assert.ok(html.includes('Claude Guard'));
    });

    it('should include connect links', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('github.com/saropa'));
        assert.ok(html.includes('medium.com'));
        assert.ok(html.includes('bsky.app'));
        assert.ok(html.includes('linkedin.com'));
    });

    it('should include company profile', () => {
        const html = buildAboutHtml('1.0.0');
        assert.ok(html.includes('Saropa Pty Limited'));
        assert.ok(html.includes('2010'));
        assert.ok(html.includes('Victoria, Australia'));
    });
});
