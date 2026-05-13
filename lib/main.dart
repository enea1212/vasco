// lib/main.dart
//
// Versiunea refactorizată a main.dart cu DI tree complet pe layere.
//
// Note despre providerii lipsă:
//   • MessagingProvider, SwipeProvider, MapUiProvider, ProfileUiProvider
//     nu există încă în lib/presentation/providers/. Sunt marcate mai jos.
//   • Când acele fișiere vor fi create, decomentați secțiunile relevante.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// Bootstrap / Firebase
import 'package:vasco/firebase_options.dart';

// Auth
import 'package:vasco/services/auth_service.dart';
import 'package:vasco/models/user_model.dart';

// Hive box name
import 'package:vasco/services/feed_cache_service.dart';

// ── Screens ──────────────────────────────────────────────────────────────────
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/presentation/screens/home/home_screen.dart';
import 'package:vasco/presentation/screens/splash/splash_screen.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';

// ── Infrastructure provider ───────────────────────────────────────────────────
import 'package:vasco/presentation/providers/infrastructure/auth_state_provider.dart';

// ── Datasources ───────────────────────────────────────────────────────────────
import 'package:vasco/data/datasources/remote/user_remote_datasource.dart';
import 'package:vasco/data/datasources/remote/post_remote_datasource.dart';
import 'package:vasco/data/datasources/remote/friend_remote_datasource.dart';
import 'package:vasco/data/datasources/remote/message_remote_datasource.dart';
import 'package:vasco/data/datasources/remote/location_remote_datasource.dart';
import 'package:vasco/data/datasources/remote/swipe_remote_datasource.dart';
import 'package:vasco/data/datasources/local/feed_local_datasource.dart';

// ── Repository interfaces ─────────────────────────────────────────────────────
import 'package:vasco/domain/repositories/i_user_repository.dart';
import 'package:vasco/domain/repositories/i_post_repository.dart';
import 'package:vasco/domain/repositories/i_friend_repository.dart';
import 'package:vasco/domain/repositories/i_message_repository.dart';
import 'package:vasco/domain/repositories/i_location_repository.dart';
import 'package:vasco/domain/repositories/i_swipe_repository.dart';

// ── Repository implementations ────────────────────────────────────────────────
import 'package:vasco/data/repositories/user_repository_impl.dart';
import 'package:vasco/data/repositories/post_repository_impl.dart';
import 'package:vasco/data/repositories/friend_repository_impl.dart';
import 'package:vasco/data/repositories/message_repository_impl.dart';
import 'package:vasco/data/repositories/location_repository_impl.dart';
import 'package:vasco/data/repositories/swipe_repository_impl.dart';

// ── Use-cases: profile ────────────────────────────────────────────────────────
import 'package:vasco/domain/usecases/profile/get_user_usecase.dart';
import 'package:vasco/domain/usecases/profile/update_profile_usecase.dart';

// ── Use-cases: feed ───────────────────────────────────────────────────────────
import 'package:vasco/domain/usecases/feed/get_feed_usecase.dart';
import 'package:vasco/domain/usecases/feed/get_user_posts_usecase.dart';

// ── Use-cases: friends ────────────────────────────────────────────────────────
import 'package:vasco/domain/usecases/friends/get_friends_usecase.dart';
import 'package:vasco/domain/usecases/friends/get_incoming_requests_usecase.dart';
import 'package:vasco/domain/usecases/friends/send_friend_request_usecase.dart';
import 'package:vasco/domain/usecases/friends/accept_friend_request_usecase.dart';
import 'package:vasco/domain/usecases/friends/decline_friend_request_usecase.dart';
import 'package:vasco/domain/usecases/friends/remove_friend_usecase.dart';
import 'package:vasco/domain/usecases/friends/search_users_usecase.dart';
import 'package:vasco/domain/usecases/friends/get_relationship_status_usecase.dart';

// ── Use-cases: location ───────────────────────────────────────────────────────
import 'package:vasco/domain/usecases/location/watch_friend_locations_usecase.dart';
import 'package:vasco/domain/usecases/location/publish_location_usecase.dart';
import 'package:vasco/domain/usecases/location/delete_location_usecase.dart';
import 'package:vasco/domain/usecases/location/get_location_visibility_usecase.dart';
import 'package:vasco/domain/usecases/location/set_location_visibility_usecase.dart';

// ── Use-cases: messaging ──────────────────────────────────────────────────────
import 'package:vasco/domain/usecases/messaging/watch_conversations_usecase.dart';
import 'package:vasco/domain/usecases/messaging/watch_messages_usecase.dart';
import 'package:vasco/domain/usecases/messaging/send_message_usecase.dart';

// ── Use-cases: swipe ──────────────────────────────────────────────────────────
import 'package:vasco/domain/usecases/swipe/get_candidates_usecase.dart';
import 'package:vasco/domain/usecases/swipe/swipe_usecase.dart';
import 'package:vasco/domain/usecases/swipe/watch_matches_usecase.dart';

// ── Domain providers ──────────────────────────────────────────────────────────
import 'package:vasco/presentation/providers/domain/user_provider.dart';
import 'package:vasco/presentation/providers/domain/friends_provider.dart';
import 'package:vasco/presentation/providers/domain/feed_provider.dart';
import 'package:vasco/presentation/providers/domain/location_provider.dart';

import 'package:vasco/presentation/providers/domain/messaging_provider.dart';
import 'package:vasco/presentation/providers/domain/swipe_provider.dart';

// ── UI providers ──────────────────────────────────────────────────────────────
import 'package:vasco/presentation/providers/ui/map_ui_provider.dart';
import 'package:vasco/presentation/providers/ui/profile_ui_provider.dart';

// ── Auth + Feed cache providers ───────────────────────────────────────────────
import 'package:vasco/presentation/providers/infrastructure/auth_provider.dart';
import 'package:vasco/presentation/providers/domain/feed_cache_provider.dart';
import 'package:vasco/presentation/providers/domain/friends_feed_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bootstrap identic cu main.dart original
  await dotenv.load(
    fileName: '.env',
    isOptional: true,
    mergeWith: {
      'SPOTIFY_CLIENT_ID': const String.fromEnvironment('SPOTIFY_CLIENT_ID'),
    },
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox(FeedCacheService.boxName);
  // FeedLocalDatasource folosește același box (boxName = 'feed_cache')
  await Hive.openBox(FeedLocalDatasource.boxName);

  runApp(
    MultiProvider(
      providers: [
        // ── Servicii tehnice ─────────────────────────────────────────────────
        Provider<AuthService>(create: (_) => AuthService()),

        // AuthViewModel wraps AuthService for login/register screens
        ChangeNotifierProvider<AuthViewModel>(
          create: (ctx) => AuthViewModel(ctx.read<AuthService>()),
        ),

        // ── Layer 1: Infrastructure providers ────────────────────────────────
        ChangeNotifierProvider<AuthStateProvider>(
          create: (_) => AuthStateProvider(),
        ),

        // ── Datasources (singleton-uri fără state) ────────────────────────────
        //
        // UserRemoteDatasource(FirebaseFirestore db)
        Provider<UserRemoteDatasource>(
          create: (_) => UserRemoteDatasource(FirebaseFirestore.instance),
        ),

        // PostRemoteDatasource(FirebaseFirestore db, FirebaseFunctions functions)
        Provider<PostRemoteDatasource>(
          create: (_) => PostRemoteDatasource(
            FirebaseFirestore.instance,
            FirebaseFunctions.instance,
          ),
        ),

        // FriendRemoteDatasource(FirebaseFirestore db, FirebaseFunctions functions)
        Provider<FriendRemoteDatasource>(
          create: (_) => FriendRemoteDatasource(
            FirebaseFirestore.instance,
            FirebaseFunctions.instance,
          ),
        ),

        // MessageRemoteDatasource(FirebaseFirestore db)
        Provider<MessageRemoteDatasource>(
          create: (_) => MessageRemoteDatasource(FirebaseFirestore.instance),
        ),

        // LocationRemoteDatasource(FirebaseFirestore db)
        Provider<LocationRemoteDatasource>(
          create: (_) => LocationRemoteDatasource(FirebaseFirestore.instance),
        ),

        // SwipeRemoteDatasource(FirebaseFirestore db, FirebaseFunctions functions)
        Provider<SwipeRemoteDatasource>(
          create: (_) => SwipeRemoteDatasource(
            FirebaseFirestore.instance,
            FirebaseFunctions.instance,
          ),
        ),

        // FeedLocalDatasource — fără parametri (folosește Hive.box intern)
        Provider<FeedLocalDatasource>(
          create: (_) => FeedLocalDatasource(),
        ),

        // ── Repository implementations (expuse ca interfețe) ──────────────────
        //
        // Regulă: Provider<IXxx> nu Provider<XxxImpl>

        // IUserRepository ← UserRepositoryImpl(UserRemoteDatasource)
        Provider<IUserRepository>(
          create: (ctx) => UserRepositoryImpl(
            ctx.read<UserRemoteDatasource>(),
          ),
        ),

        // IPostRepository ← PostRepositoryImpl(PostRemoteDatasource)
        Provider<IPostRepository>(
          create: (ctx) => PostRepositoryImpl(
            ctx.read<PostRemoteDatasource>(),
          ),
        ),

        // IFriendRepository ← FriendRepositoryImpl(FriendRemoteDatasource)
        Provider<IFriendRepository>(
          create: (ctx) => FriendRepositoryImpl(
            ctx.read<FriendRemoteDatasource>(),
          ),
        ),

        // IMessageRepository ← MessageRepositoryImpl(MessageRemoteDatasource)
        Provider<IMessageRepository>(
          create: (ctx) => MessageRepositoryImpl(
            ctx.read<MessageRemoteDatasource>(),
          ),
        ),

        // ILocationRepository ← LocationRepositoryImpl(LocationRemoteDatasource)
        Provider<ILocationRepository>(
          create: (ctx) => LocationRepositoryImpl(
            ctx.read<LocationRemoteDatasource>(),
          ),
        ),

        // ISwipeRepository ← SwipeRepositoryImpl(SwipeRemoteDatasource)
        Provider<ISwipeRepository>(
          create: (ctx) => SwipeRepositoryImpl(
            ctx.read<SwipeRemoteDatasource>(),
          ),
        ),

        // ── Layer 2: Domain providers ─────────────────────────────────────────
        //
        // Use-case-urile se instanțiază inline în create: cu repository din context.

        // UserProvider(GetUserUsecase, UpdateProfileUsecase)
        ChangeNotifierProvider<UserProvider>(
          create: (ctx) => UserProvider(
            GetUserUsecase(ctx.read<IUserRepository>()),
            UpdateProfileUsecase(ctx.read<IUserRepository>()),
          ),
        ),

        // FeedProvider(GetFeedUsecase, GetUserPostsUsecase)
        ChangeNotifierProvider<FeedProvider>(
          create: (ctx) => FeedProvider(
            GetFeedUsecase(ctx.read<IPostRepository>()),
            GetUserPostsUsecase(ctx.read<IPostRepository>()),
          ),
        ),

        // FriendsProvider(8 use-case-uri)
        ChangeNotifierProvider<FriendsProvider>(
          create: (ctx) {
            final repo = ctx.read<IFriendRepository>();
            return FriendsProvider(
              GetFriendsUsecase(repo),
              GetIncomingRequestsUsecase(repo),
              SendFriendRequestUsecase(repo),
              AcceptFriendRequestUsecase(repo),
              DeclineFriendRequestUsecase(repo),
              RemoveFriendUsecase(repo),
              SearchUsersUsecase(repo),
              GetRelationshipStatusUsecase(repo),
            );
          },
        ),

        // LocationProvider(5 use-case-uri)
        ChangeNotifierProvider<LocationProvider>(
          create: (ctx) {
            final repo = ctx.read<ILocationRepository>();
            return LocationProvider(
              WatchFriendLocationsUsecase(repo),
              PublishLocationUsecase(repo),
              DeleteLocationUsecase(repo),
              GetLocationVisibilityUsecase(repo),
              SetLocationVisibilityUsecase(repo),
            );
          },
        ),

        ChangeNotifierProvider<MessagingProvider>(
          create: (ctx) {
            final repo = ctx.read<IMessageRepository>();
            return MessagingProvider(
              WatchConversationsUsecase(repo),
              WatchMessagesUsecase(repo),
              SendMessageUsecase(repo),
            );
          },
        ),

        ChangeNotifierProvider<SwipeProvider>(
          create: (ctx) {
            final repo = ctx.read<ISwipeRepository>();
            return SwipeProvider(
              GetCandidatesUsecase(repo),
              SwipeUsecase(repo),
              WatchMatchesUsecase(repo),
            );
          },
        ),

        // ── Layer 3: UI providers ─────────────────────────────────────────────
        ChangeNotifierProvider<MapUiProvider>(create: (_) => MapUiProvider()),
        ChangeNotifierProvider<ProfileUiProvider>(create: (_) => ProfileUiProvider()),

        // Raw-map feed cache (for home screen PostCard)
        ChangeNotifierProvider<FeedCacheProvider>(
          create: (ctx) => FeedCacheProvider(
            ctx.read<PostRemoteDatasource>(),
            ctx.read<FeedLocalDatasource>(),
          ),
        ),

        // Friends & Friends-of-Friends feed (two-tab home feed)
        ChangeNotifierProvider<FriendsFeedProvider>(
          create: (ctx) => FriendsFeedProvider(
            ctx.read<PostRemoteDatasource>(),
            ctx.read<FriendRemoteDatasource>(),
          ),
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
        brightness: Brightness.dark,
<<<<<<< HEAD
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4F46E5),
          secondary: Color(0xFF7C3AED),
          surface: Color(0xFF13122B),
          error: Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF07071A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF07071A),
=======
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
>>>>>>> loading_screen
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
<<<<<<< HEAD
            backgroundColor: const Color(0xFF4F46E5),
=======
            backgroundColor: AppColors.primary,
>>>>>>> loading_screen
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
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
<<<<<<< HEAD
            side: const BorderSide(color: Color(0x1AFFFFFF), width: 1.5),
=======
            side: const BorderSide(color: AppColors.border, width: 1.5),
>>>>>>> loading_screen
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
<<<<<<< HEAD
          fillColor: const Color(0xFF1C1B36),
=======
          fillColor: AppColors.surfaceAlt,
>>>>>>> loading_screen
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
<<<<<<< HEAD
            borderSide: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
=======
            borderSide: const BorderSide(color: AppColors.border, width: 1),
>>>>>>> loading_screen
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
<<<<<<< HEAD
          labelStyle: const TextStyle(color: Color(0x8CFFFFFF)),
          hintStyle: const TextStyle(color: Color(0x61FFFFFF)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF13122B),
=======
          labelStyle: const TextStyle(color: AppColors.textMuted),
          hintStyle: const TextStyle(color: AppColors.textHint),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
>>>>>>> loading_screen
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerTheme: const DividerThemeData(
<<<<<<< HEAD
          color: Color(0x0DFFFFFF),
=======
          color: AppColors.divider,
>>>>>>> loading_screen
          thickness: 1,
          space: 1,
        ),
        dialogTheme: const DialogThemeData(
<<<<<<< HEAD
          backgroundColor: Color(0xFF13122B),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF1C1B36),
          surfaceTintColor: Colors.transparent,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF4F46E5);
            }
            return const Color(0x1AFFFFFF);
          }),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF4F46E5);
            }
            return const Color(0x8CFFFFFF);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0x334F46E5);
            }
            return const Color(0x1AFFFFFF);
          }),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1C1B36),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: StreamBuilder<UserModel?>(
        stream: context.read<AuthService>().authStateChanges(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF07071A),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4F46E5),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          // Utilizator autentificat → init providers → HomeScreen
          if (snapshot.hasData && snapshot.data != null) {
            final String uid = snapshot.data!.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;

              // Domain providers cu metoda init(uid)
              context.read<UserProvider>().init(uid);
              context.read<FriendsProvider>().init(uid);
              context.read<FeedProvider>().init(uid);
              context.read<LocationProvider>().init(uid);

              context.read<MessagingProvider>().init(uid);
              context.read<SwipeProvider>().initMatches(uid);
              context.read<FeedCacheProvider>().init(uid);

              // Pornire publishing locație (același pattern ca în main.dart original)
              final locationProvider = context.read<LocationProvider>();
              context
                  .read<ILocationRepository>()
                  .getVisibility(uid)
                  .then(
                    (vis) => locationProvider.startPublishing(uid, vis),
                    onError: (_) =>
                        locationProvider.startPublishing(uid, 'all'),
                  );
            });
            return const HomeScreen();
          }

          // Neutentificat → LoginScreen
          return const LoginScreen();
        },
      ),
=======
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surfaceAlt,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? AppColors.primary : null),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? AppColors.primary : null),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primaryLight
                  : null),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: AppColors.surfaceAlt,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

// ─── Auth gate ────────────────────────────────────────────────────────────────
// Routes: auth-loading → SplashScreen, logged-in+loading → SplashScreen,
//         ready → HomeScreen, logged-out → LoginScreen.

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _readyUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: context.read<AuthService>().authStateChanges(),
      builder: (context, snapshot) {
        // Firebase auth still resolving
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;

        // Not authenticated
        if (user == null) {
          _readyUid = null;
          return const LoginScreen();
        }

        // Authenticated but providers not yet initialised for this uid
        if (_readyUid != user.id) {
          return SplashScreen(
            uid: user.id,
            onReady: () => setState(() => _readyUid = user.id),
          );
        }

        // Everything ready
        return const HomeScreen();
      },
>>>>>>> loading_screen
    );
  }
}
