import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:vasco/core/cache/map_data_cache.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/domain/repositories/i_location_repository.dart';
import 'package:vasco/presentation/providers/domain/feed_cache_provider.dart';
import 'package:vasco/presentation/providers/domain/feed_provider.dart';
import 'package:vasco/presentation/providers/domain/friends_provider.dart';
import 'package:vasco/presentation/providers/domain/location_provider.dart';
import 'package:vasco/presentation/providers/domain/messaging_provider.dart';
import 'package:vasco/presentation/providers/domain/swipe_provider.dart';
import 'package:vasco/presentation/providers/domain/user_provider.dart';

class SplashScreen extends StatefulWidget {
  /// When [uid] is provided the splash initialises all providers and calls
  /// [onReady] when both user data has loaded and the minimum display time
  /// has elapsed.  When [uid] is null it simply shows the branded animation
  /// (used while the Firebase auth state is still resolving).
  final String? uid;
  final VoidCallback? onReady;

  const SplashScreen({super.key, this.uid, this.onReady});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeIn;
  late final AnimationController _pulse;
  bool _initStarted = false;

  @override
  void initState() {
    super.initState();

    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    if (widget.uid != null && widget.onReady != null) {
      _initStarted = true;
      _initProviders();
    }
  }

  Future<void> _initProviders() async {
    final uid = widget.uid!;
    if (!mounted) return;

    context.read<UserProvider>().init(uid);
    context.read<FriendsProvider>().init(uid);
    context.read<FeedProvider>().init(uid);
    context.read<LocationProvider>().init(uid);
    context.read<MessagingProvider>().init(uid);
    context.read<SwipeProvider>().initMatches(uid);
    context.read<FeedCacheProvider>().init(uid);

    // Start location publishing in background
    final locationProvider = context.read<LocationProvider>();
    context
        .read<ILocationRepository>()
        .getVisibility(uid)
        .then(
          (vis) => locationProvider.startPublishing(uid, vis),
          onError: (_) => locationProvider.startPublishing(uid, 'all'),
        );

    // Wait for user data, map pre-load, locations, swipe candidates,
    // and a minimum display time — all in parallel.
    await Future.wait([
      _waitForUser(),
      _waitForLocations(),
      _preloadMapData(),
      context.read<SwipeProvider>().loadCandidates(uid).catchError((_) {}),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);

    if (!mounted) return;
    widget.onReady?.call();
  }

  Future<void> _waitForLocations() async {
    if (!mounted) return;
    final provider = context.read<LocationProvider>();
    if (provider.friends.isNotEmpty) return;

    final completer = Completer<void>();
    void listener() {
      if (provider.friends.isNotEmpty && !completer.isCompleted) {
        completer.complete();
      }
    }

    provider.addListener(listener);
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 4)),
    ]);
    provider.removeListener(listener);
  }

  Future<void> _preloadMapData() async {
    // GeoJSON
    if (!MapDataCache.geoJsonReady) {
      try {
        final raw = await rootBundle.loadString('assets/custom.geo.json');
        MapDataCache.geoJson = raw;
        MapDataCache.geoJsonData = json.decode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Profile photo bytes (the slow HTTP part that map_page uses for the pin)
    if (MapDataCache.profilePhotoBytes == null && mounted) {
      final photoUrl = context.read<UserProvider>().user?.photoUrl;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(photoUrl));
          if (res.statusCode == 200) {
            MapDataCache.profilePhotoBytes = res.bodyBytes;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _waitForUser() async {
    if (!mounted) return;
    final provider = context.read<UserProvider>();
    if (provider.user != null) return;

    final completer = Completer<void>();
    void listener() {
      if (provider.user != null && !completer.isCompleted) {
        completer.complete();
      }
    }

    provider.addListener(listener);
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 7)),
    ]);
    provider.removeListener(listener);
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auth resolved after the no-uid splash was already mounted: Flutter reuses
    // this state via reconciliation, so initState never re-runs.  Trigger init
    // now that we have a uid.
    if (!_initStarted && widget.uid != null && widget.onReady != null) {
      _initStarted = true;
      _initProviders();
    }
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            // ── Branded centre ────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing icon
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Transform.scale(
                        scale: 1.0 + _pulse.value * 0.045,
                        child: child,
                      ),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 36,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.travel_explore_rounded,
                          color: Colors.white,
                          size: 46,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Gradient wordmark
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.primary, AppColors.purple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: const Text(
                        'Vasco',
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -2.5,
                          height: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Explore the world together',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Animated dots ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 48,
              ),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => _BouncingDots(t: _pulse.value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Three dots that bounce in a staggered wave.
class _BouncingDots extends StatelessWidget {
  final double t; // 0 → 1 oscillation from AnimationController

  const _BouncingDots({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        // Phase-shift each dot by 1/3
        final phase = (t + i / 3.0) % 1.0;
        // Sine-like bounce: peaks at 0.5
        final lift = phase < 0.5 ? phase * 2 : (1.0 - phase) * 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Transform.translate(
            offset: Offset(0, -8 * lift),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.35 + lift * 0.65),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
