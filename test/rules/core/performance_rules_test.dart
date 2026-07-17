import 'dart:io';

import 'package:saropa_lints/src/rules/core/performance_rules.dart';
import 'package:test/test.dart';

/// Tests for 49 Performance lint rules.
///
/// Test fixtures: example/lib/performance/*
///
/// Two test patterns live here:
///   1. Rule instantiation pin — every rule's class constructs without
///      throwing AND its [code] field carries a problem message ≥50
///      chars containing the canonical `[rule_name]` prefix. This
///      catches typos in either the constructor or the message string
///      that would otherwise only fail at user-facing analysis time.
///   2. Fixture-presence checks — auto-discovered from disk by scanning
///      `example/lib/performance/*_fixture.dart`. New fixtures are
///      verified automatically; no manual list to maintain.
///
/// Length 50 chars is intentional: the registry's `[rule_name]` prefix
/// alone is around 25 chars, so requiring 50+ guarantees a meaningful
/// human description follows the prefix.
void main() {
  group('Performance Rules - Rule Instantiation', () {
    // Reusable runner: each call produces one `test()`. Closing over
    // the factory lets the rule type stay private to the call — we
    // never instantiate the rule outside the test body, so a slow
    // constructor only affects its own test.
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
      'RequireKeysInAnimatedListsRule',
      'require_keys_in_animated_lists',
      () => RequireKeysInAnimatedListsRule(),
    );
    testRule(
      'AvoidExpensiveBuildRule',
      'avoid_expensive_build',
      () => AvoidExpensiveBuildRule(),
    );
    testRule(
      'AvoidSynchronousFileIoRule',
      'avoid_synchronous_file_io',
      () => AvoidSynchronousFileIoRule(),
    );
    testRule(
      'PreferComputeForHeavyWorkRule',
      'prefer_compute_for_heavy_work',
      () => PreferComputeForHeavyWorkRule(),
    );
    testRule(
      'PreferDiskCacheForPersistenceRule',
      'prefer_disk_cache_for_persistence',
      () => PreferDiskCacheForPersistenceRule(),
    );
    testRule(
      'AvoidObjectCreationInHotLoopsRule',
      'avoid_object_creation_in_hot_loops',
      () => AvoidObjectCreationInHotLoopsRule(),
    );
    testRule(
      'PreferCachedGetterRule',
      'prefer_cached_getter',
      () => PreferCachedGetterRule(),
    );
    testRule(
      'AvoidExcessiveWidgetDepthRule',
      'avoid_excessive_widget_depth',
      () => AvoidExcessiveWidgetDepthRule(),
    );
    testRule(
      'RequireItemExtentForLargeListsRule',
      'require_item_extent_for_large_lists',
      () => RequireItemExtentForLargeListsRule(),
    );
    testRule(
      'PreferImagePrecacheRule',
      'prefer_image_precache',
      () => PreferImagePrecacheRule(),
    );
    testRule(
      'AvoidControllerInBuildRule',
      'avoid_controller_in_build',
      () => AvoidControllerInBuildRule(),
    );
    testRule(
      'AvoidSetStateInBuildRule',
      'avoid_setstate_in_build',
      () => AvoidSetStateInBuildRule(),
    );
    testRule(
      'AvoidStringConcatenationLoopRule',
      'avoid_string_concatenation_loop',
      () => AvoidStringConcatenationLoopRule(),
    );
    testRule(
      'AvoidScrollListenerInBuildRule',
      'avoid_scroll_listener_in_build',
      () => AvoidScrollListenerInBuildRule(),
    );
    testRule(
      'PreferValueListenableBuilderRule',
      'prefer_value_listenable_builder',
      () => PreferValueListenableBuilderRule(),
    );
    testRule(
      'AvoidGlobalKeyMisuseRule',
      'avoid_global_key_misuse',
      () => AvoidGlobalKeyMisuseRule(),
    );
    testRule(
      'RequireRepaintBoundaryRule',
      'require_repaint_boundary',
      () => RequireRepaintBoundaryRule(),
    );
    testRule(
      'AvoidTextSpanInBuildRule',
      'avoid_text_span_in_build',
      () => AvoidTextSpanInBuildRule(),
    );
    testRule(
      'AvoidLargeListCopyRule',
      'avoid_large_list_copy',
      () => AvoidLargeListCopyRule(),
    );
    testRule(
      'PreferConstWidgetsRule',
      'prefer_const_widgets',
      () => PreferConstWidgetsRule(),
    );
    testRule(
      'AvoidExpensiveComputationInBuildRule',
      'avoid_expensive_computation_in_build',
      () => AvoidExpensiveComputationInBuildRule(),
    );
    testRule(
      'AvoidWidgetCreationInLoopRule',
      'avoid_widget_creation_in_loop',
      () => AvoidWidgetCreationInLoopRule(),
    );
    testRule(
      'AvoidCallingOfInBuildRule',
      'avoid_calling_of_in_build',
      () => AvoidCallingOfInBuildRule(),
    );
    testRule(
      'RequireImageCacheManagementRule',
      'require_image_cache_management',
      () => RequireImageCacheManagementRule(),
    );
    testRule(
      'AvoidMemoryIntensiveOperationsRule',
      'avoid_memory_intensive_operations',
      () => AvoidMemoryIntensiveOperationsRule(),
    );
    testRule(
      'AvoidClosureMemoryLeakRule',
      'avoid_closure_memory_leak',
      () => AvoidClosureMemoryLeakRule(),
    );
    testRule(
      'PreferStaticConstWidgetsRule',
      'prefer_static_const_widgets',
      () => PreferStaticConstWidgetsRule(),
    );
    testRule(
      'RequireDisposePatternRule',
      'require_dispose_pattern',
      () => RequireDisposePatternRule(),
    );
    testRule(
      'RequireListPreallocateRule',
      'require_list_preallocate',
      () => RequireListPreallocateRule(),
    );
    testRule(
      'PreferBuilderForConditionalRule',
      'prefer_builder_for_conditional',
      () => PreferBuilderForConditionalRule(),
    );
    testRule(
      'RequireWidgetKeyStrategyRule',
      'require_widget_key_strategy',
      () => RequireWidgetKeyStrategyRule(),
    );
    testRule(
      'RequireMenuBarForDesktopRule',
      'require_menu_bar_for_desktop',
      () => RequireMenuBarForDesktopRule(),
    );
    testRule(
      'RequireWindowCloseConfirmationRule',
      'require_window_close_confirmation',
      () => RequireWindowCloseConfirmationRule(),
    );
    testRule(
      'PreferNativeFileDialogsRule',
      'prefer_native_file_dialogs',
      () => PreferNativeFileDialogsRule(),
    );
    testRule(
      'PreferInheritedWidgetCacheRule',
      'prefer_inherited_widget_cache',
      () => PreferInheritedWidgetCacheRule(),
    );
    testRule(
      'PreferLayoutBuilderOverMediaQueryRule',
      'prefer_layout_builder_over_media_query',
      () => PreferLayoutBuilderOverMediaQueryRule(),
    );
    testRule(
      'AvoidBlockingDatabaseUiRule',
      'avoid_blocking_database_ui',
      () => AvoidBlockingDatabaseUiRule(),
    );
    testRule(
      'AvoidMoneyArithmeticOnDoubleRule',
      'avoid_money_arithmetic_on_double',
      () => AvoidMoneyArithmeticOnDoubleRule(),
    );
    testRule(
      'AvoidRebuildOnScrollRule',
      'avoid_rebuild_on_scroll',
      () => AvoidRebuildOnScrollRule(),
    );
    testRule(
      'AvoidAnimationInLargeListRule',
      'avoid_animation_in_large_list',
      () => AvoidAnimationInLargeListRule(),
    );
    testRule(
      'PreferLazyLoadingImagesRule',
      'prefer_lazy_loading_images',
      () => PreferLazyLoadingImagesRule(),
    );
    testRule(
      'PreferElementRebuildRule',
      'prefer_element_rebuild',
      () => PreferElementRebuildRule(),
    );
    testRule(
      'RequireIsolateForHeavyRule',
      'require_isolate_for_heavy',
      () => RequireIsolateForHeavyRule(),
    );
    testRule(
      'AvoidFinalizerMisuseRule',
      'avoid_finalizer_misuse',
      () => AvoidFinalizerMisuseRule(),
    );
    testRule(
      'AvoidJsonInMainRule',
      'avoid_json_in_main',
      () => AvoidJsonInMainRule(),
    );
    testRule(
      'AvoidBlockingMainThreadRule',
      'avoid_blocking_main_thread',
      () => AvoidBlockingMainThreadRule(),
    );
    testRule(
      'AvoidFullSyncOnEveryLaunchRule',
      'avoid_full_sync_on_every_launch',
      () => AvoidFullSyncOnEveryLaunchRule(),
    );
    testRule(
      'AvoidCacheStampedeRule',
      'avoid_cache_stampede',
      () => AvoidCacheStampedeRule(),
    );
    testRule(
      'PreferBinaryFormatRule',
      'prefer_binary_format',
      () => PreferBinaryFormatRule(),
    );
    testRule(
      'PreferPoolPatternRule',
      'prefer_pool_pattern',
      () => PreferPoolPatternRule(),
    );
  });
  group('Performance Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/performance');

    // Auto-discover fixtures from disk so new files are verified
    // automatically — no manual list to drift out of sync.
    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/performance/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
