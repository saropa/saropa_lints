import * as assert from 'assert';
import * as sinon from 'sinon';
import * as fs from 'fs';
import * as path from 'path';
import {
    parseChangelogHtml,
    fetchPubDevChangelog,
} from '../../../vibrancy/services/pubdev-changelog';

const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');

describe('pubdev-changelog', () => {
    describe('parseChangelogHtml', () => {
        it('should parse pub.dev HTML into markdown entries', () => {
            const html = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8',
            );
            const md = parseChangelogHtml(html);
            assert.ok(md);
            assert.ok(md!.includes('## 2.0.0'));
            assert.ok(md!.includes('## 1.5.0'));
            assert.ok(md!.includes('## 1.0.0'));
        });

        it('should convert list items to markdown bullets', () => {
            const html = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8',
            );
            const md = parseChangelogHtml(html)!;
            assert.ok(md.includes('- Breaking: Removed legacy API'));
        });

        it('should return null for HTML with no version headings', () => {
            assert.strictEqual(parseChangelogHtml('<p>No versions</p>'), null);
        });

        it('should return null for empty HTML', () => {
            assert.strictEqual(parseChangelogHtml(''), null);
        });

        it('should decode HTML entities', () => {
            const html = '<h2>1.0.0</h2><p>Use &amp; enjoy &lt;T&gt;</p>';
            const md = parseChangelogHtml(html)!;
            assert.ok(md.includes('& enjoy <T>'));
        });
    });

    describe('fetchPubDevChangelog', () => {
        let fetchStub: sinon.SinonStub;

        beforeEach(() => {
            fetchStub = sinon.stub(globalThis, 'fetch');
        });

        afterEach(() => {
            fetchStub.restore();
        });

        it('should fetch and parse pub.dev changelog page', async () => {
            const html = fs.readFileSync(
                path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8',
            );
            fetchStub.resolves(new Response(html, { status: 200 }));

            const result = await fetchPubDevChangelog('http');
            assert.ok(result);
            assert.ok(result!.includes('## 2.0.0'));
            assert.ok(
                fetchStub.firstCall.args[0].includes(
                    'pub.dev/packages/http/changelog',
                ),
            );
        });

        it('should return null on 404', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const result = await fetchPubDevChangelog('nonexistent');
            assert.strictEqual(result, null);
        });

        it('should return null for unparseable HTML', async () => {
            fetchStub.resolves(
                new Response('<p>No versions</p>', { status: 200 }),
            );
            const result = await fetchPubDevChangelog('broken');
            assert.strictEqual(result, null);
        });
    });
});
