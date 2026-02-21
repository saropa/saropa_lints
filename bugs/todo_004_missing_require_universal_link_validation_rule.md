# Missing Rule: require_universal_link_validation

## Status
Not implemented — class `RequireUniversalLinkValidationRule` was never created during v5 migration.

## Location
- Referenced in `lib/saropa_lints.dart:1888` (commented out)
- Referenced in `lib/src/tiers.dart:1057` (commented out in recommendedOnlyRules)

## Description
This rule was planned to warn when universal links (iOS) are handled without validating the incoming URL. The rule name appeared in the v4 roadmap but the implementation class was never created.

## Action Required
Either implement the rule class or remove all references from tiers and registration.
