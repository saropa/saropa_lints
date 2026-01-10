# Implementation Plan: 50 Easy Lint Rules

> **Criteria**: All rules use exact API/parameter matching - no variable name heuristics.

---
<!-- cspell:disable -->
## Rules 1-25 (First Batch)

### 1. `require_image_loading_placeholder`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `Image.network` constructor without `loadingBuilder` or `frameBuilder` parameter
- **Quick-fix**: Add `loadingBuilder: (context, child, progress) => progress == null ? child : CircularProgressIndicator()`
- **Concerns**: May conflict with `CachedNetworkImage` which has different API
- **Opportunities**: Could also check `FadeInImage` as alternative pattern

### 2. `require_image_error_fallback`
- **Tier**: Recommended
- **Severity**: WARNING (network failures are common)
- **Detection**: `Image.network` constructor without `errorBuilder` parameter
- **Quick-fix**: Add `errorBuilder: (context, error, stack) => Icon(Icons.error)`
- **Concerns**: None - straightforward parameter check
- **Opportunities**: Pair with rule #1 in same file for efficiency

### 3. `prefer_image_size_constraints`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: `Image.network` or `Image.asset` without `cacheWidth` or `cacheHeight`
- **Quick-fix**: Add `cacheWidth: 200` with TODO comment to set appropriate size
- **Concerns**: Not always needed for small images; may be noisy
- **Opportunities**: Could calculate suggested size from `width`/`height` if present

### 4. `require_avatar_alt_text`
- **Tier**: Recommended
- **Severity**: WARNING (accessibility issue)
- **Detection**: `CircleAvatar` without `semanticLabel` parameter
- **Quick-fix**: Add `semanticLabel: 'User avatar'` with TODO
- **Concerns**: None - simple parameter check
- **Opportunities**: Part of accessibility rules bundle

### 5. `require_snackbar_duration`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `SnackBar` constructor without `duration` parameter
- **Quick-fix**: Add `duration: Duration(seconds: 4)`
- **Concerns**: Default duration (4s) is often fine; rule may be too noisy
- **Opportunities**: Could be INFO only, not WARNING

### 6. `require_dialog_barrier_dismissible`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `showDialog` without explicit `barrierDismissible` parameter
- **Quick-fix**: Add `barrierDismissible: true` (or false with TODO)
- **Concerns**: Default is true which is often correct
- **Opportunities**: Rename to `require_explicit_barrier_dismissible` for clarity

### 7. `require_keyboard_action_type`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `TextField` or `TextFormField` without `textInputAction` parameter
- **Quick-fix**: Add `textInputAction: TextInputAction.next` (or done for last field)
- **Concerns**: Not always needed for single-field forms
- **Opportunities**: Could check if in a Form widget first

### 8. `require_keyboard_dismiss_on_scroll`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `ListView`/`CustomScrollView` without `keyboardDismissBehavior`
- **Quick-fix**: Add `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`
- **Concerns**: Default behavior may be acceptable in many cases
- **Opportunities**: Only flag when TextField is ancestor/sibling

### 9. `avoid_bluetooth_scan_without_timeout`
- **Tier**: Professional
- **Severity**: WARNING (battery drain)
- **Detection**: `FlutterBluePlus.startScan()` or similar without `timeout` parameter
- **Quick-fix**: Add `timeout: Duration(seconds: 10)`
- **Concerns**: Need to identify all BLE package APIs
- **Opportunities**: Also check `flutter_blue`, `flutter_reactive_ble`

### 10. `require_badge_semantics`
- **Tier**: Recommended
- **Severity**: WARNING (accessibility)
- **Detection**: `Badge` widget without `Semantics` wrapper or `label` parameter
- **Quick-fix**: Wrap with `Semantics(label: 'X notifications')`
- **Concerns**: Badge API varies between packages
- **Opportunities**: Check both Material 3 Badge and badges package

### 11. `require_qr_scan_feedback`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: QR `onDetect` callback without haptic/visual feedback
- **Quick-fix**: Add `HapticFeedback.mediumImpact()` call
- **Concerns**: Hard to detect "feedback" - may need heuristics
- **Opportunities**: Could be simplified to just check for HapticFeedback import

### 12. `prefer_video_loading_placeholder`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `VideoPlayer` widget without placeholder during load
- **Quick-fix**: Add `placeholder: CircularProgressIndicator()`
- **Concerns**: API varies by video player package
- **Opportunities**: Check `video_player`, `better_player`, `chewie`

### 13. `require_scroll_controller_dispose`
- **Tier**: Essential
- **Severity**: ERROR (memory leak)
- **Detection**: `ScrollController` field without `dispose()` call in `dispose()` method
- **Quick-fix**: Add `_scrollController.dispose();` to dispose method
- **Concerns**: Already have similar disposal rules - check for conflicts
- **Opportunities**: Combine with other controller dispose rules

### 14. `require_focus_node_dispose`
- **Tier**: Essential
- **Severity**: ERROR (memory leak)
- **Detection**: `FocusNode` field without `dispose()` call
- **Quick-fix**: Add `_focusNode.dispose();` to dispose method
- **Concerns**: Same pattern as ScrollController
- **Opportunities**: Share detection logic with rule #13

### 15. `prefer_duration_constants`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `Duration(seconds: 60)` when `Duration(minutes: 1)` is clearer
- **Quick-fix**: Replace with equivalent larger unit
- **Concerns**: Need to handle all unit combinations (ms->s, s->m, m->h)
- **Opportunities**: Also suggest named constants for magic durations

### 16. `require_badge_count_limit`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `Badge` with `count` parameter > 99 literal
- **Quick-fix**: Replace with `count > 99 ? '99+' : '$count'`
- **Concerns**: Only catches literals, not variables
- **Opportunities**: Could also flag count > 999 as definitely wrong

### 17. `avoid_badge_without_meaning`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Detection**: `Badge` shown when `count == 0` or `isLabelVisible: count > 0` missing
- **Quick-fix**: Add `isLabelVisible: count > 0`
- **Concerns**: Sometimes 0 badge is intentional (empty state)
- **Opportunities**: Make this INFO not WARNING

### 18. `avoid_datetime_now_in_tests`
- **Tier**: Essential
- **Severity**: WARNING (flaky tests)
- **Detection**: `DateTime.now()` in files matching `*_test.dart`
- **Quick-fix**: Add TODO comment suggesting clock injection
- **Concerns**: Sometimes DateTime.now() is intentional in tests
- **Opportunities**: Suggest `clock` package or `withClock` pattern

### 19. `prefer_cached_network_image`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `Image.network` usage
- **Quick-fix**: Replace with `CachedNetworkImage(imageUrl: url)`
- **Concerns**: Requires adding dependency; may not always be needed
- **Opportunities**: Only suggest if image appears in ListView/GridView

### 20. `prefer_cached_paint_objects`
- **Tier**: Professional
- **Severity**: INFO (performance)
- **Detection**: `Paint()` constructor inside `paint()` method of CustomPainter
- **Quick-fix**: Move to class field with `static final` or instance field
- **Concerns**: Need to identify paint() method context
- **Opportunities**: Big performance win for complex painters

### 21. `require_custom_painter_shouldrepaint`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: `CustomPainter` subclass without `shouldRepaint` override returning meaningful value
- **Quick-fix**: Add `@override bool shouldRepaint(covariant X old) => false;`
- **Concerns**: Need to detect if shouldRepaint just returns true (default-ish)
- **Opportunities**: Suggest comparing relevant fields

### 22. `prefer_itemextent_when_known`
- **Tier**: Professional
- **Severity**: INFO (performance)
- **Detection**: `ListView.builder` without `itemExtent` when items appear uniform
- **Quick-fix**: Add `itemExtent: 72.0` with TODO to measure actual size
- **Concerns**: Hard to know if items are uniform without runtime info
- **Opportunities**: Only flag when itemBuilder returns same widget type

### 23. `require_pdf_error_handling`
- **Tier**: Recommended
- **Severity**: WARNING
- **Detection**: PDF loading (various packages) without try-catch
- **Quick-fix**: Wrap in try-catch with error state handling
- **Concerns**: Many PDF packages with different APIs
- **Opportunities**: Check `flutter_pdfview`, `syncfusion_flutter_pdf`, `pdf_render`

### 24. `require_file_exists_check`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `File.readAsString()`, `File.readAsBytes()` without `exists()` or try-catch
- **Quick-fix**: Add `if (await file.exists())` wrapper or try-catch
- **Concerns**: try-catch may be in calling function
- **Opportunities**: Similar pattern to JSON/DateTime parse rules

### 25. `require_graphql_error_handling`
- **Tier**: Essential
- **Severity**: WARNING
- **Detection**: GraphQL response usage without checking `.errors` or `.hasException`
- **Quick-fix**: Add `if (result.hasException) { ... }` check
- **Concerns**: Different GraphQL packages have different APIs
- **Opportunities**: Check `graphql_flutter`, `ferry`, `artemis`

---

## Rules 26-50 (Second Batch)

### 26. `require_currency_formatting_locale`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `NumberFormat.currency()` without `locale` parameter
- **Quick-fix**: Add `locale: Localizations.localeOf(context).toString()`
- **Concerns**: Need context access for locale
- **Opportunities**: Also check `NumberFormat.simpleCurrency()`

### 27. `require_number_formatting_locale`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: `NumberFormat()`, `NumberFormat.decimal()` etc without `locale`
- **Quick-fix**: Add `locale: 'en_US'` with TODO
- **Concerns**: Many NumberFormat constructors to check
- **Opportunities**: Combine with rule #26

### 28. `require_dialog_result_handling`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: `showDialog` without `await` or `.then()` when dialog has return type
- **Quick-fix**: Add `final result = await showDialog(...)`
- **Concerns**: Hard to know if dialog returns value without type info
- **Opportunities**: Could just flag all non-awaited showDialog calls

### 29. `avoid_snackbar_queue_buildup`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: Multiple `showSnackBar` calls without `clearSnackBars()` or `hideCurrentSnackBar()`
- **Quick-fix**: Add `ScaffoldMessenger.of(context).clearSnackBars();` before show
- **Concerns**: Need to track multiple calls in same method - complex
- **Opportunities**: May need to simplify to just "always clear before show"

### 30. `require_tab_state_preservation`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: `TabBarView` children StatefulWidget without `AutomaticKeepAliveClientMixin`
- **Quick-fix**: Add mixin and `wantKeepAlive => true`
- **Concerns**: Need to check widget inside TabBarView - complex traversal
- **Opportunities**: Also check PageView children

### 31. `require_loading_timeout`
- **Tier**: Essential
- **Severity**: WARNING
- **Detection**: Loading state without timeout/error handling after N seconds
- **Quick-fix**: Add `Future.delayed` with timeout error
- **Concerns**: Very hard to detect "loading state" generically
- **Opportunities**: May need to be package-specific (dio timeout, etc.)

### 32. `require_refresh_completion_feedback`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `RefreshIndicator.onRefresh` that completes without setState or data change
- **Quick-fix**: Add TODO comment about feedback
- **Concerns**: Hard to detect "no visible change"
- **Opportunities**: Could just check for setState/notifyListeners call

### 33. `require_infinite_scroll_end_indicator`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `ListView.builder` with scroll listener but no "end of list" widget
- **Quick-fix**: Add end-of-list item in builder
- **Concerns**: Complex pattern detection
- **Opportunities**: Check for common patterns like `hasMore` flag

### 34. `prefer_sliverfillremaining_for_empty`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: Empty state widget as `SliverToBoxAdapter` in `CustomScrollView`
- **Quick-fix**: Replace with `SliverFillRemaining(child: emptyWidget)`
- **Concerns**: Need to identify "empty state" pattern
- **Opportunities**: Check for common empty state widget names

### 35. `require_responsive_breakpoints`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `MediaQuery.of(context).size.width > 600` magic numbers
- **Quick-fix**: Extract to constant `kTabletBreakpoint`
- **Concerns**: Many valid breakpoint values
- **Opportunities**: Suggest `LayoutBuilder` instead

### 36. `require_animation_controller_dispose`
- **Tier**: Essential
- **Severity**: ERROR (memory leak)
- **Detection**: `AnimationController` field without `dispose()` call
- **Quick-fix**: Add `_controller.dispose();`
- **Concerns**: Same pattern as other dispose rules
- **Opportunities**: Most important dispose rule - prioritize

### 37. `require_text_editing_controller_dispose`
- **Tier**: Essential
- **Severity**: ERROR (memory leak)
- **Detection**: `TextEditingController` field without `dispose()` call
- **Quick-fix**: Add `_textController.dispose();`
- **Concerns**: Very common issue
- **Opportunities**: High value rule

### 38. `require_page_controller_dispose`
- **Tier**: Essential
- **Severity**: ERROR (memory leak)
- **Detection**: `PageController` field without `dispose()` call
- **Quick-fix**: Add `_pageController.dispose();`
- **Concerns**: Same pattern as others
- **Opportunities**: Bundle all controller dispose rules

### 39. `prefer_logger_over_print`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `print()` function calls
- **Quick-fix**: Replace with `log()` from dart:developer or suggest logger package
- **Concerns**: print is fine for quick debugging
- **Opportunities**: Different from `avoid_print_in_production` - this is style suggestion

### 40. `require_graphql_operation_names`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: GraphQL query/mutation string without operation name
- **Quick-fix**: Add operation name after query/mutation keyword
- **Concerns**: Need to parse GraphQL string literals
- **Opportunities**: Helps with debugging and caching

### 41. `require_qr_permission_check`
- **Tier**: Essential
- **Severity**: ERROR
- **Detection**: `QRView` or `MobileScanner` without `Permission.camera` check
- **Quick-fix**: Add permission check with `permission_handler`
- **Concerns**: Permission handling varies by package
- **Opportunities**: Critical for app store compliance

### 42. `avoid_qr_scanner_always_active`
- **Tier**: Professional
- **Severity**: INFO (battery)
- **Detection**: `QRView` without `controller.pauseCamera()` in lifecycle
- **Quick-fix**: Add pause in `didChangeAppLifecycleState`
- **Concerns**: Different QR packages have different APIs
- **Opportunities**: Check `qr_code_scanner`, `mobile_scanner`

### 43. `require_bluetooth_state_check`
- **Tier**: Essential
- **Severity**: WARNING
- **Detection**: BLE operations without checking adapter state
- **Quick-fix**: Add `FlutterBluePlus.adapterState.listen` check
- **Concerns**: Package-specific APIs
- **Opportunities**: Critical for Bluetooth apps

### 44. `require_ble_disconnect_handling`
- **Tier**: Essential
- **Severity**: WARNING
- **Detection**: BLE connection without disconnect listener
- **Quick-fix**: Add `device.connectionState.listen` for disconnect
- **Concerns**: Package-specific
- **Opportunities**: Common BLE bug

### 45. `require_audio_focus_handling`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: Audio playback without `AudioSession` configuration
- **Quick-fix**: Add `AudioSession.instance` setup
- **Concerns**: Only needed for background/concurrent audio
- **Opportunities**: Check `just_audio`, `audioplayers`

### 46. `require_lifecycle_observer`
- **Tier**: Essential
- **Severity**: WARNING
- **Detection**: `Timer.periodic` or long-running stream without `WidgetsBindingObserver`
- **Quick-fix**: Add mixin and pause in `didChangeAppLifecycleState`
- **Concerns**: Complex to detect "long-running" operations
- **Opportunities**: Focus on Timer.periodic first

### 47. `avoid_image_rebuild_on_scroll`
- **Tier**: Professional
- **Severity**: WARNING (performance)
- **Detection**: `Image.network` inside `ListView.builder` without caching
- **Quick-fix**: Replace with `CachedNetworkImage`
- **Concerns**: Need to detect ListView ancestor
- **Opportunities**: Big performance win

### 48. `require_avatar_fallback`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: `CircleAvatar` with `backgroundImage` from network without error handling
- **Quick-fix**: Add `onBackgroundImageError` or wrap with fallback
- **Concerns**: `backgroundImage` doesn't have errorBuilder like Image
- **Opportunities**: Suggest using Image inside CircleAvatar instead

### 49. `avoid_loading_flash`
- **Tier**: Professional
- **Severity**: INFO
- **Detection**: Loading indicator shown immediately without delay
- **Quick-fix**: Add `Future.delayed(Duration(milliseconds: 150))` guard
- **Concerns**: Hard to detect "loading indicator" generically
- **Opportunities**: Check for CircularProgressIndicator with no delay

### 50. `require_loading_state_distinction`
- **Tier**: Recommended
- **Severity**: INFO
- **Detection**: Same loading widget for initial load vs refresh
- **Quick-fix**: Add TODO to distinguish loading states
- **Concerns**: Very hard to detect automatically
- **Opportunities**: May be too complex - consider dropping

---

## Summary & Prioritization

### High Priority (Essential, ERROR severity)
1. #13 `require_scroll_controller_dispose`
2. #14 `require_focus_node_dispose`
3. #36 `require_animation_controller_dispose`
4. #37 `require_text_editing_controller_dispose`
5. #38 `require_page_controller_dispose`
6. #41 `require_qr_permission_check`

### Medium Priority (Essential/Recommended, WARNING)
7. #2 `require_image_error_fallback`
8. #4 `require_avatar_alt_text`
9. #9 `avoid_bluetooth_scan_without_timeout`
10. #18 `avoid_datetime_now_in_tests`
11. #25 `require_graphql_error_handling`
12. #43 `require_bluetooth_state_check`
13. #44 `require_ble_disconnect_handling`
14. #46 `require_lifecycle_observer`
15. #47 `avoid_image_rebuild_on_scroll`

### Lower Priority (INFO severity)
Remaining 35 rules

### Consider Dropping (Too Complex)
- #31 `require_loading_timeout` - hard to detect generically
- #32 `require_refresh_completion_feedback` - hard to detect "no change"
- #33 `require_infinite_scroll_end_indicator` - complex pattern
- #50 `require_loading_state_distinction` - too abstract

### Implementation Order Recommendation
1. All dispose rules first (#13, 14, 36, 37, 38) - same pattern, high value
2. Image rules (#1, 2, 3, 19, 47) - same widget, related
3. Accessibility rules (#4, 10) - related concern
4. DateTime/Duration rules (#15, 18) - simple detection
5. Dialog/Snackbar rules (#5, 6, 28, 29) - UI feedback patterns
6. Bluetooth/QR rules (#9, 41, 42, 43, 44) - device hardware
7. Remaining by priority
