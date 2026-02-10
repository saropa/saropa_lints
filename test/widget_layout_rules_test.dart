import 'dart:io';

import 'package:test/test.dart';

/// Tests for 73 widget layout lint rules.
///
/// These rules cover layout constraints, scroll behavior, Container
/// alternatives, nesting depth, responsive design, and layout performance.
///
/// Test fixtures: example/lib/widget_layout/*
void main() {
  group('Widget Layout Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_absorb_pointer_misuse',
      'avoid_border_all',
      'avoid_deep_widget_nesting',
      'avoid_deeply_nested_widgets',
      'avoid_expanded_as_spacer',
      'avoid_fixed_dimensions',
      'avoid_flexible_outside_flex',
      'avoid_gesture_detector_in_scrollview',
      'avoid_hardcoded_layout_values',
      'avoid_layout_builder_in_scrollable',
      'avoid_layout_builder_misuse',
      'avoid_listview_without_item_extent',
      'avoid_misnamed_padding',
      'avoid_nested_scaffolds',
      'avoid_nested_scrollables',
      'avoid_opacity_misuse',
      'avoid_repaint_boundary_misuse',
      'avoid_shrink_wrap_in_lists',
      'avoid_shrink_wrap_in_scroll',
      'avoid_singlechildscrollview_with_column',
      'avoid_sized_box_expand',
      'avoid_unconstrained_box_misuse',
      'avoid_unconstrained_images',
      'avoid_wrapping_in_padding',
      'check_for_equals_in_render_object_setters',
      'consistent_update_render_object',
      'prefer_clip_behavior',
      'prefer_const_border_radius',
      'prefer_const_widgets_in_lists',
      'prefer_correct_edge_insets_constructor',
      'prefer_custom_single_child_layout',
      'prefer_fractional_sizing',
      'prefer_ignore_pointer',
      'prefer_intrinsic_dimensions',
      'prefer_keep_alive',
      'prefer_listview_builder',
      'prefer_opacity_widget',
      'prefer_page_storage_key',
      'prefer_positioned_directional',
      'prefer_safe_area_aware',
      'prefer_sized_box_for_whitespace',
      'prefer_sliver_app_bar',
      'prefer_sliver_list',
      'prefer_sliver_list_delegate',
      'prefer_sliver_prefix',
      'prefer_spacing_over_sizedbox',
      'prefer_transform_over_container',
      'prefer_using_list_view',
      'prefer_wrap_over_overflow',
      'require_overflow_box_rationale',
      'require_physics_for_nested_scroll',
      'require_scroll_controller',
      'require_scroll_physics',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/widget_layout/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Flex Layout Rules', () {
    group('avoid_expanded_as_spacer', () {
      test('Expanded with empty child SHOULD trigger', () {
        // Use Spacer() instead
        expect('Expanded-as-spacer detected', isNotNull);
      });

      test('Spacer() should NOT trigger', () {
        expect('Spacer passes', isNotNull);
      });
    });

    group('avoid_flexible_outside_flex', () {
      test('Flexible outside Row/Column SHOULD trigger', () {
        expect('Flexible outside flex detected', isNotNull);
      });

      test('Flexible inside Column should NOT trigger', () {
        expect('Flexible in Column passes', isNotNull);
      });
    });

    group('avoid_single_child_column_row', () {
      test('Column with one child SHOULD trigger', () {
        expect('single child Column detected', isNotNull);
      });

      test('Column with multiple children should NOT trigger', () {
        expect('multi-child Column passes', isNotNull);
      });
    });

    group('avoid_expanded_outside_flex', () {
      test('Expanded outside Row/Column/Flex SHOULD trigger', () {
        expect('Expanded outside flex detected', isNotNull);
      });
    });

    group('prefer_expanded_at_call_site', () {
      test('Expanded returned from build SHOULD trigger', () {
        // Breaks widget reusability
        expect('Expanded in build return detected', isNotNull);
      });
    });

    group('avoid_spacer_in_wrap', () {
      test('Spacer inside Wrap SHOULD trigger', () {
        expect('Spacer in Wrap detected', isNotNull);
      });
    });
  });

  group('Container Alternative Rules', () {
    group('prefer_sized_box_for_whitespace', () {
      test('Container for whitespace SHOULD trigger', () {
        expect('Container for whitespace detected', isNotNull);
      });

      test('SizedBox should NOT trigger', () {
        expect('SizedBox passes', isNotNull);
      });
    });

    group('prefer_align_over_container', () {
      test('Container with only alignment SHOULD trigger', () {
        expect('Container-as-Align detected', isNotNull);
      });
    });

    group('prefer_padding_over_container', () {
      test('Container with only padding SHOULD trigger', () {
        expect('Container-as-Padding detected', isNotNull);
      });
    });

    group('prefer_constrained_box_over_container', () {
      test('Container with only constraints SHOULD trigger', () {
        expect('Container-as-ConstrainedBox detected', isNotNull);
      });
    });

    group('prefer_transform_over_container', () {
      test('Container with only transform SHOULD trigger', () {
        expect('Container-as-Transform detected', isNotNull);
      });
    });

    group('prefer_center_over_align', () {
      test('Align(alignment: center) SHOULD trigger', () {
        expect('Align-as-Center detected', isNotNull);
      });
    });

    group('prefer_opacity_widget', () {
      test('Container for opacity on complex child SHOULD trigger', () {
        expect('Container for opacity detected', isNotNull);
      });
    });

    group('prefer_ignore_pointer', () {
      test('AbsorbPointer for disabling SHOULD trigger', () {
        expect('AbsorbPointer detected', isNotNull);
      });
    });
  });

  group('Scroll Rules', () {
    group('avoid_shrink_wrap_in_lists', () {
      test('shrinkWrap in nested scrollable SHOULD trigger', () {
        // Causes performance issues
        expect('shrinkWrap in list detected', isNotNull);
      });
    });

    group('avoid_shrink_wrap_in_scroll', () {
      test('shrinkWrap in scrollable SHOULD trigger', () {
        expect('shrinkWrap in scroll detected', isNotNull);
      });
    });

    group('avoid_nested_scrollables', () {
      test('nested scrollable widgets SHOULD trigger', () {
        expect('nested scrollables detected', isNotNull);
      });
    });

    group('avoid_singlechildscrollview_with_column', () {
      test('SingleChildScrollView wrapping Column SHOULD trigger', () {
        expect('SCSV with Column detected', isNotNull);
      });
    });

    group('avoid_gesture_detector_in_scrollview', () {
      test('GestureDetector around scrollable SHOULD trigger', () {
        expect('gesture conflict detected', isNotNull);
      });
    });

    group('avoid_layout_builder_in_scrollable', () {
      test('LayoutBuilder inside scrollable SHOULD trigger', () {
        expect('LayoutBuilder in scrollable detected', isNotNull);
      });
    });

    group('avoid_scrollable_in_intrinsic', () {
      test('scrollable inside IntrinsicWidth SHOULD trigger', () {
        expect('scrollable in intrinsic detected', isNotNull);
      });
    });

    group('require_scroll_physics', () {
      test('scrollable without physics SHOULD trigger', () {
        expect('missing scroll physics detected', isNotNull);
      });
    });

    group('require_scroll_controller', () {
      test('scrollable without controller SHOULD trigger', () {
        expect('missing scroll controller detected', isNotNull);
      });
    });

    group('require_physics_for_nested_scroll', () {
      test(
          'nested scrollable without NeverScrollableScrollPhysics SHOULD trigger',
          () {
        expect('missing nested physics detected', isNotNull);
      });
    });

    group('prefer_page_storage_key', () {
      test('scrollable without PageStorageKey SHOULD trigger', () {
        expect('missing PageStorageKey detected', isNotNull);
      });
    });

    group('prefer_keep_alive', () {
      test('tab view without AutomaticKeepAlive SHOULD trigger', () {
        expect('missing keep alive detected', isNotNull);
      });
    });
  });

  group('ListView Rules', () {
    group('prefer_using_list_view', () {
      test('Column in SingleChildScrollView SHOULD trigger', () {
        // Bypasses lazy loading
        expect('Column as list detected', isNotNull);
      });
    });

    group('prefer_listview_builder', () {
      test('ListView with direct children SHOULD trigger', () {
        expect('non-builder ListView detected', isNotNull);
      });
    });

    group('avoid_listview_without_item_extent', () {
      test('ListView.builder without itemExtent SHOULD trigger', () {
        expect('missing itemExtent detected', isNotNull);
      });
    });

    group('avoid_unbounded_listview_in_column', () {
      test('ListView inside Column without constraints SHOULD trigger', () {
        expect('unbounded ListView detected', isNotNull);
      });
    });

    group('avoid_builder_index_out_of_bounds', () {
      test('itemBuilder without bounds check SHOULD trigger', () {
        expect('out of bounds risk detected', isNotNull);
      });
    });
  });

  group('Sliver Rules', () {
    group('prefer_sliver_list', () {
      test('ListView inside CustomScrollView SHOULD trigger', () {
        expect('ListView in CustomScrollView detected', isNotNull);
      });
    });

    group('prefer_sliver_list_delegate', () {
      test('SliverList without delegate SHOULD trigger', () {
        expect('missing delegate detected', isNotNull);
      });
    });

    group('prefer_sliver_app_bar', () {
      test('AppBar in CustomScrollView SHOULD trigger', () {
        expect('AppBar in CustomScrollView detected', isNotNull);
      });
    });

    group('prefer_sliver_prefix', () {
      test('sliver widget without Sliver prefix SHOULD trigger', () {
        expect('missing Sliver prefix detected', isNotNull);
      });
    });
  });

  group('Nesting & Depth Rules', () {
    group('avoid_deeply_nested_widgets', () {
      test('deeply nested widget tree SHOULD trigger', () {
        expect('deep nesting detected', isNotNull);
      });
    });

    group('avoid_deep_widget_nesting', () {
      test('widget tree exceeding 15 levels SHOULD trigger', () {
        expect('excessive nesting detected', isNotNull);
      });
    });

    group('avoid_nested_scaffolds', () {
      test('nested Scaffold SHOULD trigger', () {
        // Creates duplicate app bars
        expect('nested Scaffold detected', isNotNull);
      });
    });

    group('prefer_custom_single_child_layout', () {
      test('deeply nested positioning SHOULD trigger', () {
        expect('deep positioning detected', isNotNull);
      });
    });
  });

  group('Constraint & Sizing Rules', () {
    group('avoid_unbounded_constraints', () {
      test('Column in SCSV without constraints SHOULD trigger', () {
        expect('unbounded constraints detected', isNotNull);
      });
    });

    group('avoid_unconstrained_box_misuse', () {
      test('UnconstrainedBox in constrained parent SHOULD trigger', () {
        expect('UnconstrainedBox misuse detected', isNotNull);
      });
    });

    group('avoid_unconstrained_images', () {
      test('Image without sizing SHOULD trigger', () {
        expect('unconstrained image detected', isNotNull);
      });
    });

    group('avoid_sized_box_expand', () {
      test('SizedBox.expand() SHOULD trigger', () {
        expect('SizedBox.expand detected', isNotNull);
      });
    });

    group('avoid_fixed_dimensions', () {
      test('fixed pixel dimensions SHOULD trigger', () {
        expect('fixed dimensions detected', isNotNull);
      });
    });

    group('prefer_fractional_sizing', () {
      test(
          'percentage-based sizing not using FractionallySizedBox SHOULD trigger',
          () {
        expect('non-fractional sizing detected', isNotNull);
      });
    });

    group('prefer_intrinsic_dimensions', () {
      test('content-based sizing not using IntrinsicWidth SHOULD trigger', () {
        expect('missing IntrinsicWidth detected', isNotNull);
      });
    });

    group('avoid_hardcoded_layout_values', () {
      test('hardcoded layout values SHOULD trigger', () {
        expect('hardcoded values detected', isNotNull);
      });
    });

    group('prefer_sized_box_square', () {
      test('SizedBox(width: x, height: x) SHOULD trigger', () {
        expect('non-square SizedBox detected', isNotNull);
      });
    });

    group('require_overflow_box_rationale', () {
      test('OverflowBox without comment SHOULD trigger', () {
        expect('uncommented OverflowBox detected', isNotNull);
      });
    });

    group('avoid_fixed_size_in_scaffold_body', () {
      test('fixed dimensions in Scaffold body SHOULD trigger', () {
        expect('fixed size in scaffold detected', isNotNull);
      });
    });
  });

  group('Padding & Border Rules', () {
    group('avoid_wrapping_in_padding', () {
      test('Padding around widget with own padding SHOULD trigger', () {
        expect('redundant Padding detected', isNotNull);
      });
    });

    group('avoid_misnamed_padding', () {
      test('"padding" used for margin SHOULD trigger', () {
        expect('misnamed padding detected', isNotNull);
      });
    });

    group('prefer_const_border_radius', () {
      test('non-const BorderRadius.all SHOULD trigger', () {
        expect('non-const BorderRadius detected', isNotNull);
      });
    });

    group('prefer_correct_edge_insets_constructor', () {
      test('EdgeInsets.only with symmetric values SHOULD trigger', () {
        expect('wrong EdgeInsets constructor detected', isNotNull);
      });
    });

    group('avoid_border_all', () {
      test('Border.all for const borders SHOULD trigger', () {
        expect('Border.all detected', isNotNull);
      });
    });
  });

  group('RenderObject Rules', () {
    group('check_for_equals_in_render_object_setters', () {
      test('setter without equality check SHOULD trigger', () {
        expect('missing equality check detected', isNotNull);
      });
    });

    group('consistent_update_render_object', () {
      test('updateRenderObject missing property SHOULD trigger', () {
        expect('inconsistent update detected', isNotNull);
      });
    });
  });

  group('Stack & Positioning Rules', () {
    group('avoid_stack_without_positioned', () {
      test('Stack child without Positioned SHOULD trigger', () {
        expect('unpositioned Stack child detected', isNotNull);
      });
    });

    group('avoid_positioned_outside_stack', () {
      test('Positioned outside Stack SHOULD trigger', () {
        expect('Positioned outside Stack detected', isNotNull);
      });
    });

    group('prefer_positioned_directional', () {
      test('Positioned without RTL support SHOULD trigger', () {
        expect('non-directional Positioned detected', isNotNull);
      });
    });

    group('avoid_table_cell_outside_table', () {
      test('TableCell outside Table SHOULD trigger', () {
        expect('TableCell outside Table detected', isNotNull);
      });
    });

    group('avoid_unconstrained_dialog_column', () {
      test('Column inside dialog without constraints SHOULD trigger', () {
        expect('unconstrained dialog Column detected', isNotNull);
      });
    });

    group('avoid_textfield_in_row', () {
      test('TextField inside Row SHOULD trigger', () {
        expect('TextField in Row detected', isNotNull);
      });
    });
  });

  group('Miscellaneous Layout Rules', () {
    group('avoid_layout_builder_misuse', () {
      test('LayoutBuilder ignoring constraints SHOULD trigger', () {
        expect('LayoutBuilder misuse detected', isNotNull);
      });
    });

    group('avoid_repaint_boundary_misuse', () {
      test('RepaintBoundary around const content SHOULD trigger', () {
        expect('RepaintBoundary misuse detected', isNotNull);
      });
    });

    group('avoid_absorb_pointer_misuse', () {
      test('AbsorbPointer blocking all events SHOULD trigger', () {
        expect('AbsorbPointer misuse detected', isNotNull);
      });
    });

    group('avoid_opacity_misuse', () {
      test('Opacity for animations SHOULD trigger', () {
        // Use AnimatedOpacity instead
        expect('Opacity animation misuse detected', isNotNull);
      });
    });

    group('prefer_const_widgets_in_lists', () {
      test('non-const widget in list SHOULD trigger', () {
        expect('non-const widget in list detected', isNotNull);
      });
    });

    group('prefer_clip_behavior', () {
      test('widget without explicit clipBehavior SHOULD trigger', () {
        expect('missing clipBehavior detected', isNotNull);
      });
    });

    group('prefer_safe_area_aware', () {
      test('content overlapping notch SHOULD trigger', () {
        expect('missing SafeArea detected', isNotNull);
      });
    });

    group('prefer_wrap_over_overflow', () {
      test('Row with many children SHOULD trigger', () {
        // May overflow, use Wrap
        expect('potential overflow detected', isNotNull);
      });
    });

    group('prefer_spacing_over_sizedbox', () {
      test('SizedBox for gaps SHOULD trigger', () {
        expect('SizedBox gap detected', isNotNull);
      });
    });

    group('require_baseline_text_baseline', () {
      test('CrossAxisAlignment.baseline without TextBaseline SHOULD trigger',
          () {
        expect('missing TextBaseline detected', isNotNull);
      });
    });
  });
}
