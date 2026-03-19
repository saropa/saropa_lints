/**
 * Unit test for the bundled Saropa Lints AI instructions template.
 * Ensures the template exists and contains required sections so the
 * "Create Saropa Lints Instructions for AI Agents" command produces a valid ruleset.
 */

import * as assert from 'assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

describe('Saropa instructions template', () => {
  const templatePath = path.join(
    __dirname,
    '../../../media/saropa_lints_instructions.mdc',
  );

  it('template file exists in extension media', () => {
    assert.ok(fs.existsSync(templatePath), `Template missing: ${templatePath}`);
  });

  it('template contains required project references and guidelines', () => {
    const content = fs.readFileSync(templatePath, 'utf-8');
    assert.ok(content.includes('all_rules.dart'), 'Template must reference rule registration');
    assert.ok(content.includes('tiers.dart'), 'Template must reference tier assignment');
    assert.ok(content.includes('ROADMAP.md'), 'Template must reference ROADMAP');
    assert.ok(content.includes('// ignore'), 'Template must mention ignore prohibition');
    assert.ok(content.includes('CLAUDE.md'), 'Template must reference CLAUDE.md');
  });
});
