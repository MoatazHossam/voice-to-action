import '../models/ai_intake_input.dart';

/// Real camera/gallery capture, kept behind an interface for the same
/// testability reason as [PermissionGate]: the controller must not depend
/// on `image_picker` directly.
abstract class ImageCapture {
  Future<AiIntakeInput?> pickFromCamera();
  Future<AiIntakeInput?> pickFromGallery();
}
