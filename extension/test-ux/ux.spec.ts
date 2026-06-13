import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

/**
 * Renders every generated dashboard page (page x theme) at a narrow and a wide
 * webview width, runs axe-core, measures horizontal overflow, and captures a
 * full-page screenshot. Results are written to .results/ and .screens/ for
 * inspection; assertions are soft so one bad page does not hide the rest.
 */

const PAGES_DIR = path.join(__dirname, '.pages');
const SCREENS_DIR = path.join(__dirname, '.screens');
const RESULTS_DIR = path.join(__dirname, '.results');

const WIDTHS = [
  { label: 'narrow', width: 380, height: 900 },
  { label: 'wide', width: 1600, height: 1000 },
];

// axe rule tags: WCAG A/AA plus best-practice. Contrast lives in wcag2aa.
const AXE_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'best-practice'];

interface ManifestEntry { name: string; theme: string; file: string; }

const manifest: ManifestEntry[] = JSON.parse(
  fs.readFileSync(path.join(PAGES_DIR, 'manifest.json'), 'utf8'),
);

fs.mkdirSync(SCREENS_DIR, { recursive: true });
fs.mkdirSync(RESULTS_DIR, { recursive: true });

const axeSource = fs.readFileSync(require.resolve('axe-core'), 'utf8');

for (const entry of manifest) {
  for (const vp of WIDTHS) {
    test(`${entry.name} · ${entry.theme} · ${vp.label}`, async ({ page }) => {
      const fileUrl = pathToFileURL(path.join(PAGES_DIR, entry.file)).href;
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await page.goto(fileUrl, { waitUntil: 'load' });
      // Let inline scripts hydrate and any entrance transitions settle.
      await page.waitForTimeout(350);

      // Horizontal overflow: content wider than the viewport = broken layout
      // at this width. A 2px slack absorbs sub-pixel rounding.
      const overflow = await page.evaluate(() => {
        const el = document.documentElement;
        return el.scrollWidth - el.clientWidth;
      });

      // When the page overflows, name the elements whose right edge crosses the
      // viewport so the fix targets the real culprit (usually a non-wrapping
      // table) instead of guessing. Reports the widest offenders, deepest-first.
      const culprits = overflow > 2 ? await page.evaluate(() => {
        const docW = document.documentElement.clientWidth;
        const hits: Array<{ sel: string; right: number; width: number }> = [];
        document.querySelectorAll('*').forEach((node) => {
          const r = node.getBoundingClientRect();
          if (r.width > 0 && r.right > docW + 2) {
            const cls = typeof node.className === 'string' && node.className.trim()
              ? '.' + node.className.trim().split(/\s+/).slice(0, 3).join('.')
              : '';
            hits.push({ sel: node.tagName.toLowerCase() + cls, right: Math.round(r.right), width: Math.round(r.width) });
          }
        });
        return hits.sort((a, b) => b.right - a.right).slice(0, 10);
      }) : [];

      // axe-core contrast + a11y audit.
      await page.evaluate(axeSource);
      const axeResults = await page.evaluate(async (tags) => {
        // @ts-expect-error axe is injected into the page global above.
        return await window.axe.run(document, {
          resultTypes: ['violations'],
          runOnly: { type: 'tag', values: tags },
        });
      }, AXE_TAGS);

      const violations = (axeResults.violations ?? []) as Array<{
        id: string; impact: string | null; help: string;
        nodes: Array<{ target: string[]; failureSummary?: string; any?: Array<{ data?: Record<string, unknown> }> }>;
      }>;

      const summary = {
        page: entry.name, theme: entry.theme, width: vp.label, pxWidth: vp.width,
        overflowPx: overflow,
        overflowCulprits: culprits,
        violations: violations.map((v) => ({
          id: v.id, impact: v.impact, help: v.help,
          count: v.nodes.length,
          targets: v.nodes.slice(0, 6).map((n) => n.target.join(' ')),
          // For contrast, capture the measured colors + ratio so findings can be
          // triaged (real defect vs theme-shim artifact) without re-running.
          detail: v.id === 'color-contrast'
            ? v.nodes.slice(0, 8).map((n) => {
                const d = n.any?.[0]?.data as Record<string, unknown> | undefined;
                return { target: n.target.join(' '), fg: d?.fgColor, bg: d?.bgColor, ratio: d?.contrastRatio };
              })
            : undefined,
        })),
      };
      fs.writeFileSync(
        path.join(RESULTS_DIR, `${entry.name}.${entry.theme}.${vp.label}.json`),
        JSON.stringify(summary, null, 2), 'utf8',
      );

      await page.screenshot({
        path: path.join(SCREENS_DIR, `${entry.name}.${entry.theme}.${vp.label}.png`),
        fullPage: true,
      });

      const serious = violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
      const contrast = violations.filter((v) => v.id === 'color-contrast');

      // Soft so the whole matrix runs and every result file is written.
      expect.soft(overflow, `horizontal overflow on ${entry.file} @ ${vp.label}`).toBeLessThanOrEqual(2);
      expect.soft(contrast, `contrast violations on ${entry.file} @ ${vp.label}`).toHaveLength(0);
      expect.soft(serious, `serious/critical a11y on ${entry.file} @ ${vp.label}`).toHaveLength(0);
    });
  }
}
