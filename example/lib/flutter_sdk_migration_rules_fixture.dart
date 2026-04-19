// ignore_for_file: undefined_class, undefined_method, undefined_function
// ignore_for_file: undefined_named_parameter, undefined_identifier
// ignore_for_file: undefined_getter, undefined_setter
// ignore_for_file: unused_local_variable, unused_element, dead_code
// ignore_for_file: invalid_use_of_void_result, prefer_const_constructors
// ignore_for_file: avoid_print
//
// Test fixture: Flutter / Dart SDK migration rules
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart
//
// Rules covered:
//   - prefer_iterable_cast (#024)
//   - avoid_deprecated_use_inherited_media_query (#043)
//   - prefer_utf8_encode (#050)
//   - avoid_removed_appbar_backwards_compatibility (#055)
//   - prefer_type_sync_over_is_link_sync (#079)
//   - avoid_removed_js_number_to_dart (#090)
//
// We import Flutter mocks for widget-shaped rules and dart:convert/dart:io
// for the SDK rules. JSNumber is referenced as an undefined identifier (the
// fixture intentionally exercises the unresolved-target code path).

import 'dart:convert';
import 'dart:io';

import 'flutter_mocks.dart';

// =============================================================================
// prefer_iterable_cast (#024) — Iterable.castFrom → .cast<T>()
// =============================================================================

void preferIterableCastBad() {
  final source = <Object>[1, 2, 3];

  // expect_lint: prefer_iterable_cast
  final a = Iterable.castFrom<Object, int>(source);
  // expect_lint: prefer_iterable_cast
  final b = List.castFrom<Object, int>(source);
  // expect_lint: prefer_iterable_cast
  final c = Set.castFrom<Object, int>(source.toSet());
  // expect_lint: prefer_iterable_cast
  final d = Map.castFrom<Object, Object, String, int>(<Object, Object>{});
}

void preferIterableCastGood() {
  final source = <Object>[1, 2, 3];

  // OK: instance method form is the recommended replacement.
  final a = source.cast<int>();

  // OK: List.from / Map.from / Set.from are different APIs (not castFrom).
  final b = List<int>.from(source);
  final c = Set<int>.from(source);
  final d = Map<String, int>.from(<Object, Object>{});

  // OK: a user-defined `castFrom` on a non-dart:core class must not lint.
  final user = _UserCastable<int>();
  user.castFrom<int>(source);
}

class _UserCastable<T> {
  void castFrom<U>(Iterable<Object?> _) {}
}

// =============================================================================
// avoid_deprecated_use_inherited_media_query (#043)
// =============================================================================

Widget useInheritedMediaQueryBad() {
  // expect_lint: avoid_deprecated_use_inherited_media_query
  return MaterialApp(useInheritedMediaQuery: true, home: const _Empty());
}

Widget useInheritedMediaQueryBadCupertino() {
  // expect_lint: avoid_deprecated_use_inherited_media_query
  return CupertinoApp(useInheritedMediaQuery: true, home: const _Empty());
}

Widget useInheritedMediaQueryBadWidgets() {
  // expect_lint: avoid_deprecated_use_inherited_media_query
  return WidgetsApp(useInheritedMediaQuery: true, home: const _Empty());
}

Widget useInheritedMediaQueryGood() {
  // OK: deprecated argument removed.
  return MaterialApp(home: const _Empty());
}

Widget useInheritedMediaQueryFalsePositive() {
  // OK: a non-target widget with the same parameter name must NOT lint —
  // the rule restricts to {MaterialApp, CupertinoApp, WidgetsApp}.
  return _CustomThemeRoot(useInheritedMediaQuery: true);
}

class _Empty extends Widget {
  const _Empty();
}

class _CustomThemeRoot extends Widget {
  const _CustomThemeRoot({super.key, this.useInheritedMediaQuery = false});
  final bool useInheritedMediaQuery;
}

class CupertinoApp extends Widget {
  const CupertinoApp({super.key, Widget? home, bool? useInheritedMediaQuery});
}

class WidgetsApp extends Widget {
  const WidgetsApp({super.key, Widget? home, bool? useInheritedMediaQuery});
}

// =============================================================================
// prefer_utf8_encode (#050) — Utf8Encoder().convert(x) → utf8.encode(x)
// =============================================================================

void preferUtf8EncodeBad() {
  // expect_lint: prefer_utf8_encode
  final a = const Utf8Encoder().convert('hello');
  // expect_lint: prefer_utf8_encode
  final b = Utf8Encoder().convert('world');
}

void preferUtf8EncodeGood() {
  // OK: shorter, idiomatic call.
  final a = utf8.encode('hello');

  // OK: Utf8Encoder used with chunked-conversion APIs is a separate use case
  // and should not be rewritten to utf8.encode.
  final encoder = const Utf8Encoder();
  final sink = encoder.startChunkedConversion(_NoopSink());
  sink.add('chunked');
  sink.close();
}

class _NoopSink implements Sink<List<int>> {
  @override
  void add(List<int> data) {}
  @override
  void close() {}
}

// =============================================================================
// avoid_removed_appbar_backwards_compatibility (#055)
// =============================================================================

Widget appBarBackwardsCompatibilityBad() {
  // expect_lint: avoid_removed_appbar_backwards_compatibility
  return AppBar(backwardsCompatibility: false, title: const _Empty());
}

Widget sliverAppBarBackwardsCompatibilityBad() {
  // expect_lint: avoid_removed_appbar_backwards_compatibility
  return SliverAppBar(backwardsCompatibility: false, title: const _Empty());
}

Widget appBarBackwardsCompatibilityGood() {
  // OK: removed parameter dropped.
  return AppBar(title: const _Empty());
}

Widget appBarBackwardsCompatibilityFalsePositive() {
  // OK: a user widget with the same parameter must NOT lint — the rule
  // restricts to {AppBar, SliverAppBar}.
  return _CustomBar(backwardsCompatibility: true);
}

class _CustomBar extends Widget {
  const _CustomBar({super.key, this.backwardsCompatibility = false});
  final bool backwardsCompatibility;
}

// =============================================================================
// prefer_type_sync_over_is_link_sync (#079)
// =============================================================================

bool isLinkSyncBad(String path) {
  // expect_lint: prefer_type_sync_over_is_link_sync
  return FileSystemEntity.isLinkSync(path);
}

bool isLinkSyncBadInsideCondition(String path) {
  // expect_lint: prefer_type_sync_over_is_link_sync
  if (FileSystemEntity.isLinkSync(path)) {
    return true;
  }
  return false;
}

bool isLinkSyncGood(String path) {
  // OK: portable replacement.
  return FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.link;
}

bool isLinkSyncFalsePositive(String path) {
  // OK: a method named isLinkSync on an unrelated class must NOT lint.
  // The rule restricts to the static FileSystemEntity.isLinkSync from dart:io.
  return _LinkChecker().isLinkSync(path);
}

class _LinkChecker {
  bool isLinkSync(String path) => false;
}

// =============================================================================
// avoid_removed_js_number_to_dart (#090) — .toDart on JSNumber → .toDartDouble / .toDartInt
// =============================================================================
//
// JSNumber lives in dart:js_interop and is web-only. We model it locally so the
// fixture compiles in this Dart-only example package. The rule's unresolved-
// receiver fallback path is what actually fires here, which is also what
// surfaces when an end-user upgrades their Dart SDK past 3.2 and the original
// JSNumber declaration becomes unresolved.

class JSNumber {
  // The removed getter is intentionally absent so the call site is unresolved.
}

extension on JSNumber {
  // Replacements present so the GOOD examples compile.
  double get toDartDouble => 0.0;
  int get toDartInt => 0;
}

double jsNumberToDartBad(JSNumber n) {
  // expect_lint: avoid_removed_js_number_to_dart
  return n.toDart;
}

double jsNumberToDartBadChained(JSNumber Function() factory) {
  // expect_lint: avoid_removed_js_number_to_dart
  return factory().toDart;
}

double jsNumberToDartGoodDouble(JSNumber n) {
  // OK: replacement getter for floating-point values.
  return n.toDartDouble;
}

int jsNumberToDartGoodInt(JSNumber n) {
  // OK: replacement getter for integer values.
  return n.toDartInt;
}

int jsNumberToDartFalsePositive(_NotJsNumber n) {
  // OK: a user-defined .toDart on an unrelated class must NOT lint —
  // the rule's receiver check requires the type be named `JSNumber`.
  return n.toDart;
}

class _NotJsNumber {
  int get toDart => 0;
}
