import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

Future<void> badMissingManifestEntry() async {
  // LINT: Example project intentionally omits AndroidManifest permission rows.
  await Geolocator.getCurrentPosition();
}

Future<void> badMissingCameraPermission() async {
  final picker = ImagePicker();
  // LINT: Camera usage also requires AndroidManifest permission entries.
  await picker.pickImage(source: ImageSource.camera);
}

Future<void> okWhenManifestContainsPermissions() async {
  // OK: In a real app this call is valid once AndroidManifest has required
  // uses-permission entries configured.
  await Geolocator.getPositionStream().first;
}
