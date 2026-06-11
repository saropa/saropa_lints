// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `audioplayers_pool_not_disposed` (WARNING).
library;

import 'package:audioplayers/audioplayers.dart';

// expect_lint: audioplayers_pool_not_disposed
class BadSfx {
  late final AudioPool _pool;

  Future<void> init() async {
    _pool = await AudioPool.create(
      source: AssetSource('click.wav'),
      maxPlayers: 4,
    );
  }
  // No dispose() that releases _pool — the pooled players leak.
}

class GoodSfx {
  late final AudioPool _pool;

  Future<void> init() async {
    _pool = await AudioPool.create(
      source: AssetSource('click.wav'),
      maxPlayers: 4,
    );
  }

  void dispose() {
    _pool.dispose();
  }
}
