import 'package:permission_handler/permission_handler.dart';

import '../contracts/permission_gate.dart';

/// Explicit permission state for the idle -> permission -> capture
/// transition, kept separate from `AudioRecorder`/`ImageCaptureService` so
/// the UI can show a dedicated "permission needed/denied" state rather than
/// inferring it from a capture failure.
class PermissionService implements PermissionGate {
  @override
  Future<bool> hasMicrophone() => Permission.microphone.isGranted;

  @override
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  @override
  Future<bool> hasCamera() => Permission.camera.isGranted;

  @override
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> isMicrophonePermanentlyDenied() =>
      Permission.microphone.isPermanentlyDenied;

  Future<void> openSettings() => openAppSettings();
}
