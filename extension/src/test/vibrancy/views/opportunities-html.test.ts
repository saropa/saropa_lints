/**
 * Tests **opportunities-html**: the dedicated Upgrade Opportunities dashboard
 * renderer. Verifies it lists only packages with unadopted features, ranks them
 * by relevance score, renders the empty state when none, and surfaces the
 * features, code locations, and the Write Report button.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import {
    buildOpportunitiesHtml,
    OpportunityCardData,
} from '../../../vibrancy/views/opportunities-html';
import { VibrancyResult } from '../../../vibrancy/types';

// Minimal VibrancyResult stub — only the fields the renderer reads.
function result(over: Partial<VibrancyResult>): VibrancyResult {
    return {
        package: { name: 'pkg', version: '1.0.0' },
        pubDev: { description: 'A package' },
        fileUsages: [],
        ...over,
    } as unknown as VibrancyResult;
}

function card(over: Partial<VibrancyResult>, aiPrompt: string | null = 'PROMPT'): OpportunityCardData {
    return { result: result(over), aiPrompt };
}

describe('opportunities-html', () => {
    it('renders the empty state when no package has unadopted features', () => {
        const html = buildOpportunitiesHtml(
            [card({ unadoptedApiNames: [], opportunityScore: 0 })], '1.0.0',
        );
        assert.ok(html.includes('Nothing to adopt'));
    });

    it('lists a package that has unadopted features', () => {
        const html = buildOpportunitiesHtml([card({
            package: { name: 'reel_text', version: '0.4.0' } as never,
            unadoptedApiNames: ['ReelText.rich'],
            opportunityScore: 20,
        })], '1.0.0');
        assert.ok(html.includes('reel_text'));
        assert.ok(html.includes('ReelText.rich'));
        assert.ok(!html.includes('Nothing to adopt'));
    });

    it('orders packages by descending opportunity score', () => {
        const html = buildOpportunitiesHtml([
            card({ package: { name: 'low_pkg', version: '1.0.0' } as never, unadoptedApiNames: ['A'], opportunityScore: 5 }),
            card({ package: { name: 'high_pkg', version: '1.0.0' } as never, unadoptedApiNames: ['B'], opportunityScore: 80 }),
        ], '1.0.0');
        assert.ok(html.indexOf('high_pkg') < html.indexOf('low_pkg'), 'higher score should render first');
    });

    it('renders Write Report buttons when cards exist, omits them in empty state', () => {
        // Global header button + per-card button when a prompt exists.
        const withCards = buildOpportunitiesHtml(
            [card({ unadoptedApiNames: ['A'], opportunityScore: 10 }, 'THE PROMPT')], '1.0.0',
        );
        assert.ok(withCards.includes('id="writeReportBtn"'), 'global write-report button');
        assert.ok(withCards.includes('opp-write-card'), 'per-card write-report button');

        // Per-card button absent when aiPrompt is null. Use the button tag
        // selector to avoid false matches on the class name in the <script>.
        const noPrompt = buildOpportunitiesHtml(
            [card({ unadoptedApiNames: ['A'], opportunityScore: 10 }, null)], '1.0.0',
        );
        assert.ok(noPrompt.includes('id="writeReportBtn"'), 'global button still shows');
        assert.ok(!noPrompt.includes('<button class="opp-btn opp-write-card"'), 'no per-card button without prompt');

        // Empty state has neither button.
        const empty = buildOpportunitiesHtml(
            [card({ unadoptedApiNames: [], opportunityScore: 0 })], '1.0.0',
        );
        assert.ok(!empty.includes('id="writeReportBtn"'));
        assert.ok(!empty.includes('<button class="opp-btn opp-write-card"'));
    });

    it('shows code locations as openable links', () => {
        const html = buildOpportunitiesHtml([card({
            unadoptedApiNames: ['A'],
            opportunityScore: 10,
            fileUsages: [{ filePath: 'lib/main.dart', isCommented: false, line: 12, importLine: 12, exportLine: null, isExport: false }],
        } as never)], '1.0.0');
        assert.ok(html.includes('lib/main.dart:12'));
        assert.ok(html.includes('data-file="lib/main.dart"'));
    });
});
