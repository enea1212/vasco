import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vasco/services/feed_cache_service.dart';

class FeedCacheProvider extends ChangeNotifier {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _feedSub;
  List<Map<String, dynamic>> _posts = [];
  bool _hasLoadedRemote = false;
  bool _isRefreshing = false;
  Object? _error;
  bool _isInitialized = false;

  List<Map<String, dynamic>> get posts => _posts;
  bool get hasLoadedRemote => _hasLoadedRemote;
  Object? get error => _error;
  bool get isInitialLoading => !_hasLoadedRemote && _posts.isEmpty;

  Query<Map<String, dynamic>> _feedQuery() => FirebaseFirestore.instance
      .collection('location_photos')
      .orderBy('createdAt', descending: true)
      .limit(40);

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    _posts = FeedCacheService.loadPosts()
        .map(FeedCacheService.decodePost)
        .toList();
    _listenToFeed();
  }

  void _listenToFeed() {
    _feedSub?.cancel();
    _feedSub = _feedQuery().snapshots().listen(
      (snapshot) async {
        await _applySnapshot(snapshot);
      },
      onError: (error, stackTrace) {
        debugPrint('[FeedCacheProvider] feed stream error: $error');
        _hasLoadedRemote = true;
        _error = error;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await _refreshFromServer().timeout(const Duration(seconds: 5));
    } catch (error, stackTrace) {
      debugPrint('[FeedCacheProvider] feed refresh error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _hasLoadedRemote = true;
      _error = error;
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshFromServer() async {
    final snapshot = await _feedQuery().get(
      const GetOptions(source: Source.server),
    );
    await _applySnapshot(snapshot);
  }

  Future<void> _applySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    await FeedCacheService.saveSnapshot(snapshot);
    _posts = snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
    _hasLoadedRemote = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    super.dispose();
  }
}
