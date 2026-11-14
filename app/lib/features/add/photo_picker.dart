import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where a receipt photo comes from.
enum PhotoSource { camera, gallery }

/// Opens the phone's camera or gallery and returns the picked file's path,
/// or null when the user backs out. Tests replace it through
/// [photoPickerProvider].
abstract interface class PhotoPicker {
  Future<String?> pick(PhotoSource source);
}

/// The real picker (image_picker; the camera runs through the system app,
/// so no camera permission is needed).
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
