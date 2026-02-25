// Test fixture for v5.1.0 lint rules
// ignore_for_file: unused_local_variable, unused_element, prefer_const_declarations
// ignore_for_file: avoid_print_in_release, prefer_no_commented_out_code
// ignore_for_file: unused_import, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, avoid_returning_null_for_void
// ignore_for_file: avoid_image_rebuild_on_scroll, avoid_large_objects_in_state
// ignore_for_file: require_dispose, avoid_undisposed_instances

import 'flutter_mocks.dart';

// =============================================================================
// avoid_cached_image_web
// =============================================================================

// BAD: CachedNetworkImage inside kIsWeb true branch
Widget badCachedImageWeb() {
  if (kIsWeb) {
    // expect_lint: avoid_cached_image_web
    return CachedNetworkImage(imageUrl: 'https://example.com/image.png');
  }

  return CachedNetworkImage(imageUrl: 'https://example.com/image.png');
}

// BAD: Negated form — CachedNetworkImage in else branch of !kIsWeb
Widget badCachedImageWebNegated() {
  if (!kIsWeb) {
    return Container();
  } else {
    // expect_lint: avoid_cached_image_web
    return CachedNetworkImage(imageUrl: 'https://example.com/image.png');
  }
}

// GOOD: CachedNetworkImage outside kIsWeb branch
Widget goodCachedImageMobile() {
  return CachedNetworkImage(imageUrl: 'https://example.com/image.png');
}

// GOOD: Image.network inside kIsWeb branch
Widget goodImageNetworkWeb() {
  if (kIsWeb) {
    return Image(image: NetworkImage('https://example.com/image.png'));
  }

  return CachedNetworkImage(imageUrl: 'https://example.com/image.png');
}

// FALSE POSITIVE: CachedNetworkImage in else branch (not web)
Widget fpCachedImageElse() {
  if (kIsWeb) {
    return Container();
  } else {
    return CachedNetworkImage(imageUrl: 'https://example.com/image.png');
  }
}

// =============================================================================
// avoid_clip_during_animation
// =============================================================================

// BAD: ClipRRect inside AnimatedContainer
Widget badClipInAnimation() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    // expect_lint: avoid_clip_during_animation
    child: ClipRRect(child: Container()),
  );
}

// BAD: ClipOval inside FadeTransition
Widget badClipOvalInFade() {
  return FadeTransition(
    opacity: AlwaysStoppedAnimation(1.0),
    // expect_lint: avoid_clip_during_animation
    child: ClipOval(child: Container()),
  );
}

// GOOD: ClipRRect outside animated widget
Widget goodClipOutsideAnimation() {
  return ClipRRect(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Container(),
    ),
  );
}

// GOOD: ClipRRect with no animated ancestor
Widget goodClipAlone() {
  return ClipRRect(child: Container());
}

// FALSE POSITIVE: Clip in non-animated Container
Widget fpClipInContainer() {
  return Container(child: ClipRRect(child: Container()));
}

// =============================================================================
// avoid_auto_route_context_navigation (requires auto_route import pattern)
// =============================================================================
// Note: These rules use requiredPatterns: ['auto_route'] so they only fire
// in files that reference auto_route. Test separately if needed.

// =============================================================================
// avoid_accessing_other_classes_private_members
// =============================================================================

class _SecretKeeper {
  final int _secret = 42;
  int get secret => _secret;
}

class _PeekingClass {
  void badPeek(_SecretKeeper keeper) {
    // expect_lint: avoid_accessing_other_classes_private_members
    print(keeper._secret);
  }

  void goodPeek(_SecretKeeper keeper) {
    print(keeper.secret);
  }
}

// FALSE POSITIVE: Accessing own class private member
class _SelfAccess {
  final int _myField = 10;

  void accessOwn(_SelfAccess other) {
    // OK: Same class, should not trigger
    print(other._myField);
  }
}

// =============================================================================
// avoid_closure_capture_leaks
// =============================================================================

class _BadTimerState extends State<_BadTimerWidget> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (_) {
      // expect_lint: avoid_closure_capture_leaks
      setState(() {
        _counter++;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _BadTimerWidget extends StatefulWidget {
  const _BadTimerWidget();

  @override
  State<_BadTimerWidget> createState() => _BadTimerState();
}

class _GoodTimerState extends State<_GoodTimerWidget> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _counter++;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _GoodTimerWidget extends StatefulWidget {
  const _GoodTimerWidget();

  @override
  State<_GoodTimerWidget> createState() => _GoodTimerState();
}

// FALSE POSITIVE: setState not in Timer callback
class _DirectSetState extends State<_DirectSetStateWidget> {
  void handleTap() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _DirectSetStateWidget extends StatefulWidget {
  const _DirectSetStateWidget();

  @override
  State<_DirectSetStateWidget> createState() => _DirectSetState();
}

// =============================================================================
// avoid_behavior_subject_last_value
// =============================================================================

// BAD: Accessing .value inside isClosed true branch
String badBehaviorSubjectValue() {
  final subject = BehaviorSubject<String>(seedValue: 'hello');
  if (subject.isClosed) {
    // expect_lint: avoid_behavior_subject_last_value
    return subject.value;
  }

  return subject.value;
}

// GOOD: Accessing .value with negated isClosed check
String goodBehaviorSubjectValue() {
  final subject = BehaviorSubject<String>(seedValue: 'hello');
  if (!subject.isClosed) {
    return subject.value;
  }

  return 'fallback';
}

// FALSE POSITIVE: .value access without isClosed context
String fpBehaviorSubjectNoCheck() {
  final subject = BehaviorSubject<String>(seedValue: 'hello');
  return subject.value;
}

// =============================================================================
// avoid_cache_stampede
// =============================================================================

class _BadCacheService {
  final Map<String, String> _cache = {};

  // expect_lint: avoid_cache_stampede
  Future<String> getData(String id) async {
    if (_cache.containsKey(id)) return _cache[id]!;
    final data = await _fetchFromApi(id);
    _cache[id] = data;
    return data;
  }

  Future<String> _fetchFromApi(String id) async => 'data_$id';
}

class _GoodCacheService {
  final Map<String, String> _cache = {};
  final Map<String, Future<String>> _inFlight = {};

  Future<String> getData(String id) async {
    return _cache[id] ??
        await (_inFlight[id] ??= _fetchFromApi(id).then((data) {
          _cache[id] = data;
          _inFlight.remove(id);
          return data;
        }));
  }

  Future<String> _fetchFromApi(String id) async => 'data_$id';
}

// FALSE POSITIVE: Synchronous cache access (no await)
class _SyncCacheService {
  final Map<String, String> _cache = {};

  String? getData(String id) {
    if (_cache.containsKey(id)) return _cache[id]!;
    return null;
  }
}
