import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

void main() {
  group('SaropaLints Plugin', () {
    test('createPlugin returns a PluginBase instance', () {
      final plugin = createPlugin();
      expect(plugin, isA<PluginBase>());
    });

    test('createPlugin is callable multiple times', () {
      final plugin1 = createPlugin();
      final plugin2 = createPlugin();
      expect(plugin1, isA<PluginBase>());
      expect(plugin2, isA<PluginBase>());
    });
  });
}
