import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/datasources/remote/post_remote_datasource.dart';
import '../../../data/datasources/local/feed_local_datasource.dart';

class FeedCacheProvider extends ChangeNotifier {
  FeedCacheProvider(this._remote, this._local);

  final PostRemoteDatasource _remote;
  final FeedLocalDatasource _local;

  List<Map<String, dynamic>> _posts = [];
  bool _isInitialLoading = true;
  Object? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String? _userId;

  List<Map<String, dynamic>> get posts => _posts;
  bool get isInitialLoading => _isInitialLoading;
  Object? get error => _error;

  void init(String userId) {
    _userId = userId;
    final cached = _local.getCachedFeed(userId) ?? [];
    if (cached.isNotEmpty) {
      _posts = cached;
      _isInitialLoading = false;
      notifyListeners();
    }

    _sub?.cancel();
    _sub = _remote.watchFeed().listen(
      (rawPosts) {
        _posts = rawPosts;
        _isInitialLoading = false;
        _error = null;
        _local.cacheFeed(userId, rawPosts);
        notifyListeners();
      },
      onError: (e) {
        _error = e;
        _isInitialLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    _error = null;
    notifyListeners();
    try {
      final fresh = await _remote.fetchFeed();
      _posts = fresh;
      if (_userId != null) {
        await _local.cacheFeed(_userId!, fresh);
      }
      notifyListeners();
    } catch (e) {
      _error = e;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
