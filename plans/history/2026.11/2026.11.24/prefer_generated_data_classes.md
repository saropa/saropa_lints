# prefer_generated_data_classes (issue #415)

Projects that depend on dart_mappable, freezed or json_serializable still accumulated hand-written `toJson`/`fromJson`/`copyWith`/`==` boilerplate, mostly from AI-assisted code, producing typos and many `avoid_duplicate_string_literals_pair` hits. No existing rule covered `@MappableClass`; `prefer_freezed_for_data_classes` ignores dart_mappable and serialization members.

## Finish Report (2026-11-24)

- New rule `PreferGeneratedDataClassesRule` in `lib/src/rules/codegen/generated_data_class_rules.dart`; registered in `_allRuleFactories`, `all_rules.dart`, `professionalOnlyRules`, and `rule_category_map.dart`. INFO severity, no quick fix (conversion needs build_runner).
- Fires on non-abstract classes with an instance field and a concrete `toJson`, `fromJson`, `copyWith`, or both `==` and `hashCode`, when a generator package is a dependency. `toString` alone and a lone `==` are excluded by design (noise).
- Skips `@MappableClass`, `@freezed`, `@Freezed`, `@unfreezed`, `@Unfreezed`, `@JsonSerializable`, and generated mixins (`_$X`, `XMappable`).
- Verified: scan CLI on a temp project flagged exactly the two BAD classes with dart_mappable present and none without it. `generated_data_classes_test.dart`, `saropa_lints_test.dart`, `anti_pattern_detection_test.dart`, `rule_tier_index_test.dart` pass.
- Limitation: `example_packages` has no generator dependency, so the fixture cannot fire there; behavior is pinned by the scan check above.
