import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vasco/tinder_card/tinder_card.dart';
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

  Future<void> _updateLocationThenLoad() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await LocationService().updateCurrentUserLocation(uid);
    }
    _loadRecommendations();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() => isLoading = true);
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('getRecommendations');
      final results = await callable.call();

      final List<dynamic> data = results.data;
      if (!mounted) return;
      setState(() {
        recommendations =
            data.map((e) => Map<String, dynamic>.from(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Eroare la încărcarea recomandărilor: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  bool _onSwipe(
    int? previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (previousIndex != null) {
      _handleSwipe(previousIndex, direction);
    }
    return true;
  }
  Future<void> _handleSwipe(
    int previousIndex,
    CardSwiperDirection direction,
  ) async {
    final swipedProfile = recommendations[previousIndex];
    final myUserId = FirebaseAuth.instance.currentUser?.uid;

    if (myUserId == null) return;

    bool isLike = direction == CardSwiperDirection.right;

    try {
      await FirebaseFirestore.instance.collection('swipes').add({
        'fromUserId': myUserId,
        'toUserId': swipedProfile['id'],
        'isLike': isLike,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("Swipe salvat! $isLike pe ${swipedProfile['displayName']}");
    } catch (e) {
      debugPrint("Eroare la salvarea swipe-ului: $e");
    }
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
                      const Text('Nu am găsit persoane noi în zonă.'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadRecommendations,
                        child: const Text('Caută din nou'),
                      )
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              FloatingActionButton(
                                onPressed: () => controller.swipeLeft(),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                child: const Icon(Icons.close, size: 30),
                              ),
                              FloatingActionButton(
                                onPressed: () => controller.swipeRight(),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                child: const Icon(Icons.favorite, size: 30),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
    );
  }
}