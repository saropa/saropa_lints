// ignore_for_file: unused_local_variable, unused_element, unused_import

/// Fixture for share_plus lint rules.
///
/// BAD examples are marked with `// LINT: <rule_code>`.
/// GOOD examples must NOT trigger any of the rules.
///
/// Mock stubs replace the real share_plus types so the fixture compiles without
/// the package present in this test environment.
library;

import 'package:share_plus/share_plus.dart';

// =============================================================================
// Mock stubs — replace real share_plus types for fixture compilation.
// The rules are import-gated; the `package:share_plus/share_plus.dart` import
// above satisfies the gate. These stubs are only needed when the package is not
// in the pubspec of example_packages.
// =============================================================================

// NOTE: If example_packages has share_plus in its pubspec, remove these stubs.
// They are provided here so the fixture compiles in environments where the real
// package is absent.

// =============================================================================
// prefer_shareplus_instance  — static Share.* calls (migration rule)
// =============================================================================

Future<void> badPreferSharePlusInstance() async {
  // LINT: prefer_shareplus_instance
  Share.share('Hello world');

  // LINT: prefer_shareplus_instance
  Share.share('Hello world', subject: 'Greeting');

  // LINT: prefer_shareplus_instance — sharePositionOrigin must be preserved
  Share.share(
    'Hello iPad',
    subject: 'iPad share',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 50),
  );

  // LINT: prefer_shareplus_instance
  Share.shareUri(Uri.parse('https://example.com'));

  // LINT: prefer_shareplus_instance
  Share.shareXFiles([XFile('/path/to/file.png')], text: 'caption');

  // LINT: prefer_shareplus_instance
  Share.shareFiles(['/path/to/file.png'], text: 'caption');
}

Future<void> goodPreferSharePlusInstance() async {
  // OK: uses the new instance API — must NOT trigger prefer_shareplus_instance.
  await SharePlus.instance.share(ShareParams(text: 'Hello world'));

  // OK: with subject.
  await SharePlus.instance.share(
    ShareParams(
      text: 'Hello world',
      subject: 'Greeting',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 50),
    ),
  );

  // OK: uri form.
  await SharePlus.instance.share(
    ShareParams(uri: Uri.parse('https://example.com')),
  );

  // OK: files form.
  await SharePlus.instance.share(
    ShareParams(files: [XFile('/path/to/file.png')], text: 'caption'),
  );
}

// =============================================================================
// share_plus_missing_position_origin
// =============================================================================

Future<void> badMissingPositionOrigin() async {
  // LINT: share_plus_missing_position_origin — no sharePositionOrigin
  final p1 = ShareParams(text: 'Hello');

  // LINT: share_plus_missing_position_origin — files form, still missing origin
  final p2 = ShareParams(files: [XFile('/img.png')]);

  // LINT: share_plus_missing_position_origin — uri form, still missing origin
  final p3 = ShareParams(uri: Uri.parse('https://example.com'));
}

Future<void> goodMissingPositionOrigin() async {
  // OK: sharePositionOrigin present.
  final p = ShareParams(
    text: 'Hello',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 200, 50),
  );
}

// =============================================================================
// share_plus_unchecked_result
// =============================================================================

Future<void> badUncheckedResult() async {
  final params = ShareParams(
    text: 'Hello',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 50),
  );

  // LINT: share_plus_unchecked_result — awaited but result discarded
  await SharePlus.instance.share(params);
}

Future<void> goodUncheckedResult() async {
  final params = ShareParams(
    text: 'Hello',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 50),
  );

  // OK: result is captured and can be inspected.
  final result = await SharePlus.instance.share(params);
  // (use result here)
}

// =============================================================================
// share_plus_empty_share_params
// =============================================================================

void badEmptyShareParams() {
  // LINT: share_plus_empty_share_params — all fields absent
  final p1 = ShareParams();

  // LINT: share_plus_empty_share_params — empty text, others absent
  final p2 = ShareParams(text: '');

  // LINT: share_plus_empty_share_params — explicit nulls on all three fields
  final p3 = ShareParams(text: null, files: null, uri: null);

  // LINT: share_plus_empty_share_params — empty list files, others absent
  final p4 = ShareParams(files: []);
}

void goodEmptyShareParams() {
  // OK: text is non-empty.
  final p1 = ShareParams(text: 'Hello');

  // OK: files is non-empty.
  final p2 = ShareParams(files: [XFile('/img.png')]);

  // OK: uri is non-null.
  final p3 = ShareParams(uri: Uri.parse('https://example.com'));

  // OK: dynamic value — rule stays silent.
  final someText = 'dynamic';
  final p4 = ShareParams(text: someText);
}

// =============================================================================
// share_plus_uri_and_text_conflict
// =============================================================================

void badUriAndTextConflict() {
  // LINT: share_plus_uri_and_text_conflict — both uri and text are non-null
  final p1 = ShareParams(
    uri: Uri.parse('https://example.com'),
    text: 'Check this out',
  );
}

void goodUriAndTextConflict() {
  // OK: only uri.
  final p1 = ShareParams(uri: Uri.parse('https://example.com'));

  // OK: only text.
  final p2 = ShareParams(text: 'Check this out');

  // OK: nullable String? variable — rule stays silent (conservative).
  String? maybeText;
  final p3 = ShareParams(
    uri: Uri.parse('https://example.com'),
    text: maybeText,
  );
}
