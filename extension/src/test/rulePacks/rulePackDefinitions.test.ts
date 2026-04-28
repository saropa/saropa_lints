import * as assert from 'assert';
import { RULE_PACK_DEFINITIONS, isPackDetected } from '../../rulePacks/rulePackDefinitions';

function def(id: string) {
  const match = RULE_PACK_DEFINITIONS.find((d) => d.id === id);
  assert.ok(match, `missing pack definition for ${id}`);
  return match!;
}

describe('rulePackDefinitions sdk detection', () => {
  it('detects flutter_sdk_3_32 from environment flutter constraint', () => {
    const pubspec = `
name: demo
environment:
  flutter: ">=3.32.0"
`;
    assert.strictEqual(isPackDetected(def('flutter_sdk_3_32'), pubspec), true);
    assert.strictEqual(isPackDetected(def('flutter_sdk_3_35'), pubspec), false);
  });

  it('detects dart_sdk_3_2 from environment sdk constraint', () => {
    const pubspec = `
name: demo
environment:
  sdk: ">=3.2.0 <4.0.0"
`;
    assert.strictEqual(isPackDetected(def('dart_sdk_3_2'), pubspec), true);
  });

  it('keeps dependency-based detection for package packs', () => {
    const pubspec = `
name: demo
dependencies:
  flutter_riverpod: ^2.0.0
`;
    assert.strictEqual(isPackDetected(def('riverpod'), pubspec), true);
  });
});
