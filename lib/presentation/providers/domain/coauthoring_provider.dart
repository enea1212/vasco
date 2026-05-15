import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/post_entity.dart';
import '../../../domain/usecases/coauthoring/accept_coauthor_request_usecase.dart';
import '../../../domain/usecases/coauthoring/decline_coauthor_request_usecase.dart';
import '../../../domain/usecases/coauthoring/watch_pending_coauthor_requests_usecase.dart';

class CoAuthoringProvider extends ChangeNotifier {
  CoAuthoringProvider(
    this._watchPending,
    this._accept,
    this._decline,
  );

  final WatchPendingCoAuthorRequestsUsecase _watchPending;
  final AcceptCoAuthorRequestUsecase _accept;
  final DeclineCoAuthorRequestUsecase _decline;

  List<PostEntity> _pending = const [];
  bool _isLoading = false;
  String? _userId;
  StreamSubscription<List<PostEntity>>? _sub;

  List<PostEntity> get pending => _pending;
  bool get isLoading => _isLoading;
  int get pendingCount => _pending.length;

  void init(String userId) {
    if (_userId == userId && _sub != null) return;
    _userId = userId;
    _sub?.cancel();
    _isLoading = true;
    notifyListeners();

    _sub = _watchPending(userId).listen(
      (list) {
        _pending = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[CoAuthoringProvider] pending stream error: $e');
        _pending = const [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> accept(String postId) async {
    final uid = _userId;
    if (uid == null) return;
    // Optimistic UI: hide it from the pending list immediately.
    _pending = _pending.where((p) => p.id != postId).toList();
    notifyListeners();
    try {
      await _accept(postId, uid);
    } catch (e) {
      debugPrint('[CoAuthoringProvider] accept error: $e');
      rethrow;
    }
  }

  Future<void> decline(String postId) async {
    final uid = _userId;
    if (uid == null) return;
    _pending = _pending.where((p) => p.id != postId).toList();
    notifyListeners();
    try {
      await _decline(postId, uid);
    } catch (e) {
      debugPrint('[CoAuthoringProvider] decline error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
