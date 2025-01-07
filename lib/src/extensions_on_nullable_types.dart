import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _SaropaLints();

class _SaropaLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const _DetectExtensionsOnNullableTypes(),
      ];
}

class _DetectExtensionsOnNullableTypes extends DartLintRule {
  const _DetectExtensionsOnNullableTypes() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_extensions_on_nullable_types',
    problemMessage: 'Avoid defining extensions on nullable types, '
        'as they might not be called when used with ?.',
    correctionMessage: 'Consider using the ?? operator to handle null values.',
    url:
        'https://github.com/myusername/myproject/blob/main/README.md#avoid-extensions-on-nullable-types', // Update with your URL
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionDeclaration((node) {
      final extendedType = node.declaredElement?.extendedType;

      if (extendedType != null &&
          extendedType is InterfaceType &&
          extendedType.nullabilitySuffix == NullabilitySuffix.question) {
        // Access the identifier (name) of the extension
        final extensionName = node.name;

        if (extensionName != null) {
          reporter.atToken(extensionName, _code, arguments: [extendedType]);
        }
      }
    });
  }
}
