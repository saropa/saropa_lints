# Missing Rule: require_ios_platform_check

## Status
Not implemented — class `RequireIosPlatformCheckRule` was never created during v5 migration.

## Location
- Referenced in `lib/saropa_lints.dart:1817` (commented out)
- Referenced in `lib/src/tiers.dart:1055, 2611` (commented out in recommendedOnlyRules and pedanticOnlyRules)

## Description
This rule was planned to warn when iOS-specific code is used without a platform check (e.g., `Platform.isIOS`). The rule name appeared in the v4 roadmap but the implementation class was never created.

## Action Required
Either implement the rule class or remove all references from tiers and registration.
