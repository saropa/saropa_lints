// ignore_for_file: depend_on_referenced_packages

/// Detection helpers for [PreferImageFilterQualityMediumRule] and
/// [PreferImageFilterQualityMediumFix].
///
/// ## Design
///
/// Flutter 3.24 ([PR #148799](https://github.com/flutter/flutter/pull/148799))
/// changed the default `filterQuality` for `Image`, `RawImage`, `FadeInImage`,
/// and `DecorationImage` from [FilterQuality.low] to [FilterQuality.medium].
/// User code that still passes `filterQuality: FilterQuality.low` is usually
/// legacy alignment with the old default; this rule nudges toward `medium` or
/// omission.
///
/// ## Safety / false positives
///
/// - Widget types must resolve to `package:flutter/` when an [InterfaceElement]
///   is available, so a project-local class named `Image` is not flagged.
/// - When the type is unresolved, lexeme matching is used (typical in partial
///   analysis); that path is narrower than substring heuristics.
/// - `FilterQuality.low` is accepted only when resolved to `dart:ui` / Flutter,
///   or via a strict structural fallback (`FilterQuality.low` only).
/// - `Texture` is intentionally out of scope (framework defaults differ).
///
/// ## Analyzer API
///
/// [SimpleIdentifier] resolution uses [SimpleIdentifier.element] (analyzer 9+).
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

/// Shared AST / element checks for [PreferImageFilterQualityMediumRule] and its fix.
abstract final class ImageFilterQualityLowDetection {
  ImageFilterQualityLowDetection._();

  static const Set<String> _imageFamilyTypes = <String>{
    'Image',
    'RawImage',
    'FadeInImage',
    'DecorationImage',
  };

  static const Set<String> _imageNamedFactories = <String>{
    'network',
    'asset',
    'file',
    'memory',
  };

  static bool _isFlutterSdkInterface(InterfaceElement? e) {
    if (e == null) return false;
    final String u = e.library.uri.toString();
    return u.startsWith('package:flutter/');
  }

  /// Resolved element for [id] (analyzer 9+: [SimpleIdentifier.element]).
  static Element? _identifierElement(SimpleIdentifier id) {
    try {
      return id.element;
    } on Object catch (_) {
      return null;
    }
  }

  /// Whether [typeLexeme] names an image API this rule cares about, and (when
  /// [cls] is resolved) the type comes from `package:flutter/`.
  ///
  /// Unresolved types use [typeLexeme] only so typical Flutter code still
  /// matches; a project-local class named `Image` does not (resolved element
  /// would not be Flutter SDK).
  static bool matchesImageFamilyType(InterfaceElement? cls, String typeLexeme) {
    if (!_imageFamilyTypes.contains(typeLexeme)) {
      return false;
    }
    if (cls == null) {
      return true;
    }
    return _isFlutterSdkInterface(cls) && cls.name == typeLexeme;
  }

  /// `Image(…)` allows the default constructor and `Image.network` / `.asset` / … factories only.
  static bool imageConstructorAllowed(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme != 'Image') return true;
    final String? ctor = node.constructorName.name?.name;
    if (ctor == null) return true;
    return _imageNamedFactories.contains(ctor);
  }

  /// `filterQuality:` argument whose value is `FilterQuality.low` (dart:ui / Flutter).
  static NamedExpression? violatingFilterQualityNamedArg(
    InstanceCreationExpression node,
  ) {
    final NamedType typeNode = node.constructorName.type;
    final String lexeme = typeNode.name.lexeme;
    final Element? typeEl = typeNode.element;
    final InterfaceElement? iface = typeEl is InterfaceElement ? typeEl : null;
    if (!matchesImageFamilyType(iface, lexeme)) return null;
    if (!imageConstructorAllowed(node)) return null;
    return _findFilterQualityLowNamed(node.argumentList.arguments);
  }

  /// Unqualified `Image.network` / … or `FadeInImage.*` parsed as [MethodInvocation].
  static NamedExpression? violatingFilterQualityNamedArgInvocation(
    MethodInvocation node,
  ) {
    final Expression? target = node.target;
    if (target == null) {
      return _violatingFilterQualityForNullTargetMethodInvocation(node);
    }
    if (target is! SimpleIdentifier) return null;
    final String typeName = target.name;
    if (typeName == 'Image') {
      if (!_imageNamedFactories.contains(node.methodName.name)) return null;
    } else if (typeName != 'FadeInImage') {
      return null;
    }

    final Element? targetEl = _identifierElement(target);
    if (targetEl is InterfaceElement) {
      if (!matchesImageFamilyType(targetEl, typeName)) return null;
    } else if (targetEl != null) {
      return null;
    }

    return _findFilterQualityLowNamed(node.argumentList.arguments);
  }

  /// `RawImage(…)`, `Image(…)`, `DecorationImage(…)` often parse as [MethodInvocation]
  /// with a null [MethodInvocation.target] when the ctor context is missing
  /// (e.g. [parseString]); real analysis may still use [InstanceCreationExpression].
  static NamedExpression? _violatingFilterQualityForNullTargetMethodInvocation(
    MethodInvocation node,
  ) {
    final String method = node.methodName.name;
    if (!_imageFamilyTypes.contains(method)) {
      return null;
    }

    final Element? callee = _identifierElement(node.methodName);

    if (callee is ConstructorElement) {
      final Element? enc = callee.enclosingElement;
      final InterfaceElement? iface = enc is InterfaceElement ? enc : null;
      if (iface == null || iface.name != method) {
        return null;
      }
      if (!matchesImageFamilyType(iface, method)) {
        return null;
      }
      final String ctorName = callee.name ?? '';
      if (method == 'Image' && ctorName.isNotEmpty) {
        return null;
      }
      return _findFilterQualityLowNamed(node.argumentList.arguments);
    }

    if (callee != null) {
      return null;
    }

    if (!matchesImageFamilyType(null, method)) {
      return null;
    }
    return _findFilterQualityLowNamed(node.argumentList.arguments);
  }

  static NamedExpression? _findFilterQualityLowNamed(
    NodeList<Expression> args,
  ) {
    for (final Expression arg in args) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'filterQuality') continue;
      if (isFilterQualityLowValue(arg.expression)) return arg;
    }
    return null;
  }

  /// True when [expr] is the [FilterQuality.low] enum constant from `dart:ui` or Flutter.
  static bool isFilterQualityLowValue(Expression expr) {
    final SimpleIdentifier? lowId = _lowNameIdentifier(expr);
    if (lowId == null) return false;
    final Element? el = _identifierElement(lowId);
    if (el is FieldElement && el.name == 'low') {
      final Element? enc = el.enclosingElement;
      if (enc is InterfaceElement && enc.name == 'FilterQuality') {
        final String u = enc.library.uri.toString();
        if (u == 'dart:ui' || u.startsWith('package:flutter/')) {
          return true;
        }
      }
    }
    return _structuralFilterQualityLow(expr);
  }

  static SimpleIdentifier? _lowNameIdentifier(Expression e) {
    if (e is PrefixedIdentifier && e.identifier.name == 'low') {
      return e.identifier;
    }
    if (e is PropertyAccess && e.propertyName.name == 'low') {
      return e.propertyName;
    }
    return null;
  }

  /// Fallback when resolution failed: `FilterQuality.low` only (no import prefix on type).
  static bool _structuralFilterQualityLow(Expression e) {
    if (e is PrefixedIdentifier && e.identifier.name == 'low') {
      final Identifier prefix = e.prefix;
      return prefix is SimpleIdentifier && prefix.name == 'FilterQuality';
    }
    if (e is PropertyAccess && e.propertyName.name == 'low') {
      final Expression? t = e.target;
      return t is SimpleIdentifier && t.name == 'FilterQuality';
    }
    return false;
  }

  /// Replace `.low` with `.medium` when present; otherwise `FilterQuality.medium`.
  ///
  /// Only call after [isFilterQualityLowValue] is true for [expr].
  static String replacementSource(Expression expr) {
    final String src = expr.toSource();
    if (src.endsWith('.low')) {
      return '${src.substring(0, src.length - 4)}.medium';
    }
    return 'FilterQuality.medium';
  }
}
