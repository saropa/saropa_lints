// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_grace_period_handling` lint rule.

// NOTE: prefer_grace_period_handling fires on purchase status
// checks only for purchased without pending handling.
//
// BAD:
// if (status == PurchaseStatus.purchased) { grant(); }
//
// GOOD:
// if (status == PurchaseStatus.purchased) { grant(); }
// else if (status == PurchaseStatus.pending) { showPending(); }

void main() {}
