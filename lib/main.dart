import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';
import 'package:vasco/providers/auth_provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/screens/home_screen.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart'; 
import 'package:vasco/services/auth_service.dart';

Future<void> main() async {
  // 1. Asigură-te că serviciile Flutter sunt inițializate
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();


  // 3. Injectează AuthService folosind MultiProvider
  runApp(
  MultiProvider(
  providers: [
    Provider<AuthService>(create: (_) => AuthService()),
    Provider<PostRepository>(create: (_) => PostRepository()),
    ChangeNotifierProxyProvider<AuthService, AuthViewModel>(
      create: (context) => AuthViewModel(context.read<AuthService>()),
      update: (context, authService, previous) => AuthViewModel(authService),
    ),
  ],
  child: const MyApp(),
));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VascoApp',
      debugShowCheckedModeBanner: false,
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


