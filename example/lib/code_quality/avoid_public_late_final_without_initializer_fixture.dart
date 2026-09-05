// ignore_for_file: unused_local_variable, unused_element, unused_field

/// Fixture for `avoid_public_late_final_without_initializer` lint rule.

// BAD: Should trigger avoid_public_late_final_without_initializer
class _BadUploadTask {
  // expect_lint: avoid_public_late_final_without_initializer
  late final String uploadId; // public, no initializer - crash risk
}

// GOOD: Should NOT trigger — field is private, class controls assignment.
class _GoodPrivateUploadTask {
  late final String _uploadId;

  void assignId(String id) {
    _uploadId = id;
  }
}

// GOOD: Should NOT trigger — field has an inline initializer.
class _GoodInitializedUploadTask {
  late final String uploadId = _generateId();

  static String _generateId() => 'id';
}

// BAD: Should trigger — static late final with no initializer has the same
// hidden-assignment-contract problem as instance fields.
class _BadStaticLateFinal {
  // expect_lint: avoid_public_late_final_without_initializer
  static late final String config;
}

// BAD: Should trigger on BOTH variables — each public late final without
// initializer is a separate hidden contract.
class _BadMultiVariable {
  // expect_lint: avoid_public_late_final_without_initializer
  // expect_lint: avoid_public_late_final_without_initializer
  late final String first, second;
}

// GOOD: Should NOT trigger — late but not final, out of scope for this rule.
class _GoodLateNonFinalUploadTask {
  late String uploadId;
}

// GOOD: Should NOT trigger — static late final WITH an initializer is
// self-documenting about its value.
class _GoodStaticInitialized {
  static late final String config = _loadConfig();

  static String _loadConfig() => 'default';
}
