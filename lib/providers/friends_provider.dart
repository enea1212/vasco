import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../repository/friends_repository.dart';

class FriendsProvider with ChangeNotifier {
  final FriendsRepository _repo = FriendsRepository();

  List<UserModel> _searchResults = [];
  List<FriendRequestModel> _incomingRequests = [];
  List<UserModel> _friends = [];

  bool _isSearching = false;
  String _searchQuery = '';

  // Status cache: otherUserId -> 'none' | 'pending_sent' | 'pending_received' | 'friends'
  final Map<String, String> _statusCache = {};

  StreamSubscription<List<FriendRequestModel>>? _requestsSub;
  StreamSubscription<List<UserModel>>? _friendsSub;

  List<UserModel> get searchResults => _searchResults;
  List<FriendRequestModel> get incomingRequests => _incomingRequests;
  List<UserModel> get friends => _friends;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  int get pendingCount => _incomingRequests.length;

  void init(String userId) {
    _requestsSub?.cancel();
    _friendsSub?.cancel();
    _searchResults = [];
    _searchQuery = '';
    _statusCache.clear();

    _requestsSub = _repo.getIncomingRequests(userId).listen((requests) {
      _incomingRequests = requests;
      notifyListeners();
    });

    _friendsSub = _repo.getFriends(userId).listen((friends) {
      _friends = friends;
      notifyListeners();
    });
  }

  Future<void> search(String query, String currentUserId) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _repo.searchUsers(query, currentUserId);
      await Future.wait(_searchResults.map((u) => _loadStatus(currentUserId, u.id)));
    } catch (e, st) {
      debugPrint('[FriendsProvider] search error: $e\n$st');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<String> getStatus(String currentUserId, String otherUserId) async {
    if (!_statusCache.containsKey(otherUserId)) {
      await _loadStatus(currentUserId, otherUserId);
    }
    return _statusCache[otherUserId] ?? 'none';
  }

  Future<void> _loadStatus(String currentUserId, String otherUserId) async {
    final status = await _repo.getRelationshipStatus(currentUserId, otherUserId);
    _statusCache[otherUserId] = status;
  }

  Future<void> sendRequest(String fromId, String toId) async {
    await _repo.sendFriendRequest(fromId, toId);
    _statusCache[toId] = 'pending_sent';
    notifyListeners();
  }

  Future<void> cancelRequest(String fromId, String toId) async {
    await _repo.cancelFriendRequest(fromId, toId);
    _statusCache[toId] = 'none';
    notifyListeners();
  }

  Future<void> acceptRequest(String requestId, String fromId, String toId) async {
    await _repo.acceptFriendRequest(requestId, fromId, toId);
    _statusCache[fromId] = 'friends';
    _incomingRequests = _incomingRequests.where((r) => r.id != requestId).toList();
    notifyListeners();
  }

  Future<void> declineRequest(String requestId, String fromId) async {
    await _repo.declineFriendRequest(requestId);
    _statusCache[fromId] = 'none';
    _incomingRequests = _incomingRequests.where((r) => r.id != requestId).toList();
    notifyListeners();
  }

  Future<void> removeFriend(String currentUserId, String friendId) async {
    await _repo.removeFriend(currentUserId, friendId);
    _statusCache[friendId] = 'none';
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    _friendsSub?.cancel();
    super.dispose();
  }
}
