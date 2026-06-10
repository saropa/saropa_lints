// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_dispose_before_new_instance` lint rule.
///
/// The rule fires when a disposable field is reassigned without disposing the
/// previous instance. It must NOT fire when the old instance is disposed —
/// including the deferred idiom where the old value is captured into a local
/// and disposed inside an addPostFrameCallback/microtask closure (disposing
/// inline asserts while the controller is still attached to a mounted widget).

class _State {
  PageController? _pageController;

  // GOOD: inline dispose before reassignment.
  void replaceInline(double f) {
    _pageController?.dispose();
    _pageController = PageController(viewportFraction: f);
  }

  // GOOD: capture old value, reassign, dispose old in a post-frame callback.
  void replaceDeferred(double f) {
    final PageController? old = _pageController;
    _pageController = PageController(viewportFraction: f);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  // GOOD: microtask variant of the capture-and-dispose idiom.
  void replaceMicrotask(double f) {
    final PageController? old = _pageController;
    _pageController = PageController(viewportFraction: f);
    Future.microtask(() => old?.dispose());
  }

  // BAD: reassigned with no capture, no inline dispose, no deferred dispose.
  // expect_lint: prefer_dispose_before_new_instance
  void leak(double f) {
    _pageController = PageController(viewportFraction: f);
  }
}

void main() {}
