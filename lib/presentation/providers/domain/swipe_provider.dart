import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/match_entity.dart';
import '../../../domain/entities/swipe_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/swipe/get_candidates_usecase.dart';
import '../../../domain/usecases/swipe/swipe_usecase.dart';
import '../../../domain/usecases/swipe/watch_matches_usecase.dart';

class SwipeProvider extends ChangeNotifier {
  SwipeProvider(
    this._getCandidates,
    this._swipe,
    this._watchMatches,
  );

  final GetCandidatesUsecase _getCandidates;
  final SwipeUsecase _swipe;
  final WatchMatchesUsecase _watchMatches;

  List<UserEntity> _candidates = [];
  List<MatchEntity> _matches = [];
  bool _isLoading = false;

  StreamSubscription<List<MatchEntity>>? _matchesSub;

  List<UserEntity> get candidates => _candidates;
  List<MatchEntity> get matches => _matches;
  bool get isLoading => _isLoading;

  Future<void> loadCandidates(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _candidates = await _getCandidates(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> swipe(SwipeEntity swipeEntity) async {
    final isMatch = await _swipe(swipeEntity);
    if (isMatch) {
      notifyListeners();
    }
    return isMatch;
  }

  void initMatches(String userId) {
    _matchesSub?.cancel();
    _matchesSub = _watchMatches(userId).listen((m) {
      _matches = m;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    super.dispose();
  }
}
