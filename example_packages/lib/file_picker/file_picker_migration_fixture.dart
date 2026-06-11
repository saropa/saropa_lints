// ignore_for_file: unused_local_variable, unused_element

/// Fixtures for the 4 version-gated file_picker deprecation rules.
///
/// These rules live in the file_picker_10 / file_picker_12 migration packs and
/// only fire on projects already on those majors. All four flags target named
/// arguments that were removed or replaced in the respective major release.
library;

import 'package:file_picker/file_picker.dart';

// ─── file_picker_deprecated_with_data (pack: file_picker_12) ─────────────────

Future<void> badWithData() async {
  // expect_lint: file_picker_deprecated_with_data
  await FilePicker.platform.pickFiles(withData: true);
}

Future<void> goodWithData() async {
  // withData removed — read bytes lazily after picking.
  final result = await FilePicker.platform.pickFiles();
  if (result == null) return;
  final bytes = await result.files.single.readAsBytes();
}

// ─── file_picker_deprecated_with_read_stream (pack: file_picker_12) ──────────

Future<void> badWithReadStream() async {
  // expect_lint: file_picker_deprecated_with_read_stream
  await FilePicker.platform.pickFiles(withReadStream: true);
}

Future<void> goodWithReadStream() async {
  // withReadStream removed — use readAsByteStream() on the PlatformFile.
  final result = await FilePicker.platform.pickFiles();
  if (result == null) return;
  final stream = result.files.single.readAsByteStream();
}

// ─── file_picker_deprecated_allow_multiple (pack: file_picker_12) ────────────

Future<void> badAllowMultipleTrue() async {
  // expect_lint: file_picker_deprecated_allow_multiple
  await FilePicker.platform.pickFiles(allowMultiple: true);
}

Future<void> badAllowMultipleFalse() async {
  // expect_lint: file_picker_deprecated_allow_multiple
  await FilePicker.platform.pickFiles(allowMultiple: false);
}

Future<void> goodAllowMultiple() async {
  // allowMultiple: true  → pickFiles() (argument removed)
  await FilePicker.platform.pickFiles();
  // allowMultiple: false → pickFile()
  await FilePicker.platform.pickFile();
}

// ─── file_picker_deprecated_allow_compression (pack: file_picker_10) ─────────

Future<void> badAllowCompressionTrue() async {
  // expect_lint: file_picker_deprecated_allow_compression
  await FilePicker.platform.pickFiles(allowCompression: true);
}

Future<void> badAllowCompressionFalse() async {
  // expect_lint: file_picker_deprecated_allow_compression
  await FilePicker.platform.pickFiles(allowCompression: false);
}

Future<void> badAllowCompressionNonLiteral(bool compress) async {
  // Non-literal value: rule fires but no quick fix is offered (report-only).
  // expect_lint: file_picker_deprecated_allow_compression
  await FilePicker.platform.pickFiles(allowCompression: compress);
}

Future<void> goodAllowCompression() async {
  // true  → compressionQuality: 75  (quick fix target)
  await FilePicker.platform.pickFiles(compressionQuality: 75);
  // false → compressionQuality: 0   (quick fix target)
  await FilePicker.platform.pickFiles(compressionQuality: 0);
}
