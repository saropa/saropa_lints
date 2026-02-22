# Missing Rule: require_method_channel_error_handling

## Status
Not implemented — class `RequireMethodChannelErrorHandlingRule` was never created during v5 migration.

## Location
- Referenced in `lib/saropa_lints.dart:1866` (commented out)
- Referenced in `lib/src/tiers.dart:506` (commented out in essentialRules)

## Description
This rule was planned to warn when MethodChannel calls lack error handling (try-catch for PlatformException). The rule name appeared in the v4 roadmap but the implementation class was never created.

## Action Required
Either implement the rule class or remove all references from tiers and registration.
