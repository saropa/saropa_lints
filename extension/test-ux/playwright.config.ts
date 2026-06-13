import { defineConfig } from '@playwright/test';

/**
 * UX render harness. Loads the standalone HTML produced by the page generator
 * (out-ux/test/ux/generate-pages.js) from .pages/ and audits each one. No web
 * server: pages are local files loaded via file:// in the spec.
 */
export default defineConfig({
  testDir: '.',
  fullyParallel: true,
  reporter: [['list'], ['json', { outputFile: '.results/results.json' }]],
  use: {
    headless: true,
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
