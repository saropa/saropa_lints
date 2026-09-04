/// Fixtures for use_compare_without_case.
library;

// =============================================================================
// BAD: direct == comparison of unnormalized String values
// =============================================================================

/// User-supplied role compared without normalizing case — silently rejects
/// "Admin", "ADMIN", etc. even though they mean the same role as "admin".
bool isAdminRole(String role) {
  // expect_lint: use_compare_without_case
  return role == 'admin';
}

/// `!=` form of the same bug.
bool isNotAdminRole(String role) {
  // expect_lint: use_compare_without_case
  return role != 'admin';
}

// =============================================================================
// BAD: compareTo(...) == 0 is the same bug in a different shape
// =============================================================================

bool sameEmailIgnoringCaseBug(String typedEmail, String storedEmail) {
  // expect_lint: use_compare_without_case
  return typedEmail.compareTo(storedEmail) == 0;
}

// =============================================================================
// GOOD: normalized with toLowerCase()/toUpperCase() before comparing
// =============================================================================

bool isAdminRoleNormalized(String role) {
  return role.toLowerCase() == 'admin';
}

bool isNotAdminRoleNormalized(String role) {
  return role.toUpperCase() != 'ADMIN';
}

// =============================================================================
// GOOD: both sides are compile-time constants under our own control
//
// NOTE: a parameter compared against a single const (e.g.
// `route == kRouteName`) still fires — the parameter side is not a
// compile-time constant, so the "at least one side is not constant"
// trigger condition still applies. The exemption requires BOTH sides to be
// constants we author ourselves, e.g. two internal route-name constants.
// =============================================================================

const String kInternalRouteNameA = 'settings_page';
const String kInternalRouteNameB = 'settings_page';

/// Both operands are our own const strings — casing is intentional and
/// fully known at author time, so this is exempt.
bool sameInternalRoute() => kInternalRouteNameA == kInternalRouteNameB;

bool literalsMatch() => 'abc' == 'xyz';

// =============================================================================
// GOOD near-miss: not a String comparison at all (int/bool operands)
// =============================================================================

bool sameCount(int a, int b) => a == b;

// =============================================================================
// GOOD near-miss: compareTo() used for ordering, not equality (rule only
// targets the `== 0`/`!= 0` equality shape)
// =============================================================================

bool isBeforeAlphabetically(String a, String b) => a.compareTo(b) < 0;
