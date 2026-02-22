# Missing Rule: avoid_ios_background_fetch_abuse

## Status
Not implemented — class `AvoidIosBackgroundFetchAbuseRule` was never created during v5 migration.

## Location
- Referenced in `lib/saropa_lints.dart:1818` (commented out)
- Referenced in `lib/src/tiers.dart:1056, 2612` (commented out in recommendedOnlyRules and pedanticOnlyRules)

## Description
This rule was planned to warn when iOS background fetch is used for non-data-fetching tasks (e.g., analytics, mining). The rule name appeared in the v4 roadmap but the implementation class was never created.

## Action Required
Either implement the rule class or remove all references from tiers and registration.
