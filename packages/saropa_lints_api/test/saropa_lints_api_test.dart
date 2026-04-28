import 'package:analysis_server_plugin/registry.dart';
import 'package:saropa_lints_api/saropa_lints_api.dart';
import 'package:test/test.dart';

void main() {
  test('exports registerSaropaLintRules for composite plugins', () {
    expect(registerSaropaLintRules, isA<void Function(PluginRegistry)>());
  });
}
