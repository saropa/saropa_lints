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
