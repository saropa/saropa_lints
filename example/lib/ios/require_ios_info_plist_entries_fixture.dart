import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

Future<void> badMissingLocationKey() async {
  // LINT: Missing NSLocationWhenInUseUsageDescription in Info.plist.
  await Geolocator.getCurrentPosition();
}

Future<void> badMissingPhotoKey() async {
  final picker = ImagePicker();
  // LINT: Missing NSPhotoLibraryUsageDescription in Info.plist.
  await picker.pickImage(source: ImageSource.gallery);
}

Future<void> okWhenPlistConfigured() async {
  // OK: This usage is valid once matching NS*UsageDescription keys exist.
  await Geolocator.getPositionStream().first;
}
