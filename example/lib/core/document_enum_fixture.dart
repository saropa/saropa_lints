// ignore_for_file: unused_element

/// Fixtures for document_enum.
library;

// =============================================================================
// BAD: undocumented public enum and undocumented enum values
// =============================================================================

// expect_lint: document_enum
enum OrderStatus {
  // expect_lint: document_enum
  pending,
  // expect_lint: document_enum
  shipped,
  // expect_lint: document_enum
  canceled,
}

/// Documented enum declaration, but its values are not — each
/// documentation target (enum itself, each value) is checked
/// independently, so the declaration passes while the values still fire.
enum ShipmentPriority {
  // expect_lint: document_enum
  standard,
  // expect_lint: document_enum
  expedited,
}

// =============================================================================
// GOOD: fully documented public enum
// =============================================================================

/// Lifecycle states for a customer order.
enum PaymentStatus {
  /// Payment has been authorized but not captured.
  authorized,

  /// Payment has been captured and funds transferred.
  captured,

  /// Payment was refunded after capture.
  refunded,
}

// =============================================================================
// GOOD: private enum is not public API — never flagged
// =============================================================================

enum _InternalRetryPhase {
  initial,
  backoff,
  giveUp,
}

// =============================================================================
// Annotated constants: verifies the doc-comment-vs-annotation ordering does
// NOT cause a false positive/negative. Confirmed empirically against this
// package's analyzer version (see resolved_rule_harness-backed test in
// document_enum_rules_test.dart) — `documentationComment` is recognized
// regardless of whether the `///` block sits before, after, or on the same
// line as an enum constant's annotation. This fixture locks that behavior in
// so a future analyzer upgrade that changes it is caught by a test failure
// rather than shipping a silent regression.
// =============================================================================

/// Serialization-format identifiers for API payload versions.
enum ApiVersion {
  /// Original payload format, kept for legacy client compatibility.
  @Deprecated('Use v2 instead')
  v1,

  @Deprecated('Superseded by v3')
  /// Second payload format — doc comment placed after the annotation still
  /// counts as documented, so this does NOT fire.
  v2,

  /// Current default payload format.
  v3,

  // expect_lint: document_enum
  @Deprecated('Never shipped')
  v0,
}
