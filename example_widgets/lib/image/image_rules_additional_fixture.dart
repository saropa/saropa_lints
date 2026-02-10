// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: prefer_const_constructors
// Test fixture for image rules

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// require_image_cache_dimensions
// =========================================================================
// Warns when Image.network is used without cacheWidth/cacheHeight.

// BAD: Image.network without cache dimensions
class BadImageNetworkNoCacheDimensions extends StatelessWidget {
  const BadImageNetworkNoCacheDimensions({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_image_cache_dimensions
    return Image.network('https://example.com/large-image.jpg');
  }
}

// GOOD: Image.network with cacheWidth
class GoodImageNetworkWithCacheWidth extends StatelessWidget {
  const GoodImageNetworkWithCacheWidth({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://example.com/large-image.jpg',
      cacheWidth: 400,
    );
  }
}

// GOOD: Image.network with both cache dimensions
class GoodImageNetworkWithBothDimensions extends StatelessWidget {
  const GoodImageNetworkWithBothDimensions({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://example.com/large-image.jpg',
      cacheWidth: 400,
      cacheHeight: 300,
    );
  }
}

// =========================================================================
// prefer_cached_image_cache_manager
// =========================================================================
// Warns when CachedNetworkImage doesn't use a custom CacheManager.

// BAD: CachedNetworkImage without cacheManager
class BadCachedImageNoManager extends StatelessWidget {
  const BadCachedImageNoManager({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: prefer_cached_image_cache_manager
    return CachedNetworkImage(
      imageUrl: 'https://example.com/image.jpg',
    );
  }
}

// GOOD: CachedNetworkImage with cacheManager
class GoodCachedImageWithManager extends StatelessWidget {
  const GoodCachedImageWithManager({super.key});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: 'https://example.com/image.jpg',
      cacheManager: CustomCacheManager(),
    );
  }
}

// =========================================================================
// Helper mocks
// =========================================================================

class Image extends Widget {
  const Image({super.key});

  const Image.network(
    String url, {
    Key? key,
    int? cacheWidth,
    int? cacheHeight,
  }) : super(key: key);

  const Image.asset(String name, {Key? key}) : super(key: key);
}

class CachedNetworkImage extends Widget {
  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.cacheManager,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final CacheManager? cacheManager;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
}

class CacheManager {}

class CustomCacheManager extends CacheManager {}
