import * as assert from 'assert';
import { RULE_PACK_DEFINITIONS, isPackDetected } from '../../rulePacks/rulePackDefinitions';

/** Static pack definitions vs pubspec environment (SDK / Flutter gates). */

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

  it('detects dart_sdk_3_4 from environment sdk constraint', () => {
    const pubspec = `
name: demo
environment:
  sdk: ">=3.4.0 <4.0.0"
`;
    assert.strictEqual(isPackDetected(def('dart_sdk_3_4'), pubspec), true);
    assert.strictEqual(isPackDetected(def('dart_sdk_3_2'), pubspec), true);
  });

  it('includes js_interop migration rules in dart_sdk_3_2 pack', () => {
    const dartSdkPack = def('dart_sdk_3_2');
    assert.ok(
      dartSdkPack.ruleCodes.includes('avoid_legacy_jsboolean_return_assumptions'),
      'expected avoid_legacy_jsboolean_return_assumptions in dart_sdk_3_2',
    );
    assert.ok(
      dartSdkPack.ruleCodes.includes('prefer_string_for_typeof_equals'),
      'expected prefer_string_for_typeof_equals in dart_sdk_3_2',
    );
    assert.ok(
      dartSdkPack.ruleCodes.includes('prefer_int_for_jsarray_with_length'),
      'expected prefer_int_for_jsarray_with_length in dart_sdk_3_2',
    );
  });

  it('includes dart 3.4 migration rules in dart_sdk_3_4 pack', () => {
    const dartSdkPack = def('dart_sdk_3_4');
    assert.ok(
      dartSdkPack.ruleCodes.includes('avoid_deprecated_file_system_delete_event_is_directory'),
      'expected avoid_deprecated_file_system_delete_event_is_directory in dart_sdk_3_4',
    );
    assert.ok(
      dartSdkPack.ruleCodes.includes('avoid_removed_null_thrown_error'),
      'expected avoid_removed_null_thrown_error in dart_sdk_3_4',
    );
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
