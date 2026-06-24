/**
 * Tests **opportunities-html**: the dedicated Upgrade Opportunities dashboard
 * renderer. Verifies it lists only packages with unadopted features, ranks them
 * by relevance score, renders the empty state when none, and surfaces the
 * features, code locations, and the Copy-for-AI button.
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

    it('renders the Copy-for-AI button only when a prompt exists', () => {
        // The stylesheet always contains the `.opp-copy` rule; the BUTTON is
        // identified by its unique data-prompt attribute, so assert on that.
        const withPrompt = buildOpportunitiesHtml(
            [card({ unadoptedApiNames: ['A'], opportunityScore: 10 }, 'THE PROMPT')], '1.0.0',
        );
        assert.ok(withPrompt.includes('data-prompt='));
        const withoutPrompt = buildOpportunitiesHtml(
            [card({ unadoptedApiNames: ['A'], opportunityScore: 10 }, null)], '1.0.0',
        );
        assert.ok(!withoutPrompt.includes('data-prompt='));
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
