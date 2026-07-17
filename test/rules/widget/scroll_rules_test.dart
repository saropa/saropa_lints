import 'dart:io';

import 'package:saropa_lints/src/rules/widget/scroll_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 18 Scroll lint rules.
///
/// Test fixtures: example/lib/scroll/*
void main() {
  group('Scroll Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidShrinkWrapInScrollViewRule',
      'avoid_shrinkwrap_in_scrollview',
      () => AvoidShrinkWrapInScrollViewRule(),
    );
    testRule(
      'AvoidNestedScrollablesConflictRule',
      'avoid_nested_scrollables_conflict',
      () => AvoidNestedScrollablesConflictRule(),
    );
    testRule(
      'AvoidListViewChildrenForLargeListsRule',
      'avoid_listview_children_for_large_lists',
      () => AvoidListViewChildrenForLargeListsRule(),
    );
    testRule(
      'AvoidExcessiveBottomNavItemsRule',
      'avoid_excessive_bottom_nav_items',
      () => AvoidExcessiveBottomNavItemsRule(),
    );
    testRule(
      'RequireTabControllerLengthSyncRule',
      'require_tab_controller_length_sync',
      () => RequireTabControllerLengthSyncRule(),
    );
    testRule(
      'AvoidRefreshWithoutAwaitRule',
      'avoid_refresh_without_await',
      () => AvoidRefreshWithoutAwaitRule(),
    );
    testRule(
      'AvoidMultipleAutofocusRule',
      'avoid_multiple_autofocus',
      () => AvoidMultipleAutofocusRule(),
    );
    testRule(
      'RequireRefreshIndicatorOnListsRule',
      'require_refresh_indicator_on_lists',
      () => RequireRefreshIndicatorOnListsRule(),
    );
    testRule(
      'AvoidShrinkWrapExpensiveRule',
      'avoid_shrink_wrap_expensive',
      () => AvoidShrinkWrapExpensiveRule(),
    );
    testRule(
      'PreferItemExtentRule',
      'prefer_item_extent',
      () => PreferItemExtentRule(),
    );
    testRule(
      'PreferCacheExtentRule',
      'prefer_cache_extent',
      () => PreferCacheExtentRule(),
    );
    testRule(
      'PreferPrototypeItemRule',
      'prefer_prototype_item',
      () => PreferPrototypeItemRule(),
    );
    testRule(
      'RequireKeyForReorderableRule',
      'require_key_for_reorderable',
      () => RequireKeyForReorderableRule(),
    );
    testRule(
      'RequireAddAutomaticKeepAlivesOffRule',
      'require_add_automatic_keep_alives_off',
      () => RequireAddAutomaticKeepAlivesOffRule(),
    );
    testRule(
      'PreferSliverFillRemainingForEmptyRule',
      'prefer_sliverfillremaining_for_empty',
      () => PreferSliverFillRemainingForEmptyRule(),
    );
    testRule(
      'AvoidInfiniteScrollDuplicateRequestsRule',
      'avoid_infinite_scroll_duplicate_requests',
      () => AvoidInfiniteScrollDuplicateRequestsRule(),
    );
    testRule(
      'PreferInfiniteScrollPreloadRule',
      'prefer_infinite_scroll_preload',
      () => PreferInfiniteScrollPreloadRule(),
    );
    testRule(
      'RequirePaginationForLargeListsRule',
      'require_pagination_for_large_lists',
      () => RequirePaginationForLargeListsRule(),
    );
  });
  group('Scroll Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/scroll');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/scroll/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
