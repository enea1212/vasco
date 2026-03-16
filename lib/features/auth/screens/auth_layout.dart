//Persistență automată: Când închizi aplicația și o redeschizi,
//StreamBuilder verifică singur sesiunea. Dacă erai logat,
// te duce direct la HomeScreen fără să mai treci prin Login.
//
//Logout instant: Dacă din orice parte a aplicației apelezi authService.signOut(), 
//acest AuthLayout va detecta imediat că snapshot.hasData a
// devenit fals și te va arunca automat afară pe pagina de Login. 
//Nu trebuie să scrii tu cod de navigare manual pentru logout.
//
//Parametrul pageIfNotConnected: Oferă flexibilitate. Dacă vrei ca uneori,
// în loc de Login, să trimiți omul la o pagină de „Welcome” sau „Onboarding”,
// poți face asta prin acest parametru.


import 'package:flutter/material.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';
import 'package:vasco/screens/home_screen.dart';
import 'package:vasco/services/auth_service.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    this.pageIfNotConnected,
  });

  final Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: authService,
      builder: (context, currentAuthService, child) {
        return StreamBuilder(
          stream: currentAuthService.authStateChanges(),
          builder: (context, snapshot) {
            Widget widget;
            if (snapshot.connectionState == ConnectionState.waiting) {
              widget = const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasData) {
              widget = HomeScreen();
            } else {
              widget = pageIfNotConnected ?? const LoginScreen();
            }
            return widget;
          },
        );
      },
    );
  }
}

