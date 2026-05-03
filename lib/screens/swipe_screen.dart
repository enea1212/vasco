import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/tinder_card/tinder_card.dart';
import 'package:vasco/tinder_card/match_dialog.dart';
import 'package:vasco/tinder_services/tinder_location_service.dart';

class SwipeScreen extends StatefulWidget {
  @override
  _SwipeScreenState createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final CardSwiperController controller = CardSwiperController();
  List<Map<String, dynamic>> recommendations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _updateLocationThenLoad();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _updateLocationThenLoad() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await LocationService().updateCurrentUserLocation(uid);
    }
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getRecommendations');
      final results = await callable.call();
      final List<dynamic> data = results.data;
      if (!mounted) return;
      setState(() {
        recommendations = data.map((e) => Map<String, dynamic>.from(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Eroare la încărcarea recomandărilor: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  bool _onSwipe(int? previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex != null) {
      _handleSwipe(previousIndex, direction);
    }
    return true;
  }

  Future<void> _handleSwipe(int previousIndex, CardSwiperDirection direction) async {
    final swipedProfile = recommendations[previousIndex];
    final myUserId = FirebaseAuth.instance.currentUser?.uid;
    if (myUserId == null) return;

    final isLike = direction == CardSwiperDirection.right;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('recordSwipe');
      final result = await callable.call({
        'toUserId': swipedProfile['id'],
        'isLike': isLike,
      });

      final data = Map<String, dynamic>.from(result.data);

      if (data['matched'] == true && mounted) {
        final currentUser = context.read<UserProvider>().user;
        _showMatchDialog(
          myUserId: myUserId,
          currentUserPhoto: currentUser?.photoUrl ?? '',
          matchedUser: Map<String, dynamic>.from(data['matchedUser']),
          conversationId: data['conversationId'],
        );
      }
    } catch (e) {
      debugPrint('Eroare la salvarea swipe-ului: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare swipe: $e')),
        );
      }
    }
  }

  void _showMatchDialog({
    required String myUserId,
    required String currentUserPhoto,
    required Map<String, dynamic> matchedUser,
    required String conversationId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MatchDialog(
        currentUserId: myUserId,
        currentUserPhoto: currentUserPhoto,
        matchedUser: matchedUser,
        conversationId: conversationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vasco Dating',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : recommendations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 16),
                      const Text(
                        'Nu am găsit persoane noi în zonă.',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadRecommendations,
                        child: const Text('Caută din nou'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: CardSwiper(
                            controller: controller,
                            cardsCount: recommendations.length,
                            numberOfCardsDisplayed: recommendations.length == 1 ? 1 : 2,
                            onSwipe: _onSwipe,
                            cardBuilder: (context, index) =>
                                TinderCard(profile: recommendations[index]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              FloatingActionButton(
                                heroTag: 'swipe_left',
                                onPressed: () => controller.swipeLeft(),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                elevation: 4,
                                child: const Icon(Icons.close_rounded, size: 30),
                              ),
                              FloatingActionButton(
                                heroTag: 'swipe_right',
                                onPressed: () => controller.swipeRight(),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                elevation: 4,
                                child: const Icon(Icons.favorite_rounded, size: 30),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
