// Sign-in is delegated directly to AuthService (Firebase Auth).
// This use-case wraps the service call for testability and consistency
// with the use-case pattern used elsewhere in the domain layer.
class SignInUsecase {
  const SignInUsecase(this._signIn);

  /// Injected function delegate from AuthService.
  final Future<void> Function(String email, String password) _signIn;

  Future<void> call(String email, String password) =>
      _signIn(email, password);
}
