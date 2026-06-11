// ignore_for_file: unused_local_variable, unused_element, unused_field

/// Fixture for the three receive_sharing_intent lint rules.
///
/// Rules covered:
///   - `rsi_missing_initial_media` (WARNING)
///   - `rsi_missing_reset_after_initial_media` (WARNING)
///   - `rsi_unfiltered_shared_media_type` (INFO)
library;

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// =============================================================================
// Minimal stubs — reproduce the package surface the rules reason about without
// requiring the real package to be present in the example_packages pubspec.
// =============================================================================

// ignore: avoid_classes_with_only_static_members
class ReceiveSharingIntent {
  static final ReceiveSharingIntent instance = ReceiveSharingIntent._();
  ReceiveSharingIntent._();

  Stream<List<SharedMediaFile>> getMediaStream() => const Stream.empty();
  Future<List<SharedMediaFile>> getInitialMedia() async => [];
  void reset() {}
}

class SharedMediaFile {
  const SharedMediaFile({
    required this.path,
    this.thumbnail,
    this.duration,
    this.mimeType,
    required this.type,
  });
  final String path;
  final String? thumbnail;
  final int? duration;
  final String? mimeType;
  final SharedMediaType type;
}

enum SharedMediaType { image, video, file, text, url }

// =============================================================================
// rsi_missing_initial_media — BAD: getMediaStream() called, no getInitialMedia()
// =============================================================================

void badMissingInitialMedia() {
  // expect_lint: rsi_missing_initial_media
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    for (final file in files) {
      _process(file.path);
    }
  });
  // getInitialMedia() is never called — cold-start shares silently dropped.
}

// =============================================================================
// rsi_missing_initial_media — GOOD: both paths wired in the same file
// =============================================================================

void goodBothPathsWired() {
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    for (final file in files) {
      _process(file.path);
    }
  });
  // getInitialMedia() also wired — compliant.
  ReceiveSharingIntent.instance.getInitialMedia().then((files) {
    for (final file in files) {
      _process(file.path);
    }
  });
}

// =============================================================================
// rsi_missing_reset_after_initial_media — BAD: getInitialMedia() with no reset()
// =============================================================================

class BadNoResetClass {
  void init() {
    // expect_lint: rsi_missing_reset_after_initial_media
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _processAll(files);
      // reset() never called — stale intent re-delivered on next resume.
    });
  }

  void _processAll(List<SharedMediaFile> files) {}
}

// =============================================================================
// rsi_missing_reset_after_initial_media — GOOD: reset() present in class
// =============================================================================

class GoodResetsAfterInitialMedia {
  void init() {
    // reset() is called inside the then() callback — compliant.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _processAll(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _processAll(List<SharedMediaFile> files) {}
}

// =============================================================================
// rsi_unfiltered_shared_media_type — BAD: .path accessed, SharedMediaType absent
// =============================================================================

void badUnfilteredMediaType() {
  // expect_lint: rsi_unfiltered_shared_media_type
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    for (final file in files) {
      // .path accessed without any SharedMediaType check.
      _process(file.path);
    }
  });
}

void badUnfilteredInitialMedia() {
  ReceiveSharingIntent.instance.getInitialMedia().then(
    // expect_lint: rsi_unfiltered_shared_media_type
    (files) {
      for (final file in files) {
        // .mimeType accessed but no SharedMediaType reference.
        print(file.mimeType);
      }
    },
  );
}

// =============================================================================
// rsi_unfiltered_shared_media_type — GOOD: SharedMediaType referenced in callback
// =============================================================================

void goodFilteredByType() {
  // SharedMediaType.image is referenced in the callback — compliant.
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    for (final file in files) {
      if (file.type == SharedMediaType.image) {
        _process(file.path);
      }
    }
  });
}

void goodFilteredInitialMedia() {
  ReceiveSharingIntent.instance.getInitialMedia().then((files) {
    for (final file in files) {
      // SharedMediaType checked via switch — compliant.
      switch (file.type) {
        case SharedMediaType.image:
          _process(file.path);
        case SharedMediaType.video:
          _processVideo(file.path);
        default:
          break;
      }
    }
  });
}

// =============================================================================
// rsi_unfiltered_shared_media_type — GOOD: no SharedMediaFile fields accessed
// =============================================================================

void goodNoFieldAccess() {
  // Callback does not access SharedMediaFile fields — not flagged.
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    print(files.length);
  });
}

// =============================================================================
// Utility stubs
// =============================================================================

void _process(String path) {}
void _processVideo(String path) {}
