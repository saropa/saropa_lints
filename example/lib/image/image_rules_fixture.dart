// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// Test fixture for image rules (Plan Group A)

import 'package:flutter/material.dart';

// =========================================================================
// avoid_image_rebuild_on_scroll (A5)
// =========================================================================

class BadImageListWidget extends StatelessWidget {
  final List<String> urls;
  const BadImageListWidget({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: urls.length,
      itemBuilder: (context, index) {
        // expect_lint: avoid_image_rebuild_on_scroll
        return Image.network(urls[index]);
      },
    );
  }
}

class GoodImageListWidget extends StatelessWidget {
  final List<String> urls;
  const GoodImageListWidget({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    // GOOD: Use CachedNetworkImage or other caching solution
    return ListView.builder(
      itemCount: urls.length,
      itemBuilder: (context, index) {
        // CachedNetworkImage would be used here in real code
        return Container(
          child: Text('Image ${index + 1}'),
        );
      },
    );
  }
}

// =========================================================================
// require_avatar_fallback (A6)
// =========================================================================

class BadAvatarFallbackWidget extends StatelessWidget {
  const BadAvatarFallbackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_avatar_fallback
    return CircleAvatar(
      backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
    );
  }
}

class GoodAvatarFallbackWidget extends StatelessWidget {
  const GoodAvatarFallbackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Has onBackgroundImageError handler
    return CircleAvatar(
      backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle error - could log or use fallback
      },
    );
  }
}

// =========================================================================
// prefer_video_loading_placeholder (A7)
// =========================================================================

// Note: This requires Chewie or BetterPlayer packages
// The test demonstrates the pattern that would trigger the lint

/*
class BadVideoWidget extends StatelessWidget {
  const BadVideoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: prefer_video_loading_placeholder
    return Chewie(controller: chewieController);
  }
}

class GoodVideoWidget extends StatelessWidget {
  const GoodVideoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Has placeholder
    return Chewie(
      controller: chewieController,
      placeholder: Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
*/
