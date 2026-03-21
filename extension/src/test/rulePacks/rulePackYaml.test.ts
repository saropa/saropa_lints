import * as assert from 'assert';
import { parseRulePacksEnabled } from '../../rulePacks/rulePackYaml';

describe('rulePackYaml', () => {
  it('parseRulePacksEnabled reads enabled list', () => {
    const yaml = `
plugins:
  saropa_lints:
    version: "9.0.0"
    rule_packs:
      enabled:
        - riverpod
        - drift
    diagnostics:
      foo: true
`;
    const ids = parseRulePacksEnabled(yaml);
    assert.deepStrictEqual(ids, ['riverpod', 'drift']);
  });

  it('parseRulePacksEnabled returns empty when absent', () => {
    assert.deepStrictEqual(parseRulePacksEnabled('plugins:\n  saropa_lints:\n'), []);
  });

  it('parseRulePacksEnabled handles CRLF line endings', () => {
    const yaml =
      'plugins:\r\n  saropa_lints:\r\n    rule_packs:\r\n      enabled:\r\n        - riverpod\r\n';
    assert.deepStrictEqual(parseRulePacksEnabled(yaml), ['riverpod']);
  });
});
