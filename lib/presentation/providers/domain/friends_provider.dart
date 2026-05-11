import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/friend_request_entity.dart';
import '../../../domain/usecases/friends/get_friends_usecase.dart';
import '../../../domain/usecases/friends/get_incoming_requests_usecase.dart';
import '../../../domain/usecases/friends/send_friend_request_usecase.dart';
import '../../../domain/usecases/friends/accept_friend_request_usecase.dart';
import '../../../domain/usecases/friends/decline_friend_request_usecase.dart';
import '../../../domain/usecases/friends/remove_friend_usecase.dart';
import '../../../domain/usecases/friends/search_users_usecase.dart';
import '../../../domain/usecases/friends/get_relationship_status_usecase.dart';

class FriendsProvider extends ChangeNotifier {
  FriendsProvider(
    this._getFriends,
    this._getIncomingRequests,
    this._sendRequest,
    this._acceptRequest,
    this._declineRequest,
    this._removeFriend,
    this._searchUsers,
    this._getRelationshipStatus,
  );

  final GetFriendsUsecase _getFriends;
  final GetIncomingRequestsUsecase _getIncomingRequests;
  final SendFriendRequestUsecase _sendRequest;
  final AcceptFriendRequestUsecase _acceptRequest;
  final DeclineFriendRequestUsecase _declineRequest;
  final RemoveFriendUsecase _removeFriend;
  final SearchUsersUsecase _searchUsers;
  final GetRelationshipStatusUsecase _getRelationshipStatus;

  List<UserEntity> _friends = [];
  List<FriendRequestEntity> _incomingRequests = [];
  List<UserEntity> _searchResults = [];
  bool _isLoading = false;
  final Map<String, String> _statusCache = {};
  StreamSubscription<List<UserEntity>>? _friendsSub;
  StreamSubscription<List<FriendRequestEntity>>? _requestsSub;

  List<UserEntity> get friends => _friends;
  List<FriendRequestEntity> get incomingRequests => _incomingRequests;
  List<UserEntity> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  int get pendingCount => _incomingRequests.length;

  void init(String userId) {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    _searchResults = [];
    _statusCache.clear();

    _friendsSub = _getFriends(userId).listen(
      (list) { _friends = list; notifyListeners(); },
      onError: (e) {
        debugPrint('[FriendsProvider] friends stream error: $e');
        _friends = [];
        notifyListeners();
      },
    );

    _requestsSub = _getIncomingRequests(userId).listen(
      (list) { _incomingRequests = list; notifyListeners(); },
      onError: (e) {
        debugPrint('[FriendsProvider] requests stream error: $e');
        _incomingRequests = [];
        notifyListeners();
      },
    );
  }

  Future<void> search(String query, String currentUserId) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _searchResults = await _searchUsers(query, currentUserId);
      await Future.wait(
        _searchResults.map((u) => _loadStatus(currentUserId, u.id)),
      );
    } catch (e) {
      debugPrint('[FriendsProvider] search error: $e');
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> getRelationship(
    String currentUserId,
    String otherUserId,
  ) async {
    if (!_statusCache.containsKey(otherUserId)) {
      await _loadStatus(currentUserId, otherUserId);
    }
    return _statusCache[otherUserId] ?? 'none';
  }

  Future<void> sendRequest(String from, String to) async {
    await _sendRequest(from, to);
    _statusCache[to] = 'pending_sent';
    notifyListeners();
  }

  Future<void> acceptRequest(
    String requestId,
    String from,
    String to,
  ) async {
    await _acceptRequest(requestId, from, to);
    _statusCache[from] = 'friends';
    _incomingRequests =
        _incomingRequests.where((r) => r.id != requestId).toList();
    notifyListeners();
  }

  Future<void> declineRequest(String requestId) async {
    await _declineRequest(requestId);
    _incomingRequests =
        _incomingRequests.where((r) => r.id != requestId).toList();
    notifyListeners();
  }

  Future<void> removeFriend(String currentUserId, String friendId) async {
    await _removeFriend(currentUserId, friendId);
    _statusCache[friendId] = 'none';
    notifyListeners();
  }

  Future<void> _loadStatus(String currentUserId, String otherUserId) async {
    final status = await _getRelationshipStatus(currentUserId, otherUserId);
    _statusCache[otherUserId] = status;
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
