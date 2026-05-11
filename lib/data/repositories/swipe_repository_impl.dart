// ignore_for_file: avoid_dynamic_calls
import '../../domain/entities/match_entity.dart';
import '../../domain/entities/swipe_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_swipe_repository.dart';
// injected - see data/datasources/remote/swipe_remote_datasource.dart
import '../models/match_model_ext.dart';
import '../models/swipe_model_ext.dart';
import '../models/user_model_ext.dart';

class SwipeRepositoryImpl implements ISwipeRepository {
  const SwipeRepositoryImpl(this._datasource);

  /// SwipeRemoteDatasource — typed as dynamic until Fase 2A file is created.
  final dynamic _datasource;

  @override
  Future<List<UserEntity>> getCandidates(String userId) async {
    final maps = await _datasource.getCandidates(userId)
        as List<Map<String, dynamic>>;
    return maps.map((m) => userModelFromMap(m).toEntity()).toList();
  }

  @override
  Future<bool> swipe(SwipeEntity swipe) async {
    final map = swipeEntityToMap(swipe);
    return await _datasource.swipe(map) as bool;
  }

  @override
  Stream<List<MatchEntity>> watchMatches(String userId) {
    return (_datasource.watchMatches(userId)
            as Stream<List<Map<String, dynamic>>>)
        .map((maps) => maps
            .map((m) => matchModelFromMap(m, m['id'] as String? ?? '').toEntity())
            .toList());
  }
}
