// Test fixture for v4.15.0 ROADMAP ⭐ rules
// ignore_for_file: unused_local_variable, unused_element, prefer_const_declarations
// ignore_for_file: avoid_print_in_release, prefer_no_commented_out_code
// ignore_for_file: unused_import, depend_on_referenced_packages

import 'flutter_mocks.dart';

// =============================================================================
// avoid_ignoring_return_values
// =============================================================================

// BAD: Return value of map() is ignored
void badIgnoreReturn() {
  final list = [1, 2, 3];
  // expect_lint: avoid_ignoring_return_values
  list.map((e) => e * 2);
}

// BAD: Return value of int.parse() is ignored
void badIgnoreParse() {
  // expect_lint: avoid_ignoring_return_values
  int.parse('42');
}

// GOOD: Return value is assigned
void goodReturnUsed() {
  final list = [1, 2, 3];
  final doubled = list.map((e) => e * 2).toList();
  final value = int.parse('42');
  print('$doubled $value');
}

// FALSE POSITIVE: void methods should not trigger
void fpVoidReturn() {
  print('hello');
  final list = <int>[];
  list.add(1);
  list.clear();
}

// FALSE POSITIVE: cascade expressions should not trigger
void fpCascade() {
  final sb = StringBuffer();
  sb
    ..write('a')
    ..write('b');
}

// =============================================================================
// prefer_optimistic_updates
// =============================================================================

// BAD: setState after await
// class BadOptimistic extends StatefulWidget {
//   Future<void> _onLike() async {
//     await api.likePost(postId);
//     setState(() { isLiked = true; }); // User waits for network
//   }
// }

// GOOD: setState before await with rollback
// class GoodOptimistic extends StatefulWidget {
//   Future<void> _onLike() async {
//     setState(() { isLiked = true; }); // Immediate feedback
//     try {
//       await api.likePost(postId);
//     } catch (_) {
//       setState(() { isLiked = false; }); // Rollback on failure
//     }
//   }
// }

// FALSE POSITIVE: setState in sync method (no await)
// class FpOptimistic extends StatefulWidget {
//   void _toggle() {
//     setState(() { isLiked = !isLiked; });
//   }
// }

// =============================================================================
// avoid_full_sync_on_every_launch
// =============================================================================

// BAD: Bulk fetch in initState
// class BadFullSync extends StatefulWidget {
//   @override
//   void initState() {
//     super.initState();
//     database.getAll(); // Downloads everything on launch
//   }
// }

// GOOD: Delta sync in initState
// class GoodFullSync extends StatefulWidget {
//   @override
//   void initState() {
//     super.initState();
//     syncService.syncSince(lastSyncTimestamp);
//   }
// }

// FALSE POSITIVE: getAll outside initState
// class FpFullSync extends StatefulWidget {
//   void _refreshAll() {
//     database.getAll(); // Explicit user action, OK
//   }
// }

// =============================================================================
// avoid_cached_image_unbounded_list
// =============================================================================

// BAD: CachedNetworkImage in ListView.builder without cache bounds
// Widget badCachedList(List<String> urls) => ListView.builder(
//   itemBuilder: (context, index) => CachedNetworkImage(
//     imageUrl: urls[index],
//   ),
// );

// GOOD: CachedNetworkImage with memCacheWidth
// Widget goodCachedList(List<String> urls) => ListView.builder(
//   itemBuilder: (context, index) => CachedNetworkImage(
//     imageUrl: urls[index],
//     memCacheWidth: 200,
//     memCacheHeight: 200,
//   ),
// );

// FALSE POSITIVE: CachedNetworkImage outside list builder
// Widget fpCachedSingle() => CachedNetworkImage(
//   imageUrl: 'https://example.com/img.png',
// );

// =============================================================================
// require_session_timeout
// =============================================================================

// BAD: signIn without session timeout
// Future<void> badSession() async {
//   await FirebaseAuth.instance.signInWithEmailAndPassword(
//     email: email, password: password,
//   );
//   // No session timeout configured
// }

// GOOD: signIn with session timer
// Future<void> goodSession() async {
//   await FirebaseAuth.instance.signInWithEmailAndPassword(
//     email: email, password: password,
//   );
//   _sessionTimer = Timer(sessionTimeout, _handleSessionExpiry);
// }

// FALSE POSITIVE: non-signIn method that starts with 'sign'
// void fpSession() {
//   signalReady(); // Not a sign-in method
// }

// =============================================================================
// prefer_semantics_container
// =============================================================================

// BAD: Semantics wraps Column without container: true
// expect_lint: prefer_semantics_container
Widget badSemantics() => Semantics(
      label: 'User info',
      child: Column(children: []),
    );

// GOOD: Has container: true
Widget goodSemantics() => Semantics(
      container: true,
      label: 'User info',
      child: Column(children: []),
    );

// FALSE POSITIVE: Semantics with non-group child (Text)
Widget fpSemantics() => Semantics(
      label: 'Title',
      child: Text('Hello'),
    );

// =============================================================================
// avoid_redundant_semantics
// =============================================================================

// BAD: Semantics wrapping Image with semanticLabel
// expect_lint: avoid_redundant_semantics
Widget badRedundant() => Semantics(
      label: 'Logo',
      child: Image.asset('logo.png', semanticLabel: 'Logo'),
    );

// GOOD: Image with semanticLabel only (no Semantics wrapper)
Widget goodRedundant() => Image.asset('logo.png', semanticLabel: 'Logo');

// FALSE POSITIVE: Semantics wrapping Image WITHOUT semanticLabel
Widget fpRedundant() => Semantics(
      label: 'Logo',
      child: Image.asset('logo.png'),
    );

// =============================================================================
// avoid_image_picker_quick_succession
// =============================================================================

// BAD: pickImage without guard
// void badPicker(ImagePicker picker) async {
//   final image = await picker.pickImage(source: ImageSource.gallery);
// }

// GOOD: pickImage with isPicking guard
// void goodPicker(ImagePicker picker) async {
//   if (_isPicking) return;
//   _isPicking = true;
//   try {
//     final image = await picker.pickImage(source: ImageSource.gallery);
//   } finally {
//     _isPicking = false;
//   }
// }
// bool _isPicking = false;

// FALSE POSITIVE: pickImage on non-ImagePicker target
// void fpPicker() async {
//   final myService = MyService();
//   myService.pickImage();
// }

// =============================================================================
// require_analytics_error_handling
// =============================================================================

// BAD: analytics call without try-catch
// void badAnalytics(FirebaseAnalytics analytics) async {
//   await analytics.logEvent(name: 'purchase');
// }

// GOOD: analytics call with try-catch
// void goodAnalytics(FirebaseAnalytics analytics) async {
//   try {
//     await analytics.logEvent(name: 'purchase');
//   } catch (e) {
//     // Silent failure
//   }
// }

// FALSE POSITIVE: logEvent on non-analytics target
// void fpAnalytics() {
//   final logger = MyLogger();
//   logger.logEvent('test');
// }

// =============================================================================
// prefer_input_formatters
// =============================================================================

// BAD: phone keyboard without inputFormatters
// Widget badField() => TextField(
//   keyboardType: TextInputType.phone,
// );

// GOOD: phone keyboard with inputFormatters
// Widget goodField() => TextField(
//   keyboardType: TextInputType.phone,
//   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
// );

// FALSE POSITIVE: text keyboard (no formatters needed)
// Widget fpField() => TextField(
//   keyboardType: TextInputType.text,
// );

// =============================================================================
// prefer_go_router_redirect
// =============================================================================

// BAD: GoRouter without redirect
// final badRouter = GoRouter(
//   routes: [GoRoute(path: '/', builder: (_, __) => HomeScreen())],
// );

// GOOD: GoRouter with redirect
// final goodRouter = GoRouter(
//   redirect: (context, state) => null,
//   routes: [GoRoute(path: '/', builder: (_, __) => HomeScreen())],
// );

// FALSE POSITIVE: Non-GoRouter class with similar name
// final myRouter = AppRouter(routes: []);

// =============================================================================
// prefer_permission_request_in_context
// =============================================================================

// BAD: permission request in initState
// void initState() async {
//   super.initState();
//   await Permission.camera.request();
// }

// GOOD: permission request in user action
// void onTakePhotoPressed() async {
//   await Permission.camera.request();
// }

// FALSE POSITIVE: non-Permission .request() call
// void fpPermission() async {
//   await httpClient.request('GET', '/api/data');
// }

// =============================================================================
// avoid_shared_prefs_large_data
// =============================================================================

// BAD: setString with jsonEncode
// void badPrefs(SharedPreferences prefs) async {
//   await prefs.setString('user', jsonEncode(userData));
// }

// GOOD: simple string value
// void goodPrefs(SharedPreferences prefs) async {
//   await prefs.setString('theme', 'dark');
// }

// FALSE POSITIVE: setString on non-prefs target
// void fpPrefs() async {
//   await myStorage.setString('data', jsonEncode(obj));
// }

// =============================================================================
// prefer_geocoding_cache
// =============================================================================

// BAD: reverse geocoding without cache
// void badGeocode() async {
//   final placemarks = await placemarkFromCoordinates(lat, lng);
// }

// GOOD: reverse geocoding with cache
// void goodGeocode() async {
//   final cached = _geocodeCache[key];
//   if (cached != null) return cached;
//   final placemarks = await placemarkFromCoordinates(lat, lng);
// }

// FALSE POSITIVE: unrelated method with similar name
// void fpGeocode() {
//   getAddressFromDatabase(id);
// }

// =============================================================================
// prefer_oauth_pkce
// =============================================================================

// BAD: OAuth request without PKCE
// final badOAuth = AuthorizationTokenRequest('clientId', 'redirect');

// GOOD: OAuth request with codeVerifier
// final goodOAuth = AuthorizationTokenRequest(
//   'clientId', 'redirect', codeVerifier: generateVerifier(),
// );

// FALSE POSITIVE: non-OAuth class with similar name
// final fpAuth = AuthorizationConfig('clientId');

// =============================================================================
// avoid_continuous_location_updates
// =============================================================================

// BAD: getPositionStream without distance filter
// void badLocation() {
//   Geolocator.getPositionStream().listen((pos) {});
// }

// GOOD: getPositionStream with locationSettings
// void goodLocation() {
//   Geolocator.getPositionStream(
//     locationSettings: LocationSettings(distanceFilter: 100),
//   ).listen((pos) {});
// }

// FALSE POSITIVE: non-location stream method
// void fpLocation() {
//   myService.getPositionStream().listen((pos) {});
// }

// =============================================================================
// prefer_adaptive_icons
// =============================================================================

// BAD: Icon with hardcoded size
// Widget badIcon() => Icon(Icons.add, size: 32);

// GOOD: Icon without size (uses IconTheme)
// Widget goodIcon() => Icon(Icons.add);

// GOOD: Icon with variable size
// Widget goodIconVar(double s) => Icon(Icons.add, size: s);

// FALSE POSITIVE: non-Icon widget with size
// Widget fpIcon() => Container(width: 32, height: 32);

// =============================================================================
// prefer_grace_period_handling
// =============================================================================

// BAD: only checks PurchaseStatus.purchased
// void badPurchase(PurchaseDetails details) {
//   if (details.status == PurchaseStatus.purchased) {
//     grantAccess();
//   }
// }

// GOOD: also handles pending
// void goodPurchase(PurchaseDetails details) {
//   if (details.status == PurchaseStatus.purchased ||
//       details.status == PurchaseStatus.pending) {
//     grantAccess();
//   }
// }

// FALSE POSITIVE: non-IAP status check
// void fpPurchase() {
//   if (order.status == OrderStatus.purchased) {}
// }

// =============================================================================
// require_cached_image_device_pixel_ratio
// =============================================================================

// BAD: CachedNetworkImage with fixed dimensions
// Widget badCached() => CachedNetworkImage(
//   imageUrl: 'https://example.com/img.png',
//   width: 200,
//   height: 200,
// );

// GOOD: CachedNetworkImage with DPR scaling
// Widget goodCached(BuildContext context) {
//   final dpr = MediaQuery.of(context).devicePixelRatio;
//   return CachedNetworkImage(
//     imageUrl: 'https://example.com/img.png',
//     memCacheWidth: (200 * dpr).toInt(),
//   );
// }

// FALSE POSITIVE: CachedNetworkImage without fixed size
// Widget fpCached() => CachedNetworkImage(
//   imageUrl: 'https://example.com/img.png',
// );

// =============================================================================
// prefer_foreground_service_android
// =============================================================================

// BAD: Timer.periodic without foreground service
// void badTimer() {
//   Timer.periodic(Duration(seconds: 30), (_) {
//     uploadData();
//   });
// }

// GOOD: Timer.periodic with ForegroundTask
// void goodTimer() {
//   FlutterForegroundTask.startService();
//   Timer.periodic(Duration(seconds: 30), (_) {
//     uploadData();
//   });
// }

// FALSE POSITIVE: non-Timer periodic
// void fpTimer() {
//   stream.periodic(Duration(seconds: 1));
// }

// =============================================================================
// prefer_sliverfillremaining_for_empty
// =============================================================================

// BAD: SliverToBoxAdapter for empty state
// Widget badSliver() => CustomScrollView(
//   slivers: [
//     SliverToBoxAdapter(child: Center(child: Text('No items'))),
//   ],
// );

// GOOD: SliverFillRemaining for empty state
// Widget goodSliver() => CustomScrollView(
//   slivers: [
//     SliverFillRemaining(child: Center(child: Text('No items'))),
//   ],
// );

// FALSE POSITIVE: SliverToBoxAdapter with non-empty content
// Widget fpSliver() => CustomScrollView(
//   slivers: [
//     SliverToBoxAdapter(child: Header()),
//   ],
// );

// =============================================================================
// avoid_infinite_scroll_duplicate_requests
// =============================================================================

// BAD: scroll listener without loading guard
// void badScroll() {
//   _scrollController.addListener(() {
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent) {
//       loadNextPage();
//     }
//   });
// }

// GOOD: scroll listener with loading guard
// void goodScroll() {
//   _scrollController.addListener(() {
//     if (!_isLoading &&
//         _scrollController.position.pixels >=
//             _scrollController.position.maxScrollExtent) {
//       loadNextPage();
//     }
//   });
// }

// FALSE POSITIVE: addListener on non-scroll controller
// void fpScroll() {
//   _textController.addListener(() {
//     print(_textController.text);
//   });
// }

// =============================================================================
// prefer_infinite_scroll_preload
// =============================================================================

// BAD: exact equality with maxScrollExtent
// void badPreload() {
//   controller.addListener(() {
//     if (controller.position.pixels == controller.position.maxScrollExtent) {
//       loadMore();
//     }
//   });
// }

// GOOD: threshold-based preloading
// void goodPreload() {
//   controller.addListener(() {
//     if (controller.position.pixels >=
//         controller.position.maxScrollExtent * 0.8) {
//       loadMore();
//     }
//   });
// }

// =============================================================================
// prefer_use_callback
// =============================================================================

// BAD: inline closure in HookWidget
// class BadHookWidget extends HookWidget {
//   Widget build(BuildContext context) {
//     return ElevatedButton(
//       onPressed: () { doSomething(); },
//       child: Text('Click'),
//     );
//   }
// }

// GOOD: useCallback in HookWidget
// class GoodHookWidget extends HookWidget {
//   Widget build(BuildContext context) {
//     final onPressed = useCallback(() { doSomething(); }, []);
//     return ElevatedButton(
//       onPressed: onPressed,
//       child: Text('Click'),
//     );
//   }
// }

// FALSE POSITIVE: inline closure in non-HookWidget
// class FpWidget extends StatelessWidget {
//   Widget build(BuildContext context) {
//     return ElevatedButton(
//       onPressed: () { doSomething(); },
//       child: Text('Click'),
//     );
//   }
// }

// =============================================================================
// require_stepper_state_management
// =============================================================================

// BAD: Stepper with TextField but no state management
// Widget badStepper() => Stepper(
//   steps: [
//     Step(title: Text('Name'), content: TextField()),
//     Step(title: Text('Address'), content: TextField()),
//   ],
// );

// GOOD: Stepper with controller
// Widget goodStepper() => Stepper(
//   steps: [
//     Step(
//       title: Text('Name'),
//       content: TextField(controller: _nameController),
//     ),
//   ],
// );

// FALSE POSITIVE: Stepper without form inputs
// Widget fpStepper() => Stepper(
//   steps: [
//     Step(title: Text('Review'), content: Text('Summary')),
//   ],
// );
