import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vasco/screens/home_screen.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';




Future<void> main() async {
  // 1. Asigură-te că serviciile Flutter sunt inițializate
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Încarcă fișierul .env
  try {
    await dotenv.load(fileName: ".env");
    print("Fișierul .env a fost încărcat cu succes!");
  } catch (e) {
    print("Eroare la încărcarea .env: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VascoApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}


