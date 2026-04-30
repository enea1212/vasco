import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';
import 'package:vasco/providers/auth_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/repository/user_repository.dart';
import 'package:vasco/repository/friends_repository.dart';
import 'package:vasco/providers/friends_provider.dart';
import 'package:vasco/repository/messaging_repository.dart';
import 'package:vasco/providers/messaging_provider.dart';
import 'package:vasco/screens/home_screen.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:vasco/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<PostRepository>(create: (_) => PostRepository()),
        Provider<UserRepository>(create: (_) => UserRepository()),
        ChangeNotifierProxyProvider<AuthService, AuthViewModel>(
          create: (context) => AuthViewModel(context.read<AuthService>()),
          update: (context, authService, previous) => AuthViewModel(authService),
        ),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        Provider<FriendsRepository>(create: (_) => FriendsRepository()),
        ChangeNotifierProvider<FriendsProvider>(create: (_) => FriendsProvider()),
        Provider<MessagingRepository>(create: (_) => MessagingRepository()),
        ChangeNotifierProxyProvider<MessagingRepository, MessagingProvider>(
          create: (context) => MessagingProvider(context.read<MessagingRepository>()),
          update: (context, repo, previous) => previous ?? MessagingProvider(repo),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vasco',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111827),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFF4F46E5), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFF3F4F6),
          thickness: 1,
          space: 1,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF9FAFB),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4F46E5),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            final String uid = snapshot.data!.uid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<UserProvider>().listenToUser(uid);
              context.read<FriendsProvider>().init(uid);
              context.read<MessagingProvider>().init(uid);
            });
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
