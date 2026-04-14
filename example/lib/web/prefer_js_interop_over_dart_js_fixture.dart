// ignore_for_file: uri_does_not_exist, unused_import
// Test fixture for: prefer_js_interop_over_dart_js
// Source: lib/src/rules/platforms/web_rules.dart

// BAD: Should trigger prefer_js_interop_over_dart_js
// expect_lint: prefer_js_interop_over_dart_js
import 'dart:js';

// BAD: dart:js_util also triggers
// expect_lint: prefer_js_interop_over_dart_js
import 'dart:js_util';

void main() {}

// OK: Compliant — use dart:js_interop instead (not in same file to avoid triggering on bad imports)
// See: import 'dart:js_interop';
