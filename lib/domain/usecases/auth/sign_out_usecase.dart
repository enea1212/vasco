// Sign-out is delegated directly to AuthService (Firebase Auth).
// This use-case wraps the service call for testability and consistency
// with the use-case pattern used elsewhere in the domain layer.
class SignOutUsecase {
  const SignOutUsecase(this._signOut);

  /// Injected function delegate from AuthService.
  final Future<void> Function() _signOut;

  Future<void> call() => _signOut();
}
