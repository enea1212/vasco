import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/post_entity.dart';
import '../../../domain/usecases/feed/get_feed_usecase.dart';
import '../../../domain/usecases/feed/get_user_posts_usecase.dart';

class FeedProvider extends ChangeNotifier {
  FeedProvider(this._getFeed, this._getUserPosts);

  final GetFeedUsecase _getFeed;
  final GetUserPostsUsecase _getUserPosts;

  List<PostEntity> _feed = [];
  List<PostEntity> _userPosts = [];
  bool _isLoading = false;
  StreamSubscription<List<PostEntity>>? _feedSub;
  StreamSubscription<List<PostEntity>>? _userPostsSub;

  List<PostEntity> get feed => _feed;
  List<PostEntity> get userPosts => _userPosts;
  bool get isLoading => _isLoading;

  void init(String userId) {
    _feedSub?.cancel();
    _userPostsSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _feedSub = _getFeed(userId).listen(
      (posts) {
        _feed = posts;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[FeedProvider] feed stream error: $e');
        _isLoading = false;
        notifyListeners();
      },
    );

    _userPostsSub = _getUserPosts(userId).listen(
      (posts) {
        _userPosts = posts;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[FeedProvider] user posts stream error: $e');
      },
    );
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _userPostsSub?.cancel();
    super.dispose();
  }
}
