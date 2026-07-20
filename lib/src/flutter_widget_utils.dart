// ignore_for_file: depend_on_referenced_packages

/// Utilities for identifying Flutter SDK widgets by resolved element.
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Unwraps a [TypeAliasElement] to its underlying [InterfaceElement], if any.
///
/// `typedef MyImage = Image;` produces a [TypeAliasElement] whose
/// `aliasedType` is an [InterfaceType] wrapping the real [InterfaceElement].
/// Without unwrapping, `type.element is InterfaceElement` returns false and
/// the widget is missed.
InterfaceElement? unwrapToInterface(Element? element) {
  if (element is InterfaceElement) return element;
  if (element is TypeAliasElement) {
    final DartType aliased = element.aliasedType;
    if (aliased is InterfaceType) return aliased.element;
  }
  return null;
}

/// Whether [element] is a class named [name] declared in `package:flutter/`.
///
/// Handles [TypeAliasElement] wrapping and null/unresolved elements. Returns
/// false for identically-named classes from other packages (`package:image`,
/// `dart:ui`, project-local code).
bool isFlutterWidgetNamed(Element? element, String name) {
  final InterfaceElement? iface = unwrapToInterface(element);
  if (iface == null || iface.name != name) return false;
  return iface.library.uri.toString().startsWith('package:flutter/');
}

/// Whether [element] is any class declared in `package:flutter/`.
///
/// Useful when the caller already checked the name and only needs the library
/// origin guard.
bool isFlutterSdkInterface(Element? element) {
  final InterfaceElement? iface = unwrapToInterface(element);
  if (iface == null) return false;
  return iface.library.uri.toString().startsWith('package:flutter/');
}
