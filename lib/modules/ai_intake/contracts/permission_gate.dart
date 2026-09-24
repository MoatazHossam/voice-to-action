/// Explicit mic/camera permission checks, kept behind an interface so
/// `AiIntakeController` never talks to a permission plugin directly — this
/// is what keeps the idle -> permission -> capture transition unit-testable
/// without a platform channel.
abstract class PermissionGate {
  Future<bool> hasMicrophone();
  Future<bool> requestMicrophone();
  Future<bool> hasCamera();
  Future<bool> requestCamera();
}
