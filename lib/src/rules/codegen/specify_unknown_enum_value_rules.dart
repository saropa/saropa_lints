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
/// `Map<K, Enum>` fields, checked on the map's value type — an enum-typed
/// map *key* is not checked) inside a class carrying `@JsonSerializable()`
/// and/or a class-level `@JsonEnum(...)` whose own `@JsonKey` (or absence of
/// one) carries no `unknownEnumValue`, and the enclosing class has no
/// class-level `@JsonEnum(unknownEnumValue: ...)` covering it. A class
/// annotated `@JsonSerializable(createFactory: false)` is out of scope
/// entirely — no `.fromJson` decoder is generated, so there is no decode
/// path that can throw. A field is also exempt when its `@JsonKey` carries
/// `ignore: true`, `includeFromJson: false`, or a custom `fromJson:`
/// converter — each removes the field from the generated decoder's enum-map
/// lookup, so `unknownEnumValue` would not apply to it. Detection is scoped
/// to annotations visible in the same file as the field declaration; an
/// `@JsonEnum(unknownEnumValue: ...)` placed directly on the enum
/// declaration in a different file is not currently tracked — see the
/// Alternatives section of the originating proposal for the reasoning.
/// Annotation matching is by simple name only (with basic support for a
/// prefixed import, e.g. `@json.JsonSerializable()`), not by resolved
/// import — an unrelated local class that happens to be named
/// `JsonSerializable`/`JsonKey`/`JsonEnum` would also match.
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
        '...) covering the enum type. For a nullable enum field, an '
        'unrecognized value silently decodes to null instead of throwing — '
        'if that is the intended fallback, suppress with `// ignore:` and a '
        'one-line reason rather than leaving the gap undocumented.',
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
      // otherwise there is no `.fromJson` call site that can throw. A class
      // is in scope via either @JsonSerializable() (the common pairing) or
      // a bare class-level @JsonEnum(...) (a shared enum-decoding config
      // class with no @JsonSerializable of its own) — matching the
      // proposal's stated scope rather than requiring @JsonSerializable
      // unconditionally.
      final Annotation? jsonSerializable = _findAnnotation(
        enclosingClass.metadata,
        'JsonSerializable',
      );
      final Annotation? jsonEnum = _findAnnotation(
        enclosingClass.metadata,
        'JsonEnum',
      );
      if (jsonSerializable == null && jsonEnum == null) return;

      // @JsonSerializable(createFactory: false) generates toJson-only code —
      // no `.fromJson` decoder is emitted at all, so there is no decode path
      // that can ever throw on an unrecognized enum value. Bail out rather
      // than flag a class that has no fallible decode site. A bare
      // @JsonEnum with no @JsonSerializable has no `createFactory` argument
      // of its own, so this only applies when @JsonSerializable is present.
      if (jsonSerializable != null &&
          _argumentIsFalse(jsonSerializable, 'createFactory')) {
        return;
      }

      // A class-level @JsonEnum(unknownEnumValue: ...) is treated as
      // covering every enum field in the class (a simplification — see the
      // class doc comment's known-limitation note).
      final bool classHasUnknownEnumValue =
          jsonEnum != null && _hasNamedArgument(jsonEnum, 'unknownEnumValue');
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
        // A custom `fromJson:` converter routes decoding through a
        // hand-written function instead of the generated enum-map lookup —
        // json_serializable ignores `unknownEnumValue` entirely when a
        // custom converter is present, so any unknown-value handling (or
        // lack of it) lives inside that function, out of this rule's reach.
        if (_hasNamedArgument(jsonKey, 'fromJson')) return;
      }

      reporter.atNode(node);
    });
  }

  Annotation? _findAnnotation(NodeList<Annotation> metadata, String name) {
    for (final Annotation annotation in metadata) {
      final String annotationName = annotation.name.name;
      // Plain `@JsonSerializable()` resolves `name.name` to the bare class
      // name, but a prefixed import (`import '...' as json;` then
      // `@json.JsonSerializable()`) makes `name` a PrefixedIdentifier whose
      // `.name` returns the full "json.JsonSerializable" lexeme — never
      // equal to the bare literal, so match the trailing ".Name" segment
      // too rather than silently treating the class as out of scope.
      if (annotationName == name || annotationName.endsWith('.$name')) {
        return annotation;
      }
    }
    return null;
  }

  /// True when [annotation] carries a named argument [argumentName] (value
  /// not inspected — presence alone means a fallback/converter was
  /// configured, which is all the call sites above need).
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

    // Prefer the analyzer's own dart:core type predicates over comparing
    // bare type names — a user-defined class literally named `List`/`Map`
    // (in an unrelated library) would otherwise be misidentified as the
    // core collection type it merely shares a name with.
    final bool isSingleTypeArgCollection =
        type.isDartCoreList || type.isDartCoreSet || type.isDartCoreIterable;
    if (isSingleTypeArgCollection && type.typeArguments.length == 1) {
      return _findEnumElement(type.typeArguments.first);
    }
    // Map value (not key) is the JSON-decode target `unknownEnumValue`
    // applies to — enum-typed map keys are not checked (see class doc
    // comment's known-limitation note).
    if (type.isDartCoreMap && type.typeArguments.length == 2) {
      return _findEnumElement(type.typeArguments[1]);
    }
    return null;
  }
}
