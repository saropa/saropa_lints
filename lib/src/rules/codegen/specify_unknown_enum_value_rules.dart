// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// `json_serializable` enum-decoding safety rule.
///
/// Flags enum-typed fields inside `@JsonSerializable()` classes that have no
/// `unknownEnumValue` fallback configured, so a backend value the client
/// hasn't shipped support for yet throws instead of degrading gracefully.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

/// Warns when an enum-typed field inside a `@JsonSerializable()` class has no
/// `unknownEnumValue` fallback configured on its `@JsonKey`/`@JsonEnum`
/// annotation.
///
/// Since: v14.5.0 | Rule version: v1
///
/// `json_serializable` lets an enum field declare
/// `@JsonKey(unknownEnumValue: MyEnum.unknown)` (or a class-level
/// `@JsonEnum(unknownEnumValue: ...)`) so that when the backend sends an enum
/// string not present in the generated `_$MyEnumEnumMap`, deserialization
/// falls back to the configured sentinel value instead of throwing a
/// `CheckedFromJsonException`. Backend teams routinely add new enum values
/// ahead of client releases; a client without this fallback crashes on any
/// payload carrying the new value — including for enums as innocuous as a
/// "notification type" or "status" field, which can crash the app open on
/// the home screen. This rule flags enum fields (including `List<Enum>` and
/// `Map<K, Enum>` fields) inside a `@JsonSerializable()`/`@JsonEnum()` class
/// whose own `@JsonKey` (or absence of one) carries no `unknownEnumValue`,
/// and the enclosing class has no class-level `@JsonEnum(unknownEnumValue:
/// ...)` covering it. A field explicitly excluded from JSON decoding via
/// `@JsonKey(ignore: true)` or `@JsonKey(includeFromJson: false)` is exempt
/// — it is never populated from JSON, so no fallback is needed. Detection is
/// scoped to annotations visible in the same file as the field declaration;
/// an `@JsonEnum(unknownEnumValue: ...)` placed directly on the enum
/// declaration in a different file is not currently tracked — see the
/// Alternatives section of the originating proposal for the reasoning.
///
/// **BAD:**
/// ```dart
/// enum NotificationType { message, reminder, promo }
///
/// @JsonSerializable()
/// class NotificationPayload {
///   // Enum field has no unknownEnumValue fallback; a new backend value
///   // (e.g. "digest") crashes deserialization instead of degrading
///   // gracefully.
///   final NotificationType type;
///
///   NotificationPayload(this.type);
///
///   factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
///       _$NotificationPayloadFromJson(json);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// enum NotificationType { message, reminder, promo, unknown }
///
/// @JsonSerializable()
/// class NotificationPayload {
///   // Unrecognized backend values fall back to NotificationType.unknown
///   // instead of throwing.
///   @JsonKey(unknownEnumValue: NotificationType.unknown)
///   final NotificationType type;
///
///   NotificationPayload(this.type);
///
///   factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
///       _$NotificationPayloadFromJson(json);
/// }
/// ```
class SpecifyUnknownEnumValueRule extends SaropaLintRule {
  SpecifyUnknownEnumValueRule() : super(code: _code);

  /// Forward-compatibility crash risk, but conditional on the backend
  /// actually shipping a new enum value — not a deterministic failure at
  /// the call site, so this sits at warning rather than error, matching
  /// the sibling `require_json_decode_try_catch` json-decode-safety rule.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'codegen', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  // Enum-element resolution requires the field's static type.
  @override
  bool get usesTypeResolution => true;

  // Cheap pre-filter: every candidate file must reference the annotation
  // class name literally before we bother walking fields.
  @override
  Set<String>? get requiredPatterns => const {'JsonSerializable'};

  static const LintCode _code = LintCode(
    'specify_unknown_enum_value',
    '[specify_unknown_enum_value] Enum-typed field in a @JsonSerializable() '
        'class has no unknownEnumValue fallback configured. When the backend '
        'ships a new enum member ahead of this client release, '
        'json_serializable throws a CheckedFromJsonException while decoding '
        'the unrecognized string instead of degrading gracefully, which can '
        'crash the app on any screen that receives the payload — even for a '
        'field as innocuous as a notification or status type. {v1}',
    correctionMessage:
        'Add @JsonKey(unknownEnumValue: MyEnum.unknown) to the field (adding '
        'an unknown/unrecognized member to the enum first if it does not '
        'already have one), or a class-level @JsonEnum(unknownEnumValue: '
        '...) covering the enum type.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      // Static/const fields aren't populated per-instance from JSON.
      if (node.isStatic) return;

      final ClassDeclaration? enclosingClass = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (enclosingClass == null) return;

      // Only classes that actually generate a JSON decoder are in scope —
      // otherwise there is no `.fromJson` call site that can throw.
      final bool classInScope = _hasAnnotation(
        enclosingClass.metadata,
        'JsonSerializable',
      );
      if (!classInScope) return;

      // A class-level @JsonEnum(unknownEnumValue: ...) is treated as
      // covering every enum field in the class (a simplification — see the
      // class doc comment's known-limitation note).
      final bool classHasUnknownEnumValue = _annotationHasArgument(
        enclosingClass.metadata,
        annotationName: 'JsonEnum',
        argumentName: 'unknownEnumValue',
      );
      if (classHasUnknownEnumValue) return;

      final TypeAnnotation? typeAnnotation = node.fields.type;
      if (typeAnnotation == null) return;

      final DartType? type = typeAnnotation.type;
      if (type == null) return;

      final EnumElement? enumElement = _findEnumElement(type);
      if (enumElement == null) return;

      // Field-level @JsonKey: explicit exclusion or an existing fallback
      // both clear the field.
      final Annotation? jsonKey = _findAnnotation(node.metadata, 'JsonKey');
      if (jsonKey != null) {
        if (_argumentIsTrue(jsonKey, 'ignore')) return;
        if (_argumentIsFalse(jsonKey, 'includeFromJson')) return;
        if (_hasNamedArgument(jsonKey, 'unknownEnumValue')) return;
      }

      reporter.atNode(node);
    });
  }

  /// True when [metadata] contains an annotation whose simple name is
  /// [name] (e.g. `@JsonSerializable(...)` matches `'JsonSerializable'`).
  bool _hasAnnotation(NodeList<Annotation> metadata, String name) =>
      _findAnnotation(metadata, name) != null;

  Annotation? _findAnnotation(NodeList<Annotation> metadata, String name) {
    for (final Annotation annotation in metadata) {
      if (annotation.name.name == name) return annotation;
    }
    return null;
  }

  /// True when [metadata] has an annotation named [annotationName] carrying
  /// a named argument [argumentName] (value not inspected — presence alone
  /// means a fallback was configured).
  bool _annotationHasArgument(
    NodeList<Annotation> metadata, {
    required String annotationName,
    required String argumentName,
  }) {
    final Annotation? annotation = _findAnnotation(metadata, annotationName);
    if (annotation == null) return false;
    return _hasNamedArgument(annotation, argumentName);
  }

  bool _hasNamedArgument(Annotation annotation, String argumentName) {
    final ArgumentList? args = annotation.arguments;
    if (args == null) return false;
    for (final Expression arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == argumentName) {
        return true;
      }
    }
    return false;
  }

  bool _argumentIsTrue(Annotation annotation, String argumentName) =>
      _namedBoolArgumentEquals(annotation, argumentName, expected: true);

  bool _argumentIsFalse(Annotation annotation, String argumentName) =>
      _namedBoolArgumentEquals(annotation, argumentName, expected: false);

  bool _namedBoolArgumentEquals(
    Annotation annotation,
    String argumentName, {
    required bool expected,
  }) {
    final ArgumentList? args = annotation.arguments;
    if (args == null) return false;
    for (final Expression arg in args.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != argumentName) continue;
      final Expression value = arg.expression;
      if (value is BooleanLiteral) return value.value == expected;
      return false;
    }
    return false;
  }

  /// Resolves the [EnumElement] backing [type], looking through `List<T>`,
  /// `Set<T>`, `Iterable<T>`, and `Map<K, T>` (checked on the value type
  /// argument) since `json_serializable` supports `unknownEnumValue` on
  /// collection-typed enum fields identically to bare enum fields.
  /// Nullability does not change the resolved element, so nullable enum
  /// fields (`MyEnum?`) are flagged the same way.
  EnumElement? _findEnumElement(DartType type) {
    if (type is! InterfaceType) return null;

    final Element element = type.element;
    if (element is EnumElement) return element;

    final String typeName = element.name ?? '';
    if ((typeName == 'List' || typeName == 'Set' || typeName == 'Iterable') &&
        type.typeArguments.length == 1) {
      return _findEnumElement(type.typeArguments.first);
    }
    if (typeName == 'Map' && type.typeArguments.length == 2) {
      return _findEnumElement(type.typeArguments[1]);
    }
    return null;
  }
}
