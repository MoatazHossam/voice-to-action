import 'package:image_picker/image_picker.dart';

import '../contracts/image_capture.dart';
import '../models/ai_intake_input.dart';

/// Real camera/gallery capture for the image entry journey. Receiving
/// images via another app's OS share sheet is a separate, optional
/// integration and is intentionally out of scope here.
class ImageCaptureService implements ImageCapture {
  ImageCaptureService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Caps the longest edge to keep OCR input at a reasonable resolution and
  /// bound memory use; orientation is preserved/normalized by image_picker.
  static const double _maxDimension = 2000;

  @override
  Future<AiIntakeInput?> pickFromCamera() => _pick(ImageSource.camera, 'camera');

  @override
  Future<AiIntakeInput?> pickFromGallery() => _pick(ImageSource.gallery, 'gallery');

  Future<AiIntakeInput?> _pick(ImageSource source, String label) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: 90,
    );
    if (file == null) return null;
    return AiIntakeInput(
      sourceType: AiIntakeSourceType.image,
      localPath: file.path,
      capturedAt: DateTime.now(),
      captureMetadata: {'source': label},
    );
  }
}
