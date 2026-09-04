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

/// Same bug as above, but with the zero literal on the left
/// (`0 == a.compareTo(b)`) — exercises the reversed-operand-order branch of
/// `_stringPairFor`, which is otherwise identical logic to the more common
/// `a.compareTo(b) == 0` ordering above.
bool sameEmailIgnoringCaseBugReversed(String typedEmail, String storedEmail) {
  // expect_lint: use_compare_without_case
  return 0 == typedEmail.compareTo(storedEmail);
}

// =============================================================================
// BAD: nullable String operand still triggers the rule
//
// `_isStringTyped` special-cases the `String?` display name explicitly, so a
// nullable parameter compared against a non-const literal must still fire —
// nullability does not change the case-sensitivity bug.
// =============================================================================

bool isAdminRoleNullable(String? role) {
  // expect_lint: use_compare_without_case
  return role == 'admin';
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

/// `ClassName.constField`-style access — a `PrefixedIdentifier`, not a bare
/// `SimpleIdentifier` — resolving through the same const-accessor check.
/// Exercises the `_isConstantString` branch called out in the rule's own
/// comment as otherwise unverified by any fixture.
class RouteNames {
  static const String settings = 'settings_page';
}

bool sameRouteViaClassConstant() =>
    RouteNames.settings == kInternalRouteNameA;

// =============================================================================
// GOOD near-miss: not a String comparison at all (int/bool operands)
// =============================================================================

bool sameCount(int a, int b) => a == b;

// =============================================================================
// GOOD near-miss: compareTo() used for ordering, not equality (rule only
// targets the `== 0`/`!= 0` equality shape)
// =============================================================================

bool isBeforeAlphabetically(String a, String b) => a.compareTo(b) < 0;

// =============================================================================
// BAD (documented false positive): enum.name compared against a literal tag
//
// This is a named false-positive risk (see proposal Finish Report), NOT an
// exempted near-miss: `myEnum.name` is a getter access
// (PropertyAccess/PrefixedIdentifier), not a const reference, so neither
// side is recognized as constant and the comparison still fires under
// today's logic, even though the case-sensitive exact-tag match here is
// intentional and correct. Locked in as current behavior so a future
// `_isConstantString`/enum-aware widening is a deliberate change, not an
// accidental regression discovered later.
// =============================================================================

enum Status { active, inactive }

bool isActiveStatus(Status status) {
  // expect_lint: use_compare_without_case
  return status.name == 'active';
}

// =============================================================================
// GOOD near-miss: JSON/API discriminator field compared against a literal
//
// Same reasoning as the enum.name case above: `json['type']` has static
// type `dynamic`, not `String`, so `_isStringTyped` returns false and this
// does NOT fire today — documented so the "not statically typed String"
// exemption for dynamic-typed map access is a locked-in regression case,
// not an accident.
// =============================================================================

bool isSuccessResponse(Map<String, dynamic> json) => json['type'] == 'success';
