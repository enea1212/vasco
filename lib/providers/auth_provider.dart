import 'package:flutter/material.dart';
import 'package:vasco/services/auth_service.dart';



//Acesta este "Managerul" sau "Creierul" paginii. 
//El face legătura între AuthService și ecranele tale 
//(UI).Responsabilitate: Gestionează starea interfeței 
//(State Management).Rol principal: * Să pornească și să oprească indicatorul de încărcare 
//(_isLoading).




class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  bool _isLoading = false;

  AuthViewModel(this._authService);

  bool get isLoading => _isLoading;

  // Metoda preluată și adaptată din login_screen.dart
  Future<void> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners(); // Notifică UI-ul să afișeze indicatorul de încărcare
    try {
      await _authService.signInWithEmail(email, password);
    } catch (e) {
      rethrow; // Aruncăm eroarea pentru a fi prinsă de UI (showDialog)
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



Future<void> register({
  required String email,
  required String password,
  required String name,
}) async {
  _isLoading = true;
  notifyListeners(); // Notificăm UI-ul să afișeze loading (ex: pe buton)

  try {
    // Apelăm AuthService (Repository-ul) [cite: 1]
    await _authService.createAccount(email, password, name);
  } catch (e) {
    // Aruncăm eroarea mai departe pentru a fi prinsă de showDialog în UI
    rethrow; 
  } finally {
    _isLoading = false;
    notifyListeners(); // Oprim loading-ul indiferent dacă a reușit sau nu
  }
}



}