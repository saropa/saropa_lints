import 'package:analyzer/dart/element/element.dart';

/// Shared predicates for [AvoidDeprecatedFlutterTestWindowRule].
///
/// Kept in a dedicated library so unit tests can validate package-URI logic
/// (and document element-level contracts) without duplicating heuristics.

/// True when [uri] is a `package:flutter_test/...` library.
bool isFlutterTestPackageUri(Uri? uri) {
  if (uri == null || !uri.isScheme('package')) return false;
  final List<String> segs = uri.pathSegments;
  return segs.isNotEmpty && segs.first == 'flutter_test';
}

/// True when [element] is the SDK [TestWindow] class or one of its constructors.
///
/// **False-positive guard:** only elements whose declaring library is
/// `package:flutter_test` match; a user-defined `class TestWindow` in app code
/// does not.
bool isFlutterTestSdkTestWindowElement(Element? element) {
  if (element == null) return false;
  InterfaceElement? iface;
  if (element is InterfaceElement && element.name == 'TestWindow') {
    iface = element;
  } else if (element is ConstructorElement) {
    final Element? enc = element.enclosingElement;
    if (enc is InterfaceElement && enc.name == 'TestWindow') {
      iface = enc;
    }
  }
  if (iface == null) return false;
  return isFlutterTestPackageUri(iface.library.uri);
}

/// True when [element] is the deprecated `window` getter on SDK
/// [TestWidgetsFlutterBinding].
///
/// [SimpleIdentifier.element] for a getter read is a [GetterElement] in
/// analyzer 9 (setters use [SetterElement]).
bool isFlutterTestSdkTestWidgetsFlutterBindingWindowGetter(Element? element) {
  if (element is! GetterElement) return false;
  if (element.name != 'window') return false;
  final Element? enc = element.enclosingElement;
  if (enc is! ClassElement) return false;
  if (enc.name != 'TestWidgetsFlutterBinding') return false;
  return isFlutterTestPackageUri(enc.library.uri);
}
