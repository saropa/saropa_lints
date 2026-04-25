import 'package:just_audio/just_audio.dart';

void badMissingBackgroundAudioConfig() {
  // LINT: Example assumes Info.plist / AndroidManifest lack background audio.
  final player = AudioPlayer();
  player.play();
}

void okWhenPlatformConfigured() {
  // OK: Valid once UIBackgroundModes audio and FOREGROUND_SERVICE are configured.
  final player = AudioPlayer();
  player.stop();
}
