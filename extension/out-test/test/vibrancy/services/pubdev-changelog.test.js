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
const sinon = __importStar(require("sinon"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const pubdev_changelog_1 = require("../../../vibrancy/services/pubdev-changelog");
const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');
describe('pubdev-changelog', () => {
    describe('parseChangelogHtml', () => {
        it('should parse pub.dev HTML into markdown entries', () => {
            const html = fs.readFileSync(path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8');
            const md = (0, pubdev_changelog_1.parseChangelogHtml)(html);
            assert.ok(md);
            assert.ok(md.includes('## 2.0.0'));
            assert.ok(md.includes('## 1.5.0'));
            assert.ok(md.includes('## 1.0.0'));
        });
        it('should convert list items to markdown bullets', () => {
            const html = fs.readFileSync(path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8');
            const md = (0, pubdev_changelog_1.parseChangelogHtml)(html);
            assert.ok(md.includes('- Breaking: Removed legacy API'));
        });
        it('should return null for HTML with no version headings', () => {
            assert.strictEqual((0, pubdev_changelog_1.parseChangelogHtml)('<p>No versions</p>'), null);
        });
        it('should return null for empty HTML', () => {
            assert.strictEqual((0, pubdev_changelog_1.parseChangelogHtml)(''), null);
        });
        it('should decode HTML entities', () => {
            const html = '<h2>1.0.0</h2><p>Use &amp; enjoy &lt;T&gt;</p>';
            const md = (0, pubdev_changelog_1.parseChangelogHtml)(html);
            assert.ok(md.includes('& enjoy <T>'));
        });
    });
    describe('fetchPubDevChangelog', () => {
        let fetchStub;
        beforeEach(() => {
            fetchStub = sinon.stub(globalThis, 'fetch');
        });
        afterEach(() => {
            fetchStub.restore();
        });
        it('should fetch and parse pub.dev changelog page', async () => {
            const html = fs.readFileSync(path.join(fixturesDir, 'pub-dev-changelog.html'), 'utf8');
            fetchStub.resolves(new Response(html, { status: 200 }));
            const result = await (0, pubdev_changelog_1.fetchPubDevChangelog)('http');
            assert.ok(result);
            assert.ok(result.includes('## 2.0.0'));
            assert.ok(fetchStub.firstCall.args[0].includes('pub.dev/packages/http/changelog'));
        });
        it('should return null on 404', async () => {
            fetchStub.resolves(new Response('', { status: 404 }));
            const result = await (0, pubdev_changelog_1.fetchPubDevChangelog)('nonexistent');
            assert.strictEqual(result, null);
        });
        it('should return null for unparseable HTML', async () => {
            fetchStub.resolves(new Response('<p>No versions</p>', { status: 200 }));
            const result = await (0, pubdev_changelog_1.fetchPubDevChangelog)('broken');
            assert.strictEqual(result, null);
        });
    });
});
//# sourceMappingURL=pubdev-changelog.test.js.map