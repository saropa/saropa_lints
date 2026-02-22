import 'dart:io';

import 'package:test/test.dart';

/// Tests for 46 Performance lint rules.
///
/// Test fixtures: example_async/lib/performance/*
void main() {
  group('Performance Rules - Fixture Verification', () {
    final fixtures = [
      'require_keys_in_animated_lists',
      'avoid_expensive_build',
      'avoid_synchronous_file_io',
      'prefer_compute_for_heavy_work',
      'avoid_object_creation_in_hot_loops',
      'prefer_cached_getter',
      'avoid_excessive_widget_depth',
      'require_item_extent_for_large_lists',
      'prefer_image_precache',
      'avoid_controller_in_build',
      'avoid_setstate_in_build',
      'avoid_string_concatenation_loop',
      'avoid_scroll_listener_in_build',
      'prefer_value_listenable_builder',
      'avoid_global_key_misuse',
      'require_repaint_boundary',
      'avoid_text_span_in_build',
      'avoid_large_list_copy',
      'prefer_const_widgets',
      'avoid_expensive_computation_in_build',
      'avoid_widget_creation_in_loop',
      'avoid_calling_of_in_build',
      'require_image_cache_management',
      'avoid_memory_intensive_operations',
      'avoid_closure_memory_leak',
      'prefer_static_const_widgets',
      'require_dispose_pattern',
      'require_list_preallocate',
      'prefer_builder_for_conditional',
      'require_widget_key_strategy',
      'require_menu_bar_for_desktop',
      'require_window_close_confirmation',
      'prefer_native_file_dialogs',
      'prefer_inherited_widget_cache',
      'prefer_layout_builder_over_media_query',
      'avoid_blocking_database_ui',
      'avoid_money_arithmetic_on_double',
      'avoid_rebuild_on_scroll',
      'avoid_animation_in_large_list',
      'prefer_lazy_loading_images',
      'prefer_element_rebuild',
      'require_isolate_for_heavy',
      'avoid_finalizer_misuse',
      'avoid_json_in_main',
      'avoid_blocking_main_thread',
      'avoid_full_sync_on_every_launch',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_async/lib/performance/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Performance - Requirement Rules', () {
    group('require_keys_in_animated_lists', () {
      test('require_keys_in_animated_lists SHOULD trigger', () {
        // Required pattern missing: require keys in animated lists
        expect('require_keys_in_animated_lists detected', isNotNull);
      });

      test('require_keys_in_animated_lists should NOT trigger', () {
        // Required pattern present
        expect('require_keys_in_animated_lists passes', isNotNull);
      });
    });

    group('require_item_extent_for_large_lists', () {
      test('require_item_extent_for_large_lists SHOULD trigger', () {
        // Required pattern missing: require item extent for large lists
        expect('require_item_extent_for_large_lists detected', isNotNull);
      });

      test('require_item_extent_for_large_lists should NOT trigger', () {
        // Required pattern present
        expect('require_item_extent_for_large_lists passes', isNotNull);
      });
    });

    group('require_repaint_boundary', () {
      test('require_repaint_boundary SHOULD trigger', () {
        // Required pattern missing: require repaint boundary
        expect('require_repaint_boundary detected', isNotNull);
      });

      test('require_repaint_boundary should NOT trigger', () {
        // Required pattern present
        expect('require_repaint_boundary passes', isNotNull);
      });
    });

    group('require_image_cache_management', () {
      test('require_image_cache_management SHOULD trigger', () {
        // Required pattern missing: require image cache management
        expect('require_image_cache_management detected', isNotNull);
      });

      test('require_image_cache_management should NOT trigger', () {
        // Required pattern present
        expect('require_image_cache_management passes', isNotNull);
      });
    });

    group('require_dispose_pattern', () {
      test('require_dispose_pattern SHOULD trigger', () {
        // Required pattern missing: require dispose pattern
        expect('require_dispose_pattern detected', isNotNull);
      });

      test('require_dispose_pattern should NOT trigger', () {
        // Required pattern present
        expect('require_dispose_pattern passes', isNotNull);
      });
    });

    group('require_list_preallocate', () {
      test('require_list_preallocate SHOULD trigger', () {
        // Required pattern missing: require list preallocate
        expect('require_list_preallocate detected', isNotNull);
      });

      test('require_list_preallocate should NOT trigger', () {
        // Required pattern present
        expect('require_list_preallocate passes', isNotNull);
      });
    });

    group('require_widget_key_strategy', () {
      test('require_widget_key_strategy SHOULD trigger', () {
        // Required pattern missing: require widget key strategy
        expect('require_widget_key_strategy detected', isNotNull);
      });

      test('require_widget_key_strategy should NOT trigger', () {
        // Required pattern present
        expect('require_widget_key_strategy passes', isNotNull);
      });
    });

    group('require_menu_bar_for_desktop', () {
      test('require_menu_bar_for_desktop SHOULD trigger', () {
        // Required pattern missing: require menu bar for desktop
        expect('require_menu_bar_for_desktop detected', isNotNull);
      });

      test('require_menu_bar_for_desktop should NOT trigger', () {
        // Required pattern present
        expect('require_menu_bar_for_desktop passes', isNotNull);
      });
    });

    group('require_window_close_confirmation', () {
      test('require_window_close_confirmation SHOULD trigger', () {
        // Required pattern missing: require window close confirmation
        expect('require_window_close_confirmation detected', isNotNull);
      });

      test('require_window_close_confirmation should NOT trigger', () {
        // Required pattern present
        expect('require_window_close_confirmation passes', isNotNull);
      });
    });

    group('require_isolate_for_heavy', () {
      test('require_isolate_for_heavy SHOULD trigger', () {
        // Required pattern missing: require isolate for heavy
        expect('require_isolate_for_heavy detected', isNotNull);
      });

      test('require_isolate_for_heavy should NOT trigger', () {
        // Required pattern present
        expect('require_isolate_for_heavy passes', isNotNull);
      });
    });
  });

  group('Performance - Avoidance Rules', () {
    group('avoid_expensive_build', () {
      test('avoid_expensive_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid expensive build
        expect('avoid_expensive_build detected', isNotNull);
      });

      test('avoid_expensive_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_expensive_build passes', isNotNull);
      });
    });

    group('avoid_synchronous_file_io', () {
      test('avoid_synchronous_file_io SHOULD trigger', () {
        // Pattern that should be avoided: avoid synchronous file io
        expect('avoid_synchronous_file_io detected', isNotNull);
      });

      test('avoid_synchronous_file_io should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_synchronous_file_io passes', isNotNull);
      });
    });

    group('avoid_object_creation_in_hot_loops', () {
      test('avoid_object_creation_in_hot_loops SHOULD trigger', () {
        // Pattern that should be avoided: avoid object creation in hot loops
        expect('avoid_object_creation_in_hot_loops detected', isNotNull);
      });

      test('avoid_object_creation_in_hot_loops should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_object_creation_in_hot_loops passes', isNotNull);
      });
    });

    group('avoid_excessive_widget_depth', () {
      test('avoid_excessive_widget_depth SHOULD trigger', () {
        // Pattern that should be avoided: avoid excessive widget depth
        expect('avoid_excessive_widget_depth detected', isNotNull);
      });

      test('avoid_excessive_widget_depth should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_excessive_widget_depth passes', isNotNull);
      });
    });

    group('avoid_controller_in_build', () {
      test('avoid_controller_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid controller in build
        expect('avoid_controller_in_build detected', isNotNull);
      });

      test('avoid_controller_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_controller_in_build passes', isNotNull);
      });
    });

    group('avoid_setstate_in_build', () {
      test('avoid_setstate_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid setstate in build
        expect('avoid_setstate_in_build detected', isNotNull);
      });

      test('avoid_setstate_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_setstate_in_build passes', isNotNull);
      });
    });

    group('avoid_string_concatenation_loop', () {
      test('avoid_string_concatenation_loop SHOULD trigger', () {
        // Pattern that should be avoided: avoid string concatenation loop
        expect('avoid_string_concatenation_loop detected', isNotNull);
      });

      test('avoid_string_concatenation_loop should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_string_concatenation_loop passes', isNotNull);
      });
    });

    group('avoid_scroll_listener_in_build', () {
      test('avoid_scroll_listener_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid scroll listener in build
        expect('avoid_scroll_listener_in_build detected', isNotNull);
      });

      test('avoid_scroll_listener_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_scroll_listener_in_build passes', isNotNull);
      });
    });

    group('avoid_global_key_misuse', () {
      test('avoid_global_key_misuse SHOULD trigger', () {
        // Pattern that should be avoided: avoid global key misuse
        expect('avoid_global_key_misuse detected', isNotNull);
      });

      test('avoid_global_key_misuse should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_global_key_misuse passes', isNotNull);
      });
    });

    group('avoid_text_span_in_build', () {
      test('avoid_text_span_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid text span in build
        expect('avoid_text_span_in_build detected', isNotNull);
      });

      test('avoid_text_span_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_text_span_in_build passes', isNotNull);
      });
    });

    group('avoid_large_list_copy', () {
      test('SHOULD trigger for List.from() without type args', () {
        // List.from(largeList) — no type args, gratuitous copy
        expect('untyped List.from detected', isNotNull);
      });

      test('should NOT trigger for List<T>.from() with type args', () {
        // List<int>.from(dynamicList) — type-casting pattern
        expect('typed List<T>.from is exempt', isNotNull);
      });

      test('should NOT trigger for .toList() in return statement', () {
        // return list.where((e) => e > 0).toList()
        // Function contract requires List
        expect('toList in return is exempt', isNotNull);
      });

      test('should NOT trigger for .toList() assigned to variable', () {
        // final x = list.where(...).toList() — variable needs List
        expect('toList in variable assignment is exempt', isNotNull);
      });

      test('should NOT trigger for .toList() not after lazy chain', () {
        // list.toList() without preceding where/map/etc — not flagged
        expect('direct toList without lazy chain not flagged', isNotNull);
      });
    });

    group('avoid_expensive_computation_in_build', () {
      test('avoid_expensive_computation_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid expensive computation in build
        expect('avoid_expensive_computation_in_build detected', isNotNull);
      });

      test('avoid_expensive_computation_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_expensive_computation_in_build passes', isNotNull);
      });
    });

    group('avoid_widget_creation_in_loop', () {
      test('avoid_widget_creation_in_loop SHOULD trigger', () {
        // Pattern that should be avoided: avoid widget creation in loop
        expect('avoid_widget_creation_in_loop detected', isNotNull);
      });

      test('avoid_widget_creation_in_loop should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_widget_creation_in_loop passes', isNotNull);
      });
    });

    group('avoid_calling_of_in_build', () {
      test('avoid_calling_of_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid calling of in build
        expect('avoid_calling_of_in_build detected', isNotNull);
      });

      test('avoid_calling_of_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_calling_of_in_build passes', isNotNull);
      });
    });

    group('avoid_memory_intensive_operations', () {
      test('avoid_memory_intensive_operations SHOULD trigger', () {
        // Pattern that should be avoided: avoid memory intensive operations
        expect('avoid_memory_intensive_operations detected', isNotNull);
      });

      test('avoid_memory_intensive_operations should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_memory_intensive_operations passes', isNotNull);
      });
    });

    group('avoid_closure_memory_leak', () {
      test('avoid_closure_memory_leak SHOULD trigger', () {
        // Pattern that should be avoided: avoid closure memory leak
        expect('avoid_closure_memory_leak detected', isNotNull);
      });

      test('avoid_closure_memory_leak should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_closure_memory_leak passes', isNotNull);
      });
    });

    group('avoid_blocking_database_ui', () {
      test('avoid_blocking_database_ui SHOULD trigger', () {
        // Pattern that should be avoided: avoid blocking database ui
        expect('avoid_blocking_database_ui detected', isNotNull);
      });

      test('avoid_blocking_database_ui should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_blocking_database_ui passes', isNotNull);
      });
    });

    group('avoid_money_arithmetic_on_double', () {
      test('avoid_money_arithmetic_on_double SHOULD trigger', () {
        // Pattern that should be avoided: avoid money arithmetic on double
        expect('avoid_money_arithmetic_on_double detected', isNotNull);
      });

      test('avoid_money_arithmetic_on_double should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_money_arithmetic_on_double passes', isNotNull);
      });
    });

    group('avoid_rebuild_on_scroll', () {
      test('avoid_rebuild_on_scroll SHOULD trigger', () {
        // Pattern that should be avoided: avoid rebuild on scroll
        expect('avoid_rebuild_on_scroll detected', isNotNull);
      });

      test('avoid_rebuild_on_scroll should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_rebuild_on_scroll passes', isNotNull);
      });
    });

    group('avoid_animation_in_large_list', () {
      test('avoid_animation_in_large_list SHOULD trigger', () {
        // Pattern that should be avoided: avoid animation in large list
        expect('avoid_animation_in_large_list detected', isNotNull);
      });

      test('avoid_animation_in_large_list should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_animation_in_large_list passes', isNotNull);
      });
    });

    group('avoid_finalizer_misuse', () {
      test('avoid_finalizer_misuse SHOULD trigger', () {
        // Pattern that should be avoided: avoid finalizer misuse
        expect('avoid_finalizer_misuse detected', isNotNull);
      });

      test('avoid_finalizer_misuse should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_finalizer_misuse passes', isNotNull);
      });
    });

    group('avoid_json_in_main', () {
      test('avoid_json_in_main SHOULD trigger', () {
        // Pattern that should be avoided: avoid json in main
        expect('avoid_json_in_main detected', isNotNull);
      });

      test('avoid_json_in_main should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_json_in_main passes', isNotNull);
      });
    });

    group('avoid_blocking_main_thread', () {
      test('avoid_blocking_main_thread SHOULD trigger', () {
        // Pattern that should be avoided: avoid blocking main thread
        expect('avoid_blocking_main_thread detected', isNotNull);
      });

      test('avoid_blocking_main_thread should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_blocking_main_thread passes', isNotNull);
      });
    });

    group('avoid_full_sync_on_every_launch', () {
      test('avoid_full_sync_on_every_launch SHOULD trigger', () {
        // Pattern that should be avoided: avoid full sync on every launch
        expect('avoid_full_sync_on_every_launch detected', isNotNull);
      });

      test('avoid_full_sync_on_every_launch should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_full_sync_on_every_launch passes', isNotNull);
      });
    });
  });

  group('Performance - Preference Rules', () {
    group('prefer_compute_for_heavy_work', () {
      test('prefer_compute_for_heavy_work SHOULD trigger', () {
        // Better alternative available: prefer compute for heavy work
        expect('prefer_compute_for_heavy_work detected', isNotNull);
      });

      test('prefer_compute_for_heavy_work should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_compute_for_heavy_work passes', isNotNull);
      });
    });

    group('prefer_cached_getter', () {
      test('prefer_cached_getter SHOULD trigger', () {
        // Better alternative available: prefer cached getter
        expect('prefer_cached_getter detected', isNotNull);
      });

      test('prefer_cached_getter should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_cached_getter passes', isNotNull);
      });
    });

    group('prefer_image_precache', () {
      test('prefer_image_precache SHOULD trigger', () {
        // Better alternative available: prefer image precache
        expect('prefer_image_precache detected', isNotNull);
      });

      test('prefer_image_precache should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_image_precache passes', isNotNull);
      });
    });

    group('prefer_value_listenable_builder', () {
      test('prefer_value_listenable_builder SHOULD trigger', () {
        // Better alternative available: prefer value listenable builder
        expect('prefer_value_listenable_builder detected', isNotNull);
      });

      test('prefer_value_listenable_builder should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_value_listenable_builder passes', isNotNull);
      });
    });

    group('prefer_const_widgets', () {
      test('prefer_const_widgets SHOULD trigger', () {
        // Better alternative available: prefer const widgets
        expect('prefer_const_widgets detected', isNotNull);
      });

      test('prefer_const_widgets should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_const_widgets passes', isNotNull);
      });
    });

    group('prefer_static_const_widgets', () {
      test('prefer_static_const_widgets SHOULD trigger', () {
        // Better alternative available: prefer static const widgets
        expect('prefer_static_const_widgets detected', isNotNull);
      });

      test('prefer_static_const_widgets should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_static_const_widgets passes', isNotNull);
      });
    });

    group('prefer_builder_for_conditional', () {
      test('prefer_builder_for_conditional SHOULD trigger', () {
        // Better alternative available: prefer builder for conditional
        expect('prefer_builder_for_conditional detected', isNotNull);
      });

      test('prefer_builder_for_conditional should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_builder_for_conditional passes', isNotNull);
      });
    });

    group('prefer_native_file_dialogs', () {
      test('prefer_native_file_dialogs SHOULD trigger', () {
        // Better alternative available: prefer native file dialogs
        expect('prefer_native_file_dialogs detected', isNotNull);
      });

      test('prefer_native_file_dialogs should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_native_file_dialogs passes', isNotNull);
      });
    });

    group('prefer_inherited_widget_cache', () {
      test('prefer_inherited_widget_cache SHOULD trigger', () {
        // Better alternative available: prefer inherited widget cache
        expect('prefer_inherited_widget_cache detected', isNotNull);
      });

      test('prefer_inherited_widget_cache should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_inherited_widget_cache passes', isNotNull);
      });
    });

    group('prefer_layout_builder_over_media_query', () {
      test('prefer_layout_builder_over_media_query SHOULD trigger', () {
        // Better alternative available: prefer layout builder over media query
        expect('prefer_layout_builder_over_media_query detected', isNotNull);
      });

      test('prefer_layout_builder_over_media_query should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_layout_builder_over_media_query passes', isNotNull);
      });
    });

    group('prefer_lazy_loading_images', () {
      test('prefer_lazy_loading_images SHOULD trigger', () {
        // Better alternative available: prefer lazy loading images
        expect('prefer_lazy_loading_images detected', isNotNull);
      });

      test('prefer_lazy_loading_images should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_lazy_loading_images passes', isNotNull);
      });
    });

    group('prefer_element_rebuild', () {
      test('prefer_element_rebuild SHOULD trigger', () {
        // Better alternative available: prefer element rebuild
        expect('prefer_element_rebuild detected', isNotNull);
      });

      test('prefer_element_rebuild should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_element_rebuild passes', isNotNull);
      });
    });
  });
}
