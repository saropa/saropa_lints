// ignore_for_file: unused_element, depend_on_referenced_packages
// Test fixture for: prefer_schedule_microtask_over_window_postmessage
// Source: lib/src/rules/platforms/web_rules.dart

import 'dart:html' as html;

// BAD: empty payload + wildcard origin — same-window scheduling hack
// expect_lint: prefer_schedule_microtask_over_window_postmessage
void _badScheduleEmpty() {
  html.window.postMessage('', '*');
}

// BAD: null payload + wildcard origin
// expect_lint: prefer_schedule_microtask_over_window_postmessage
void _badScheduleNull() {
  html.window.postMessage(null, '*');
}

// OK: explicit target origin (not the defer hack we target)
void _goodExplicitOrigin() {
  html.window.postMessage('', html.window.location.origin);
}

// OK: non-empty payload may be real messaging
void _goodNonEmptyMessage() {
  html.window.postMessage('ping', '*');
}
