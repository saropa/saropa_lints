// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: prefer_utf8_encode
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart

import 'dart:convert';

void preferUtf8EncodeBad() {
  // expect_lint: prefer_utf8_encode
  final a = const Utf8Encoder().convert('hello');
  // expect_lint: prefer_utf8_encode
  final b = Utf8Encoder().convert('world');
}

void preferUtf8EncodeGood() {
  final a = utf8.encode('hello');
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
