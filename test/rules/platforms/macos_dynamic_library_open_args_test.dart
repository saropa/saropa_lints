// AvoidMacosHardenedRuntimeViolationsRule reads the first POSITIONAL argument
// of `DynamicLibrary.open`. Under analyzer 14 the argument list is
// `NodeList<Argument>`, so `.whereType<Expression>()` must skip named
// arguments rather than unwrap them.
import 'package:saropa_lints/src/rules/platforms/macos_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  Future<int> count(String code) async => (await runRuleResolved(
    AvoidMacosHardenedRuntimeViolationsRule(),
    code,
  )).length;

  test('absolute positional path is reported', () async {
    expect(
      await count("void f() { DynamicLibrary.open('/usr/lib/x.dylib'); }"),
      1,
    );
  });

  test('Frameworks path is not reported', () async {
    expect(
      await count("void f() { DynamicLibrary.open('/a/Frameworks/x.dylib'); }"),
      0,
    );
  });

  test('named-only argument is ignored, not unwrapped', () async {
    expect(
      await count(
        "void f() { DynamicLibrary.open(path: '/usr/lib/x.dylib'); }",
      ),
      0,
    );
  });

  test('no arguments does not throw or report', () async {
    expect(await count('void f() { DynamicLibrary.open(); }'), 0);
  });
}
