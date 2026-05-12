import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/datasources/remote/post_remote_datasource.dart';
import '../../../data/datasources/remote/friend_remote_datasource.dart';

class FriendsFeedProvider extends ChangeNotifier {
  FriendsFeedProvider(this._postDs, this._friendDs);

  final PostRemoteDatasource _postDs;
  final FriendRemoteDatasource _friendDs;

  List<Map<String, dynamic>> _friendsFeed = [];
  List<Map<String, dynamic>> _fofFeed = [];
  bool _friendsLoading = false;
  bool _fofLoading = false;
  StreamSubscription<List<Map<String, dynamic>>>? _friendsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _fofSub;

  List<Map<String, dynamic>> get friendsFeed => _friendsFeed;
  List<Map<String, dynamic>> get fofFeed => _fofFeed;
  bool get friendsLoading => _friendsLoading;
  bool get fofLoading => _fofLoading;

  Future<void> initForUser(String userId, List<String> friendIds) async {
    _friendsSub?.cancel();
    _fofSub?.cancel();

    if (friendIds.isEmpty) {
      _friendsFeed = [];
      _fofFeed = [];
      _friendsLoading = false;
      _fofLoading = false;
      notifyListeners();
      return;
    }

    _friendsLoading = true;
    _fofLoading = true;
    notifyListeners();

    _friendsSub = _postDs.watchPostsByUserIds(friendIds).listen(
      (posts) {
        _friendsFeed = posts;
        _friendsLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[FriendsFeedProvider] friends feed error: $e');
        _friendsLoading = false;
        notifyListeners();
      },
    );

    try {
      final fofSets = await Future.wait(
        friendIds.take(20).map((fid) => _friendDs.fetchFriendIds(fid)),
      );
      final fofIds = {
        ...fofSets.expand((ids) => ids),
      }..removeAll({userId, ...friendIds});

      if (fofIds.isEmpty) {
        _fofFeed = [];
        _fofLoading = false;
        notifyListeners();
        return;
      }

      _fofSub = _postDs.watchPostsByUserIds(fofIds.toList()).listen(
        (posts) {
          _fofFeed = posts;
          _fofLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[FriendsFeedProvider] FOF feed error: $e');
          _fofLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[FriendsFeedProvider] FOF init error: $e');
      _fofLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _fofSub?.cancel();
    super.dispose();
  }
}
