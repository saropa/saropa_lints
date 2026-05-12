import 'package:analysis_server_plugin/registry.dart';
import 'package:saropa_lints_api/saropa_lints_api.dart';
// Requires `dart pub get` in packages/saropa_lints_api/ — this sub-package
// has its own pubspec.yaml and dependency resolution is not inherited from the
// monorepo root.
import 'package:test/test.dart';

void main() {
  test('exports registerSaropaLintRules for composite plugins', () {
    expect(registerSaropaLintRules, isA<void Function(PluginRegistry)>());
  });
}
