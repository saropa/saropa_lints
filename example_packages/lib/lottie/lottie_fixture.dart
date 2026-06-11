// ignore_for_file: unused_local_variable, unused_element

/// Fixture for all 5 lottie lint rules.
///
/// BAD examples are annotated with `// expect_lint: <rule_name>`.
/// GOOD examples must NOT trigger any lottie rules.
/// The `Image.network` call at the bottom confirms the receiver guard works
/// (same method name 'network', but NOT a Lottie receiver).
library;

import 'package:lottie/lottie.dart';

// ─── Mock stubs ────────────────────────────────────────────────────────────
// Minimal stubs so the fixture compiles without the real lottie package
// in the example_packages analysis context. In real usage the lottie package
// resolves these types.

// ignore: avoid_classes_with_only_static_members
class _MockAnimationController {
  Duration duration = Duration.zero;
  void forward() {}
  void dispose() {}
}

final _controller = _MockAnimationController();

// ─── lottie_controller_missing_on_loaded ───────────────────────────────────

void badControllerNoOnLoaded() {
  // BAD: controller: present, onLoaded: absent → animation frozen at frame 0.
  Lottie.asset(
    'assets/anim.json',
    // expect_lint: lottie_controller_missing_on_loaded
    controller: _controller,
  );
}

void goodControllerWithOnLoaded() {
  // GOOD: both controller: and onLoaded: present.
  Lottie.asset(
    'assets/anim.json',
    controller: _controller,
    onLoaded: (composition) {
      _controller.duration = composition.duration;
      _controller.forward();
    },
  );
}

void goodNoController() {
  // GOOD: no controller: → package self-manages, onLoaded: is optional.
  Lottie.asset('assets/anim.json');
}

// ─── lottie_network_missing_error_builder ─────────────────────────────────

void badNetworkNoErrorBuilder() {
  // BAD: Lottie.network without errorBuilder: → blank widget on failure.
  // expect_lint: lottie_network_missing_error_builder
  Lottie.network('https://example.com/anim.json');
}

void goodNetworkWithErrorBuilder() {
  // GOOD: errorBuilder: present → failure shows a fallback.
  Lottie.network(
    'https://example.com/anim.json',
    errorBuilder: (context, error, stackTrace) {
      return const _FallbackWidget();
    },
  );
}

// ─── lottie_frame_rate_max_without_render_cache ───────────────────────────

void badFrameRateMaxNoRenderCache() {
  // BAD: FrameRate.max without renderCache: → 4× repaint cost on 120 Hz.
  Lottie.asset(
    'assets/anim.json',
    // expect_lint: lottie_frame_rate_max_without_render_cache
    frameRate: FrameRate.max,
  );
}

void goodFrameRateMaxWithRenderCache() {
  // GOOD: FrameRate.max paired with renderCache: → developer is aware.
  Lottie.asset(
    'assets/anim.json',
    frameRate: FrameRate.max,
    renderCache: RenderCache.drawingCommands,
  );
}

void goodFrameRateComposition() {
  // GOOD: FrameRate.composition (default) → no extra repaint cost.
  Lottie.asset('assets/anim.json', frameRate: FrameRate.composition);
}

// ─── lottie_render_cache_raster_large_risk ────────────────────────────────

void badRenderCacheRaster() {
  // BAD: RenderCache.raster risks high memory use (API doc warns against it
  // for anything but very small/short animations).
  Lottie.asset(
    'assets/anim.json',
    // expect_lint: lottie_render_cache_raster_large_risk
    renderCache: RenderCache.raster,
  );
}

void goodRenderCacheDrawingCommands() {
  // GOOD: drawingCommands is the lower-risk alternative.
  Lottie.asset('assets/anim.json', renderCache: RenderCache.drawingCommands);
}

// ─── lottie_network_missing_background_loading ────────────────────────────

void badNetworkNoBackgroundLoading() {
  // BAD: backgroundLoading: absent → JSON parsed on UI thread.
  // expect_lint: lottie_network_missing_background_loading
  Lottie.network('https://example.com/anim.json', errorBuilder: _eb);
}

void badNetworkBackgroundLoadingFalse() {
  // BAD: explicit false is as bad as omitting it.
  Lottie.network(
    'https://example.com/anim.json',
    errorBuilder: _eb,
    // expect_lint: lottie_network_missing_background_loading
    backgroundLoading: false,
  );
}

void goodNetworkWithBackgroundLoading() {
  // GOOD: backgroundLoading: true → JSON parsed on background isolate.
  Lottie.network(
    'https://example.com/anim.json',
    errorBuilder: _eb,
    backgroundLoading: true,
  );
}

// ─── Receiver-guard proof: Image.network must NOT trigger lottie rules ─────

// This import uses a stub class defined below; the real flutter/widgets import
// is avoided to keep the fixture self-contained.
void proofImageNetworkDoesNotTrigger() {
  // This call has method name 'network' on a non-Lottie receiver.
  // None of the lottie rules should fire here.
  _MockImage.network('https://example.com/photo.jpg');
}

// ─── Helpers ───────────────────────────────────────────────────────────────

Widget _eb(Object context, Object error, Object? stackTrace) =>
    const _FallbackWidget();

class _FallbackWidget {
  const _FallbackWidget();
}

/// Stub that proves `Image.network` does not match the Lottie import guard.
// ignore: avoid_classes_with_only_static_members
class _MockImage {
  static Object network(String url) => url;
}
