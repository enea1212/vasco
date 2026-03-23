import 'package:vasco/models/user_model.dart';

class AuthService {
  UserModel? get currentUser {
    return null;
  }

  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> createAccount(String email, String password, String name) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> signOut() async {}

  Future<void> resetPassword({required String email}) async {}

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {}
}