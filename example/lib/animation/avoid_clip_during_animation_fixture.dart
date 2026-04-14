// ignore_for_file: unused_local_variable, unused_element
// Fixture for avoid_clip_during_animation.
// BAD: Clip inside animated widget causes expensive rasterization every frame.
// GOOD: Clip outside animated scope or use BoxDecoration.borderRadius.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: ClipRRect inside AnimatedContainer — should trigger avoid_clip_during_animation
// LINT
Widget badClipInsideAnimation() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: const SizedBox(),
    ),
  );
}

// GOOD: Clip outside animated widget
Widget goodClipOutside() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: const SizedBox(),
    ),
  );
}
