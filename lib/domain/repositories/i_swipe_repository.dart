import '../entities/match_entity.dart';
import '../entities/swipe_entity.dart';
import '../entities/user_entity.dart';

abstract interface class ISwipeRepository {
  Future<List<UserEntity>> getCandidates(String userId);
  Future<bool> swipe(SwipeEntity swipe);
  Stream<List<MatchEntity>> watchMatches(String userId);
}
