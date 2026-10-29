// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_speech_stop_on_dispose` lint rule.

// NOTE: require_speech_stop_on_dispose requires specific framework types
// and widget/package context to trigger.
// See rule documentation for bad/good examples.

void main() {}

// GOOD: dispose() calls `_cancelEngine()`, a helper that calls
// `_speech.cancel()` (same class, or an extension/part file).
